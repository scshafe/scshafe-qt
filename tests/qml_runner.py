"""Run the QtQuickTest suites in tests/qml (tst_*.qml) with Scshafe.Ui registered.

PySide6 wheels ship no `qmltestrunner` binary; PySide6.QtQuickTest's
QUICK_TEST_MAIN_WITH_SETUP is the same runner. Arguments are passed to it
(e.g. `-functions`, `-o result.xml,junitxml`).

    QT_QPA_PLATFORM=offscreen uv run python tests/qml_runner.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, Slot  # noqa: E402
from PySide6.QtQml import QQmlEngine  # noqa: E402
from PySide6.QtQuickTest import QUICK_TEST_MAIN_WITH_SETUP  # noqa: E402

import scshafe_qt  # noqa: E402


class Setup(QObject):
    @Slot(QQmlEngine)
    def qmlEngineAvailable(self, engine: QQmlEngine) -> None:  # noqa: N802 (Qt slot name)
        scshafe_qt.register(engine)


if __name__ == "__main__":
    tests_dir = Path(__file__).resolve().parent / "qml"
    sys.exit(QUICK_TEST_MAIN_WITH_SETUP("scshafe_qt", Setup, argv=sys.argv, dir=str(tests_dir)))
