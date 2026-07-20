// =====================================================================
// Hollywood Manager — UI / Rendering
// =====================================================================

const UI = {
  tab: "buero",
  modalQueue: [],
  negoForm: null,

  // ---------- Start ----------
  init() {
    const grid = document.getElementById("era-grid");
    grid.innerHTML = D.ERAS.map(e => `
      <div class="era-card" onclick="UI.startGame(${e.year})">
        <h3>${e.title}</h3>
        <div class="era-name">${e.name}</div>
        <p>${e.desc}</p>
      </div>`).join("");
    if (Game.hasSave()) {
      document.getElementById("load-save-row").innerHTML =
        `<button class="primary" onclick="UI.loadGame()">Gespeichertes Spiel fortsetzen</button>`;
    }
  },

  startGame(year) {
    const name = document.getElementById("agency-name-input").value.trim() || "Meine Agentur";
    Game.newGame(name, year);
    Music.start(year);
    this.enterGame();
  },

  loadGame() {
    if (Game.load()) {
      Music.start(Game.state.year);
      this.enterGame();
    }
  },

  saveGame() {
    Game.save();
    const btn = event.target;
    btn.textContent = "Gespeichert ✓";
    setTimeout(() => { btn.textContent = "Speichern"; }, 1200);
  },

  toggleMusic() {
    const on = Music.toggle();
    document.getElementById("music-btn").textContent = on ? "🔊" : "🔇";
  },

  enterGame() {
    document.getElementById("start-screen").style.display = "none";
    document.getElementById("header").style.display = "flex";
    document.getElementById("tabs").style.display = "flex";
    this.tab = "buero";
    this.render();
  },

  restart() {
    localStorage.removeItem("hm_save");
    location.reload();
  },

  // ---------- Rendering ----------
  render() {
    const st = Game.state;
    document.getElementById("hdr-agency").textContent = st.agency.name;
    document.getElementById("hdr-date").textContent = Game.dateStr();
    const cashEl = document.getElementById("hdr-cash");
    cashEl.textContent = Calc.fmtMoney(st.agency.cash);
    cashEl.className = st.agency.cash < 0 ? "neg" : "money";
    document.getElementById("hdr-rep").textContent = `${st.agency.rep}/100`;
    document.getElementById("hdr-network").textContent = `${Math.round(st.network)}/100`;
    document.getElementById("hdr-market").textContent = Math.round(st.market * 100) + " %" + (st.strikeMonths > 0 ? " ⚠" : "");
    document.getElementById("hdr-clients").textContent = st.clients.length;
    document.getElementById("btn-next").disabled = st.over;

    const tabs = [
      ["buero", "Agentur"],
      ["klienten", `Klienten${st.clients.length ? ` (${st.clients.length})` : ""}`],
      ["pool", "Talentpool"],
      ["castings", `Castings${st.castings.length ? ` <span class="badge">${st.castings.length}</span>` : ""}`],
      ["filme", "Filme"],
      ["chronik", "Chronik"],
    ];
    document.getElementById("tabs").innerHTML = tabs.map(([id, label]) =>
      `<button class="${this.tab === id ? "active" : ""}" onclick="UI.switchTab('${id}')">${label}</button>`).join("");

    document.getElementById("content").innerHTML = this["render_" + this.tab]();
    document.getElementById("sidebar").innerHTML = this.renderSidebar();
  },

  switchTab(t) { this.tab = t; this.render(); },

  miStr(mi) { return `${MONTHS_DE[mi % 12]} ${Math.floor(mi / 12)}`; },

  logEntry(l) {
    return `<div class="log-entry ${l.type}"><span class="date">${MONTHS_DE[l.m - 1]} ${l.y}</span><br>${l.text}</div>`;
  },

  bar(v, cls = "", w = 100) {
    return `<div class="bar ${cls}"><div style="width:${clamp(Math.round(v), 0, 100)}%"></div></div>`;
  },

  // Verdeckte Werte als Notenspanne (US-Schulnoten). spread = Unschärfe:
  // Talentpool 9 (Scouting-Gerücht), eigene Klienten 4 (man kennt seine Leute).
  attrGrades(actor, spread, talentOverride) {
    const at = Game.attrs(actor);
    const g = (v, key) => Calc.gradeRange(v, spread, actor.id + key);
    return `
      <div class="statline" title="Einschätzung der Branche — keine exakten Werte">Talent <b>${g(talentOverride !== undefined ? talentOverride : actor.talent, "tal")}</b> · Charisma <b>${g(at.charisma, "cha")}</b></div>
      <div class="statline">Disziplin <b>${g(at.discipline, "dis")}</b> · Leinwandpräsenz <b>${g(at.presence, "pre")}</b></div>`;
  },

  // ---------- Sidebar (Widescreen): Ticker & Pipeline ----------
  renderSidebar() {
    const st = Game.state;
    // Pipeline: Castings → Produktionen → Premieren
    let pipeline = "";
    if (st.castings.length) {
      pipeline += st.castings.map(cs => {
        const open = cs.roles.filter(r => !r.filled).length;
        return `<div class="statline">🎬 <b>„${cs.title}“</b> — Casting endet in ${cs.deadline} Mon., ${open} Rolle${open !== 1 ? "n" : ""} offen</div>`;
      }).join("");
    }
    if (st.productions.length) {
      pipeline += st.productions.map(p => {
        const mine = p.roles.filter(r => r.filled && r.filled.clientId).map(r => { const c = Game.client(r.filled.clientId); return c ? Game.clientName(c) : null; }).filter(Boolean);
        return `<div class="statline">🎥 <b>„${p.title}“</b> — Premiere in ~${p.monthsLeft} Mon.${mine.length ? " · " + mine.join(", ") : ""}</div>`;
      }).join("");
    }
    if (!pipeline) pipeline = `<div class="sub">Nichts in Arbeit. Zeit für Akquise.</div>`;

    // Fristen: Versprechen & Verträge
    const deadlines = [];
    for (const c of st.clients) {
      for (const p of c.promises) if (!p.fulfilled && !p.broken) deadlines.push({ mi: p.due, text: `📜 ${Game.clientName(c)}: ${p.label}` });
      if (c.contractEnd - Game.mi() <= 12) deadlines.push({ mi: c.contractEnd, text: `📄 Vertrag ${Game.clientName(c)} läuft aus` });
    }
    deadlines.sort((a, b) => a.mi - b.mi);

    return `
      <div class="card">
        <h3>Pipeline</h3>
        ${pipeline}
      </div>
      ${deadlines.length ? `<div class="card"><h3>Fristen</h3>${deadlines.slice(0, 6).map(d => `<div class="statline">${d.text} — <b>${this.miStr(d.mi)}</b></div>`).join("")}</div>` : ""}
      <div class="card">
        <h3>Ticker</h3>
        ${st.log.slice(0, 14).map(l => this.logEntry(l)).join("")}
      </div>`;
  },

  // ---------- Tab: Agentur ----------
  render_buero() {
    const st = Game.state;
    const infl = Calc.infl(st.year);
    const baseCost = Math.round((2200 + st.clients.length * 600) * infl);
    const perkCost = Math.round(Game.perkCosts());
    const promises = st.clients.flatMap(c => c.promises.filter(p => !p.fulfilled && !p.broken).map(p => ({ c, p })));
    const gw = Game.genreWeights();
    const gwMax = Math.max(...Object.values(gw));
    const genreRows = Object.entries(gw).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([g, v]) =>
      `<tr><td>${D.GENRES[g].de}</td><td style="width:55%">${this.bar(v / gwMax * 100, "blue")}</td></tr>`).join("");
    const studios = Game.activeStudios().map(s =>
      `<tr><td>${s.name}</td><td class="sub">${s.style === "prestige" ? "Prestige" : s.style === "indie" ? "Indie" : "Kommerziell"}</td><td style="width:40%">${this.bar(st.studioRel[s.id], st.studioRel[s.id] >= 60 ? "green" : st.studioRel[s.id] < 30 ? "red" : "")}</td><td>${st.studioRel[s.id]}</td></tr>`).join("");
    const mh = st.marketHistory.length ? st.marketHistory : [Math.round(st.market * 100)];
    const spark = mh.map(v => `<div class="${v < 90 ? "lo" : v > 110 ? "hi" : ""}" style="height:${clamp((v - 40) / 1.4, 4, 100)}%" title="${v} %"></div>`).join("");
    const monthlyIncome = st.clients.reduce((s, c) => s + (c.flags.tvIncome && c.flags.tvIncome.months > 0 ? c.flags.tvIncome.monthly : 0), 0);

    return `
      <div class="grid wide">
        <div class="card">
          <h3>${st.agency.name}</h3>
          <div class="sub">Gegründet ${st.startYear} · ${Game.dateStr()}</div>
          <table class="simple kv" style="margin-top:10px">
            <tr><td>Kapital</td><td class="${st.agency.cash < 0 ? "neg" : "money"}">${Calc.fmtMoney(st.agency.cash)}</td></tr>
            <tr><td>Ruf</td><td>${st.agency.rep}/100</td></tr>
            <tr><td>Netzwerk (Gefallen)</td><td>${Math.round(st.network)}/100</td></tr>
            <tr><td>Bürokosten / Monat</td><td>${Calc.fmtMoney(baseCost)}</td></tr>
            <tr><td>Perk-Kosten / Monat</td><td>${Calc.fmtMoney(perkCost)}</td></tr>
            ${monthlyIncome ? `<tr><td>TV-Einnahmen / Monat</td><td class="pos">${Calc.fmtMoney(monthlyIncome)}</td></tr>` : ""}
            <tr><td>Inflationsfaktor</td><td>×${infl.toFixed(1)} (Basis 1925)</td></tr>
          </table>
          <div class="statline" style="margin-top:8px">Ruf ${st.agency.rep}/100 — bestimmt, welche Stars überhaupt mit dir reden</div>
          ${this.bar(st.agency.rep)}
        </div>
        <div class="card">
          <h3>Marktlage ${Math.round(st.market * 100)} % ${st.strikeMonths > 0 ? `<span class="tag warn">Streik: noch ${st.strikeMonths} Mon.</span>` : ""}</h3>
          <div class="sub">Einspielergebnisse werden mit der Marktlage multipliziert. Letzte ${mh.length} Monate:</div>
          <div class="spark">${spark}</div>
          <table class="simple kv" style="margin-top:10px">
            <tr><td>Klienten unter Vertrag</td><td>${st.clients.length}</td></tr>
            <tr><td>Offene Rollen in Castings</td><td>${st.castings.reduce((s, cs) => s + cs.roles.filter(r => !r.filled).length, 0)}</td></tr>
            <tr><td>Filme in Produktion</td><td>${st.productions.length}</td></tr>
            <tr><td>Vermittelte Filme gesamt</td><td>${st.released.length}</td></tr>
            <tr><td>Gewonnene Awards</td><td>${st.clients.reduce((s, c) => s + (c.awards || 0), 0)} 🏆</td></tr>
          </table>
        </div>
        <div class="card">
          <h3>Studio-Beziehungen</h3>
          <div class="sub">Gute Beziehungen = bessere Passung, mehr Verhandlungsspielraum.</div>
          <table class="simple" style="margin-top:8px">${studios}</table>
        </div>
        <div class="card">
          <h3>Genre-Nachfrage ${st.year}</h3>
          <div class="sub">Was die Studios gerade suchen — verschiebt sich mit den Epochen.</div>
          <table class="simple" style="margin-top:8px">${genreRows}</table>
        </div>
        <div class="card">
          <h3>Offene Versprechen</h3>
          ${promises.length ? promises.map(({ c, p }) =>
            `<div class="statline">📜 <b>${Game.clientName(c)}</b>: ${p.label} — fällig ${this.miStr(p.due)}</div>`).join("")
            : `<div class="sub">Keine. Ein Agent ohne Versprechen ist ein Agent ohne Klienten.</div>`}
        </div>
        <div class="card">
          <h3>Jüngste Ereignisse</h3>
          ${st.log.slice(0, 6).map(l => this.logEntry(l)).join("")}
        </div>
      </div>`;
  },

  // ---------- Tab: Klienten ----------
  render_klienten() {
    const st = Game.state;
    if (!st.clients.length) return `<div class="card"><h3>Noch keine Klienten</h3><div class="sub">Geh in den Talentpool und überzeuge jemanden, dass du seine Karriere in Gold verwandelst.</div></div>`;
    return `<div class="grid wide">` + st.clients.map(c => {
      const a = ACTOR_BY_ID[c.aid];
      const busy = c.busyUntil > Game.mi();
      const phase = st.year < a.peak ? `<span class="tag ok">Aufsteigend</span>` : (c.fame < a.peakFame * 0.6 ? `<span class="tag">Verblassend</span>` : `<span class="tag warn">Zenit</span>`);
      const heatTag = c.heat >= 4 ? `<span class="tag hot">Heiß +${Math.round(c.heat)}</span>` : c.heat <= -4 ? `<span class="tag">Kalt ${Math.round(c.heat)}</span>` : `<span class="tag">Heat ${Math.round(c.heat)}</span>`;
      const films = c.films.slice(0, 3).map(f => `<div class="statline">🎞 „${f.title}“ (${f.year}) — ${f.verdict}, Q ${f.quality}</div>`).join("");
      return `
      <div class="card">
        <div class="row between">
          <h3>${a.name} ${"🏆".repeat(c.awards || 0)}</h3>
          <span class="sub">${Calc.age(a, st.year)} J. · ${phase}</span>
        </div>
        <div class="sub">${a.genres.map(g => D.GENRES[g].de).join(" · ")}${c.flags.typecast ? ` · <span class="tag warn">Typecast</span>` : ""}</div>
        ${this.attrGrades(a, 4, Math.round(Game.effTalent(c)))}
        <div class="sub" style="margin-top:2px">Vertrag: ${c.commission} % Provision · bis ${this.miStr(c.contractEnd)} · Gagen-Niveau ${Calc.fmtMoney(Calc.askFee(c.fame, st.year))}</div>
        ${c.perks.length ? `<div style="margin-top:4px">${c.perks.map(p => `<span class="tag ok" title="${PERKS[p].desc}">${PERKS[p].de}</span>`).join("")}</div>` : ""}
        <div style="margin-top:8px; display:grid; grid-template-columns: 1fr 1fr; gap: 2px 16px">
          <div><div class="statline">Ruhm ${Math.round(c.fame)}/100</div>${this.bar(c.fame)}</div>
          <div><div class="statline">Loyalität ${Math.round(c.loyalty)}/100</div>${this.bar(c.loyalty, c.loyalty < 35 ? "red" : "green")}</div>
          <div><div class="statline">Laune ${Math.round(c.mood)}/100</div>${this.bar(c.mood, c.mood < 35 ? "red" : "")}</div>
          <div><div class="statline">Erschöpfung ${Math.round(c.exhaustion)}/100</div>${this.bar(c.exhaustion, c.exhaustion > 60 ? "red" : "blue")}</div>
        </div>
        <div class="statline" style="margin-top:6px">${heatTag} ${busy ? `<span class="tag ok">Am Set bis ${this.miStr(c.busyUntil)}</span>` : `<span class="tag">Verfügbar</span>`}${c.flags.tvIncome && c.flags.tvIncome.months > 0 ? ` <span class="tag">TV-Serie: noch ${c.flags.tvIncome.months} Mon.</span>` : ""}</div>
        ${c.promises.length ? `<div style="margin-top:6px">` + c.promises.map(p =>
          `<div class="statline">${p.fulfilled ? "✅" : p.broken ? "❌" : "📜"} ${p.label}${!p.fulfilled && !p.broken ? " (bis " + this.miStr(p.due) + ")" : ""}</div>`).join("") + `</div>` : ""}
        ${films ? `<div style="margin-top:6px">${films}</div>` : ""}
      </div>`;
    }).join("") + `</div>`;
  },

  // ---------- Tab: Talentpool ----------
  poolFilter: "",
  render_pool() {
    const st = Game.state;
    const all = Game.availableActors();
    const f = this.poolFilter.toLowerCase();
    const list = (f ? all.filter(a => a.name.toLowerCase().includes(f)) : all).slice(0, 60);
    return `
      <div class="filter-bar row">
        <input type="text" placeholder="Name suchen …" value="${this.poolFilter}"
          oninput="UI.poolFilter=this.value; clearTimeout(UI._ft); UI._ft=setTimeout(()=>UI.render(),300)" style="width:260px">
        <span class="sub">${all.length} Schauspieler verfügbar in ${st.year} — sortiert nach Ruhm. Große Namen verhandeln nur mit Agenturen von Rang (Ruf!).</span>
      </div>
      <div class="grid">` + list.map(a => {
        const fame = Calc.fameAt(a, st.year);
        const age = Calc.age(a, st.year);
        const rising = st.year < a.peak;
        const ask = Calc.askFee(fame, st.year);
        const reqRep = Calc.requiredRep(fame);
        const locked = st.agency.rep < reqRep;
        return `
        <div class="card">
          <div class="row between">
            <h3>${a.name}</h3>
            <span class="sub">${age} J.</span>
          </div>
          <div class="sub">*${a.birth}${a.death ? " †" + a.death : ""} · ${a.genres.map(g => D.GENRES[g].de).join(" · ")}</div>
          <div style="margin-top:8px">
            <div class="statline">Ruhm ${fame}/100 ${rising ? `<span class="tag ok">Aufsteigend</span>` : fame < a.peakFame * 0.6 && st.year > a.peak ? `<span class="tag">Verblassend</span>` : ""}</div>
            ${this.bar(fame)}
            ${this.attrGrades(a, 9)}
            <div class="statline">Gagen-Niveau ca. ${Calc.fmtMoney(ask)}${reqRep ? ` · Anspruch: Ruf ≥ ${reqRep}` : ""}</div>
          </div>
          <div class="row" style="margin-top:10px">
            ${locked
              ? `<button disabled title="Dein Ruf (${st.agency.rep}) reicht nicht — dieser Star verhandelt erst ab Ruf ${reqRep}.">🔒 Ruf ${reqRep} nötig</button>`
              : `<button onclick="UI.openNegotiation('${a.id}')">Anwerben</button>`}
          </div>
        </div>`;
      }).join("") + `</div>`;
  },

  // ---------- Verhandlung v2: Anwerbung ----------
  openNegotiation(actorId) {
    const n = Game.startNegotiation(actorId);
    if (n.locked) {
      this.showRawModal(`<h2>Kein Termin</h2>
        <div class="quote">„${n.actor.name} lässt ausrichten: Man kennt Ihre Agentur nicht.“</div>
        <p>Stars dieses Kalibers (Ruhm ${n.fame}) verhandeln erst mit Agenturen ab <b>Ruf ${n.reqRep}</b> (aktuell: ${Game.state.agency.rep}).</p>
        <p class="hint">Baue Ruf auf: erfolgreiche Vermittlungen, gehaltene Versprechen, Hits, Awards.</p>
        <div class="actions"><button onclick="UI.closeModal()">Verstanden</button></div>`);
      return;
    }
    this.negoForm = { commission: 10, bonus: 0, years: 3, perks: [], promise: "" };
    this.renderNegotiation();
  },

  negoOffer() {
    const f = this.negoForm;
    return { commission: f.commission, bonus: f.bonus, years: f.years, perks: [...f.perks], promise: f.promise || null };
  },

  updateNegoPreview() {
    const score = Game.evaluateOffer(this.negoOffer());
    const mood = Game.moodLabel(score);
    const el = document.getElementById("ng-mood");
    if (el) el.innerHTML = `Stimmung: <b class="${mood.cls}">${mood.label}</b>`;
    const bv = document.getElementById("ng-bonus-val");
    if (bv) bv.textContent = Calc.fmtMoney(this.negoForm.bonus);
    const cv = document.getElementById("ng-comm-val");
    if (cv) cv.textContent = this.negoForm.commission + " %";
    const pc = document.getElementById("ng-perk-cost");
    if (pc) {
      const monthly = this.negoForm.perks.reduce((s, p) => s + PERKS[p].cost, 0) * Calc.infl(Game.state.year);
      pc.textContent = monthly ? `Laufende Perk-Kosten: ${Calc.fmtMoney(monthly)}/Monat` : "";
    }
  },

  negoPerkChange(key, checked) {
    const f = this.negoForm;
    if (checked && !f.perks.includes(key)) f.perks.push(key);
    if (!checked) f.perks = f.perks.filter(p => p !== key);
    this.updateNegoPreview();
  },

  renderNegotiation(hint) {
    const n = Game.nego;
    const a = n.actor;
    const f = this.negoForm;
    const st = Game.state;
    const maxBonus = Math.max(1000, Math.round(n.ask * 0.4 / 1000) * 1000);
    const step = Math.max(1000, Math.round(maxBonus / 40 / 1000) * 1000);
    const counter = n.counter;
    const counterAffordable = counter && counter.bonus <= st.agency.cash;
    const perkRows = Object.entries(PERKS).map(([k, p]) => `
      <div class="perk-row">
        <input type="checkbox" id="ng-perk-${k}" ${f.perks.includes(k) ? "checked" : ""} onchange="UI.negoPerkChange('${k}', this.checked)">
        <div><label for="ng-perk-${k}" style="display:inline; margin:0; text-transform:none; letter-spacing:0; color:var(--text); cursor:pointer">${p.de}</label>
        <span class="sub">${p.cost ? " · " + Calc.fmtMoney(p.cost * Calc.infl(st.year)) + "/Mon." : " · kostenlos"}</span>
        <div class="pdesc">${p.desc}</div></div>
      </div>`).join("");

    this.showRawModal(`
      <h2>Verhandlung: ${a.name}</h2>
      <div class="sub">Runde ${n.round}/${n.maxRounds}</div>
      ${hint ? `<div class="quote">${hint}</div>` : ""}
      <div class="modal-cols" style="margin-top:10px">
        <div>
          <label>Provision (dein Anteil an allen Gagen)</label>
          <input type="range" min="5" max="20" value="${f.commission}" style="width:100%"
            oninput="UI.negoForm.commission=parseInt(this.value); UI.updateNegoPreview()">
          <div class="sub" id="ng-comm-val">${f.commission} %</div>
          <label>Signing-Bonus (sofort fällig)</label>
          <input type="range" min="0" max="${maxBonus}" step="${step}" value="${f.bonus}" style="width:100%"
            oninput="UI.negoForm.bonus=parseInt(this.value); UI.updateNegoPreview()">
          <div class="sub" id="ng-bonus-val">${Calc.fmtMoney(f.bonus)}</div>
          <label>Vertragslaufzeit</label>
          <select style="width:100%" onchange="UI.negoForm.years=parseInt(this.value); UI.updateNegoPreview()">
            ${CONTRACT_YEARS.map(y => `<option value="${y}" ${f.years === y ? "selected" : ""}>${y} Jahre</option>`).join("")}
          </select>
          <label>Versprechen (wird protokolliert — halte es, oder es wird teuer)</label>
          <select style="width:100%" onchange="UI.negoForm.promise=this.value; UI.updateNegoPreview()">
            <option value="">Kein Versprechen</option>
            ${Object.entries(PROMISES).map(([k, p]) => `<option value="${k}" ${f.promise === k ? "selected" : ""}>${p.label}</option>`).join("")}
          </select>
        </div>
        <div>
          <table class="simple kv">
            <tr><td>Ruhm</td><td>${n.fame}/100</td></tr>
            <tr><td>Talent</td><td>${Calc.gradeRange(a.talent, 6, a.id + "tal")}</td></tr>
            <tr><td>Charisma</td><td>${Calc.gradeRange(Game.attrs(a).charisma, 6, a.id + "cha")}</td></tr>
            <tr><td>Disziplin</td><td>${Calc.gradeRange(Game.attrs(a).discipline, 6, a.id + "dis")}</td></tr>
            <tr><td>Leinwandpräsenz</td><td>${Calc.gradeRange(Game.attrs(a).presence, 6, a.id + "pre")}</td></tr>
            <tr><td>Alter</td><td>${Calc.age(a, st.year)} Jahre</td></tr>
            <tr><td>Gagen-Niveau</td><td>${Calc.fmtMoney(n.ask)}</td></tr>
            <tr><td>Karrierephase</td><td>${st.year < a.peak ? "Aufsteigend ↑" : "Nach dem Zenit ↓"}</td></tr>
            <tr><td>Genres</td><td>${a.genres.map(g => D.GENRES[g].de).join(", ")}</td></tr>
          </table>
          <label>Zusatzleistungen (Perks)</label>
          ${perkRows}
          <div class="sub" id="ng-perk-cost"></div>
        </div>
      </div>
      ${counter ? `
      <div class="counter-box">
        <h4>Gegenvorschlag von ${a.name}</h4>
        <div class="quote" style="margin:6px 0">${counter.text}</div>
        <div class="sub">Bedeutet: ${counter.commission} % Provision · Bonus ${Calc.fmtMoney(counter.bonus)} · ${counter.years} Jahre · ${counter.perks.length ? counter.perks.map(p => PERKS[p].de).join(", ") : "keine Perks"}${counter.promise ? " · Versprechen: " + PROMISES[counter.promise].label : ""}</div>
        <div class="actions" style="margin-top:10px">
          <button class="primary" ${counterAffordable ? "" : "disabled title='Bonus übersteigt deine Kasse'"} onclick="UI.doAcceptCounter()">Gegenvorschlag annehmen${counterAffordable ? "" : " (zu teuer)"}</button>
        </div>
      </div>` : ""}
      <div class="hint" id="ng-mood" style="margin-top:14px"></div>
      <div class="actions">
        <button class="primary" onclick="UI.submitOffer()">Eigenes Angebot machen</button>
        <button onclick="UI.closeModal()">Abbrechen</button>
      </div>`);
    this.updateNegoPreview();
  },

  doAcceptCounter() {
    const res = Game.acceptCounter();
    if (res.broke) return;
    this.showSignedModal(Game.nego.counter);
  },

  showSignedModal(terms) {
    const a = Game.nego.actor;
    this.showRawModal(`<h2>Vertrag unterschrieben!</h2>
      <div class="quote">„Also gut. Machen Sie mich unsterblich.“</div>
      <p><b>${a.name}</b> ist jetzt Klient von ${Game.state.agency.name} — ${terms.commission} % Provision, ${terms.years} Jahre${terms.bonus ? `, ${Calc.fmtMoney(terms.bonus)} Bonus` : ""}${terms.perks && terms.perks.length ? `, Perks: ${terms.perks.map(p => PERKS[p].de).join(", ")}` : ""}.</p>
      ${terms.promise ? `<p class="hint">📜 Dein Versprechen (${PROMISES[terms.promise].label}) wurde protokolliert. In dieser Stadt ist das Wort eines Agenten alles.</p>` : ""}
      <div class="actions"><button class="primary" onclick="UI.closeModal()">Ausgezeichnet</button></div>`);
  },

  submitOffer() {
    const offer = this.negoOffer();
    const res = Game.makeOffer(offer);
    if (res.broke) {
      this.showRawModal(`<h2>Zu wenig Kapital</h2><p>Der Signing-Bonus übersteigt deine Kasse.</p>
        <div class="actions"><button class="primary" onclick="UI.renderNegotiation()">Zurück</button></div>`);
      return;
    }
    if (res.accepted) {
      this.showSignedModal(offer);
    } else if (res.final) {
      this.showRawModal(`<h2>Abgelehnt</h2>
        <div class="quote">${res.hint}</div>
        <p>${Game.nego.actor.name} hat genug gehört. Vielleicht nächstes Jahr — mit besserem Ruf.</p>
        <div class="actions"><button onclick="UI.closeModal()">Schade</button></div>`);
    } else {
      this.renderNegotiation(res.hint);
    }
  },

  // ---------- Tab: Castings ----------
  render_castings() {
    const st = Game.state;
    if (st.strikeMonths > 0) return `<div class="card"><h3>Streik!</h3><div class="sub">Für ${st.strikeMonths} weitere Monate ruhen alle Castings.</div></div>`;
    if (!st.castings.length) return `<div class="card"><h3>Keine offenen Castings</h3><div class="sub">Nächsten Monat schreiben die Studios neue Projekte aus.</div></div>`;
    return `<div class="grid wide">` + st.castings.map(cs => {
      const studio = D.STUDIOS.find(s => s.id === cs.studioId);
      const stars = "★".repeat(cs.prestige) + "☆".repeat(3 - cs.prestige);
      return `
      <div class="card">
        <h3>„${cs.title}“</h3>
        <div class="sub">${studio.name} · ${D.GENRES[cs.genre].de} · Prestige ${stars} · Budget ${Calc.fmtMoney(cs.budget)}</div>
        <div class="sub">Casting endet in ${cs.deadline} Monat${cs.deadline > 1 ? "en" : ""} · Studio-Beziehung ${st.studioRel[cs.studioId]}/100</div>
        <table class="simple" style="margin-top:8px">
          ${cs.roles.map((r, i) => {
            let status;
            if (r.filled && r.filled.clientId) {
              const cl = Game.client(r.filled.clientId);
              status = `<span class="pos">${cl ? Game.clientName(cl) : "?"} (${Calc.fmtMoney(r.filled.fee)})</span>`;
            } else if (r.filled) {
              status = `<span class="sub">${r.filled.name}</span>`;
            } else {
              status = `<button onclick="UI.openPitch(${cs.id},${i})">Klient pitchen</button>`;
            }
            return `<tr>
              <td>${r.type === "lead" ? "<b>Hauptrolle</b>" : "Nebenrolle"} (${r.gender === "m" ? "♂" : "♀"}, ${r.ageMin}–${r.ageMax} J.)</td>
              <td class="sub">ab Ruhm ${r.minFame} · ca. ${Calc.fmtMoney(r.fee)}</td>
              <td>${status}</td>
            </tr>`;
          }).join("")}
        </table>
      </div>`;
    }).join("") + `</div>`;
  },

  openPitch(castingId, roleIdx) {
    const cs = Game.state.castings.find(x => x.id === castingId);
    const role = cs.roles[roleIdx];
    const options = Game.eligibleClients(cs, role).filter(e => !(role.rejected || []).includes(e.c.id));
    if (!options.length) {
      this.showRawModal(`<h2>Niemand passt</h2><p>Kein verfügbarer Klient passt auf diese Rolle (${role.gender === "m" ? "männlich" : "weiblich"}, ${role.ageMin}–${role.ageMax} Jahre)${(role.rejected || []).length ? " — oder wurde bereits abgelehnt" : ""}. Klienten mit Drehbuch-Mitsprache lehnen Rollen mit Passung unter 35 ab.</p>
        <div class="actions"><button onclick="UI.closeModal()">Zurück</button></div>`);
      return;
    }
    this.showRawModal(`
      <h2>Pitch: „${cs.title}“</h2>
      <div class="sub">${role.type === "lead" ? "Hauptrolle" : "Nebenrolle"} · ab Ruhm ${role.minFame} · Basis-Gage ca. ${Calc.fmtMoney(role.fee)}</div>
      <table class="simple" style="margin-top:12px">
        <tr><th>Klient</th><th>Passung</th><th>Erwartete Gage</th><th>Erschöpfung</th><th></th></tr>
        ${options.map(e => `<tr>
          <td>${Game.clientName(e.c)}${"🏆".repeat(e.c.awards || 0)}</td>
          <td>${e.fit} %<div class="bar ${e.fit >= 60 ? "green" : e.fit < 35 ? "red" : ""}" style="width:80px"><div style="width:${e.fit}%"></div></div></td>
          <td>${Calc.fmtMoney(e.estFee)}</td>
          <td class="${e.c.exhaustion > 60 ? "neg" : "sub"}">${Math.round(e.c.exhaustion)}</td>
          <td><button onclick="UI.doPitch(${castingId},${roleIdx},${e.c.id})">Vorschlagen</button></td>
        </tr>`).join("")}
      </table>
      <div class="hint">Passung = Genre-Fit + Ruhm vs. Anforderung + Heat + Studio-Beziehung − Erschöpfung. Ein abgelehnter Pitch kostet etwas Studio-Beziehung.</div>
      <div class="actions"><button onclick="UI.closeModal()">Abbrechen</button></div>`);
  },

  doPitch(castingId, roleIdx, clientId) {
    const res = Game.submitPitch(castingId, roleIdx, clientId);
    if (!res.success) {
      this.showRawModal(`<h2>Absage</h2>
        <div class="quote">„Wir hatten uns die Rolle … anders vorgestellt. Danke für Ihre Zeit.“</div>
        <div class="actions"><button onclick="UI.closeModal()">Weiter</button></div>`);
      return;
    }
    this.renderStudioOffer();
  },

  renderStudioOffer(note) {
    const ctx = Game.pitchCtx;
    const name = Game.clientName(ctx.client);
    const pkg = Game.packageOptions();
    this.showRawModal(`
      <h2>Angebot des Studios</h2>
      ${note ? `<div class="quote">${note}</div>` : ""}
      <p>Das Studio will <b>${name}</b> für „${ctx.casting.title}“ — Gage: <b class="money">${Calc.fmtMoney(ctx.fee)}</b>
      (deine Provision: ${Calc.fmtMoney(ctx.fee * ctx.client.commission / 100)}).</p>
      <div class="actions">
        <button class="primary" onclick="Game.acceptOffer(); UI.closeModal()">Annehmen</button>
        ${!ctx.haggled ? `<button onclick="UI.doHaggle()">+25 % fordern</button>` : ""}
        ${pkg.length ? `<button onclick="UI.renderPackage()">Package-Deal …</button>` : ""}
        <button class="danger" onclick="Game.pitchCtx=null; UI.closeModal()">Absagen</button>
      </div>
      ${pkg.length ? `<div class="hint">Package-Deal: Du drückst einen zweiten Klienten in eine Nebenrolle — beide Gagen +12 %. Scheitert der Versuch, kostet es Studio-Beziehung.</div>` : ""}`);
  },

  doHaggle() {
    const res = Game.haggle();
    if (res.lost) {
      this.showRawModal(`<h2>Verhandlung geplatzt</h2>
        <div class="quote">„Sagen Sie Ihrem Klienten, er soll sich einen anderen Film suchen.“</div>
        <div class="actions"><button onclick="UI.closeModal()">Autsch</button></div>`);
      return;
    }
    this.renderStudioOffer(res.success
      ? `„Also gut, also gut. ${Calc.fmtMoney(res.fee)}. Aber kein Cent mehr.“`
      : `„Nein. Das Angebot steht — nehmen Sie es oder lassen Sie es.“`);
  },

  renderPackage() {
    const ctx = Game.pitchCtx;
    const pkg = Game.packageOptions();
    this.showRawModal(`
      <h2>Package-Deal schnüren</h2>
      <p>„${ctx.casting.title}“ — Hauptdeal: ${Game.clientName(ctx.client)} (${Calc.fmtMoney(ctx.fee)}). Wähle den zweiten Klienten:</p>
      <table class="simple">
        <tr><th>Klient</th><th>Rolle</th><th>Passung</th><th></th></tr>
        ${pkg.map(o => `<tr>
          <td>${Game.clientName(o.c)}</td>
          <td>Nebenrolle (${o.role.gender === "m" ? "♂" : "♀"})</td>
          <td>${o.fit} %</td>
          <td><button onclick="UI.doPackage(${o.roleIdx},${o.c.id})">Vorschlagen</button></td>
        </tr>`).join("")}
      </table>
      <div class="actions"><button onclick="UI.renderStudioOffer()">Zurück</button></div>`);
  },

  doPackage(roleIdx, clientId) {
    const res = Game.tryPackage(roleIdx, clientId);
    if (res.success) {
      this.showRawModal(`<h2>Package-Deal perfekt!</h2>
        <div class="quote">„Zwei Ihrer Leute in einem Film? Sie werden mir langsam unheimlich.“</div>
        <p>Beide Deals sind unter Dach und Fach — mit 12 % Aufschlag.</p>
        <div class="actions"><button class="primary" onclick="UI.closeModal()">Großartig</button></div>`);
    } else {
      this.renderStudioOffer(`„Den zweiten Namen nehmen wir nicht. Aber das ursprüngliche Angebot steht noch.“`);
    }
  },

  // ---------- Tab: Filme ----------
  render_filme() {
    const st = Game.state;
    let html = "";
    if (st.productions.length) {
      html += `<h3 style="color:var(--gold); margin-bottom:8px">In Produktion</h3><div class="grid wide">` +
        st.productions.map(p => {
          const studio = D.STUDIOS.find(s => s.id === p.studioId);
          const castNames = p.roles.map(r => r.filled ? (r.filled.clientId ? `<b>${(() => { const c = Game.client(r.filled.clientId); return c ? Game.clientName(c) : "?"; })()}</b>` : r.filled.name) : "—").join(", ");
          return `<div class="card"><h3>„${p.title}“</h3>
            <div class="sub">${studio.name} · ${D.GENRES[p.genre].de} · Budget ${Calc.fmtMoney(p.budget)}${p.qualityMod ? ` · Qualitäts-Modifikator ${p.qualityMod > 0 ? "+" : ""}${p.qualityMod}` : ""}</div>
            <div class="statline">Besetzung: ${castNames}</div>
            <div class="statline">Kinostart in ca. ${p.monthsLeft} Monat${p.monthsLeft > 1 ? "en" : ""}${st.strikeMonths > 0 && !st.strikeExempt ? ` <span class="tag warn">pausiert (Streik)</span>` : ""}</div></div>`;
        }).join("") + `</div>`;
    }
    if (st.released.length) {
      html += `<h3 style="color:var(--gold); margin:16px 0 8px">Veröffentlicht</h3>
      <table class="simple">
        <tr><th>Jahr</th><th>Film</th><th>Genre</th><th>Studio</th><th>Qualität</th><th>Budget</th><th>Einspiel</th><th>Faktor</th><th>Urteil</th></tr>
        ${st.released.slice(0, 40).map(f => `<tr>
          <td>${f.year}</td><td>„${f.title}“</td><td>${D.GENRES[f.genre].de}</td>
          <td class="sub">${(D.STUDIOS.find(s => s.id === f.studioId) || {}).name || "?"}</td>
          <td>${f.quality}/100</td><td class="sub">${Calc.fmtMoney(f.budget)}</td><td>${Calc.fmtMoney(f.revenue)}</td>
          <td>×${f.ratio.toFixed(1)}</td>
          <td class="${f.ratio < 1 ? "neg" : f.ratio >= 2 ? "pos" : ""}">${f.verdict}</td>
        </tr>`).join("")}
      </table>`;
    }
    return html || `<div class="card"><h3>Noch keine Filme</h3><div class="sub">Platziere Klienten in Castings — sobald ein Film abgedreht ist, erscheint er hier.</div></div>`;
  },

  // ---------- Tab: Chronik ----------
  render_chronik() {
    return Game.state.log.map(l => this.logEntry(l)).join("") || `<div class="sub">Noch nichts passiert.</div>`;
  },

  // ---------- Modals ----------
  showRawModal(html) {
    document.getElementById("modal").innerHTML = html;
    document.getElementById("modal-overlay").style.display = "flex";
  },

  closeModal() {
    document.getElementById("modal-overlay").style.display = "none";
    if (Game.state && !Game.state.over) Game.save(); // Event-Entscheidungen sofort persistieren
    this.render();
    this.showNextQueued();
  },

  enqueue(events) {
    this.modalQueue.push(...events);
    this.showNextQueued();
  },

  showNextQueued() {
    if (document.getElementById("modal-overlay").style.display === "flex") return;
    const ev = this.modalQueue.shift();
    if (!ev) return;
    const choiceBtns = ev.choices.map((ch, i) =>
      `<button class="${i === 0 ? "primary" : ""}" onclick="UI.resolveChoice(${i})">${ch.label}</button>`).join("");
    this._currentEvent = ev;
    this.showRawModal(`<h2>${ev.title}</h2>${ev.html}<div class="actions">${choiceBtns}</div>`);
  },

  resolveChoice(i) {
    const ch = this._currentEvent.choices[i];
    if (ch.action === "restart") { this.restart(); return; }
    this._currentEvent = null;
    if (ch.fn) {
      const outcome = ch.fn();
      if (outcome) {
        this.showRawModal(`<h2>…</h2><p>${outcome}</p><div class="actions"><button class="primary" onclick="UI.closeModal()">Weiter</button></div>`);
        return;
      }
    }
    this.closeModal();
  },
};

// Monatswechsel: Game.endMonth liefert Event-Modals
const _origEnd = Game.endMonth.bind(Game);
Game.endMonth = function () {
  const events = _origEnd();
  UI.render();
  if (events && events.length) UI.enqueue(events);
  Game.save();
};

window.UI = UI;
UI.init();
