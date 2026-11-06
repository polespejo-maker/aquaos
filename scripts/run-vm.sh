#!/usr/bin/env bash
# ============================================================================
#  AquaOS · arranca una ISO en QEMU para probarla
#
#  Uso:  ./scripts/run-vm.sh [-b] <ruta.iso> [memoria_MB]
#    -b   arrancar en modo BIOS (por defecto: UEFI)
#
#  Variables de entorno:
#    AQUAOS_VM_NOGL=1   desactiva la aceleración GL (equipos sin GPU/OpenGL)
#
#  Requisitos: qemu-full y edk2-ovmf (pacman -S qemu-full edk2-ovmf)
# ============================================================================
set -Eeuo pipefail

BIOS=0
if [[ "${1:-}" == "-b" ]]; then BIOS=1; shift; fi

ISO="${1:?uso: run-vm.sh [-b] <ruta.iso> [memoria_MB]}"
MEM="${2:-4096}"
[[ -f "${ISO}" ]] || { echo "no existe la ISO: ${ISO}" >&2; exit 1; }

command -v qemu-system-x86_64 >/dev/null || {
    echo "falta qemu:  sudo pacman -S --needed qemu-full edk2-ovmf" >&2
    exit 1
}

VARS_TMP=""
limpiar() { [[ -n "${VARS_TMP}" ]] && rm -f -- "${VARS_TMP}"; }
trap limpiar EXIT

args=(
    -m "${MEM}"
    -smp "$(nproc)"
    -cpu max
    -machine q35
    -device qemu-xhci
    -device usb-tablet
    -device intel-hda -device hda-duplex
    -netdev "user,id=net0" -device "e1000,netdev=net0"
    -drive "file=${ISO},media=cdrom,readonly=on"
    -boot d
)

if [[ "${AQUAOS_VM_NOGL:-0}" == "1" ]]; then
    args+=(-vga std -display gtk)
else
    args+=(-device virtio-vga-gl -display "gtk,gl=on")
fi

if (( BIOS )); then
    echo "==> Arrancando en modo BIOS (SeaBIOS)"
else
    echo "==> Arrancando en modo UEFI (OVMF)"
    # OVMF se compone de dos volúmenes pflash: código (solo lectura) y variables
    # (una copia escribible por VM, para no tocar la del sistema).
    encontrado=0
    for dir in /usr/share/edk2/x64 /usr/share/edk2-ovmf/x64 /usr/share/ovmf/x64; do
        for code in "${dir}"/OVMF_CODE*.fd; do
            [[ -f "${code}" ]] || continue
            vars="${code/OVMF_CODE/OVMF_VARS}"
            [[ -f "${vars}" ]] || continue
            VARS_TMP="$(mktemp --suffix=.fd)"
            cp -f -- "${vars}" "${VARS_TMP}"
            args+=(-drive "if=pflash,format=raw,readonly=on,file=${code}"
                   -drive "if=pflash,format=raw,file=${VARS_TMP}")
            encontrado=1
            break 2
        done
    done

    if (( ! encontrado )); then
        echo "aviso: no encuentro OVMF; arrancando en BIOS" >&2
    fi
fi

# Copia escribible de la ISO: así el overlay (cow) no toca el archivo original.
qemu-system-x86_64 "${args[@]}" -snapshot
