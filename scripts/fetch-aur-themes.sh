#!/usr/bin/env bash
# ============================================================================
#  AquaOS · integra los temas de AUR (WhiteSur) dentro del airootfs
#
#  Los temas son paquetes SOLO DE DATOS (iconos, cursores, temas GTK), así que
#  en vez de montar un repositorio local dentro de la ISO simplemente
#  compilamos el paquete y extraemos su contenido en el árbol del sistema.
#
#  Uso:  ./fetch-aur-themes.sh <dir-temporal> <airootfs> [paquete ...]
# ============================================================================
set -Eeuo pipefail

OUT="${1:?falta el directorio de trabajo}"
AIROOTFS="${2:?falta la ruta del airootfs}"
shift 2

PKGS=("$@")
if (( ${#PKGS[@]} == 0 )); then
    PKGS=(
        whitesur-icon-theme
        whitesur-cursor-theme-git
        whitesur-gtk-theme
    )
fi

warn() { printf ' aviso  %s\n' "$*" >&2; }
info() { printf '==> %s\n' "$*"; }

# makepkg se niega a compilar como root: creamos un usuario de build.
if ! id builder >/dev/null 2>&1; then
    useradd -m -s /bin/bash builder
fi
printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/99-aquaos-builder
chmod 0440 /etc/sudoers.d/99-aquaos-builder

pacman -S --needed --noconfirm --quiet git base-devel sudo >/dev/null

mkdir -p -- "${OUT}"
chown builder:builder "${OUT}"

built=0
for pkg in "${PKGS[@]}"; do
    info "AUR: ${pkg}"
    dir="${OUT}/${pkg}"
    rm -rf -- "${dir}"

    if ! git clone --depth=1 --quiet "https://aur.archlinux.org/${pkg}.git" "${dir}" 2>/dev/null; then
        warn "no se pudo clonar ${pkg} (¿sin red?)"
        continue
    fi
    chown -R builder:builder "${dir}"

    # HOME explícito: makepkg lee ~/.makepkg.conf y ~/.config/pacman.
    if ! ( cd -- "${dir}" && runuser -u builder -- env HOME=/home/builder \
            makepkg -s --noconfirm --nosign --skippgpcheck ) >"${dir}.log" 2>&1; then
        warn "falló la compilación de ${pkg} (ver ${dir}.log)"
        continue
    fi

    pkgfile="$(find "${dir}" -maxdepth 1 -name '*.pkg.tar.zst' -print -quit)"
    if [[ -z "${pkgfile}" ]]; then
        warn "${pkg} no generó ningún paquete"
        continue
    fi

    # Extraemos solo el contenido útil (los metadatos de pacman no hacen falta)
    bsdtar -xf "${pkgfile}" -C "${AIROOTFS}" \
        --exclude '.PKGINFO' --exclude '.BUILDINFO' --exclude '.MTREE' --exclude '.INSTALL'
    built=$(( built + 1 ))
    info "integrado $(basename -- "${pkgfile}")"
done

if (( built == 0 )); then
    warn "ningún tema de AUR se pudo integrar"
    exit 1
fi
info "${built} tema(s) integrado(s)"
