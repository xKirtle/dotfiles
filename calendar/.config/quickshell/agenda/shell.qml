// Agenda panel: today + the next days from the Proton Calendar (synced by vdirsyncer, read by khal).
// Toggle: `calendarctl panel` (Super+A), or qs -c agenda ipc call agenda toggle.
// Data: JSON from `calendarctl agenda`. ←/→ (h/l) = previous/next 5 days, T = back to today,
// ↑/↓ (k/j) = select an event, Enter (or click) = show its details (description, links: click a link
// to open it, drag to select, Ctrl+C copies), O = open the event's first link, R = sync now,
// Esc = close. Opening always starts at today. Links open with xdg-open (default browser).
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
    property var ag: ({})
    property var pal: ({})
    property bool syncing: false
    property int offset: 0          // first day shown, in days from today (paged by `days`)
    property bool reloadPending: false
    property int eventCount: 0      // events on screen; each gets an index `_i` and a stable `_key`
    property int selected: -1       // keyboard selection (index), -1 = none
    property string expandedKey: "" // event whose details are shown (survives the 1-minute refresh)
    property bool overDetails: false // mouse over a details text: drag selects text instead of scrolling
    property var activeDetails: null // details text the user last selected in (Ctrl+C copies from it)
    property string hint: ""         // short feedback in the footer, e.g. "No link in this event"

    readonly property string home: Quickshell.env("HOME")
    // Absolute path: the session's PATH (from Hyprland/uwsm) doesn't include ~/.local/bin.
    readonly property string calendarctl: home + "/.local/bin/calendarctl"
    readonly property string font: gsf.status === FontLoader.Ready ? gsf.name : "Inter"
    readonly property int days: 5

    function c(key, fallback) {
        return pal[key] ? "#" + pal[key] : fallback;
    }

    // A running Process ignores command changes, so a request mid-run re-runs it afterwards.
    function refresh() {
        if (loader.running) reloadPending = true;
        else loader.running = true;
    }

    function page(step) {
        offset = step === 0 ? 0 : offset + step * days;
        selected = -1;
        expandedKey = "";
        refresh();
    }

    function eventAt(i) {
        for (const d of ag.days ?? [])
            for (const e of d.events)
                if (e._i === i) return e;
        return null;
    }

    function hasDetails(e) {
        return !!(e.description || e.url || (e.location && e.location.length > 40));
    }

    function toggleDetails(e) {
        if (!e) return;
        selected = e._i;
        expandedKey = expandedKey === e._key ? "" : e._key;
    }

    // First link in the event: its URL field, then the location, then the description.
    function firstLink(e) {
        if (!e) return "";
        if (e.url) return e.url;
        const m = `${e.location ?? ""} ${e.description ?? ""}`.match(/https?:\/\/[^\s<>"]+/);
        return m ? m[0] : "";
    }

    function openLink(url) {
        if (!url) {
            say("No link in this event");
            return;
        }
        Quickshell.execDetached(["/usr/bin/xdg-open", url]);
        open = false;
    }

    function say(text) {
        hint = text;
        hintTimer.restart();
    }

    // Plain text -> rich text with clickable links (the description is untrusted: escape it first).
    function linkify(s) {
        const esc = (s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const col = c("primary", "#cba6f7");
        return esc.replace(/https?:\/\/[^\s<>"]+/g, u => `<a href="${u}" style="color:${col}">${u}</a>`)
                  .replace(/\n/g, "<br>");
    }

    // "Mon 19 Oct – Fri 23 Oct", shown in the header when not starting at today.
    function range() {
        const d = ag.days ?? [];
        return d.length ? `${d[0].subtitle} – ${d[d.length - 1].subtitle}` : "";
    }

    function status() {
        if (syncing) return "syncing…";
        if (ag.configured === false) return "not set up";
        if (!ag.synced) return "never synced";
        const t = new Date(ag.synced);
        const sameDay = t.toDateString() === new Date().toDateString();
        return (ag.syncOk ? "synced " : "sync failed ") + Qt.formatDateTime(t, sameDay ? "HH:mm" : "ddd HH:mm");
    }

    FontLoader {
        id: gsf
        source: "file:///etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
    }

    FileView {
        id: schemeFile
        path: root.home + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.pal = JSON.parse(text()).colours; } catch (e) {}
        }
    }

    // Written by `calendarctl sync` after every sync (timer or R): reload the list.
    FileView {
        path: root.home + "/.local/state/calendar/sync.json"
        watchChanges: true
        onFileChanged: { reload(); if (root.open) root.refresh(); }
    }

    Process {
        id: loader
        command: [root.calendarctl, "agenda", "--days", String(root.days), "--offset", String(root.offset)]
        stdout: StdioCollector {
            onStreamFinished: {
                let ag;
                try { ag = JSON.parse(text); } catch (e) { ag = { error: "calendarctl agenda: bad output" }; }
                let n = 0;
                for (const d of ag.days ?? [])
                    for (const e of d.events) {
                        e._i = n++;
                        e._key = `${e.start}|${e.title}`;
                    }
                root.eventCount = n;
                if (root.selected >= n) root.selected = n - 1;
                root.ag = ag;
            }
        }
        onExited: {
            if (root.reloadPending) {
                root.reloadPending = false;
                running = true;
            }
        }
    }

    Process {
        id: syncer
        command: [root.calendarctl, "sync"]
        onExited: { root.syncing = false; root.refresh(); }
    }

    Timer {
        id: hintTimer
        interval: 2500
        onTriggered: root.hint = ""
    }

    Timer {
        interval: 60000
        running: root.open
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "agenda"

        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            schemeFile.reload();
            root.offset = 0;
            root.selected = -1;
            root.expandedKey = "";
            root.refresh();
            root.open = true;
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
        WlrLayershell.namespace: "agenda"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusiveZone: 0  // sit beside Caelestia's bar instead of reserving space

        anchors.left: true
        anchors.top: true
        margins.left: 10
        margins.top: 10

        implicitWidth: 420
        implicitHeight: Math.min(body.implicitHeight + 40, (screen ? screen.height : 1080) - 20)

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

            focus: true
            Keys.onEscapePressed: root.open = false
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_R:
                    if (!root.syncing) {
                        root.syncing = true;
                        syncer.running = true;
                    }
                    break;
                case Qt.Key_Left: case Qt.Key_H: root.page(-1); break;
                case Qt.Key_Right: case Qt.Key_L: root.page(1); break;
                case Qt.Key_T: case Qt.Key_Home: root.page(0); break;
                case Qt.Key_Down: case Qt.Key_J:
                    if (root.eventCount) root.selected = Math.min(root.eventCount - 1, root.selected + 1);
                    break;
                case Qt.Key_Up: case Qt.Key_K:
                    if (root.eventCount) root.selected = Math.max(0, root.selected - 1);
                    break;
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                    root.toggleDetails(root.eventAt(root.selected));
                    break;
                case Qt.Key_O:
                    if (root.selected < 0) root.say("Select an event first (↑↓)");
                    else root.openLink(root.firstLink(root.eventAt(root.selected)));
                    break;
                case Qt.Key_C:
                    if (!(event.modifiers & Qt.ControlModifier)) return;
                    if (root.activeDetails && root.activeDetails.selectedText) {
                        root.activeDetails.copy();
                        root.say("Copied");
                    }
                    break;
                default: return;
                }
                event.accepted = true;
            }

            Flickable {
                id: flick
                anchors.fill: parent
                interactive: !root.overDetails  // the wheel still scrolls
                anchors.margins: 20
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body
                    width: parent.width
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Agenda"
                            font.family: root.font
                            font.pointSize: 13
                            font.weight: Font.DemiBold
                            color: root.c("onSurface", "#cdd6f4")
                        }
                        Text {
                            visible: root.offset !== 0
                            text: root.range()
                            font.family: root.font
                            font.pointSize: 9
                            color: root.c("primary", "#cba6f7")
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.status()
                            font.family: root.font
                            font.pointSize: 9
                            color: root.ag.syncOk === false && root.ag.synced ? "#fab387" : root.c("onSurfaceVariant", "#a6adc8")
                        }
                    }

                    Text {
                        visible: text !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: [root.ag.configured === false
                               ? "No calendar link yet: set PROTON_CALENDAR_URL in ~/Dev/Personal/dotfiles/.env, then press R." : "",
                               (root.ag.error ?? "").includes("PROTON_CALENDAR_URL") ? "" : root.ag.error ?? ""]
                              .filter(x => x).join("\n")
                        font.family: root.font
                        font.pointSize: 9
                        color: "#fab387"
                    }

                    Repeater {
                        model: root.ag.days ?? []

                        ColumnLayout {
                            id: day
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                visible: day.index > 0
                                Layout.fillWidth: true
                                Layout.bottomMargin: 4
                                implicitHeight: 1
                                color: root.c("outlineVariant", "#45475a")
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: day.modelData.label
                                    font.family: root.font
                                    font.pointSize: 10.5
                                    font.weight: day.index === 0 ? Font.Bold : Font.Medium
                                    color: day.index === 0 ? root.c("primary", "#cba6f7") : root.c("onSurface", "#cdd6f4")
                                }
                                Text {
                                    text: day.modelData.subtitle
                                    font.family: root.font
                                    font.pointSize: 8.5
                                    color: root.c("onSurfaceVariant", "#a6adc8")
                                }
                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                visible: day.modelData.events.length === 0
                                text: "Nothing scheduled"
                                font.family: root.font
                                font.pointSize: 9
                                color: root.c("outline", "#7f849c")
                            }

                            Repeater {
                                model: day.modelData.events

                                Rectangle {
                                    id: ev
                                    required property var modelData
                                    readonly property bool sel: root.selected === modelData._i
                                    readonly property bool expanded: root.expandedKey === modelData._key
                                    Layout.fillWidth: true
                                    implicitHeight: evRow.implicitHeight + 14
                                    radius: 12
                                    opacity: modelData.past && !expanded ? 0.5 : 1
                                    color: modelData.now ? root.c("primaryContainer", "#45475a")
                                                         : root.c("surfaceContainerHigh", "#2a2a3c")
                                    border.width: sel ? 2 : 0
                                    border.color: root.c("primary", "#cba6f7")

                                    // Keep the keyboard selection (and opened details) scrolled into view.
                                    function reveal() {
                                        const p = mapToItem(body, 0, 0);
                                        if (p.y < flick.contentY) flick.contentY = p.y;
                                        else if (p.y + height > flick.contentY + flick.height)
                                            flick.contentY = Math.min(p.y + height - flick.height, Math.max(0, flick.contentHeight - flick.height));
                                    }
                                    onSelChanged: if (sel) Qt.callLater(reveal)
                                    onExpandedChanged: if (expanded) Qt.callLater(reveal)

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleDetails(ev.modelData)
                                    }

                                    RowLayout {
                                        id: evRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        Rectangle {
                                            Layout.fillHeight: true
                                            implicitWidth: 4
                                            radius: 2
                                            color: ev.modelData.now ? root.c("onPrimaryContainer", "#cdd6f4")
                                                 : ev.modelData.allDay ? root.c("tertiary", "#94e2d5") : root.c("primary", "#cba6f7")
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: ev.modelData.title
                                                    elide: Text.ElideRight
                                                    font.family: root.font
                                                    font.pointSize: 10
                                                    font.weight: Font.Medium
                                                    color: ev.modelData.now ? root.c("onPrimaryContainer", "#cdd6f4") : root.c("onSurface", "#cdd6f4")
                                                }
                                                Text {
                                                    visible: ev.modelData.recurring
                                                    text: "⟳"
                                                    font.pointSize: 12
                                                    color: root.c("onSurfaceVariant", "#a6adc8")
                                                }
                                                Text {  // has a description / link: expandable
                                                    visible: root.hasDetails(ev.modelData)
                                                    text: ev.expanded ? "▴" : "▾"
                                                    font.pointSize: 10
                                                    color: root.c("onSurfaceVariant", "#a6adc8")
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: ev.modelData.time + (ev.modelData.now ? " · now" : "")
                                                      + (ev.modelData.location && !ev.expanded ? " · " + ev.modelData.location : "")
                                                elide: Text.ElideRight
                                                font.family: root.font
                                                font.pointSize: 8.5
                                                color: ev.modelData.now ? root.c("onPrimaryContainer", "#cdd6f4") : root.c("onSurfaceVariant", "#a6adc8")
                                            }

                                            // Details: full location, URL field, description (links clickable)
                                            TextEdit {
                                                id: details
                                                visible: ev.expanded
                                                Layout.fillWidth: true
                                                Layout.topMargin: 6
                                                readOnly: true
                                                selectByMouse: true
                                                persistentSelection: true
                                                activeFocusOnPress: false  // keep keys going to the panel (Ctrl+C is handled there)
                                                selectionColor: root.c("primary", "#cba6f7")
                                                selectedTextColor: root.c("onPrimary", "#1e1e2e")
                                                onSelectedTextChanged: if (selectedText) root.activeDetails = details
                                                wrapMode: TextEdit.Wrap
                                                textFormat: TextEdit.RichText
                                                text: [
                                                    ev.modelData.location ? "📍 " + root.linkify(ev.modelData.location) : "",
                                                    ev.modelData.url ? "🔗 " + root.linkify(ev.modelData.url) : "",
                                                    ev.modelData.description ? root.linkify(ev.modelData.description)
                                                        : (!ev.modelData.location && !ev.modelData.url ? "<i>No description</i>" : "")
                                                ].filter(x => x).join("<br><br>")
                                                font.family: root.font
                                                font.pointSize: 9
                                                color: ev.modelData.now ? root.c("onPrimaryContainer", "#cdd6f4") : root.c("onSurface", "#cdd6f4")
                                                onLinkActivated: link => root.openLink(link)

                                                HoverHandler {
                                                    onHoveredChanged: root.overDetails = hovered
                                                    cursorShape: details.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
                                                }
                                            }
                                            Text {
                                                visible: ev.expanded
                                                Layout.topMargin: 2
                                                text: (root.firstLink(ev.modelData) ? "O opens the first link · " : "")
                                                      + "drag to select, Ctrl+C copies"
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

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.hint || (root.offset !== 0 ? "T today · " : "") + "←→ days · ↑↓ select · Enter details · O link · R sync · Esc close"
                        font.weight: root.hint ? Font.DemiBold : Font.Normal
                        font.family: root.font
                        font.pointSize: 8
                        color: root.c("outline", "#7f849c")
                    }
                }
            }
        }
    }
}
