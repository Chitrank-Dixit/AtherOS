#!/usr/bin/env bash
# shellcheck disable=SC2034
iso_name="aether-arch-gnome-experiment"
iso_label="AETHER_GNOME_$(date +%Y%m)"
iso_publisher="Aether Linux"
iso_application="Aether Linux Arch GNOME package experiment"
iso_version="0.1.0"
install_dir="aether-gnome"
buildmodes=('iso')
bootmodes=('uefi-x64.systemd-boot.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
)
