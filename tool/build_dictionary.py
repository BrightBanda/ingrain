#!/usr/bin/env python3
"""Regenerates assets/data/dictionary.json.

Builds a curated Japanese dictionary subset for the ingrain MVP from JMdict:

1. Fetch JMdict_e.gz from EDRDG and parse it into surface -> entry records
   (reading, part of speech, English glosses).
2. Order the candidates so the subset is useful for real material:
   - words that actually appear in Japanese subtitles come first, by
     descending frequency;
   - the rest is filled with JMdict's most common vocabulary band, grouped by
     word length so the everyday 1-2 character words lead.
3. Emit the first N entries as JSON. Selection is deterministic: the same
   inputs always produce the same file.

The output keeps the JMdict/EDICT CC BY-SA 4.0 attribution inside `meta`; the
same credit is shown in the app's Settings screen.

Usage:
    python3 tool/build_dictionary.py [--limit 3000] [--cache-dir .cache]

Downloads are cached, so re-running is cheap. If a download fails the script
exits non-zero and the existing asset is left untouched.
"""

from __future__ import annotations

import argparse
import gzip
import json
import sys
import urllib.request
import xml.etree.ElementTree as ElementTree
from pathlib import Path

FREQUENCY_URL = (
    "https://raw.githubusercontent.com/hermitdave/FrequencyWords/"
    "master/content/2018/ja/ja_full.txt"
)
JMDICT_URLS = (
    "https://www.edrdg.org/pub/Nihongo/JMdict_e.gz",
    "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz",
)

META = {
    "license": "CC BY-SA 4.0",
    "source": "JMdict/EDICT",
    "attribution": (
        "This dictionary data is derived from JMdict (CC BY-SA 4.0). "
        "See https://www.jdic.org/codedoc JMdict for licensing details."
    ),
    "description": "Curated Japanese dictionary subset for ingrain MVP",
}

MAX_GLOSSES = 3
LENGTH_BUCKETS = 6

# The bundled JMdict XML expands its entity references to readable labels such
# as "noun (common) (futsuumeishi)", so parts of speech are matched by their
# leading word.
POS_LABELS = {
    "noun": "noun",
    "suru verb": "verb",
    "ichidan verb": "verb",
    "godan verb": "verb",
    "nidan verb": "verb",
    "verb": "verb",
    "i-adjective": "i-adjective",
    "adjectival": "i-adjective",
    "na-adjective": "na-adjective",
    "adjectival nouns": "na-adjective",
    "adverb": "adverb",
    "adverbial": "adverb",
    "particle": "particle",
    "conjunction": "conjunction",
    "interjection": "interjection",
    "numeric": "numeral",
    "counter": "numeral",
    "pronoun": "pronoun",
    "prefix": "prefix",
    "suffix": "suffix",
    "expression": "expression",
}

# Senses are ranked so a word like 人 shows "person" instead of the rare "-ian"
# suffix reading that happens to come first in the source file.
POS_RANK = {
    "noun": 0,
    "verb": 1,
    "i-adjective": 2,
    "na-adjective": 3,
    "adverb": 4,
    "pronoun": 5,
    "particle": 6,
    "conjunction": 7,
    "interjection": 8,
    "numeral": 9,
    "expression": 10,
    "prefix": 11,
    "suffix": 12,
}

# JMdict priority bands, best first.
COMMON_PRIORITIES = {"ichi1", "news1"}
SECOND_PRIORITIES = {"ichi2", "news2"}
DEFAULT_NEWS_RANK = 99
# How many common-vocabulary words are interleaved per subtitle-frequency word.
# The frequency list tokenises everyday words out of existence (猫, 食べる,
# 見る are all absent), so JMdict's common band is weighted higher.
COMMON_WEIGHT = 2

HALFWIDTH_KATAKANA_START = 0xFF61
HALFWIDTH_KATAKANA_END = 0xFF9F
HALFWIDTH_KANA_OFFSET = HALFWIDTH_KATAKANA_START - 0x30A1
KATAKANA_START = 0x30A1
KATAKANA_END = 0x30F6
HIRAGANA_OFFSET = KATAKANA_START - 0x3041
CJK_START = 0x3040
CJK_END = 0x9FFF
HALFWIDTH_START = 0xFF01
HALFWIDTH_END = 0xFF60

# An entry whose canonical sense is a prefix or a suffix describes a derived
# form, never the word itself, so it loses to a real headword meaning.
AFFIX_LABELS = {"prefix", "suffix"}


def to_hiragana(text: str) -> str:
    """Normalises katakana (half or full width) to hiragana."""
    out = []
    for ch in text:
        code = ord(ch)
        if HALFWIDTH_KATAKANA_START <= code <= HALFWIDTH_KATAKANA_END:
            out.append(chr(code - HALFWIDTH_KANA_OFFSET))
        elif KATAKANA_START <= code <= KATAKANA_END:
            out.append(chr(code - HIRAGANA_OFFSET))
        else:
            out.append(ch)
    return "".join(out)


def to_fullwidth_kana(text: str) -> str:
    """Widens halfwidth katakana so subtitle text can match the headword."""
    return "".join(
        chr(ord(ch) + HALFWIDTH_KANA_OFFSET)
        if HALFWIDTH_KATAKANA_START <= ord(ch) <= HALFWIDTH_KATAKANA_END
        else ch
        for ch in text
    )


def is_japanese(text: str) -> bool:
    return any(
        CJK_START <= ord(ch) <= CJK_END
        or HALFWIDTH_START <= ord(ch) <= HALFWIDTH_END
        for ch in text
    )


def download(urls: tuple[str, ...], cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    cached = cache_dir / urls[0].rsplit("/", 1)[-1]
    if cached.exists() and cached.stat().st_size > 0:
        return cached

    errors = []
    for candidate in urls:
        try:
            request = urllib.request.Request(
                candidate, headers={"User-Agent": "ingrain-dictionary-builder"}
            )
            with urllib.request.urlopen(request, timeout=180) as response:
                payload = response.read()
            cached.write_bytes(payload)
            return cached
        except Exception as error:  # noqa: BLE001 - report and try the mirror
            errors.append(f"{candidate}: {error}")
    raise RuntimeError("download failed -> " + " | ".join(errors))


def read_frequency(cache_dir: Path) -> list[str]:
    """Surfaces that appear in Japanese subtitles, most frequent first."""
    raw = download((FREQUENCY_URL,), cache_dir).read_text(
        encoding="utf-8", errors="replace"
    )
    counts: dict[str, int] = {}
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) != 2 or not parts[1].isdigit():
            continue
        if not is_japanese(parts[0]):
            continue
        counts[parts[0]] = int(parts[1])
    return [
        surface
        for surface, _ in sorted(
            counts.items(), key=lambda kv: (-kv[1], kv[0])
        )
    ]


def _text(element: ElementTree.Element | None) -> str:
    return (element.text or "").strip() if element is not None else ""


def _pos_label(element: ElementTree.Element) -> str:
    """Maps a JMdict <pos> element to one of the labels above."""
    head = _text(element).split("(")[0].strip().lower()
    if not head:
        return ""
    return POS_LABELS.get(head, POS_LABELS.get(head.split()[0], ""))


def _priorities_for(entry: ElementTree.Element) -> set[str]:
    return {
        _text(node).strip()
        for node in entry.iter()
        if node.tag in ("ke_pri", "re_pri")
    }


def _priority_band(entry: ElementTree.Element) -> int:
    priorities = _priorities_for(entry)
    if priorities & COMMON_PRIORITIES:
        return 0
    if priorities & SECOND_PRIORITIES:
        return 1
    return 2


def _news_rank(entry: ElementTree.Element) -> int:
    """JMdict's news-frequency rank (nf01 is the most common)."""
    ranks = [
        int(priority[2:])
        for priority in _priorities_for(entry)
        if priority.startswith("nf") and priority[2:].isdigit()
    ]
    return min(ranks) if ranks else DEFAULT_NEWS_RANK


def _sequence(entry: ElementTree.Element) -> int:
    try:
        return int(_text(entry.find("ent_seq")))
    except ValueError:
        return 0


def _readings_for(entry: ElementTree.Element) -> list[str]:
    """Full readings for the entry, hiragana, in source order."""
    readings = []
    for r_ele in entry.findall("r_ele"):
        reading = _text(r_ele.find("reb")) or _text(r_ele.find("rb"))
        if reading:
            readings.append(to_hiragana(reading))
    return readings


def _surfaces_for(entry: ElementTree.Element, readings: list[str]) -> list[str]:
    """Every spelling of the entry, including its kana form."""
    surfaces: list[str] = []
    for k_ele in entry.findall("k_ele"):
        for keb in k_ele.findall("keb"):
            surface = to_fullwidth_kana(_text(keb))
            if surface and is_japanese(surface):
                surfaces.append(surface)
    if not surfaces and readings and is_japanese(readings[0]):
        surfaces.append(readings[0])
    return surfaces


def _senses_for(entry: ElementTree.Element) -> tuple[int, str, list[str]]:
    """Returns (rank, pos label, glosses) for the entry's canonical sense.

    JMdict already lists senses in order of importance, so the first sense is
    taken as the meaning. Senses carrying a `misc` marker (archaic, slang,
    abbreviation, ...) are skipped so 何 resolves to "what" instead of a marked
    colloquial reading. Only an entry whose canonical sense is a prefix or a
    suffix is downgraded, which keeps 人 on "person" rather than its rare
    "-ian" suffix reading while leaving verb and adjective entries alone.
    """
    unmarked: list[str] = []
    fallback: list[str] = []

    for sense in entry.findall("sense"):
        glosses = [
            _text(gloss) for gloss in sense.findall("gloss") if _text(gloss)
        ]
        if not glosses:
            continue
        if sense.findall("misc"):
            fallback = fallback or glosses
            continue
        if not unmarked:
            unmarked = glosses

    meanings = unmarked or fallback
    if not meanings:
        return (len(POS_RANK), "", [])

    label = ""
    rank = 0
    for sense in entry.findall("sense"):
        if sense.findall("misc"):
            continue
        glosses = [_text(gloss) for gloss in sense.findall("gloss")]
        if not any(gloss and gloss in meanings for gloss in glosses):
            continue
        labels = [
            value
            for value in (_pos_label(pos) for pos in sense.findall("pos"))
            if value
        ]
        if labels:
            label = labels[0]
            rank = 1 if label in AFFIX_LABELS else 0
        break

    return (rank, label, meanings[:MAX_GLOSSES])


def parse_jmdict(cache_dir: Path) -> dict[str, dict]:
    """Returns surface -> {reading, pos, meanings, band, rank}."""
    path = download(JMDICT_URLS, cache_dir)
    entries: dict[str, dict] = {}

    with gzip.open(path, "rb") as stream:
        context = ElementTree.iterparse(stream, events=("start", "end"))
        _, root = next(context)
        for event, element in context:
            if event != "end" or element.tag != "entry":
                continue

            rank, label, meanings = _senses_for(element)
            if meanings:
                readings = _readings_for(element)
                reading = readings[0] if readings else ""
                band = _priority_band(element)
                record = {
                    "reading": reading,
                    "pos": label,
                    "meanings": meanings,
                    "band": band,
                    "rank": rank,
                    "newsRank": _news_rank(element),
                    "sequence": _sequence(element),
                }
                for surface in _surfaces_for(element, readings):
                    existing = entries.get(surface)
                    # The most common band, then the most useful part of
                    # speech, then the source ordering decides which sense a
                    # spelling resolves to.
                    if existing is None or (band, rank, record["sequence"]) < (
                        existing["band"],
                        existing["rank"],
                        existing["sequence"],
                    ):
                        entries[surface] = record
            element.clear()
            root.clear()

    return entries


def select(entries: dict[str, dict], frequent: list[str], limit: int) -> list[str]:
    """Interleaves real subtitle words with JMdict's common vocabulary.

    The subtitle frequency list alone misses everyday words its tokeniser split
    away (猫, 食べる, 見る), while JMdict's news band alone misses colloquial
    material, so the two sources are woven together at a 1:2 ratio rather than
    one crowding the other out.
    """
    in_frequency = [
        surface for surface in frequent if surface in entries
    ][:limit]

    seen = set(in_frequency)
    by_commonness = sorted(
        (surface for surface in entries if surface not in seen),
        key=lambda surface: (
            entries[surface]["band"],
            entries[surface]["newsRank"],
            min(len(surface), LENGTH_BUCKETS),
            surface,
        ),
    )[:limit]

    ordered: list[str] = []
    primary = 0
    secondary = 0
    while len(ordered) < limit and (
        primary < len(in_frequency) or secondary < len(by_commonness)
    ):
        if primary < len(in_frequency) and len(ordered) < limit:
            ordered.append(in_frequency[primary])
            primary += 1
        for _ in range(COMMON_WEIGHT):
            if secondary < len(by_commonness) and len(ordered) < limit:
                ordered.append(by_commonness[secondary])
                secondary += 1
    return ordered


def build(limit: int, cache_dir: Path) -> dict:
    frequent = read_frequency(cache_dir)
    entries = parse_jmdict(cache_dir)

    output: list[dict] = []
    for surface in select(entries, frequent, limit):
        record = entries[surface]
        entry = {
            "surface": surface,
            "reading": record["reading"] or surface,
            "meanings": record["meanings"],
        }
        if record["pos"]:
            entry["pos"] = record["pos"]
        output.append(entry)

    meta = dict(META)
    meta["entryCount"] = len(output)
    return {"meta": meta, "entries": output}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=8000)
    parser.add_argument(
        "--cache-dir",
        default=".cache",
        help="Where downloaded sources are cached (default: .cache)"
    )
    parser.add_argument(
        "--output",
        default="assets/data/dictionary.json",
        help="Destination asset path",
    )
    args = parser.parse_args()

    try:
        payload = build(args.limit, Path(args.cache_dir))
    except Exception as error:  # noqa: BLE001 - surface a clean CLI failure
        print(f"error: {error}", file=sys.stderr)
        return 1

    destination = Path(args.output)
    if not payload["entries"]:
        print("error: no entries produced", file=sys.stderr)
        return 1

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(
        f"wrote {len(payload['entries'])} entries to {destination} "
        f"({destination.stat().st_size} bytes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())