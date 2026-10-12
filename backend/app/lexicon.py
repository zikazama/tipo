"""Keyword lexicon for the deterministic mock agents.

Live mode asks Gemini to do this reading. Mock mode uses the same labels so the
Dayeuhkolot replay is stable for judges and unit tests.
"""

from __future__ import annotations

import re
import unicodedata

# Distinctive tokens. Indonesian flood words are shared; regional markers decide language.
SUNDA = {
    "punten", "geus", "kolot", "lembur", "orok", "mangga", "tiasa", "caah",
    "nyarande", "nyarandé", "ema-ema", "bantosan", "dibantosan", "teu", "jeung", "cai",
}
JAVA = {
    "ngapunten", "banyu", "dengkul", "dalan", "lara", "nganti", "dodo", "wis",
    "sing", "peteng", "geni", "omahe", "omah", "cedhak", "sesuk", "ambegan",
}
VULNERABLE = (
    ("elderly", ("lansia", "kolot", "wong tuwa", "elderly", "nenek", "kakek")),
    ("infants", ("orok", "bayi", "infant", "budak orok")),
    ("disability", ("disabilitas", "difabel", "disability")),
    ("pregnant", ("ibu hamil", "bumil", "hamil")),
)

NEEDS = (
    ("boat", ("perahu", "boat", "karet")),
    ("firefighting", ("damkar", "pemadam", "truk tangki", "manggala agni", "firefight", "water bombing", "apd")),
    ("evacuation", ("evakuasi", "mengungsi", "evacuation")),
    ("medicine", ("obat", "medicine", "puskesmas", "klinik", "masker", "sesak")),
    ("water", ("air minum", "air bersih", "drinking water")),
    ("food", ("makanan", "sembako", "food")),
)

PLACE_KEYS = (
    ("cangkuang", ("cangkuang",)),
    ("bojongsoang", ("bojongsoang",)),
    ("baleendah", ("baleendah", "andir")),
    ("dayeuhkolot", ("dayeuhkolot", "sukabirus", "al-ikhlas", "al ikhlas", "pasawahan")),
    ("telukmeranti", ("teluk meranti", "telukmeranti")),
    ("bunut", ("bunut",)),
    ("segati", ("segati",)),
)


def tokens(text: str) -> list[str]:
    norm = unicodedata.normalize("NFKD", text.lower())
    norm = "".join(ch for ch in norm if not unicodedata.combining(ch))
    return re.findall(r"[a-z0-9]+(?:-[a-z0-9]+)?", norm)


def detect_language(text: str) -> str:
    toks = set(tokens(text))
    su = len(toks & SUNDA)
    jv = len(toks & {t for t in JAVA if t not in {"sing", "wis"}})
    # 'sing' and 'wis' are short; still count them but Sundanese 'cai' is strong.
    jv += len(toks & {"sing", "wis"})
    if su >= 2 and su >= jv:
        return "su"
    if jv >= 2 and jv > su:
        return "jv"
    if re.search(r"[a-z]", text.lower()) and any(w in toks for w in ("the", "flood", "water", "trapped")):
        if "banjir" not in toks and "cai" not in toks and "banyu" not in toks:
            return "en"
    return "id"


def detect_hazard(text: str) -> str:
    low = unicodedata.normalize("NFKD", text.lower())
    low = "".join(ch for ch in low if not unicodedata.combining(ch))
    if any(w in low for w in ("longsor", "ambles", "tanah bergerak", "landslide")):
        return "landslide"
    if any(w in low for w in ("gempa", "lindu", "earthquake")):
        return "earthquake"
    if any(
        w in low
        for w in (
            "karhutla",
            "kebakaran hutan",
            "kebakaran lahan",
            "lahan gambut",
            "gambut terbakar",
            "wildfire",
            "peatland fire",
            "hotspot",
            "asap tebal",
            "menjalar",
        )
    ) or re.search(r"\b(geni|kebakaran|asap)\b", low) is not None:
        return "fire"
    if (
        any(w in low for w in ("banjir", "caah", "banyu", "flood", "terendam", "setinggi"))
        or re.search(r"\bcai\b", low) is not None
        or re.search(r"\bair\b", low) is not None
    ):
        return "flood"
    return "other"


def detect_vulnerable(text: str) -> list[str]:
    low = text.lower()
    found = [label for label, words in VULNERABLE if any(w in low for w in words)]
    return found


def _mentioned(text: str, word: str) -> bool:
    """True when a word appears and is not cancelled by belum/tidak just before it."""
    low = text.lower()
    if word not in low:
        return False
    return re.search(rf"(belum|tidak|tdk|tanpa)\s+(\w+\s+){{0,4}}{re.escape(word)}", low) is None


def detect_needs(text: str) -> list[str]:
    low = text.lower()
    found = [label for label, words in NEEDS if any(w in low for w in words)]
    trapped_word = any(_mentioned(low, w) for w in ("terjebak", "kejebak", "kepepet"))
    if trapped_word:
        if "evacuation" not in found:
            found.append("evacuation")
        hazard = detect_hazard(text)
        if "boat" not in found and hazard == "flood":
            found.append("boat")
        if "firefighting" not in found and hazard == "fire":
            found.append("firefighting")
    return found


def place_key(text: str, place_name: str = "") -> str:
    blob = f"{text} {place_name}".lower()
    for key, words in PLACE_KEYS:
        if any(w in blob for w in words):
            return key
    return "unknown"


def severity_hint(text: str) -> int:
    low = text.lower()
    trapped = any(_mentioned(low, w) for w in ("terjebak", "kejebak", "kepepet"))
    if any(w in low for w in ("setinggi rumah", "setinggi atap", "nyawa", "kritis", "mengepung rumah", "menjalar ke permukiman")):
        return 5
    if trapped or any(w in low for w in ("dada", "dodo", "chest", "lantai dua", "lantai 2", "sesak", "ambegan")):
        return 5
    if any(w in low for w in ("pinggang", "waist", "asap tebal", "rumah terancam", "cedhak omah")):
        return 4
    if any(w in low for w in ("lutut", "dengkul", "knee", "masuk ke rumah", "terendam", "asap", "hotspot")):
        return 3
    if any(w in low for w in ("naik", "rising", "mulai", "bergerak")):
        return 2
    return 2


_PEOPLE = re.compile(r"(\d+)\s*(jiwa|orang|warga|people)", re.I)
_HOUSE = re.compile(r"(\d+)\s*(rumah tangga|keluarga|kk|households|families|rumah)", re.I)
_TRAPPED = re.compile(r"(\d+)\s*(lansia|kolot|orang|jiwa|warga|elderly)?[^\.]{0,40}(terjebak|kejebak|kepepet)", re.I)
_TRAPPED_REV = re.compile(r"(terjebak|kejebak|kepepet)[^\.]{0,40}(\d+)\s*(lansia|kolot|orang|jiwa)?", re.I)
_VULN_COUNT = re.compile(r"(\d+)\s*(lansia|kolot|bayi|orok|ibu hamil)", re.I)


def extract_counts(text: str) -> dict:
    people_vals = [int(m.group(1)) for m in _PEOPLE.finditer(text)]
    for m in _HOUSE.finditer(text):
        word = m.group(2).lower()
        n = int(m.group(1))
        people_vals.append(n if word == "rumah" else n * 4)
    people = max(people_vals) if people_vals else 0
    trapped_vals: list[int] = []
    for m in _TRAPPED.finditer(text):
        window = text[max(0, m.start() - 24) : m.end()]
        if re.search(r"belum|tidak|tdk|tanpa", window, re.I):
            continue
        trapped_vals.append(int(m.group(1)))
    for m in _TRAPPED_REV.finditer(text):
        window = text[max(0, m.start() - 24) : m.end()]
        if re.search(r"belum|tidak|tdk|tanpa", window, re.I):
            continue
        trapped_vals.append(int(m.group(2)))
    trapped = max(trapped_vals) if trapped_vals else 0
    vuln_n = max([int(m.group(1)) for m in _VULN_COUNT.finditer(text)] or [0])
    if trapped == 0 and vuln_n and any(w in text.lower() for w in ("terjebak", "kejebak", "kepepet")):
        trapped = vuln_n
    if people == 0 and trapped:
        people = trapped
    if people == 0 and vuln_n:
        people = vuln_n
    return {"people_affected": people, "trapped": trapped}
