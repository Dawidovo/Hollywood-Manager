// =====================================================================
// Hollywood Manager — Spiellogik
// =====================================================================

const D = window.HM_DATA;
// IMDb-Vollimport (tools/import_imdb.py) ersetzt die Seed-Stars, falls vorhanden
const ACTORS = (window.ACTORS_FULL && window.ACTORS_FULL.length) ? window.ACTORS_FULL : D.ACTORS;
const ACTOR_BY_ID = Object.fromEntries(ACTORS.map(a => [a.id, a]));

const MONTHS_DE = ["Januar","Februar","März","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"];

// ---------- Zufall & Helfer ----------
const rnd = (a, b) => a + Math.random() * (b - a);
const rndInt = (a, b) => Math.floor(rnd(a, b + 1));
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const chance = p => Math.random() < p;
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

// ---------- Vertrags-Bausteine ----------
// Perks: Zusatzleistungen im Klientenvertrag. cost = monatlich, ×Inflation.
const PERKS = {
  pr:        { de: "PR-Betreuung",          cost: 1500, desc: "Mildert Skandale und Leaks, Laune +1/Monat" },
  travel:    { de: "Erste-Klasse-Komfort",  cost: 1200, desc: "Laune +2/Monat, Erholung geht schneller" },
  script:    { de: "Drehbuch-Mitsprache",   cost: 0,    desc: "Klient lehnt Rollen mit Passung < 35 ab, +5 Passung bei Genre-Treffern" },
  coach:     { de: "Privat-Coach",          cost: 1800, desc: "Talent wächst langsam (bis +10)" },
  assistant: { de: "Persönliche Assistenz", cost: 800,  desc: "Halbiert Erschöpfung am Set, Loyalität +1/Monat" },
};

const PROMISES = {
  lead12:   { label: "Hauptrolle innerhalb von 12 Monaten",      months: 12 },
  prestige: { label: "ein Prestige-Projekt innerhalb von 18 Monaten", months: 18 },
  oscar:    { label: "eine Oscar-Nominierung innerhalb von 24 Monaten", months: 24 },
};

const CONTRACT_YEARS = [2, 3, 5, 7];

// ---------- Ökonomie & Karriere-Mathematik ----------
const Calc = {
  // Inflation: ~×19 von 1925 bis 2025
  infl(year) { return Math.pow(1.03, year - 1925); },

  // Asymmetrische Karrierekurve: steiler Aufstieg, langsamer Abstieg
  fameAt(actor, year) {
    if (year < actor.debut) return 0;
    const rise = Math.max(3, (actor.peak - actor.debut) / 2.2);
    const fall = 14;
    const d = year - actor.peak;
    const s = d < 0 ? rise : fall;
    const f = actor.peakFame * Math.exp(-0.5 * (d / s) * (d / s));
    return clamp(Math.round(f), 5, 100);
  },

  age(actor, year) { return year - actor.birth; },

  // Marktübliche Gage pro Film
  askFee(fame, year) {
    const f = this.infl(year) * 900000 * Math.pow(fame / 100, 2.6);
    return Math.max(f, 5000 * this.infl(year));
  },

  // Ruf-Schwelle: große Stars reden nicht mit kleinen Agenturen
  requiredRep(fame) { return fame <= 45 ? 0 : Math.round((fame - 45) * 1.1); },

  // ---------- US-Schulnoten für verdeckte Werte ----------
  GRADE_BANDS: [[92, "A+"], [85, "A"], [80, "A−"], [75, "B+"], [70, "B"], [65, "B−"], [60, "C+"], [55, "C"], [50, "C−"], [45, "D+"], [40, "D"], [35, "D−"], [0, "F"]],
  grade(v) {
    for (const [min, gd] of this.GRADE_BANDS) if (v >= min) return gd;
    return "F";
  },
  hash(s) {
    let h = 5381;
    for (const ch of String(s)) h = (h * 33 + ch.charCodeAt(0)) >>> 0;
    return h;
  },
  // Spannweite statt exakter Zahl: deterministisch pro Person verrauscht,
  // damit Scouting-Berichte konsistent bleiben. spread = Unschärfe in Punkten.
  gradeRange(v, spread, seed) {
    const jitter = (this.hash(seed) % 9) - 4;
    const center = clamp(v + jitter, 3, 100);
    const lo = this.grade(clamp(center - spread, 0, 100));
    const hi = this.grade(clamp(center + spread, 0, 100));
    return lo === hi ? lo : `${lo} – ${hi}`;
  },

  fmtMoney(v) {
    const sign = v < 0 ? "-" : "";
    v = Math.abs(v);
    if (v >= 1e9) return sign + (v / 1e9).toLocaleString("de-DE", { maximumFractionDigits: 2 }) + " Mrd. $";
    if (v >= 1e6) return sign + (v / 1e6).toLocaleString("de-DE", { maximumFractionDigits: 2 }) + " Mio. $";
    if (v >= 1e4) return sign + Math.round(v / 1000).toLocaleString("de-DE") + " Tsd. $";
    return sign + Math.round(v).toLocaleString("de-DE") + " $";
  },
};

// =====================================================================
// Spielzustand & Kernschleife
// =====================================================================
const Game = {
  state: null,
  nego: null,       // laufende Anwerbe-Verhandlung
  pitchCtx: null,   // laufende Casting-Verhandlung

  newGame(agencyName, startYear) {
    this.state = {
      agency: { name: agencyName || "Meine Agentur", cash: Math.round(120000 * Calc.infl(startYear)), rep: 15, debtMonths: 0 },
      year: startYear, month: 1, startYear,
      network: 10,
      clients: [],
      castings: [],
      productions: [],
      released: [],
      log: [],
      studioRel: {},
      market: 1.0,
      marketHistory: [],
      usedHistory: [],
      eventCd: {},
      followups: [],
      usedTitles: [],
      strikeMonths: 0, strikeExempt: false,
      nextId: 1,
      over: false,
    };
    for (const s of D.STUDIOS) this.state.studioRel[s.id] = rndInt(20, 45);
    this.log(`${agencyName} öffnet ihre Büros am Sunset Boulevard. Zeit, Karrieren zu machen.`, "history");
    this.spawnCastings(rndInt(2, 3));
    return this.state;
  },

  id() { return this.state.nextId++; },

  log(text, type = "info") {
    this.state.log.unshift({ y: this.state.year, m: this.state.month, text, type });
    if (this.state.log.length > 300) this.state.log.pop();
  },

  dateStr() { return `${MONTHS_DE[this.state.month - 1]} ${this.state.year}`; },
  mi() { return this.state.year * 12 + (this.state.month - 1); },

  // ---------- Talentpool & Klienten ----------
  activeStudios() {
    const y = this.state.year;
    return D.STUDIOS.filter(s => s.from <= y && s.to >= y);
  },

  isClient(actorId) { return this.state.clients.some(c => c.aid === actorId); },

  availableActors() {
    const y = this.state.year;
    return ACTORS.filter(a =>
      a.debut <= y &&
      (a.death === null || a.death > y) &&
      Calc.age(a, y) <= 85 &&
      !this.isClient(a.id)
    ).sort((a, b) => Calc.fameAt(b, y) - Calc.fameAt(a, y));
  },

  client(cid) { return this.state.clients.find(c => c.id === cid); },
  clientName(c) { return ACTOR_BY_ID[c.aid].name; },
  randomClient(filter) {
    const list = this.state.clients.filter(filter || (() => true));
    return list.length ? pick(list) : null;
  },
  availableClient(c) { return c.busyUntil <= this.mi(); },
  effTalent(c) {
    return clamp(ACTOR_BY_ID[c.aid].talent + (c.talentBonus || 0) - (c.flags.typecast ? 5 : 0), 5, 100);
  },

  // Verdeckte Zusatz-Attribute, deterministisch aus der Person abgeleitet
  // (kein Speicherbedarf, über Sessions stabil). Anzeige nur als Notenspanne.
  _attrCache: {},
  attrs(actor) {
    if (!this._attrCache[actor.id]) {
      const h = k => Calc.hash(actor.id + k) % 100;
      this._attrCache[actor.id] = {
        charisma: clamp(Math.round(30 + h("cha") * 0.5 + (actor.peakFame - 60) * 0.4), 5, 98),
        discipline: clamp(Math.round(95 - actor.ego * 0.55 - h("dis") * 0.25), 5, 95),
        presence: clamp(Math.round(actor.talent * 0.35 + actor.peakFame * 0.4 + h("pre") * 0.25 - 5), 5, 98),
      };
    }
    return this._attrCache[actor.id];
  },
  perkCosts() {
    const infl = Calc.infl(this.state.year);
    return this.state.clients.reduce((sum, c) =>
      sum + c.perks.reduce((s, p) => s + PERKS[p].cost, 0) * infl, 0);
  },
  overhead() {
    return Math.round((2200 + this.state.clients.length * 600) * Calc.infl(this.state.year) + this.perkCosts());
  },

  // =====================================================================
  // Verhandlungssystem v2: verdeckte Forderungen & Gegenvorschläge
  // =====================================================================
  actorProfile(actor, fame) {
    const y = this.state.year;
    const money = 20 + actor.ego * 0.5 + (fame > 70 ? 15 : 0);
    const prestige = actor.talent * 0.7;
    const security = clamp(85 - fame, 5, 60) + (Calc.age(actor, y) > 50 ? 15 : 0);
    const sum = money + prestige + security;
    return {
      money: money / sum, prestige: prestige / sum, security: security / sum,
      top: money >= prestige && money >= security ? "money" : (prestige >= security ? "prestige" : "security"),
    };
  },

  // Verdeckte Wunschliste des Stars
  actorDemands(actor, fame, ask, profile) {
    const perksByTrait = {
      money: ["travel", "assistant"], prestige: ["script", "coach"], security: ["pr", "assistant"],
    };
    const traits = ["money", "prestige", "security"].sort((a, b) => profile[b] - profile[a]);
    const wanted = [];
    wanted.push(pick(perksByTrait[traits[0]]));
    const second = pick(perksByTrait[traits[1]]);
    if (!wanted.includes(second) && chance(0.7)) wanted.push(second);
    let promise = null;
    if (profile.top === "prestige" && fame < 75) promise = chance(0.5) ? "prestige" : null;
    if (profile.top === "security") promise = chance(0.5) ? "lead12" : null;
    if (actor.talent > 88 && actor.ego > 75 && chance(0.4)) promise = "oscar";
    return {
      commission: clamp(Math.round(16 - fame / 10 - actor.ego / 20), 5, 14),
      bonus: Math.round(ask * (0.04 + actor.ego / 500 + profile.money * 0.12)),
      years: profile.top === "security" ? 7 : profile.top === "money" ? 3 : 5,
      perks: wanted,
      promise,
    };
  },

  startNegotiation(actorId) {
    const actor = ACTOR_BY_ID[actorId];
    const fame = Calc.fameAt(actor, this.state.year);
    const reqRep = Calc.requiredRep(fame);
    if (this.state.agency.rep < reqRep) {
      return { locked: true, actor, fame, reqRep };
    }
    const ask = Calc.askFee(fame, this.state.year);
    const profile = this.actorProfile(actor, fame);
    this.nego = {
      actor, fame, ask, profile,
      demands: this.actorDemands(actor, fame, ask, profile),
      round: 1, maxRounds: 4,
      counter: null, done: false,
    };
    return this.nego;
  },

  // Angebot: { commission, bonus, years, perks: [], promise: null|key }
  evaluateOffer(offer) {
    const n = this.nego, p = n.profile, d = n.demands, rep = this.state.agency.rep;
    const trust = 0.35 + rep / 140; // Versprechen sind nur so viel wert wie der Ruf der Agentur
    const bonusFactor = clamp(offer.bonus / (n.ask * 0.12), 0, 1.3);
    const moneyRaw = (18 - offer.commission) * 3.5 + bonusFactor * 50;
    let promiseRaw = 0;
    if (offer.promise === "lead12") promiseRaw = 38 * (p.security * 0.6 + p.prestige * 0.4) * 3;
    if (offer.promise === "prestige") promiseRaw = 38 * p.prestige * 3;
    if (offer.promise === "oscar") promiseRaw = 48 * p.prestige * 3;
    if (d.promise && offer.promise === d.promise) promiseRaw += 10;
    const perksScore = offer.perks.reduce((s, pk) => s + (d.perks.includes(pk) ? 13 : 4), 0);
    const yearsScore = -Math.abs(offer.years - d.years) * 2.5;
    const standing = (rep - n.fame * 0.55) * 0.9;
    return moneyRaw * p.money * 2.6 + promiseRaw * trust + perksScore + yearsScore + standing - (n.round - 1) * 3;
  },

  moodLabel(score) {
    if (score >= 65) return { label: "begeistert", cls: "pos" };
    if (score >= 50) return { label: "interessiert", cls: "" };
    if (score >= 34) return { label: "abwägend", cls: "" };
    return { label: "ablehnend", cls: "neg" };
  },

  negotiationHint() {
    const n = this.nego, a = n.actor;
    const hints = {
      money: [
        `„Schöne Worte zahlen keine Villa in Bel Air, mein Freund.“`,
        `„Reden wir über Zahlen. Alles andere ist Smalltalk.“`,
      ],
      prestige: [
        `„Ich will Rollen, über die man in dreißig Jahren noch spricht.“`,
        `„Geld verdirbt. Kunst bleibt. Was bieten Sie mir künstlerisch?“`,
      ],
      security: [
        `„Ich muss wissen, dass ich nächstes Jahr noch arbeite. Können Sie das garantieren?“`,
        `„Versprechen Sie mir nichts, was Sie nicht halten können — davon hatte ich genug.“`,
      ],
    };
    return `${a.name}: ${pick(hints[n.profile.top])}`;
  },

  // Gegenvorschlag: der Star biegt das Angebot in Richtung seiner Wünsche
  buildCounter(offer) {
    const n = this.nego, d = n.demands;
    const counter = {
      commission: Math.min(offer.commission, d.commission),
      bonus: Math.max(offer.bonus, Math.round(d.bonus * 0.85 / 1000) * 1000),
      years: d.years,
      perks: [...new Set([...offer.perks, ...d.perks])],
      promise: offer.promise || d.promise,
    };
    // Text in Charakter-Sprache
    const parts = [];
    if (counter.commission < offer.commission) parts.push(`${counter.commission} % Provision — keinen Punkt mehr`);
    if (counter.bonus > offer.bonus) parts.push(`${Calc.fmtMoney(counter.bonus)} Handgeld im Voraus`);
    if (counter.years !== offer.years) parts.push(`${counter.years} Jahre Laufzeit`);
    const newPerks = counter.perks.filter(p => !offer.perks.includes(p));
    if (newPerks.length) parts.push(newPerks.map(p => PERKS[p].de).join(" und "));
    if (counter.promise && counter.promise !== offer.promise) parts.push(`Ihr Wort auf ${PROMISES[counter.promise].label}`);
    if (!parts.length) return null;
    counter.text = `„Mein Angebot: ${parts.join(", ")}. Dann unterschreibe ich heute noch.“`;
    return counter;
  },

  signClient(terms) {
    const n = this.nego;
    if (terms.bonus > this.state.agency.cash) return { broke: true };
    this.state.agency.cash -= terms.bonus;
    const c = {
      id: this.id(), aid: n.actor.id, fame: n.fame, heat: 0,
      loyalty: rndInt(45, 60) + (terms.bonus > 0 ? 6 : 0), mood: 60, exhaustion: 0,
      commission: terms.commission, perks: terms.perks || [],
      years: terms.years, contractEnd: this.mi() + terms.years * 12,
      promises: [], busyUntil: 0, films: [], flags: {}, talentBonus: 0, campaign: 0, awards: 0,
      signedAt: this.mi(),
    };
    if (terms.promise) {
      c.promises.push({ type: terms.promise, label: PROMISES[terms.promise].label, due: this.mi() + PROMISES[terms.promise].months, fulfilled: false });
    }
    this.state.clients.push(c);
    this.state.agency.rep = clamp(this.state.agency.rep + Math.round(n.fame / 22), 0, 100);
    const perkStr = c.perks.length ? ", " + c.perks.map(p => PERKS[p].de).join("/") : "";
    this.log(`${n.actor.name} unterschreibt für ${terms.years} Jahre (${terms.commission} % Provision${terms.bonus ? ", Bonus " + Calc.fmtMoney(terms.bonus) : ""}${perkStr}${terms.promise ? ", mit Versprechen" : ""}).`, "deal");
    n.done = true;
    return { accepted: true, client: c };
  },

  makeOffer(offer) {
    const n = this.nego;
    const score = this.evaluateOffer(offer) + rnd(-9, 9);
    if (score >= 58) {
      const res = this.signClient(offer);
      if (res.broke) return { accepted: false, broke: true };
      return res;
    }
    n.round++;
    n.counter = score >= 34 ? this.buildCounter(offer) : null;
    if (n.round > n.maxRounds) {
      n.done = true;
      this.log(`${n.actor.name} lehnt endgültig ab.`, "bad");
      return { accepted: false, final: true, hint: this.negotiationHint() };
    }
    return { accepted: false, final: false, hint: this.negotiationHint(), counter: n.counter };
  },

  acceptCounter() {
    const res = this.signClient(this.nego.counter);
    return res;
  },

  // =====================================================================
  // Castings & Studio-Verhandlung
  // =====================================================================
  genreWeights() {
    const y = this.state.year;
    const w = { drama: 20, comedy: 16, romance: 12, thriller: 10, crime: 10, adventure: 8, action: 6, horror: 5 };
    w.western = y < 1975 ? 12 : 1;
    w.musical = y < 1970 ? 10 : 2;
    w.scifi = y < 1950 ? 1 : (y < 1977 ? 5 : 12);
    if (y >= 1980) { w.action = 16; w.romance = 8; }
    return w;
  },

  pickGenre() {
    const w = this.genreWeights();
    const total = Object.values(w).reduce((a, b) => a + b, 0);
    let r = Math.random() * total;
    for (const [g, v] of Object.entries(w)) { r -= v; if (r <= 0) return g; }
    return "drama";
  },

  makeTitle(genre) {
    const t = D.TITLES[genre];
    return `${pick(t.a)} ${pick(t.b)}`;
  },

  // Bevorzugt echte Filmtitel nahe am Spieljahr (jeder nur einmal pro
  // Spielstand), sonst der Generator.
  projectTitle(genre) {
    const y = this.state.year;
    const used = this.state.usedTitles;
    const cand = D.REAL_TITLES.filter(t => Math.abs(t.y - y) <= 4 && t.g.includes(genre) && !used.includes(t.t));
    if (cand.length && chance(0.8)) {
      const t = pick(cand);
      used.push(t.t);
      return t.t;
    }
    return this.makeTitle(genre);
  },

  spawnCastings(count) {
    const y = this.state.year;
    for (let i = 0; i < count; i++) {
      const studio = pick(this.activeStudios());
      const genre = this.pickGenre();
      let prestige = studio.style === "prestige" ? rndInt(1, 3) : studio.style === "indie" ? rndInt(1, 3) : rndInt(0, 2);
      if (genre === "drama" && chance(0.4)) prestige = Math.min(3, prestige + 1);
      const roles = [];
      const leadGender = chance(0.5) ? "m" : "f";
      const mkRole = (type, gender) => {
        const minFame = type === "lead" ? rndInt(25, 55 + prestige * 10) : rndInt(10, 35);
        const ageMin = rndInt(18, 45), ageSpan = rndInt(12, 30);
        return {
          type, gender, minFame, ageMin, ageMax: ageMin + ageSpan,
          fee: Math.round(Calc.askFee(minFame + 12, y) * (type === "lead" ? 1 : 0.35)),
          filled: null,
        };
      };
      roles.push(mkRole("lead", leadGender));
      if (chance(0.6)) roles.push(mkRole("lead", leadGender === "m" ? "f" : "m"));
      roles.push(mkRole("support", chance(0.5) ? "m" : "f"));
      if (chance(0.4)) roles.push(mkRole("support", chance(0.5) ? "m" : "f"));
      const feeSum = roles.reduce((s, r) => s + r.fee, 0);
      this.state.castings.push({
        id: this.id(), studioId: studio.id, title: this.projectTitle(genre), genre, prestige,
        budget: Math.round(feeSum * rnd(3, 4.5) + 400000 * Calc.infl(y) * rnd(0.6, 1.4) * (1 + prestige * 0.3)),
        deadline: rndInt(2, 3), roles, qualityMod: 0,
      });
    }
  },

  // Passung eines Klienten für eine Rolle (0-100)
  fitScore(casting, role, c) {
    const actor = ACTOR_BY_ID[c.aid];
    const y = this.state.year;
    const age = Calc.age(actor, y);
    let fit = 30;
    if (actor.genres.includes(casting.genre)) fit += 22 + (c.perks.includes("script") ? 5 : 0);
    fit += (this.attrs(actor).charisma - 50) / 15;
    fit += clamp((c.fame - role.minFame) * 0.7, -25, 18);
    fit += c.heat * 2;
    fit += this.state.studioRel[casting.studioId] / 6;
    fit -= Math.max(0, (c.exhaustion - 50) / 2.5);
    if (age < role.ageMin) fit -= (role.ageMin - age) * 2.5;
    if (age > role.ageMax) fit -= (age - role.ageMax) * 2.5;
    return clamp(Math.round(fit), 2, 97);
  },

  eligibleClients(casting, role) {
    return this.state.clients
      .filter(c => {
        const a = ACTOR_BY_ID[c.aid];
        return a.g === role.gender && c.busyUntil <= this.mi() &&
          !casting.roles.some(r => r.filled && r.filled.clientId === c.id);
      })
      .map(c => ({ c, fit: this.fitScore(casting, role, c), estFee: this.roleFeeFor(casting, role, c) }))
      .filter(e => !(e.c.perks.includes("script") && e.fit < 35)) // Drehbuch-Mitsprache: Klient winkt ab
      .sort((a, b) => b.fit - a.fit);
  },

  roleFeeFor(casting, role, c) {
    const ask = Calc.askFee(c.fame, this.state.year) * (role.type === "lead" ? 1 : 0.35) * (1 + (c.awards || 0) * 0.08);
    return Math.round(clamp(ask, role.fee * 0.6, role.fee * 2.2));
  },

  submitPitch(castingId, roleIdx, clientId) {
    const casting = this.state.castings.find(x => x.id === castingId);
    const role = casting.roles[roleIdx];
    const c = this.client(clientId);
    const fit = this.fitScore(casting, role, c);
    const p = clamp(fit / 100 + 0.08, 0.05, 0.95);
    if (chance(p)) {
      const fee = this.roleFeeFor(casting, role, c);
      this.pitchCtx = { casting, roleIdx, role, client: c, fee, haggled: false };
      return { success: true, fee };
    }
    role.rejected = role.rejected || [];
    role.rejected.push(clientId);
    this.state.studioRel[casting.studioId] = clamp(this.state.studioRel[casting.studioId] - 1, 0, 100);
    return { success: false };
  },

  closeDeal(fee, extraLog = "") {
    const ctx = this.pitchCtx;
    const { casting, role, client } = ctx;
    role.filled = { clientId: client.id, fee };
    client.busyUntil = this.mi() + casting.deadline;
    const studio = D.STUDIOS.find(s => s.id === casting.studioId);
    this.log(`Deal: ${this.clientName(client)} spielt ${role.type === "lead" ? "die Hauptrolle" : "eine Nebenrolle"} in „${casting.title}“ (${studio.name}) für ${Calc.fmtMoney(fee)}. Provision: ${Calc.fmtMoney(fee * client.commission / 100)}.${extraLog}`, "deal");
    this.checkPromisesOnDeal(client, casting, role);
    client.mood = clamp(client.mood + 8, 0, 100);
    this.state.network = clamp(this.state.network + 1, 0, 100);
    this.pitchCtx = null;
  },

  acceptOffer() { this.closeDeal(this.pitchCtx.fee); },

  haggle() {
    const ctx = this.pitchCtx;
    const rel = this.state.studioRel[ctx.casting.studioId];
    const surplus = ctx.client.fame - ctx.role.minFame;
    const p = clamp(0.35 + surplus / 120 + ctx.client.heat / 50 + rel / 250 + (ctx.client.awards || 0) * 0.06, 0.1, 0.88);
    ctx.haggled = true;
    if (chance(p)) {
      ctx.fee = Math.round(ctx.fee * 1.25);
      return { success: true, fee: ctx.fee };
    }
    if (chance(0.45)) {
      this.state.studioRel[ctx.casting.studioId] = clamp(rel - 6, 0, 100);
      this.log(`Zu hoch gepokert: „${ctx.casting.title}“ — das Studio bricht die Verhandlung mit ${this.clientName(ctx.client)} ab.`, "bad");
      const lost = this.pitchCtx;
      this.pitchCtx = null;
      return { success: false, lost: true, casting: lost.casting };
    }
    return { success: false, lost: false, fee: ctx.fee };
  },

  packageOptions() {
    const ctx = this.pitchCtx;
    if (!ctx || this.state.agency.rep < 25) return [];
    const out = [];
    ctx.casting.roles.forEach((r, idx) => {
      if (r.type === "support" && !r.filled && idx !== ctx.roleIdx) {
        for (const e of this.eligibleClients(ctx.casting, r)) {
          if (e.c.id !== ctx.client.id) out.push({ roleIdx: idx, role: r, ...e });
        }
      }
    });
    return out.sort((a, b) => b.fit - a.fit).slice(0, 6);
  },

  tryPackage(supportRoleIdx, secondClientId) {
    const ctx = this.pitchCtx;
    const casting = ctx.casting;
    const role2 = casting.roles[supportRoleIdx];
    const c2 = this.client(secondClientId);
    const rel = this.state.studioRel[casting.studioId];
    const p = clamp(0.4 + this.state.agency.rep / 180 + this.fitScore(casting, role2, c2) / 300, 0.15, 0.9);
    if (chance(p)) {
      const fee1 = Math.round(ctx.fee * 1.12);
      const fee2 = Math.round(this.roleFeeFor(casting, role2, c2) * 1.12);
      this.closeDeal(fee1, " (Package-Deal)");
      role2.filled = { clientId: c2.id, fee: fee2 };
      c2.busyUntil = this.mi() + casting.deadline;
      c2.mood = clamp(c2.mood + 8, 0, 100);
      this.checkPromisesOnDeal(c2, casting, role2);
      this.log(`Package-Deal perfekt: ${this.clientName(c2)} übernimmt zusätzlich eine Nebenrolle in „${casting.title}“ für ${Calc.fmtMoney(fee2)}.`, "deal");
      this.state.agency.rep = clamp(this.state.agency.rep + 2, 0, 100);
      this.state.network = clamp(this.state.network + 2, 0, 100);
      return { success: true };
    }
    this.state.studioRel[casting.studioId] = clamp(rel - 4, 0, 100);
    return { success: false };
  },

  checkPromisesOnDeal(client, casting, role) {
    for (const pr of client.promises) {
      if (pr.fulfilled) continue;
      if (pr.type === "lead12" && role.type === "lead") this.fulfillPromise(client, pr);
      if (pr.type === "prestige" && casting.prestige >= 2) this.fulfillPromise(client, pr);
    }
  },

  fulfillPromise(client, pr) {
    pr.fulfilled = true;
    client.loyalty = clamp(client.loyalty + 18, 0, 100);
    client.mood = clamp(client.mood + 10, 0, 100);
    this.state.agency.rep = clamp(this.state.agency.rep + 3, 0, 100);
    this.log(`Versprechen gehalten: ${this.clientName(client)} — ${pr.label}. Loyalität steigt deutlich.`, "deal");
  },

  // Sofort-Deal aus Ereignissen (Einspringer, Paket-Anfragen …)
  quickProduction(c, opts = {}) {
    const st = this.state;
    const actor = ACTOR_BY_ID[c.aid];
    const genre = opts.genre || (chance(0.7) ? pick(actor.genres) : this.pickGenre());
    const studio = opts.studio || pick(this.activeStudios());
    const roleType = opts.roleType || "lead";
    const fee = Math.round(Calc.askFee(c.fame, st.year) * (roleType === "lead" ? 1 : 0.35) * (opts.feeMult || 1));
    const months = rndInt(4, 6);
    const prod = {
      id: this.id(), studioId: studio.id, title: this.projectTitle(genre), genre,
      prestige: opts.prestige !== undefined ? opts.prestige : rndInt(1, 2),
      budget: Math.round(fee * rnd(3, 4.5) + 300000 * Calc.infl(st.year)),
      monthsLeft: months, qualityMod: opts.qualityMod || 0,
      roles: [{ type: roleType, gender: actor.g, minFame: 30, ageMin: 18, ageMax: 99, fee, filled: { clientId: c.id, fee } }],
    };
    st.productions.push(prod);
    const income = Math.round(fee * c.commission / 100);
    st.agency.cash += income;
    c.busyUntil = this.mi() + months;
    this.log(`Sofort-Deal: ${this.clientName(c)} in „${prod.title}“ (${studio.name}) — ${Calc.fmtMoney(fee)} Gage, ${Calc.fmtMoney(income)} Provision.`, "deal");
    return { fee, income, title: prod.title, studioName: studio.name, prod };
  },

  // =====================================================================
  // Monatswechsel
  // =====================================================================
  endMonth() {
    const st = this.state;
    if (st.over) return;
    const events = [];

    st.month++;
    if (st.month > 12) { st.month = 1; st.year++; }
    if (window.Music) Music.setEra(st.year);

    // Historische Ereignisse
    for (const h of D.HISTORY) {
      const key = h.year + "-" + h.month;
      if (h.year === st.year && h.month === st.month && !st.usedHistory.includes(key)) {
        st.usedHistory.push(key);
        st.market = h.market;
        this.log(h.text, "history");
        events.push({ title: "Schlagzeile", html: `<div class="quote">${h.text}</div>`, choices: [{ label: "Weiter" }] });
        if (h.effect === "talkies") {
          for (const c of st.clients) {
            if (ACTOR_BY_ID[c.aid].debut <= 1924) {
              c.fame = clamp(c.fame - 12, 5, 100); c.mood -= 15;
              this.log(`${this.clientName(c)} kämpft mit dem Tonfilm — der Ruhm bröckelt.`, "bad");
            }
          }
        }
      }
    }
    st.market += (1 - st.market) * 0.06;
    st.marketHistory.push(Math.round(st.market * 100));
    if (st.marketHistory.length > 24) st.marketHistory.shift();

    // Streik: legt Castings & Produktionen lahm
    const strike = st.strikeMonths > 0;
    if (strike) {
      st.strikeMonths--;
      this.log(`Der Streik legt Hollywood lahm${st.strikeExempt ? " — deine Produktionen laufen per Ausnahme weiter" : ""}.`, "bad");
      if (st.strikeMonths === 0) { this.log("Der Streik ist beendet. Die Studios fahren die Produktion wieder hoch.", "history"); st.strikeExempt = false; }
    }

    // Castings: Deadline senken, bei 0 → Produktion
    if (!strike) {
      for (const casting of [...st.castings]) {
        casting.deadline--;
        if (casting.deadline <= 0) {
          this.startProduction(casting);
          st.castings = st.castings.filter(x => x.id !== casting.id);
        }
      }
    }

    // Produktionen fortschreiten / Release
    if (!strike || st.strikeExempt) {
      for (const prod of [...st.productions]) {
        prod.monthsLeft--;
        if (prod.monthsLeft <= 0) {
          const rel = this.releaseFilm(prod);
          st.productions = st.productions.filter(x => x.id !== prod.id);
          events.push(rel.modal);
        }
      }
    }

    // Neue Castings
    if (!strike) {
      this.spawnCastings(rndInt(1, 2) + (st.agency.rep >= 50 ? 1 : 0));
      if (st.castings.length > 10) st.castings = st.castings.slice(-10);
    }

    // Klienten-Pflege
    this.tickClients(events);

    // Follow-up-Ereignisse (z. B. wieder auftauchende Fotos)
    for (const fu of [...st.followups]) {
      if (this.mi() >= fu.due) {
        st.followups = st.followups.filter(x => x !== fu);
        const ev = window.HM_FOLLOWUPS && HM_FOLLOWUPS[fu.type] && HM_FOLLOWUPS[fu.type](this, fu);
        if (ev) events.push(ev);
      }
    }

    // Awards im Februar
    if (st.month === 2) {
      const aw = this.awardsCeremony();
      if (aw) events.push(aw);
    }

    // Zufallsereignis über die Event-Engine
    this.maybeFireEvent(events);

    // Kosten & Pleite-Check
    st.agency.cash -= this.overhead();
    if (st.agency.cash < 0) {
      st.agency.debtMonths++;
      this.log(`Die Agentur ist zahlungsunfähig (${st.agency.debtMonths}/3 Monate). Die Banken werden nervös.`, "bad");
      if (st.agency.debtMonths >= 3) {
        st.over = true;
        events.push({ title: "Game Over", html: `<p>Drei Monate in den roten Zahlen — die Gläubiger übernehmen. ${st.agency.name} schließt für immer die Türen.</p><p class="hint">Erreicht: ${st.clients.length} Klienten, Ruf ${st.agency.rep}, ${st.released.length} vermittelte Filme.</p>`, choices: [{ label: "Neues Spiel", action: "restart" }] });
      }
    } else st.agency.debtMonths = 0;

    return events;
  },

  maybeFireEvent(events) {
    if (!window.HM_EVENTS) return;
    const st = this.state;
    const candidates = HM_EVENTS
      .filter(e => (st.eventCd[e.id] || 0) <= this.mi())
      .map(e => ({ e, w: e.weight(this) }))
      .filter(x => x.w > 0);
    if (!candidates.length) return;
    const seasonal = candidates.some(x => x.w >= 3);
    if (!chance(seasonal ? 0.8 : 0.45)) return;
    const total = candidates.reduce((s, x) => s + x.w, 0);
    let r = Math.random() * total;
    let chosen = candidates[0];
    for (const x of candidates) { r -= x.w; if (r <= 0) { chosen = x; break; } }
    st.eventCd[chosen.e.id] = this.mi() + (chosen.e.cd || 9);
    const ev = chosen.e.build(this);
    if (ev) events.push(ev);
  },

  tickClients(events) {
    const st = this.state;
    for (const c of [...st.clients]) {
      const actor = ACTOR_BY_ID[c.aid];
      // Tod
      if (actor.death !== null && st.year >= actor.death) {
        this.log(`Hollywood trauert: ${actor.name} ist verstorben (${actor.birth}–${actor.death}).`, "history");
        st.clients = st.clients.filter(x => x.id !== c.id);
        continue;
      }
      const busy = c.busyUntil > this.mi();
      // Erschöpfung (undisziplinierte Naturen verschleißen schneller)
      const disc = this.attrs(actor).discipline;
      if (busy) c.exhaustion = clamp(c.exhaustion + (c.perks.includes("assistant") ? 3 : 6) + (disc < 40 ? 2 : disc > 75 ? -1 : 0), 0, 100);
      else c.exhaustion = clamp(c.exhaustion - (c.perks.includes("travel") ? 11 : 8), 0, 100);
      if (c.exhaustion > 75) c.mood = clamp(c.mood - 4, 0, 100);
      // Perk-Effekte
      if (c.perks.includes("pr")) c.mood = clamp(c.mood + 1, 0, 100);
      if (c.perks.includes("travel")) c.mood = clamp(c.mood + 2, 0, 100);
      if (c.perks.includes("assistant")) c.loyalty = clamp(c.loyalty + 1, 0, 100);
      if (c.perks.includes("coach")) c.talentBonus = Math.min(10, (c.talentBonus || 0) + 0.15);
      // TV-Vertrag (Ereignis 20)
      if (c.flags.tvIncome && c.flags.tvIncome.months > 0) {
        st.agency.cash += c.flags.tvIncome.monthly;
        c.flags.tvIncome.months--;
        c.fame = clamp(c.fame - 0.3, 5, 100);
      }
      // Ruhm & Stimmung
      if (!busy) {
        c.heat = clamp(c.heat - 1, -10, 10);
        c.fame = Math.max(c.fame - 0.4, Calc.fameAt(actor, st.year) * 0.6, 5);
        c.mood = clamp(c.mood - 2, 0, 100);
        if (c.mood < 35) c.loyalty = clamp(c.loyalty - 2, 0, 100);
      } else {
        c.mood = clamp(c.mood + 1, 0, 100);
      }
      // Versprechen-Deadlines
      for (const pr of c.promises) {
        if (!pr.fulfilled && !pr.broken && this.mi() > pr.due) {
          pr.broken = true;
          c.loyalty = clamp(c.loyalty - 35, 0, 100);
          c.mood = clamp(c.mood - 20, 0, 100);
          st.agency.rep = clamp(st.agency.rep - 5, 0, 100);
          this.log(`Versprechen gebrochen: ${actor.name} wartete vergeblich auf ${pr.label}. Das spricht sich herum.`, "bad");
          events.push({ title: "Ein gebrochenes Versprechen", html: `<div class="quote">„Sie hatten mir Ihr Wort gegeben. In dieser Stadt ist das Wort eines Agenten alles — dachte ich.“</div><p>${actor.name} ist tief enttäuscht. Loyalität stürzt ab, dein Ruf leidet.</p>`, choices: [{ label: "Verstanden" }] });
        }
      }
      // Vertragsende
      if (this.mi() >= c.contractEnd) {
        if (c.loyalty >= 65) {
          c.contractEnd = this.mi() + c.years * 12;
          this.log(`${actor.name} verlängert den Vertrag ohne Zögern um ${c.years} Jahre.`, "deal");
        } else {
          const cid = c.id;
          events.push({
            title: "Vertrag läuft aus",
            html: `<p>Der Vertrag mit <b>${actor.name}</b> endet. Die Loyalität (${Math.round(c.loyalty)}/100) reicht nicht für eine automatische Verlängerung.</p>`,
            choices: [
              { label: "Zugeständnis: Provision −2 Punkte", fn: () => {
                const cl = this.client(cid); if (!cl) return "Zu spät.";
                cl.commission = Math.max(5, cl.commission - 2);
                cl.contractEnd = this.mi() + cl.years * 12;
                cl.loyalty = clamp(cl.loyalty + 10, 0, 100);
                return `${actor.name} bleibt — zu ${cl.commission} % Provision.`;
              }},
              { label: "Ziehen lassen", fn: () => {
                st.clients = st.clients.filter(x => x.id !== cid);
                this.log(`${actor.name} verlässt die Agentur nach Vertragsende — im Guten.`, "info");
                return `Man trennt sich professionell. Keine bösen Schlagzeilen.`;
              }},
            ],
          });
          c.contractEnd = this.mi() + 2; // Schonfrist bis zur Entscheidung
        }
      }
      // Kündigung bei zerrütteter Beziehung
      if (c.loyalty < 20 && chance(0.4)) {
        st.clients = st.clients.filter(x => x.id !== c.id);
        st.agency.rep = clamp(st.agency.rep - 3, 0, 100);
        this.log(`${actor.name} verlässt die Agentur. „Meine Anwälte melden sich.“`, "bad");
        events.push({ title: "Klient verloren", html: `<p>${actor.name} hat den Vertrag gekündigt und wechselt zur Konkurrenz.</p>`, choices: [{ label: "Weiter" }] });
      }
      // Alters-Ruhestand
      if (Calc.age(actor, st.year) > 85) {
        st.clients = st.clients.filter(x => x.id !== c.id);
        this.log(`${actor.name} zieht sich mit ${Calc.age(actor, st.year)} Jahren aus dem Geschäft zurück.`, "info");
      }
    }
  },

  // ---------- Produktion & Box-Office ----------
  startProduction(casting) {
    const st = this.state;
    for (const role of casting.roles) {
      if (role.filled) continue;
      const y = st.year;
      const candidates = this.availableActors().filter(a =>
        a.g === role.gender && Calc.fameAt(a, y) >= role.minFame * 0.6 &&
        Calc.age(a, y) >= role.ageMin - 6 && Calc.age(a, y) <= role.ageMax + 8
      );
      if (candidates.length && chance(0.7)) {
        const a = pick(candidates.slice(0, 8));
        role.filled = { npc: true, name: a.name, talent: a.talent, fame: Calc.fameAt(a, y) };
      } else {
        const first = role.gender === "m" ? pick(D.NPC_FIRST_M) : pick(D.NPC_FIRST_F);
        role.filled = { npc: true, name: `${first} ${pick(D.NPC_LAST)}`, talent: rndInt(35, 70), fame: rndInt(10, Math.max(12, role.minFame)) };
      }
    }
    const months = rndInt(4, 7);
    let income = 0;
    for (const role of casting.roles) {
      if (role.filled.clientId) {
        const c = this.client(role.filled.clientId);
        if (c) { income += role.filled.fee * c.commission / 100; c.busyUntil = this.mi() + months; }
      }
    }
    if (income > 0) {
      st.agency.cash += Math.round(income);
      this.log(`Drehbeginn „${casting.title}“ — Provisionen über ${Calc.fmtMoney(income)} gehen ein.`, "deal");
    }
    st.productions.push({ ...casting, monthsLeft: months });
  },

  releaseFilm(prod) {
    const st = this.state;
    const castInfo = f => f.clientId ? this.client(f.clientId) : null;
    const script = 35 + prod.prestige * 8 + rnd(0, 20);
    const talents = prod.roles.map(r => {
      const c = castInfo(r.filled);
      return c ? this.effTalent(c) : (r.filled.talent || 50);
    });
    const castQ = talents.reduce((a, b) => a + b, 0) / talents.length;
    let fitBonus = 0;
    for (const r of prod.roles) {
      const c = castInfo(r.filled);
      if (c && ACTOR_BY_ID[c.aid].genres.includes(prod.genre)) fitBonus += 2.5;
    }
    const quality = clamp(Math.round(script * 0.45 + castQ * 0.5 + fitBonus + (prod.qualityMod || 0) + rnd(-5, 5)), 5, 100);
    const leads = prod.roles.filter(r => r.type === "lead");
    // Star-Power: Ruhm plus Leinwandpräsenz der Hauptdarsteller
    const fames = leads.map(r => {
      const c = castInfo(r.filled);
      return c ? c.fame * 0.75 + this.attrs(ACTOR_BY_ID[c.aid]).presence * 0.25 : (r.filled.fame || 25);
    });
    const starPower = fames.reduce((a, b) => a + b, 0) / Math.max(1, fames.length);
    const revenue = Math.round(prod.budget * (0.25 + quality / 45 + starPower / 70) * st.market * rnd(0.55, 1.75));
    const ratio = revenue / prod.budget;
    const verdict = ratio < 1 ? "Flop" : ratio < 2 ? "Achtbarer Erfolg" : ratio < 3.2 ? "Hit" : "Blockbuster";
    const affected = [];
    for (const r of prod.roles) {
      const c = castInfo(r.filled);
      if (!c) continue;
      const mult = r.type === "lead" ? 1 : 0.5;
      const delta = clamp(((quality - 55) / 8 + (ratio - 1.6) * 2.5) * mult, -8, 10);
      c.fame = clamp(c.fame + delta, 5, 100);
      c.heat = clamp(c.heat + delta * 0.7, -10, 10);
      c.loyalty = clamp(c.loyalty + (delta > 0 ? 3 : -2), 0, 100);
      c.films.unshift({ title: prod.title, year: st.year, verdict, quality, lead: r.type === "lead" });
      if (c.films.length > 12) c.films.pop();
      affected.push({ name: this.clientName(c), delta: Math.round(delta) });
    }
    if (affected.length) st.agency.rep = clamp(st.agency.rep + (ratio >= 2 ? 2 : ratio < 1 ? -1 : 0), 0, 100);
    const studio = D.STUDIOS.find(s => s.id === prod.studioId);
    st.studioRel[prod.studioId] = clamp(st.studioRel[prod.studioId] + (ratio >= 2 ? 5 : ratio < 1 ? -3 : 1), 0, 100);
    st.released.unshift({ title: prod.title, genre: prod.genre, year: st.year, studioId: prod.studioId, quality, revenue, budget: prod.budget, ratio, verdict, prestige: prod.prestige, roles: prod.roles });
    this.log(`Premiere „${prod.title}“ (${studio.name}): ${verdict} — ${Calc.fmtMoney(revenue)} Einspielergebnis bei Qualität ${quality}.`, ratio < 1 ? "bad" : "deal");
    const castList = affected.map(a => `${a.name} (${a.delta >= 0 ? "+" : ""}${a.delta} Ruhm)`).join(", ");
    return {
      modal: {
        title: `Premiere: „${prod.title}“`,
        html: `<p><b>${studio.name}</b> · ${D.GENRES[prod.genre].de} · Qualität ${quality}/100</p>
               <p>Einspielergebnis: <b class="money">${Calc.fmtMoney(revenue)}</b> (Budget ${Calc.fmtMoney(prod.budget)}) — <b>${verdict}</b></p>
               ${castList ? `<p class="hint">Deine Klienten: ${castList}</p>` : ""}`,
        choices: [{ label: "Weiter" }],
      },
    };
  },

  // ---------- Awards ----------
  awardsCeremony() {
    const st = this.state;
    const pool = st.released.filter(f => f.year === st.year - 1);
    if (!pool.length) return null;
    const sorted = [...pool].sort((a, b) => b.quality - a.quality);
    const noms = sorted.slice(0, 3);
    const winner = noms[0];
    let html = `<p>Die Academy ehrt die Filme des Jahres ${st.year - 1}.</p><p><b>Bester Film:</b> „${winner.title}“</p>`;
    const perfs = [];
    for (const f of noms) for (const r of f.roles) {
      if (r.type !== "lead") continue;
      const c = r.filled.clientId ? this.client(r.filled.clientId) : null;
      const name = c ? this.clientName(c) : r.filled.name;
      const talent = c ? this.effTalent(c) : (r.filled.talent || 50);
      perfs.push({ c, name, score: talent * 0.5 + f.quality * 0.4 + (c ? c.campaign : 0) + rnd(0, 15), film: f.title });
    }
    perfs.sort((a, b) => b.score - a.score);
    const best = perfs[0];
    if (best) {
      html += `<p><b>Beste darstellerische Leistung:</b> ${best.name} („${best.film}“)</p>`;
      if (best.c) {
        best.c.fame = clamp(best.c.fame + 8, 5, 100);
        best.c.heat = clamp(best.c.heat + 5, -10, 10);
        best.c.loyalty = clamp(best.c.loyalty + 12, 0, 100);
        best.c.awards = (best.c.awards || 0) + 1;
        st.agency.rep = clamp(st.agency.rep + 6, 0, 100);
        html += `<p class="pos">Dein Klient gewinnt! Ruf +6, Ruhm +8 — und dauerhaft mehr Verhandlungsmacht.</p>`;
        this.log(`${best.name} gewinnt den Academy Award — vermittelt von ${st.agency.name}!`, "history");
      }
    }
    const nomClients = perfs.slice(0, 3).filter(p => p.c).map(p => p.c);
    for (const c of nomClients) {
      for (const pr of c.promises) {
        if (!pr.fulfilled && !pr.broken && pr.type === "oscar") this.fulfillPromise(c, pr);
      }
      if (c !== (best && best.c)) { c.fame = clamp(c.fame + 4, 5, 100); }
    }
    for (const c of st.clients) c.campaign = 0;
    return { title: `Award-Saison ${st.year}`, html, choices: [{ label: "Applaus!" }] };
  },

  // ---------- Speichern / Laden ----------
  save() { localStorage.setItem("hm_save", JSON.stringify(this.state)); },
  load() {
    const raw = localStorage.getItem("hm_save");
    if (!raw) return false;
    this.state = JSON.parse(raw);
    // Migration älterer Spielstände
    const st = this.state;
    st.network = st.network ?? 10;
    st.marketHistory = st.marketHistory || [];
    st.eventCd = st.eventCd || {};
    st.followups = st.followups || [];
    st.usedTitles = st.usedTitles || [];
    st.strikeMonths = st.strikeMonths || 0;
    st.strikeExempt = st.strikeExempt || false;
    for (const c of st.clients) {
      c.exhaustion = c.exhaustion ?? 0;
      c.perks = c.perks || [];
      c.years = c.years || 5;
      c.contractEnd = c.contractEnd ?? this.mi() + 36;
      c.films = c.films || [];
      c.flags = c.flags || {};
      c.talentBonus = c.talentBonus || 0;
      c.campaign = c.campaign || 0;
      c.awards = c.awards || 0;
    }
    return true;
  },
  hasSave() { return !!localStorage.getItem("hm_save"); },
};

window.Game = Game;
window.Calc = Calc;
window.PERKS = PERKS;
window.PROMISES = PROMISES;
window.CONTRACT_YEARS = CONTRACT_YEARS;
