#!/usr/bin/env bash
# ============================================================================
#  AquaOS · comprobaciones estáticas (sin compilar la ISO)
#  Uso:  ./scripts/lint.sh
# ============================================================================
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}" || exit 1

errores=0
rojo=$'\033[31m'; verde=$'\033[32m'; amarillo=$'\033[33m'; azul=$'\033[34m'; reset=$'\033[0m'

ok()    { printf '%s  ok%s %s\n' "${verde}" "${reset}" "$*"; }
fallo() { printf '%s fallo%s %s\n' "${rojo}" "${reset}" "$*"; errores=$(( errores + 1 )); }
idea()  { printf '%s  --%s %s\n' "${amarillo}" "${reset}" "$*"; }

# Todos los scripts bash del proyecto (sin build/, out/ ni dependencias).
mapfile -t SCRIPTS < <(
    {
        find . -name '*.sh' \
            -not -path './build/*' -not -path './out/*' \
            -not -path './.git/*' -not -path './.venv/*' \
            -not -path './node_modules/*'
        find profile/airootfs/usr/local/bin -maxdepth 1 -type f -name 'aquaos-*'
        find profile/airootfs/usr/share/aquaos -type f -name '*.sh'
    } | sort
)

printf '%s==>%s Sintaxis de bash\n' "${azul}" "${reset}"
if command -v bash >/dev/null 2>&1; then
    for f in "${SCRIPTS[@]}"; do
        if bash -n "${f}" 2>/tmp/aquaos-bash-err; then
            ok "${f}"
        else
            fallo "${f}: $(cat /tmp/aquaos-bash-err)"
        fi
    done
else
    idea "bash no disponible: se omite la comprobación de sintaxis"
fi

printf '\n%s==>%s ShellCheck\n' "${azul}" "${reset}"
if command -v shellcheck >/dev/null 2>&1; then
    for f in "${SCRIPTS[@]}"; do
        if shellcheck --shell=bash --severity=warning --format=gcc "${f}" >/tmp/aquaos-sc-err 2>&1; then
            ok "${f}"
        else
            fallo "${f}:"
            sed 's/^/       /' /tmp/aquaos-sc-err
        fi
    done
else
    idea "shellcheck no disponible (pacman -S shellcheck)"
fi

printf '\n%s==>%s Python\n' "${azul}" "${reset}"
PY=""
# En Windows, "python3" puede ser el alias vacío de la Microsoft Store: hay que
# comprobar que arranca de verdad antes de fiarse de él.
for candidato in python3 python; do
    if command -v "${candidato}" >/dev/null 2>&1 &&
       "${candidato}" -c 'import sys' >/dev/null 2>&1; then
        PY="${candidato}"
        break
    fi
done
if [[ -n "${PY}" ]]; then
    if "${PY}" -m py_compile scripts/make-wallpapers.py 2>/tmp/aquaos-py-err; then
        ok "scripts/make-wallpapers.py"
    else
        fallo "$(cat /tmp/aquaos-py-err)"
    fi
else
    idea "python no disponible"
fi

printf '\n%s==>%s JavaScript (layout de Plasma)\n' "${azul}" "${reset}"
if command -v node >/dev/null 2>&1; then
    if node --check profile/airootfs/usr/share/aquaos/plasma/layout.js 2>/tmp/aquaos-js-err; then
        ok "layout.js"
    else
        fallo "$(cat /tmp/aquaos-js-err)"
    fi
else
    idea "node no disponible"
fi

printf '\n%s==>%s Coherencia de listas de paquetes\n' "${azul}" "${reset}"
limpia() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1" | sort -u; }
faltan="$(comm -23 <(limpia profile/packages-desktop.txt) <(limpia profile/packages.x86_64))"
if [[ -z "${faltan}" ]]; then
    ok "packages-desktop.txt ⊆ packages.x86_64"
else
    fallo "paquetes del escritorio que no están en la ISO:"
    printf '%s\n' "${faltan}" | sed 's/^/       /'
fi

printf '\n%s==>%s Archivos imprescindibles\n' "${azul}" "${reset}"
for f in \
    profile/profiledef.sh \
    profile/pacman.conf \
    profile/packages.x86_64 \
    profile/airootfs/root/customize_airootfs.sh \
    profile/airootfs/etc/sddm.conf.d/00-aquaos.conf \
    profile/airootfs/etc/systemd/system/aquaos-firstboot.service \
    profile/airootfs/etc/xdg/autostart/aquaos-desktop-setup.desktop \
    profile/airootfs/usr/local/bin/aquaos-firstboot \
    profile/airootfs/usr/local/bin/aquaos-install \
    profile/airootfs/usr/local/bin/aquaos-desktop-setup \
    profile/airootfs/usr/local/bin/aquaos-info \
    profile/airootfs/usr/share/aquaos/plasma/layout.js \
    profile/airootfs/usr/share/aquaos/install/in-chroot.sh \
    profile/airootfs/usr/share/wallpapers/AquaOS/ventura.png
do
    if [[ -e "${f}" ]]; then ok "${f}"; else fallo "falta ${f}"; fi
done

printf '\n%s==>%s Referencias entre scripts y build.sh\n' "${azul}" "${reset}"
idea "/usr/share/aquaos/packages-desktop.txt lo inyecta build.sh"
if grep -q 'packages-desktop.txt' profile/airootfs/usr/local/bin/aquaos-install; then
    ok "el instalador usa la lista que inyecta build.sh"
else
    fallo "el instalador no referencia packages-desktop.txt"
fi

printf '\n'
if (( errores > 0 )); then
    printf '%s%d problema(s)%s\n' "${rojo}" "${errores}" "${reset}"
    exit 1
fi
printf '%sTodo correcto%s\n' "${verde}" "${reset}"
