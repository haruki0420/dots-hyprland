#!/usr/bin/env bash
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$test_dir/../.." && pwd)
test_tmp=$(mktemp -d)
trap 'rm -rf -- "$test_tmp"' EXIT
cp -r "$test_dir/mocks" "$test_tmp/mocks"
cp "$test_dir"/tst_*.qml "$test_tmp/"
cp "$repo_dir/dots/.config/quickshell/ii/modules/settings/FaceModels.js" "$test_tmp/"
# Exercise the production state machine with a fake PAM backend. Scope is a
# nonvisual container; Item allows the tests to run without a Quickshell host.
sed -e '/^import Quickshell$/d' \
    -e 's/^import Quickshell.Services.Pam$/import "mocks"/' \
    -e 's/^Scope {/Item {/' \
    "$repo_dir/dots/.config/quickshell/ii/modules/common/panels/lock/FaceUnlock.qml" \
    > "$test_tmp/FaceUnlock.qml"
sed -e '/^import Quickshell$/d' \
    -e 's/^import Quickshell.Io$/import "mocks"/' \
    -e 's/^Scope {/Item {/' \
    "$repo_dir/dots/.config/quickshell/ii/modules/common/panels/lock/LidState.qml" \
    > "$test_tmp/LidState.qml"
sed -e '/^import qs$/d' \
    -e '/^import qs.modules.common$/d' \
    -e '/^import Quickshell$/d' \
    -e '/^import Quickshell.Io$/d' \
    -e 's/^import Quickshell.Services.Pam$/import "mocks"/' \
    -e 's/^Scope {/Item {/' \
    "$repo_dir/dots/.config/quickshell/ii/modules/common/panels/lock/LockContext.qml" \
    > "$test_tmp/LockContext.qml"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}" -input "$test_tmp" "$@"
