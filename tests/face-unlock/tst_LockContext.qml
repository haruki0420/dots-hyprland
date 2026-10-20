import QtQuick
import QtTest
import "mocks"

TestCase {
    id: test
    name: "LockContext"
    when: windowShown
    property var subject
    Component { id: factory; LockContext {} }
    SignalSpy { id: unlocked; signalName: "unlocked" }

    function init() {
        Harness.reset();
        GlobalStates.screenLocked = false;
        subject = createTemporaryObject(factory, test);
        verify(subject !== null);
        Harness.query.started();
        Harness.query.stdout.text = "(<false>,)";
        Harness.query.stdout.streamFinished();
        GlobalStates.screenLocked = true;
        unlocked.target = subject;
        unlocked.clear();
    }
    function cleanup() {
        subject.stopFaceUnlock();
        GlobalStates.screenLocked = false;
        unlocked.target = null;
    }
    function test_retryAfterFailureClearsPasswordAndUnlocks() {
        subject.tryFaceUnlock();
        tryCompare(Harness, "starts", 1, 2200);
        Harness.current.finish(PamResult.Failed);
        verify(subject.canRetryFaceUnlock);
        subject.currentText = "typed password";
        subject.retryFaceUnlock();
        compare(subject.currentText, "");
        verify(!subject.canRetryFaceUnlock);
        subject.retryFaceUnlock(); // repeated clicks cannot create more attempts
        tryCompare(Harness, "starts", 2, 2200);
        Harness.current.finish(PamResult.Success);
        compare(unlocked.count, 1);
        compare(unlocked.signalArguments[0][0], LockContext.ActionEnum.Unlock);
    }
    function test_retryClosedLidDoesNotStart() {
        Harness.monitor.stdout.read("{'LidIsClosed': <true>}");
        verify(!subject.canRetryFaceUnlock);
        subject.retryFaceUnlock();
        wait(1600);
        compare(Harness.starts, 0);
    }
    function test_retryCannotApprovePowerActionsOrPasswordConversation() {
        subject.targetAction = LockContext.ActionEnum.Poweroff;
        verify(!subject.canRetryFaceUnlock);
        subject.retryFaceUnlock();
        subject.targetAction = LockContext.ActionEnum.Unlock;
        subject.unlockInProgress = true;
        verify(!subject.canRetryFaceUnlock);
        subject.retryFaceUnlock();
        wait(1600);
        compare(Harness.starts, 0);
    }
    function test_retryOnUnlockedDesktopDoesNotStart() {
        GlobalStates.screenLocked = false;
        verify(!subject.canRetryFaceUnlock);
        subject.retryFaceUnlock();
        wait(1600);
        compare(Harness.starts, 0);
    }
}
