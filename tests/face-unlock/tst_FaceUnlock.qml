import QtQuick
import QtTest
import "mocks"

TestCase {
    id: test
    name: "FaceUnlock"
    when: windowShown
    property var subject

    Component {
        id: factory
        FaceUnlock { canAuthenticate: true }
    }
    SignalSpy { id: accepted; signalName: "authenticated" }

    function init() {
        Harness.reset();
        subject = createTemporaryObject(factory, test);
        verify(subject !== null);
        accepted.target = subject;
        accepted.clear();
    }
    function cleanup() {
        subject.stop();
        accepted.target = null;
    }
    function startAttempt() {
        subject.schedule();
        tryCompare(Harness, "starts", 1, 2200);
        verify(subject.active);
        compare(Harness.current.config, "quickshell-face");
    }

    function test_noCameraOnCreation() {
        wait(1600);
        compare(Harness.starts, 0);
    }
    function test_ineligibleResume() {
        subject.canAuthenticate = false;
        subject.schedule();
        wait(1600);
        compare(Harness.starts, 0);
    }
    function test_success() {
        startAttempt();
        Harness.current.finish(PamResult.Success);
        compare(accepted.count, 1);
        verify(!subject.requested);
    }
    function test_failedMatchAndMissingModule_data() {
        return [{tag: "mismatch", result: PamResult.Failed},
                {tag: "missing-module", result: PamResult.Error}];
    }
    function test_failedMatchAndMissingModule(data) {
        startAttempt();
        Harness.current.finish(data.result);
        compare(accepted.count, 0);
        verify(!subject.requested);
        wait(1600);
        compare(Harness.starts, 1); // no retry loop
    }
    function test_passwordOrPowerActionCancels() {
        startAttempt();
        subject.canAuthenticate = false;
        compare(Harness.aborts, 1);
        Harness.current.finish(PamResult.Success); // late result must be ignored
        compare(accepted.count, 0);
    }
    function test_typingDuringCameraDelayCancels() {
        subject.schedule();
        subject.canAuthenticate = false;
        subject.canAuthenticate = true;
        wait(1600);
        compare(Harness.starts, 0);
    }
    function test_passwordSubmissionCancels() {
        startAttempt();
        subject.stop();
        Harness.current.finish(PamResult.Success);
        compare(accepted.count, 0);
    }
    function test_passwordPromptIsNeverAnswered() {
        startAttempt();
        Harness.current.responseRequired = true;
        Harness.current.pamMessage();
        compare(Harness.aborts, 1);
        Harness.current.finish(PamResult.Success);
        compare(accepted.count, 0);
    }
    function test_repeatedResumeIgnoresOldResultDuringDelay() {
        startAttempt();
        const previous = Harness.current;
        subject.schedule();
        previous.finish(PamResult.Success);
        compare(accepted.count, 0);
        tryCompare(Harness, "starts", 2, 2200);
        Harness.current.finish(PamResult.Success);
        compare(accepted.count, 1);
    }
    function test_unavailableBackend() {
        Harness.startAllowed = false;
        subject.schedule();
        tryCompare(Harness, "starts", 1, 2200);
        verify(!subject.requested);
        compare(accepted.count, 0);
    }
    function test_watchdog() {
        startAttempt();
        tryCompare(Harness, "aborts", 1, 11000);
        verify(!subject.active);
        Harness.current.finish(PamResult.Success);
        compare(accepted.count, 0);
    }
}
