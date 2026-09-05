/*
 * lavender-clip: put several MIME types on the Wayland clipboard (or primary selection) at once.
 *
 * wl-copy offers one type per selection; this uses wlr-data-control so a screenshot can be pasted as
 * image/png *and* as a file (text/uri-list, x-special/gnome-copied-files) *and* as its path (text/plain).
 *
 *   lavender-clip [--primary] [--foreground] (--type TYPES (--file PATH | --text STRING))...
 *
 * TYPES is one MIME type or a comma-separated list sharing the same data (parameters like ;charset=utf-8 are
 * fine). Each --type is followed by the data it offers: a file to read, or literal bytes. Offers are advertised
 * in command-line order. Unless --foreground is given the process daemonises once the selection is set and
 * exits when another client replaces it.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-data-control-unstable-v1-client-protocol.h"

struct offer {
	const char *mime;
	const char *data;
	size_t len;
};

static struct offer *offers;
static size_t n_offers;
static struct wl_seat *seat;
static struct zwlr_data_control_manager_v1 *manager;
static uint32_t manager_version;
static int cancelled;

static void die(const char *fmt, const char *arg)
{
	fprintf(stderr, "lavender-clip: ");
	fprintf(stderr, fmt, arg);
	fputc('\n', stderr);
	exit(1);
}

static void registry_global(void *data, struct wl_registry *reg, uint32_t name, const char *iface, uint32_t version)
{
	(void)data;
	if (!seat && strcmp(iface, wl_seat_interface.name) == 0) {
		seat = wl_registry_bind(reg, name, &wl_seat_interface, 1);
	} else if (strcmp(iface, zwlr_data_control_manager_v1_interface.name) == 0) {
		manager_version = version < 2 ? version : 2;
		manager = wl_registry_bind(reg, name, &zwlr_data_control_manager_v1_interface, manager_version);
	}
}

static void registry_global_remove(void *data, struct wl_registry *reg, uint32_t name)
{
	(void)data;
	(void)reg;
	(void)name;
}

static const struct wl_registry_listener registry_listener = {registry_global, registry_global_remove};

/* Write the whole payload to the receiver's pipe, giving up on a reader that stalls for 5 s. */
static void write_all(int fd, const char *buf, size_t len)
{
	while (len > 0) {
		struct pollfd p = {.fd = fd, .events = POLLOUT};
		if (poll(&p, 1, 5000) <= 0)
			return;
		ssize_t n = write(fd, buf, len);
		if (n < 0) {
			if (errno == EINTR || errno == EAGAIN)
				continue;
			return;
		}
		buf += n;
		len -= (size_t)n;
	}
}

static void source_send(void *data, struct zwlr_data_control_source_v1 *src, const char *mime, int32_t fd)
{
	(void)data;
	(void)src;
	for (size_t i = 0; i < n_offers; i++) {
		if (strcmp(offers[i].mime, mime) == 0) {
			write_all(fd, offers[i].data, offers[i].len);
			break;
		}
	}
	close(fd);
}

static void source_cancelled(void *data, struct zwlr_data_control_source_v1 *src)
{
	(void)data;
	(void)src;
	cancelled = 1;
}

static const struct zwlr_data_control_source_v1_listener source_listener = {source_send, source_cancelled};

/* We never read other clients' selections, but offers they announce must be released. */
static void device_data_offer(void *data, struct zwlr_data_control_device_v1 *dev, struct zwlr_data_control_offer_v1 *offer)
{
	(void)data;
	(void)dev;
	(void)offer;
}

static void device_selection(void *data, struct zwlr_data_control_device_v1 *dev, struct zwlr_data_control_offer_v1 *offer)
{
	(void)data;
	(void)dev;
	if (offer)
		zwlr_data_control_offer_v1_destroy(offer);
}

static void device_finished(void *data, struct zwlr_data_control_device_v1 *dev)
{
	(void)data;
	(void)dev;
	cancelled = 1;
}

static const struct zwlr_data_control_device_v1_listener device_listener = {
	device_data_offer, device_selection, device_finished, device_selection,
};

static char *read_file(const char *path, size_t *len)
{
	FILE *f = fopen(path, "rb");
	if (!f)
		die("cannot open %s", path);
	size_t cap = 1 << 16, used = 0;
	char *buf = malloc(cap);
	if (!buf)
		die("out of memory%s", "");
	size_t n;
	while ((n = fread(buf + used, 1, cap - used, f)) > 0) {
		used += n;
		if (used == cap) {
			cap *= 2;
			buf = realloc(buf, cap);
			if (!buf)
				die("out of memory%s", "");
		}
	}
	fclose(f);
	*len = used;
	return buf;
}

static void add_offers(char *types, const char *data, size_t len)
{
	for (char *mime = strtok(types, ","); mime; mime = strtok(NULL, ",")) {
		offers = realloc(offers, (n_offers + 1) * sizeof *offers);
		if (!offers)
			die("out of memory%s", "");
		offers[n_offers++] = (struct offer){mime, data, len};
	}
}

static void usage(void)
{
	printf("usage: lavender-clip [--primary] [--foreground] (--type TYPES (--file PATH | --text STRING))...\n");
}

int main(int argc, char **argv)
{
	int primary = 0, foreground = 0;
	char *types = NULL;
	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--primary") == 0) {
			primary = 1;
		} else if (strcmp(argv[i], "--foreground") == 0) {
			foreground = 1;
		} else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
			usage();
			return 0;
		} else if (strcmp(argv[i], "--type") == 0 && i + 1 < argc && !types) {
			types = argv[++i];
		} else if ((strcmp(argv[i], "--file") == 0 || strcmp(argv[i], "--text") == 0) && i + 1 < argc && types) {
			const char *data;
			size_t len;
			if (argv[i][2] == 'f') {
				data = read_file(argv[i + 1], &len);
			} else {
				data = argv[i + 1];
				len = strlen(data);
			}
			add_offers(types, data, len);
			types = NULL;
			i++;
		} else {
			usage();
			die("unexpected argument '%s'", argv[i]);
		}
	}
	if (types)
		die("--type %s has no --file or --text", types);
	if (n_offers == 0)
		die("nothing to copy (see --help)%s", "");

	signal(SIGPIPE, SIG_IGN);

	struct wl_display *display = wl_display_connect(NULL);
	if (!display)
		die("cannot connect to the Wayland display%s", "");
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	if (!seat)
		die("no wl_seat%s", "");
	if (!manager)
		die("compositor lacks zwlr_data_control_manager_v1%s", "");
	if (primary && manager_version < 2)
		die("data-control v2 (primary selection) not supported%s", "");

	struct zwlr_data_control_device_v1 *device = zwlr_data_control_manager_v1_get_data_device(manager, seat);
	zwlr_data_control_device_v1_add_listener(device, &device_listener, NULL);
	struct zwlr_data_control_source_v1 *source = zwlr_data_control_manager_v1_create_data_source(manager);
	zwlr_data_control_source_v1_add_listener(source, &source_listener, NULL);
	for (size_t i = 0; i < n_offers; i++)
		zwlr_data_control_source_v1_offer(source, offers[i].mime);
	if (primary)
		zwlr_data_control_device_v1_set_primary_selection(device, source);
	else
		zwlr_data_control_device_v1_set_selection(device, source);
	wl_display_roundtrip(display);

	if (!foreground) {
		pid_t pid = fork();
		if (pid < 0)
			die("fork failed%s", "");
		if (pid > 0)
			_exit(0);
		setsid();
		int null = open("/dev/null", O_RDWR);
		if (null >= 0) {
			dup2(null, 0);
			dup2(null, 1);
			dup2(null, 2);
		}
	}

	while (!cancelled && wl_display_dispatch(display) != -1)
		;
	return 0;
}
