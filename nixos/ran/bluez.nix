{ stdenv, fetchurl, rpmextract, lib }:

stdenv.mkDerivation {
  pname = "bfubase-firmware";
  version = "1.2";

  # Fetch the openSUSE bluez-firmware RPM
  src = fetchurl {
    url = "https://rpmfind.net/linux/opensuse/tumbleweed/repo/oss/x86_64/bluez-firmware-1.2-150.6.x86_64.rpm";
    sha256 = "sha256-XNX5cqNejKgVgdM+J0S3RINP5yXnyEdXxb69bcCTr44=";
  };

  nativeBuildInputs = [ rpmextract ];

  unpackPhase = ''
    rpmextract $src
  '';

  installPhase = ''
    mkdir -p $out/lib/firmware
    cp -v usr/lib/firmware/bfubase.frm $out/lib/firmware/
  '';

  meta = with lib; {
    description = "Extracted bfubase.frm Bluetooth firmware";
    license = licenses.unfreeRedistributableFirmware;
    platforms = platforms.all;
  };
}
