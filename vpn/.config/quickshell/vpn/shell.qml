// VPN panel: pick a Proton VPN country, city or server (Proton CLI, through vpnctl).
// Toggle: `vpnctl panel` (Super+Shift+P), or qs -c vpn ipc call vpn toggle.
// Data: JSON from `vpnctl list` (servers, from the CLI's cache) and `vpnctl status` (polled while open).
// Type to search (country, code, city or server like PT#79), ↑/↓ select, Enter (or click) = connect to
// the fastest server there, →/← (or the chevron) = show/hide cities and servers, Tab = Standard /
// Secure Core / P2P, Ctrl+F = favourite the selected country (or click the star), Ctrl+D = disconnect,
// Esc = clear the search, then close. The top card also shows your public IP
// (click copies it) and, below it, its ISP.
// Connecting moves all traffic to the new tunnel: open connections drop.
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
    property var list: ({})
    property var vpn: ({ connected: false })
    property var pal: ({})
    property string mode: "standard"     // standard | sc (Secure Core) | p2p
    property string query: ""
    property string expandedCountry: ""
    property string expandedCity: ""     // "<code>|<city>"
    property string selectedKey: ""
    property string busy: ""             // "Connecting to Portugal…" while the CLI runs
    property string hint: ""
    property var ipInfo: ({})            // {ip, code, flag, isp} or {error}; refreshed on open and on (dis)connect
    readonly property bool connected: vpn.connected
    onConnectedChanged: ipTimer.restart()  // also catches the drawer toggle

    readonly property string home: Quickshell.env("HOME")
    // Absolute path: the session's PATH (from Hyprland/uwsm) doesn't include ~/.local/bin.
    readonly property string vpnctl: home + "/.local/bin/vpnctl"
    readonly property string font: gsf.status === FontLoader.Ready ? gsf.name : "Inter"
    readonly property var modes: [
        { id: "standard", label: "Standard", args: [] },
        { id: "sc", label: "Secure Core", args: ["-sc"] },
        { id: "p2p", label: "P2P", args: ["--p2p"] }
    ]
    readonly property var modeArgs: modes.find(m => m.id === mode).args
    readonly property int serverCap: 25  // servers shown per city (fastest first)

    readonly property var rows: buildRows(list, mode, query, expandedCountry, expandedCity)
    readonly property int selected: rows.findIndex(r => r.key === selectedKey)

    function c(key, fallback) {
        return pal[key] ? "#" + pal[key] : fallback;
    }

    function say(text) {
        hint = text;
        hintTimer.restart();
    }

    function modeOk(s) {
        if (mode === "sc") return s.secureCore;
        if (mode === "p2p") return s.p2p && !s.secureCore;
        return !s.secureCore;
    }

    // One country with only the servers the current mode allows; fastest = lowest Proton score.
    function summarize(c) {
        const cities = [];
        let count = 0, best = null;
        for (const ci of c.cities) {
            const servers = ci.servers.filter(modeOk);
            if (!servers.length) continue;
            cities.push({ name: ci.name, servers: servers });
            count += servers.length;
            if (!best || servers[0].score < best.score) best = servers[0];
        }
        return { code: c.code, name: c.name, flag: c.flag, cities: cities, count: count, best: best };
    }

    // Flat list of rows (headers, countries, cities, servers) so ↑/↓ can walk everything shown.
    function buildRows(list, mode, query, expandedCountry, expandedCity) {
        const q = query.trim().toLowerCase();
        const favs = list.favorites ?? [];
        const out = [];
        const all = (list.countries ?? []).map(summarize).filter(c => c.count > 0);

        if (q.includes("#")) {  // server name search
            for (const c of all)
                for (const ci of c.cities)
                    for (const s of ci.servers)
                        if (s.name.toLowerCase().includes(q) && out.length < 50)
                            out.push({ kind: "server", key: "s|" + s.name, s: s, code: c.code, city: ci.name, depth: 0 });
            return out;
        }

        const addCountry = (c, cityFilter) => {
            const open = expandedCountry === c.code || cityFilter !== null;
            out.push({ kind: "country", key: "c|" + c.code, c: c, fav: favs.includes(c.code), expanded: open });
            if (!open) return;
            for (const ci of c.cities) {
                if (cityFilter !== null && !ci.name.toLowerCase().includes(cityFilter)) continue;
                const ck = c.code + "|" + ci.name;
                const cityOpen = expandedCity === ck || c.cities.length === 1;
                out.push({ kind: "city", key: "t|" + ck, code: c.code, city: ci, expanded: cityOpen,
                           single: c.cities.length === 1 });
                if (!cityOpen) continue;
                for (const s of ci.servers.slice(0, serverCap))
                    out.push({ kind: "server", key: "s|" + s.name, s: s, code: c.code, city: ci.name, depth: 1 });
                if (ci.servers.length > serverCap)
                    out.push({ kind: "note", key: "n|" + ck,
                               text: `${ci.servers.length - serverCap} more: search for e.g. ${c.code}#` });
            }
        };

        if (q) {
            for (const c of all) {
                if (c.name.toLowerCase().includes(q) || c.code.toLowerCase() === q) addCountry(c, null);
                else if (c.cities.some(ci => ci.name.toLowerCase().includes(q))) addCountry(c, q);
            }
            return out;
        }

        const favRows = all.filter(c => favs.includes(c.code));
        if (favRows.length) {
            out.push({ kind: "header", key: "h|fav", text: "Favourites" });
            for (const c of favRows) addCountry(c, null);
            out.push({ kind: "header", key: "h|all", text: "All countries" });
        }
        for (const c of all) addCountry(c, null);
        return out;
    }

    function selectable(r) {
        return r && (r.kind === "country" || r.kind === "city" || r.kind === "server");
    }

    function move(step) {
        let i = selected;
        for (let n = 0; n < rows.length; n++) {
            i = i < 0 ? (step > 0 ? 0 : rows.length - 1) : Math.max(0, Math.min(rows.length - 1, i + step));
            if (selectable(rows[i])) { selectedKey = rows[i].key; return; }
            if (i === 0 || i === rows.length - 1) return;
        }
    }

    function expand(r, on) {
        if (!r) return;
        if (r.kind === "country") {
            expandedCountry = on ? r.c.code : "";
            expandedCity = "";
        } else if (r.kind === "city" && !r.single) {
            expandedCity = on ? r.code + "|" + r.city.name : "";
        } else if (!on && r.kind === "server" && r.depth > 0) {
            expandedCity = "";
            selectedKey = "t|" + r.code + "|" + r.city;
        }
    }

    function countryName(code) {
        return (list.countries ?? []).find(c => c.code === code)?.name ?? code;
    }

    function connect(r) {
        if (!r || busy) return;
        if (r.kind === "country") run(["connect", "--country", r.c.code, ...modeArgs], `Connecting to ${r.c.name}…`);
        else if (r.kind === "city") run(["connect", "--city", r.city.name, ...modeArgs], `Connecting to ${r.city.name}…`);
        else if (r.kind === "server") run(["connect", r.s.name], `Connecting to ${r.s.name}…`);
    }

    function quickConnect() {
        if (!busy) run(["connect", ...modeArgs], "Connecting to the fastest server…");
    }

    function disconnect() {
        if (!busy && vpn.connected) run(["disconnect"], "Disconnecting…");
    }

    function run(args, label) {
        busy = label;
        action.command = [vpnctl, ...args];
        action.running = true;
    }

    function refreshIp() {
        if (ipProc.running) return;
        ipInfo = Object.assign({}, ipInfo, { loading: true });
        ipProc.running = true;
    }

    function copyIp() {
        if (!ipInfo.ip) return;
        Quickshell.execDetached(["/usr/bin/wl-copy", ipInfo.ip]);
        say("IP copied");
    }

    function ipText() {
        if (ipInfo.loading && !ipInfo.ip) return "IP: checking…";
        if (ipInfo.error || !ipInfo.ip) return "IP: unknown (offline?)";
        return `IP: ${ipInfo.ip}` + (ipInfo.loading ? " · checking…" : "");
    }

    function toggleFav(code) {
        favProc.command = [vpnctl, "fav", code];
        favProc.running = true;
    }

    function loadText(n) {
        return n + "%";
    }

    function loadColour(n) {
        return n >= 90 ? c("error", "#f38ba8") : n >= 70 ? "#fab387" : c("tertiary", "#94e2d5");
    }

    function features(s) {
        return [s.secureCore ? "via " + s.entry : "", s.p2p && mode !== "p2p" ? "P2P" : "", s.tor ? "Tor" : "",
                s.streaming ? "streaming" : ""].filter(x => x).join(" · ");
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

    Process {
        id: lister
        command: [root.vpnctl, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.list = JSON.parse(text); } catch (e) { root.list = { error: "vpnctl list: bad output" }; }
            }
        }
    }

    Process {
        id: statusProc
        command: [root.vpnctl, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.vpn = JSON.parse(text); } catch (e) {}
            }
        }
    }

    Process {
        id: action
        stdout: StdioCollector { id: actionOut }
        onExited: code => {
            root.busy = "";
            if (code !== 0) root.say(actionOut.text.trim() || "Proton VPN CLI failed");
            statusProc.running = true;
            lister.running = true;  // the CLI refreshes server loads on connect
            ipTimer.restart();
        }
    }

    Process {
        id: ipProc
        command: [root.vpnctl, "ip"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.ipInfo = JSON.parse(text); } catch (e) { root.ipInfo = { error: "bad output" }; }
            }
        }
    }

    // The new route needs a moment after a (dis)connect before the lookup goes through the tunnel.
    Timer {
        id: ipTimer
        interval: 1500
        onTriggered: root.refreshIp()
    }

    Process {
        id: favProc
        onExited: lister.running = true
    }

    Timer {
        id: hintTimer
        interval: 4000
        onTriggered: root.hint = ""
    }

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!statusProc.running) statusProc.running = true
    }

    IpcHandler {
        target: "vpn"

        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            schemeFile.reload();
            root.query = "";
            root.expandedCountry = "";
            root.expandedCity = "";
            root.selectedKey = "";
            if (!lister.running) lister.running = true;
            root.refreshIp();
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
        WlrLayershell.namespace: "vpn"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusiveZone: 0  // sit beside Caelestia's bar instead of reserving space

        anchors.left: true
        anchors.top: true
        margins.left: 10
        margins.top: 10

        implicitWidth: 440
        implicitHeight: Math.min(body.implicitHeight + listBox.implicitHeight + footer.implicitHeight + 40 + 28,
                                 Math.round((screen ? screen.height : 1080) * 0.75))

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
                    id: body
                    Layout.fillWidth: true
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "VPN"
                            font.family: root.font
                            font.pointSize: 13
                            font.weight: Font.DemiBold
                            color: root.c("onSurface", "#cdd6f4")
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.busy || (root.vpn.connected ? "connected" : "not connected")
                            font.family: root.font
                            font.pointSize: 9
                            color: root.vpn.connected && !root.busy ? root.c("primary", "#cba6f7") : root.c("onSurfaceVariant", "#a6adc8")
                        }
                    }

                    // Current connection + quick connect / disconnect
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: statusRow.implicitHeight + 20
                        radius: 14
                        color: root.vpn.connected ? root.c("primaryContainer", "#45475a") : root.c("surfaceContainerHigh", "#2a2a3c")

                        RowLayout {
                            id: statusRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 12

                            Text {
                                text: root.vpn.connected ? (root.vpn.flag || "🔒") : "🔓"
                                font.pointSize: 18
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: root.vpn.connected ? `${root.vpn.server}` + (root.vpn.secureCore ? ` (Secure Core via ${root.vpn.entry})` : "")
                                                             : "Not protected"
                                    font.family: root.font
                                    font.pointSize: 10.5
                                    font.weight: Font.Medium
                                    color: root.vpn.connected ? root.c("onPrimaryContainer", "#cdd6f4") : root.c("onSurface", "#cdd6f4")
                                }
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: root.vpn.connected
                                          ? [root.vpn.city, root.vpn.country].filter(x => x).join(", ") + (root.vpn.load !== undefined ? ` · load ${root.vpn.load}%` : "")
                                          : "Your real IP is visible"
                                    font.family: root.font
                                    font.pointSize: 8.5
                                    color: root.vpn.connected ? root.c("onPrimaryContainer", "#cdd6f4") : root.c("onSurfaceVariant", "#a6adc8")
                                }
                                Text {  // public IP as the internet sees it; click copies
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: root.ipText()
                                    font.family: root.font
                                    font.pointSize: 8.5
                                    font.weight: ipHover.hovered ? Font.Medium : Font.Normal
                                    color: root.vpn.connected ? root.c("onPrimaryContainer", "#cdd6f4") : root.c("onSurfaceVariant", "#a6adc8")
                                    HoverHandler { id: ipHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.copyIp() }
                                }
                                Text {  // who the IP belongs to: your ISP when unprotected, Proton AG on the VPN
                                    Layout.fillWidth: true
                                    visible: !!root.ipInfo.isp
                                    elide: Text.ElideRight
                                    text: root.ipInfo.isp ?? ""
                                    font.family: root.font
                                    font.pointSize: 8.5
                                    color: root.vpn.connected ? root.c("onPrimaryContainer", "#cdd6f4") : root.c("onSurfaceVariant", "#a6adc8")
                                }
                            }
                            Rectangle {
                                implicitWidth: btnText.implicitWidth + 24
                                implicitHeight: btnText.implicitHeight + 14
                                radius: height / 2
                                opacity: root.busy ? 0.5 : 1
                                color: root.vpn.connected ? root.c("surfaceContainer", "#1e1e2e") : root.c("primary", "#cba6f7")
                                Text {
                                    id: btnText
                                    anchors.centerIn: parent
                                    text: root.vpn.connected ? "Disconnect" : "Quick connect"
                                    font.family: root.font
                                    font.pointSize: 9
                                    font.weight: Font.Medium
                                    color: root.vpn.connected ? root.c("onSurface", "#cdd6f4") : root.c("onPrimary", "#1e1e2e")
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.vpn.connected ? root.disconnect() : root.quickConnect()
                                }
                            }
                        }
                    }

                    // Mode: which servers are listed and how "fastest" connects pick one
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.modes
                            Rectangle {
                                required property var modelData
                                readonly property bool on: root.mode === modelData.id
                                implicitWidth: chip.implicitWidth + 22
                                implicitHeight: chip.implicitHeight + 12
                                radius: height / 2
                                color: on ? root.c("secondaryContainer", "#45475a") : "transparent"
                                border.width: on ? 0 : 1
                                border.color: root.c("outlineVariant", "#45475a")
                                Text {
                                    id: chip
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.family: root.font
                                    font.pointSize: 9
                                    color: parent.on ? root.c("onSecondaryContainer", "#cdd6f4") : root.c("onSurfaceVariant", "#a6adc8")
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.mode = parent.modelData.id
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
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
                            onTextChanged: { root.query = text; root.selectedKey = ""; }
                            font.family: root.font
                            font.pointSize: 10
                            color: root.c("onSurface", "#cdd6f4")
                            selectionColor: root.c("primary", "#cba6f7")
                            selectedTextColor: root.c("onPrimary", "#1e1e2e")
                            clip: true

                            Text {
                                visible: !search.text
                                text: "Search country, city or server (PT#79)"
                                font: search.font
                                color: root.c("outline", "#7f849c")
                            }

                            Keys.onPressed: event => {
                                const r = root.rows[root.selected];
                                const ctrl = event.modifiers & Qt.ControlModifier;
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    if (search.text) search.text = "";
                                    else root.open = false;
                                    break;
                                case Qt.Key_Down: root.move(1); break;
                                case Qt.Key_Up: root.move(-1); break;
                                case Qt.Key_PageDown: root.move(10); break;
                                case Qt.Key_PageUp: root.move(-10); break;
                                case Qt.Key_Return: case Qt.Key_Enter:
                                    if (r) root.connect(r);
                                    else root.say("Select a country first (↑↓)");
                                    break;
                                case Qt.Key_Right:
                                    if (!r || search.cursorPosition < search.text.length) return;
                                    root.expand(r, true);
                                    break;
                                case Qt.Key_Left:
                                    if (!r || search.cursorPosition > 0) return;
                                    root.expand(r, false);
                                    break;
                                case Qt.Key_Tab: {
                                    const i = root.modes.findIndex(m => m.id === root.mode);
                                    root.mode = root.modes[(i + 1) % root.modes.length].id;
                                    break;
                                }
                                case Qt.Key_F:
                                    if (!ctrl) return;
                                    if (r && r.kind === "country") root.toggleFav(r.c.code);
                                    else root.say("Select a country to favourite");
                                    break;
                                case Qt.Key_D:
                                    if (!ctrl) return;
                                    root.disconnect();
                                    break;
                                default: return;
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        visible: !!root.list.error
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: root.list.error ?? ""
                        font.family: root.font
                        font.pointSize: 9
                        color: "#fab387"
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
                        spacing: 4

                        Text {
                            visible: root.rows.length === 0 && !!root.list.countries
                            text: root.query ? "No match" : "No servers in this mode"
                            font.family: root.font
                            font.pointSize: 9
                            color: root.c("outline", "#7f849c")
                        }

                        Repeater {
                            model: root.rows

                            Loader {
                                id: row
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                sourceComponent: modelData.kind === "header" ? headerRow
                                               : modelData.kind === "note" ? noteRow : itemRow
                            }
                        }
                    }
                }

                Text {
                    id: footer
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: root.hint || "↑↓ select · Enter connect · →← expand · Tab mode · Ctrl+F favourite · Ctrl+D disconnect · Esc"
                    wrapMode: Text.Wrap
                    font.weight: root.hint ? Font.DemiBold : Font.Normal
                    font.family: root.font
                    font.pointSize: 8
                    color: root.c("outline", "#7f849c")
                }
            }
        }
    }

    Component {
        id: headerRow
        Text {
            property var modelData: parent.modelData
            topPadding: modelData.key === "h|fav" ? 0 : 8
            bottomPadding: 2
            text: modelData.text
            font.family: root.font
            font.pointSize: 8.5
            font.weight: Font.DemiBold
            color: root.c("primary", "#cba6f7")
        }
    }

    Component {
        id: noteRow
        Text {
            property var modelData: parent.modelData
            leftPadding: 52
            text: modelData.text
            font.family: root.font
            font.pointSize: 8
            color: root.c("outline", "#7f849c")
        }
    }

    // Country, city or server row
    Component {
        id: itemRow
        Rectangle {
            id: item
            property var modelData: parent.modelData
            readonly property string kind: modelData.kind
            readonly property bool sel: root.selectedKey === modelData.key
            readonly property bool current: root.vpn.connected && (
                kind === "server" ? root.vpn.server === modelData.s.name
                : kind === "country" ? root.vpn.code === modelData.c.code
                : root.vpn.code === modelData.code && root.vpn.city === modelData.city.name)
            readonly property int indent: kind === "country" ? 0 : kind === "city" ? 26 : (modelData.depth ? 52 : 0)

            implicitHeight: line.implicitHeight + (kind === "country" ? 16 : 10)
            radius: 10
            color: sel ? root.c("surfaceContainerHighest", "#313244")
                 : hover.hovered ? root.c("surfaceContainerHigh", "#2a2a3c") : "transparent"
            border.width: sel ? 1 : 0
            border.color: root.c("primary", "#cba6f7")

            function reveal() {
                const p = mapToItem(listBox, 0, 0);
                if (p.y < flick.contentY) flick.contentY = p.y;
                else if (p.y + height > flick.contentY + flick.height)
                    flick.contentY = Math.min(p.y + height - flick.height, Math.max(0, flick.contentHeight - flick.height));
            }
            onSelChanged: if (sel) Qt.callLater(reveal)

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedKey = item.modelData.key;
                    root.connect(item.modelData);
                }
            }

            RowLayout {
                id: line
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10 + item.indent
                anchors.rightMargin: 6
                spacing: 10

                Text {  // flag / bullet
                    text: item.kind === "country" ? item.modelData.c.flag : item.kind === "city" ? "" : ""
                    visible: text !== ""
                    font.pointSize: 14
                }
                Rectangle {  // connected marker
                    visible: item.current
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: root.c("primary", "#cba6f7")
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: item.kind === "country" ? item.modelData.c.name
                            : item.kind === "city" ? item.modelData.city.name
                            : item.modelData.s.name + (item.modelData.depth ? "" : ` · ${item.modelData.city}`)
                        font.family: root.font
                        font.pointSize: item.kind === "country" ? 10 : 9.5
                        font.weight: item.kind === "country" ? Font.Medium : Font.Normal
                        color: item.current ? root.c("primary", "#cba6f7") : root.c("onSurface", "#cdd6f4")
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        elide: Text.ElideRight
                        text: item.kind === "country" ? `${item.modelData.c.count} servers · ${item.modelData.c.cities.length} ${item.modelData.c.cities.length === 1 ? "city" : "cities"}`
                            : item.kind === "city" ? `${item.modelData.city.servers.length} servers`
                            : root.features(item.modelData.s)
                        font.family: root.font
                        font.pointSize: 8
                        color: root.c("onSurfaceVariant", "#a6adc8")
                    }
                }
                Text {  // load of the server Enter would pick
                    readonly property int load: item.kind === "country" ? item.modelData.c.best.load
                                              : item.kind === "city" ? item.modelData.city.servers[0].load
                                              : item.modelData.s.load
                    text: root.loadText(load)
                    font.family: root.font
                    font.pointSize: 8.5
                    color: root.loadColour(load)
                }
                Text {  // favourite star (countries)
                    visible: item.kind === "country"
                    text: item.modelData.fav ? "★" : "☆"
                    font.pointSize: 12
                    color: item.modelData.fav ? root.c("primary", "#cba6f7") : root.c("outline", "#7f849c")
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleFav(item.modelData.c.code)
                    }
                }
                Text {  // expand chevron
                    readonly property bool can: item.kind === "country" || (item.kind === "city" && !item.modelData.single)
                    opacity: can ? 1 : 0
                    text: item.modelData.expanded ? "▴" : "▾"
                    font.pointSize: 11
                    color: root.c("onSurfaceVariant", "#a6adc8")
                    MouseArea {
                        enabled: parent.can
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedKey = item.modelData.key;
                            root.expand(item.modelData, !item.modelData.expanded);
                        }
                    }
                }
            }
        }
    }
}
