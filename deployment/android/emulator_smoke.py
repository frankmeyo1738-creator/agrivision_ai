"""Drive the real release APK/gallery via adb; no injected predictions or UI test hooks."""

import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", default="emulator-5554")
    args = parser.parse_args()
    root = Path("artifacts/android_verification")
    root.mkdir(parents=True, exist_ok=True)
    trace = []

    def adb(*command):
        return subprocess.check_output([args.adb, "-s", args.serial, *command], timeout=40)

    def screen():
        adb("shell", "uiautomator", "dump", "/sdcard/agrivision-ui.xml")
        xml = adb("exec-out", "cat", "/sdcard/agrivision-ui.xml").decode()
        (root / "ui_latest.xml").write_text(xml)
        return ET.fromstring(xml)

    def nodes():
        return list(screen().iter("node"))

    def click(fragment, *, description=False, wait_seconds=40):
        deadline = time.monotonic() + wait_seconds
        while time.monotonic() < deadline:
            for node in nodes():
                value = node.get("content-desc" if description else "text", "")
                if fragment.lower() in value.lower():
                    x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
                    if x2 <= x1 or y2 <= y1:
                        continue
                    adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
                    trace.append({"clicked": value})
                    time.sleep(0.5)
                    return
            time.sleep(0.5)
        raise RuntimeError(f"Could not find {fragment}; inspect ui_latest.xml")

    adb("shell", "am", "force-stop", "ai.agrivision.agrivision_ai")
    adb("shell", "am", "start", "-n", "ai.agrivision.agrivision_ai/.MainActivity")
    time.sleep(3)
    (root / "offline_overview.png").write_bytes(adb("exec-out", "screencap", "-p"))
    click("Analyze", description=True)
    # Scroll the app's content, not the persistent bottom navigation.
    display = adb("shell", "wm", "size").decode().strip().splitlines()[-1]
    width, height = map(int, re.findall(r"(\d+)x(\d+)", display)[0])
    for _ in range(1):
        adb(
            "shell",
            "input",
            "swipe",
            str(width // 2),
            str(height * 3 // 4),
            str(width // 2),
            str(height // 3),
            "450",
        )
        time.sleep(0.3)
    click("Choose image", description=True)
    (root / "gallery_picker.png").write_bytes(adb("exec-out", "screencap", "-p"))
    click("Photo taken", description=True)
    click("Done")
    click("This is a tomato leaf", description=True)
    click("Analyze leaf", description=True)
    time.sleep(2)
    adb(
        "shell",
        "input",
        "swipe",
        str(width // 2),
        str(height * 3 // 4),
        str(width // 2),
        str(height // 3),
        "450",
    )
    time.sleep(0.5)
    result_nodes = nodes()
    text = "\n".join(node.get("text", "") + node.get("content-desc", "") for node in result_nodes)
    if "Healthy" not in text or "99.3% confidence" not in text:
        raise RuntimeError(
            "Fixed-leaf release result does not match the expected reference display."
        )
    (root / "offline_result.png").write_bytes(adb("exec-out", "screencap", "-p"))
    trace.append(
        {
            "result": "Healthy",
            "display_confidence": "99.3%",
            "source": "actual bundled model through gallery UI",
        }
    )
    print("Release gallery/inference flow passed. Visible controls:")
    print(
        json.dumps(
            [
                {key: node.get(key) for key in ("text", "content-desc", "resource-id", "bounds")}
                for node in nodes()
                if node.get("text") or node.get("content-desc")
            ],
            indent=2,
        )
    )
    (root / "ui_trace.json").write_text(json.dumps(trace, indent=2))


if __name__ == "__main__":
    main()
