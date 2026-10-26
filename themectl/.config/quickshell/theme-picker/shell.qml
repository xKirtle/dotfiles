// Wallpaper picker for themectl. Toggle: `themectl picker` (or qs -c theme-picker ipc call picker toggle).
// Browses ~/Pictures/Wallpapers like a file manager: folders first (a collage of up to 4 wallpapers),
// then the loose images. Enter (or click) opens a folder or applies a wallpaper, R applies a random
// one from the view, Arrows / hjkl move, Esc goes back / closes. Folders are only groups: every
// wallpaper gets its own dynamic colours (`themectl wall`), and its swatches show what it would make.
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
    property var folders: []        // `themectl list --json --dynamic`; the loose images are the one with root: true
    property var pal: ({})
    property int selected: 0
    property int browseIdx: -1      // folder whose wallpapers are shown (Enter), -1 = top level
    property bool slow: false       // listing is taking a while (new images being analysed): show the spinner

    readonly property string home: Quickshell.env("HOME")
    // Absolute path: the session's PATH (from Hyprland/uwsm) doesn't include ~/.local/bin.
    readonly property string themectl: home + "/.local/bin/themectl"
    readonly property string font: gsf.status === FontLoader.Ready ? gsf.name : "Inter"
    readonly property var folder: browseIdx >= 0 ? folders[browseIdx] ?? null : null

    // What the grid shows: a folder's wallpapers, or the top level (folders, then the loose images).
    // Each item is a wallpaper (file) or a folder (folder = index in folders).
    readonly property var items: folder ? walls(folder)
        // (Qt's JS engine has no Array.flatMap.)
        : folders.map(folderItem).filter(it => !folders[it.folder].root)
            .concat(walls(folders.find(f => f.root) ?? { wallpapers: [] }))
    readonly property int columns: Math.max(1, Math.min(4, items.length))
    readonly property int tileHeight: 196
    // Rows visible before scrolling: one per 432 px of screen height (logical), i.e. 4x4 on the
    // 4K monitors at scale 1.25 (1728 px tall), 7 rows on the portrait one.
    readonly property int rows: Math.max(1, Math.floor((win.screen?.height ?? 1728) / 432))

    function walls(f) {
        return f.wallpapers.map((w, i) => ({
            file: w,
            folder: -1,
            image: f.thumbs?.[i] ?? w,  // themectl's cached thumbnail
            collage: [],
            title: w.slice(w.lastIndexOf("/") + 1).replace(/\.[^.]+$/, ""),
            count: 0,
            swatches: f.wallpaper_swatches?.[i] ?? [],  // the scheme this wallpaper would make
            current: w === f.current_wallpaper
        }));
    }

    function folderItem(f, i) {
        return {
            file: "",
            folder: i,
            image: "",
            collage: (f.thumbs ?? f.wallpapers).slice(0, 4),
            title: f.name,
            count: f.wallpapers.length,
            swatches: [],  // a folder has no one scheme
            current: f.current
        };
    }

    function c(key, fallback) {
        return pal[key] ? "#" + pal[key] : fallback;
    }

    function show() {
        browseIdx = -1;
        folders = [];
        lister.running = true;
        slow = false;
        slowTimer.restart();
        schemeFile.reload();
        open = true;
    }

    function apply(file) {
        applier.command = [root.themectl, "wall", file];
        applier.running = true;
        open = false;
    }

    // Apply a random wallpaper from the open folder, or from all of them at the top level,
    // other than the current one.
    function random() {
        const pool = (folder ? [folder] : folders).reduce((all, f) => all.concat(f.wallpapers), []);
        const current = folders.map(f => f.current_wallpaper).find(w => w);
        const others = pool.filter(w => w !== current);
        const choice = (others.length ? others : pool)[Math.floor(Math.random() * (others.length || pool.length))];
        if (choice) apply(choice);
    }

    // Collage layout for n (1-4) images in a w x h box: rects {x, y, w, h}, 2 px gaps.
    function collageCell(i, n, w, h) {
        const g = 2, hw = (w - g) / 2, hh = (h - g) / 2;
        if (n === 1) return { x: 0, y: 0, w: w, h: h };
        if (n === 2) return { x: i * (hw + g), y: 0, w: hw, h: h };
        if (n === 3) return i === 0 ? { x: 0, y: 0, w: hw, h: h } : { x: hw + g, y: (i - 1) * (hh + g), w: hw, h: hh };
        return { x: (i % 2) * (hw + g), y: Math.floor(i / 2) * (hh + g), w: hw, h: hh };
    }

    // Enter on item i: open a folder (always, even with one wallpaper), or apply a wallpaper.
    function activate(i) {
        const item = items[i];
        if (!item) return;
        if (item.file) {
            apply(item.file);
            return;
        }
        browseIdx = item.folder;
        selected = Math.max(0, folder.wallpapers.indexOf(folder.current_wallpaper));
    }

    function back() {
        if (browseIdx >= 0) {
            const f = browseIdx;
            browseIdx = -1;
            selected = Math.max(0, items.findIndex(it => it.folder === f));
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
        command: [root.themectl, "list", "--json", "--dynamic"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.folders = JSON.parse(text); } catch (e) { root.folders = []; }
                root.selected = Math.max(0, root.items.findIndex(t => t.current));
            }
        }
    }

    Process {
        id: applier
    }

    // A warm listing takes ~0.2 s; only show the spinner past that, so it doesn't flash.
    Timer {
        id: slowTimer
        interval: 250
        onTriggered: root.slow = lister.running
    }

    IpcHandler {
        target: "picker"

        function toggle(): void {
            if (root.open) root.open = false;
            else root.show();
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
                case Qt.Key_R: root.random(); break;
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: root.activate(root.selected); break;
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
                        text: root.folder ? `Wallpapers › ${root.folder.name}` : "Wallpapers"
                        font.family: root.font
                        font.pointSize: 15
                        font.weight: Font.DemiBold
                        color: root.c("onSurface", "#cdd6f4")
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.folder ? "↑↓←→ move · Enter apply wallpaper + its colours · R random · Esc back"
                            : "↑↓←→ move · Enter open folder / apply · R random · Esc close"
                        font.family: root.font
                        font.pointSize: 9
                        color: root.c("onSurfaceVariant", "#a6adc8")
                    }
                }

                ColumnLayout {
                    visible: root.slow && lister.running
                    Layout.preferredWidth: 520
                    Layout.topMargin: 24
                    Layout.bottomMargin: 24
                    spacing: 14

                    Canvas {
                        id: spinner
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 36
                        implicitHeight: 36
                        readonly property color arc: root.c("primary", "#cba6f7")
                        onArcChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.lineWidth = 3.5;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = arc;
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, width / 2 - 3, 0, Math.PI * 1.5);
                            ctx.stroke();
                        }
                        RotationAnimator on rotation {
                            running: spinner.visible
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Preparing new wallpapers…"
                        font.family: root.font
                        font.pointSize: 10.5
                        color: root.c("onSurfaceVariant", "#a6adc8")
                    }
                }

                Text {
                    visible: root.folders.length === 0 && !lister.running
                    Layout.preferredWidth: 520
                    wrapMode: Text.Wrap
                    text: "No wallpapers yet. Put images in ~/Pictures/Wallpapers (subfolders are fine, to group them)."
                    font.family: root.font
                    font.pointSize: 10.5
                    color: root.c("onSurfaceVariant", "#a6adc8")
                }

                // Up to root.rows rows show at once; more scroll (wheel, or follow the keyboard selection).
                Flickable {
                    id: scroller
                    readonly property int pad: 8  // room for the selected tile's 1.03 scale and border
                    readonly property real rowStep: root.tileHeight + grid.rowSpacing
                    visible: root.items.length > 0
                    implicitWidth: grid.implicitWidth + 2 * pad
                    implicitHeight: Math.min(grid.implicitHeight, root.rows * rowStep - grid.rowSpacing) + 2 * pad
                    contentWidth: implicitWidth
                    contentHeight: grid.implicitHeight + 2 * pad
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // Keep the selected row in view.
                    function follow() {
                        const top = Math.floor(root.selected / root.columns) * rowStep;
                        const bottom = top + root.tileHeight + 2 * pad;
                        if (top < contentY) contentY = top;
                        else if (bottom > contentY + height) contentY = bottom - height;
                    }
                    Connections {
                        target: root
                        function onSelectedChanged() { scroller.follow(); }
                        function onItemsChanged() { scroller.contentY = 0; Qt.callLater(scroller.follow); }
                    }

                    GridLayout {
                        id: grid
                        x: scroller.pad
                        y: scroller.pad
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
                                readonly property bool folderTile: modelData.folder >= 0

                                implicitWidth: 280
                                implicitHeight: root.tileHeight
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
                                        id: preview
                                        visible: !tile.folderTile
                                        anchors.fill: parent
                                        source: visible ? "file://" + tile.modelData.image : ""
                                        sourceSize.width: 560
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }

                                    Repeater {
                                        model: tile.modelData.collage
                                        Image {
                                            required property string modelData
                                            required property int index
                                            readonly property var cell: root.collageCell(index, tile.modelData.collage.length,
                                                                                        preview.width, preview.height)
                                            x: cell.x
                                            y: cell.y
                                            width: cell.w
                                            height: cell.h
                                            source: "file://" + modelData
                                            sourceSize.width: 280
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                        }
                                    }

                                    // Wallpaper count badge (folders)
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

                                    Text {
                                        visible: tile.folderTile
                                        text: "folder"  // Material Symbols ligature
                                        font.family: "Material Symbols Rounded"
                                        font.pointSize: 15
                                        color: root.c("primary", "#cba6f7")
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: tile.modelData.title + (tile.modelData.current ? "  ·  current" : "")
                                        font.family: root.font
                                        font.pointSize: 10.5
                                        font.weight: Font.Medium
                                        color: root.c("onSurface", "#cdd6f4")
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
                                    onEntered: root.selected = tile.index
                                    onClicked: root.activate(tile.index)
                                }
                            }
                        }
                    }

                    // Scroll position indicator, only when there's more than fits
                    Rectangle {
                        visible: scroller.contentHeight > scroller.height
                        parent: scroller
                        anchors.right: parent.right
                        width: 4
                        radius: 2
                        y: scroller.visibleArea.yPosition * scroller.height
                        height: scroller.visibleArea.heightRatio * scroller.height
                        color: root.c("outline", "#7f849c")
                        opacity: 0.6
                    }
                }
            }
        }
    }
}
