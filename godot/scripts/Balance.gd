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

# ---------- Versprechen ----------
const PROMISE_KEPT_LOYALTY := 18.0
const PROMISE_KEPT_TRUST := 14.0
const PROMISE_KEPT_MOOD := 10.0
const PROMISE_KEPT_REP := 3
const PROMISE_BROKEN_LOYALTY := 35.0
const PROMISE_BROKEN_TRUST := 24.0
const PROMISE_BROKEN_MOOD := 20.0
const PROMISE_BROKEN_REP := 5

# ---------- Karriere-DNA (Prägung bei Release) ----------
const DNA_PRESTIGE_UNIKAT := 3.0
const DNA_PRESTIGE_POPULAR := -2.0
# Blockbuster (Einspielfaktor ≥ RATIO) macht populär, Flops kosten Verlass.
const DNA_BLOCKBUSTER_RATIO := 3.0
const DNA_BLOCKBUSTER_POPULAR := 4.0
const DNA_FLOP_VERLASS := -2.0
