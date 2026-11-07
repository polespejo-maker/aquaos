#!/usr/bin/env bash
# ============================================================================
#  AquaOS · aplica el escritorio a un Arch Linux ya instalado
#
#  No compila ISO: instala los paquetes y copia la configuración en el sistema
#  actual. Útil para probar el "look" rápido.
#
#  Uso:  sudo ./scripts/apply-to-current-system.sh [--no-packages]
# ============================================================================
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="${ROOT}/profile/airootfs"
INSTALAR_PAQUETES=1

[[ "${1:-}" == "--no-packages" ]] && INSTALAR_PAQUETES=0

msg()  { printf '\033[34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m  ok\033[0m %s\n' "$*"; }
morir(){ printf '\033[31m error\033[0m %s\n' "$*" >&2; exit 1; }

(( EUID == 0 )) || morir "ejecútalo con sudo"
[[ -f /etc/arch-release ]] || morir "esto es para Arch Linux"
[[ -n "${SUDO_USER:-}" ]] || morir "lánzalo con sudo desde tu usuario (no como root directo)"

USUARIO="${SUDO_USER}"

if (( INSTALAR_PAQUETES )); then
    msg "Instalando paquetes del escritorio"
    mapa="$(sed -e 's/#.*//' -e '/^\s*$/d' "${ROOT}/profile/packages-desktop.txt" | tr '\n' ' ')"
    # shellcheck disable=SC2086
    pacman -S --needed --noconfirm ${mapa}
    ok "paquetes instalados"
fi

msg "Copiando fondos, marca y scripts"
install -d -m 0755 /usr/share/aquaos /usr/share/wallpapers
cp -a "${OVERLAY}/usr/share/aquaos/." /usr/share/aquaos/
cp -a "${OVERLAY}/usr/share/wallpapers/AquaOS" /usr/share/wallpapers/
install -m 0755 "${OVERLAY}"/usr/local/bin/aquaos-* /usr/local/bin/
install -Dm 0644 "${OVERLAY}/etc/xdg/autostart/aquaos-desktop-setup.desktop" \
    /etc/xdg/autostart/aquaos-desktop-setup.desktop
install -Dm 0644 "${OVERLAY}/etc/sddm.conf.d/00-aquaos.conf" \
    /etc/sddm.conf.d/00-aquaos.conf
install -Dm 0644 "${OVERLAY}/etc/systemd/system/aquaos-firstboot.service" \
    /etc/systemd/system/aquaos-firstboot.service
cp -f "${ROOT}/profile/packages-desktop.txt" /usr/share/aquaos/packages-desktop.txt
ok "archivos copiados"

# --- temas propios: splash de arranque y login ------------------------------
msg "Instalando temas de Plymouth y SDDM"

if [[ -d "${OVERLAY}/usr/share/aquaos/plymouth/aquaos" ]]; then
    if pacman -Qq plymouth >/dev/null 2>&1; then
        install -d -m 0755 /usr/share/plymouth/themes/aquaos
        cp -a "${OVERLAY}/usr/share/aquaos/plymouth/aquaos/." \
            /usr/share/plymouth/themes/aquaos/
        plymouth-set-default-theme aquaos >/dev/null 2>&1 || true
        ok "tema Plymouth aquaos"
    else
        ok "plymouth no está instalado: se omite el splash"
    fi
fi

if [[ -d "${OVERLAY}/usr/share/aquaos/sddm/aquaos" ]]; then
    install -d -m 0755 /usr/share/sddm/themes/aquaos /etc/sddm.conf.d
    cp -a "${OVERLAY}/usr/share/aquaos/sddm/aquaos/." /usr/share/sddm/themes/aquaos/
    printf '[Theme]\nCurrent=aquaos\n' > /etc/sddm.conf.d/15-aquaos-theme.conf
    ok "tema SDDM aquaos"
fi

# El hook plymouth arranca el splash desde el initramfs. Solo tiene sentido si
# el paquete está instalado; si no, se deja el arranque en texto.
if pacman -Qq plymouth >/dev/null 2>&1; then
    msg "Activando el splash en el initramfs y en GRUB"

    if [[ -f /etc/mkinitcpio.conf ]] \
        && ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
        sed -i -E 's/^(HOOKS=\(.*\b)udev(.*\))$/\1udev plymouth\2/' /etc/mkinitcpio.conf
    fi

    if [[ -f /etc/default/grub ]] \
        && ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bsplash\b' /etc/default/grub; then
        if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
            sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)"/\1\2 splash"/' /etc/default/grub
        else
            printf 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"\n' >> /etc/default/grub
        fi
    fi

    mkinitcpio -P
    if [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
    fi
    ok "splash activo"
else
    ok "plymouth no está instalado: arranque en texto"
fi

msg "Añadiendo configuración por defecto para usuarios nuevos (/etc/skel)"
install -d -m 0755 /etc/skel/.config
cp -an "${OVERLAY}/etc/skel/.config/." /etc/skel/.config/ 2>/dev/null || true
ok "skel actualizado"

msg "Aplicando tema y usuario ${USUARIO}"
rm -f /var/lib/aquaos/firstboot.done
AQUAOS_USER="${USUARIO}" /usr/local/bin/aquaos-firstboot || true
ok "tema aplicado"

# El 00-aquaos.conf copiado viene pensado para el live (User=aqua). En un
# sistema real lo anulamos con un archivo posterior: sin autologin y con la
# sesión Plasma correcta.
msg "Ajustando SDDM"
install -d -m 0755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-autologin.conf <<'EOF'
[Autologin]
User=
Session=plasma
EOF
systemctl enable aquaos-firstboot.service >/dev/null 2>&1 || true

systemctl enable --now sddm.service 2>/dev/null || true

cat <<EOF

Listo. Cierra sesión y vuelve a entrar para que Plasma aplique la disposición,
o ejecuta ahora (en tu sesión, no como root):

    /usr/local/bin/aquaos-desktop-setup

Nota: si ya tenías configuración propia de KDE, este script NO la sobrescribe
(usa cp -n); el diseño de paneles sí se aplica porque lo hace por API.
EOF
