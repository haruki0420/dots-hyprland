import QtQuick
import QtTest
import "FaceModels.js" as FaceModels

TestCase {
    name: "FaceModels"
    function test_metadataOnlyAndNewestFirst() {
        const rows = FaceModels.metadata(JSON.stringify([
            {id: 0, label: "自分の顔", time: 100, data: [[0.1, 0.2]]},
            {id: 1, label: "眼鏡あり", time: 200, data: [[0.3, 0.4]]}
        ]));
        compare(rows.length, 2);
        compare(rows[0].label, "眼鏡あり");
        compare(rows[1].id, 0);
        compare(Object.keys(rows[0]).sort().join(","), "id,label,time");
    }
    function test_empty() {
        compare(FaceModels.metadata("[]").length, 0);
    }
    function test_invalid_data() {
        return [{tag: "broken-json", text: "["},
                {tag: "wrong-shape", text: "{}"},
                {tag: "invalid-date", text: '[{"id":0,"label":"face","time":"bad"}]'}];
    }
    function test_invalid(data) {
        let rejected = false;
        try { FaceModels.metadata(data.text); } catch (_) { rejected = true; }
        verify(rejected);
    }
}
