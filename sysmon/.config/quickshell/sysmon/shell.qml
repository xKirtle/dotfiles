// System monitor panel: CPU / memory / GPU / disk / network graphs and a task manager.
// Toggle: Ctrl+Shift+Esc (sysmonctl panel, or qs -c sysmon ipc call sysmon toggle).
// Data: `sysmonctl watch` streams one JSON sample a second while the panel is open (stopped when it
// closes, so the graphs start empty on each open). CPU % is of the whole machine, like Windows;
// Memory is private (resident minus shared); Disk is read + write per second (own processes only:
// other users' /proc/<pid>/io isn't readable).
// Type to filter (name, PID, user or command line), ↑/↓/PgUp/PgDn select, Enter (or double-click)
// = expand / collapse a group, Del = end task (SIGTERM), Shift+Del = force kill (SIGKILL), Tab /
// Shift+Tab = next / previous sort column (or click a header; again = reverse), Ctrl+G = group by
// name on/off, Ctrl+P = pause the list, Esc = cancel / clear the filter, then close.
// Force kills, several processes at once and session-critical ones ask first (Enter = yes).
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
    property var pal: ({})
    property var sample: null           // last `sysmonctl watch` line
    property var procs: []              // the list shown (frozen while paused / confirming)
    property var hist: ({ cpu: [], mem: [], gpu: [], vram: [], dr: [], dw: [], rx: [], tx: [] })
    property string query: ""
    property string sortKey: "cpu"
    property bool sortDesc: true
    property bool group: true
    property bool paused: false
    property var expanded: ({})         // group name → true
    property string selectedKey: ""
    property var pending: null          // {how, pids, label, warn}: waiting for Enter
    property string hint: ""

    readonly property string home: Quickshell.env("HOME")
    // Absolute path: the session's PATH (from Hyprland/uwsm) doesn't include ~/.local/bin.
    readonly property string sysmonctl: home + "/.local/bin/sysmonctl"
    readonly property string font: gsf.status === FontLoader.Ready ? gsf.name : "Inter"
    readonly property int points: 60    // seconds of history in the graphs
    readonly property var sortKeys: ["name", "pid", "user", "cpu", "mem", "disk"]
    // Ending these takes the session (or sound, the bar…) with it: always ask first
    readonly property var critical: ["Hyprland", "uwsm", "systemd", "dbus-broker", "dbus-daemon", "Xwayland",
                                     "pipewire", "pipewire-pulse", "wireplumber", "qs", "quickshell", "greetd"]

    readonly property var rows: buildRows(procs, query, sortKey, sortDesc, group, expanded)
    readonly property int selected: rows.findIndex(r => r.key === selectedKey)
    readonly property var current: selected >= 0 ? rows[selected] : null
    onRowsChanged: syncModel()

    function c(key, fallback) {
        return pal[key] ? "#" + pal[key] : fallback;
    }

    function alpha(colour, a) {
        const q = Qt.darker(colour, 1);
        return Qt.rgba(q.r, q.g, q.b, a);
    }

    function say(text) {
        hint = text;
        hintTimer.restart();
    }

    function show() {
        schemeFile.reload();
        query = "";
        selectedKey = "";
        pending = null;
        paused = false;
        sample = null;
        procs = [];
        hist = { cpu: [], mem: [], gpu: [], vram: [], dr: [], dw: [], rx: [], tx: [] };
        open = true;
    }

    function bytes(n, digits) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1000 && i < units.length - 1) { n /= 1024; i++; }
        return (i === 0 ? Math.round(n) : n.toFixed(n >= 100 ? 0 : digits ?? 1)) + " " + units[i];
    }

    function rate(n) {
        return n < 1 ? "0 B/s" : bytes(n) + "/s";
    }

    function pct(n) {
        return (n >= 10 ? n.toFixed(0) : n.toFixed(1)) + "%";
    }

    function onSample(line) {
        let s;
        try { s = JSON.parse(line); } catch (e) { return; }
        const push = (arr, v) => arr.concat([v ?? 0]).slice(-points);
        const h = hist;
        hist = {
            cpu: push(h.cpu, s.cpu.total),
            mem: push(h.mem, 100 * s.mem.used / s.mem.total),
            gpu: push(h.gpu, s.gpu?.util),
            vram: push(h.vram, s.gpu ? 100 * s.gpu.memUsed / s.gpu.memTotal : 0),
            dr: push(h.dr, s.disk.read), dw: push(h.dw, s.disk.write),
            rx: push(h.rx, s.net.rx), tx: push(h.tx, s.net.tx)
        };
        sample = s;
        if (!paused && !pending) procs = s.procs;
    }

    // Flat list of rows: processes, or groups by name (expanded ones followed by their processes)
    function buildRows(procs, query, sortKey, desc, group, expanded) {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w);
        const list = !words.length ? procs : procs.filter(p => {
            const text = `${p.name} ${p.pid} ${p.user} ${p.cmd}`.toLowerCase();
            return words.every(w => text.includes(w));
        });
        const text = sortKey === "name" || sortKey === "user";
        const cmp = (a, b) => {
            const r = text ? a[sortKey].toLowerCase().localeCompare(b[sortKey].toLowerCase()) : a[sortKey] - b[sortKey];
            return (desc ? -r : r) || a.pid - b.pid;
        };
        const procRow = (p, depth) => ({
            key: "p|" + p.pid, kind: "proc", depth: depth, name: p.name, count: 1, pid: p.pid,
            user: p.user, cpu: p.cpu, mem: p.mem, disk: p.disk, cmd: p.cmd, pids: String(p.pid),
            expanded: false
        });
        if (!group) return list.slice().sort(cmp).map(p => procRow(p, 0));

        const byName = {}, groups = [];
        for (const p of list) {
            let g = byName[p.name];
            if (!g) {
                g = byName[p.name] = { name: p.name, members: [], cpu: 0, mem: 0, disk: 0, pid: p.pid, user: p.user };
                groups.push(g);
            }
            g.members.push(p);
            g.cpu += p.cpu; g.mem += p.mem; g.disk += p.disk;
            g.pid = Math.min(g.pid, p.pid);
            if (g.user !== p.user) g.user = "various";
        }
        const out = [];
        for (const g of groups.sort(cmp)) {
            if (g.members.length === 1) {
                out.push(procRow(g.members[0], 0));
                continue;
            }
            const open = !!expanded[g.name];
            out.push({ key: "g|" + g.name, kind: "group", depth: 0, name: g.name, count: g.members.length,
                       pid: g.pid, user: g.user, cpu: g.cpu, mem: g.mem, disk: g.disk,
                       cmd: `${g.members.length} processes`, pids: g.members.map(p => p.pid).join(" "),
                       expanded: open });
            if (open) for (const p of g.members.sort(cmp)) out.push(procRow(p, 1));
        }
        return out;
    }

    // Update the ListModel in place, so the view keeps its scroll position between samples
    function syncModel() {
        const rs = rows;
        for (let i = 0; i < rs.length; i++) {
            if (i < procModel.count) procModel.set(i, rs[i]);
            else procModel.append(rs[i]);
        }
        if (procModel.count > rs.length) procModel.remove(rs.length, procModel.count - rs.length);
    }

    function move(step) {
        if (!rows.length) return;
        const i = selected < 0 ? (step > 0 ? 0 : rows.length - 1)
                               : Math.max(0, Math.min(rows.length - 1, selected + step));
        selectedKey = rows[i].key;
        list.positionViewAtIndex(i, ListView.Contain);
    }

    function setExpanded(r, on) {
        if (!r) return;
        if (r.kind === "proc" && r.depth > 0 && !on) {
            // ← on a child: collapse its group and select it
            selectedKey = "g|" + r.name;
            r = { kind: "group", name: r.name };
        }
        if (r.kind !== "group") return;
        const e = Object.assign({}, expanded);
        if (on) e[r.name] = true; else delete e[r.name];
        expanded = e;
    }

    function setSort(key) {
        if (sortKey === key) sortDesc = !sortDesc;
        else {
            sortKey = key;
            sortDesc = !(key === "name" || key === "user" || key === "pid");
        }
    }

    function cycleSort(step) {
        const i = (sortKeys.indexOf(sortKey) + step + sortKeys.length) % sortKeys.length;
        sortKey = sortKeys[i];
        sortDesc = !(sortKey === "name" || sortKey === "user" || sortKey === "pid");
    }

    // Del / Shift+Del / the buttons: end or force kill the selected row (a group = all its processes)
    function act(how) {
        const r = current;
        if (!r || killer.running) return;
        const pids = r.pids.split(" ").map(Number);
        const label = r.count > 1 ? `${r.name} (${r.count} processes)` : `${r.name} (${r.pid})`;
        const warn = critical.includes(r.name) ? (r.name === "Hyprland" || r.name === "uwsm" || r.name === "systemd"
                                                  ? "This ends your session." : "Part of the desktop session.")
                   : r.user !== Quickshell.env("USER") ? "Runs as " + r.user + ": asks for your password." : "";
        const req = { how: how, pids: pids, label: label, warn: warn };
        if (how === "kill" || pids.length > 1 || critical.includes(r.name)) pending = req;
        else run(req);
    }

    function run(req) {
        pending = null;
        killer.req = req;
        killer.command = [sysmonctl, "kill", req.how, ...req.pids.map(String)];
        killer.running = true;
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

    ListModel { id: procModel }

    Process {
        id: watcher
        running: root.open
        command: [root.sysmonctl, "watch"]
        stdout: SplitParser {
            onRead: data => root.onSample(data)
        }
        onExited: code => { if (root.open) root.say(`sysmonctl watch stopped (exit ${code})`); }
    }

    Process {
        id: killer
        property var req: null
        stdout: StdioCollector { id: killOut }
        onExited: code => {
            let res = {};
            try { res = JSON.parse(killOut.text); } catch (e) {}
            const verb = req.how === "kill" ? "Force killed" : "Ended";
            if (code === 0) root.say(`${verb} ${req.label}`);
            else if (res.denied) root.say(`Not allowed for ${res.denied.length} of ${req.pids.length}: ${res.denied.join(", ")}`);
            else root.say("sysmonctl kill failed");
        }
    }

    Timer {
        id: hintTimer
        interval: 4000
        onTriggered: root.hint = ""
    }

    IpcHandler {
        target: "sysmon"

        function toggle(): void {
            if (root.open) root.open = false;
            else root.show();
        }

        function close(): void {
            root.open = false;
        }
    }

    // A small line/area chart: first series filled, the others as lines. peak 0 = scale to the data.
    component Graph: Canvas {
        property var series: []
        property var colours: []
        property real peak: 100
        property int points: 60
        property color grid: "#45475a"
        readonly property real scaleTop: peak > 0 ? peak : Math.max(1, ...series.map(s => Math.max(0, ...s)))

        onSeriesChanged: requestPaint()
        onColoursChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = grid;
            ctx.lineWidth = 1;
            for (const f of [0.25, 0.5, 0.75]) {
                ctx.beginPath();
                ctx.moveTo(0, Math.round(height * f) + 0.5);
                ctx.lineTo(width, Math.round(height * f) + 0.5);
                ctx.globalAlpha = 0.5;
                ctx.stroke();
            }
            ctx.globalAlpha = 1;
            const step = width / (points - 1);
            series.forEach((s, si) => {
                if (s.length < 2) return;
                const x0 = width - (s.length - 1) * step;
                ctx.beginPath();
                s.forEach((v, i) => {
                    const x = x0 + i * step, y = height - 1 - Math.min(1, v / scaleTop) * (height - 2);
                    if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
                });
                ctx.strokeStyle = colours[si];
                ctx.lineWidth = 1.5;
                ctx.stroke();
                if (si === 0) {
                    ctx.lineTo(width, height);
                    ctx.lineTo(x0, height);
                    ctx.closePath();
                    ctx.fillStyle = colours[si];
                    ctx.globalAlpha = 0.22;
                    ctx.fill();
                    ctx.globalAlpha = 1;
                }
            });
        }
    }

    // One performance card: title + big value + detail line, then a graph, then `extra` below it
    component Card: Rectangle {
        id: card
        property string icon
        property string title
        property string value
        property string detail
        property string fontName
        property color fg
        property color muted
        property color accent
        default property alias extra: extraBox.data

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1  // equal widths
        radius: 14

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: card.icon
                    font.family: "Material Symbols Rounded"
                    font.pointSize: 11
                    color: card.accent
                }
                Text {
                    Layout.fillWidth: true
                    text: card.title
                    elide: Text.ElideRight
                    font.family: card.fontName
                    font.pointSize: 8.5
                    font.weight: Font.DemiBold
                    color: card.muted
                }
            }
            Text {
                Layout.fillWidth: true
                text: card.value
                elide: Text.ElideRight
                font.family: card.fontName
                font.pointSize: 13
                font.weight: Font.DemiBold
                color: card.fg
            }
            Text {
                Layout.fillWidth: true
                text: card.detail
                elide: Text.ElideRight
                font.family: card.fontName
                font.pointSize: 8
                color: card.muted
            }
            ColumnLayout {
                id: extraBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 4
                spacing: 4
            }
        }
    }

    // A thin labelled usage bar (storage card)
    component Bar: ColumnLayout {
        id: bar
        property string label
        property string valueText
        property real frac
        property string fontName
        property color fg
        property color track
        property color fill
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            Text { text: bar.label; font.family: bar.fontName; font.pointSize: 7.5; color: bar.fg; Layout.fillWidth: true }
            Text { text: bar.valueText; font.family: bar.fontName; font.pointSize: 7.5; color: bar.fg }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: bar.track
            Rectangle {
                width: parent.width * Math.min(1, bar.frac)
                height: parent.height
                radius: 2
                color: bar.fill
            }
        }
    }

    PanelWindow {
        id: win

        visible: root.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sysmon"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusiveZone: 0

        // No anchors: centred on the monitor
        implicitWidth: Math.min(1180, Math.round((screen ? screen.width : 1920) * 0.92))
        implicitHeight: Math.min(1000, Math.round((screen ? screen.height : 1080) * 0.85))

        onVisibleChanged: if (visible) { list.positionViewAtBeginning(); search.forceActiveFocus(); }

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
                spacing: 12

                // --- Header -----------------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "monitoring"  // Material Symbols ligature
                        font.family: "Material Symbols Rounded"
                        font.pointSize: 15
                        color: root.c("primary", "#cba6f7")
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "System monitor"
                        font.family: root.font
                        font.pointSize: 13
                        font.weight: Font.DemiBold
                        color: root.c("onSurface", "#cdd6f4")
                    }
                    Text {
                        text: root.sample ? `${root.sample.procs.length} processes` : "Starting…"
                        font.family: root.font
                        font.pointSize: 9
                        color: root.c("onSurfaceVariant", "#a6adc8")
                    }
                }

                // --- Performance cards ------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    // The cards fill their height, which would otherwise make this row take all the space
                    Layout.fillHeight: false
                    Layout.preferredHeight: 230
                    Layout.maximumHeight: 230
                    spacing: 10

                    Card {
                        readonly property var cpu: root.sample?.cpu
                        icon: "memory"
                        title: "CPU"
                        value: cpu ? root.pct(cpu.total) : "–"
                        detail: cpu ? [cpu.freq ? cpu.freq.toFixed(2) + " GHz" : "", cpu.temp ? Math.round(cpu.temp) + " °C" : "",
                                       cpu.count + " threads"].filter(x => x).join(" · ") : ""
                        fontName: root.font
                        fg: root.c("onSurface", "#cdd6f4")
                        muted: root.c("onSurfaceVariant", "#a6adc8")
                        accent: root.c("primary", "#cba6f7")
                        color: root.c("surfaceContainerHigh", "#2a2a3c")

                        Graph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            series: [root.hist.cpu]
                            colours: [root.c("primary", "#cba6f7")]
                            grid: root.c("outlineVariant", "#45475a")
                            points: root.points
                        }
                        // One bar per thread
                        Row {
                            id: cores
                            Layout.fillWidth: true
                            Layout.preferredHeight: 14
                            readonly property var load: root.sample?.cpu.cores ?? []
                            spacing: 2
                            Repeater {
                                model: cores.load.length
                                Rectangle {
                                    required property int index
                                    width: (cores.width - (cores.load.length - 1) * cores.spacing) / cores.load.length
                                    height: cores.height
                                    radius: 2
                                    color: root.c("surfaceContainerHighest", "#313244")
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(1, parent.height * cores.load[parent.index] / 100)
                                        radius: 2
                                        color: root.c("primary", "#cba6f7")
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        readonly property var mem: root.sample?.mem
                        icon: "memory_alt"
                        title: "Memory"
                        value: mem ? `${root.bytes(mem.used)} / ${root.bytes(mem.total, 0)}` : "–"
                        detail: mem ? `${root.pct(100 * mem.used / mem.total)} · cache ${root.bytes(mem.cached)}`
                                      + (mem.swapTotal ? ` · swap ${root.bytes(mem.swapUsed)}` : "") : ""
                        fontName: root.font
                        fg: root.c("onSurface", "#cdd6f4")
                        muted: root.c("onSurfaceVariant", "#a6adc8")
                        accent: root.c("secondary", "#89b4fa")
                        color: root.c("surfaceContainerHigh", "#2a2a3c")

                        Graph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            series: [root.hist.mem]
                            colours: [root.c("secondary", "#89b4fa")]
                            grid: root.c("outlineVariant", "#45475a")
                            points: root.points
                        }
                    }

                    Card {
                        readonly property var gpu: root.sample?.gpu
                        icon: "developer_board"
                        title: gpu ? gpu.name.replace(/^NVIDIA (GeForce )?/, "GPU · ") : "GPU"
                        value: gpu ? root.pct(gpu.util ?? 0) : root.sample ? "no data" : "–"
                        detail: gpu ? [`VRAM ${root.bytes(gpu.memUsed)} / ${root.bytes(gpu.memTotal, 0)}`,
                                       gpu.temp !== null ? Math.round(gpu.temp) + " °C" : "",
                                       gpu.power !== null ? Math.round(gpu.power) + " W" : ""].filter(x => x).join(" · ") : ""
                        fontName: root.font
                        fg: root.c("onSurface", "#cdd6f4")
                        muted: root.c("onSurfaceVariant", "#a6adc8")
                        accent: root.c("tertiary", "#94e2d5")
                        color: root.c("surfaceContainerHigh", "#2a2a3c")

                        Graph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            series: [root.hist.gpu, root.hist.vram]
                            colours: [root.c("tertiary", "#94e2d5"), root.c("secondary", "#89b4fa")]
                            grid: root.c("outlineVariant", "#45475a")
                            points: root.points
                        }
                        Text {
                            text: `<font color="${root.c("tertiary", "#94e2d5")}">■</font> load   `
                                  + `<font color="${root.c("secondary", "#89b4fa")}">■</font> VRAM`
                            textFormat: Text.StyledText
                            font.family: root.font
                            font.pointSize: 7.5
                            color: root.c("onSurfaceVariant", "#a6adc8")
                        }
                    }

                    Card {
                        id: diskCard
                        readonly property var disk: root.sample?.disk
                        icon: "hard_drive"
                        title: "Disk"
                        value: disk ? `↓ ${root.rate(disk.read)}  ↑ ${root.rate(disk.write)}` : "–"
                        detail: "read ↓ · write ↑ · scale " + root.rate(Math.max(1, ...root.hist.dr, ...root.hist.dw))
                        fontName: root.font
                        fg: root.c("onSurface", "#cdd6f4")
                        muted: root.c("onSurfaceVariant", "#a6adc8")
                        accent: root.c("primary", "#cba6f7")
                        color: root.c("surfaceContainerHigh", "#2a2a3c")

                        Graph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            series: [root.hist.dr, root.hist.dw]
                            colours: [root.c("primary", "#cba6f7"), root.c("tertiary", "#94e2d5")]
                            grid: root.c("outlineVariant", "#45475a")
                            peak: 0
                            points: root.points
                        }
                        Repeater {
                            model: diskCard.disk?.fs ?? []
                            Bar {
                                required property var modelData
                                label: modelData.name
                                valueText: `${root.bytes(modelData.used, 0)} / ${root.bytes(modelData.total, 0)}`
                                frac: modelData.used / modelData.total
                                fontName: root.font
                                fg: root.c("onSurfaceVariant", "#a6adc8")
                                track: root.c("surfaceContainerHighest", "#313244")
                                fill: modelData.used / modelData.total > 0.9 ? root.c("error", "#f38ba8") : root.c("primary", "#cba6f7")
                            }
                        }
                    }

                    Card {
                        readonly property var net: root.sample?.net
                        icon: "lan"
                        title: "Network"
                        value: net ? `↓ ${root.rate(net.rx)}  ↑ ${root.rate(net.tx)}` : "–"
                        detail: "received ↓ · sent ↑ · scale " + root.rate(Math.max(1, ...root.hist.rx, ...root.hist.tx))
                        fontName: root.font
                        fg: root.c("onSurface", "#cdd6f4")
                        muted: root.c("onSurfaceVariant", "#a6adc8")
                        accent: root.c("secondary", "#89b4fa")
                        color: root.c("surfaceContainerHigh", "#2a2a3c")

                        Graph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            series: [root.hist.rx, root.hist.tx]
                            colours: [root.c("secondary", "#89b4fa"), root.c("tertiary", "#94e2d5")]
                            grid: root.c("outlineVariant", "#45475a")
                            peak: 0
                            points: root.points
                        }
                    }
                }

                // --- Filter + toggles -------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

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
                            onTextChanged: { root.query = text; list.positionViewAtBeginning(); }
                            font.family: root.font
                            font.pointSize: 10
                            color: root.c("onSurface", "#cdd6f4")
                            selectionColor: root.c("primary", "#cba6f7")
                            selectedTextColor: root.c("onPrimary", "#1e1e2e")
                            clip: true

                            Text {
                                visible: !search.text
                                text: "Filter by name, PID, user or command line"
                                font: search.font
                                color: root.c("outline", "#7f849c")
                            }

                            Keys.onPressed: event => {
                                const ctrl = event.modifiers & Qt.ControlModifier;
                                const shift = event.modifiers & Qt.ShiftModifier;
                                if (root.pending) {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.run(root.pending);
                                    else if (event.key === Qt.Key_Escape) root.pending = null;
                                    event.accepted = true;
                                    return;
                                }
                                const page = Math.max(1, Math.floor(list.height / 30) - 1);
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    if (search.text) search.text = "";
                                    else root.open = false;
                                    break;
                                case Qt.Key_Down: root.move(1); break;
                                case Qt.Key_Up: root.move(-1); break;
                                case Qt.Key_PageDown: root.move(page); break;
                                case Qt.Key_PageUp: root.move(-page); break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    if (root.current) root.setExpanded(root.current, !root.current.expanded);
                                    break;
                                case Qt.Key_Right:
                                    if (search.cursorPosition < search.text.length) return;
                                    root.setExpanded(root.current, true);
                                    break;
                                case Qt.Key_Left:
                                    if (search.text) return;
                                    root.setExpanded(root.current, false);
                                    break;
                                case Qt.Key_Delete: root.act(shift ? "kill" : "term"); break;
                                case Qt.Key_Tab: root.cycleSort(1); break;
                                case Qt.Key_Backtab: root.cycleSort(-1); break;
                                case Qt.Key_G: if (!ctrl) return; root.group = !root.group; break;
                                case Qt.Key_P: if (!ctrl) return; root.paused = !root.paused; break;
                                default: return;
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    Repeater {
                        model: [
                            { label: "Group by name", on: root.group, toggle: () => root.group = !root.group },
                            { label: "Pause", on: root.paused, toggle: () => root.paused = !root.paused }
                        ]
                        Rectangle {
                            id: chip
                            required property var modelData
                            implicitWidth: chipText.implicitWidth + 24
                            implicitHeight: search.implicitHeight + 18
                            radius: 12
                            color: modelData.on ? root.c("secondaryContainer", "#45475a")
                                 : chipHover.hovered ? root.c("surfaceContainerHighest", "#313244")
                                 : root.c("surfaceContainerHigh", "#2a2a3c")
                            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: chip.modelData.toggle() }
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: chip.modelData.label
                                font.family: root.font
                                font.pointSize: 9
                                color: chip.modelData.on ? root.c("onSecondaryContainer", "#cdd6f4") : root.c("onSurfaceVariant", "#a6adc8")
                            }
                        }
                    }
                }

                // --- Process table ----------------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: root.c("surfaceContainerLow", "#181825")
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 0

                        // Column headers: click to sort, again to reverse
                        RowLayout {
                            id: headers
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            implicitHeight: 28
                            spacing: 0
                            Repeater {
                                model: [
                                    { key: "name", label: "Name", w: -1 },
                                    { key: "pid", label: "PID", w: 80 },
                                    { key: "user", label: "User", w: 100 },
                                    { key: "cpu", label: "CPU", w: 80 },
                                    { key: "mem", label: "Memory", w: 100 },
                                    { key: "disk", label: "Disk", w: 100 }
                                ]
                                Item {
                                    id: head
                                    required property var modelData
                                    readonly property bool active: root.sortKey === modelData.key
                                    readonly property bool num: ["cpu", "mem", "disk"].includes(modelData.key)
                                    Layout.fillWidth: modelData.w < 0
                                    Layout.preferredWidth: modelData.w < 0 ? 100 : modelData.w
                                    implicitHeight: 28
                                    HoverHandler { id: headHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.setSort(head.modelData.key) }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: head.num ? undefined : parent.left
                                        anchors.right: head.num ? parent.right : undefined
                                        anchors.rightMargin: head.num ? 8 : 0
                                        text: head.modelData.label + (head.active ? (root.sortDesc ? " ↓" : " ↑") : "")
                                        font.family: root.font
                                        font.pointSize: 8.5
                                        font.weight: head.active ? Font.Bold : Font.DemiBold
                                        color: head.active || headHover.hovered ? root.c("primary", "#cba6f7") : root.c("onSurfaceVariant", "#a6adc8")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: root.c("outlineVariant", "#45475a")
                        }

                        ListView {
                            id: list
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 4
                            clip: true
                            model: procModel
                            boundsBehavior: Flickable.StopAtBounds
                            reuseItems: true

                            Text {
                                anchors.centerIn: parent
                                visible: list.count === 0
                                text: !root.sample ? "Reading processes…" : root.query ? "No match" : "No processes"
                                font.family: root.font
                                font.pointSize: 9
                                color: root.c("outline", "#7f849c")
                            }

                            delegate: Rectangle {
                                id: row
                                required property int index
                                required property string key
                                required property string kind
                                required property int depth
                                required property string name
                                required property int count
                                required property int pid
                                required property string user
                                required property real cpu
                                required property real mem
                                required property real disk
                                required property bool expanded
                                readonly property bool isSel: root.selectedKey === key
                                readonly property bool isGroup: kind === "group"

                                width: ListView.view.width
                                height: 30
                                radius: 8
                                color: isSel ? root.c("secondaryContainer", "#45475a")
                                     : rowHover.hovered ? root.c("surfaceContainerHigh", "#2a2a3c") : "transparent"

                                HoverHandler { id: rowHover }
                                TapHandler {
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onTapped: { root.selectedKey = row.key; search.forceActiveFocus(); }
                                    onDoubleTapped: if (row.isGroup) root.setExpanded({ kind: "group", name: row.name }, !row.expanded)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 100
                                        Layout.leftMargin: row.depth * 22
                                        spacing: 4
                                        Text {
                                            // Chevron for groups; children get an indent instead
                                            Layout.preferredWidth: 18
                                            text: row.isGroup ? (row.expanded ? "expand_more" : "chevron_right") : ""
                                            font.family: "Material Symbols Rounded"
                                            font.pointSize: 11
                                            color: root.c("onSurfaceVariant", "#a6adc8")
                                            TapHandler {
                                                onTapped: root.setExpanded({ kind: "group", name: row.name }, !row.expanded)
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: row.name + (row.isGroup ? ` <font color="${root.c("outline", "#7f849c")}">(${row.count})</font>` : "")
                                            textFormat: Text.StyledText
                                            elide: Text.ElideRight
                                            font.family: root.font
                                            font.pointSize: 9.5
                                            color: row.isSel ? root.c("onSecondaryContainer", "#cdd6f4") : root.c("onSurface", "#cdd6f4")
                                        }
                                    }
                                    Text {
                                        Layout.preferredWidth: 80
                                        text: row.isGroup ? "" : row.pid
                                        font.family: root.font
                                        font.pointSize: 9
                                        color: root.c("onSurfaceVariant", "#a6adc8")
                                    }
                                    Text {
                                        Layout.preferredWidth: 100
                                        text: row.user
                                        elide: Text.ElideRight
                                        font.family: root.font
                                        font.pointSize: 9
                                        color: root.c("onSurfaceVariant", "#a6adc8")
                                    }
                                    // Numbers with a heat tint behind them, like Windows' Task Manager
                                    Repeater {
                                        model: [
                                            { w: 80, text: root.pct(row.cpu), heat: row.cpu / 25 },
                                            { w: 100, text: root.bytes(row.mem), heat: row.mem / 4e9 },
                                            { w: 100, text: row.disk >= 1 ? root.rate(row.disk) : "0", heat: row.disk / 50e6 }
                                        ]
                                        Rectangle {
                                            required property var modelData
                                            Layout.preferredWidth: modelData.w
                                            Layout.fillHeight: true
                                            Layout.topMargin: 2
                                            Layout.bottomMargin: 2
                                            radius: 6
                                            color: root.alpha(root.c("primary", "#cba6f7"), Math.min(0.45, modelData.heat * 0.45))
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                text: parent.modelData.text
                                                font.family: root.font
                                                font.pointSize: 9
                                                color: root.c("onSurface", "#cdd6f4")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Selection / confirmation bar ---------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 12
                    color: root.pending ? root.c("errorContainer", "#5b2333") : root.c("surfaceContainerHigh", "#2a2a3c")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 6
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            font.family: root.font
                            font.pointSize: 9
                            color: root.pending ? root.c("onErrorContainer", "#f5c2e7") : root.c("onSurfaceVariant", "#a6adc8")
                            text: {
                                const p = root.pending;
                                if (p) return `<b>${p.how === "kill" ? "Force kill" : "End"} ${p.label}?</b>`
                                              + (p.warn ? " " + p.warn : "") + " Enter = yes · Esc = no";
                                if (root.hint) return root.hint;
                                const r = root.current;
                                if (!r) return root.paused ? "Paused (Ctrl+P resumes)" : "Select a process: ↑/↓ or click";
                                return r.cmd.replace(/&/g, "&amp;").replace(/</g, "&lt;") || `[${r.name}]`;
                            }
                        }

                        Repeater {
                            model: root.pending
                                ? [{ label: "Yes", danger: true, go: () => root.run(root.pending) },
                                   { label: "Cancel", danger: false, go: () => root.pending = null }]
                                : [{ label: "End task", danger: false, go: () => root.act("term") },
                                   { label: "Force kill", danger: true, go: () => root.act("kill") }]
                            Rectangle {
                                id: btn
                                required property var modelData
                                readonly property bool enabled: root.pending || root.current
                                implicitWidth: btnText.implicitWidth + 24
                                implicitHeight: 32
                                radius: 10
                                opacity: enabled ? 1 : 0.4
                                color: modelData.danger
                                    ? (btnHover.hovered && enabled ? Qt.lighter(root.c("error", "#f38ba8"), 1.1) : root.c("error", "#f38ba8"))
                                    : (btnHover.hovered && enabled ? root.c("surfaceContainerHighest", "#313244") : root.c("surfaceContainer", "#1e1e2e"))
                                HoverHandler { id: btnHover; cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                                TapHandler { onTapped: if (btn.enabled) { btn.modelData.go(); search.forceActiveFocus(); } }
                                Text {
                                    id: btnText
                                    anchors.centerIn: parent
                                    text: btn.modelData.label
                                    font.family: root.font
                                    font.pointSize: 9
                                    font.weight: Font.Medium
                                    color: btn.modelData.danger ? root.c("onError", "#1e1e2e") : root.c("onSurface", "#cdd6f4")
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: "↑↓ select · Enter expand · Del end · Shift+Del force kill · Tab sort · Ctrl+G group · Ctrl+P pause · Esc clear / close"
                    font.family: root.font
                    font.pointSize: 8
                    color: root.c("outline", "#7f849c")
                }
            }
        }
    }
}
