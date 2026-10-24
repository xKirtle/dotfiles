// Theme and wallpaper pickers for themectl. Toggle: `themectl picker themes|wallpapers`
// (or qs -c theme-picker ipc call picker toggle <mode>).
// Themes: Enter (or click) shows the theme's wallpapers to choose from (one-wallpaper themes apply
// directly); Shift+Enter (or Shift/right-click) applies it with its first wallpaper.
// Wallpapers: the current theme's wallpapers; Enter applies. Arrows / hjkl move, Esc closes.
// Colours follow Caelestia's current scheme (~/.local/state/caelestia/scheme.json).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool open: false
    property var themes: []
    property var pal: ({})
    property int selected: 0
    property string mode: "themes"  // or "wallpapers"
    property int browseIdx: -1      // themes mode: theme whose wallpapers are shown (Enter)

    readonly property string home: Quickshell.env("HOME")
    // Absolute path: the session's PATH (from Hyprland/uwsm) doesn't include ~/.local/bin.
    readonly property string themectl: home + "/.local/bin/themectl"
    readonly property string font: gsf.status === FontLoader.Ready ? gsf.name : "Inter"
    // Wallpapers mode browses the current theme (or the first one if none is set yet).
    readonly property var theme: browseIdx >= 0 ? themes[browseIdx] ?? null
        : mode === "wallpapers" ? (themes.find(t => t.current) ?? themes[0] ?? null) : null

    // What the grid shows, in either mode.
    readonly property var items: theme
        ? theme.wallpapers.map(w => ({
            image: w,
            title: w.slice(w.lastIndexOf("/") + 1).replace(/\.[^.]+$/, ""),
            subtitle: "",
            count: 0,
            swatches: [],
            current: w === theme.current_wallpaper
        }))
        : themes.map(t => ({
            image: t.current_wallpaper || t.wallpapers[0],
            title: t.name,
            subtitle: t.scheme === "dynamic" ? "colours from wallpaper" : [t.scheme, t.flavour].filter(x => x).join(" "),
            count: t.wallpapers.length,
            swatches: t.swatches,
            current: t.current
        }))
    readonly property int columns: Math.max(1, Math.min(4, items.length))

    function c(key, fallback) {
        return pal[key] ? "#" + pal[key] : fallback;
    }

    function show(m) {
        mode = m === "wallpapers" ? "wallpapers" : "themes";
        browseIdx = -1;
        themes = [];
        lister.running = true;
        schemeFile.reload();
        open = true;
    }

    function activate(i) {
        let args;
        if (theme)
            args = [theme.name, theme.wallpapers[i]];
        else if (themes[i])
            args = [themes[i].name];
        else
            return;
        applier.command = [root.themectl, "set"].concat(args);
        applier.running = true;
        open = false;
    }

    // Themes mode: show theme i's wallpapers (picking one applies the theme with it).
    function browse(i) {
        if (mode !== "themes" || browseIdx >= 0 || !themes[i]) return;
        if (themes[i].wallpapers.length === 1) {
            activate(i);  // nothing to choose
            return;
        }
        browseIdx = i;
        selected = Math.max(0, theme.wallpapers.indexOf(theme.current_wallpaper));
    }

    function back() {
        if (browseIdx >= 0) {
            selected = browseIdx;
            browseIdx = -1;
        } else {
            open = false;
        }
    }

    function move(dx, dy) {
        const n = selected + dx + dy * columns;
        if (n >= 0 && n < items.length) selected = n;
    }

    FontLoader {
        id: gsf
        source: "file:///etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
    }

    FileView {
        id: schemeFile
        path: root.home + "/.local/state/caelestia/scheme.json"
        onLoaded: {
            try { root.pal = JSON.parse(text()).colours; } catch (e) {}
        }
    }

    Process {
        id: lister
        command: [root.themectl, "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.themes = JSON.parse(text); } catch (e) { root.themes = []; }
                root.selected = Math.max(0, root.items.findIndex(t => t.current));
            }
        }
    }

    Process {
        id: applier
    }

    IpcHandler {
        target: "picker"

        function toggle(mode: string): void {
            if (root.open && root.mode === mode) root.open = false;
            else root.show(mode);
        }

        function close(): void {
            root.open = false;
        }
    }

    PanelWindow {
        id: win

        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        color: "#73000000"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "theme-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusiveZone: -1  // cover the whole monitor, bar included

        anchors.left: true
        anchors.right: true
        anchors.top: true
        anchors.bottom: true

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: body.implicitWidth + 48
            height: body.implicitHeight + 48
            radius: 24
            color: root.c("surfaceContainer", "#1e1e2e")
            border.color: root.c("outlineVariant", "#45475a")
            border.width: 1

            focus: true
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape: case Qt.Key_Backspace: root.back(); break;
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                    if (!(event.modifiers & Qt.ShiftModifier) && root.mode === "themes" && root.browseIdx < 0)
                        root.browse(root.selected);
                    else
                        root.activate(root.selected);
                    break;
                case Qt.Key_Left: case Qt.Key_H: root.move(-1, 0); break;
                case Qt.Key_Right: case Qt.Key_L: root.move(1, 0); break;
                case Qt.Key_Up: case Qt.Key_K: root.move(0, -1); break;
                case Qt.Key_Down: case Qt.Key_J: root.move(0, 1); break;
                default: return;
                }
                event.accepted = true;
            }

            MouseArea {
                anchors.fill: parent  // swallow clicks so they don't close the picker
            }

            ColumnLayout {
                id: body
                anchors.centerIn: parent
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: root.browseIdx >= 0 ? `Themes › ${root.theme.name}`
                            : root.theme ? `Wallpapers · ${root.theme.name}` : "Themes"
                        font.family: root.font
                        font.pointSize: 15
                        font.weight: Font.DemiBold
                        color: root.c("onSurface", "#cdd6f4")
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.browseIdx >= 0 ? "↑↓←→ move · Enter apply theme + wallpaper · Esc back"
                            : root.theme ? "↑↓←→ move · Enter apply · Esc close"
                            : "↑↓←→ move · Enter choose wallpaper · Shift+Enter first wallpaper · Esc close"
                        font.family: root.font
                        font.pointSize: 9
                        color: root.c("onSurfaceVariant", "#a6adc8")
                    }
                }

                Text {
                    visible: root.themes.length === 0
                    Layout.preferredWidth: 520
                    wrapMode: Text.Wrap
                    text: "No wallpapers yet. Put images in ~/Pictures/Wallpapers, or a folder per theme named after a "
                        + "Caelestia scheme (e.g. catppuccin-mocha, gruvbox-hard, rosepine-moon). Any other name "
                        + "gets colours generated from the wallpaper."
                    font.family: root.font
                    font.pointSize: 10.5
                    color: root.c("onSurfaceVariant", "#a6adc8")
                }

                GridLayout {
                    visible: root.items.length > 0
                    columns: root.columns
                    columnSpacing: 16
                    rowSpacing: 16

                    Repeater {
                        model: root.items

                        Rectangle {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool sel: root.selected === index

                            implicitWidth: 280
                            implicitHeight: modelData.subtitle ? 210 : 196
                            radius: 16
                            color: root.c("surfaceContainerHigh", "#313244")
                            border.width: sel ? 3 : modelData.current ? 2 : 0
                            border.color: sel ? root.c("primary", "#cba6f7") : root.c("outline", "#7f849c")
                            scale: sel ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            Item {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                height: 148
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + tile.modelData.image
                                    sourceSize.width: 560
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                }

                                // Wallpaper count badge (themes view)
                                Rectangle {
                                    visible: tile.modelData.count > 0
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    implicitWidth: countText.implicitWidth + 18
                                    implicitHeight: countText.implicitHeight + 8
                                    radius: height / 2
                                    color: "#d9" + (root.pal.surfaceContainer ?? "1e1e2e")  // #AARRGGBB, 85% opaque

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: `${tile.modelData.count} wallpaper${tile.modelData.count === 1 ? "" : "s"}`
                                        font.family: root.font
                                        font.pointSize: 8.5
                                        font.weight: Font.Medium
                                        color: root.c("onSurface", "#cdd6f4")
                                    }
                                }
                            }

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 14
                                spacing: 6

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: tile.modelData.title + (tile.modelData.current ? "  ·  current" : "")
                                        font.family: root.font
                                        font.pointSize: 10.5
                                        font.weight: Font.Medium
                                        color: root.c("onSurface", "#cdd6f4")
                                    }
                                    Text {
                                        visible: !!tile.modelData.subtitle
                                        text: tile.modelData.subtitle
                                        font.family: root.font
                                        font.pointSize: 8
                                        color: root.c("onSurfaceVariant", "#a6adc8")
                                    }
                                }
                                Repeater {
                                    model: tile.modelData.swatches
                                    Rectangle {
                                        required property string modelData
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        radius: 7
                                        color: modelData
                                        border.color: root.c("outlineVariant", "#45475a")
                                        border.width: 1
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onEntered: root.selected = tile.index
                                onClicked: mouse => {
                                    const first = mouse.button === Qt.RightButton || (mouse.modifiers & Qt.ShiftModifier);
                                    if (!first && root.mode === "themes" && root.browseIdx < 0) root.browse(tile.index);
                                    else root.activate(tile.index);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
