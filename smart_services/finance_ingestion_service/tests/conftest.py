from pathlib import Path
import sys


# Ensure `app` resolves when pytest is run from the service directory.
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
