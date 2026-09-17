import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ----------------------------- state -----------------------------
    property real fiveHourUtil: -1
    property var fiveHourReset: null
    property real sevenDayUtil: -1
    property var sevenDayReset: null
    property string lastError: ""
    property double lastUpdated: 0        // epoch ms of the last reading from Claude Code
    property bool connected: true         // statusline.sh is Claude Code's status line
    property int tick: 0   // incremented to refresh the countdowns

    readonly property color accentOrange: "#D97757"   // default accent orange

    readonly property string helperPath:
        Qt.resolvedUrl("../code/helper.sh").toString().replace(/^file:\/\//, "")

    // font chosen in the settings ("" = system font)
    readonly property string fontFamily: Plasmoid.configuration.fontFamily.length > 0
                                         ? Plasmoid.configuration.fontFamily
                                         : Kirigami.Theme.defaultFont.family

    readonly property bool hasData: fiveHourUtil >= 0 || sevenDayUtil >= 0

    // Current values: once a window's reset time has passed, its usage is 0
    // until Claude Code reports the new window.
    readonly property real fiveHourNow: { root.tick; return windowUtil(fiveHourUtil, fiveHourReset); }
    readonly property var fiveHourResetNow: { root.tick; return windowReset(fiveHourReset); }
    readonly property real sevenDayNow: { root.tick; return windowUtil(sevenDayUtil, sevenDayReset); }
    readonly property var sevenDayResetNow: { root.tick; return windowReset(sevenDayReset); }

    // metric shown in the panel
    readonly property real panelUtil:
        Plasmoid.configuration.panelMetric === "seven_day" ? sevenDayNow : fiveHourNow
    readonly property var panelReset:
        Plasmoid.configuration.panelMetric === "seven_day" ? sevenDayResetNow : fiveHourResetNow
    readonly property real displayValue: {
        if (panelUtil < 0)
            return 0;
        return Plasmoid.configuration.showRemaining ? Math.max(0, 100 - panelUtil) : panelUtil;
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: "utilities-system-monitor"

    // --------------------------- utilities ---------------------------
    function colorFor(util) {
        if (util < 0)
            return Kirigami.Theme.disabledTextColor;
        if (!Plasmoid.configuration.useThresholdColors)
            return root.accentOrange;
        if (util >= Plasmoid.configuration.critThreshold)
            return Kirigami.Theme.negativeTextColor;
        if (util >= Plasmoid.configuration.warnThreshold)
            return Kirigami.Theme.neutralTextColor;
        return Kirigami.Theme.positiveTextColor;
    }

    function fmtCountdown(d) {
        if (!d || isNaN(d.getTime()))
            return "—";
        var ms = d.getTime() - Date.now();
        if (ms <= 0)
            return i18n("now");
        var s = Math.floor(ms / 1000);
        var days = Math.floor(s / 86400);
        s -= days * 86400;
        var h = Math.floor(s / 3600);
        s -= h * 3600;
        var m = Math.floor(s / 60);
        if (days > 0)
            return i18n("%1 d %2 h", days, h);
        if (h > 0)
            return i18n("%1 h %2 min", h, m);
        return i18n("%1 min", m);
    }

    // compact version for the panel: "2d14h", "3h04", "34m"
    function fmtCountdownShort(d) {
        if (!d || isNaN(d.getTime()))
            return "";
        var ms = d.getTime() - Date.now();
        if (ms <= 0)
            return i18n("0m");
        var s = Math.floor(ms / 1000);
        var days = Math.floor(s / 86400);
        s -= days * 86400;
        var h = Math.floor(s / 3600);
        s -= h * 3600;
        var m = Math.floor(s / 60);
        if (days > 0)
            return days + "d" + h + "h";
        if (h > 0)
            return h + "h" + (m < 10 ? "0" : "") + m;
        return m + "m";
    }

    function windowUtil(util, reset) {
        if (util < 0)
            return -1;
        if (reset && reset.getTime() <= Date.now())
            return 0;
        return util;
    }

    function windowReset(reset) {
        return (reset && reset.getTime() > Date.now()) ? reset : null;
    }

    function fmtAge(ms) {
        var mins = Math.floor((Date.now() - ms) / 60000);
        if (mins < 1)
            return i18n("less than a minute ago");
        if (mins < 60)
            return i18np("1 min ago", "%1 min ago", mins);
        var hours = Math.floor(mins / 60);
        if (hours < 48)
            return i18np("1 h ago", "%1 h ago", hours);
        return i18np("1 day ago", "%1 days ago", Math.floor(hours / 24));
    }

    function errorText(code) {
        switch (code) {
        case "not_connected":
            return i18n("Not connected to Claude Code.");
        case "no_data":
            return i18n("No reading yet: use Claude Code and it will show up here.");
        case "no_jq":
            return i18n("Missing system dependency (jq).");
        case "write_failed":
        case "invalid_settings":
            return i18n("Couldn't update ~/.claude/settings.json (%1).", code);
        default:
            return i18n("Couldn't read the usage data (%1).", code);
        }
    }

    // informational states: nothing is broken
    function errorIsTransient(code) {
        return code === "no_data" || code === "parse" || code === "no_output";
    }

    function epochDate(secs) {
        return (typeof secs === "number" && secs > 0) ? new Date(secs * 1000) : null;
    }

    function handleData(stdout) {
        var txt = (stdout || "").trim();
        if (txt.length === 0) {
            root.lastError = "no_output";
            return;
        }
        var obj;
        try {
            obj = JSON.parse(txt);
        } catch (e) {
            root.lastError = "parse";
            return;
        }
        if (obj.error) {
            if (obj.error === "not_connected" || obj.error === "no_data")
                root.connected = obj.error !== "not_connected";
            root.lastError = obj.error;
            return;
        }
        root.connected = obj.connected !== false;
        root.lastError = root.connected ? "" : "not_connected";
        if (obj.five_hour) {
            root.fiveHourUtil = obj.five_hour.used_percentage;
            root.fiveHourReset = root.epochDate(obj.five_hour.resets_at);
        }
        if (obj.seven_day) {
            root.sevenDayUtil = obj.seven_day.used_percentage;
            root.sevenDayReset = root.epochDate(obj.seven_day.resets_at);
        }
        root.lastUpdated = (obj.updated_at || 0) * 1000;
    }

    function refresh() {
        helper.run("read");
    }

    function connectClaudeCode() {
        helper.run("connect");
    }

    // --------------------------- execution ---------------------------
    // Everything goes through helper.sh, which only reads the cache written by
    // the status line bridge (and edits settings.json on connect).
    P5Support.DataSource {
        id: helper
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            helper.disconnectSource(sourceName);
            if (sourceName.endsWith(" read"))
                root.handleData(data["stdout"]);
            else
                root.refresh();
        }

        function run(action) {
            var cmd = "/bin/sh '" + root.helperPath + "' " + action;
            if (connectedSources.indexOf(cmd) < 0)
                connectSource(cmd);
        }
    }

    Timer {
        id: pollTimer
        interval: Math.max(5, Plasmoid.configuration.refreshInterval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // refreshes the UI countdowns
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    // ----------------------------- tooltip -----------------------------
    toolTipMainText: i18n("AI Usage Meter")
    toolTipSubText: {
        root.tick; // dependency to recompute
        if (!root.hasData)
            return root.lastError.length > 0 ? root.errorText(root.lastError) : i18n("Loading…");
        var txt = i18n("5 h: %1% used · resets in %2\n7 days: %3% used · resets in %4",
                       Math.round(root.fiveHourNow), root.fmtCountdown(root.fiveHourResetNow),
                       Math.round(root.sevenDayNow), root.fmtCountdown(root.sevenDayResetNow));
        txt += "\n" + i18n("Last reading from Claude Code: %1", root.fmtAge(root.lastUpdated));
        if (root.lastError.length > 0)
            txt += "\n" + root.errorText(root.lastError);
        return txt;
    }

    // ------------------------ context menu ------------------------
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            onTriggered: root.refresh()
        },
        PlasmaCore.Action {
            text: i18n("Show weekly limit in panel")
            icon.name: "view-calendar-week"
            checkable: true
            checked: Plasmoid.configuration.panelMetric === "seven_day"
            onTriggered: {
                Plasmoid.configuration.panelMetric =
                    (Plasmoid.configuration.panelMetric === "seven_day") ? "five_hour" : "seven_day";
            }
        },
        PlasmaCore.Action {
            isSeparator: true
        },
        PlasmaCore.Action {
            text: i18n("About AI Usage Meter…")
            icon.name: "help-about"
            onTriggered: {
                aboutLoader.active = true;
                aboutLoader.item.show();
                aboutLoader.item.raise();
                aboutLoader.item.requestActivate();
            }
        }
    ]

    // created on demand and destroyed when closed
    Loader {
        id: aboutLoader
        active: false
        sourceComponent: AboutDialog {
            metaData: Plasmoid.metaData
            onClosing: aboutLoader.active = false
        }
    }

    // ---------------------- compact representation ----------------------
    compactRepresentation: MouseArea {
        id: compactRoot
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property bool barStyle: Plasmoid.configuration.panelStyle === "bar"
        // exact width = bar content + side margins
        readonly property real barContentWidth: panelBar.implicitWidth + 2 * Kirigami.Units.smallSpacing

        Layout.minimumWidth: vertical
                             ? 0
                             : (barStyle ? barContentWidth : compactRoot.height)
        Layout.preferredWidth: vertical
                               ? 0
                               : (barStyle ? barContentWidth : compactRoot.height)
        Layout.minimumHeight: vertical
                              ? (barStyle ? Math.round(Kirigami.Units.gridUnit * 1.4) : compactRoot.width)
                              : 0

        // ring
        UsageRing {
            visible: !compactRoot.barStyle
            anchors.centerIn: parent
            height: Math.min(compactRoot.height, compactRoot.width)
            width: height
            value: root.panelUtil < 0 ? 0 : root.panelUtil
            progressColor: root.colorFor(root.panelUtil)
            textColor: Kirigami.Theme.textColor
            fontFamily: Plasmoid.configuration.fontFamily
            fontPointSize: Plasmoid.configuration.fontSize
            fontBold: Plasmoid.configuration.fontBold
            centerText: root.panelUtil < 0
                        ? (root.lastError.length > 0 ? "!" : "…")
                        : (Plasmoid.configuration.showPercent ? Math.round(root.displayValue) : "")
        }

        // horizontal bar
        UsageBar {
            id: panelBar
            visible: compactRoot.barStyle
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            value: root.panelUtil < 0 ? 0 : root.panelUtil
            fillColor: root.colorFor(root.panelUtil)
            showBar: Plasmoid.configuration.showBar
            fontFamily: Plasmoid.configuration.fontFamily
            fontPointSize: Plasmoid.configuration.fontSize
            fontBold: Plasmoid.configuration.fontBold
            label: {
                root.tick; // recompute the countdown
                if (root.panelUtil < 0)
                    return root.lastError.length > 0 ? "!" : "…";
                var parts = [];
                if (Plasmoid.configuration.showPercent)
                    parts.push(Math.round(root.displayValue) + "%");
                if (Plasmoid.configuration.showReset) {
                    var t = root.fmtCountdownShort(root.panelReset);
                    if (t.length > 0)
                        parts.push(t);
                }
                return parts.join(" · ");
            }
        }
    }

    // ----------------------- full representation -----------------------
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 15
        spacing: Kirigami.Units.largeSpacing

        // header
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading {
                level: 2
                font.family: root.fontFamily
                text: i18n("AI Usage Meter")
            }
            Item { Layout.fillWidth: true }
            Kirigami.Icon {
                visible: root.lastError.length > 0
                source: root.errorIsTransient(root.lastError) ? "dialog-information" : "dialog-warning"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                HoverHandler { id: errHover }
                QQC2.ToolTip.text: root.errorText(root.lastError)
                QQC2.ToolTip.visible: errHover.hovered && root.lastError.length > 0
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("Refresh now")
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: root.refresh()
            }
        }

        // the two windows
        RowLayout {
            id: cardsRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing

            // both cards share the same width and stretch to fill the popup,
            // so there is no leftover space and the separator stays centered
            readonly property real cardWidth: Math.max(fiveHourCard.implicitWidth,
                                                       sevenDayCard.implicitWidth)

            UsageCard {
                id: fiveHourCard
                Layout.fillWidth: true
                Layout.minimumWidth: cardsRow.cardWidth
                Layout.preferredWidth: cardsRow.cardWidth
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                title: i18n("Last 5 hours")
                fontFamily: root.fontFamily
                util: root.fiveHourNow
                accentColor: root.colorFor(root.fiveHourNow)
                countdownText: root.fmtCountdown(root.fiveHourResetNow)
            }

            Kirigami.Separator { Layout.fillHeight: true }

            UsageCard {
                id: sevenDayCard
                Layout.fillWidth: true
                Layout.minimumWidth: cardsRow.cardWidth
                Layout.preferredWidth: cardsRow.cardWidth
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                title: i18n("Last 7 days")
                fontFamily: root.fontFamily
                util: root.sevenDayNow
                accentColor: root.colorFor(root.sevenDayNow)
                countdownText: root.fmtCountdown(root.sevenDayResetNow)
            }
        }

        Item { Layout.fillHeight: true }

        // not connected: offer to set up the status line bridge
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.connected
            PlasmaComponents.Button {
                text: i18n("Connect to Claude Code")
                icon.name: "network-connect"
                onClicked: root.connectClaudeCode()
            }
            PlasmaComponents.ToolButton {
                icon.name: "help-contextual"
                display: QQC2.AbstractButton.IconOnly
                text: i18n("The widget reads your usage from Claude Code's status line. Connecting sets it in ~/.claude/settings.json (your current status line keeps working). You can undo it from the settings.")
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // footer: status/last update on a single line (doesn't grow the popup)
        QQC2.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideRight
            opacity: root.lastError.length > 0 ? 0.95 : 0.6
            color: root.lastError.length > 0
                   ? (root.errorIsTransient(root.lastError) ? Kirigami.Theme.neutralTextColor
                                                            : Kirigami.Theme.negativeTextColor)
                   : Kirigami.Theme.textColor
            font.family: root.fontFamily
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            text: {
                root.tick;
                if (root.lastError.length > 0)
                    return root.errorText(root.lastError);
                if (root.lastUpdated <= 0)
                    return i18n("No reading yet");
                return i18n("Last reading from Claude Code: %1", root.fmtAge(root.lastUpdated));
            }
        }
    }
}
