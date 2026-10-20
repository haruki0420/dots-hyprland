import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.panels.lock

Dialog {
    id: root
    title: Translation.tr("Register your face")
    modal: true
    anchors.centerIn: parent
    width: Math.min(520, parent.width - 32)
    closePolicy: enrollment.running ? Popup.NoAutoClose : Popup.CloseOnEscape
    property string resultText: ""
    property bool helperReady: false
    padding: 20

    background: Rectangle {
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: Appearance.colors.colLayer3
    }
    header: StyledText {
        text: root.title
        padding: 20
        font.pixelSize: Appearance.font.pixelSize.larger
    }

    LidState { id: lidState }

    Process {
        id: helperCheck
        command: ["test", "-x", "/usr/local/libexec/end4-face-enroll"]
        running: true
        onExited: exitCode => root.helperReady = exitCode === 0
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.opened && !root.helperReady
        onTriggered: helperCheck.running = true
    }

    Process {
        id: enrollment
        command: ["pkexec", "/usr/local/libexec/end4-face-enroll", label.text.trim()]
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onExited: exitCode => {
            root.resultText = exitCode === 0 ? Translation.tr("Face registered. You can now enable face unlock after suspend.")
                : exitCode === 126 ? Translation.tr("Registration canceled.")
                : Translation.tr("Could not register your face. Open the camera shutter, face the camera, and try again.")
                    + "\n\n" + (errors.text + "\n" + output.text).trim().slice(-1600);
        }
    }

    contentItem: ColumnLayout {
        spacing: 16
        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            visible: !root.helperReady
            text: Translation.tr("Face registration setup is not complete yet. Finish the system setup before registering.")
        }
        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Translation.tr("Open the laptop lid and camera shutter, then look at the camera. Move your head slightly if the IR light goes dark. Administrator authentication is required to save your face securely.")
        }
        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            visible: !lidState.known || lidState.closed
            text: Translation.tr("Open the laptop lid to register your face.")
        }
        MaterialTextField {
            id: label
            Layout.fillWidth: true
            enabled: !enrollment.running
            maximumLength: 24
            placeholderText: Translation.tr("Face name")
            text: Translation.tr("My face")
        }
        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: enrollment.running
            visible: running
        }
        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: enrollment.running ? Translation.tr("Look at the camera. Waiting for registration…") : root.resultText
            visible: text.length > 0
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            DialogButton {
                buttonText: Translation.tr("Close")
                enabled: !enrollment.running
                onClicked: root.close()
            }
            DialogButton {
                buttonText: Translation.tr("Register")
                enabled: root.helperReady && !enrollment.running && lidState.known && !lidState.closed && label.text.trim().length > 0
                onClicked: {
                    root.resultText = "";
                    enrollment.running = true;
                }
            }
        }
    }
}
