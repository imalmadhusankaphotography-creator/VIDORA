#!/usr/bin/env python3
"""Rename FilmCraft to VIDORA in every user-visible text of the app.

Run from anywhere:  python3 packaging/vidora/rebrand_strings.py [--check]

It is safe to run again (it only changes what still says "FilmCraft"), so after merging a new
FilmCraft release run it once more to rename the strings that release added.

What it changes:
  * "FilmCraft" inside Rust string literals ("...", r"...", r#"..."#) in apps/ and crates/.
    Comments, identifiers and byte strings (b"...") stay as they are: byte strings are often
    fixed-size file-format fields, and crate names (filmcraft-*) keep upstream merges simple.
  * "FilmCraft" anywhere in the UI translation catalogs (crates/ui-egui/src/i18n/*.tsv), so the
    translated text keeps matching the English source strings.
  * The command-line tool's name in its own messages ("filmcraft-cli" -> "vidora-cli", and
    "filmcraft --control" -> "VIDORA --control"), in apps/filmcraft-cli/src and
    crates/automation/src: the Windows build ships the tools as VIDORA.exe and vidora-cli.exe.

What it leaves alone: the golden-image attribution text (crates/golden, crates/testkit/src/
golden.rs), which credits the FilmCraft contributors for those images.

--check prints what would change and exits 1 if anything would.
"""
import pathlib
import re
import sys

OLD, NEW = "FilmCraft", "VIDORA"
# never renamed: credits for the people who made FilmCraft ("FilmCraft contributors",
# "FilmCraft by the ArtCraft team")
KEEP = r"(?! contributors| by the ArtCraft)"
# (old, new, only in files under these paths)
CLI_RULES = [
    ("filmcraft-cli", "vidora-cli", ("apps/filmcraft-cli/src/", "crates/automation/src/")),
    ("`filmcraft --control", "`VIDORA --control", ("apps/filmcraft-cli/src/", "crates/automation/src/")),
]
ROOT = pathlib.Path(__file__).resolve().parents[2]
SKIP = ("crates/golden/", "crates/testkit/src/golden.rs", "apps/filmcraft-web/")


def rust_string_spans(src):
    """Yield (start, end, is_byte) for every string literal token in Rust source `src`."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j + 1
        elif src.startswith("/*", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if src.startswith("/*", i):
                    depth, i = depth + 1, i + 2
                elif src.startswith("*/", i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
        elif c == "'":
            # char literal ('a', '\n', '\u{1F600}', '"') or a lifetime/label ('a, 'static)
            if src.startswith("\\", i + 1):
                j = src.find("'", i + 2)
                i = n if j < 0 else j + 1
            elif i + 2 < n and src[i + 2] == "'":
                i += 3
            else:
                i += 1
        elif c == '"' or (c in "rb" and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == "_"))):
            # optional prefix: b, r, br, then hashes for raw strings
            j, is_byte, raw = i, False, False
            if src[j] == "b":
                is_byte, j = True, j + 1
            if j < n and src[j] == "r":
                raw, j = True, j + 1
            hashes = 0
            while raw and j < n and src[j] == "#":
                hashes, j = hashes + 1, j + 1
            if j >= n or src[j] != '"' or (not raw and hashes) or (j == i and c != '"'):
                i += 1
                continue
            start, j = i, j + 1
            if raw:
                end = src.find('"' + "#" * hashes, j)
                end = n if end < 0 else end + 1 + hashes
            else:
                while j < n and src[j] != '"':
                    j += 2 if src[j] == "\\" else 1
                end = min(j + 1, n)
            yield start, end, is_byte
            i = end
        else:
            i += 1


def sub(old, new, text):
    """Replace `old` with `new` in `text`, except in credits (see KEEP), which
    keep naming the people who made FilmCraft. Returns (new text, number of replacements)."""
    return re.subn(re.escape(old) + KEEP, new.replace("\\", "\\\\"), text)


def rebrand_rust(src, rules):
    out, last, count = [], 0, 0
    for s, e, is_byte in rust_string_spans(src):
        lit = src[s:e]
        if is_byte or "CARGO_BIN_EXE_" in lit or not any(sub(old, new, lit)[1] for old, new in rules):
            continue
        out.append(src[last:s])
        for old, new in rules:
            lit, k = sub(old, new, lit)
            count += k
        out.append(lit)
        last = e
    out.append(src[last:])
    return "".join(out), count


def main():
    check = "--check" in sys.argv[1:]
    changed = 0
    files = sorted(p for d in ("apps", "crates") for p in (ROOT / d).rglob("*.rs"))
    files += sorted((ROOT / "crates/ui-egui/src/i18n").glob("*.tsv"))
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith(SKIP) or "/target/" in rel:
            continue
        text = path.read_text(encoding="utf-8")
        rules = [(OLD, NEW)] + [(o, n) for o, n, where in CLI_RULES if rel.startswith(where)]
        if not any(sub(old, new, text)[1] for old, new in rules):
            continue
        if path.suffix == ".tsv":
            new, count = sub(OLD, NEW, text)
        else:
            new, count = rebrand_rust(text, rules)
        if count:
            changed += count
            print(f"{rel}: {count}")
            if not check:
                path.write_text(new, encoding="utf-8")
    print(f"{'would change' if check else 'changed'} {changed} occurrence(s)")
    return 1 if check and changed else 0


if __name__ == "__main__":
    sys.exit(main())
