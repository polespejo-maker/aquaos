#!/usr/bin/env bash
# ============================================================================
#  AquaOS · compila la ISO dentro de un contenedor Arch (necesita Docker en
#  Linux; en Windows/WSL2 mkarchiso no puede usar loop devices).
#
#  Uso:  ./scripts/build-in-docker.sh [--no-aur]
# ============================================================================
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
EXTRA="${*:-}"

command -v docker >/dev/null || { echo "falta docker" >&2; exit 1; }

docker run --rm -it \
    --privileged \
    -v "${ROOT}:/work" \
    -w /work \
    -e EXTRA="${EXTRA}" \
    archlinux:latest \
    bash -lc '
        set -e
        pacman -Sy --noconfirm --needed archiso git base-devel dosfstools mtools
        ./build.sh ${EXTRA}
    '
