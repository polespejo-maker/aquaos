# AquaOS

**Una distribución Linux con escritorio estilo macOS.** Base Arch Linux, KDE Plasma 6,
tema propio (fondos, barra superior con menú global, dock flotante, botones de ventana a
la izquierda) y un instalador. Se construye desde cero con un comando.

> Estado: **v0.1** — proyecto funcional y compilable, pendiente de validación en hardware real.
> macOS es una marca de Apple Inc. Este proyecto no está afiliado a Apple y no incluye
> ningún recurso con copyright de Apple: fondos, iconos y marca son propios o libres.

---

## 0. Si vienes de Windows y solo quieres verlo

Sin permisos de administrador, sin instalar nada: **`EMPIEZA-AQUI.txt`** (subir a GitHub,
compilar en la nube y descargar la ISO). Luego, doble clic en `Abrir AquaOS.cmd`.

Con Docker Desktop (requiere admin), en dos dobles clics:

1. `Compilar ISO (Docker).cmd` — compila la ISO una sola vez (20-60 min).
2. `Abrir AquaOS.cmd` — abre AquaOS en una ventana de VirtualBox.

Cierras la ventana y sigues en Windows. Reinicias el PC y arranca Windows. Nada más.

---

## 1. Qué hay aquí

```
aquaos/
├─ EMPIEZA-AQUI.txt              ← camino sin admin: compilar en GitHub
├─ Abrir AquaOS.cmd              ← doble clic: AquaOS en una ventana
├─ Compilar ISO (Docker).cmd     ← doble clic: compila (necesita Docker Desktop)
├─ build.sh                     ← compila la ISO (Arch + archiso)
├─ profile/                     ← perfil archiso + overlay del sistema
│  ├─ profiledef.sh             nombre, etiqueta, compresión, permisos
│  ├─ packages.x86_64           paquetes de la ISO live
│  ├─ packages-desktop.txt      paquetes del sistema instalado (los usa el instalador)
│  ├─ pacman.conf
│  └─ airootfs/                 lo que se copia dentro del sistema
│     ├─ root/customize_airootfs.sh     branding + locales (post-paquetes)
│     ├─ etc/skel/.config/…             configuración KDE por defecto
│     ├─ etc/sddm.conf.d/               login con autologin
│     ├─ usr/local/bin/aquaos-*         firstboot, instalador, info
│     ├─ usr/share/aquaos/plasma/layout.js   barra + dock vía API de Plasma
│     └─ usr/share/wallpapers/AquaOS/   fondos generados
├─ scripts/
│  ├─ make-wallpapers.py        genera los 4 fondos y la marca
│  ├─ fetch-aur-themes.sh       WhiteSur (iconos/cursores/GTK) desde AUR
│  ├─ run-vm.sh                 prueba la ISO en QEMU
│  ├─ build-in-docker.sh        compila en contenedor (Linux)
│  ├─ build-in-docker.ps1       compila en contenedor (Windows + Docker Desktop)
│  ├─ apply-to-current-system.sh  aplica el look a un Arch ya instalado
│  └─ lint.sh                   comprobaciones estáticas
├─ player/                      ← abrir AquaOS en Windows sin tocar el PC
│  ├─ AquaOS.cmd                doble clic: arranca la ISO en VirtualBox
│  ├─ aquaos-player.ps1         crea/gestiona la VM
│  └─ LEEME.txt
├─ docker/Dockerfile
├─ .github/workflows/build-iso.yml   compila la ISO en CI (sin Linux local)
└─ docs/
```

## 2. Por qué no un kernel desde cero

Un "SO desde cero" de verdad (kernel, libc, drivers, compilador, escritorio) son años de
trabajo y no arrancaría en tu PC. Lo que sí da un sistema **propio, instalable y con
identidad** es una distribución: kernel Linux + userland + escritorio configurado al
milímetro + instalador + marca. Eso es lo que hay aquí, y es la decisión que tomó
prácticamente todo el mundo que ha hecho algo parecido.

Decisiones técnicas (detalle en `docs/arquitectura.md`):

| Pieza | Elección | Motivo |
|---|---|---|
| Base | Arch Linux | paquetes al día, `archiso` compila la ISO con un comando, KDE 6 actual |
| Escritorio | KDE Plasma 6 | menú global real, paneles configurables, Wayland maduro, KWin con gestos |
| Disposición | API de scripting de Plasma | aguanta actualizaciones mejor que editar ficheros `rc` a mano |
| Compresión | squashfs + zstd | ISO en ~1/3 del tiempo de xz con tamaño parecido |
| Temas | WhiteSur (AUR, opcional) | es el "look" macOS más completo que existe para Linux |

## 3. Requisitos para compilar

- **Arch Linux** (físico o máquina virtual) con 14 GB libres (10 GB si compilas con
  `--no-offline-repo`) y root.
- Paquetes: `archiso` (arrastra `squashfs-tools`, `libisoburn`, etc.).
- Red (para paquetes y, opcionalmente, AUR).

```bash
sudo pacman -S --needed archiso git base-devel dosfstools mtools
```

> **No se puede compilar en Windows de forma nativa**: `mkarchiso` necesita `mount`, `loop
> devices` y `chroot`. Las tres vías reales están en el punto 4.

## 4. Compilar la ISO (tres caminos)

### A. En Arch (lo más fiable)

```bash
git clone <este-repo> aquaos && cd aquaos
sudo ./build.sh                 # ~20-60 min, ISO en out/
# opciones:
#   --no-aur            sin temas WhiteSur (build más rápido)
#   --no-offline-repo   ISO más pequeña, pero el instalador exigirá internet
#   --clean             borra build/ y out/ antes de compilar
#   --vm                arranca la ISO en QEMU al terminar
```

Resultado: `out/aquaos-0.1.YYYYMMDD-x86_64.iso` + `SHA256SUMS`.

La ISO incluye, por defecto, un **repositorio de paquetes** para poder instalar sin red
(añade ~1,5-2,5 GB a la imagen, que acaba en ~3-4 GB).

### B. En una máquina virtual

1. Descarga la ISO de Arch y arráncala en VirtualBox/VMware/QEMU con 4 GB de RAM y 25 GB de disco.
2. `archinstall` (opción "Instalar Arch") o instala a mano; sirve cualquier Arch con red.
3. Copia el proyecto dentro (carpeta compartida, `scp` o `git clone`) y `sudo ./build.sh`.

### C. Sin Linux local: GitHub Actions

`.github/workflows/build-iso.yml` compila la ISO en un runner de Ubuntu usando el
contenedor oficial de Arch y la sube como *artifact*. Solo hay que subir el repo a GitHub
y lanzar el workflow (`Actions → Build ISO → Run workflow`).

Docker Desktop en Windows (backend WSL2) **puede** servir, pero es la vía frágil: `mkarchiso`
necesita `--privileged` y que el kernel de WSL2 permita `mount --bind` y `chroot` (no usa
loop devices, así que la parte crítica es más sencilla de lo que parece). Está automatizada
en `.\scripts\build-in-docker.ps1` (compila en un volumen, no sobre `C:\`, y deja la ISO en
`out\`). Si falla, usa GitHub Actions (C) o una VM Arch (B). En un Linux con Docker:
`./scripts/build-in-docker.sh`.

## 5. Probarla

### En Windows, sin tocar nada (una ventana)

`Abrir AquaOS.cmd` (en la raíz; por dentro usa `player\aquaos-player.ps1`) crea una máquina
virtual con **VirtualBox** y arranca la ISO dentro.
No modifica el disco, ni el arranque, ni el registro: apagas la ventana y sigues en
Windows; reinicias el PC y arranca Windows. La primera vez tarda un poco en crear la VM
(4 GB de RAM, 4 CPU, disco de 30 GB que crece según se usa). Si la ISO llega troceada
(GitHub Actions), la une y verifica su SHA256 antes de arrancar.

```powershell
Abrir AquaOS.cmd                 # live
Abrir AquaOS.cmd -DesdeDisco     # si instalaste AquaOS dentro de la VM
Abrir AquaOS.cmd -Recrear        # borra la VM y la crea de cero
```

Si quieres instalarlo de verdad, ejecuta `sudo aquaos-install` dentro del live y elige el
disco de 30 GB de la VM: queda instalado **dentro del archivo `.vdi`**, Windows intacto.

### En Linux, con QEMU

```bash
sudo pacman -S --needed qemu-full edk2-ovmf
./scripts/run-vm.sh out/aquaos-*.iso 4096
```

o grábala en un USB (esto **borra** el USB):

```bash
sudo dd if=out/aquaos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Al arrancar: usuario **aqua**, contraseña **aqua**, sudo sin contraseña.
En la sesión live, `Alt+Espacio` abre el buscador (KRunner), `Ctrl+Alt+T` una terminal,
`Alt+F4` cierra la ventana activa y `Meta+L` bloquea la sesión.

## 6. Instalar en el PC

Dentro del sistema live:

```bash
sudo aquaos-install
```

Pregunta el disco (lo **borra entero**), zona horaria, nombre del equipo, contraseña y si
quieres autologin. Crea GPT + ESP 1 GiB + raíz ext4, instala con `pacstrap`, copia la
personalización, configura GRUB y los servicios.

- `--offline` instala usando el repositorio de paquetes incluido en la ISO (sin red).
  Si compilaste con `--no-offline-repo`, esa opción avisará y habrá que usar red.
- `--bios` para equipos sin UEFI.
- `--no-swap` para no crear un swapfile de 2 GB.

## 7. Aplicarlo a un Arch que ya tengas

Sin compilar nada:

```bash
sudo ./scripts/apply-to-current-system.sh
```

Instala los paquetes del escritorio, copia los fondos y la configuración, genera el
usuario/tema y deja el autostart listo. Cierra sesión y vuelve a entrar.

## 8. Qué hace exactamente el escritorio

- **Barra superior** (30 px, translúcida): lanzador con la marca de AquaOS, **menú global**
  de la app activa (applet `org.kde.plasma.appmenu`), bandeja del sistema y reloj.
- **Dock inferior** flotante, centrado y de altura 64 px: Finder (Dolphin), navegador
  (Firefox), correo (Thunderbird), editor (Kate), fotos (Gwenview), música (Elisa), vídeo
  (Haruna), terminal (Konsole), tienda (Discover) y ajustes. Se oculta bajo las ventanas
  (`windowsgobelow`), como el dock de macOS.
- **Botones de ventana a la izquierda** en orden cerrar/minimizar/maximizar (`XIA`).
- **Tipografía** Inter (parecida a SF Pro), mono JetBrains Mono, emoji Noto.
- **Azul de acento** `#0A84FF`, esquema Breeze Light, desenfoque activado.
- **Fondos propios** generados por script (`sonoma`, `ventura`, `sequoia`, `graphite`).

Todo esto se aplica con `layout.js` contra la API de scripting de Plasma, no escribiendo
`plasma-org.kde.plasma.desktop-appletsrc` a mano: si algo falla, se conserva el panel por
defecto y el sistema sigue siendo usable.

## 9. Limitaciones conocidas de la v0.1

- El instalador es propio y **destructivo por diseño**: probarlo primero en una VM.
- Sin cifrado de disco (LUKS) ni btrfs/subvolúmenes todavía (ver `docs/roadmap.md`).
- Sin splash de arranque (Plymouth): el arranque es texto, como en Arch.
- El menú global funciona con apps Qt/KDE; en Firefox no hay menú global (limitación de la app).
- Los temas WhiteSur vienen de AUR y pueden fallar al compilar; en ese caso se usa Breeze.
- Solo x86_64.
- **Secure Boot debe estar desactivado**: la ISO y GRUB no están firmados. Actívalo de
  nuevo (o configura tus propias claves) si lo necesitas.
- **Cuenta root bloqueada**: no tiene contraseña (se entra con `sudo -i`). Si la quieres,
  ejecuta `sudo passwd root`.
- **Drivers NVIDIA propietarios no incluidos**: el ISO arranca con `nouveau`/modo software.
  Tras instalar, `sudo pacman -S nvidia nvidia-utils` (y `nvidia-dkms` si usas otro kernel)
  para el driver oficial.

## 10. Cambiar el nombre, la marca y los colores

- Nombre/etiqueta de la ISO: `profile/profiledef.sh` (`iso_name`, `iso_label`).
- Textos e identidad: `profile/airootfs/root/customize_airootfs.sh` (`/etc/os-release`, `motd`).
- Fondo y paleta: `scripts/make-wallpapers.py` (`PALETTES`) → `python scripts/make-wallpapers.py`.
- Colores/accento y fuentes: `profile/airootfs/etc/skel/.config/kdeglobals`.
- Dock y barra: `profile/airootfs/usr/share/aquaos/plasma/layout.js` (`DOCK_APPS`).

Después de cambiar fondos, vuelve a compilar la ISO (o copia los PNG a
`/usr/share/wallpapers/AquaOS/` en una instalación existente).

## 11. Licencia

Código propio: MIT. Los paquetes instalados conservan su licencia (Arch Linux, KDE, etc.).
No se distribuye ningún recurso de Apple.
