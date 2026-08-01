"""
Persist the last-seen IMAP UID between poll cycles
"""

import os
import tempfile
from pathlib import Path


def read_watermark(path: Path) -> int:
    if not path.exists():
        return 0

    return int(path.read_text().strip())


def write_watermark(path: Path, uid: int) -> None:
    current = read_watermark(path)
    if uid < current:
        raise ValueError(
            f"refuse to move watermark backwards: {uid} < current {current}"
        )

    fd, tmp_path = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(str(uid))
        os.replace(tmp_path, path)
    except Exception:
        os.unlink(tmp_path)
        raise
