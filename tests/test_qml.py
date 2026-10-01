"""Runs the QtQuickTest suites (tests/qml/tst_*.qml) in a subprocess.

QUICK_TEST_MAIN creates its own application and event loop, so it does not
share pytest-qt's QApplication.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

RUNNER = Path(__file__).resolve().parent / "qml_runner.py"


def test_qml_testcases():
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}
    proc = subprocess.run(
        [sys.executable, str(RUNNER)], env=env, capture_output=True, text=True, timeout=120
    )
    output = proc.stdout + proc.stderr
    totals = re.search(r"Totals: (\d+) passed, (\d+) failed, (\d+) skipped", output)
    assert totals, output
    passed, failed, skipped = map(int, totals.groups())
    assert proc.returncode == 0 and failed == 0, output
    assert passed >= 21 and skipped == 0, output
