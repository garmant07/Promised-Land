#!/usr/bin/env python3
"""Convert a 66-book USFM Bible zip/folder into deterministic per-book JSON."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import tempfile
import zipfile
from pathlib import Path


BOOK_CODES = (
    "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB "
    "PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG "
    "ZEC MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT "
    "PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV"
).split()

NOTE_BLOCK = re.compile(r"\\(?:f|fe|ef|x|ex)\b.*?\\(?:f|fe|ef|x|ex)\*", re.DOTALL)
WORD = re.compile(r"\\\+?w\s+([^|\\]+?)(?:\|[^\\]*?)?\\\+?w\*")
MILESTONE = re.compile(r"\\[^\s\\]+-s\b.*?\\\*")
END_MILESTONE = re.compile(r"\\[^\s\\]+-e\\\*")
INLINE_MARKER = re.compile(r"\\\+?[A-Za-z0-9-]+\*?")
WHITESPACE = re.compile(r"\s+")

# Lines with these markers are structure/headings, not verse continuations.
NON_TEXT_MARKERS = {
    "id", "ide", "h", "toc1", "toc2", "toc3", "mt", "mt1", "mt2", "mt3", "mt4",
    "mte", "mte1", "mte2", "ms", "ms1", "ms2", "ms3", "ms4", "mr", "s", "s1", "s2",
    "s3", "s4", "sr", "r", "rq", "rem", "cl", "cp", "ca", "cd", "sp",
}


def clean_text(value: str) -> str:
    previous = None
    while previous != value:
        previous = value
        value = NOTE_BLOCK.sub("", value)
    value = WORD.sub(lambda match: match.group(1), value)
    value = MILESTONE.sub("", value)
    value = END_MILESTONE.sub("", value)
    value = INLINE_MARKER.sub("", value)
    value = value.replace("//", " ")
    return WHITESPACE.sub(" ", value).strip()


def parse_usfm(path: Path) -> tuple[str, dict]:
    content = path.read_text(encoding="utf-8-sig")
    id_match = re.search(r"^\\id\s+([0-9A-Z]{3})\b", content, re.MULTILINE)
    if not id_match:
        raise ValueError(f"No USFM book id in {path}")
    code = id_match.group(1)
    if code not in BOOK_CODES:
        return code, {}
    chapters: dict[str, dict] = {}
    chapter: dict | None = None
    current_verse: dict | None = None
    pending_title: str | None = None

    for raw_line in content.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        chapter_match = re.match(r"^\\c\s+(\d+)\b", line)
        if chapter_match:
            chapter = {"verses": []}
            chapters[chapter_match.group(1)] = chapter
            current_verse = None
            pending_title = None
            continue
        if chapter is None:
            continue
        title_match = re.match(r"^\\d\s+(.*)", line)
        if title_match:
            title = clean_text(title_match.group(1))
            pending_title = title or None
            current_verse = None
            continue
        verse_match = re.match(r"^\\v\s+(\S+)\s*(.*)", line)
        if verse_match:
            number = verse_match.group(1)
            if not number.isdigit():
                raise ValueError(f"Unsupported verse number {number!r} in {path}")
            if any(verse["n"] == int(number) for verse in chapter["verses"]):
                raise ValueError(f"Duplicate verse {number} in {path}")
            current_verse = {"n": int(number), "t": clean_text(verse_match.group(2))}
            chapter["verses"].append(current_verse)
            if pending_title and "title" not in chapter:
                chapter["title"] = pending_title
            pending_title = None
            continue
        marker_match = re.match(r"^\\([^\s\\]+)\s*(.*)", line)
        if not marker_match:
            if current_verse:
                current_verse["t"] = clean_text(current_verse["t"] + " " + line)
            continue
        marker, remainder = marker_match.groups()
        if marker in NON_TEXT_MARKERS:
            current_verse = None
        elif current_verse and remainder:
            continuation = clean_text(remainder)
            if continuation:
                current_verse["t"] = clean_text(current_verse["t"] + " " + continuation)

    if not chapters:
        raise ValueError(f"No chapters in {path}")
    return code, {"chapters": chapters}


def source_folder(source: Path) -> tuple[Path, tempfile.TemporaryDirectory | None]:
    if source.is_dir():
        return source, None
    if not zipfile.is_zipfile(source):
        raise ValueError("Source must be a USFM zip or folder")
    temporary = tempfile.TemporaryDirectory(prefix="bible-import-")
    with zipfile.ZipFile(source) as archive:
        archive.extractall(temporary.name)
    return Path(temporary.name), temporary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="USFM zip file or extracted folder")
    parser.add_argument("abbreviation", help="Output translation folder, such as ASV")
    parser.add_argument("--output-root", type=Path, default=Path("Promised Land/Bible/Texts"))
    args = parser.parse_args()

    folder, temporary = source_folder(args.source)
    try:
        parsed: dict[str, dict] = {}
        for path in sorted(folder.rglob("*.usfm")):
            code, book = parse_usfm(path)
            if code in BOOK_CODES:
                parsed[code] = book
        missing = [code for code in BOOK_CODES if code not in parsed]
        if missing:
            raise SystemExit(f"Missing canonical books: {', '.join(missing)}")

        output = args.output_root / args.abbreviation.upper()
        if output.exists():
            shutil.rmtree(output)
        output.mkdir(parents=True)
        for code in BOOK_CODES:
            data = json.dumps(parsed[code], ensure_ascii=False, separators=(",", ":"), sort_keys=True)
            (output / f"{args.abbreviation.upper()}_{code}.json").write_text(data + "\n", encoding="utf-8")
        print(f"Wrote {len(BOOK_CODES)} books to {output}")
    finally:
        if temporary:
            temporary.cleanup()


if __name__ == "__main__":
    main()
