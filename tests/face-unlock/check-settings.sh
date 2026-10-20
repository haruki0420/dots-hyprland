#!/usr/bin/env bash
# Native smoke check: requires a running Wayland session and Quickshell.
# Uses the actual settings entrypoint's dynamic URL loader in a hidden window.
# No enrollment operation or camera authentication is performed.
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
qml_root="$test_dir/../../dots/.config/quickshell/ii"
check_file=$(mktemp "$qml_root/face-settings-smoke-XXXXXX.qml")
check_log=$(mktemp)
trap 'rm -f -- "$check_file" "$check_log"' EXIT
sed -e 's/property int currentPage: 0/property int currentPage: 4/' \
    -e '0,/visible: true/s//visible: false/' \
    -e 's/source = root.pages\[0\].component/source = root.pages[root.currentPage].component/' \
    -e '$d' "$qml_root/settings.qml" > "$check_file"
cat >> "$check_file" <<'QML'
    Loader {
        id: enrollmentCheck
        active: Config.ready
        source: "modules/settings/FaceEnrollmentDialog.qml"
        onLoaded: {
            item.parent = Overlay.overlay;
            item.open();
        }
    }
    Timer {
        running: true
        interval: 2500
        onTriggered: {
            const ready = pageLoader.status === Loader.Ready
                && pageLoader.item !== null && pageLoader.item.contentHeight > 100
                && enrollmentCheck.status === Loader.Ready && enrollmentCheck.item !== null
                && (Quickshell.env("FACE_EXPECT_COUNT") === ""
                    || enrollmentCheck.item.registeredFaces.length === Number(Quickshell.env("FACE_EXPECT_COUNT")));
            console.log(ready ? "SETTINGS_FACE_SMOKE_PASS" : "SETTINGS_FACE_SMOKE_FAIL",
                pageLoader.status, enrollmentCheck.status);
            Qt.quit();
        }
    }
}
QML
timeout 15s qs --no-color --path "$check_file" 2>&1 | tee "$check_log"
rg -q 'SETTINGS_FACE_SMOKE_PASS' "$check_log"
