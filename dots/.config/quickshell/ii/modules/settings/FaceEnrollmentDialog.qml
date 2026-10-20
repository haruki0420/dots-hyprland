import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.panels.lock
import "FaceModels.js" as FaceModels

Dialog {
    id: root
    title: Translation.tr("Face authentication")
    modal: true
    anchors.centerIn: parent
    width: Math.min(560, Math.max(320, (parent?.width ?? 608) - 48))
    height: Math.min(implicitHeight, Math.max(240, (parent?.height ?? 900) - 48))
    padding: 0
    header: null
    footer: null
    background: null
    closePolicy: busy ? Popup.NoAutoClose : Popup.CloseOnEscape
    property string resultText: ""
    property string resultDetails: ""
    property bool resultSuccess: false
    property bool detailsExpanded: false
    property bool helperReady: false
    property var registeredFaces: []
    property string modelError: ""
    property bool nameEdited: false
    readonly property string suggestedName: FaceModels.nextName(registeredFaces, Translation.tr("Face authentication %1"))
    property int pendingDeleteId: -1
    property string pendingDeleteName: ""
    readonly property bool busy: enrollment.running || removal.running
    onSuggestedNameChanged: {
        if (!nameEdited && label) label.text = suggestedName;
    }
    readonly property bool canRegister: helperReady && lidState.known && !lidState.closed
        && !busy && pendingDeleteId < 0 && label.text.trim().length > 0

    function requestDeletion(id, name) {
        if (busy || !helperReady) return;
        pendingDeleteId = id;
        pendingDeleteName = name;
        resultText = "";
        resultDetails = "";
        detailsExpanded = false;
    }

    Overlay.modal: Rectangle { color: "#66000000" }
    onOpened: modelFile.reload()

    LidState { id: lidState }
    FileView {
        id: modelFile
        path: "/etc/howdy/models/" + (Quickshell.env("USER") || SystemInfo.username) + ".dat"
        preload: true
        // The model directory deliberately allows traversal without listing.
        // Refresh on opening, after enrollment, and via the refresh button.
        watchChanges: false
        onLoaded: {
            try {
                root.registeredFaces = FaceModels.metadata(text());
                root.modelError = "";
                if (!root.busy && !root.registeredFaces.some(face => face.id === root.pendingDeleteId))
                    root.pendingDeleteId = -1;
            } catch (_) {
                root.registeredFaces = [];
                root.pendingDeleteId = -1;
                root.modelError = Translation.tr("Could not read registered faces.");
            }
        }
        onLoadFailed: error => {
            root.registeredFaces = [];
            root.pendingDeleteId = -1;
            root.modelError = error === FileViewError.FileNotFound ? ""
                : Translation.tr("Could not read registered faces.");
        }
    }
    Process {
        id: helperCheck
        command: ["/usr/local/libexec/end4-face-enroll", "--version"]
        stdout: StdioCollector { id: helperVersion }
        running: true
        onExited: exitCode => root.helperReady = exitCode === 0 && helperVersion.text.trim() === "end4-face-models 2"
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.opened && !root.helperReady
        onTriggered: helperCheck.running = true
    }
    Process {
        id: enrollment
        command: ["pkexec", "/usr/local/libexec/end4-face-enroll", "add", label.text.trim()]
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onExited: exitCode => {
            if (exitCode === 0) {
                root.nameEdited = false;
                label.text = root.suggestedName;
            }
            modelFile.reload();
            root.resultSuccess = exitCode === 0;
            root.resultDetails = exitCode === 0 || exitCode === 126 ? ""
                : (errors.text + "\n" + output.text).trim().slice(-1600);
            root.resultText = exitCode === 0
                ? Translation.tr("Face registered. You can now enable face authentication.")
                : exitCode === 126 ? Translation.tr("Registration canceled.")
                : Translation.tr("Could not register your face. Open the camera shutter, face the camera, and try again.");
        }
    }
    Process {
        id: removal
        stdout: StdioCollector { id: removalOutput }
        stderr: StdioCollector { id: removalErrors }
        onExited: exitCode => {
            root.resultSuccess = exitCode === 0;
            root.resultDetails = exitCode === 0 || exitCode === 126 ? ""
                : (removalErrors.text + "\n" + removalOutput.text).trim().slice(-1600);
            root.resultText = exitCode === 0 ? Translation.tr("Face deleted.")
                : exitCode === 126 ? Translation.tr("Deletion canceled.")
                : Translation.tr("Could not delete the face. Refresh the list and try again.");
            root.pendingDeleteId = -1;
            modelFile.reload();
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

        Flickable {
            anchors.fill: parent
            anchors.margins: 24
            contentWidth: width
            contentHeight: cardLayout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: cardLayout
                width: parent.width
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
                            text: Translation.tr("For unlocking the screen and after suspend")
                            color: Appearance.m3colors.m3onSurfaceVariant
                            font.pixelSize: 13
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Registered faces (%1)").arg(root.registeredFaces.length)
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onSurface
                        }
                        DialogButton {
                            buttonText: Translation.tr("Refresh")
                            enabled: !root.busy
                            onClicked: modelFile.reload()
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.modelError.length > 0 || root.registeredFaces.length === 0
                        text: root.modelError || Translation.tr("No faces registered yet.")
                        wrapMode: Text.Wrap
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(faceRows.implicitHeight, 144)
                        visible: root.registeredFaces.length > 0
                        contentWidth: availableWidth
                        clip: true
                        ColumnLayout {
                            id: faceRows
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: root.registeredFaces
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: faceInfo.implicitHeight + 20
                                    radius: 12
                                    color: Appearance.m3colors.m3surfaceContainerLow
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        ColumnLayout {
                                            id: faceInfo
                                            Layout.fillWidth: true
                                            spacing: 4
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.label
                                                textFormat: Text.PlainText
                                                elide: Text.ElideRight
                                                color: Appearance.m3colors.m3onSurface
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: Translation.tr("ID %1 · Registered %2").arg(modelData.id)
                                                    .arg(Qt.formatDateTime(new Date(modelData.time * 1000), "yyyy/MM/dd HH:mm"))
                                                font.pixelSize: 12
                                                color: Appearance.m3colors.m3onSurfaceVariant
                                            }
                                        }
                                        DialogButton {
                                            objectName: "faceDeleteButton-" + modelData.id
                                            buttonText: Translation.tr("Delete")
                                            enabled: root.helperReady && !root.busy
                                            onClicked: root.requestDeletion(modelData.id, modelData.label)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: deleteConfirmation.implicitHeight + 24
                    visible: root.pendingDeleteId >= 0
                    radius: 12
                    color: Appearance.m3colors.m3errorContainer
                    ColumnLayout {
                        id: deleteConfirmation
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Delete “%1”?").arg(root.pendingDeleteName)
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onErrorContainer
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.registeredFaces.length === 1
                                ? Translation.tr("This is your last registered face. Face unlock will be unavailable until you register again.")
                                : Translation.tr("This face will no longer unlock your screen. Administrator authentication is required to delete it.")
                            wrapMode: Text.Wrap
                            font.pixelSize: 13
                            color: Appearance.m3colors.m3onErrorContainer
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            DialogButton {
                                objectName: "cancelFaceDeletion"
                                buttonText: Translation.tr("Cancel")
                                enabled: !root.busy
                                onClicked: root.pendingDeleteId = -1
                            }
                            DialogButton {
                                objectName: "confirmFaceDeletion"
                                buttonText: root.busy ? Translation.tr("Deleting…") : Translation.tr("Delete")
                                enabled: root.helperReady && !root.busy
                                colBackground: Appearance.m3colors.m3error
                                colText: Appearance.m3colors.m3onError
                                onClicked: removal.exec(["pkexec", "/usr/local/libexec/end4-face-enroll",
                                    "remove", String(root.pendingDeleteId)])
                            }
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
                        objectName: "faceNameField"
                        Layout.fillWidth: true
                        implicitHeight: 50
                        enabled: !root.busy
                        maximumLength: 24
                        text: root.suggestedName
                        onTextEdited: root.nameEdited = true
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
                            visible: root.busy
                            running: visible
                            implicitWidth: 22
                            implicitHeight: 22
                        }
                        MaterialSymbol {
                            visible: !root.busy
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
                            text: removal.running ? Translation.tr("Deleting…")
                                : enrollment.running ? Translation.tr("Look at the camera. Waiting for registration…")
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
                    text: Translation.tr("Saving and deleting require administrator authentication. Move your head slightly if the IR light goes dark.")
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
                        enabled: !root.busy
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
}
