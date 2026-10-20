#!/usr/bin/env python3
"""Exercise the production helper using disposable models and fake OS commands.

Only this test copy bypasses EUID and redirects privileged commands/paths. No
administrator access, real camera, Howdy model, or system ACL is used.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2] / "sdata/optional/face-unlock/end4-face-enroll"
STUB = r'''
import json, os, sys
from pathlib import Path
base = Path(os.environ["FACE_TEST_DIR"])
command = Path(sys.argv[0]).name
args = sys.argv[1:]
with (base / "calls").open("a") as log:
    log.write(json.dumps([command, *args]) + "\n")
if command == "getent":
    print("testuser:x:1000:1000::/nonexistent:/bin/bash")
elif command == "gdbus":
    print("(<true>,)" if os.environ.get("FACE_TEST_CLOSED") else "(<false>,)")
elif command == "howdy":
    if os.environ.get("FACE_TEST_FAIL"):
        sys.exit(1)
    assert args[:3] == ["-U", "testuser", "-y"]
    assert args[4] == "--"
    model = base / "models/testuser.dat"
    rows = json.loads(model.read_text()) if model.exists() else []
    if args[3] == "remove":
        remaining = [row for row in rows if str(row["id"]) != args[5]]
        if len(remaining) == len(rows):
            sys.exit(1)
        if remaining:
            model.write_text(json.dumps(remaining))
        else:
            model.unlink()
    else:
        assert args[3] == "add"
        rows.append({"id": 2, "label": args[5], "data": ["test-only"]})
        model.write_text(json.dumps(rows))
'''


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        (self.base / "models").mkdir()
        self.model = self.base / "models/testuser.dat"
        self.model.write_text(json.dumps([{"id": 0, "label": "first"}, {"id": 1, "label": "second"}]))
        text = SOURCE.read_text().replace("[[ $EUID -ne 0", "[[ 0 -ne 0")
        text = text.replace("/etc/howdy/models", str(self.base / "models"))
        for name in ("getent", "gdbus", "howdy", "chmod", "setfacl"):
            stub = self.base / name
            stub.write_text(f"#!{sys.executable}\n" + STUB)
            stub.chmod(0o755)
            text = text.replace(f"/usr/bin/{name}", str(stub))
        self.helper = self.base / "helper"
        self.helper.write_text(text)
        self.env = {**os.environ, "FACE_TEST_DIR": str(self.base), "PKEXEC_UID": "1000"}

    def run_helper(self, *args, **env):
        return subprocess.run(["/bin/bash", str(self.helper), *args], env={**self.env, **env},
                              text=True, capture_output=True, timeout=8)

    def calls(self):
        path = self.base / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_version_without_elevation(self):
        result = self.run_helper("--version", PKEXEC_UID="")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "end4-face-models 2")
        self.assertEqual(self.calls(), [])

    def test_remove_one_with_closed_lid(self):
        result = self.run_helper("remove", "0", FACE_TEST_CLOSED="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row["id"] for row in json.loads(self.model.read_text())], [1])
        self.assertFalse(any(call[0] == "gdbus" for call in self.calls()))
        self.assertIn(["setfacl", "-m", "u:testuser:r--", str(self.model)], self.calls())

    def test_remove_last_does_not_recreate_model(self):
        self.model.write_text('[{"id":0,"label":"only"}]')
        result = self.run_helper("remove", "0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.model.exists())

    def test_invalid_ids_never_invoke_howdy(self):
        for value in ("-1", "00", "all", "0;touch bad", "1/../../other"):
            with self.subTest(value=value):
                self.assertNotEqual(self.run_helper("remove", value).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_failed_remove_keeps_model(self):
        before = self.model.read_text()
        self.assertNotEqual(self.run_helper("remove", "99").returncode, 0)
        self.assertEqual(self.model.read_text(), before)

    def test_add_with_closed_lid_never_invoke_howdy(self):
        self.assertNotEqual(self.run_helper("add", "face", FACE_TEST_CLOSED="1").returncode, 0)
        self.assertFalse(any(call[0] == "howdy" for call in self.calls()))

    def test_label_is_one_literal_argument(self):
        label = 'face;$(touch bad)'
        result = self.run_helper("add", label)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.model.read_text())[-1]["label"], label)
        self.assertIn(["howdy", "-U", "testuser", "-y", "add", "--", label], self.calls())

    def test_reject_symlink_model(self):
        other = self.base / "other.dat"
        other.write_text("untouched")
        self.model.unlink()
        self.model.symlink_to(other)
        self.assertNotEqual(self.run_helper("remove", "0").returncode, 0)
        self.assertEqual(other.read_text(), "untouched")
        self.assertFalse(any(call[0] == "howdy" for call in self.calls()))


if __name__ == "__main__":
    unittest.main()
