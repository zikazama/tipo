"""Build the Dayeuhkolot flood scenario, placeholder photos, and silent voice notes.

Photos are drawn diagrams labeled SIMULATED. They are not pictures of real victims.
Voice files are short tones plus a transcript, not recorded speech.
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
OUT = ROOT / "dayeuhkolot_flood.json"


def _font(size: int):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
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
        dict(id="rpt-01", delay_s=0, channel="app", reporter_id="warga-01",
             lat=-6.9761, lng=107.6262, place_name="Dayeuhkolot RW 04",
             text="Banjir di Dayeuhkolot RW 04, air setinggi dada. Satu lansia terjebak di lantai dua dan tidak bisa turun.",
             translation_en="Flood in Dayeuhkolot RW 04, water at chest height. One elderly person is trapped on the second floor and cannot come down."),
        dict(id="rpt-02", delay_s=3.0, channel="app", reporter_id="warga-02",
             lat=-6.9754, lng=107.6270, place_name="Sukabirus, Dayeuhkolot",
             photo_file="flood_street.png",
             text="Foto dari Jalan Sukabirus, Dayeuhkolot. Air setinggi pinggang, warung sudah tutup, arus cukup kencang.",
             translation_en="Photo from Jalan Sukabirus, Dayeuhkolot. Water is at waist height, shops are closed, the current is fairly strong."),
        dict(id="rpt-03", delay_s=3.2, channel="voice", reporter_id="warga-03",
             lat=-6.9766, lng=107.6254, place_name="Dayeuhkolot",
             audio_file="voice_su_elderly.wav",
             transcript="Punten, cai di Dayeuhkolot RW 04 geus naek nepi ka dada. Aya kolot nu kejebak di lantai dua, teu tiasa turun. Butuh perahu.",
             text="Punten, cai di Dayeuhkolot RW 04 geus naek nepi ka dada. Aya kolot nu kejebak di lantai dua, teu tiasa turun. Butuh perahu.",
             translation_en="Excuse me, the water in Dayeuhkolot RW 04 has risen to chest height. An elderly person is trapped on the second floor and cannot come down. We need a boat."),
        dict(id="rpt-04", delay_s=1.2, channel="whatsapp_sim", reporter_id="warga-04",
             lat=-6.9764, lng=107.6258, place_name="Dayeuhkolot RW 04",
             text="WA: sama seperti voice note tadi, di Dayeuhkolot RW 04 ada kolot kejebak lantai 2. Butuh perahu sekarang.",
             translation_en="WhatsApp: same as the voice note, an elderly person is trapped on the second floor in Dayeuhkolot RW 04. Need a boat now."),
        dict(id="rpt-05", delay_s=3.4, channel="app", reporter_id="warga-05",
             lat=-6.9748, lng=107.6244, place_name="Jalan Dayeuhkolot",
             text="Banjir di Jalan Dayeuhkolot, sekitar 40 rumah tangga terendam, kira-kira 160 jiwa. Listrik padam.",
             translation_en="Flood on Jalan Dayeuhkolot, about 40 households under water, roughly 160 people. Power is out."),
        dict(id="rpt-06", delay_s=3.0, channel="voice", reporter_id="warga-06",
             lat=-6.9738, lng=107.6228, place_name="Sukabirus",
             audio_file="voice_su_infants.wav",
             transcript="Di Sukabirus cai caah. Budak orok jeung ema-ema nyarande di masjid. Listrik pareum. Mangga dibantosan.",
             text="Di Sukabirus cai caah. Budak orok jeung ema-ema nyarande di masjid. Listrik pareum. Mangga dibantosan.",
             translation_en="Floodwater in Sukabirus. Infants and mothers are sheltering at the mosque. The power is out. Please help."),
        dict(id="rpt-07", delay_s=3.1, channel="petabencana", reporter_id="pb-01",
             lat=-6.9758, lng=107.6260, place_name="Dayeuhkolot",
             text="PetaBencana report: flood depth about 120 cm in Dayeuhkolot. Road impassable for motorbikes.",
             translation_en="PetaBencana report: flood depth about 120 cm in Dayeuhkolot. Road impassable for motorbikes."),
        dict(id="rpt-08", delay_s=1.3, channel="whatsapp_sim", reporter_id="warga-08",
             lat=-6.9750, lng=107.6248, place_name="Jalan Dayeuhkolot",
             text="Grup RW: ulang ya, 40 rumah tangga di Jalan Dayeuhkolot terendam, sekitar 160 jiwa. Mohon logistik.",
             translation_en="Neighborhood group: repeating, 40 households on Jalan Dayeuhkolot are flooded, about 160 people. Please send supplies."),
        dict(id="rpt-09", delay_s=2.8, channel="app", reporter_id="warga-09",
             lat=-6.9772, lng=107.6236, place_name="Dayeuhkolot",
             text="Warga Dayeuhkolot butuh air minum. Dapur umum belum jalan, anak-anak sudah lapar dari siang.",
             translation_en="Dayeuhkolot residents need drinking water. The public kitchen is not running yet, and children have been hungry since noon."),
        dict(id="rpt-10", delay_s=2.6, channel="app", reporter_id="warga-10",
             lat=-6.9729, lng=107.6215, place_name="Dayeuhkolot",
             text="Jembatan kecil di Dayeuhkolot tidak bisa dilewati. Akses perahu dari jalan utama masih mungkin.",
             translation_en="The small bridge in Dayeuhkolot cannot be crossed. Boat access from the main road is still possible."),
        dict(id="rpt-11", delay_s=1.4, channel="app", reporter_id="warga-11",
             lat=-6.9768, lng=107.6266, place_name="Dayeuhkolot RW 04",
             text="Saya di titik yang sama dengan laporan pertama. Dayeuhkolot RW 04, air masih setinggi dada, lansia di lantai dua belum tertolong.",
             translation_en="I am at the same spot as the first report. Dayeuhkolot RW 04, water is still at chest height, the elderly person on the second floor has not been rescued."),
        dict(id="rpt-12", delay_s=3.3, channel="app", reporter_id="warga-12",
             lat=-6.9742, lng=107.6231, place_name="Masjid Al-Ikhlas, Dayeuhkolot",
             text="8 lansia terjebak di Masjid Al-Ikhlas Dayeuhkolot, air setinggi dada. Mereka tidak kuat berenang.",
             translation_en="8 elderly people are trapped at Masjid Al-Ikhlas in Dayeuhkolot, water at chest height. They cannot swim."),
        dict(id="rpt-13", delay_s=4.0, channel="app", reporter_id="warga-13",
             lat=-7.0042, lng=107.6304, place_name="Baleendah Andir",
             text="Banjir di Baleendah Andir, air setinggi lutut. Puluhan rumah sudah kemasukan air, jalan utama gelap.",
             translation_en="Flood in Baleendah Andir, water at knee height. Dozens of houses are inundated, the main road is dark."),
        dict(id="rpt-14", delay_s=2.7, channel="voice", reporter_id="warga-14",
             lat=-7.0048, lng=107.6296, place_name="Baleendah Andir",
             audio_file="voice_jv_medicine.wav",
             transcript="Ngapunten, banyu ing Baleendah Andir wis nganti dengkul. Dalan utama peteng. Ana wong tuwa sing lara, butuh obat.",
             text="Ngapunten, banyu ing Baleendah Andir wis nganti dengkul. Dalan utama peteng. Ana wong tuwa sing lara, butuh obat.",
             translation_en="Sorry, the water in Baleendah Andir is already at knee height. The main road is dark. A sick elderly person needs medicine."),
        dict(id="rpt-15", delay_s=2.4, channel="app", reporter_id="warga-15",
             lat=-7.0055, lng=107.6312, place_name="Baleendah",
             photo_file="flood_street.png",
             text="Foto halaman rumah di Baleendah, air kecokelatan setinggi lutut, sepeda motor tidak bisa keluar.",
             translation_en="Photo of a yard in Baleendah, brown water at knee height, motorbikes cannot get out."),
        dict(id="rpt-16", delay_s=1.2, channel="whatsapp_sim", reporter_id="warga-16",
             lat=-7.0044, lng=107.6308, place_name="Baleendah Andir",
             text="Duplikat dari grup: Baleendah Andir air setinggi lutut, mohon dicatat satu laporan saja.",
             translation_en="Duplicate from the group: Baleendah Andir, water at knee height, please log it as one report."),
        dict(id="rpt-17", delay_s=2.9, channel="app", reporter_id="warga-17",
             lat=-7.0061, lng=107.6284, place_name="Baleendah",
             text="Puskesmas pembantu Baleendah kehabisan obat untuk lansia. Akses mobil masih putus.",
             translation_en="The Baleendah sub-clinic is out of medicine for elderly patients. Car access is still cut."),
        dict(id="rpt-18", delay_s=2.5, channel="petabencana", reporter_id="pb-02",
             lat=-7.0036, lng=107.6318, place_name="Baleendah",
             text="PetaBencana: flood report Baleendah, depth about 50 cm, several alleys blocked.",
             translation_en="PetaBencana: flood report in Baleendah, depth about 50 cm, several alleys blocked."),
        dict(id="rpt-19", delay_s=3.2, channel="app", reporter_id="warga-19",
             lat=-7.0072, lng=107.6335, place_name="SD Negeri Baleendah",
             text="18 keluarga berteduh di SD Negeri Baleendah. Mereka butuh makanan dan obat, air masih setinggi lutut di sekitar sekolah.",
             translation_en="18 families are sheltering at SD Negeri Baleendah. They need food and medicine. Water around the school is still at knee height."),
        dict(id="rpt-20", delay_s=3.4, channel="app", reporter_id="warga-20",
             lat=-6.9984, lng=107.6506, place_name="Bojongsoang",
             text="Air mulai masuk ke rumah di Bojongsoang, sekitar 45 jiwa terdampak. Belum ada yang terjebak.",
             translation_en="Water is starting to enter houses in Bojongsoang, about 45 people affected. Nobody is trapped yet."),
        dict(id="rpt-21", delay_s=2.2, channel="petabencana", reporter_id="pb-03",
             lat=-6.9991, lng=107.6522, place_name="Bojongsoang",
             text="PetaBencana: rising water in Bojongsoang, road toward the toll is wet but still open to high vehicles. About 45 people affected.",
             translation_en="PetaBencana: rising water in Bojongsoang, the toll road is wet but still open to high vehicles. About 45 people affected."),
        dict(id="rpt-22", delay_s=4.4, channel="whatsapp_sim", reporter_id="warga-22",
             lat=-6.9752, lng=107.6255, place_name="Dayeuhkolot",
             photo_file="hoax_coast_2024.png",
             text="Banjir dahsyat Dayeuhkolot, air setinggi rumah! Sebarkan sekarang sebelum terlambat!",
             translation_en="Catastrophic flood in Dayeuhkolot, water as high as the houses! Forward this now before it is too late!",
             exif={"taken_at": "2024-02-11T08:14:00+07:00", "lat": -6.12, "lng": 107.91, "source": "simulated_exif"},
             image_cues=[
                 "Coastal wave and beach, not a river settlement",
                 "Television watermark: NUSANTARA TV 2024",
                 "Re-shared screenshot with heavy recompression",
             ]),
        dict(id="rpt-23", delay_s=2.4, channel="whatsapp_sim", reporter_id="warga-23",
             lat=-6.9744, lng=107.6274, place_name="Dayeuhkolot",
             photo_file="hoax_repost_2023.png",
             text="Foto banjir Dayeuhkolot tadi pagi, air masuk rumah semua. Share ke grup.",
             translation_en="Flood photo from Dayeuhkolot this morning, water entered every house. Share it to the group.",
             exif={"taken_at": "2023-12-02T16:40:00+07:00", "lat": -6.15, "lng": 106.85, "source": "simulated_exif"},
             image_cues=[
                 "Date stamp burned in: 2023-12-02",
                 "Street does not match Dayeuhkolot riverside housing",
                 "Old social repost, not a new camera frame",
             ]),
        dict(id="rpt-24", delay_s=3.2, channel="app", reporter_id="warga-24",
             lat=-6.9895, lng=107.6124, place_name="Cangkuang Wetan",
             text="Tanah bergerak di belakang rumah di Cangkuang Wetan. Longsor kecil, belum mengenai bangunan utama, tidak ada yang terluka.",
             translation_en="The ground is moving behind a house in Cangkuang Wetan. A small landslide has not reached the main building. Nobody is hurt."),
        dict(id="rpt-25", delay_s=1.5, channel="whatsapp_sim", reporter_id="warga-25",
             lat=-6.9902, lng=107.6116, place_name="Cangkuang Wetan",
             text="Duplikat: longsor kecil di Cangkuang Wetan, sama dengan laporan tetangga. Tidak ada korban.",
             translation_en="Duplicate: small landslide in Cangkuang Wetan, same as the neighbor's report. No casualties."),
    ]
    gaps = [float(r["delay_s"]) for r in reports]
    target = 78.0
    scale = target / max(sum(gaps[1:]), 1)
    for index, report in enumerate(reports):
        report["delay_s"] = 0 if index == 0 else round(report["delay_s"] * scale, 2)
        report["simulated"] = True
        report.setdefault("transcript", report["text"])
        report.setdefault("image_cues", [])
        report.setdefault("exif", None)

    return {
        "id": "dayeuhkolot-flood-2026",
        "title": "Flood drill — Dayeuhkolot, Kabupaten Bandung",
        "hazard": "flood",
        "tagline": "Read the signs. Act first.",
        "summary": (
            "Twenty-five simulated citizen reports of a Citarum flood at Dayeuhkolot, "
            "plus Baleendah, Bojongsoang, a small landslide at Cangkuang Wetan, "
            "and two old-photo claims that should stay out of the confirmed cluster."
        ),
        "ethics": "All photos are drawn placeholders. Voice files are tones plus transcripts, not field recordings.",
        "reports": reports,
        "samples": [
            {
                "id": "su-elderly",
                "label": "Sundanese voice note — elderly person trapped",
                "channel": "voice",
                "transcript": reports[2]["transcript"],
                "text": reports[2]["text"],
                "translation_en": reports[2]["translation_en"],
                "lat": reports[2]["lat"],
                "lng": reports[2]["lng"],
                "place_name": reports[2]["place_name"],
                "audio_file": "voice_su_elderly.wav",
            },
            {
                "id": "jv-medicine",
                "label": "Javanese voice note — knee-deep water, medicine",
                "channel": "voice",
                "transcript": reports[13]["transcript"],
                "text": reports[13]["text"],
                "translation_en": reports[13]["translation_en"],
                "lat": reports[13]["lat"],
                "lng": reports[13]["lng"],
                "place_name": reports[13]["place_name"],
                "audio_file": "voice_jv_medicine.wav",
            },
            {
                "id": "flood-photo",
                "label": "Simulated flood photo — Sukabirus",
                "channel": "app",
                "text": reports[1]["text"],
                "translation_en": reports[1]["translation_en"],
                "lat": reports[1]["lat"],
                "lng": reports[1]["lng"],
                "place_name": reports[1]["place_name"],
                "photo_file": "flood_street.png",
            },
            {
                "id": "hoax-old",
                "label": "Old-photo sample — should score low",
                "channel": "whatsapp_sim",
                "text": reports[21]["text"],
                "translation_en": reports[21]["translation_en"],
                "lat": reports[21]["lat"],
                "lng": reports[21]["lng"],
                "place_name": reports[21]["place_name"],
                "photo_file": "hoax_coast_2024.png",
                "exif": reports[21]["exif"],
                "image_cues": reports[21]["image_cues"],
            },
        ],
        "presence": [
            {"reporter_id": "listener-01", "lat": -6.9702, "lng": 107.6194, "label": "Standby citizen, north of the posko"},
            {"reporter_id": "listener-02", "lat": -6.9804, "lng": 107.6302, "label": "Standby citizen, Sukabirus edge"},
            {"reporter_id": "listener-03", "lat": -6.9688, "lng": 107.6315, "label": "Standby citizen, 1 km east"},
        ],
        "resources": {
            "teams": [
                {"id": "boat-dk-1", "name": "Rubber boat 1", "kind": "boat", "posko": "Posko Dayeuhkolot", "lat": -6.9712, "lng": 107.6180, "crew": 4},
                {"id": "boat-dk-2", "name": "Rubber boat 2", "kind": "boat", "posko": "Posko Dayeuhkolot", "lat": -6.9715, "lng": 107.6186, "crew": 4},
                {"id": "medic-bale", "name": "Medical squad", "kind": "medical", "posko": "Posko Baleendah", "lat": -7.0055, "lng": 107.6288, "crew": 3},
                {"id": "truck-soreang", "name": "Logistics truck", "kind": "logistics", "posko": "Posko BPBD Kabupaten Bandung (Soreang)", "lat": -7.0250, "lng": 107.5190, "crew": 2},
            ],
            "shelters": [
                {"id": "sdn-dk", "name": "SDN Dayeuhkolot 1", "lat": -6.9718, "lng": 107.6188, "capacity": 200, "occupied": 40},
                {"id": "gor-bale", "name": "GOR Baleendah", "lat": -7.0088, "lng": 107.6365, "capacity": 500, "occupied": 120},
                {"id": "masjid-bojong", "name": "Masjid Al-Furqon Bojongsoang", "lat": -6.9962, "lng": 107.6480, "capacity": 150, "occupied": 20},
            ],
        },
        "bmkg": {
            "label": "Recorded scenario snapshot for the Dayeuhkolot replay. Not a live forecast.",
            "live_note": (
                "On 10 Oct 2026 a live call to api.bmkg.go.id for Kelurahan Sukarasa, Kota Bandung "
                "(adm4 32.73.01.1001) returned Mostly Cloudy and 0 mm precipitation. "
                "The replay cites this heavy-rain snapshot so the drill stays repeatable. "
                "The same tools call the live API when TIPO_MODE=live."
            ),
            "areas": {
                "dayeuhkolot": {
                    "adm4": "32.04.12.2002",
                    "name": "Desa Dayeuhkolot, Kec. Dayeuhkolot, Kab. Bandung",
                    "weather_desc_en": "Heavy rain",
                    "tp_mm": 45,
                    "period": "3h",
                    "source": "scenario_snapshot",
                    "verified_code": "adm4 32.04.12.2002 returned Desa Dayeuhkolot from api.bmkg.go.id during the build.",
                },
                "baleendah": {
                    "adm4": None,
                    "name": "Kec. Baleendah, Kab. Bandung",
                    "weather_desc_en": "Heavy rain",
                    "tp_mm": 38,
                    "period": "3h",
                    "source": "scenario_snapshot",
                    "note": "Kelurahan-level adm4 for Baleendah was not confirmed before BMKG rate-limited the build. Figures are recorded for the drill.",
                },
                "bojongsoang": {
                    "adm4": "32.04.08.2002",
                    "name": "Desa Bojongsoang, Kec. Bojongsoang, Kab. Bandung",
                    "weather_desc_en": "Rain",
                    "tp_mm": 22,
                    "period": "3h",
                    "source": "scenario_snapshot",
                    "verified_code": "adm4 32.04.08.2002 returned Desa Bojongsoang from api.bmkg.go.id during the build.",
                },
                "cangkuang": {
                    "adm4": "32.04.12.2003",
                    "name": "Desa Cangkuang Wetan, Kec. Dayeuhkolot, Kab. Bandung",
                    "weather_desc_en": "Heavy rain",
                    "tp_mm": 40,
                    "period": "3h",
                    "source": "scenario_snapshot",
                    "verified_code": "adm4 32.04.12.2003 returned Desa Cangkuang Wetan from api.bmkg.go.id during the build.",
                },
            },
            "earthquake": {
                "source": "https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json",
                "fetched_at": "2026-10-10T11:00:00+07:00",
                "magnitude": 2.4,
                "place": "Pusat gempa berada di darat 12 km barat Kendari",
                "coordinates": [-3.96, 122.40],
                "time_wib": "09 Okt 2026 17:34:55 WIB",
                "note": "Copied from the live autogempa feed during the build. Far from Bandung, so it does not support a local quake claim.",
            },
            "nowcast": [
                {
                    "title": "Recorded drill item, not a live warning: heavy rain signal for southern Kabupaten Bandung",
                    "link": "https://www.bmkg.go.id/alerts/nowcast/id/rss.xml",
                }
            ],
        },
    }


def main() -> None:
    MEDIA.mkdir(parents=True, exist_ok=True)
    _card(
        "flood_street.png",
        (42, 74, 78),
        "Dayeuhkolot street",
        ["Brown water across the lane.", "Shops closed. No people shown.", "Placeholder for a citizen photo."],
        "SIMULATED  ·  not a photograph of a real event",
    )
    _card(
        "hoax_coast_2024.png",
        (28, 74, 112),
        "Coastal frame",
        ["Wave and beach, not a riverside village.", "Watermark: NUSANTARA TV  2024", "Used to demo an old-photo cue."],
        "SIMULATED EXIF  2024-02-11  ·  GPS far from Bandung",
    )
    _card(
        "hoax_repost_2023.png",
        (72, 64, 58),
        "Old repost",
        ["Burned-in date 2023-12-02.", "Street does not match Dayeuhkolot.", "Second low-credibility claim."],
        "SIMULATED EXIF  2023-12-02  ·  GPS near Jakarta",
    )
    _tone("voice_su_elderly.wav", 220)
    _tone("voice_su_infants.wav", 262)
    _tone("voice_jv_medicine.wav", 196)
    (MEDIA / "voice_su_elderly.txt").write_text(
        "Punten, cai di Dayeuhkolot RW 04 geus naek nepi ka dada. "
        "Aya kolot nu kejebak di lantai dua, teu tiasa turun. Butuh perahu.\n",
        encoding="utf-8",
    )
    (MEDIA / "voice_su_infants.txt").write_text(
        "Di Sukabirus cai caah. Budak orok jeung ema-ema nyarande di masjid. "
        "Listrik pareum. Mangga dibantosan.\n",
        encoding="utf-8",
    )
    (MEDIA / "voice_jv_medicine.txt").write_text(
        "Ngapunten, banyu ing Baleendah Andir wis nganti dengkul. "
        "Dalan utama peteng. Ana wong tuwa sing lara, butuh obat.\n",
        encoding="utf-8",
    )
    payload = build()
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total = sum(r["delay_s"] for r in payload["reports"])
    print(f"wrote {OUT} reports={len(payload['reports'])} replay_span_s={total:.1f}")


if __name__ == "__main__":
    main()
