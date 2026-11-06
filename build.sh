#!/usr/bin/env bash
# ============================================================================
#  AquaOS · constructor de la imagen ISO
#
#  Uso:   sudo ./build.sh [opciones]
#
#  Opciones:
#    --no-aur            No compila los temas de AUR (build más rápido y sin red)
#    --no-offline-repo   No incluye los paquetes del sistema instalado en la ISO
#                        (ISO mucho más pequeña, pero el instalador necesitará red)
#    --clean             Borra build/ y out/ antes de empezar
#    --vm                Arranca la ISO en QEMU al terminar (necesita qemu)
#    -h, --help          Esta ayuda
#
#  Requisitos: Arch Linux, paquete "archiso", root, ~10 GB libres
#              (~14 GB si se incluye el repositorio offline).
# ============================================================================
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_SRC="${ROOT}/profile"
BUILD="${ROOT}/build"
OUT="${ROOT}/out"
STAGE="${BUILD}/profile"

WITH_AUR=1
WITH_OFFLINE_REPO=1
CLEAN=0
RUN_VM=0

c_reset=$'\033[0m'; c_bold=$'\033[1m'; c_blue=$'\033[34m'
c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'

msg()  { printf '%s==>%s %s\n' "${c_blue}${c_bold}" "${c_reset}" "$*"; }
ok()   { printf '%s  ok%s %s\n' "${c_green}" "${c_reset}" "$*"; }
warn() { printf '%s aviso%s %s\n' "${c_yellow}" "${c_reset}" "$*" >&2; }
die()  { printf '%s error%s %s\n' "${c_red}" "${c_reset}" "$*" >&2; exit 1; }

usage() { sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while (( $# > 0 )); do
    case "$1" in
        --no-aur) WITH_AUR=0 ;;
        --no-offline-repo) WITH_OFFLINE_REPO=0 ;;
        --clean)  CLEAN=1 ;;
        --vm)     RUN_VM=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
    shift
done

trap 'die "falló en la línea ${LINENO} (comando: ${BASH_COMMAND})"' ERR

# ---------------------------------------------------------------------------
# 0. Comprobaciones
# ---------------------------------------------------------------------------
msg "Comprobando el entorno"
(( EUID == 0 )) || die "hay que ejecutar como root (sudo ./build.sh)"
[[ -f /etc/arch-release ]] || die "esto solo compila en Arch Linux (o en el contenedor archlinux)"
command -v mkarchiso >/dev/null || die "falta el paquete archiso: pacman -S --needed archiso"
command -v xorriso  >/dev/null || die "falta xorriso (paquete libisoburn)"
command -v mkfs.fat >/dev/null || die "falta mkfs.fat (paquete dosfstools)"
command -v mmd      >/dev/null || die "falta mmd (paquete mtools)"
command -v mcopy    >/dev/null || die "falta mcopy (paquete mtools)"
if (( WITH_OFFLINE_REPO )); then
    command -v repo-add >/dev/null || die "falta repo-add (paquete pacman)"
    command -v pactree  >/dev/null || die "falta pactree (paquete pacman)"
fi
[[ -d /usr/share/archiso/configs/releng ]] || die "no encuentro el perfil releng de archiso"

FREE_GB=$(( $(df -Pk "${ROOT}" | awk 'NR==2 {print $4}') / 1024 / 1024 ))
MIN_GB=10
(( WITH_OFFLINE_REPO )) && MIN_GB=14
(( FREE_GB >= MIN_GB )) \
    || warn "solo quedan ${FREE_GB} GB libres; el build necesita ~${MIN_GB} GB"
ok "entorno correcto (${FREE_GB} GB libres)"

# ---------------------------------------------------------------------------
# 1. Preparar el árbol del perfil
# ---------------------------------------------------------------------------
if (( CLEAN )); then
    msg "Limpiando build/ y out/"
    rm -rf -- "${BUILD}" "${OUT}"
fi
mkdir -p -- "${BUILD}" "${OUT}"

msg "Preparando el perfil en ${STAGE}"
rm -rf -- "${STAGE}"
# Partimos del perfil oficial: así heredamos arranque BIOS/UEFI, hooks y
# configuración de mkinitcpio que archiso espera, y solo cambiamos lo nuestro.
cp -a -- /usr/share/archiso/configs/releng "${STAGE}"
cp -a -- "${PROFILE_SRC}/." "${STAGE}/"
ok "perfil base + overlay de AquaOS"

# ---------------------------------------------------------------------------
# 2. Utilidades internas
# ---------------------------------------------------------------------------
AIROOTFS="${STAGE}/airootfs"
SYSD="${AIROOTFS}/etc/systemd/system"

enable_unit() { # <carpeta .wants> <nombre de unidad> <ruta real de la unidad>
    local wants="${SYSD}/$1" unit="$2" target="$3"
    mkdir -p -- "${wants}"
    ln -sfn -- "${target}" "${wants}/${unit}"
}

disable_unit() { # <carpeta .wants> <unidad>
    rm -f -- "${SYSD}/$1/$2"
}

# ---------------------------------------------------------------------------
# 3. Ajustes del overlay que requieren enlaces simbólicos (no se pueden
#    guardar como symlink en un repo git de Windows)
# ---------------------------------------------------------------------------
AIROOTFS_USR="${AIROOTFS}/usr/share/aquaos"
install -d -m 0755 "${AIROOTFS_USR}"
cp -f -- "${PROFILE_SRC}/packages-desktop.txt" "${AIROOTFS_USR}/packages-desktop.txt"
if [[ -f "${ROOT}/README.md" ]]; then
    cp -f -- "${ROOT}/README.md" "${AIROOTFS_USR}/README.md"
fi

msg "Creando enlaces de systemd"

enable_unit multi-user.target.wants   aquaos-firstboot.service /etc/systemd/system/aquaos-firstboot.service
enable_unit multi-user.target.wants   NetworkManager.service     /usr/lib/systemd/system/NetworkManager.service
enable_unit multi-user.target.wants   bluetooth.service          /usr/lib/systemd/system/bluetooth.service
enable_unit graphical.target.wants    sddm.service               /usr/lib/systemd/system/sddm.service
enable_unit timers.target.wants       fstrim.timer               /usr/lib/systemd/system/fstrim.timer

# display-manager.service es el alias que usa systemd para lanzar el login gráfico
ln -sfn -- /usr/lib/systemd/system/sddm.service "${SYSD}/display-manager.service"

# Quitamos lo que trae el perfil releng y aquí no aplica:
#  - networkd: usamos NetworkManager (si no, dos gestores peleándose por la red)
#  - iwd / sshd / ModemManager / cloud-init / guests: no van en este ISO
disable_unit multi-user.target.wants systemd-networkd.service
disable_unit sockets.target.wants    systemd-networkd.socket
disable_unit network-online.target.wants systemd-networkd-wait-online.service
disable_unit multi-user.target.wants iwd.service
disable_unit multi-user.target.wants sshd.service
disable_unit multi-user.target.wants ModemManager.service
disable_unit sockets.target.wants    pcscd.socket

# cloud-init y los servicios de invitados vienen del perfil releng y aquí
# sobran (no hay nube ni hipervisor que los necesite).
rm -rf -- "${SYSD}/cloud-init.target.wants"
rm -f -- "${SYSD}/dbus-org.freedesktop.network1.service"
for u in hv_fcopy_daemon.service hv_kvp_daemon.service hv_vss_daemon.service \
         vboxservice.service vmtoolsd.service vmware-vmblock-fuse.service; do
    disable_unit multi-user.target.wants "${u}"
done
ok "unidades configuradas"

# ---------------------------------------------------------------------------
# 4. Temas opcionales de AUR (iconos, cursores, GTK)
# ---------------------------------------------------------------------------
if (( WITH_AUR )); then
    msg "Compilando temas de AUR (puede tardar unos minutos)"
    if bash "${ROOT}/scripts/fetch-aur-themes.sh" "${BUILD}/aur" "${AIROOTFS}"; then
        ok "temas de AUR integrados"
    else
        warn "no se pudieron integrar los temas de AUR; se usará el tema Breeze"
    fi
else
    warn "temas de AUR desactivados (--no-aur): el escritorio usará Breeze"
fi

# ---------------------------------------------------------------------------
# 5. Repositorio offline dentro de la ISO
#    Copia en la ISO los paquetes del sistema instalado (y sus dependencias)
#    para que `aquaos-install --offline` funcione sin conexión a internet.
#    Es lo que más engorda la imagen (~1,5-2,5 GB): se puede omitir con
#    --no-offline-repo.
# ---------------------------------------------------------------------------
if (( WITH_OFFLINE_REPO )); then
    msg "Preparando el repositorio offline (esto descarga bastantes paquetes)"
    repo_dir="${AIROOTFS}/usr/share/aquaos/repo"
    install -d -m 0755 "${repo_dir}"

    mapfile -t paquetes < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "${PROFILE_SRC}/packages-desktop.txt")
    (( ${#paquetes[@]} > 0 )) || die "packages-desktop.txt está vacío"

    pacman -Sy --noconfirm >/dev/null || die "no se pudo actualizar la base de datos de pacman"

    # El repositorio debe contener también las dependencias, no solo la lista.
    mapfile -t todos < <(
        for p in "${paquetes[@]}"; do
            printf '%s\n' "${p}"
            pactree -s -u -l "${p}" 2>/dev/null || true
        done | sed '/^[[:space:]]*$/d' | sort -u
    )

    msg "Descargando ${#todos[@]} paquetes a ${repo_dir}"
    if ! pacman -Sw --noconfirm --cachedir "${repo_dir}" "${todos[@]}" >/dev/null; then
        die "no se pudieron descargar los paquetes del repositorio offline"
    fi

    compgen -G "${repo_dir}/*.pkg.tar.zst" >/dev/null || die "el repositorio offline quedó vacío"
    repo-add --quiet --remove "${repo_dir}/aquaos-local.db.tar.gz" "${repo_dir}"/*.pkg.tar.zst
    ok "repositorio offline listo ($(du -sh -- "${repo_dir}" | cut -f1))"
else
    warn "sin repositorio offline: el instalador necesitará internet (o usa --offline y fallará)"
fi

# ---------------------------------------------------------------------------
# 6. Compilar la ISO
# ---------------------------------------------------------------------------
msg "Compilando la ISO con mkarchiso (esto tarda 20-60 min)"
mkarchiso -v -w "${BUILD}/work" -o "${OUT}" "${STAGE}"

# ---------------------------------------------------------------------------
# 7. Resumen
# ---------------------------------------------------------------------------
ISO="$(find "${OUT}" -maxdepth 1 -name '*.iso' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
[[ -n "${ISO}" ]] || die "mkarchiso terminó pero no encuentro la ISO en ${OUT}"

( cd -- "${OUT}" && sha256sum -- "$(basename -- "${ISO}")" > SHA256SUMS )

msg "Listo"
ok "ISO:    ${ISO}  ($(du -h -- "${ISO}" | cut -f1))"
ok "sha256: $(cut -d' ' -f1 "${OUT}/SHA256SUMS")"
printf '\n  Grábala con dd, Rufus o balenaEtcher.\n'
printf '  Probar en máquina virtual:  %s\n\n' "./scripts/run-vm.sh \"${ISO}\""

if (( RUN_VM )); then
    bash "${ROOT}/scripts/run-vm.sh" "${ISO}"
fi
