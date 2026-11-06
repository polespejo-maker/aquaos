#!/usr/bin/env bash
# ============================================================================
#  AquaOS · personalización EN TIEMPO DE COMPILACIÓN (chroot del airootfs)
#
#  archiso ejecuta este script después de instalar los paquetes y ANTES de
#  comprimir el sistema de archivos. Es el único punto donde se pueden tocar
#  archivos que pertenecen a paquetes (os-release, locale.gen...).
#
#  Nota: archiso lo marca como "deprecated", pero sigue siendo el mecanismo
#  oficial en la versión 92. Todo lo que se pueda hacer de forma declarativa
#  (ficheros del overlay, unidades de systemd) se hace fuera de aquí.
# ============================================================================
set -Eeuo pipefail

echo "==> AquaOS: personalización del airootfs"

# ---------------------------------------------------------------------------
# 1. Idiomas: dejamos español e inglés disponibles
# ---------------------------------------------------------------------------
if [[ -f /etc/locale.gen ]]; then
    sed -i -E 's/^#\s*(es_ES\.UTF-8)/\1/' /etc/locale.gen
    grep -q '^en_US.UTF-8' /etc/locale.gen || sed -i -E 's/^#\s*(en_US\.UTF-8)/\1/' /etc/locale.gen
    locale-gen
fi

cat > /etc/locale.conf <<'EOF'
LANG=es_ES.UTF-8
LC_MESSAGES=es_ES.UTF-8
EOF

cat > /etc/vconsole.conf <<'EOF'
KEYMAP=es
FONT=lat9w-16
EOF

# ---------------------------------------------------------------------------
# 2. Identidad de la distribución
# ---------------------------------------------------------------------------
# El archivo canónico es /usr/lib/os-release (systemd y os-release(5) lo
# documentan así); /etc/os-release es solo un enlace para quien lo lea por
# la ruta "clásica". Escribimos ambos para que no queden incoherentes.
rm -f /etc/os-release
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
ln -sfn ../usr/lib/os-release /etc/os-release

cat > /etc/hostname <<'EOF'
aquaos
EOF

cat > /etc/issue <<'EOF'

     AquaOS 0.1  ·  \r  (\l)

     usuario: aqua    contraseña: aqua
     instalador: sudo aquaos-install

EOF

cat > /etc/motd <<'EOF'
  ┌──────────────────────────────────────────────────────────────┐
  │  AquaOS · escritorio Linux con alma de macOS                 │
  └──────────────────────────────────────────────────────────────┘

  Usuario live:  aqua   (contraseña: aqua, sudo sin contraseña)
  Instalar:      sudo aquaos-install
  Ayuda:         aquaos-info

  Atajos:  Alt+Espacio   buscador      Alt+F4  cerrar ventana
           Ctrl+Alt+T    terminal      Meta+L  bloquear sesión

EOF

# ---------------------------------------------------------------------------
# 3. Cachés de fuentes e iconos
# ---------------------------------------------------------------------------
fc-cache -f >/dev/null 2>&1 || true
if [[ -d /usr/share/icons ]]; then
    for d in /usr/share/icons/*/; do
        if [[ -f "${d}/index.theme" ]]; then
            gtk-update-icon-cache -f -t "${d}" >/dev/null 2>&1 || true
        fi
    done
fi

# ---------------------------------------------------------------------------
# 4. Semilla de configuración para el usuario del escritorio
# ---------------------------------------------------------------------------
# El fondo por defecto se aplica desde layout.js; aquí solo dejamos el enlace
# cómodo para el selector de fondos de KDE.
mkdir -p /usr/share/wallpapers/AquaOS
ln -sfn /usr/share/wallpapers/AquaOS/ventura.png /usr/share/wallpapers/AquaOS/contents.png || true

echo "==> AquaOS: listo"
