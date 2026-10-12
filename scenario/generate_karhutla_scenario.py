"""Build the Pelalawan karhutla (peat / land fire) scenario and placeholder media.

Photos are drawn diagrams labeled SIMULATED. Voice files are short tones plus transcripts.
"""

from __future__ import annotations

import json
import math
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
MEDIA = ROOT / "media"
OUT = ROOT / "pelalawan_karhutla.json"


def _font(size: int):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _card(name: str, bg: tuple[int, int, int], title: str, lines: list[str], stamp: str) -> None:
    image = Image.new("RGB", (960, 540), bg)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 960, 18), fill=(196, 80, 42))
    draw.text((36, 48), "SIMULATED EVIDENCE", fill=(255, 236, 214), font=_font(18))
    draw.text((36, 90), title, fill=(255, 250, 242), font=_font(36))
    y = 170
    for line in lines:
        draw.text((36, y), line, fill=(232, 224, 208), font=_font(24))
        y += 40
    draw.rectangle((0, 480, 960, 540), fill=(12, 18, 24))
    draw.text((36, 496), stamp, fill=(242, 180, 68), font=_font(20))
    image.save(MEDIA / name, "PNG")


def _tone(name: str, freq: float) -> None:
    rate = 8000
    seconds = 0.6
    path = MEDIA / name
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        frames = bytearray()
        for i in range(int(rate * seconds)):
            sample = int(1800 * math.sin(2 * math.pi * freq * i / rate))
            frames += struct.pack("<h", sample)
        handle.writeframes(frames)


def build() -> dict:
    reports = [
        dict(
            id="kh-01", delay_s=0, channel="app", reporter_id="warga-k01",
            lat=0.3520, lng=101.9120, place_name="Segati, Pelalawan",
            text="Karhutla di Segati, Pelalawan. Lahan gambut terbakar, asap tebal. Sekitar 80 jiwa terdampak, butuh damkar.",
            translation_en="Forest and land fire in Segati, Pelalawan. Peatland is burning, smoke is thick. About 80 people affected, need firefighters.",
        ),
        dict(
            id="kh-02", delay_s=3.0, channel="app", reporter_id="warga-k02",
            lat=0.3514, lng=101.9132, place_name="Segati",
            photo_file="fire_haze.png",
            text="Foto asap di Segati. Api menjalar ke tepi kebun, jarak pandang sangat buruk.",
            translation_en="Smoke photo in Segati. Fire is spreading to the edge of the plantation, visibility is very poor.",
        ),
        dict(
            id="kh-03", delay_s=3.2, channel="voice", reporter_id="warga-k03",
            lat=0.3526, lng=101.9114, place_name="Segati",
            audio_file="voice_id_karhutla.wav",
            transcript="Tolong, kebakaran lahan gambut di Segati. Asap tebal, 20 rumah terancam. Butuh truk tangki dan evakuasi.",
            text="Tolong, kebakaran lahan gambut di Segati. Asap tebal, 20 rumah terancam. Butuh truk tangki dan evakuasi.",
            translation_en="Please help, peatland fire in Segati. Thick smoke, 20 houses threatened. Need tank trucks and evacuation.",
        ),
        dict(
            id="kh-04", delay_s=1.2, channel="whatsapp_sim", reporter_id="warga-k04",
            lat=0.3522, lng=101.9118, place_name="Segati",
            text="WA: sama seperti voice tadi, kebakaran lahan di Segati, 20 rumah terancam, butuh damkar sekarang.",
            translation_en="WhatsApp: same as the voice note, land fire in Segati, 20 houses threatened, need firefighters now.",
        ),
        dict(
            id="kh-05", delay_s=3.4, channel="app", reporter_id="warga-k05",
            lat=0.3508, lng=101.9105, place_name="Jalan Segati",
            text="Karhutla Segati, sekitar 80 jiwa. Sekolah tutup karena asap. Warga butuh masker dan air minum.",
            translation_en="Karhutla in Segati, about 80 people. School closed because of smoke. Residents need masks and drinking water.",
        ),
        dict(
            id="kh-06", delay_s=3.0, channel="voice", reporter_id="warga-k06",
            lat=0.3531, lng=101.9140, place_name="Segati kebun",
            audio_file="voice_jv_smoke.wav",
            transcript="Ngapunten, geni ing Segati wis cedhak omah. Ana wong tuwa sing sesuk ora bisa ambegan. Butuh obat lan masker.",
            text="Ngapunten, geni ing Segati wis cedhak omah. Ana wong tuwa sing sesuk ora bisa ambegan. Butuh obat lan masker.",
            translation_en="Sorry, the fire in Segati is already near the houses. An elderly person is struggling to breathe. Need medicine and masks.",
        ),
        dict(
            id="kh-07", delay_s=3.1, channel="petabencana", reporter_id="pb-k01",
            lat=0.3518, lng=101.9125, place_name="Segati",
            text="PetaBencana report: peatland fire hotspot cluster near Segati, Pelalawan. Smoke reducing visibility on the main road.",
            translation_en="PetaBencana report: peatland fire hotspot cluster near Segati, Pelalawan. Smoke reducing visibility on the main road.",
        ),
        dict(
            id="kh-08", delay_s=1.3, channel="whatsapp_sim", reporter_id="warga-k08",
            lat=0.3510, lng=101.9110, place_name="Segati",
            text="Grup RT: ulang, 80 jiwa terdampak karhutla Segati, 20 rumah terancam. Mohon logistik masker.",
            translation_en="Neighborhood group: repeating, 80 people affected by the Segati karhutla, 20 houses threatened. Please send mask supplies.",
        ),
        dict(
            id="kh-09", delay_s=2.8, channel="app", reporter_id="warga-k09",
            lat=0.3535, lng=101.9135, place_name="Segati",
            text="3 orang terjebak asap di kebun sawit Segati. Tidak bisa keluar ke jalan utama. Butuh evakuasi.",
            translation_en="3 people are trapped by smoke in a Segati palm plantation. Cannot reach the main road. Need evacuation.",
        ),
        dict(
            id="kh-10", delay_s=2.6, channel="app", reporter_id="warga-k10",
            lat=0.3502, lng=101.9098, place_name="Segati",
            text="Api menjalar ke permukiman Segati. Butuh pemadam dan truk tangki air dari Manggala Agni.",
            translation_en="Fire is spreading into Segati settlement. Need firefighters and water tank trucks from Manggala Agni.",
        ),
        dict(
            id="kh-11", delay_s=1.4, channel="app", reporter_id="warga-k11",
            lat=0.3524, lng=101.9128, place_name="Segati",
            text="Saya di titik yang sama dengan laporan pertama. Karhutla Segati masih aktif, lansia sesak napas belum tertolong.",
            translation_en="I am at the same spot as the first report. Segati karhutla still active, the elderly person with breathing trouble has not been helped.",
        ),
        dict(
            id="kh-12", delay_s=4.0, channel="app", reporter_id="warga-k12",
            lat=0.2780, lng=102.1480, place_name="Bunut, Pelalawan",
            text="Kebakaran lahan di Bunut, asap mulai masuk kampung. Sekitar 35 jiwa terdampak, belum ada yang terjebak.",
            translation_en="Land fire in Bunut, smoke is entering the village. About 35 people affected, nobody trapped yet.",
        ),
        dict(
            id="kh-13", delay_s=2.7, channel="app", reporter_id="warga-k13",
            lat=0.2788, lng=102.1472, place_name="Bunut",
            photo_file="fire_haze.png",
            text="Foto asap Bunut dari jalan desa. Api masih di lahan, belum mengepung rumah.",
            translation_en="Smoke photo from the Bunut village road. Fire is still in the field, has not surrounded houses.",
        ),
        dict(
            id="kh-14", delay_s=2.4, channel="whatsapp_sim", reporter_id="warga-k14",
            lat=0.2774, lng=102.1488, place_name="Bunut",
            text="Duplikat grup: Bunut asap tebal, 35 jiwa. Mohon dicatat satu laporan saja.",
            translation_en="Group duplicate: Bunut thick smoke, 35 people. Please log as one report.",
        ),
        dict(
            id="kh-15", delay_s=2.9, channel="petabencana", reporter_id="pb-k02",
            lat=0.2792, lng=102.1495, place_name="Bunut",
            text="PetaBencana: land-fire report Bunut, Pelalawan. Road still open to high vehicles.",
            translation_en="PetaBencana: land-fire report in Bunut, Pelalawan. Road still open to high vehicles.",
        ),
        dict(
            id="kh-16", delay_s=3.4, channel="app", reporter_id="warga-k16",
            lat=0.1560, lng=102.3850, place_name="Teluk Meranti",
            text="Asap dari kebakaran lahan di Teluk Meranti. Sekitar 18 jiwa terganggu napas, butuh masker.",
            translation_en="Smoke from a land fire in Teluk Meranti. About 18 people with breathing trouble, need masks.",
        ),
        dict(
            id="kh-17", delay_s=2.2, channel="whatsapp_sim", reporter_id="warga-k17",
            lat=0.1568, lng=102.3862, place_name="Teluk Meranti",
            text="Duplikat: Teluk Meranti asap, 18 jiwa. Sama dengan laporan warga tadi.",
            translation_en="Duplicate: Teluk Meranti smoke, 18 people. Same as the earlier citizen report.",
        ),
        dict(
            id="kh-18", delay_s=4.4, channel="whatsapp_sim", reporter_id="warga-k18",
            lat=0.3515, lng=101.9122, place_name="Segati",
            photo_file="hoax_city_fire_2023.png",
            text="API BESAR Segati! Sebarkan sekarang sebelum seluruh desa habis!",
            translation_en="HUGE FIRE in Segati! Forward this now before the whole village is gone!",
            exif={"taken_at": "2023-08-17T21:05:00+07:00", "lat": -6.21, "lng": 106.85, "source": "simulated_exif"},
            image_cues=[
                "Urban skyline and highway, not peat plantation",
                "Television watermark: METRO SIAR 2023",
                "Re-shared screenshot with heavy recompression",
            ],
        ),
        dict(
            id="kh-19", delay_s=2.4, channel="whatsapp_sim", reporter_id="warga-k19",
            lat=0.3505, lng=101.9138, place_name="Segati",
            photo_file="hoax_city_fire_2023.png",
            text="Foto kebakaran Segati tadi malam dari grup. Share ke semua RT.",
            translation_en="Segati fire photo from last night in the group. Share to every RT.",
            exif={"taken_at": "2023-08-17T21:05:00+07:00", "lat": -6.21, "lng": 106.85, "source": "simulated_exif"},
            image_cues=[
                "Same urban frame as the earlier claim",
                "Date stamp burned in: 2023-08-17",
                "Old social repost, not a new camera frame",
            ],
        ),
        dict(
            id="kh-20", delay_s=1.5, channel="app", reporter_id="warga-k20",
            lat=0.3519, lng=101.9116, place_name="Segati",
            text="Update Segati: api masih aktif di lahan gambut, akses jalan utama masih bisa untuk truk damkar.",
            translation_en="Segati update: fire still active on peatland, main road still open for fire trucks.",
        ),
    ]
    gaps = [float(r["delay_s"]) for r in reports]
    target = 70.0
    scale = target / max(sum(gaps[1:]), 1)
    for index, report in enumerate(reports):
        report["delay_s"] = 0 if index == 0 else round(report["delay_s"] * scale, 2)
        report["simulated"] = True
        report.setdefault("transcript", report["text"])
        report.setdefault("image_cues", [])
        report.setdefault("exif", None)

    return {
        "id": "pelalawan-karhutla-2026",
        "title": "Karhutla drill — Segati, Kabupaten Pelalawan",
        "hazard": "fire",
        "tagline": "Read the signs. Act first.",
        "summary": (
            "Twenty simulated citizen reports of a peatland fire (karhutla) at Segati, Pelalawan, "
            "plus Bunut and Teluk Meranti, and two old urban-fire photo claims that should stay "
            "out of the confirmed cluster."
        ),
        "ethics": "All photos are drawn placeholders. Voice files are tones plus transcripts, not field recordings.",
        "reports": reports,
        "samples": [
            {
                "id": "id-karhutla",
                "label": "Indonesian voice note — peatland fire, evacuation",
                "channel": "voice",
                "transcript": reports[2]["transcript"],
                "text": reports[2]["text"],
                "translation_en": reports[2]["translation_en"],
                "lat": reports[2]["lat"],
                "lng": reports[2]["lng"],
                "place_name": reports[2]["place_name"],
                "audio_file": "voice_id_karhutla.wav",
                "hazard_hint": "fire",
            },
            {
                "id": "jv-smoke",
                "label": "Javanese voice note — smoke, elderly breathing",
                "channel": "voice",
                "transcript": reports[5]["transcript"],
                "text": reports[5]["text"],
                "translation_en": reports[5]["translation_en"],
                "lat": reports[5]["lat"],
                "lng": reports[5]["lng"],
                "place_name": reports[5]["place_name"],
                "audio_file": "voice_jv_smoke.wav",
                "hazard_hint": "fire",
            },
            {
                "id": "fire-photo",
                "label": "Simulated haze photo — Segati",
                "channel": "app",
                "text": reports[1]["text"],
                "translation_en": reports[1]["translation_en"],
                "lat": reports[1]["lat"],
                "lng": reports[1]["lng"],
                "place_name": reports[1]["place_name"],
                "photo_file": "fire_haze.png",
                "hazard_hint": "fire",
            },
            {
                "id": "hoax-city-fire",
                "label": "Old-photo sample — should score low",
                "channel": "whatsapp_sim",
                "text": reports[17]["text"],
                "translation_en": reports[17]["translation_en"],
                "lat": reports[17]["lat"],
                "lng": reports[17]["lng"],
                "place_name": reports[17]["place_name"],
                "photo_file": "hoax_city_fire_2023.png",
                "exif": reports[17]["exif"],
                "image_cues": reports[17]["image_cues"],
                "hazard_hint": "fire",
            },
        ],
        "presence": [
            {"reporter_id": "listener-k01", "lat": 0.3600, "lng": 101.9000, "label": "Standby citizen, north of Segati"},
            {"reporter_id": "listener-k02", "lat": 0.3450, "lng": 101.9250, "label": "Standby citizen, plantation edge"},
            {"reporter_id": "listener-k03", "lat": 0.3650, "lng": 101.9300, "label": "Standby citizen, 1 km east"},
        ],
        "resources": {
            "teams": [
                {
                    "id": "damkar-plw-1",
                    "name": "Damkar unit 1",
                    "kind": "fire",
                    "posko": "Posko Manggala Agni Pelalawan",
                    "lat": 0.3970,
                    "lng": 101.8570,
                    "crew": 6,
                },
                {
                    "id": "damkar-plw-2",
                    "name": "Damkar unit 2",
                    "kind": "fire",
                    "posko": "Posko Manggala Agni Pelalawan",
                    "lat": 0.3974,
                    "lng": 101.8576,
                    "crew": 6,
                },
                {
                    "id": "medic-kerinci",
                    "name": "Medical squad",
                    "kind": "medical",
                    "posko": "Posko Pangkalan Kerinci",
                    "lat": 0.4000,
                    "lng": 101.8500,
                    "crew": 3,
                },
                {
                    "id": "truck-bpbd-riau",
                    "name": "Logistics truck",
                    "kind": "logistics",
                    "posko": "Posko BPBD Pelalawan",
                    "lat": 0.4050,
                    "lng": 101.8450,
                    "crew": 2,
                },
            ],
            "shelters": [
                {
                    "id": "gor-kerinci",
                    "name": "GOR Pangkalan Kerinci",
                    "lat": 0.4020,
                    "lng": 101.8480,
                    "capacity": 400,
                    "occupied": 60,
                },
                {
                    "id": "sdn-bunut",
                    "name": "SDN Bunut 1",
                    "lat": 0.2810,
                    "lng": 102.1450,
                    "capacity": 150,
                    "occupied": 20,
                },
            ],
        },
        "bmkg": {
            "label": "Recorded dry-season snapshot for the Pelalawan karhutla replay. Not a live SIPONGI feed.",
            "live_note": (
                "This drill uses a dry haze snapshot so verification stays repeatable. "
                "Live BMKG forecast tools still call the public API when TIPO_MODE=live. "
                "Hotspot layers (SIPONGI / LAPAN) are out of scope for this prototype."
            ),
            "areas": {
                "segati": {
                    "adm4": None,
                    "name": "Segati area, Kab. Pelalawan, Riau",
                    "weather_desc_en": "Haze",
                    "tp_mm": 0,
                    "period": "3h",
                    "source": "scenario_snapshot",
                    "fire_risk": "high",
                    "note": "Dry peat-season snapshot for the karhutla drill.",
                },
                "bunut": {
                    "adm4": None,
                    "name": "Bunut area, Kab. Pelalawan, Riau",
                    "weather_desc_en": "Haze",
                    "tp_mm": 1,
                    "period": "3h",
                    "source": "scenario_snapshot",
                    "fire_risk": "high",
                },
                "telukmeranti": {
                    "adm4": None,
                    "name": "Teluk Meranti area, Kab. Pelalawan, Riau",
                    "weather_desc_en": "Mostly cloudy",
                    "tp_mm": 2,
                    "period": "3h",
                    "source": "scenario_snapshot",
                    "fire_risk": "elevated",
                },
            },
            "earthquake": {
                "source": "https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json",
                "fetched_at": "2026-10-10T11:00:00+07:00",
                "magnitude": 2.4,
                "place": "Pusat gempa berada di darat 12 km barat Kendari",
                "coordinates": [-3.96, 122.40],
                "time_wib": "09 Okt 2026 17:34:55 WIB",
                "note": "Far from Riau; does not support a local quake claim.",
            },
            "nowcast": [
                {
                    "title": "Recorded drill item: dry haze signal for eastern Pelalawan peatlands",
                    "link": "https://www.bmkg.go.id/alerts/nowcast/id/rss.xml",
                }
            ],
        },
    }


def main() -> None:
    MEDIA.mkdir(parents=True, exist_ok=True)
    _card(
        "fire_haze.png",
        (78, 52, 36),
        "Segati haze",
        ["Orange smoke over peat lanes.", "No people shown.", "Placeholder for a citizen photo."],
        "SIMULATED  ·  not a photograph of a real event",
    )
    _card(
        "hoax_city_fire_2023.png",
        (48, 42, 58),
        "Urban frame",
        ["City skyline and highway glow.", "Watermark: METRO SIAR  2023", "Used to demo an old-photo cue."],
        "SIMULATED EXIF  2023-08-17  ·  GPS near Jakarta",
    )
    _tone("voice_id_karhutla.wav", 196)
    _tone("voice_jv_smoke.wav", 233)
    (MEDIA / "voice_id_karhutla.txt").write_text(
        "Tolong, kebakaran lahan gambut di Segati. Asap tebal, 20 rumah terancam. "
        "Butuh truk tangki dan evakuasi.\n",
        encoding="utf-8",
    )
    (MEDIA / "voice_jv_smoke.txt").write_text(
        "Ngapunten, geni ing Segati wis cedhak omah. "
        "Ana wong tuwa sing sesuk ora bisa ambegan. Butuh obat lan masker.\n",
        encoding="utf-8",
    )
    payload = build()
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total = sum(r["delay_s"] for r in payload["reports"])
    print(f"wrote {OUT} reports={len(payload['reports'])} replay_span_s={total:.1f}")


if __name__ == "__main__":
    main()
