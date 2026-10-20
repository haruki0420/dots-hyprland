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
    function test_numberedNames_data() {
        return [
            {tag: "first-ja", labels: [], template: "顔認証%1", expected: "顔認証1"},
            {tag: "first-en", labels: ["My face"], template: "Face authentication %1", expected: "Face authentication 1"},
            {tag: "next-ja", labels: ["顔認証1"], template: "顔認証%1", expected: "顔認証2"},
            {tag: "next-en", labels: ["Face authentication 1"], template: "Face authentication %1", expected: "Face authentication 2"},
            {tag: "mixed-languages", labels: ["顔認証1", "Face authentication 2"], template: "Face authentication %1", expected: "Face authentication 3"},
            {tag: "reuse-deleted-number", labels: ["顔認証1", "顔認証3"], template: "顔認証%1", expected: "顔認証2"}
        ];
    }
    function test_numberedNames(data) {
        compare(FaceModels.nextName(data.labels.map(label => ({label: label})), data.template), data.expected);
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
