#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hollywood Manager — IMDb-Dataset-Importer

Lädt die offiziellen IMDb Non-Commercial Datasets (https://datasets.imdbws.com/)
und erzeugt daraus js/actors_full.js mit den Top-N Schauspielern aller Epochen
im Spielformat. Das Spiel benutzt actors_full.js automatisch, falls vorhanden.

WICHTIG: Die IMDb-Datasets dürfen nur für persönliche, nicht-kommerzielle
Zwecke genutzt werden (https://www.imdb.com/interfaces/). Download insgesamt
ca. 300 MB (gz), bei der Verarbeitung werden einige GB RAM-schonend gestreamt.

Aufruf (aus dem Projektordner):
    python tools/import_imdb.py --top 2000
    python tools/import_imdb.py --top 5000 --keep-downloads

Für die Godot-Version: endet --out auf .json, wird eine reine JSON-Liste im
Schema von godot/data/actors/ geschrieben (DataLoader lädt sie automatisch):
    python tools/import_imdb.py --top 2000 --out "godot/data/actors/zz_imdb.json"

Dauer: einige Minuten (Download + Verarbeitung).
Exit-Codes: 0 ok · 2 Download-/Lesefehler · 3 keine verwertbaren Daten.
"""
import argparse
import gzip
import json
import math
import os
import random
import sys
import urllib.error
import urllib.request

BASE_URL = "https://datasets.imdbws.com/"
FILES = ["name.basics.tsv.gz", "title.basics.tsv.gz", "title.ratings.tsv.gz"]

# IMDb-Genres → Spiel-Genres
GENRE_MAP = {
    "Drama": "drama", "Comedy": "comedy", "Action": "action", "Romance": "romance",
    "Thriller": "thriller", "Western": "western", "Musical": "musical", "Music": "musical",
    "Sci-Fi": "scifi", "Horror": "horror", "Crime": "crime", "Adventure": "adventure",
    "Mystery": "thriller", "War": "action", "Film-Noir": "crime", "Fantasy": "adventure",
}


# Zähler für den Abschlussbericht: übersprungene kaputte Zeilen je Datei.
SKIPPED: dict = {}


def download(cache_dir: str) -> None:
    """Fehlende Dateien laden; Abbruch mit Exit 2, wenn eine Quelle scheitert."""
    os.makedirs(cache_dir, exist_ok=True)
    for f in FILES:
        dest = os.path.join(cache_dir, f)
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            print(f"  {f}: bereits vorhanden, überspringe Download")
            continue
        print(f"  Lade {BASE_URL}{f} …")
        try:
            urllib.request.urlretrieve(BASE_URL + f, dest)
        except (urllib.error.URLError, OSError) as exc:
            # Teil-Download entfernen, sonst gilt er beim nächsten Lauf als "vorhanden"
            if os.path.exists(dest):
                os.remove(dest)
            print(f"FEHLER: Download von {f} fehlgeschlagen: {exc}", file=sys.stderr)
            sys.exit(2)
        print(f"  {f}: {os.path.getsize(dest) / 1e6:.0f} MB")


def tsv_rows(path: str):
    """TSV-Zeilen als Dicts; kaputte Zeilen (falsche Spaltenzahl, kaputtes
    UTF-8/gzip-Ende) werden gezählt und übersprungen statt zu crashen."""
    name = os.path.basename(path)
    try:
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as fh:
            header = fh.readline().rstrip("\n").split("\t")
            try:
                for line in fh:
                    cells = line.rstrip("\n").split("\t")
                    if len(cells) != len(header):
                        SKIPPED[name] = SKIPPED.get(name, 0) + 1
                        continue
                    yield dict(zip(header, cells))
            except (EOFError, gzip.BadGzipFile) as exc:
                # Abgeschnittener Download: mit dem bisher Gelesenen weiterarbeiten
                print(f"WARNUNG: {name} endet vorzeitig ({exc}) — verarbeite Teilbestand.", file=sys.stderr)
    except OSError as exc:
        print(f"FEHLER: {name} ist nicht lesbar: {exc}", file=sys.stderr)
        sys.exit(2)


def load_titles(cache_dir: str) -> dict:
    """Filme: tconst -> (Jahr, Genres, Bewertung, Stimmenzahl als Bekanntheits-Proxy)."""
    ratings = {}
    for r in tsv_rows(os.path.join(cache_dir, "title.ratings.tsv.gz")):
        try:
            ratings[r["tconst"]] = (float(r["averageRating"]), int(r["numVotes"]))
        except ValueError:
            pass

    titles = {}
    for r in tsv_rows(os.path.join(cache_dir, "title.basics.tsv.gz")):
        if r.get("titleType") not in ("movie", "tvMovie"):
            continue
        t = r.get("tconst", "")
        if t not in ratings or r.get("startYear", "\\N") == "\\N":
            continue
        try:
            titles[t] = (int(r["startYear"]), r.get("genres", ""), ratings[t][0], ratings[t][1])
        except ValueError:
            SKIPPED["title.basics"] = SKIPPED.get("title.basics", 0) + 1
    return titles


def load_people(cache_dir: str, titles: dict) -> list:
    """Schauspieler mit Geburtsjahr; Bekanntheit = Stimmen ihrer bekanntesten Filme."""
    people = []
    for r in tsv_rows(os.path.join(cache_dir, "name.basics.tsv.gz")):
        prof = r.get("primaryProfession", "")
        if "actor" not in prof and "actress" not in prof:
            continue
        try:
            if r.get("birthYear", "\\N") == "\\N":
                continue
            int(r["birthYear"])
            known = [t for t in r.get("knownForTitles", "").split(",") if t in titles]
            if not known:
                continue
            votes = sum(titles[t][3] for t in known)
            people.append((votes, r, known))
        except ValueError:
            SKIPPED["name.basics"] = SKIPPED.get("name.basics", 0) + 1
    people.sort(key=lambda x: -x[0])
    return people


def film_genres(films: list) -> list:
    genres = []
    for f in films:
        for g in f[1].split(","):
            mapped = GENRE_MAP.get(g)
            if mapped and mapped not in genres:
                genres.append(mapped)
    return genres[:3] or ["drama"]


def build_actor(votes: int, r: dict, known: list, titles: dict, max_votes: float, rng) -> dict:
    birth = int(r["birthYear"])
    death_raw = r.get("deathYear", "\\N")
    death = None if death_raw == "\\N" else int(death_raw)
    films = sorted((titles[t] for t in known), key=lambda f: f[0])
    # Debüt: ~2 Jahre vor dem ersten bekannten Film, frühestens mit 15
    debut = max(birth + 15, films[0][0] - 2)
    # Peak: Jahr des meistbewerteten Films
    peak_film = max(films, key=lambda f: f[3])
    peak = max(debut + 2, peak_film[0])
    # Ruhm/Talent aus Stimmen & Bewertungen (log-skaliert)
    peak_fame = int(round(45 + 55 * math.log10(max(votes, 10)) / max_votes))
    avg_rating = sum(f[2] for f in films) / len(films)
    talent = int(max(30, min(100, round(avg_rating * 11 + rng.uniform(-6, 6)))))
    # Geschlecht aus der Berufsbezeichnung (IMDb unterscheidet actor/actress)
    gender = "f" if "actress" in r["primaryProfession"] else "m"
    return {
        "id": r["nconst"], "name": r["primaryName"], "birth": birth, "death": death,
        "g": gender, "debut": debut, "talent": talent, "ego": rng.randint(25, 90),
        "genres": film_genres(films), "peak": peak, "peakFame": max(35, min(100, peak_fame)),
    }


def main() -> int:
    # Windows-Konsole (cp1252) verkraftet die Pfeil-/Ellipsen-Zeichen der
    # Statusausgaben nicht — UTF-8 mit Ersatzzeichen statt UnicodeEncodeError.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="IMDb-Datasets → js/actors_full.js")
    ap.add_argument("--top", type=int, default=2000, help="Anzahl Schauspieler (nach Bekanntheit)")
    ap.add_argument("--cache", default="tools/imdb_cache", help="Download-Verzeichnis")
    ap.add_argument("--out", default="js/actors_full.js", help="Ausgabedatei")
    ap.add_argument("--keep-downloads", action="store_true", help="TSV-Dateien nach dem Import behalten")
    args = ap.parse_args()

    print("1/4 Downloads prüfen …")
    download(args.cache)

    print("2/4 Filme einlesen (title.basics + title.ratings) …")
    titles = load_titles(args.cache)
    print(f"   {len(titles):,} bewertete Filme")
    if not titles:
        print("FEHLER: keine verwertbaren Filme — Datasets kaputt oder leer.", file=sys.stderr)
        return 3

    print("3/4 Schauspieler einlesen (name.basics) …")
    people = load_people(args.cache, titles)
    top = people[: args.top]
    print(f"   {len(people):,} Kandidaten, Top {len(top)} werden exportiert")
    if not top:
        print("FEHLER: keine verwertbaren Schauspieler — Datasets kaputt oder leer.", file=sys.stderr)
        return 3

    print("4/4 Spielwerte ableiten & schreiben …")
    max_votes = math.log10(top[0][0]) if top else 1
    rng = random.Random(42)
    actors = []
    seen_ids = set()
    broken = 0
    for votes, r, known in top:
        if r["nconst"] in seen_ids:
            continue
        seen_ids.add(r["nconst"])
        try:
            actors.append(build_actor(votes, r, known, titles, max_votes, rng))
        except (ValueError, KeyError, ZeroDivisionError):
            broken += 1
    if not actors:
        print("FEHLER: kein einziger Datensatz ableitbar.", file=sys.stderr)
        return 3

    with open(args.out, "w", encoding="utf-8") as fh:
        if args.out.endswith(".json"):
            # Godot-Datenformat: reine JSON-Liste für godot/data/actors/
            # (DataLoader merged sie automatisch; Lizenzhinweis siehe Docstring).
            json.dump(actors, fh, ensure_ascii=False, indent="\t")
            fh.write("\n")
        else:
            fh.write("// Automatisch erzeugt von tools/import_imdb.py — IMDb Non-Commercial Datasets\n")
            fh.write("// Nutzung nur für persönliche, nicht-kommerzielle Zwecke (imdb.com/interfaces).\n")
            fh.write("window.ACTORS_FULL = ")
            json.dump(actors, fh, ensure_ascii=False, separators=(",", ":"))
            fh.write(";\n")
    print(f"   {len(actors)} Schauspieler → {args.out}")

    # Abschlussbericht: was wurde wegen kaputter Daten übersprungen?
    for src, n in sorted(SKIPPED.items()):
        print(f"   übersprungen ({src}): {n} kaputte Zeile(n)")
    if broken:
        print(f"   übersprungen (Ableitung): {broken} Datensatz/Datensätze")

    if not args.keep_downloads:
        print("   (Downloads bleiben im Cache; --keep-downloads ist implizit. Zum Löschen: tools/imdb_cache entfernen.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
