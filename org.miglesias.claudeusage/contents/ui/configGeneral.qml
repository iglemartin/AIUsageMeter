import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_refreshInterval: refreshSpin.value
    property alias cfg_showRemaining: remainingCheck.checked
    property alias cfg_warnThreshold: warnSpin.value
    property alias cfg_critThreshold: critSpin.value
    property alias cfg_autoRefreshToken: refreshTokenCheck.checked
    property alias cfg_useThresholdColors: thresholdCheck.checked
    property alias cfg_showBar: showBarCheck.checked
    property alias cfg_showPercent: showPercentCheck.checked
    property alias cfg_showReset: showResetCheck.checked

    // String ComboBoxes: handled manually
    property string cfg_panelMetric
    property string cfg_panelMetricDefault: "five_hour"
    property string cfg_panelStyle
    property string cfg_panelStyleDefault: "bar"

    QQC2.SpinBox {
        id: refreshSpin
        Kirigami.FormData.label: i18n("Refresh every:")
        from: 30
        to: 3600
        stepSize: 30
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

    QQC2.CheckBox {
        id: thresholdCheck
        Kirigami.FormData.label: i18n("Color:")
        text: i18n("Use alert colors (green/amber/red) instead of Claude orange")
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

    QQC2.CheckBox {
        id: refreshTokenCheck
        Kirigami.FormData.label: i18n("Session:")
        text: i18n("Automatically renew the token when it expires")
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        wrapMode: Text.WordWrap
        opacity: 0.7
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        text: i18n("Renewing rewrites ~/.claude/.credentials.json atomically (with a .widgetbak backup), preserving the rest. If disabled, the widget only reads the token and will show a notice when it expires.")
    }
}
