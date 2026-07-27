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
