// Keybind cheat sheet: searchable list of the live Hyprland binds (`hyprctl binds -j`, read on open).
// Toggle: Super+K (qs-panel keybinds keybinds, or qs -c keybinds ipc call keybinds toggle).
// Text comes from each bind's description, set where it's bound: hl.bind(key, action, { description =
// "Group: what it does" }); the "Group:" prefix sorts it into a section. Binds with the same description
// and modifiers share a row (Super + 1 / 2 / …). A bind without one is listed under "Undocumented".
// Type to search by description or by key: words match anywhere ("screenshot", "super f"), and a
// query with "+" matches the combo itself ("super+shift+v"). Rows whose keys are exactly the typed
// words come first. ↑/↓/PgUp/PgDn scroll, Esc = clear the search, then close.
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
    property var binds: []    // {section, action, mods, keys, raw, combo, chips}
    property var pal: ({})
    property string query: ""

    readonly property string home: Quickshell.env("HOME")
    readonly property string font: gsf.status === FontLoader.Ready ? gsf.name : "Inter"
    readonly property var shown: filter(binds, query)

    // Section order; groups not listed here follow alphabetically, then "Undocumented"
    readonly property var order: ["Apps", "Shell", "Panels", "Windows", "Workspaces", "Screenshots", "Clipboard", "Audio", "Media", "System"]
    // How keys are shown; others are capitalised as Hyprland names them
    readonly property var keyNames: ({
        mouse_down: "Scroll down", mouse_up: "Scroll up", "mouse:272": "Left drag", "mouse:273": "Right drag",
        grave: "`", period: ".", comma: ",", bracketleft: "[", bracketright: "]", minus: "-", equal: "=",
        slash: "/", semicolon: ";", apostrophe: "'", Return: "Enter", Escape: "Esc",
        XF86AudioRaiseVolume: "Volume Up", XF86AudioLowerVolume: "Volume Down", XF86AudioMute: "Mute",
        XF86AudioMicMute: "Mic Mute", XF86AudioPlay: "Play", XF86AudioPause: "Pause", XF86AudioNext: "Next",
        XF86AudioPrev: "Prev", XF86MonBrightnessUp: "Brightness Up", XF86MonBrightnessDown: "Brightness Down"
    })
    // Typed names for keys
    readonly property var aliases: ({ win: "super", mod: "super", cmd: "super", control: "ctrl",
                                     return: "enter", escape: "esc", backtick: "`", tilde: "`" })

    function c(key, fallback) {
        return pal[key] ? "#" + pal[key] : fallback;
    }

    function show() {
        query = "";
        lister.running = true;
        open = true;
    }

    function mods(mask) {
        return [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]].filter(m => mask & m[0]).map(m => m[1]);
    }

    function keyName(k) {
        return keyNames[k] ?? (k.length === 1 ? k.toUpperCase() : k[0].toUpperCase() + k.slice(1));
    }

    // hyprctl binds -j → rows: one per (description, modifiers), keys merged, grouped by "Group:" prefix
    function build(list) {
        const rows = [], byId = {};
        for (const b of list) {
            // Skip pass-through listeners, e.g. Caelestia's runtime Caps_Lock/Num_Lock binds (lock-key indicator)
            if (b.submap || (b.non_consuming && !b.description)) continue;
            const desc = b.description;
            const m = desc.match(/^([A-Z][A-Za-z ]{0,20}): (.+)$/);
            const section = !desc ? "Undocumented" : m ? m[1] : "Other";
            const action = !desc ? "no description: add one where it's bound" : m ? m[2] : desc;
            const id = desc ? `${b.modmask}|${desc}` : `${b.modmask}|${b.key}`;
            if (!byId[id]) {
                byId[id] = { section: section, action: action, mods: mods(b.modmask), keys: [],
                             raw: [] };
                rows.push(byId[id]);
            }
            byId[id].keys.push(keyName(b.key));
            byId[id].raw.push(b.key);
        }
        const rank = s => s === "Undocumented" ? 1000 : order.indexOf(s) >= 0 ? order.indexOf(s) : 100;
        for (const r of rows) {
            // Workspace digits in keyboard order: 1…9, 0
            r.keys.sort((a, b) => (/^\d$/.test(a) && /^\d$/.test(b)) ? (+a || 10) - (+b || 10) : 0);
            r.combo = r.mods.concat([r.keys.join(" / ")]).join(" + ");
            r.chips = r.mods.concat(r.keys).map(k => k.toLowerCase());
        }
        // Binds keep Hyprland's order within a section (index tiebreak: Qt's Array.sort isn't stable)
        rows.forEach((r, i) => r.index = i);
        return rows.sort((a, b) => rank(a.section) - rank(b.section)
                                || (rank(a.section) === 100 ? a.section.localeCompare(b.section) : 0)
                                || a.index - b.index);
    }

    function filter(list, q) {
        q = q.trim().toLowerCase();
        if (!q) return list;
        if (q.includes("+")) {
            // Combo search: every typed key is one of the row's modifiers or keys, in any order;
            // rows with exactly the typed modifiers first (super+v: Super + V before Super + Shift + V)
            const keys = q.split(/\s*\+\s*/).filter(k => k).map(k => aliases[k] ?? k);
            const combos = list.filter(b => keys.every(k => b.chips.includes(k)));
            const sameMods = b => b.mods.every(m => keys.includes(m.toLowerCase()));
            return combos.filter(sameMods).concat(combos.filter(b => !sameMods(b)));
        }
        const words = q.split(/\s+/).map(w => aliases[w] ?? w);
        const hits = list.filter(b => {
            const text = `${b.combo} ${b.raw.join(" ")} ${b.action} ${b.section}`.toLowerCase();
            return words.every(w => text.includes(w));
        });
        // Exact key matches first ("f" → Super + F before every action containing an f)
        const exact = b => words.every(w => b.chips.includes(w));
        return hits.filter(exact).concat(hits.filter(b => !exact(b)));
    }

    function scroll(dy) {
        flick.contentY = Math.max(0, Math.min(flick.contentY + dy, flick.contentHeight - flick.height));
    }

    FontLoader {
        id: gsf
        source: "file:///etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
    }

    FileView {
        path: root.home + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.pal = JSON.parse(text()).colours; } catch (e) {}
        }
    }

    Process {
        id: lister
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.binds = root.build(JSON.parse(text)); } catch (e) { root.binds = []; }
            }
        }
    }

    IpcHandler {
        target: "keybinds"

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
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "keybinds"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusiveZone: 0

        // No anchors: centred on the monitor
        implicitWidth: 760
        implicitHeight: Math.min(header.implicitHeight + listBox.implicitHeight + footer.implicitHeight + 40 + 28,
                                 Math.round((screen ? screen.height : 1080) * 0.75))

        onVisibleChanged: if (visible) { flick.contentY = 0; search.forceActiveFocus(); }

        HyprlandFocusGrab {
            windows: [win]
            active: win.visible
            onCleared: root.open = false
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: root.c("surfaceContainer", "#1e1e2e")
            border.color: root.c("outlineVariant", "#45475a")
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                ColumnLayout {
                    id: header
                    Layout.fillWidth: true
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "keyboard"  // Material Symbols ligature
                            font.family: "Material Symbols Rounded"
                            font.pointSize: 15
                            color: root.c("primary", "#cba6f7")
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Keybinds"
                            font.family: root.font
                            font.pointSize: 13
                            font.weight: Font.DemiBold
                            color: root.c("onSurface", "#cdd6f4")
                        }
                        Text {
                            text: root.query ? `${root.shown.length} of ${root.binds.length}` : `${root.binds.length} binds`
                            font.family: root.font
                            font.pointSize: 9
                            color: root.c("onSurfaceVariant", "#a6adc8")
                        }
                    }

                    // Search
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: search.implicitHeight + 18
                        radius: 12
                        color: root.c("surfaceContainerHigh", "#2a2a3c")

                        TextInput {
                            id: search
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            focus: true
                            text: root.query
                            onTextChanged: { root.query = text; flick.contentY = 0; }
                            font.family: root.font
                            font.pointSize: 10
                            color: root.c("onSurface", "#cdd6f4")
                            selectionColor: root.c("primary", "#cba6f7")
                            selectedTextColor: root.c("onPrimary", "#1e1e2e")
                            clip: true

                            Text {
                                visible: !search.text
                                text: "Search by description or key (screenshot, super+shift+v)"
                                font: search.font
                                color: root.c("outline", "#7f849c")
                            }

                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    if (search.text) search.text = "";
                                    else root.open = false;
                                    break;
                                case Qt.Key_Down: root.scroll(60); break;
                                case Qt.Key_Up: root.scroll(-60); break;
                                case Qt.Key_PageDown: root.scroll(flick.height - 60); break;
                                case Qt.Key_PageUp: root.scroll(-(flick.height - 60)); break;
                                default: return;
                                }
                                event.accepted = true;
                            }
                        }
                    }
                }

                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: listBox.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: listBox
                        width: parent.width
                        spacing: 2

                        Text {
                            visible: root.shown.length === 0
                            text: root.binds.length ? "No match" : lister.running ? "Loading…" : "Couldn't read hyprctl binds -j"
                            font.family: root.font
                            font.pointSize: 9
                            color: root.c("outline", "#7f849c")
                        }

                        Repeater {
                            model: root.shown

                            ColumnLayout {
                                id: entry
                                required property var modelData
                                required property int index
                                // Section headings only in the unfiltered list (search results are ranked)
                                readonly property bool firstOfSection: !root.query
                                    && (index === 0 || root.shown[index - 1].section !== modelData.section)
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    visible: entry.firstOfSection
                                    topPadding: entry.index === 0 ? 0 : 12
                                    bottomPadding: 2
                                    text: entry.modelData.section
                                    font.family: root.font
                                    font.pointSize: 8.5
                                    font.weight: Font.DemiBold
                                    color: root.c("primary", "#cba6f7")
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: line.implicitHeight + 12
                                    radius: 10
                                    color: hover.hovered ? root.c("surfaceContainerHigh", "#2a2a3c") : "transparent"

                                    HoverHandler { id: hover }

                                    RowLayout {
                                        id: line
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 14

                                        // Keycaps, with the +, / and , between them as plain text
                                        Flow {
                                            Layout.preferredWidth: 250
                                            Layout.alignment: Qt.AlignTop
                                            spacing: 4

                                            Repeater {
                                                model: entry.modelData.combo.split(/(\s+[+\/]\s+)/).filter(p => p)

                                                Item {
                                                    id: part
                                                    required property string modelData
                                                    readonly property bool sep: /^\s+[+\/]\s+$/.test(modelData)
                                                    implicitWidth: sep ? sepText.implicitWidth : cap.implicitWidth
                                                    implicitHeight: cap.implicitHeight

                                                    Text {
                                                        id: sepText
                                                        visible: part.sep
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: part.modelData.trim()
                                                        font.family: root.font
                                                        font.pointSize: 8.5
                                                        color: root.c("outline", "#7f849c")
                                                    }
                                                    Rectangle {
                                                        id: cap
                                                        visible: !part.sep
                                                        implicitWidth: capText.implicitWidth + 14
                                                        implicitHeight: capText.implicitHeight + 6
                                                        radius: 6
                                                        color: root.c("surfaceContainerHighest", "#313244")
                                                        border.color: root.c("outlineVariant", "#45475a")
                                                        border.width: 1
                                                        Text {
                                                            id: capText
                                                            anchors.centerIn: parent
                                                            text: part.modelData
                                                            font.family: root.font
                                                            font.pointSize: 8.5
                                                            font.weight: Font.Medium
                                                            color: root.c("onSurface", "#cdd6f4")
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                                text: entry.modelData.action
                                                font.family: root.font
                                                font.pointSize: 9.5
                                                color: root.c("onSurface", "#cdd6f4")
                                            }
                                            Text {
                                                // The section, in search results
                                                visible: !!root.query
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: entry.modelData.section
                                                font.family: root.font
                                                font.pointSize: 8
                                                color: root.c("outline", "#7f849c")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    id: footer
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "Live from hyprctl binds · ↑↓ scroll · Esc clear / close"
                    font.family: root.font
                    font.pointSize: 8
                    color: root.c("outline", "#7f849c")
                }
            }
        }
    }
}
