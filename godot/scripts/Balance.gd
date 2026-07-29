extends Node
# =====================================================================
# Zentrale Spielbalance-Konstanten (Chunk 01) — Autoload "Balance".
# Reine Zahlensammlung, gruppiert nach System — das Verhalten wohnt
# weiterhin in Game.gd/Persona.gd. Balancing-Werkzeug: tools/BalanceSim.
# Nur Werte aufnehmen, deren Bedeutung klar ist; Unklares bleibt im Code.
# =====================================================================

# ---------- Wirtschaft ----------
# Startkapital der Agentur (× Inflation × Era-Faktor "startCapitalMult"
# aus data/eras/core.json).
const START_CAPITAL := 120000.0
# Büro-Fixkosten pro Monat: Basis + Betrag je Klient (× Inflation).
const OFFICE_BASE := 2200.0
const OFFICE_PER_CLIENT := 600.0
# Studiosystem-Ära: kleine Büros, kleine Gagen (Balance-Chunk 19).
const OFFICE_EARLY_ERA_MULT := 0.6
const OFFICE_EARLY_ERA_UNTIL := 1948
# Wochenplaner „Bücher prüfen“ (ab 3 Slots/Monat) senkt die Bürokosten.
const OFFICE_BOOKS_MULT := 0.9
# Monate in Folge zahlungsunfähig, bis die Banken übernehmen.
const INSOLVENCY_MONTHS := 3
# Kreditrahmen: wie tief die Agentur ins Minus darf (× Inflation).
# Basis + Ruf-Anteil — ein respektiertes Haus bekommt mehr Leine.
const CREDIT_LIMIT_BASE := 25000.0
const CREDIT_LIMIT_PER_REP := 500.0

# ---------- Gagen & Deals ----------
# Gagenkurve: BASE × (Ruhm/100)^EXPONENT, nie unter MIN (alles × Inflation).
# Exponent 2,35 hebt den unteren Ruhm-Bereich (Balance-Chunk 19).
const FEE_BASE := 900000.0
const FEE_EXPONENT := 2.35
const FEE_MIN := 5000.0
# Nachverhandeln: +25 % Gage fordern (Meister-Verhandler: +32 %).
const HAGGLE_MULT := 1.25
const HAGGLE_MASTER_MULT := 1.32
# Package-Deal: beide Gagen +12 %.
const PACKAGE_FEE_MULT := 1.12

# ---------- Produktion ----------
# Produktionsdauer in Monaten; ab MODERN_YEAR (Streaming) kürzer.
const PROD_MONTHS_MIN := 4
const PROD_MONTHS_MAX := 7
const PROD_MODERN_YEAR := 2015
const PROD_MONTHS_MIN_MODERN := 3
const PROD_MONTHS_MAX_MODERN := 5

# ---------- Roster-Beziehungen: Power-Couples & Feuds ----------
# Persönliche Chemie (−10…+10) plus gemeinsame Filme entscheiden, ob zwei
# eigene Klienten zum Traumpaar werden oder sich verkrachen.
const PAIR_COUPLE_CHEM := 7
const PAIR_COUPLE_FILMS := 2
const PAIR_FEUD_CHEM := -7
const PAIR_COUPLE_FIT := 6.0

# ---------- Award-Saison: „For Your Consideration“-Kampagnen ----------
# Kampagnen-Fenster: November–Januar (Zeremonie im Februar). Der Boost
# fließt in die Performance-Wertung (Zufallsanteil dort: 0–15).
const FYC_SMALL_COST := 4000.0
const FYC_SMALL_BOOST := 8.0
const FYC_BIG_COST := 12000.0
const FYC_BIG_BOOST := 18.0
const FYC_CAP := 30.0

# ---------- Comeback (spätes Karriere-Kunststück) ----------
# Ein Star nach dem Zenit, ein Prestige-Projekt, eine Kampagne: zündet es
# (Einspielfaktor oder Qualität über den Schwellen), ist er zurück.
const COMEBACK_CAMPAIGN_COST := 8000.0
const COMEBACK_SUCCESS_RATIO := 1.6
const COMEBACK_SUCCESS_QUALITY := 70
const COMEBACK_SUCCESS_FAME := 14.0

# ---------- Versprechen ----------
const PROMISE_KEPT_LOYALTY := 18.0
const PROMISE_KEPT_TRUST := 14.0
const PROMISE_KEPT_MOOD := 10.0
const PROMISE_KEPT_REP := 3
const PROMISE_BROKEN_LOYALTY := 35.0
const PROMISE_BROKEN_TRUST := 24.0
const PROMISE_BROKEN_MOOD := 20.0
const PROMISE_BROKEN_REP := 5

# ---------- Tonfilm-Umbruch (1927+) ----------
# Schwache Sprechstimmen (Util.voice_of < THRESHOLD) geraten in der
# Übergangszeit unter Druck: Casting-Malus und Ruhm-Drift, bis der Klient
# per Sprechtraining (Flag voiceTrained) gerettet ist.
const VOICE_WEAK_THRESHOLD := 38
const TALKIE_YEAR := 1928
const TALKIE_TRANSITION_END := 1934
const VOICE_FIT_MALUS := 12.0
const VOICE_FAME_DRIFT := 1.2

# ---------- Emotionsmodell (Gesamtpaket Teil A) ----------
# Wahrnehmungsstufen: Lese-Score = Menschenkenntnis + Instinkt/EMO_INSTINCT_DIV.
# Unter TIER_LIKELY nur Valenz/unlesbar (EMO_ERR_LOW % falsche Nachbaremotion),
# bis TIER_CLEAR korrekt-aber-vage (EMO_ERR_MID % Fehler), bis TIER_CAUSE klar,
# darüber zusätzlich die konkrete Ursache.
const EMO_TIER_LIKELY := 30.0
const EMO_TIER_CLEAR := 55.0
const EMO_TIER_CAUSE := 75.0
const EMO_ERR_LOW := 25
const EMO_ERR_MID := 10
const EMO_INSTINCT_DIV := 10.0

# ---------- Gefallen-Ökonomie ----------
# Gefallen verjähren schneller (vorher 24–36 Monate: das Register lief
# voll und nichts drängte). Kurze Fristen + aktive Verwendungen halten
# den Kreislauf in Bewegung. VERFALL_CHANCE: Anteil mit Ablaufdatum.
const FAVOR_EXPIRY_MIN_MONTHS := 12
const FAVOR_EXPIRY_MAX_MONTHS := 18
const FAVOR_EXPIRY_CHANCE := 0.9
# Aktiver Einsatz „Tür öffnen“: Beziehungsgewinn beim Studio.
const FAVOR_DOOR_REL := 7

# ---------- Signing-Verhandlung ----------
# Nach einer endgültigen Absage („declines for good“) ist die Tür so
# lange zu — Verhandlungen haben damit einen echten Einsatz.
const SIGNING_COOLDOWN_MONTHS := 9

# ---------- Mehrparteien-Verhandlungstisch ----------
# Der Tisch ist ein Ereignis, keine Routine: nur Prestige-Spitzenprojekte
# (SOLO), Traumpaar-Castings oder Star-Hauptrollen (minFame ≥ STAR) in
# Prestige-Stoffen versammeln alle Parteien.
const TABLE_PRESTIGE_SOLO := 3
const TABLE_STAR_MINFAME := 45

# ---------- Schlüsselbegegnungen (Gesamtpaket Teil A3) ----------
# Vertragsende: unter dieser Loyalität (oder nach Wortbruch) wird die
# Verlängerung zur vollen Szene statt zum stillen Automatismus.
const SHOWDOWN_LOYALTY := 50.0
# Abwerbe-Duell: ab diesem Klienten-Ruhm wird das Duell zur vollen Szene.
const POACH_SCENE_FAME := 50.0
# Geständnis-Szene: ab diesem Glauben an ein wahres Gerücht gesteht der Klient.
const CONFESSION_BELIEF := 40.0
# Studio-Gipfel: so viele geplatzte Deals im Fenster rufen den Boss auf den Plan.
const SUMMIT_BURSTS := 2
const SUMMIT_WINDOW_MONTHS := 24
const SUMMIT_COOLDOWN_MONTHS := 12

# ---------- Pressekonferenz (Gesamtpaket Teil B2) ----------
# Ab diesem Glauben an ein Gerücht über einen eigenen Klienten liegt das
# Podium-Angebot in der Post (1× pro Gerücht, plus globaler Cooldown).
const PRESSCONF_BELIEF := 55.0
const PRESSCONF_COOLDOWN_MONTHS := 6

# ---------- Klienten-Bedürfnisse (Gesamtpaket Teil C1) ----------
# Sättigung startet bei NEEDS_START; fällt das schlechteste Bedürfnis
# unter NEEDS_LOW, kostet das monatlich Laune, unter NEEDS_CRITICAL
# zusätzlich Loyalität. Driftraten: Needs.gd.
const NEEDS_START := 55.0
const NEEDS_LOW := 35.0
const NEEDS_CRITICAL := 20.0
const NEEDS_MOOD_MALUS := 2.0
const NEEDS_LOYALTY_MALUS := 1.0
# Erwartungsgespräch: Rhythmus, Dringlichkeits-Schwelle und wie stark
# gehaltene/gebrochene Zusagen das Bedürfnis bewegen (Teil C2).
const NEEDS_TALK_COOLDOWN_MONTHS := 6
const NEEDS_TALK_RITUAL_MONTHS := 12
const NEEDS_URGENT := 25.0
const NEEDS_PROMISE_KEPT := 30.0
const NEEDS_PROMISE_BROKEN := 20.0

# ---------- TV-Umbruch 1948–62 & Streaming 2015+ (Teil C3) ----------
# Serien-Angebote locken nur fernsehtaugliche Gesichter (Util.tv_appeal);
# laufende Serien kosten im Prestige-Kino Standing (bis 1965). Ab
# STREAMING_YEAR baut sich Heat schneller AUF und AB (Binge-Ruhm).
const TV_ERA_START := 1948
const TV_ERA_END := 1962
const TV_PRESTIGE_MALUS := 5.0
const TV_PRESTIGE_MALUS_UNTIL := 1965
const STREAMING_YEAR := 2015
const BINGE_HEAT_EXTRA := 0.5

# ---------- Spieler-Attribute (RPG-Chunk 15) ----------
# Basiswert neuer Spielfiguren; Wachstum nur durch Benutzung mit
# abnehmendem Ertrag: voll bis SOFTCAP_1, ×0,5 bis SOFTCAP_2, ×0,25 darüber.
const ATTR_BASE := 22.0
const ATTR_SOFTCAP_1 := 40.0
const ATTR_SOFTCAP_2 := 70.0

# ---------- Karriere-DNA (Prägung bei Release) ----------
const DNA_PRESTIGE_UNIKAT := 3.0
const DNA_PRESTIGE_POPULAR := -2.0
# Blockbuster (Einspielfaktor ≥ RATIO) macht populär, Flops kosten Verlass.
const DNA_BLOCKBUSTER_RATIO := 3.0
const DNA_BLOCKBUSTER_POPULAR := 4.0
const DNA_FLOP_VERLASS := -2.0
