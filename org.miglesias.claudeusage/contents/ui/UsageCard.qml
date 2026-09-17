import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Card for one usage window: title, large ring and reset detail.
ColumnLayout {
    id: card

    property string title: ""
    property real util: -1               // -1 = no data
    property string countdownText: "—"
    property color accentColor: "#888888"
    property string fontFamily: Kirigami.Theme.defaultFont.family

    spacing: Kirigami.Units.smallSpacing
    Layout.fillWidth: true

    Kirigami.Heading {
        level: 5
        text: card.title
        font.family: card.fontFamily
        Layout.alignment: Qt.AlignHCenter
        opacity: 0.85
    }

    UsageRing {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Kirigami.Units.gridUnit * 5
        implicitHeight: Kirigami.Units.gridUnit * 5
        value: card.util < 0 ? 0 : card.util
        progressColor: card.accentColor
        textColor: Kirigami.Theme.textColor
        fontFamily: card.fontFamily
        centerText: card.util < 0 ? "…" : Math.round(card.util) + "%"
    }

    QQC2.Label {
        Layout.alignment: Qt.AlignHCenter
        text: card.util < 0 ? i18n("no data")
                            : i18n("%1% free", Math.max(0, Math.round(100 - card.util)))
        font.bold: true
        font.family: card.fontFamily
    }

    QQC2.Label {
        Layout.alignment: Qt.AlignHCenter
        text: i18n("Resets in %1", card.countdownText)
        opacity: 0.7
        font.family: card.fontFamily
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
    }
}
