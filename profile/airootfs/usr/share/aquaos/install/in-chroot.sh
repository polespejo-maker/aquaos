#!/usr/bin/env bash
# ============================================================================
#  AquaOS · configuración dentro del sistema ya instalado (chroot)
#
#  Lo llama aquaos-install con arch-chroot y estas variables de entorno:
#    AQUAOS_EQUIPO AQUAOS_ZONA AQUAOS_USUARIO AQUAOS_PASS
#    AQUAOS_SWAP   AQUAOS_UEFI AQUAOS_DISCO   AQUAOS_AUTOLOGIN
# ============================================================================
set -Eeuo pipefail

: "${AQUAOS_EQUIPO:?}" "${AQUAOS_ZONA:?}" "${AQUAOS_USUARIO:?}" "${AQUAOS_PASS:?}"
: "${AQUAOS_SWAP:=0}" "${AQUAOS_UEFI:=1}" "${AQUAOS_DISCO:?}" "${AQUAOS_AUTOLOGIN:=n}"

echo "==> configuración dentro del chroot"

# --- llavero de pacman ----------------------------------------------------
# El instalador copia al destino el llavero del live (ya poblado por
# pacman-init.service). Aun así ejecutamos `--populate` (idempotente) para
# cubrir el caso de un llavero vacío y dejar pacman utilizable al arrancar.
if [[ ! -d /etc/pacman.d/gnupg ]]; then
    pacman-key --init
fi
if ! pacman-key --populate archlinux; then
    echo "aviso: no se pudo poblar el llavero de pacman" >&2
fi

# --- idioma ---------------------------------------------------------------
if [[ -f /etc/locale.gen ]]; then
    sed -i -E 's/^#\s*(es_ES\.UTF-8)/\1/' /etc/locale.gen
    sed -i -E 's/^#\s*(en_US\.UTF-8)/\1/' /etc/locale.gen
    locale-gen
fi
printf 'LANG=es_ES.UTF-8\n' > /etc/locale.conf

# --- teclado --------------------------------------------------------------
printf 'KEYMAP=es\nFONT=lat9w-16\n' > /etc/vconsole.conf

# X11/Xwayland (KWin Wayland lee la distribución del usuario vía kxkbrc,
# que viene en /etc/skel; esto cubre las apps X11 y la consola gráfica).
install -d -m 0755 /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf <<'EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
EndSection
EOF

# Variable estándar para las apps que arrancan fuera de una sesión Plasma.
install -d -m 0755 /etc/environment.d
printf 'XKB_DEFAULT_LAYOUT=es\n' > /etc/environment.d/60-aquaos-keyboard.conf

# --- identidad ------------------------------------------------------------
printf '%s\n' "${AQUAOS_EQUIPO}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${AQUAOS_EQUIPO}.localdomain ${AQUAOS_EQUIPO}
EOF

# --- zona horaria ---------------------------------------------------------
ln -sf "/usr/share/zoneinfo/${AQUAOS_ZONA}" /etc/localtime
hwclock --systohc

# --- usuario --------------------------------------------------------------
if ! id "${AQUAOS_USUARIO}" >/dev/null 2>&1; then
    grupos=()
    for g in wheel video audio render input power storage optical network; do
        if getent group "${g}" >/dev/null 2>&1; then
            grupos+=("${g}")
        fi
    done
    lista_grupos="$(IFS=,; echo "${grupos[*]}")"
    extra=()
    if [[ -n "${lista_grupos}" ]]; then
        extra=(-G "${lista_grupos}")
    fi
    useradd -m -c "AquaOS" -s /bin/bash "${extra[@]}" "${AQUAOS_USUARIO}"
fi
printf '%s:%s\n' "${AQUAOS_USUARIO}" "${AQUAOS_PASS}" | chpasswd

install -d -m 0755 /etc/sudoers.d
printf '%s ALL=(ALL:ALL) ALL\n' "${AQUAOS_USUARIO}" > /etc/sudoers.d/10-aquaos
chmod 0440 /etc/sudoers.d/10-aquaos

# --- servicios ------------------------------------------------------------
systemctl set-default graphical.target
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
systemctl enable sddm.service
systemctl enable fstrim.timer
systemctl enable aquaos-firstboot.service
systemctl enable systemd-timesyncd.service

# --- initramfs ------------------------------------------------------------
mkinitcpio -P

# --- swap ----------------------------------------------------------------
if [[ "${AQUAOS_SWAP}" == "1" ]]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    printf '/swapfile none swap defaults 0 0\n' >> /etc/fstab
fi

# --- gestor de arranque ---------------------------------------------------
if [[ "${AQUAOS_UEFI}" == "1" ]]; then
    grub-install --target=x86_64-efi --efi-directory=/boot \
        --bootloader-id=AquaOS --recheck
else
    grub-install --target=i386-pc "${AQUAOS_DISCO}" --recheck
fi
grub-mkconfig -o /boot/grub/grub.cfg

# --- sesión gráfica -------------------------------------------------------
# OJO: no sobrescribimos 00-aquaos.conf (contiene el resto de ajustes de SDDM);
# el autologin va en un archivo aparte que SDDM lee después.
if [[ "${AQUAOS_AUTOLOGIN}" == "s" ]]; then
    printf '[Autologin]\nUser=%s\nSession=plasma\nRelogin=false\n' "${AQUAOS_USUARIO}" \
        > /etc/sddm.conf.d/10-autologin.conf
else
    printf '[Autologin]\nUser=\nSession=plasma\n' > /etc/sddm.conf.d/10-autologin.conf
fi

echo "==> chroot completado"
