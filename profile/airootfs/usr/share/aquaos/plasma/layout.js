/*
 * ============================================================================
 *  AquaOS · disposición del escritorio estilo macOS
 *
 *  Se ejecuta una sola vez (primer inicio de sesión) mediante
 *  `aquaos-desktop-setup` contra la API de scripting de Plasma:
 *
 *     gdbus call --session --dest org.kde.plasmashell \
 *       --object-path /PlasmaShell \
 *       --method org.kde.PlasmaShell.evaluateScript "<este archivo>"
 *
 *  Idea: barra superior (menú global + reloj + bandeja) y dock inferior
 *  flotante y centrado. Nada de esto toca archivos de configuración a mano:
 *  usamos la API pública, que es la que mejor aguanta actualizaciones.
 * ============================================================================
 */

/* global Panel, panels, panelById, desktops, print */

(function () {
    "use strict";

    var WALLPAPER = "file:///usr/share/wallpapers/AquaOS/ventura.png";

    // Aplicaciones ancladas al dock, en orden (equivalente al dock de macOS).
    var DOCK_APPS = [
        "applications:org.kde.dolphin.desktop",        // Finder
        "applications:firefox.desktop",                // Safari
        "applications:thunderbird.desktop",            // Mail
        "applications:org.kde.kate.desktop",           // TextEdit
        "applications:org.kde.gwenview.desktop",       // Fotos
        "applications:org.kde.elisa.desktop",          // Música
        "applications:org.kde.haruna.desktop",         // Reproductor de vídeo
        "applications:org.kde.konsole.desktop",        // Terminal
        "applications:org.kde.discover.desktop",       // App Store
        "applications:systemsettings.desktop"          // Ajustes del Sistema
    ];

    function log(text) {
        print("AquaOS: " + text);
    }

    /** Escribe claves de configuración de un widget sin romper el script. */
    function configure(widget, group, values) {
        if (!widget) {
            return;
        }
        try {
            widget.currentConfigGroup = group;
            for (var key in values) {
                if (Object.prototype.hasOwnProperty.call(values, key)) {
                    widget.writeConfig(key, values[key]);
                }
            }
        } catch (e) {
            log("no se pudo configurar el widget: " + e);
        }
    }

    /**
     * Crea un panel. Plasma 6 prefiere `new Panel(<plantilla>)`, pero también
     * acepta el constructor sin argumentos de Plasma 5. Probamos ambos.
     */
    function createPanel(edge, thickness) {
        var panel = null;

        try {
            panel = new Panel("org.kde.panel");
        } catch (e) {
            log("new Panel(plugin) falló: " + e);
        }
        if (!panel) {
            try {
                panel = new Panel();
            } catch (e) {
                log("new Panel() falló: " + e);
                return null;
            }
        }

        try {
            panel.location = edge;
            panel.height = thickness;
            panel.opacity = "adaptive";
        } catch (e) {
            log("panel no utilizable: " + e);
            return null;
        }
        return panel;
    }

    function currentPanelIds() {
        var ids = [];
        try {
            var list = panels();
            for (var i = 0; i < list.length; i++) {
                ids.push(list[i].id);
            }
        } catch (e) {
            log("panels() no disponible: " + e);
        }
        return ids;
    }

    function buildTopBar() {
        var bar = createPanel("top", 30);
        if (!bar) {
            return null;
        }

        try {
            bar.alignment = "left";
            bar.lengthMode = "fill";
            bar.floating = false;
            bar.hiding = "none";
        } catch (e) {
            log("ajustes de la barra: " + e);
        }

        // Menú de aplicaciones (el "logo" de la esquina izquierda)
        var launcher = bar.addWidget("org.kde.plasma.kickoff");
        configure(launcher, ["General"], {
            useCustomButtonImage: true,
            customButtonImage: "file:///usr/share/aquaos/branding/menu-icon.png"
        });

        // Menús de la app activa, como la barra de menús de macOS
        bar.addWidget("org.kde.plasma.appmenu");

        // Empuja el resto de widgets a la derecha
        bar.addWidget("org.kde.plasma.panelspacer");

        bar.addWidget("org.kde.plasma.systemtray");

        var clock = bar.addWidget("org.kde.plasma.digitalclock");
        configure(clock, ["Appearance"], {
            showDate: true
        });

        return bar;
    }

    function buildDock() {
        var dock = createPanel("bottom", 64);
        if (!dock) {
            return null;
        }

        try {
            dock.alignment = "center";
            dock.lengthMode = "fit";
            dock.floating = true;
            dock.hiding = "windowsgobelow";
        } catch (e) {
            log("ajustes del dock: " + e);
        }

        var tasks = dock.addWidget("org.kde.plasma.icontasks");
        configure(tasks, ["General"], {
            launchers: DOCK_APPS.join(","),
            showOnlyMinimized: false,
            separateLaunchers: false,
            maxStripes: 1,
            indicatorsEnabled: true,
            showToolTips: true
        });

        return dock;
    }

    function applyWallpaper(url) {
        var screens;
        try {
            screens = desktops();
        } catch (e) {
            log("desktops() no disponible: " + e);
            return;
        }
        for (var i = 0; i < screens.length; i++) {
            try {
                screens[i].wallpaperPlugin = "org.kde.image";
                screens[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
                screens[i].writeConfig("Image", url);
                screens[i].writeConfig("FillMode", 2);
            } catch (e) {
                log("fondo de pantalla: " + e);
            }
        }
    }

    // ------------------------------------------------------------------------
    //  Construcción
    // ------------------------------------------------------------------------
    var previous = currentPanelIds();

    var topBar = buildTopBar();
    var dock = buildDock();

    if (!topBar || !dock) {
        log("no se pudo crear el diseño; se conserva el escritorio por defecto");
        try { if (topBar) { topBar.remove(); } } catch (e) { /* nada */ }
        try { if (dock) { dock.remove(); } } catch (e) { /* nada */ }
        return;
    }

    // Solo ahora quitamos los paneles que había antes (el panel por defecto).
    for (var i = 0; i < previous.length; i++) {
        try {
            panelById(previous[i]).remove();
        } catch (e) {
            log("no se pudo quitar el panel " + previous[i] + ": " + e);
        }
    }

    applyWallpaper(WALLPAPER);
    log("escritorio configurado");
}());
