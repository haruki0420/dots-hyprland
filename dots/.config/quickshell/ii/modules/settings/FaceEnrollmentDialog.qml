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
    width: Math.min(560, Math.max(320, (parent?.width ?? 608) - 48))
    padding: 0
    header: null
    footer: null
    background: null
    closePolicy: enrollment.running ? Popup.NoAutoClose : Popup.CloseOnEscape
    property string resultText: ""
    property string resultDetails: ""
    property bool resultSuccess: false
    property bool detailsExpanded: false
    property bool helperReady: false
    readonly property bool canRegister: helperReady && lidState.known && !lidState.closed
        && !enrollment.running && label.text.trim().length > 0

    Overlay.modal: Rectangle { color: "#66000000" }

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
            root.resultSuccess = exitCode === 0;
            root.resultDetails = exitCode === 0 || exitCode === 126 ? ""
                : (errors.text + "\n" + output.text).trim().slice(-1600);
            root.resultText = exitCode === 0
                ? Translation.tr("Face registered. You can now enable face unlock after suspend.")
                : exitCode === 126 ? Translation.tr("Registration canceled.")
                : Translation.tr("Could not register your face. Open the camera shutter, face the camera, and try again.");
        }
    }

    // Use a solid surface, not the translucent overlay colors used by panels.
    contentItem: Rectangle {
        id: card
        implicitHeight: cardLayout.implicitHeight + 48
        color: Appearance.m3colors.m3surfaceContainerHigh
        radius: 28
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant

        ColumnLayout {
            id: cardLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 24
            }
            spacing: 18

            RowLayout {
                spacing: 16
                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: 16
                    color: Appearance.m3colors.m3primaryContainer
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "face"
                        iconSize: 28
                        color: Appearance.m3colors.m3onPrimaryContainer
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    StyledText {
                        Layout.fillWidth: true
                        text: root.title
                        color: Appearance.m3colors.m3onSurface
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: Translation.tr("For unlocking after suspend")
                        color: Appearance.m3colors.m3onSurfaceVariant
                        font.pixelSize: 13
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Open the lid and camera shutter, then look at the camera.")
                color: Appearance.m3colors.m3onSurface
                lineHeight: 1.3
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                StyledText {
                    text: Translation.tr("Face name")
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
                TextField {
                    id: label
                    Layout.fillWidth: true
                    implicitHeight: 50
                    enabled: !enrollment.running
                    maximumLength: 24
                    text: Translation.tr("My face")
                    placeholderText: Translation.tr("Face name")
                    color: Appearance.m3colors.m3onSurface
                    selectionColor: Appearance.m3colors.m3primaryContainer
                    selectedTextColor: Appearance.m3colors.m3onPrimaryContainer
                    font.family: Appearance.font.family.main
                    font.pixelSize: 15
                    leftPadding: 14
                    rightPadding: 14
                    background: Rectangle {
                        radius: 12
                        color: Appearance.m3colors.m3surfaceContainerLow
                        border.width: label.activeFocus ? 2 : 1
                        border.color: label.activeFocus ? Appearance.m3colors.m3primary
                            : Appearance.m3colors.m3outlineVariant
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: statusRow.implicitHeight + 24
                radius: 12
                color: Appearance.m3colors.m3surfaceContainerLow
                RowLayout {
                    id: statusRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 12
                    }
                    spacing: 10
                    BusyIndicator {
                        visible: enrollment.running
                        running: visible
                        implicitWidth: 22
                        implicitHeight: 22
                    }
                    MaterialSymbol {
                        visible: !enrollment.running
                        text: !root.helperReady ? "build_circle"
                            : !lidState.known ? "pending"
                            : lidState.closed ? "laptop_chromebook" : "check_circle"
                        iconSize: 22
                        color: Appearance.m3colors.m3primary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: 13
                        color: Appearance.m3colors.m3onSurfaceVariant
                        text: enrollment.running ? Translation.tr("Look at the camera. Waiting for registration…")
                            : !root.helperReady ? Translation.tr("Face registration setup is not complete yet. Finish the system setup before registering.")
                            : !lidState.known ? Translation.tr("Checking the laptop lid…")
                            : lidState.closed ? Translation.tr("Open the laptop lid to register your face.")
                            : Translation.tr("Ready to register")
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: Appearance.m3colors.m3onSurfaceVariant
                text: Translation.tr("Administrator authentication is required when saving. Move your head slightly if the IR light goes dark.")
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.resultText.length > 0
                spacing: 8
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: root.resultText
                    color: root.resultSuccess ? Appearance.m3colors.m3primary : Appearance.m3colors.m3onSurface
                }
                DialogButton {
                    visible: root.resultDetails.length > 0
                    buttonText: root.detailsExpanded ? Translation.tr("Hide details") : Translation.tr("Show details")
                    onClicked: root.detailsExpanded = !root.detailsExpanded
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    visible: root.detailsExpanded && root.resultDetails.length > 0
                    clip: true
                    TextArea {
                        text: root.resultDetails
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        color: Appearance.m3colors.m3onSurfaceVariant
                        font.pixelSize: 12
                        background: Rectangle {
                            radius: 8
                            color: Appearance.m3colors.m3surfaceContainerLow
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                DialogButton {
                    buttonText: Translation.tr("Close")
                    implicitHeight: 44
                    enabled: !enrollment.running
                    onClicked: root.close()
                }
                DialogButton {
                    buttonText: Translation.tr("Register")
                    implicitHeight: 44
                    padding: 20
                    enabled: root.canRegister
                    colBackground: enabled ? Appearance.m3colors.m3primary
                        : Appearance.m3colors.m3surfaceContainerLow
                    colBackgroundHover: Appearance.m3colors.m3primary
                    colText: enabled ? Appearance.m3colors.m3onPrimary
                        : Appearance.m3colors.m3onSurfaceVariant
                    onClicked: {
                        root.resultText = "";
                        root.resultDetails = "";
                        root.detailsExpanded = false;
                        enrollment.running = true;
                    }
                }
            }
        }
    }
}
