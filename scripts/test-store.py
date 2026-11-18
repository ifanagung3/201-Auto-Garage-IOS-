#!/usr/bin/env python3
"""Compile the real store/models against controlled SDK boundaries, then test races.

Uses in-memory test doubles, not Firebase SDKs or the Firebase Emulator. It verifies
store orchestration/session isolation; it does not validate Firestore security rules.
"""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix="autogarage-store-tests-") as temporary:
        work = Path(temporary)
        sources = []
        for filename in ("GarageModels.swift", "GarageStore.swift"):
            source = (ROOT / "201AutoGarage" / filename).read_text()
            source = re.sub(r"^import (?:Firebase\w*|GoogleSignIn|UIKit)\n", "", source, flags=re.MULTILINE)
            # UIKit normally reexports Foundation in the iOS target.
            if "import Foundation\n" not in source:
                source = "import Foundation\n" + source
            target = work / filename
            target.write_text(source)
            sources.append(str(target))
        executable = work / "StoreRegressionTests"
        subprocess.run([
            "xcrun", "swiftc", "-parse-as-library", "-swift-version", "5",
            "-module-cache-path", str(work / "ModuleCache"),
            str(ROOT / "Tests/StoreTestDoubles.swift"), *sources,
            str(ROOT / "Tests/StoreRegressionTests.swift"), "-o", str(executable),
        ], check=True, cwd=ROOT)
        subprocess.run([str(executable)], check=True, cwd=ROOT, timeout=30)


if __name__ == "__main__":
    main()
