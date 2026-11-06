#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# AquaOS · definición del perfil archiso
# Se copia sobre el perfil "releng" oficial antes de compilar.
#
# Los valores con %...% son sustituidos por mkarchiso.

iso_name="aquaos"
iso_label="AQUAOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="AquaOS Project"
iso_application="AquaOS Live"
iso_version="0.1.$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m%d)"
install_dir="arch"
buildmodes=('iso')
# Arranque BIOS (syslinux) + UEFI (systemd-boot). Sin GRUB en el medio: menos piezas.
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd = ISO considerablemente más rápida de comprimir que xz, tamaño similar.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
kernel_params="quiet loglevel=3 nowatchdog"
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/aquaos-firstboot"]="0:0:755"
  ["/usr/local/bin/aquaos-desktop-setup"]="0:0:755"
  ["/usr/local/bin/aquaos-install"]="0:0:755"
  ["/usr/local/bin/aquaos-info"]="0:0:755"
)
