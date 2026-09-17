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
    width: Kirigami.Units.gridUnit * 20
    height: content.implicitHeight + 2 * Kirigami.Units.largeSpacing
    minimumWidth: width
    minimumHeight: height
    maximumWidth: width
    maximumHeight: height

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
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
            Layout.topMargin: Kirigami.Units.largeSpacing
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: dialog.metaData ? dialog.metaData.description : ""
        }

        QQC2.Label {
            Layout.fillWidth: true
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

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.Label {
                Kirigami.FormData.label: i18n("Author:")
                visible: dialog.authorText.length > 0
                text: dialog.authorText
            }
            QQC2.Label {
                Kirigami.FormData.label: i18n("License:")
                text: dialog.metaData ? dialog.metaData.license : ""
            }
            Kirigami.UrlButton {
                Kirigami.FormData.label: i18n("Website:")
                visible: url.length > 0
                url: dialog.metaData ? dialog.metaData.website : ""
            }
        }

        Item { Layout.fillHeight: true }

        QQC2.DialogButtonBox {
            Layout.fillWidth: true
            standardButtons: QQC2.DialogButtonBox.Close
            onRejected: dialog.close()
        }
    }
}
