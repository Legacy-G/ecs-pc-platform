#!/usr/bin/env bash
# Verifies repository hygiene across tracked text files.
# Checks for:
# - 12-digit AWS account IDs
# - ARNs containing account IDs
# - Personal email addresses
# - AWS secret and credential patterns
# - Leftover TODO and FIXME markers
# - Placeholder tokens (replace-me, changeme, example123)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if command -v python >/dev/null 2>&1 && python -c "import sys" >/dev/null 2>&1; then
  PYTHON_BIN="python"
elif command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
else
  echo "check-hygiene: python3 interpreter not found" >&2
  exit 1
fi

"$PYTHON_BIN" - <<'PY'
import re
import subprocess
import sys

EXCLUDED_PATHS = {
    "scripts/check-hygiene.sh",
    ".gitleaks.toml",
}

BINARY_EXTENSIONS = (
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".docx", ".zip", ".whl"
)

SENSITIVE_PATTERNS = [
    (r"arn:aws:[a-z0-9-]+:[a-z0-9-]*:\d{12}:", "AWS ARN containing 12-digit account ID"),
    (r"(?<![0-9a-fA-F])\d{12}(?![0-9a-fA-F])", "12-digit numeric sequence (potential AWS account ID)"),
    (r"[a-zA-Z0-9_.+-]+@(gmail|yahoo|hotmail|outlook)\.com\b", "Personal email address in tracked file"),
    (r"\bAKIA[0-9A-Z]{16}\b", "AWS Access Key ID pattern"),
    (r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", "Private cryptographic key pattern"),
]

PLACEHOLDER_PATTERNS = [
    (r"\bTODO\b", "Leftover TODO marker"),
    (r"\bFIXME\b", "Leftover FIXME marker"),
    (r"\breplace-me\b", "Placeholder token (replace-me)"),
    (r"\bchangeme\b", "Placeholder token (changeme)"),
    (r"\bexample123\b", "Placeholder token (example123)"),
]

SENSITIVE_RES = [(re.compile(pat, re.IGNORECASE), desc) for pat, desc in SENSITIVE_PATTERNS]
PLACEHOLDER_RES = [(re.compile(pat), desc) for pat, desc in PLACEHOLDER_PATTERNS]

files_out = subprocess.check_output(["git", "ls-files"], text=True)
files = [f.strip() for f in files_out.splitlines() if f.strip()]

failures = []

for path in files:
    norm_path = path.replace("\\", "/")
    if norm_path in EXCLUDED_PATHS:
        continue
    if norm_path.lower().endswith(BINARY_EXTENSIONS):
        continue

    try:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.readlines()
    except (UnicodeDecodeError, OSError):
        continue

    for lineno, line in enumerate(lines, start=1):
        for pattern, desc in SENSITIVE_RES:
            if pattern.search(line):
                failures.append(f"{norm_path}:{lineno}: [sensitive] {desc}")

        for pattern, desc in PLACEHOLDER_RES:
            if pattern.search(line):
                failures.append(f"{norm_path}:{lineno}: [placeholder] {desc}")

if failures:
    print(f"check-hygiene: FAILED with {len(failures)} violation(s):", file=sys.stderr)
    for f in failures:
        print(f"  {f}", file=sys.stderr)
    sys.exit(1)

print(f"check-hygiene: {len(files)} tracked files passed.")
PY
