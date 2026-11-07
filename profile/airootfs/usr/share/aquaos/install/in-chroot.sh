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

# Los paquetes de Arch dejan el sistema identificándose como "Arch Linux".
# En una instalación de AquaOS eso no es cierto: reescribimos os-release
# (el archivo canónico es /usr/lib/os-release; /etc/os-release es un enlace).
cat > /usr/lib/os-release <<'EOF'
NAME="AquaOS"
PRETTY_NAME="AquaOS 0.1"
ID=aquaos
ID_LIKE=arch
BUILD_ID=rolling
VERSION_ID="0.1"
VERSION="0.1 (Ventura)"
ANSI_COLOR="38;2;10;132;255"
HOME_URL="https://example.invalid/aquaos"
LOGO=aquaos-logo
EOF
rm -f /etc/os-release
ln -sfn ../usr/lib/os-release /etc/os-release

cat > /etc/issue <<EOF

     AquaOS 0.1  ·  \r  (\l)

     usuario: ${AQUAOS_USUARIO}
     ayuda:   aquaos-info

EOF

cat > /etc/motd <<'EOF'
  ┌──────────────────────────────────────────────────────────────┐
  │  AquaOS · escritorio Linux con alma de macOS                 │
  └──────────────────────────────────────────────────────────────┘

  Ayuda del sistema:  aquaos-info
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

# --- temas propios: splash de arranque y login ----------------------------
if [[ -d /usr/share/aquaos/plymouth/aquaos ]]; then
    install -d -m 0755 /usr/share/plymouth/themes/aquaos
    cp -a /usr/share/aquaos/plymouth/aquaos/. /usr/share/plymouth/themes/aquaos/
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        plymouth-set-default-theme aquaos >/dev/null 2>&1 || true
    fi
fi

if [[ -d /usr/share/aquaos/sddm/aquaos ]]; then
    install -d -m 0755 /usr/share/sddm/themes/aquaos
    cp -a /usr/share/aquaos/sddm/aquaos/. /usr/share/sddm/themes/aquaos/
    install -d -m 0755 /etc/sddm.conf.d
    printf '[Theme]\nCurrent=aquaos\n' > /etc/sddm.conf.d/15-aquaos-theme.conf
fi

# El hook plymouth arranca el splash desde el initramfs. En Arch el hook
# "udev" ya está en HOOKS; se inserta justo detrás y solo una vez.
if [[ -f /etc/mkinitcpio.conf ]] \
    && ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
    sed -i -E 's/^(HOOKS=\(.*\b)udev(.*\))$/\1udev plymouth\2/' /etc/mkinitcpio.conf
fi

# --- initramfs ------------------------------------------------------------
if ! mkinitcpio -P; then
    echo "aviso: mkinitcpio devolvió errores; se continúa (revisa el log)" >&2
fi

# --- swap ----------------------------------------------------------------
if [[ "${AQUAOS_SWAP}" == "1" ]]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    printf '/swapfile none swap defaults 0 0\n' >> /etc/fstab
fi

# --- identidad del menú de arranque ---------------------------------------
# Sin esto, GRUB mostraría "Arch Linux" y esperaría 5 s en cada arranque.
if [[ -f /etc/default/grub ]]; then
    sed -i -E 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="AquaOS"|' /etc/default/grub
    sed -i -E 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    grep -q '^GRUB_DISTRIBUTOR=' /etc/default/grub \
        || printf 'GRUB_DISTRIBUTOR="AquaOS"\n' >> /etc/default/grub
    grep -q '^GRUB_TIMEOUT=' /etc/default/grub \
        || printf 'GRUB_TIMEOUT=3\n' >> /etc/default/grub
    # Tema Breeze (paquete breeze-grub) para que el menú no sea texto plano.
    if [[ -f /usr/share/grub/themes/breeze/theme.txt ]]; then
        sed -i '/^GRUB_THEME=/d' /etc/default/grub
        printf 'GRUB_THEME="/usr/share/grub/themes/breeze/theme.txt"\n' >> /etc/default/grub
    fi
    # "splash" hace que Plymouth muestre el tema durante el arranque.
    if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bsplash\b' /etc/default/grub; then
        if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
            sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)"/\1\2 splash"/' /etc/default/grub
        else
            printf 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"\n' >> /etc/default/grub
        fi
    fi
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
