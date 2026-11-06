# Roadmap

## v0.2 — robustez

- [ ] Probar el build completo en Arch real y corregir lo que salga (primer `mkarchiso`).
- [ ] Validar `layout.js` en Plasma 6.8 (IDs de applets, `appmenu`, `icontasks`).
- [ ] Calamares o instalador con soporte de cifrado LUKS.
- [ ] Btrfs con subvolúmenes y snapshots (snapper) como opción del instalador.
- [ ] Manejo de errores del instalador con `--dry-run`.

## v0.3 — acabado macOS

- [ ] Plymouth con logo propio y barra de progreso (splash de arranque).
- [ ] Tema de SDDM propio (fondo desenfocado + avatar redondo).
- [ ] `kwin-effect-rounded-corners` + sombras suaves tipo macOS.
- [ ] Animaciones de ventanas y "Mission Control" con atajos tipo macOS
      (`Meta+↑` = vista de actividades ya funciona en Plasma 6).
- [ ] Atajos globales estilo macOS (Cmd+Q/Cmd+W/Cmd+Espacio) en `kglobalshortcutsrc`.
- [ ] Sonidos de interfaz libres.
- [ ] Modo oscuro/claro conmutables desde la barra (widget de "centro de control").

## v0.4 — producto

- [ ] Repositorio propio de paquetes (`[aquaos]`) firmado, en vez de copiar archivos.
- [ ] Actualizaciones del sistema desde Discover sin contraseña.
- [ ] Asistente de bienvenida (primer arranque instalado): idioma, tema, cuentas.
- [ ] Soporte de hardware NVIDIA (paquetes opcionales, no en la ISO).
- [ ] ISO reducida (~1.5 GB) con lista de paquetes mínima + instalación bajo demanda.
- [ ] Firma de la ISO (`gpg`) y comprobación en el arranque.

## Ideas descartadas (y por qué)

- **Kernel propio**: años de trabajo, cero drivers, no arranca en hardware real.
- **Latte Dock**: abandonado y sin soporte para Plasma 6; el dock nativo cubre el caso.
- **Pantheon (elementary)**: look muy cuidado, pero menos configurable y con menos apps.
- **GNOME + extensiones**: el menú global depende de extensiones de terceros que se rompen
  con cada versión; KDE lo trae de serie.
- **Tema copiado de macOS**: problemas legales; se generan fondos y marca propios.
