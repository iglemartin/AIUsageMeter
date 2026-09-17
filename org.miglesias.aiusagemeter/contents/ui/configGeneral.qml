import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

import "../code/links.js" as Links

Kirigami.FormLayout {
    id: page

    property alias cfg_refreshInterval: refreshSpin.value
    property alias cfg_showRemaining: remainingCheck.checked
    property alias cfg_warnThreshold: warnSpin.value
    property alias cfg_critThreshold: critSpin.value
    property alias cfg_useThresholdColors: thresholdCheck.checked
    property alias cfg_showBar: showBarCheck.checked
    property alias cfg_showPercent: showPercentCheck.checked
    property alias cfg_showReset: showResetCheck.checked
    property alias cfg_fontSize: fontSizeSpin.value
    property alias cfg_fontBold: fontBoldCheck.checked

    // String ComboBoxes: handled manually
    property string cfg_panelMetric
    property string cfg_panelMetricDefault: "five_hour"
    property string cfg_panelStyle
    property string cfg_panelStyleDefault: "bar"
    property string cfg_fontFamily
    property string cfg_fontFamilyDefault: ""

    // ------------------- Claude Code connection -------------------
    // null = unknown yet
    property var claudeConnected: null
    property string claudeError: ""
    readonly property string helperPath:
        Qt.resolvedUrl("../code/helper.sh").toString().replace(/^file:\/\//, "")

    P5Support.DataSource {
        id: helper
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            helper.disconnectSource(sourceName);
            try {
                var obj = JSON.parse((data["stdout"] || "").trim());
                page.claudeError = obj.error || "";
                if (obj.connected !== undefined)
                    page.claudeConnected = obj.connected;
            } catch (e) {
                page.claudeError = "parse";
            }
        }
        function run(action) {
            connectSource("/bin/sh '" + page.helperPath + "' " + action);
        }
    }

    Component.onCompleted: helper.run("status")

    RowLayout {
        Kirigami.FormData.label: i18n("Claude Code:")
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: page.claudeConnected ? "emblem-success" : "emblem-warning"
            visible: page.claudeConnected !== null
        }
        QQC2.Label {
            text: page.claudeConnected === null ? i18n("Checking…")
                  : page.claudeConnected ? i18n("Connected")
                  : i18n("Not connected")
        }
        QQC2.Button {
            enabled: page.claudeConnected !== null
            text: page.claudeConnected ? i18n("Disconnect") : i18n("Connect")
            icon.name: page.claudeConnected ? "network-disconnect" : "network-connect"
            onClicked: helper.run(page.claudeConnected ? "disconnect" : "connect")
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        visible: page.claudeError.length > 0
        color: Kirigami.Theme.negativeTextColor
        text: i18n("Couldn't update ~/.claude/settings.json (%1).", page.claudeError)
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        opacity: 0.7
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        text: i18n("The widget gets your usage from Claude Code's status line, the documented way: no tokens and no network access. Connecting sets it in ~/.claude/settings.json (with a backup); if you already had a status line it keeps showing, and disconnecting restores it. Readings update while you use Claude Code.")
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: refreshSpin
        Kirigami.FormData.label: i18n("Re-read every:")
        from: 5
        to: 3600
        stepSize: 5
        textFromValue: function (value) { return i18n("%1 s", value); }
        valueFromText: function (text) { return parseInt(text); }
    }

    QQC2.ComboBox {
        id: styleCombo
        Kirigami.FormData.label: i18n("Indicator style:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Horizontal bar"), value: "bar" },
            { text: i18n("Ring"), value: "ring" }
        ]
        onActivated: page.cfg_panelStyle = currentValue
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_panelStyle))
    }

    QQC2.ComboBox {
        id: metricCombo
        Kirigami.FormData.label: i18n("Show in panel:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("5-hour limit"), value: "five_hour" },
            { text: i18n("Weekly limit (7 days)"), value: "seven_day" }
        ]
        onActivated: page.cfg_panelMetric = currentValue
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_panelMetric))
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: showBarCheck
        Kirigami.FormData.label: i18n("Show in panel:")
        text: i18n("Progress bar")
        enabled: page.cfg_panelStyle === "bar"
    }

    QQC2.CheckBox {
        id: showPercentCheck
        text: i18n("Percentage")
    }

    QQC2.CheckBox {
        id: showResetCheck
        text: i18n("Time until reset")
        enabled: page.cfg_panelStyle === "bar"
    }

    QQC2.CheckBox {
        id: remainingCheck
        Kirigami.FormData.label: i18n("Displayed value:")
        text: i18n("Show % remaining instead of used")
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.ComboBox {
        id: fontCombo
        Kirigami.FormData.label: i18n("Font:")
        Layout.maximumWidth: Kirigami.Units.gridUnit * 16
        // index 0 = system font; the rest are the installed families
        model: [i18n("System default")].concat(Qt.fontFamilies())
        onActivated: page.cfg_fontFamily = currentIndex === 0 ? "" : currentText
        Component.onCompleted: {
            var idx = page.cfg_fontFamily.length > 0 ? find(page.cfg_fontFamily) : 0;
            currentIndex = Math.max(0, idx);
        }
        delegate: QQC2.ItemDelegate {
            width: ListView.view ? ListView.view.width : implicitWidth
            text: modelData
            font.family: index === 0 ? Kirigami.Theme.defaultFont.family : modelData
            highlighted: fontCombo.highlightedIndex === index
        }
    }

    QQC2.SpinBox {
        id: fontSizeSpin
        Kirigami.FormData.label: i18n("Panel text size:")
        from: 0
        to: 72
        stepSize: 1
        textFromValue: function (value) {
            return value === 0 ? i18n("Automatic") : i18n("%1 pt", value);
        }
        valueFromText: function (text) {
            var v = parseInt(text);
            return isNaN(v) ? 0 : v;
        }
    }

    QQC2.CheckBox {
        id: fontBoldCheck
        text: i18n("Bold")
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        opacity: 0.7
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        text: i18n("The font applies to the panel and the popup. The size only affects the panel text; \"Automatic\" fits it to the panel height.")
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.CheckBox {
        id: thresholdCheck
        Kirigami.FormData.label: i18n("Color:")
        text: i18n("Use alert colors (green/amber/red) instead of the default orange")
    }

    QQC2.SpinBox {
        id: warnSpin
        Kirigami.FormData.label: i18n("Warning (amber) from:")
        enabled: thresholdCheck.checked
        from: 0
        to: 100
        stepSize: 5
        textFromValue: function (value) { return i18n("%1 %", value); }
        valueFromText: function (text) { return parseInt(text); }
    }

    QQC2.SpinBox {
        id: critSpin
        Kirigami.FormData.label: i18n("Critical (red) from:")
        enabled: thresholdCheck.checked
        from: 0
        to: 100
        stepSize: 5
        textFromValue: function (value) { return i18n("%1 %", value); }
        valueFromText: function (text) { return parseInt(text); }
    }


    Item { Kirigami.FormData.isSection: true }

    QQC2.Button {
        Kirigami.FormData.label: i18n("Support:")
        text: i18n("Buy me a coffee")
        icon.name: "help-donate"
        onClicked: Qt.openUrlExternally(Links.DONATE_URL)
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        opacity: 0.7
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        text: i18n("If you find this widget useful, you can support its development. Contact: %1", Links.AUTHOR_EMAIL)
    }
}
