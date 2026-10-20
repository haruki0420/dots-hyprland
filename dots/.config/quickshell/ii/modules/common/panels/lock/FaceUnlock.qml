import QtQuick
import Quickshell
import Quickshell.Services.Pam

// A separate PAM conversation keeps a failed camera attempt from consuming a
// password attempt. Only the resume hook schedules authentication.
Scope {
    id: root

    required property bool canAuthenticate
    readonly property bool active: facePam.active
    property bool requested: false
    property bool authenticating: false
    signal authenticated()

    function schedule() {
        stop();
        if (!canAuthenticate) return;
        requested = true;
        cameraReadyTimer.restart();
    }

    function stop() {
        requested = false;
        authenticating = false;
        cameraReadyTimer.stop();
        authTimeout.stop();
        if (facePam.active) facePam.abort();
    }

    onCanAuthenticateChanged: {
        if (!canAuthenticate) stop();
    }
    Component.onDestruction: stop()

    Timer {
        id: cameraReadyTimer
        // USB cameras can take a moment to become available after suspend.
        interval: 1500
        onTriggered: {
            if (!root.requested || !root.canAuthenticate) return;
            root.authenticating = true;
            authTimeout.restart();
            if (!facePam.start()) root.stop();
        }
    }

    Timer {
        id: authTimeout
        interval: 10000
        onTriggered: root.stop()
    }

    PamContext {
        id: facePam
        config: "quickshell-face"

        // This service must only authenticate a face. Never answer a password
        // prompt or treat an unavailable module as successful authentication.
        onPamMessage: {
            if (responseRequired) root.stop();
        }
        onCompleted: result => {
            // An aborted conversation can finish while a new resume is still
            // waiting for the camera. It must not consume that pending attempt.
            if (!root.authenticating) return;
            const accepted = root.requested && root.authenticating && root.canAuthenticate
                && result === PamResult.Success;
            root.requested = false;
            root.authenticating = false;
            authTimeout.stop();
            if (accepted) root.authenticated();
        }
    }
}
