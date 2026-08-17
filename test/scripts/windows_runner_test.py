import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAIN_CPP = ROOT / "windows" / "runner" / "main.cpp"
WIN32_CPP = ROOT / "windows" / "runner" / "win32_window.cpp"


class WindowsRunnerTest(unittest.TestCase):
    def test_main_window_respects_requested_launch_state(self):
        source = MAIN_CPP.read_text(encoding="utf-8")

        self.assertRegex(
            source,
            re.compile(
                r"if \(!window\.Create\([^}]+?\}\s*"
                r"::ShowWindow\(window\.GetHandle\(\), show_command\);\s*"
                r"window\.SetQuitOnClose",
                re.DOTALL,
            ),
        )

    def test_saved_bounds_must_intersect_a_monitor(self):
        source = WIN32_CPP.read_text(encoding="utf-8")

        self.assertIn(
            "MonitorFromRect(&saved_bounds, MONITOR_DEFAULTTONULL)",
            source,
        )

    def test_minimized_or_maximized_moves_are_not_persisted(self):
        source = WIN32_CPP.read_text(encoding="utf-8")

        self.assertRegex(
            source,
            re.compile(
                r"case WM_MOVE:\s*\{\s*"
                r"if \(!IsIconic\(hwnd\) && !IsZoomed\(hwnd\)\)",
                re.DOTALL,
            ),
        )


if __name__ == "__main__":
    unittest.main()
