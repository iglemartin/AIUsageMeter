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
    property double lastUpdated: 0
    property double rateLimitedUntil: 0   // epoch ms: don't query until past this mark
    property int tick: 0   // incremented to refresh the countdowns

    readonly property color claudeOrange: "#D97757"   // Claude's signature orange

    readonly property string scriptPath:
        Qt.resolvedUrl("../code/usage.sh").toString().replace(/^file:\/\//, "")

    // font chosen in the settings ("" = system font)
    readonly property string fontFamily: Plasmoid.configuration.fontFamily.length > 0
                                         ? Plasmoid.configuration.fontFamily
                                         : Kirigami.Theme.defaultFont.family

    readonly property bool hasData: fiveHourUtil >= 0 || sevenDayUtil >= 0

    // metric shown in the panel
    readonly property real panelUtil:
        Plasmoid.configuration.panelMetric === "seven_day" ? sevenDayUtil : fiveHourUtil
    readonly property var panelReset:
        Plasmoid.configuration.panelMetric === "seven_day" ? sevenDayReset : fiveHourReset
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
            return root.claudeOrange;
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

    function errorText(code) {
        switch (code) {
        case "no_credentials":
        case "no_token":
            return i18n("No Claude session found. Sign in with Claude Code.");
        case "authentication_error":
        case "invalid_grant":
            return i18n("Token expired. Open Claude Code to renew the session.");
        case "no_curl":
        case "no_jq":
            return i18n("Missing system dependencies (curl / jq).");
        case "rate_limit_error":
            return i18n("Rate limit reached; retrying in a few minutes…");
        default:
            return i18n("Couldn't fetch usage (%1).", code);
        }
    }

    // transient errors: previous data is still valid
    function errorIsTransient(code) {
        return code === "rate_limit_error" || code === "request_failed"
            || code === "parse" || code === "no_output" || code === "exec";
    }

    function handleData(stdout, stderr, exitCode) {
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
            root.lastError = obj.error;
            if (obj.error === "rate_limit_error")
                root.rateLimitedUntil = Date.now() + 300000; // wait 5 min
            return;
        }
        root.lastError = "";
        root.rateLimitedUntil = 0;
        if (obj.five_hour) {
            root.fiveHourUtil = obj.five_hour.utilization;
            root.fiveHourReset = obj.five_hour.resets_at ? new Date(obj.five_hour.resets_at) : null;
        }
        if (obj.seven_day) {
            root.sevenDayUtil = obj.seven_day.utilization;
            root.sevenDayReset = obj.seven_day.resets_at ? new Date(obj.seven_day.resets_at) : null;
        }
        root.lastUpdated = Date.now();
    }

    // --------------------------- execution ---------------------------
    P5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            execSource.disconnectSource(sourceName);
            root.handleData(data["stdout"], data["stderr"], data["exit code"]);
        }

        function run() {
            if (connectedSources.length > 0)
                return; // a run is already in progress
            if (Date.now() < root.rateLimitedUntil)
                return; // waiting after a rate_limit_error
            var allow = Plasmoid.configuration.autoRefreshToken ? "1" : "0";
            connectSource("/bin/sh '" + root.scriptPath + "' " + allow);
        }
    }

    Timer {
        id: pollTimer
        interval: Math.max(15, Plasmoid.configuration.refreshInterval) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: execSource.run()
    }

    // refreshes the UI countdowns
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    // ----------------------------- tooltip -----------------------------
    toolTipMainText: i18n("Claude Usage")
    toolTipSubText: {
        root.tick; // dependency to recompute
        if (root.lastError.length > 0)
            return root.errorText(root.lastError);
        if (!root.hasData)
            return i18n("Loading…");
        return i18n("5 h: %1% used · resets in %2\n7 days: %3% used · resets in %4",
                    Math.round(root.fiveHourUtil), root.fmtCountdown(root.fiveHourReset),
                    Math.round(root.sevenDayUtil), root.fmtCountdown(root.sevenDayReset));
    }

    // ------------------------ context menu ------------------------
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh now")
            icon.name: "view-refresh"
            onTriggered: execSource.run()
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
            text: i18n("About Claude Usage…")
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
                text: i18n("Claude Usage")
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
                onClicked: execSource.run()
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
                util: root.fiveHourUtil
                accentColor: root.colorFor(root.fiveHourUtil)
                countdownText: { root.tick; return root.fmtCountdown(root.fiveHourReset); }
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
                util: root.sevenDayUtil
                accentColor: root.colorFor(root.sevenDayUtil)
                countdownText: { root.tick; return root.fmtCountdown(root.sevenDayReset); }
            }
        }

        Item { Layout.fillHeight: true }

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
                    return i18n("Not updated yet");
                var secs = Math.floor((Date.now() - root.lastUpdated) / 1000);
                if (secs < 60)
                    return i18n("Updated %1 s ago", secs);
                return i18n("Updated %1 min ago", Math.floor(secs / 60));
            }
        }
    }
}
