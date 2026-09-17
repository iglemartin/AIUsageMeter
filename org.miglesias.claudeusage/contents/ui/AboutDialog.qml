import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// "About" window: name, version, description, author, license and website,
// taken from the plasmoid's metadata.json (passed in as `metaData`).
Window {
    id: dialog

    property var metaData: null

    readonly property string authorText: {
        var authors = (metaData && metaData.authors) ? metaData.authors : [];
        var names = [];
        for (var i = 0; i < authors.length; ++i) {
            if (authors[i].name)
                names.push(authors[i].name);
        }
        return names.join(", ");
    }

    title: i18n("About %1", metaData ? metaData.name : "")
    flags: Qt.Dialog

    // window sized to its content (fixed size, not resizable)
    readonly property real margin: Kirigami.Units.gridUnit
    // min/max must not be bound to width/height: the first value would lock them
    readonly property int fitWidth: Math.ceil(Math.max(Kirigami.Units.gridUnit * 20,
                                                       content.implicitWidth + 2 * margin))
    readonly property int fitHeight: Math.ceil(content.implicitHeight + 2 * margin)
    width: fitWidth
    height: fitHeight
    minimumWidth: fitWidth
    maximumWidth: fitWidth
    minimumHeight: fitHeight
    maximumHeight: fitHeight

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor

    ColumnLayout {
        id: content
        x: dialog.margin
        y: dialog.margin
        width: dialog.width - 2 * dialog.margin
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            source: dialog.metaData ? dialog.metaData.iconName : ""
        }

        Kirigami.Heading {
            Layout.alignment: Qt.AlignHCenter
            level: 1
            text: dialog.metaData ? dialog.metaData.name : ""
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.7
            text: i18n("Version %1", dialog.metaData ? dialog.metaData.version : "")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: 1   // wrap to the window width instead of widening it
            Layout.topMargin: Kirigami.Units.largeSpacing
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: dialog.metaData ? dialog.metaData.description : ""
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.preferredWidth: 1   // wrap to the window width instead of widening it
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            text: i18n("Unofficial — not affiliated with Anthropic.")
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                Layout.alignment: Qt.AlignRight
                visible: dialog.authorText.length > 0
                opacity: 0.7
                text: i18n("Author:")
            }
            QQC2.Label {
                visible: dialog.authorText.length > 0
                text: dialog.authorText
            }

            QQC2.Label {
                Layout.alignment: Qt.AlignRight
                opacity: 0.7
                text: i18n("License:")
            }
            QQC2.Label {
                text: dialog.metaData ? dialog.metaData.license : ""
            }

            QQC2.Label {
                Layout.alignment: Qt.AlignRight
                visible: websiteLink.visible
                opacity: 0.7
                text: i18n("Website:")
            }
            Kirigami.UrlButton {
                id: websiteLink
                visible: url.length > 0
                url: dialog.metaData ? dialog.metaData.website : ""
            }
        }

        QQC2.DialogButtonBox {
            Layout.fillWidth: true
            standardButtons: QQC2.DialogButtonBox.Close
            onRejected: dialog.close()
        }
    }
}
