import QtQuick
import Quickshell
import Quickshell.Io

// UPower's lid property is not exposed by Quickshell.Services.UPower yet.
// Unknown or disconnected state fails closed instead of opening the camera.
Scope {
    id: root
    property bool known: false
    property bool closed: true
    property int revision: 0

    function readChange(line) {
        const match = line.match(/'LidIsClosed': <(true|false)>/);
        if (match) {
            revision++;
            closed = match[1] === "true";
            known = true;
        } else if (line.includes("does not have an owner")) {
            revision++;
            query.running = false;
            known = false;
        } else if (line.includes("is owned by")) {
            query.running = true;
        }
    }

    Process {
        id: monitor
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.UPower",
            "--object-path", "/org/freedesktop/UPower"]
        environment: ({ LC_ALL: "C" })
        running: true
        onStarted: query.running = true
        stdout: SplitParser { onRead: line => root.readChange(line) }
        onExited: {
            root.revision++;
            query.running = false;
            root.known = false;
            retryTimer.restart();
        }
    }

    Process {
        id: query
        property int startRevision: 0
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.UPower",
            "--object-path", "/org/freedesktop/UPower", "--method",
            "org.freedesktop.DBus.Properties.Get", "org.freedesktop.UPower", "LidIsClosed"]
        onStarted: startRevision = root.revision
        stdout: StdioCollector {
            onStreamFinished: {
                if (query.startRevision !== root.revision) return;
                const match = text.trim().match(/^\(<(true|false)>,\)$/);
                root.known = match !== null;
                if (match) root.closed = match[1] === "true";
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) root.known = false;
        }
    }

    Timer {
        id: retryTimer
        interval: 5000
        onTriggered: monitor.running = true
    }
}
