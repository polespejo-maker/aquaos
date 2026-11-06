# Arquitectura de AquaOS

## 1. Panorama

```
┌──────────────────────────────────────────────────────────────┐
│  Aplicaciones   Dolphin · Firefox · Kate · Konsole · …       │
├──────────────────────────────────────────────────────────────┤
│  Escritorio     KDE Plasma 6 (KWin/Wayland, plasmashell)     │
│                 + layout.js  → barra superior + dock         │
│                 + SDDM (autologin)                           │
├──────────────────────────────────────────────────────────────┤
│  Sesión         PipeWire · WirePlumber · NetworkManager      │
│                 xdg-desktop-portal(-kde) · polkit            │
├──────────────────────────────────────────────────────────────┤
│  Sistema        systemd · glibc · pacman · bash              │
├──────────────────────────────────────────────────────────────┤
│  Kernel         linux (Arch) + firmware · mkinitcpio-archiso │
├──────────────────────────────────────────────────────────────┤
│  Medio          squashfs (zstd) + systemd-boot + syslinux    │
└──────────────────────────────────────────────────────────────┘
```

## 2. Por qué Arch + archiso

- `archiso` convierte un directorio (`profile/`) en una ISO híbrida BIOS/UEFI con un
  comando. No hay que escribir arranque, initramfs ni xorriso a mano.
- Rolling release: KDE 6 y Wayland recientes, que es donde están los gestos y el pulido.
- AUR disponible para los temas que dan el acabado macOS.
- Contrapartida: hay que compilar en Arch (o su contenedor). Documentado en el README.

## 3. Cómo se construye (build.sh)

1. **Copia** `/usr/share/archiso/configs/releng` en `build/profile` (heredamos todo el
   arranque probado de Arch) y **superpone** `profile/`.
2. **Inyecta** `packages-desktop.txt` y el README en `/usr/share/aquaos/` del sistema.
3. **Crea enlaces** de systemd (`aquaos-firstboot`, SDDM, NetworkManager, bluetooth,
   `fstrim.timer`, `display-manager.service`) y **quita** los que no aplican del perfil
   releng (networkd, iwd, sshd, ModemManager, cloud-init…).
4. **Integra AUR** (opcional): `fetch-aur-themes.sh` compila con `makepkg` bajo un usuario
   `builder` y **extrae el contenido** del paquete en el `airootfs`. Son paquetes de datos
   (iconos, cursores, temas GTK), así que no hace falta repositorio dentro de la ISO.
5. **Crea el repositorio offline** (opcional, activo por defecto): descarga con `pacman -Sw`
   la lista `packages-desktop.txt` **y todas sus dependencias** en
   `/usr/share/aquaos/repo` y genera la base de datos con `repo-add`. Así
   `aquaos-install --offline` instala sin red desde la propia ISO.
6. **`mkarchiso`** hace el resto: copia el overlay, ejecuta `pacstrap`, corre
   `customize_airootfs.sh` (branding + locales), comprime squashfs y genera la ISO.

Detalle importante de archiso 92: el overlay se copia **antes** de `pacstrap`. Por eso los
archivos que pertenecen a paquetes (`/etc/os-release`, `/etc/locale.conf`, `/etc/locale.gen`)
se escriben en `customize_airootfs.sh`, que corre **después**. Los que no pertenecen a
ningún paquete (skel, wallpapers, `/usr/local/bin`, unidades propias) van en el overlay.

## 4. Arranque de la sesión live

```
firmware → systemd-boot/syslinux → initramfs (mkinitcpio-archiso)
        → systemd (multi-user) → aquaos-firstboot (oneshot, antes del login)
        → SDDM (autologin) → Plasma (Wayland)
        → autostart: aquaos-desktop-setup → gdbus evaluateScript(layout.js)
```

- `aquaos-firstboot` crea el usuario `aqua`, detecta qué tema hay instalado
  (WhiteSur vs Breeze) y escribe `kdeglobals`/`kwinrc`/GTK **antes** de que arranque el
  login, para que la primera sesión ya salga con el aspecto correcto.
- El teclado se configura en español en consola (`vconsole.conf`), X11
  (`/etc/X11/xorg.conf.d/00-keyboard.conf`) y Plasma (`kxkbrc` del esqueleto de usuario).
  El trackpad queda con scroll natural y toque para hacer clic.
- `aquaos-desktop-setup` espera a que `plasmashell` publique `org.kde.plasmashell` y le
  pasa `layout.js`. Si Plasma cambia su API, el script falla de forma controlada y el
  escritorio conserva su panel por defecto.

## 5. El diseño del escritorio

`layout.js` usa la API de scripting de Plasma (`org.kde.PlasmaShell.evaluateScript`):

1. Guarda los IDs de los paneles actuales.
2. Crea dos paneles (`new Panel("org.kde.panel")`, con *fallback* a `new Panel()`).
3. Barra superior: `kickoff` (marca propia, imagen PNG), `appmenu` (menú global),
   `panelspacer`, `systemtray`, `digitalclock`.
4. Dock: `icontasks` con la lista de apps ancladas, panel flotante, centrado,
   `hiding = "windowsgobelow"` (las ventanas pasan por encima).
5. Solo si los dos paneles se crearon bien, elimina los antiguos.
6. Aplica el fondo con el plugin `org.kde.image`.

Los nombres de applets y propiedades están verificados contra el código de
`plasma-workspace/shell/scripting` (Panel, Containment). No se escribe
`plasma-org.kde.plasma.desktop-appletsrc` a mano a propósito: ese fichero cambia entre
versiones y un error deja el escritorio roto.

## 6. Instalador

`aquaos-install` (bash, sin dependencias raras):

| Fase | Herramientas |
|---|---|
| Discos | `lsblk`, `sgdisk`, `partprobe`, `udevadm` |
| Formato | `mkfs.fat`, `mkfs.ext4` |
| Paquetes | `pacstrap` (red) o repositorio `file:///usr/share/aquaos/repo` incluido en la ISO |
| Keyring | se copia el del live; `pacman-key --populate archlinux` (idempotente) en el chroot |
| Sistema | `genfstab`, `arch-chroot`, `locale-gen`, `mkinitcpio -P`, `hwclock` |
| Arranque | `grub-install` + `grub-mkconfig` (UEFI o BIOS) |
| Personalización | copia de `/usr/share/aquaos`, skel, temas, config de SDDM |

La caché de pacman se redirige al disco destino durante la instalación y se borra al
terminar; el repositorio offline de la ISO **no** se copia al sistema instalado (solo se
usa en el medio de instalación).

Diseño destructivo y explícito: hay que escribir `BORRAR` para continuar y se rechaza el
disco del que se está arrancando.

## 7. Empaquetado del "look"

- Fondos: `scripts/make-wallpapers.py` (numpy + Pillow) genera mallas de gradiente con
  manchas difuminadas, grano y viñeteado. Nada de material de Apple.
- Marca: gota/ola generada por el mismo script (`branding/menu-icon.png`).
- Iconos/cursores/GTK: WhiteSur desde AUR, opcional y con degradación a Breeze.
- Tipografía: Inter (extra/inter-font) como sustituto libre de SF Pro.

## 8. Riesgos conocidos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| La API de scripting de Plasma cambia | `try/catch` por paso; si falla, se conserva el panel por defecto |
| Un paquete de AUR no compila | El build sigue sin temas; `firstboot` elige Breeze |
| `mkarchiso` cambia de interfaz | Partimos del perfil `releng` instalado, no de una copia congelada |
| El instalador rompe un disco | Confirmación explícita, rechazo del disco live, log en `/var/log` |
| `customize_airootfs.sh` desaparece | Es lo único que depende de esa función; el resto es declarativo |
| GPU NVIDIA propietaria no soportada de serie | El ISO usa `nouveau`/software; el driver oficial se instala después |

## 9. Limitaciones de la v0.1

- Instalador destructivo, sin LUKS ni btrfs/subvolúmenes.
- Sin Plymouth (arranque en texto).
- Menú global solo para apps Qt/KDE.
- Sin drivers NVIDIA propietarios en el ISO; root sin contraseña (se usa `sudo -i`).
- Secure Boot debe estar desactivado (ISO y GRUB sin firmar).
- Solo x86_64 y pendiente de validación en hardware real.
