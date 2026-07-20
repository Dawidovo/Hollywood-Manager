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

Dauer: einige Minuten (Download + Verarbeitung).
"""
import argparse
import gzip
import json
import math
import os
import random
import sys
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


def download(cache_dir: str) -> None:
    os.makedirs(cache_dir, exist_ok=True)
    for f in FILES:
        dest = os.path.join(cache_dir, f)
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            print(f"  {f}: bereits vorhanden, überspringe Download")
            continue
        print(f"  Lade {BASE_URL}{f} …")
        urllib.request.urlretrieve(BASE_URL + f, dest)
        print(f"  {f}: {os.path.getsize(dest) / 1e6:.0f} MB")


def tsv_rows(path: str):
    with gzip.open(path, "rt", encoding="utf-8") as fh:
        header = fh.readline().rstrip("\n").split("\t")
        for line in fh:
            yield dict(zip(header, line.rstrip("\n").split("\t")))


def main() -> int:
    ap = argparse.ArgumentParser(description="IMDb-Datasets → js/actors_full.js")
    ap.add_argument("--top", type=int, default=2000, help="Anzahl Schauspieler (nach Bekanntheit)")
    ap.add_argument("--cache", default="tools/imdb_cache", help="Download-Verzeichnis")
    ap.add_argument("--out", default="js/actors_full.js", help="Ausgabedatei")
    ap.add_argument("--keep-downloads", action="store_true", help="TSV-Dateien nach dem Import behalten")
    args = ap.parse_args()

    print("1/4 Downloads prüfen …")
    download(args.cache)

    # Filme: Jahr, Genres, Bewertungszahl (Bekanntheits-Proxy)
    print("2/4 Filme einlesen (title.basics + title.ratings) …")
    ratings = {}
    for r in tsv_rows(os.path.join(args.cache, "title.ratings.tsv.gz")):
        try:
            ratings[r["tconst"]] = (float(r["averageRating"]), int(r["numVotes"]))
        except ValueError:
            pass

    titles = {}
    for r in tsv_rows(os.path.join(args.cache, "title.basics.tsv.gz")):
        if r["titleType"] not in ("movie", "tvMovie"):
            continue
        t = r["tconst"]
        if t not in ratings:
            continue
        year = r["startYear"]
        if year == "\\N":
            continue
        titles[t] = (int(year), r["genres"], ratings[t][0], ratings[t][1])

    print(f"   {len(titles):,} bewertete Filme")

    # Schauspieler mit Geburtsjahr; Bekanntheit = Stimmen ihrer bekanntesten Filme
    print("3/4 Schauspieler einlesen (name.basics) …")
    people = []
    for r in tsv_rows(os.path.join(args.cache, "name.basics.tsv.gz")):
        prof = r["primaryProfession"]
        if "actor" not in prof and "actress" not in prof:
            continue
        if r["birthYear"] == "\\N":
            continue
        known = [t for t in r["knownForTitles"].split(",") if t in titles]
        if not known:
            continue
        votes = sum(titles[t][3] for t in known)
        people.append((votes, r, known))

    people.sort(key=lambda x: -x[0])
    top = people[: args.top]
    print(f"   {len(people):,} Kandidaten, Top {len(top)} werden exportiert")

    print("4/4 Spielwerte ableiten & schreiben …")
    max_votes = math.log10(top[0][0]) if top else 1
    rng = random.Random(42)
    actors = []
    seen_ids = set()
    for votes, r, known in top:
        birth = int(r["birthYear"])
        death = None if r["deathYear"] == "\\N" else int(r["deathYear"])
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
        ego = rng.randint(25, 90)
        genres = []
        for f in films:
            for g in f[1].split(","):
                mapped = GENRE_MAP.get(g)
                if mapped and mapped not in genres:
                    genres.append(mapped)
        genres = genres[:3] or ["drama"]
        # Geschlecht aus der Berufsbezeichnung (IMDb unterscheidet actor/actress)
        gender = "f" if "actress" in r["primaryProfession"] else "m"
        aid = r["nconst"]
        if aid in seen_ids:
            continue
        seen_ids.add(aid)
        actors.append({
            "id": aid, "name": r["primaryName"], "birth": birth, "death": death,
            "g": gender, "debut": debut, "talent": talent, "ego": ego,
            "genres": genres, "peak": peak, "peakFame": max(35, min(100, peak_fame)),
        })

    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write("// Automatisch erzeugt von tools/import_imdb.py — IMDb Non-Commercial Datasets\n")
        fh.write("// Nutzung nur für persönliche, nicht-kommerzielle Zwecke (imdb.com/interfaces).\n")
        fh.write("window.ACTORS_FULL = ")
        json.dump(actors, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write(";\n")
    print(f"   {len(actors)} Schauspieler → {args.out}")

    if not args.keep_downloads:
        print("   (Downloads bleiben im Cache; --keep-downloads ist implizit. Zum Löschen: tools/imdb_cache entfernen.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
