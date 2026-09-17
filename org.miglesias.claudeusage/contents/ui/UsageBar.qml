import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Rounded horizontal progress bar (media-player style) with an optional label
// on the right. It sizes to its content: the bar has a fixed length (barLength)
// and the label takes what it needs, so that
// implicitWidth = bar + spacing + label (no leftover width).
Item {
    id: bar

    property real value: 0                       // 0..100
    property color fillColor: "#D97757"          // Claude's signature orange
    property color trackColor: Qt.rgba(0.5, 0.5, 0.5, 0.30)
    property color textColor: Kirigami.Theme.textColor
    property string label: ""
    property bool showLabel: true
    property bool showBar: true
    property real barLength: Kirigami.Units.gridUnit * 4
    property string fontFamily: ""               // "" = system font
    property int fontPointSize: 0                // 0 = automatic (fits the height)
    property bool fontBold: true

    implicitWidth: row.implicitWidth
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.2)

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            id: track
            visible: bar.showBar
            Layout.preferredWidth: bar.barLength
            Layout.preferredHeight: Math.max(4, Math.min(bar.height * 0.45, Kirigami.Units.gridUnit * 0.5))
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: bar.trackColor

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, bar.value / 100))
                radius: height / 2
                color: bar.fillColor

                Behavior on width {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Text {
            id: lbl
            visible: bar.showLabel && text.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: bar.label
            color: bar.textColor
            // single binding: pointSize and pixelSize are mutually exclusive in QFont
            font: {
                var spec = {
                    family: bar.fontFamily.length > 0 ? bar.fontFamily : Kirigami.Theme.defaultFont.family,
                    bold: bar.fontBold
                };
                if (bar.fontPointSize > 0)
                    spec.pointSize = bar.fontPointSize;
                else
                    spec.pixelSize = Math.max(8, Math.round(bar.height * 0.5));
                return Qt.font(spec);
            }
        }
    }
}
