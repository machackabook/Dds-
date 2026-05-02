#!/usr/bin/env bash

set -euo pipefail

############################################
# CONFIG
############################################

REPLACEMENT="Flyxion"
LOG_FILE="flyxion_corrections.log"
CANDIDATE_FILE="$(mktemp)"

# IMPORTANT: Infliction REMOVED from destructive pattern
PATTERN='Flexion|Flixian|Flixing|Fliction|Flippshen|Flexumian|Fletchian|Flicksheen|Flyzion|Flyxen|Flyxian|Flyxionn|Flyxionne|Flykshun|Flykshion|Flikshun|Flikzion|Flikxion|Flixion|Fleksion|Fleksian|Flextion|Flicksion|Flickzion|Flickxion|Flickshank|Fleksheen|Flekshun|Flekzion|Flixyon|Flixxon|Flixionne|Felician|Flyxionu|Flick Sheenan|Flixan|Fugchin|Flickshen|Flickshin|Flixgen|Flixen|Flicksham|Flitchinan|Flickening'

cleanup() {
    rm -f "$CANDIDATE_FILE"
}
trap cleanup EXIT

############################################
# BACKUP
############################################

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="backup_$TIMESTAMP"

echo "Creating backup snapshot: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

while IFS= read -r -d '' file; do
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    cp "$file" "$BACKUP_DIR/$file"
done < <(find . -type f \( -name "*.json" -o -name "*.srt" -o -name "*.tsv" -o -name "*.txt" -o -name "*.vtt" \) ! -path "./backup_*/*" -print0)

echo "Backup complete."

############################################
# LOG INIT
############################################

{
    echo ""
    echo "Flyxion normalization log - $(date)"
    echo "----------------------------------------"
} >> "$LOG_FILE"

############################################
# INTERACTIVE DISAMBIGUATION (affliction + infliction)
############################################

echo "---- Interactive disambiguation: affliction / infliction ----"

python3 <<'PY'
import sys, re, pathlib

patterns = [
    re.compile(r'\b[Aa]ffliction\b'),
    re.compile(r'\b[Ii]nfliction\b')
]

try:
    tty = open("/dev/tty")
except Exception:
    sys.exit(0)

def ask(prompt):
    print(prompt, end='', flush=True)
    return tty.readline().strip().lower()

for path in pathlib.Path(".").rglob("*.txt"):
    if "backup_" in str(path):
        continue

    try:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        continue

    modified = False

    for i, line in enumerate(lines):
        for pattern in patterns:
            if pattern.search(line):
                print("\n---")
                print(f"{path}:{i+1}")
                print(line.strip())

                while True:
                    resp = ask("Is this the name (n) or the concept (c)? [n/c/skip/quit]: ")
                    if resp in ("n", "c", "skip", "quit"):
                        break

                if resp == "quit":
                    sys.exit(0)

                if resp == "n":
                    lines[i] = pattern.sub("Flyxion", line)
                    modified = True

    if modified:
        path.write_text("\n".join(lines), encoding="utf-8")
        print(f"Updated (disambiguation): {path}")
PY

############################################
# PYTHON NORMALIZATION PASS (SAFE)
############################################

python3 <<'PY'
import re, difflib, pathlib

REPLACEMENT = "Flyxion"

PATTERN = re.compile(
    r'(?i)(?<![A-Za-z])('
    r'Flexion|Flixian|Flixing|Fliction|Flippshen|Flexumian|Fletchian|Flicksheen|'
    r'Flyzion|Flyxen|Flyxian|Flyxionn|Flyxionne|Flykshun|Flykshion|Flikshun|Flikzion|'
    r'Flikxion|Flixion|Fleksion|Fleksian|Flextion|Flicksion|Flickzion|Flickxion|'
    r'Flickshank|Fleksheen|Flekshun|Flekzion|Flixyon|Flixxon|Flixionne|Felician|'
    r'Flyxionu|Flick Sheenan|Flixan|Fugchin|Flickshen|Flickshin|Flixgen|Flixen|'
    r'Flicksham|Flitchinan|Flickening'
    r')(?![A-Za-z])'
)

LOG_FILE = "flyxion_corrections.log"

def protect(text):
    text = re.sub(r'\b[Aa]ffliction\b', '__AFFLICTION__', text)
    text = re.sub(r'\b[Ii]nfliction\b', '__INFLECTION__', text)
    return text

def restore(text):
    text = text.replace('__AFFLICTION__', 'affliction')
    text = text.replace('__INFLECTION__', 'infliction')
    return text

extensions = {".json",".srt",".tsv",".txt",".vtt"}

with open(LOG_FILE, "a", encoding="utf-8") as log:
    log.write("\nPython normalization pass\n")
    log.write("----------------------------------------\n")

    for path in pathlib.Path(".").rglob("*"):
        if path.suffix.lower() not in extensions:
            continue
        if "backup_" in str(path):
            continue

        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue

        protected = protect(text)

        new_text = PATTERN.sub(REPLACEMENT, protected)
        new_text = re.sub(r'\b(in|of|af|am|an|at|to)\s*(Flyxion)', r'\1 \2', new_text, flags=re.I)

        new_text = restore(new_text)

        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            log.write(f"Updated: {path}\n")
            print(f"Updated: {path}")
        else:
            log.write(f"[no changes] {path}\n")

    log.write("----------------------------------------\n")
    log.write("Done.\n")
PY

############################################
# DONE
############################################

echo "All passes complete."