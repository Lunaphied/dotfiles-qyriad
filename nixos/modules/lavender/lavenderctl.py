#!/usr/bin/env python3
"""lavenderctl: manage the headless sway outputs and their wayvnc streams.

Runs as the session user (normally over SSH, driven by LavenderViewer). Always prints one JSON document on stdout:
{"displays": [...]} on success or {"error": "..."} (exit status 1) on failure. Arguments come from a remote client, so
everything is validated against strict patterns and no shell is ever involved.

  lavenderctl list
  lavenderctl add    [--mode WxH[@R]] [--pos X,Y | --right-of NAME] [--scale S]
  lavenderctl remove NAME
  lavenderctl set    NAME [--mode WxH[@R]] [--pos X,Y] [--scale S]
"""
import argparse
import fcntl
import json
import os
import re
import subprocess
import sys
import time

SWAYMSG = "@swaymsg@"
SYSTEMCTL = "@systemctl@"

NAME_RE = re.compile(r"^HEADLESS-[0-9]{1,4}$")
MODE_RE = re.compile(r"^([0-9]{3,5})x([0-9]{3,5})(?:@([0-9]{2,3}(?:\.[0-9]{1,3})?)(?:Hz)?)?$")
POS_RE = re.compile(r"^(-?[0-9]{1,5}),(-?[0-9]{1,5})$")
MAX_DIM = 4096  # VAAPI H.264 encode limit per stream (width and height)
MIN_DIM = 320
DEFAULT_MODE = "1920x1080@60Hz"
UNIT = "wayvnc@{}.service"


class Fail(Exception):
    pass


def uid_rundir():
    return "/run/user/%d" % os.getuid()


def run(argv, check=True):
    p = subprocess.run(argv, capture_output=True, text=True, timeout=30)
    if check and p.returncode != 0:
        raise Fail("%s failed: %s" % (os.path.basename(argv[0]), (p.stderr or p.stdout).strip()[:300]))
    return p


def swaysock():
    # sway's startup exec exports SWAYSOCK to the user manager; ssh sessions don't have it.
    env = os.environ.get("SWAYSOCK")
    if env and os.path.exists(env):
        return env
    out = run([SYSTEMCTL, "--user", "show-environment"], check=False).stdout
    for line in out.splitlines():
        if line.startswith("SWAYSOCK=") and os.path.exists(line[9:]):
            return line[9:]
    raise Fail("no running sway session found (is sway-headless.service up?)")


def sway(*args):
    return run([SWAYMSG, "-s", swaysock(), *args]).stdout


def outputs():
    data = json.loads(sway("-t", "get_outputs", "-r"))
    result = {}
    for o in data:
        if not NAME_RE.match(o["name"]):
            continue  # ignore anything that is not one of our headless outputs
        mode = o.get("current_mode") or {}
        rect = o.get("rect", {})
        result[o["name"]] = {
            "name": o["name"],
            "width": mode.get("width", 0),
            "height": mode.get("height", 0),
            "refresh": round(mode.get("refresh", 0) / 1000.0, 3),
            "x": rect.get("x", 0),
            "y": rect.get("y", 0),
            "logicalWidth": rect.get("width", 0),
            "scale": o.get("scale", 1.0),
        }
    return result


def sock_path(name):
    return "%s/lavender/%s.vnc" % (uid_rundir(), name)


def unit_active(name):
    return run([SYSTEMCTL, "--user", "is-active", UNIT.format(name)], check=False).stdout.strip() == "active"


def describe():
    displays = []
    for o in sorted(outputs().values(), key=lambda d: int(d["name"].split("-")[1])):
        o = dict(o)
        o["socket"] = sock_path(o["name"])
        o["streaming"] = unit_active(o["name"]) and os.path.exists(o["socket"])
        displays.append(o)
    return displays


def parse_mode(text):
    m = MODE_RE.match(text)
    if not m:
        raise Fail("bad mode %r (expected WxH or WxH@R)" % text)
    w, h = int(m.group(1)), int(m.group(2))
    if not (MIN_DIM <= w <= MAX_DIM and MIN_DIM <= h <= MAX_DIM):
        raise Fail("mode %dx%d outside %d..%d (hardware H.264 limit)" % (w, h, MIN_DIM, MAX_DIM))
    refresh = m.group(3) or "60"
    return "%dx%d@%sHz" % (w, h, refresh)


def parse_pos(text):
    m = POS_RE.match(text)
    if not m:
        raise Fail("bad position %r (expected X,Y)" % text)
    return int(m.group(1)), int(m.group(2))


def parse_scale(text):
    try:
        s = float(text)
    except ValueError:
        raise Fail("bad scale %r" % text)
    if not (0.5 <= s <= 4.0):
        raise Fail("scale must be between 0.5 and 4")
    return "%g" % s


def check_name(name, existing):
    if not NAME_RE.match(name or ""):
        raise Fail("bad display name %r" % name)
    if name not in existing:
        raise Fail("no such display %s" % name)


def apply_output(name, mode=None, pos=None, scale=None):
    cmd = ["output", name]
    if mode:
        cmd += ["mode", mode]
    if pos:
        cmd += ["pos", str(pos[0]), str(pos[1])]
    if scale:
        cmd += ["scale", scale]
    if len(cmd) > 2:
        reply = json.loads(sway(*cmd))
        if not all(r.get("success") for r in reply):
            raise Fail("sway rejected: %s" % json.dumps(reply)[:200])


def cmd_add(args):
    mode = parse_mode(args.mode or DEFAULT_MODE)
    scale = parse_scale(args.scale) if args.scale else None
    before = outputs()
    if args.pos:
        pos = parse_pos(args.pos)
    else:
        anchor = None
        if args.right_of:
            check_name(args.right_of, before)
            anchor = before[args.right_of]
            pos = (anchor["x"] + anchor["logicalWidth"], anchor["y"])
        else:  # right of the rightmost existing output
            right = max((o["x"] + o["logicalWidth"] for o in before.values()), default=0)
            pos = (right, 0)

    sway("create_output")
    created = sorted(set(outputs()) - set(before))
    if len(created) != 1:
        raise Fail("could not determine the new output (got %r)" % created)
    name = created[0]
    try:
        apply_output(name, mode=mode, pos=pos, scale=scale)
        run([SYSTEMCTL, "--user", "start", UNIT.format(name)])
        deadline = time.time() + 8
        while not os.path.exists(sock_path(name)):
            if time.time() > deadline:
                raise Fail("wayvnc for %s did not create %s" % (name, sock_path(name)))
            time.sleep(0.05)
    except Exception:
        run([SYSTEMCTL, "--user", "stop", UNIT.format(name)], check=False)
        run([SWAYMSG, "-s", swaysock(), "output", name, "unplug"], check=False)
        raise
    return {"added": name}


def cmd_remove(args):
    existing = outputs()
    check_name(args.name, existing)
    if len(existing) <= 1:
        raise Fail("refusing to remove the last display")
    # wayvnc does not exit when its output disappears, so stop it first and clean its sockets.
    run([SYSTEMCTL, "--user", "stop", UNIT.format(args.name)], check=False)
    for p in (sock_path(args.name), "%s/lavender/ctl-%s" % (uid_rundir(), args.name),
              "%s/lavender/wayvnc-%s.conf" % (uid_rundir(), args.name)):
        try:
            os.unlink(p)
        except FileNotFoundError:
            pass
    sway("output", args.name, "unplug")
    return {"removed": args.name}


def cmd_set(args):
    existing = outputs()
    check_name(args.name, existing)
    apply_output(args.name,
                 mode=parse_mode(args.mode) if args.mode else None,
                 pos=parse_pos(args.pos) if args.pos else None,
                 scale=parse_scale(args.scale) if args.scale else None)
    return {"updated": args.name}


def main():
    ap = argparse.ArgumentParser(prog="lavenderctl")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    a = sub.add_parser("add")
    a.add_argument("--mode")
    a.add_argument("--pos")
    a.add_argument("--right-of", dest="right_of")
    a.add_argument("--scale")
    r = sub.add_parser("remove")
    r.add_argument("name")
    s = sub.add_parser("set")
    s.add_argument("name")
    s.add_argument("--mode")
    s.add_argument("--pos")
    s.add_argument("--scale")
    args = ap.parse_args()

    os.makedirs("%s/lavender" % uid_rundir(), mode=0o700, exist_ok=True)
    with open("%s/lavender/lock" % uid_rundir(), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)  # one change at a time
        try:
            extra = {"list": lambda a: {}, "add": cmd_add, "remove": cmd_remove, "set": cmd_set}[args.cmd](args)
            print(json.dumps({**extra, "displays": describe()}))
        except Fail as e:
            print(json.dumps({"error": str(e)}))
            sys.exit(1)
        except Exception as e:  # never leak a traceback as non-JSON
            print(json.dumps({"error": "%s: %s" % (type(e).__name__, e)}))
            sys.exit(1)


if __name__ == "__main__":
    main()
