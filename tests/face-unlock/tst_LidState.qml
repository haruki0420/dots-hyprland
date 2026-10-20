import QtQuick
import QtTest
import "mocks"

TestCase {
    id: test
    name: "LidState"
    when: windowShown
    property var subject
    Component { id: factory; LidState {} }

    function init() {
        Harness.reset();
        subject = createTemporaryObject(factory, test);
        verify(subject !== null);
    }
    function test_unknownIsNotOpen() {
        verify(!subject.known);
        verify(subject.closed);
    }
    function test_initialQuery() {
        Harness.query.started();
        Harness.query.stdout.text = "(<false>,)\n";
        Harness.query.stdout.streamFinished();
        verify(subject.known);
        verify(!subject.closed);
    }
    function test_closedAndOpenNotifications() {
        subject.readChange("('org.freedesktop.UPower', {'LidIsClosed': <true>}, [])");
        verify(subject.known && subject.closed);
        subject.readChange("('org.freedesktop.UPower', {'LidIsClosed': <false>}, [])");
        verify(subject.known && !subject.closed);
    }
    function test_staleQueryCannotOverrideClosedLid() {
        Harness.query.started();
        subject.readChange("{'LidIsClosed': <true>}");
        Harness.query.stdout.text = "(<false>,)";
        Harness.query.stdout.streamFinished();
        verify(subject.known && subject.closed);
    }
    function test_daemonDisappears() {
        subject.readChange("{'LidIsClosed': <false>}");
        subject.readChange("The name org.freedesktop.UPower does not have an owner");
        verify(!subject.known);
    }
    function test_monitorDisconnectInvalidatesPendingQuery() {
        Harness.query.started();
        Harness.monitor.exited(1);
        Harness.query.stdout.text = "(<false>,)";
        Harness.query.stdout.streamFinished();
        verify(!subject.known);
    }
    function test_invalidOrFailedQuery() {
        Harness.query.started();
        Harness.query.stdout.text = "unavailable";
        Harness.query.stdout.streamFinished();
        verify(!subject.known);
        Harness.query.exited(1);
        verify(!subject.known);
    }
}
