// =====================================================================
// Hollywood Manager — Ereignis-Katalog
// Jedes Ereignis: id, cd (Cooldown in Monaten), weight(G) -> 0 = feuert
// nicht (Bedingungen!), build(G) -> Modal mit Entscheidungen.
// Designregel: Jedes Ereignis hat mindestens eine Option ohne harten,
// unvermeidbaren Schaden — Risiko entsteht nur durch bewusste Wahl.
// =====================================================================

(function () {
  const G = () => window.Game;
  const fmt = v => Calc.fmtMoney(v);
  const name = c => ACTOR_BY_ID[c.aid].name;

  // Klient in laufender Produktion (für Set-Ereignisse)
  function inProduction(g) {
    const hits = [];
    for (const prod of g.state.productions) {
      for (const r of prod.roles) {
        if (r.filled && r.filled.clientId) {
          const c = g.client(r.filled.clientId);
          if (c) hits.push({ c, prod, role: r });
        }
      }
    }
    return hits.length ? pick(hits) : null;
  }

  const free = g => g.state.clients.filter(c => g.availableClient(c));

  window.HM_EVENTS = [

    // ── 0. Der Anruf um drei Uhr morgens ─────────────────────────────
    {
      id: "call3am", cd: 10,
      weight: g => free(g).some(c => c.fame >= 30) ? 1.2 : 0,
      build(g) {
        const c = pick(free(g).filter(x => x.fame >= 30));
        const studio = pick(g.activeStudios());
        const fee = Math.round(Calc.askFee(c.fame, g.state.year) * 1.1);
        return {
          title: "Der Anruf um drei Uhr morgens",
          html: `<div class="quote">„Unser Hauptdarsteller liegt im Krankenhaus. Drehbeginn ist übermorgen. Kann ${name(c)} einspringen? Ja oder nein — jetzt.“</div>
                 <p>${studio.name} bietet eine Hauptrolle. Gage: ca. ${fmt(fee)}. Aber: keine Vorbereitung, sofortiger Drehbeginn.</p>`,
          choices: [
            { label: "Sofort zusagen", fn: () => {
              const r = g.quickProduction(c, { studio, feeMult: 1.1 });
              c.exhaustion = clamp(c.exhaustion + 30, 0, 100);
              c.heat = clamp(c.heat + 4, -10, 10);
              if (chance(0.7)) { c.fame = clamp(c.fame + 3, 5, 100); return `${name(c)} steht 36 Stunden später vor der Kamera. Die Branche redet über diesen Einsatz. (+${fmt(r.income)} Provision, Erschöpfung steigt stark)`; }
              c.mood = clamp(c.mood - 6, 0, 100);
              return `${name(c)} springt ein, wirkt aber sichtlich unvorbereitet. Das Geld stimmt (${fmt(r.income)} Provision), der Glanz weniger.`;
            }},
            { label: "Höhere Gage verlangen", fn: () => {
              if (chance(0.55)) {
                const r = g.quickProduction(c, { studio, feeMult: 1.6 });
                c.exhaustion = clamp(c.exhaustion + 30, 0, 100);
                c.heat = clamp(c.heat + 5, -10, 10);
                c.fame = clamp(c.fame + 3, 5, 100);
                return `„In Ordnung, verdammt. Aber der Wagen steht in einer Stunde vor der Tür.“ — ${fmt(r.fee)} Gage, ${fmt(r.income)} Provision. Ein Coup.`;
              }
              g.state.studioRel[studio.id] = clamp(g.state.studioRel[studio.id] - 2, 0, 100);
              return `Schweigen am anderen Ende. Dann: „Wir haben jemand anderen.“ Die Chance ist vertan.`;
            }},
            { label: "Ablehnen", fn: () => {
              g.state.studioRel[studio.id] = clamp(g.state.studioRel[studio.id] - 4, 0, 100);
              c.mood = clamp(c.mood + 4, 0, 100);
              return `${name(c)} schläft weiter. ${studio.name} vergisst so etwas nicht — aber dein Klient weiß, dass du ihn nicht verheizt.`;
            }},
          ],
        };
      },
    },

    // ── 1. Das geleakte Vorsprechen ──────────────────────────────────
    {
      id: "leak", cd: 9,
      weight: g => g.state.clients.length ? 1 : 0,
      build(g) {
        const c = g.randomClient();
        const cost = Math.round(12000 * Calc.infl(g.state.year));
        const hasPR = c.perks.includes("pr");
        return {
          title: "Das geleakte Vorsprechen",
          html: `<div class="quote">„Haben Sie das Band gesehen? Ganz Hollywood lacht.“</div>
                 <p>Eine peinliche Aufnahme vom Vorsprechen von ${name(c)} kursiert in der Branche.${hasPR ? " Deine PR-Betreuung dämpft den Schaden bereits." : ""}</p>`,
          choices: [
            { label: `Juristisch vorgehen (${fmt(cost)})`, fn: () => {
              g.state.agency.cash -= cost;
              c.mood = clamp(c.mood + 5, 0, 100);
              return `Die Anwälte kassieren jede Kopie ein. Teuer, aber das Image ist geschützt — und ${name(c)} weiß das zu schätzen.`;
            }},
            { label: "Selbstironisch veröffentlichen", fn: () => {
              if (chance(hasPR ? 0.75 : 0.55)) { c.heat = clamp(c.heat + 4, -10, 10); c.fame = clamp(c.fame + 2, 5, 100); return `Der Gag zündet: ${name(c)} gilt plötzlich als nahbar und humorvoll. Die Stadt liebt es.`; }
              c.fame = clamp(c.fame - (hasPR ? 1 : 3), 5, 100);
              return `Der Humor kommt nicht überall an. Ein paar Spötter bleiben — halb so wild, aber unschön.`;
            }},
            { label: "Ignorieren", fn: () => {
              if (chance(hasPR ? 0.85 : 0.65)) return `Nach zwei Wochen redet niemand mehr darüber. Richtig gepokert.`;
              c.heat = clamp(c.heat - 2, -10, 10);
              return `Das Band hält sich hartnäckiger als gedacht. ${name(c)} verliert etwas Momentum.`;
            }},
          ],
        };
      },
    },

    // ── 2. Ein neuer Name für einen neuen Star ───────────────────────
    {
      id: "rename", cd: 14,
      weight: g => {
        const cand = g.state.clients.filter(c => c.fame < 50);
        return cand.length ? (g.state.year < 1970 ? 1.2 : 0.5) : 0;
      },
      build(g) {
        const c = g.randomClient(x => x.fame < 50);
        const cost = Math.round(8000 * Calc.infl(g.state.year));
        return {
          title: "Ein neuer Name für einen neuen Star",
          html: `<div class="quote">„${name(c)}? Das kann doch kein Mensch aussprechen. Wir dachten an etwas … Verkäuflicheres.“</div>
                 <p>Das Studio hält den Namen deines Klienten für schwer vermarktbar.</p>`,
          choices: [
            { label: "Umbenennung akzeptieren", fn: () => {
              c.fame = clamp(c.fame + 4, 5, 100);
              c.mood = clamp(c.mood - 10, 0, 100);
              return `Der neue Name prangt bald auf Plakaten. Die Vermarktung greift — aber ${name(c)} fühlt sich wie eine Ware.`;
            }},
            { label: "Den Namen verteidigen", fn: () => {
              c.loyalty = clamp(c.loyalty + 10, 0, 100);
              g.state.agency.rep = clamp(g.state.agency.rep + 2, 0, 100);
              const s = pick(g.activeStudios());
              g.state.studioRel[s.id] = clamp(g.state.studioRel[s.id] - 4, 0, 100);
              return `„Der Name bleibt.“ ${name(c)} wird dir das nie vergessen — das Studio schon eher.`;
            }},
            { label: `Kompromiss: Künstlername (${fmt(cost)} PR)`, fn: () => {
              g.state.agency.cash -= cost;
              c.fame = clamp(c.fame + 2, 5, 100);
              c.mood = clamp(c.mood - 3, 0, 100);
              return `Ein Künstlername für die Plakate, der echte Name für die Freunde. Alle können damit leben.`;
            }},
          ],
        };
      },
    },

    // ── 3. Der Regisseur will deinen Klienten loswerden ──────────────
    {
      id: "director", cd: 10,
      weight: g => inProduction(g) ? 1 : 0,
      build(g) {
        const hit = inProduction(g);
        const { c, prod } = hit;
        const fee = hit.role.filled.fee || 100000;
        return {
          title: "Der Regisseur will deinen Klienten loswerden",
          html: `<div class="quote">„Entweder ${name(c)} verlässt mein Set, oder ich.“</div>
                 <p>Nach einem heftigen Streit bei „${prod.title}“ fordert der Regisseur eine Neubesetzung.</p>`,
          choices: [
            { label: "Klienten öffentlich verteidigen", fn: () => {
              c.loyalty = clamp(c.loyalty + 12, 0, 100);
              g.state.studioRel[prod.studioId] = clamp(g.state.studioRel[prod.studioId] - 6, 0, 100);
              prod.qualityMod = (prod.qualityMod || 0) - 3;
              return `Du stellst dich vor die Presse und hinter deinen Klienten. ${name(c)} bleibt — die Stimmung am Set bleibt frostig.`;
            }},
            { label: "Hinter verschlossenen Türen vermitteln", fn: () => {
              const p = clamp(0.35 + g.state.agency.rep / 200 + g.state.network / 150, 0.2, 0.9);
              if (chance(p)) { c.loyalty = clamp(c.loyalty + 5, 0, 100); prod.qualityMod = (prod.qualityMod || 0) + 3; g.state.network = clamp(g.state.network + 2, 0, 100); return `Zwei Stunden, eine Flasche Whiskey, ein Handschlag. Der Dreh geht weiter — besser als zuvor.`; }
              c.mood = clamp(c.mood - 5, 0, 100);
              return `Der Waffenstillstand hält, aber die Atmosphäre bleibt vergiftet. Immerhin: Der Film wird fertig.`;
            }},
            { label: "Vertragsauflösung zustimmen", fn: () => {
              const sev = Math.round(fee * 0.5);
              g.state.agency.cash += Math.round(sev * c.commission / 100);
              c.fame = clamp(c.fame - 4, 5, 100);
              c.busyUntil = g.mi();
              c.mood = clamp(c.mood - 8, 0, 100);
              for (const r of prod.roles) if (r.filled && r.filled.clientId === c.id) r.filled = { npc: true, name: "Ersatzbesetzung", talent: 55, fame: 30 };
              return `Abfindung: ${fmt(sev)} (deine Provision: ${fmt(sev * c.commission / 100)}). ${name(c)} ist wieder frei — aber die Branche registriert den Rauswurf.`;
            }},
          ],
        };
      },
    },

    // ── 4. Die Abwerbung ─────────────────────────────────────────────
    {
      id: "poach", cd: 10,
      weight: g => g.state.clients.length ? (g.state.clients.some(c => c.loyalty < 70) ? 1.2 : 0.4) : 0,
      build(g) {
        const c = [...g.state.clients].sort((a, b) => b.fame - a.fame)[0];
        const cost = Math.round(c.fame * 900 * Calc.infl(g.state.year));
        return {
          title: "Die Abwerbung",
          html: `<div class="quote">„Bei uns wären Sie kein Klient. Sie wären DER Klient.“</div>
                 <p>Eine große Konkurrenz-Agentur umgarnt deinen wertvollsten Namen: <b>${name(c)}</b> (Loyalität ${Math.round(c.loyalty)}/100).</p>`,
          choices: [
            { label: `Finanziell übertreffen (${fmt(cost)})`, fn: () => {
              g.state.agency.cash -= cost;
              c.loyalty = clamp(c.loyalty + 15, 0, 100);
              c.mood = clamp(c.mood + 5, 0, 100);
              return `Ein besseres Auto, eine bessere Suite, ein besserer Vertrag. ${name(c)} bleibt — Loyalität kann man mieten.`;
            }},
            { label: "Mit Erfolgen und Loyalität argumentieren", fn: () => {
              const wins = c.films.filter(f => f.verdict === "Hit" || f.verdict === "Blockbuster").length;
              const p = clamp(c.loyalty / 100 + wins * 0.08 + g.state.agency.rep / 300, 0.2, 0.95);
              if (chance(p)) { c.loyalty = clamp(c.loyalty + 8, 0, 100); return `„Ich weiß, wem ich meine Karriere verdanke.“ ${name(c)} sagt ab — aus Überzeugung.`; }
              g.state.clients = g.state.clients.filter(x => x.id !== c.id);
              g.state.agency.rep = clamp(g.state.agency.rep - 4, 0, 100);
              g.log(`${name(c)} wechselt zur Konkurrenz.`, "bad");
              return `Die Argumente reichen nicht. ${name(c)} unterschreibt woanders — ein schwerer Schlag.`;
            }},
            { label: "Ziehen lassen", fn: () => {
              g.state.clients = g.state.clients.filter(x => x.id !== c.id);
              g.state.agency.rep = clamp(g.state.agency.rep - 3, 0, 100);
              g.log(`${name(c)} verlässt die Agentur Richtung Konkurrenz.`, "info");
              return `Kein Bieterkrieg. Man trennt sich höflich — der Ruf leidet ein wenig, die Kasse nicht.`;
            }},
          ],
        };
      },
    },

    // ── 5. Zwei Klienten, eine Rolle ─────────────────────────────────
    {
      id: "tworoles", cd: 12,
      weight: g => {
        const f = free(g);
        const m = f.filter(c => ACTOR_BY_ID[c.aid].g === "m"), w = f.filter(c => ACTOR_BY_ID[c.aid].g === "f");
        return (m.length >= 2 || w.length >= 2) ? 0.9 : 0;
      },
      build(g) {
        const f = free(g);
        const m = f.filter(c => ACTOR_BY_ID[c.aid].g === "m"), w = f.filter(c => ACTOR_BY_ID[c.aid].g === "f");
        const duo = (m.length >= 2 ? m : w).sort((a, b) => b.fame - a.fame);
        const star = duo[0], up = duo[duo.length - 1];
        return {
          title: "Zwei Klienten, eine Rolle",
          html: `<p>Ein Studio sucht die Hauptrolle für einen großen Film — und sowohl <b>${name(star)}</b> (Ruhm ${Math.round(star.fame)}) als auch <b>${name(up)}</b> (Ruhm ${Math.round(up.fame)}) sind im Gespräch. Beide erwarten deine volle Unterstützung.</p>`,
          choices: [
            { label: `${name(star)} unterstützen (sicher)`, fn: () => {
              const r = g.quickProduction(star, {});
              up.loyalty = clamp(up.loyalty - 8, 0, 100);
              up.mood = clamp(up.mood - 8, 0, 100);
              return `${name(star)} bekommt die Rolle (${fmt(r.income)} Provision). ${name(up)} lächelt beim nächsten Treffen etwas dünner.`;
            }},
            { label: `${name(up)} fördern (riskant)`, fn: () => {
              star.mood = clamp(star.mood - 6, 0, 100);
              if (chance(0.6)) {
                const r = g.quickProduction(up, {});
                up.fame = clamp(up.fame + 5, 5, 100);
                up.loyalty = clamp(up.loyalty + 14, 0, 100);
                return `Du kämpfst für den Nachwuchs — und gewinnst. ${name(up)} bekommt die Rolle (${fmt(r.income)} Provision) und wird dir das nie vergessen.`;
              }
              up.loyalty = clamp(up.loyalty + 6, 0, 100);
              return `Das Studio besetzt am Ende extern. Kein Deal — aber ${name(up)} hat gesehen, dass du an ihn glaubst.`;
            }},
            { label: "Neutral bleiben", fn: () => {
              star.mood = clamp(star.mood - 4, 0, 100);
              up.mood = clamp(up.mood - 4, 0, 100);
              return `Du hältst dich raus, das Studio entscheidet extern. Fair — aber beide hätten sich mehr Einsatz gewünscht.`;
            }},
          ],
        };
      },
    },

    // ── 6. Die Rolle wurde herausgeschnitten ─────────────────────────
    {
      id: "cutrole", cd: 12,
      weight: g => inProduction(g) ? 0.8 : 0,
      build(g) {
        const { c, prod, role } = inProduction(g);
        const fee = role.filled.fee || 100000;
        return {
          title: "Die Rolle wurde herausgeschnitten",
          html: `<p>Nach einer desaströsen Testvorführung von „${prod.title}“ fällt fast die gesamte Rolle von ${name(c)} der Schere zum Opfer.</p>`,
          choices: [
            { label: "Nachdrehs verlangen", fn: () => {
              const p = clamp(c.fame / 120 + (c.awards || 0) * 0.1 + g.state.studioRel[prod.studioId] / 250, 0.15, 0.85);
              if (chance(p)) { prod.qualityMod = (prod.qualityMod || 0) + 4; prod.monthsLeft += 1; return `Das Studio knickt ein: Nachdrehs werden angesetzt. Die Rolle bleibt — der Film wird sogar besser.`; }
              c.mood = clamp(c.mood - 5, 0, 100);
              return `„Der Schnitt steht.“ Immerhin hast du es versucht — ${name(c)} weiß das.`;
            }},
            { label: "Zusätzliche Vergütung aushandeln", fn: () => {
              const extra = Math.round(fee * 0.3);
              g.state.agency.cash += Math.round(extra * c.commission / 100);
              c.mood = clamp(c.mood - 3, 0, 100);
              return `Geld statt Sichtbarkeit: ${fmt(extra)} Nachschlag (${fmt(extra * c.commission / 100)} Provision). Kein Ruhm, aber Ruhe.`;
            }},
            { label: "Den Konflikt öffentlich machen", fn: () => {
              c.heat = clamp(c.heat + 3, -10, 10);
              g.state.studioRel[prod.studioId] = clamp(g.state.studioRel[prod.studioId] - 8, 0, 100);
              return `„Studio verstümmelt Film!“ — Die Presse liebt den Streit, ${name(c)} ist Stadtgespräch. Das Studio tobt.`;
            }},
          ],
        };
      },
    },

    // ── 7. Der gefährliche Stunt ─────────────────────────────────────
    {
      id: "stunt", cd: 10,
      weight: g => {
        const hit = inProduction(g);
        return hit && ["action", "adventure", "western", "thriller"].includes(hit.prod.genre) ? 1 : (hit ? 0.3 : 0);
      },
      build(g) {
        const { c, prod } = inProduction(g);
        return {
          title: "Der gefährliche Stunt",
          html: `<div class="quote">„Das Publikum merkt den Unterschied. Wir wollen, dass ${name(c)} selbst springt.“</div>
                 <p>Die Produktion von „${prod.title}“ verlangt einen riskanten Stunt ohne Double.</p>`,
          choices: [
            { label: "Zustimmen", fn: () => {
              if (chance(0.7)) { c.heat = clamp(c.heat + 3, -10, 10); c.fame = clamp(c.fame + 2, 5, 100); prod.qualityMod = (prod.qualityMod || 0) + 2; return `Der Stunt sitzt beim ersten Take. Die Set-Fotos gehen um die Welt.`; }
              c.exhaustion = clamp(c.exhaustion + 25, 0, 100);
              prod.monthsLeft += 1;
              return `Der Sprung geht schief — Prellungen, Drehpause, Schrecken. ${name(c)} erholt sich, aber der Plan wackelt.`;
            }},
            { label: "Stuntdouble verlangen", fn: () => {
              g.state.studioRel[prod.studioId] = clamp(g.state.studioRel[prod.studioId] - 2, 0, 100);
              return `Das Double übernimmt. Der Regisseur murrt, dein Klient bleibt heil. Genau dafür wirst du bezahlt.`;
            }},
            { label: "Gefahrenzulage & Versicherung aushandeln", fn: () => {
              const extra = Math.round(Calc.askFee(c.fame, g.state.year) * 0.2);
              g.state.agency.cash += Math.round(extra * c.commission / 100);
              c.exhaustion = clamp(c.exhaustion + 10, 0, 100);
              g.state.network = clamp(g.state.network - 2, 0, 100);
              return `${name(c)} springt — gegen ${fmt(extra)} Zulage und eine Versicherung, die jeden Knochen einzeln abdeckt.`;
            }},
          ],
        };
      },
    },

    // ── 8. Die Franchise-Falle ───────────────────────────────────────
    {
      id: "franchise", cd: 18,
      weight: g => {
        const cand = free(g).filter(c => c.fame >= 55 && !c.flags.typecast);
        return cand.length ? (g.state.year >= 1977 ? 1.1 : 0.5) : 0;
      },
      build(g) {
        const c = pick(free(g).filter(x => x.fame >= 55 && !x.flags.typecast));
        const fee = Math.round(Calc.askFee(c.fame, g.state.year) * 2);
        return {
          title: "Die Franchise-Falle",
          html: `<div class="quote">„Fünf Filme. Eine Figur. Ihr Klient wird unsterblich — als genau diese eine Rolle.“</div>
                 <p>Ein Studio bietet ${name(c)} einen Vertrag über fünf Fortsetzungen. Vorab-Garantie: ${fmt(fee)}.</p>`,
          choices: [
            { label: "Sofort unterschreiben", fn: () => {
              g.state.agency.cash += Math.round(fee * c.commission / 100);
              c.fame = clamp(c.fame + 6, 5, 100);
              c.heat = clamp(c.heat + 4, -10, 10);
              c.flags.typecast = true;
              c.busyUntil = g.mi() + 4;
              return `Unterschrift, Scheck, Schlagzeile: ${fmt(fee * c.commission / 100)} Provision sofort. Aber von nun an sehen alle nur noch die eine Figur (Typecasting).`;
            }},
            { label: "Weniger Filme, höhere Gage fordern", fn: () => {
              if (chance(0.5)) {
                const f2 = Math.round(fee * 0.75);
                g.state.agency.cash += Math.round(f2 * c.commission / 100);
                c.fame = clamp(c.fame + 5, 5, 100);
                c.heat = clamp(c.heat + 3, -10, 10);
                c.busyUntil = g.mi() + 4;
                return `Drei Filme statt fünf, dafür fürstlich bezahlt: ${fmt(f2)} (${fmt(f2 * c.commission / 100)} Provision) — ohne Typecasting-Klausel. Meisterhaft verhandelt.`;
              }
              return `Das Studio winkt ab: „Fünf oder keiner.“ Der Deal platzt — aber niemand verliert das Gesicht.`;
            }},
            { label: "Ablehnen", fn: () => {
              c.loyalty = clamp(c.loyalty + 6, 0, 100);
              g.state.agency.rep = clamp(g.state.agency.rep + 2, 0, 100);
              return `„Mein Klient ist Schauspieler, keine Actionfigur.“ Die Branche nickt anerkennend — auch wenn die Garantie-Millionen woanders landen.`;
            }},
          ],
        };
      },
    },

    // ── 9. Das Herzensprojekt ────────────────────────────────────────
    {
      id: "passion", cd: 14,
      weight: g => free(g).length ? 0.9 : 0,
      build(g) {
        const c = pick(free(g));
        const invest = Math.round(30000 * Calc.infl(g.state.year));
        return {
          title: "Das Herzensprojekt",
          html: `<div class="quote">„Es zahlt fast nichts, ich weiß. Aber dieses Drehbuch — so etwas kommt einmal im Leben.“</div>
                 <p>${name(c)} will unbedingt in einem kleinen, künstlerischen Film mitspielen.</p>`,
          choices: [
            { label: "Unterstützen", fn: () => {
              g.quickProduction(c, { feeMult: 0.15, prestige: 3, genre: "drama" });
              c.loyalty = clamp(c.loyalty + 12, 0, 100);
              c.mood = clamp(c.mood + 10, 0, 100);
              return `Kaum Gage, viel Herz. ${name(c)} strahlt — und Prestige-Filme haben schon manche Karriere neu erfunden.`;
            }},
            { label: "Davon abraten", fn: () => {
              c.mood = clamp(c.mood - 8, 0, 100);
              return `„Kunst zahlt keine Provision.“ ${name(c)} fügt sich — mit hörbarem Zähneknirschen. Dafür bleibt der Kalender frei für bezahlte Arbeit.`;
            }},
            { label: `Als Agentur mitfinanzieren (${fmt(invest)})`, fn: () => {
              g.state.agency.cash -= invest;
              g.quickProduction(c, { feeMult: 0.15, prestige: 3, genre: "drama", qualityMod: 5 });
              c.loyalty = clamp(c.loyalty + 15, 0, 100);
              if (chance(0.35)) { g.state.agency.cash += invest * 4; g.state.agency.rep = clamp(g.state.agency.rep + 4, 0, 100); return `Du steigst als Produzent ein — und der Film wird ein Phänomen: ${fmt(invest * 4)} Rückfluss plus Prestige. Der Instinkt eines echten Agenten.`; }
              return `Du steigst als Produzent ein. Ob sich das rechnet, zeigt die Premiere — ${name(c)} jedenfalls ist dir treu ergeben.`;
            }},
          ],
        };
      },
    },

    // ── 11. Der Paketdeal (Ereignis-Variante) ────────────────────────
    {
      id: "packageEvent", cd: 12,
      weight: g => {
        const stars = free(g).filter(c => c.fame >= 60);
        const ups = free(g).filter(c => c.fame < 40);
        return stars.length && ups.length ? 0.9 : 0;
      },
      build(g) {
        const star = pick(free(g).filter(c => c.fame >= 60));
        const up = pick(free(g).filter(c => c.fame < 40));
        const studio = pick(g.activeStudios());
        return {
          title: "Der Paketdeal",
          html: `<p>${studio.name} will unbedingt <b>${name(star)}</b> für einen großen Film. Deine Chance, auch den unbekannten <b>${name(up)}</b> im Gepäck unterzubringen — oder mehr zu fordern.</p>`,
          choices: [
            { label: "Beide als Paket anbieten", fn: () => {
              g.state.studioRel[studio.id] = clamp(g.state.studioRel[studio.id] - 3, 0, 100);
              if (chance(0.7)) {
                const r1 = g.quickProduction(star, { studio });
                const r2 = g.quickProduction(up, { studio, roleType: "support", feeMult: 1 });
                up.fame = clamp(up.fame + 6, 5, 100);
                return `Das Studio schluckt die Kröte: beide sind besetzt (${fmt(r1.income + r2.income)} Provision gesamt). ${name(up)} bekommt die Bühne seines Lebens.`;
              }
              const r1 = g.quickProduction(star, { studio });
              return `„Den Star nehmen wir. Den Anhang nicht.“ Immerhin: ${name(star)} ist besetzt (${fmt(r1.income)} Provision).`;
            }},
            { label: "Nur den Star vermitteln", fn: () => {
              const r = g.quickProduction(star, { studio });
              return `Sauberer, sicherer Abschluss: ${fmt(r.fee)} Gage, ${fmt(r.income)} Provision. Kein Risiko, kein Bonus.`;
            }},
            { label: "Zusätzlich kreative Kontrolle fordern", fn: () => {
              if (chance(0.35)) {
                const r = g.quickProduction(star, { studio, feeMult: 1.7, qualityMod: 5 });
                g.state.agency.rep = clamp(g.state.agency.rep + 5, 0, 100);
                g.state.network = clamp(g.state.network + 3, 0, 100);
                return `Final Cut, Casting-Veto, ${fmt(r.fee)} Gage — ein Jahrhundert-Deal. Die Branche spricht mit neuem Respekt über deine Agentur.`;
              }
              g.state.studioRel[studio.id] = clamp(g.state.studioRel[studio.id] - 3, 0, 100);
              return `„Kreative Kontrolle? Für einen Agenten?“ Das Studio legt auf. Der Deal ist geplatzt — eine teure Lektion in Demut.`;
            }},
          ],
        };
      },
    },

    // ── 12. Die vorgetäuschte Romanze ────────────────────────────────
    {
      id: "romance", cd: 14,
      weight: g => g.state.clients.length ? 0.8 : 0,
      build(g) {
        const c = g.randomClient();
        return {
          title: "Die vorgetäuschte Romanze",
          html: `<div class="quote">„Zwei Stars, ein Restaurant, ein zufällig anwesender Fotograf. Die Schlagzeilen schreiben sich von selbst.“</div>
                 <p>Ein PR-Berater schlägt eine inszenierte Beziehung zwischen ${name(c)} und einem Co-Star vor.</p>`,
          choices: [
            { label: "Kampagne akzeptieren", fn: () => {
              c.heat = clamp(c.heat + 5, -10, 10);
              c.fame = clamp(c.fame + 2, 5, 100);
              if (chance(0.25)) g.state.followups.push({ type: "romanceLeak", cid: c.id, due: g.mi() + rndInt(3, 7) });
              return `Die „Beziehung“ dominiert die Klatschspalten. ${name(c)} ist überall — solange niemand nachfragt, wie echt das alles ist.`;
            }},
            { label: "Ablehnen", fn: () => {
              c.loyalty = clamp(c.loyalty + 4, 0, 100);
              return `Kein Theater. ${name(c)} schätzt, dass du das Privatleben nicht verkaufst.`;
            }},
            { label: "Vorschlag an die Presse leaken", fn: () => {
              c.heat = clamp(c.heat + 2, -10, 10);
              for (const s of g.activeStudios().slice(0, 2)) g.state.studioRel[s.id] = clamp(g.state.studioRel[s.id] - 3, 0, 100);
              return `„PR-Berater wollte Romanze faken!“ — Ein kurzer Lacher auf Kosten der Studios. Die merken sich das.`;
            }},
          ],
        };
      },
    },

    // ── 13. Fotos aus der Vergangenheit ──────────────────────────────
    {
      id: "photos", cd: 16,
      weight: g => g.state.clients.some(c => c.fame >= 40) ? 0.9 : 0,
      build(g) {
        const c = g.randomClient(x => x.fame >= 40);
        const cost = Math.round((20000 + c.fame * 400) * Calc.infl(g.state.year));
        return {
          title: "Fotos aus der Vergangenheit",
          html: `<div class="quote">„Sagen wir so: Diese Aufnahmen passen nicht zum sauberen Image Ihres Klienten. Wir dachten, Sie wollen sie zuerst sehen.“</div>
                 <p>Eine Zeitung besitzt kompromittierende alte Fotos von ${name(c)}.</p>`,
          choices: [
            { label: `Exklusivrechte kaufen (${fmt(cost)})`, fn: () => {
              g.state.agency.cash -= cost;
              c.flags.photosSecured = true;
              c.loyalty = clamp(c.loyalty + 8, 0, 100);
              return `Die Negative wandern in deinen Safe. Teuer — aber Kontrolle ist unbezahlbar.`;
            }},
            { label: "Mit ehrlichem Interview vorwegnehmen", fn: () => {
              if (chance(0.55)) { c.heat = clamp(c.heat + 3, -10, 10); c.fame = clamp(c.fame + 1, 5, 100); c.flags.photosSecured = true; return `„Ja, das war ich. Und?“ — Die Offenheit entwaffnet alle. Die Fotos sind wertlos geworden.`; }
              c.fame = clamp(c.fame - 3, 5, 100);
              c.flags.photosSecured = true;
              return `Das Interview gerät holprig, ein paar Schlagzeilen bleiben hässlich. Aber das Thema ist durch — endgültig.`;
            }},
            { label: "Gerichtliche Verfügung beantragen", fn: () => {
              const p = clamp(0.3 + g.state.agency.rep / 200 + g.state.network / 150, 0.2, 0.85);
              if (chance(p)) { c.flags.photosSecured = true; return `Der Richter untersagt die Veröffentlichung. Deine Anwälte sind die besten der Stadt — und heute haben sie es bewiesen.`; }
              g.state.followups.push({ type: "photosReturn", cid: c.id, due: g.mi() + rndInt(3, 8) });
              return `Der Antrag wird abgewiesen. Die Zeitung wartet ab — die Fotos schweben weiter wie ein Damoklesschwert.`;
            }},
          ],
        };
      },
    },

    // ── 14. Die Oscar-Kampagne (saisonal: Nov–Jan) ───────────────────
    {
      id: "oscarCampaign", cd: 10,
      weight: g => {
        if (![11, 12, 1].includes(g.state.month)) return 0;
        const cand = g.state.clients.filter(c => c.films.some(f => f.year >= g.state.year - 1 && f.lead && f.quality >= 60));
        return cand.length ? 3 : 0;
      },
      build(g) {
        const c = g.randomClient(x => x.films.some(f => f.year >= g.state.year - 1 && f.lead && f.quality >= 60));
        const cost = Math.round(50000 * Calc.infl(g.state.year));
        return {
          title: "Die Oscar-Kampagne",
          html: `<p>${name(c)} hat mit der letzten Leistung echte Chancen auf eine Nominierung — aber ohne Kampagne sieht die Academy gern woanders hin.</p>`,
          choices: [
            { label: `Große Kampagne finanzieren (${fmt(cost)})`, fn: () => {
              g.state.agency.cash -= cost;
              c.campaign = 25;
              return `Anzeigen, Screenings, Galas: Ganz Hollywood weiß jetzt, wen es zu nominieren gilt.`;
            }},
            { label: "Branchenkontakte aktivieren (−15 Netzwerk)", fn: () => {
              if (g.state.network < 15) return `Dein Netzwerk gibt das (noch) nicht her. Vielleicht reicht der Film ja für sich.`;
              g.state.network -= 15;
              c.campaign = 18;
              return `Ein paar Anrufe bei alten Freunden in der Academy. Keine Rechnung, nur offene Gefallen.`;
            }},
            { label: "Auf den Film vertrauen", fn: () => {
              c.campaign = 5;
              return `Qualität setzt sich durch — manchmal. Im Februar weißt du mehr.`;
            }},
          ],
        };
      },
    },

    // ── 15. Der Zusammenbruch ────────────────────────────────────────
    {
      id: "breakdown", cd: 8,
      weight: g => {
        const hit = inProduction(g);
        return hit && hit.c.exhaustion >= 60 ? 2 : 0;
      },
      build(g) {
        const candidates = [];
        for (const prod of g.state.productions) for (const r of prod.roles) {
          if (r.filled && r.filled.clientId) { const c = g.client(r.filled.clientId); if (c && c.exhaustion >= 60) candidates.push({ c, prod }); }
        }
        const { c, prod } = pick(candidates);
        const cost = Math.round(15000 * Calc.infl(g.state.year));
        return {
          title: "Der Zusammenbruch",
          html: `<div class="quote">„${name(c)} ist heute nicht am Set erschienen. Das Hotel sagt, die Tür bleibt zu.“</div>
                 <p>Dein Klient ist am Ende der Kräfte (Erschöpfung ${Math.round(c.exhaustion)}/100). Die Produktion von „${prod.title}“ steht still.</p>`,
          choices: [
            { label: "Produktion unterbrechen lassen", fn: () => {
              prod.monthsLeft += 1;
              g.state.studioRel[prod.studioId] = clamp(g.state.studioRel[prod.studioId] - 4, 0, 100);
              c.exhaustion = clamp(c.exhaustion - 35, 0, 100);
              c.loyalty = clamp(c.loyalty + 10, 0, 100);
              return `Du stellst dich vor deinen Klienten: zwei Wochen Pause, keine Diskussion. Das Studio zürnt, ${name(c)} atmet auf.`;
            }},
            { label: `Diskreten Arzt organisieren (${fmt(cost)})`, fn: () => {
              g.state.agency.cash -= cost;
              c.exhaustion = clamp(c.exhaustion - 45, 0, 100);
              c.mood = clamp(c.mood + 6, 0, 100);
              return `Ein Arzt, der keine Fragen stellt und keine Rechnungen mit Namen schreibt. Nach drei Tagen steht ${name(c)} wieder am Set — erholt.`;
            }},
            { label: "Zur Arbeit drängen", fn: () => {
              c.exhaustion = clamp(c.exhaustion + 10, 0, 100);
              c.loyalty = clamp(c.loyalty - 12, 0, 100);
              if (chance(0.35)) { prod.monthsLeft += 2; return `${name(c)} schleppt sich ans Set — und bricht dort erst recht zusammen. Jetzt steht alles still, und du bist schuld.`; }
              return `Die Show geht weiter. Der Zeitplan hält — aber ${name(c)} wird dir diesen Anruf lange übelnehmen.`;
            }},
          ],
        };
      },
    },

    // ── 16. Streik in Hollywood ──────────────────────────────────────
    {
      id: "strike", cd: 40,
      weight: g => {
        if (g.state.strikeMonths > 0) return 0;
        const y = g.state.year;
        const strikeYears = [1945, 1960, 1980, 1988, 2007, 2023];
        return strikeYears.some(s => Math.abs(y - s) <= 1) ? 3 : 0.12;
      },
      build(g) {
        g.state.strikeMonths = rndInt(2, 3);
        return {
          title: "Streik in Hollywood",
          html: `<p>Ein Arbeitskampf legt die Traumfabrik lahm: Für ${g.state.strikeMonths} Monate ruhen Castings und Drehs. Wie positioniert sich deine Agentur?</p>`,
          choices: [
            { label: "Streikende öffentlich unterstützen", fn: () => {
              g.state.agency.rep = clamp(g.state.agency.rep + 4, 0, 100);
              for (const s of g.activeStudios()) g.state.studioRel[s.id] = clamp(g.state.studioRel[s.id] - 4, 0, 100);
              for (const c of g.state.clients) c.loyalty = clamp(c.loyalty + 5, 0, 100);
              return `Du stellst dich an die Seite der Kreativen. Die Studios kochen — deine Klienten und die Branche applaudieren.`;
            }},
            { label: "Neutral bleiben", fn: () => `Kein Statement, keine Feinde. Du wartest ab, bis sich der Staub legt.` },
            { label: "Ausnahmeregelungen für eigene Produktionen suchen", fn: () => {
              g.state.strikeExempt = true;
              if (chance(0.4)) { g.state.agency.rep = clamp(g.state.agency.rep - 3, 0, 100); return `Deine Drehs laufen weiter — aber „Streikbrecher-Agentur“ steht trotzdem in einer Kolumne. Das Geld fließt, der Ruf kratzt.`; }
              return `Diskrete Anwälte, wasserdichte Alt-Verträge: Deine Produktionen laufen weiter, und niemand schreibt darüber.`;
            }},
          ],
        };
      },
    },

    // ── 17. Der Tonfilm-Test (1927–1932) ─────────────────────────────
    {
      id: "talkieTest", cd: 6,
      weight: g => {
        if (g.state.year < 1927 || g.state.year > 1932) return 0;
        return g.state.clients.some(c => ACTOR_BY_ID[c.aid].debut <= 1926) ? 2.5 : 0;
      },
      build(g) {
        const c = g.randomClient(x => ACTOR_BY_ID[x.aid].debut <= 1926);
        const cost = Math.round(8000 * Calc.infl(g.state.year));
        return {
          title: "Der Tonfilm-Test",
          html: `<div class="quote">„Das Gesicht kennen wir. Jetzt wollen wir die Stimme hören.“</div>
                 <p>Das Studio verlangt einen Sprach- und Stimmtest von ${name(c)} — der Tonfilm sortiert gerade ganz Hollywood neu.</p>`,
          choices: [
            { label: `Intensives Sprachtraining buchen (${fmt(cost)})`, fn: () => {
              g.state.agency.cash -= cost;
              if (chance(0.85)) { c.fame = clamp(c.fame + 4, 5, 100); return `Wochen mit dem besten Sprachlehrer der Westküste zahlen sich aus: Die Stimme trägt. ${name(c)} hat die Zukunft.`; }
              c.fame = clamp(c.fame - 3, 5, 100);
              return `Trotz allem Training bleibt der Test durchwachsen. Aber der Wille wurde registriert — es hätte schlimmer kommen können.`;
            }},
            { label: "Den Test sofort absolvieren", fn: () => {
              if (chance(0.55)) { c.fame = clamp(c.fame + 4, 5, 100); return `Volltreffer: Die Stimme sitzt, das Studio jubelt. ${name(c)} gehört zu den Gewinnern der Ton-Revolution.`; }
              c.fame = clamp(c.fame - 7, 5, 100);
              c.mood = clamp(c.mood - 8, 0, 100);
              return `Die Aufnahme ist ein Desaster. „Vielleicht … mit Untertiteln?“, spottet ein Techniker. Das war riskant — und ging schief.`;
            }},
            { label: "Auf Stummfilm & Auslandsmärkte setzen", fn: () => {
              c.fame = clamp(c.fame - 3, 5, 100);
              c.mood = clamp(c.mood + 3, 0, 100);
              return `Keine Blamage, aber ein Rückzugsgefecht: In Europa und im Stummfilm gibt es noch Arbeit — die Frage ist, wie lange.`;
            }},
          ],
        };
      },
    },

    // ── 18. Die Zensurbehörde (Production-Code-Ära 1934–1954) ────────
    {
      id: "censor", cd: 12,
      weight: g => (g.state.year >= 1934 && g.state.year <= 1954 && inProduction(g)) ? 1 : 0,
      build(g) {
        const { c, prod } = inProduction(g);
        const cost = Math.round(25000 * Calc.infl(g.state.year));
        return {
          title: "Die Zensurbehörde beanstandet das Drehbuch",
          html: `<p>Das Hays Office verlangt Änderungen an „${prod.title}“ — mehrere Szenen mit ${name(c)} dürfen so nicht gezeigt werden.</p>`,
          choices: [
            { label: "Drehbuch entschärfen", fn: () => {
              prod.qualityMod = (prod.qualityMod || 0) - 5;
              return `Die Schere schneidet alles Anstößige heraus. Der Film wird glatter — und ein Stück belangloser.`;
            }},
            { label: "Mit Andeutungen und Umschreibungen arbeiten", fn: () => {
              const p = clamp(0.35 + g.state.agency.rep / 150, 0.25, 0.8);
              if (chance(p)) { prod.qualityMod = (prod.qualityMod || 0) + 5; g.state.agency.rep = clamp(g.state.agency.rep + 2, 0, 100); return `Ein Blick, ein Schatten, eine geschlossene Tür: Die Zensoren finden nichts, das Publikum versteht alles. Große Kunst.`; }
              prod.qualityMod = (prod.qualityMod || 0) - 2;
              return `Ein paar Andeutungen überleben, andere fallen doch der Schere zum Opfer. Ein Teilerfolg.`;
            }},
            { label: `Unabhängige Veröffentlichung versuchen (${fmt(cost)})`, fn: () => {
              g.state.agency.cash -= cost;
              if (chance(0.3)) { prod.qualityMod = (prod.qualityMod || 0) + 10; g.state.agency.rep = clamp(g.state.agency.rep + 4, 0, 100); return `Ohne Code-Siegel in ausgewählte Häuser — und die Kritiker feiern den Mut. Ein Skandalerfolg im besten Sinne.`; }
              prod.qualityMod = (prod.qualityMod || 0) - 6;
              g.state.studioRel[prod.studioId] = clamp(g.state.studioRel[prod.studioId] - 5, 0, 100);
              return `Viele Kinos weigern sich, den Film ohne Siegel zu zeigen. Ein teures, politisch riskantes Experiment.`;
            }},
          ],
        };
      },
    },

    // ── 19. Verdacht auf unamerikanische Umtriebe (1947–1956) ────────
    // Feuert nur mit ≥4 Klienten — kleine Agenturen bleiben verschont.
    {
      id: "blacklist", cd: 20,
      weight: g => (g.state.year >= 1947 && g.state.year <= 1956 && g.state.clients.length >= 4) ? 1.5 : 0,
      build(g) {
        const c = g.randomClient();
        return {
          title: "Verdacht auf unamerikanische Umtriebe",
          html: `<div class="quote">„Das Komitee lädt ${name(c)} vor. Man interessiert sich für … frühere Bekanntschaften.“</div>
                 <p>Die Schwarze Liste greift um sich. Wie du jetzt handelst, definiert deine Agentur für Jahre.</p>`,
          choices: [
            { label: "Klienten öffentlich verteidigen", fn: () => {
              c.loyalty = clamp(c.loyalty + 18, 0, 100);
              for (const cl of g.state.clients) cl.loyalty = clamp(cl.loyalty + 5, 0, 100);
              if (chance(0.35)) {
                g.state.agency.rep = clamp(g.state.agency.rep - 8, 0, 100);
                for (const s of g.activeStudios()) g.state.studioRel[s.id] = clamp(g.state.studioRel[s.id] - 8, 0, 100);
                return `Deine Erklärung ist mutig — und teuer. Studios legen auf, Aufträge versickern. Aber jeder Klient weiß jetzt, dass du niemanden opferst.`;
              }
              g.state.agency.rep = clamp(g.state.agency.rep + 5, 0, 100);
              return `Du sprichst als Einziger Klartext — und kommst durch. In dunklen Zeiten ist Rückgrat die seltenste Währung. Dein Ansehen wächst.`;
            }},
            { label: "Unter Pseudonym im Ausland arbeiten lassen", fn: () => {
              c.busyUntil = g.mi() + 6;
              c.fame = clamp(c.fame - 5, 5, 100);
              c.loyalty = clamp(c.loyalty + 8, 0, 100);
              return `${name(c)} dreht unter falschem Namen in Europa. Die Karriere friert ein, aber sie stirbt nicht — und dein Klient weiß, wem er das verdankt.`;
            }},
            { label: "Vertrag beenden", fn: () => {
              g.state.clients = g.state.clients.filter(x => x.id !== c.id);
              g.state.agency.rep = clamp(g.state.agency.rep - 5, 0, 100);
              for (const cl of g.state.clients) cl.loyalty = clamp(cl.loyalty - 12, 0, 100);
              for (const s of g.activeStudios()) g.state.studioRel[s.id] = clamp(g.state.studioRel[s.id] + 4, 0, 100);
              g.log(`${name(c)} wurde in der Blacklist-Ära fallen gelassen.`, "bad");
              return `Die Agentur ist sicher, die Studios sind zufrieden. Aber in den Augen deiner übrigen Klienten liest du eine Frage: „Wäre ich der Nächste gewesen?“`;
            }},
          ],
        };
      },
    },

    // ── 20. Das Fernsehen klopft an (1948–1965) ──────────────────────
    {
      id: "television", cd: 14,
      weight: g => {
        if (g.state.year < 1948 || g.state.year > 1965) return 0;
        return free(g).some(c => c.fame >= 40 && c.fame <= 75) ? 1.2 : 0;
      },
      build(g) {
        const c = pick(free(g).filter(x => x.fame >= 40 && x.fame <= 75));
        const monthly = Math.round(9000 * Calc.infl(g.state.year) * (c.fame / 50) * c.commission / 100);
        return {
          title: "Das Fernsehen klopft an",
          html: `<div class="quote">„Vergessen Sie das Kino. In fünf Jahren steht in jedem Wohnzimmer ein Apparat — und wir brauchen Gesichter.“</div>
                 <p>Ein Sender bietet ${name(c)} eine eigene Serie: 12 Monate garantiertes Einkommen (${fmt(monthly)}/Monat Provision), aber das Film-Establishment rümpft die Nase.</p>`,
          choices: [
            { label: "Angebot annehmen", fn: () => {
              c.flags.tvIncome = { monthly, months: 12 };
              c.heat = clamp(c.heat + 3, -10, 10);
              c.busyUntil = g.mi() + 3;
              return `${name(c)} wird Fernsehstar: verlässliches Geld jeden Monat. Das Kino-Prestige bröckelt etwas — aber Millionen kennen jetzt dieses Gesicht.`;
            }},
            { label: "Nur Gastauftritte aushandeln", fn: () => {
              if (chance(0.5)) { g.state.agency.cash += monthly * 3; c.heat = clamp(c.heat + 2, -10, 10); return `Der Kompromiss gelingt: einzelne Auftritte, volle Gage (${fmt(monthly * 3)}), kein Exklusivvertrag. Das Beste aus beiden Welten.`; }
              return `Der Sender will alles oder nichts. Der Deal zerschlägt sich — aber die Tür bleibt einen Spalt offen.`;
            }},
            { label: "Fernsehen grundsätzlich zurückweisen", fn: () => {
              c.mood = clamp(c.mood + 2, 0, 100);
              c.loyalty = clamp(c.loyalty + 3, 0, 100);
              return `„Mein Klient ist ein Filmstar.“ Das klassische Image bleibt makellos — ob das in zehn Jahren noch klug aussieht, weiß niemand.`;
            }},
          ],
        };
      },
    },

    // ── Bonus: Ein Gefallen (Netzwerk-Aufbau) ────────────────────────
    {
      id: "favor", cd: 8,
      weight: g => 0.7,
      build(g) {
        const studio = pick(g.activeStudios());
        return {
          title: "Ein Gefallen",
          html: `<p>${studio.name} bittet um einen Gefallen: ein Klient soll unbezahlt bei einer Galapremiere auftreten.</p>`,
          choices: [
            { label: "Einwilligen", fn: () => {
              g.state.studioRel[studio.id] = clamp(g.state.studioRel[studio.id] + 8, 0, 100);
              g.state.network = clamp(g.state.network + 5, 0, 100);
              return `${studio.name} wird sich erinnern. Beziehungen sind die harte Währung dieser Stadt.`;
            }},
            { label: "Ablehnen", fn: () => {
              g.state.studioRel[studio.id] = clamp(g.state.studioRel[studio.id] - 3, 0, 100);
              return `Man verzichtet höflich. Das Studio nimmt es zur Kenntnis.`;
            }},
          ],
        };
      },
    },

    // ── Bonus: Presse-Coup ───────────────────────────────────────────
    {
      id: "press", cd: 8,
      weight: g => g.state.clients.length ? 0.7 : 0,
      build(g) {
        const c = g.randomClient();
        return {
          title: "Presse-Coup",
          html: `<p>Ein großes Magazin bietet eine Titelgeschichte über ${name(c)} an — gegen exklusiven Zugang.</p>`,
          choices: [
            { label: "Zusagen", fn: () => {
              c.heat = clamp(c.heat + 4, -10, 10);
              c.fame = clamp(c.fame + 2, 5, 100);
              return `Die Ausgabe verkauft sich glänzend. ${name(c)} ist heißer denn je.`;
            }},
            { label: "Ablehnen", fn: () => `Man verzichtet. Privatsphäre ist auch etwas wert.` },
          ],
        };
      },
    },
  ];

  // ---------- Folge-Ereignisse ----------
  window.HM_FOLLOWUPS = {
    photosReturn(g, fu) {
      const c = g.client(fu.cid);
      if (!c || c.flags.photosSecured) return null;
      const cost = Math.round((12000 + c.fame * 200) * Calc.infl(g.state.year));
      return {
        title: "Die Fotos tauchen wieder auf",
        html: `<p>Wie befürchtet: Die alten Aufnahmen von ${name(c)} sind wieder im Umlauf — diesmal bei einem Boulevardblatt.</p>`,
        choices: [
          { label: `Jetzt kaufen (${fmt(cost)})`, fn: () => {
            g.state.agency.cash -= cost;
            c.flags.photosSecured = true;
            return `Diesmal zögerst du nicht. Die Sache ist endgültig vom Tisch.`;
          }},
          { label: "Aussitzen", fn: () => {
            c.fame = clamp(c.fame - 3, 5, 100);
            c.flags.photosSecured = true;
            return `Drei unangenehme Wochen, dann ist die Empörung verraucht. Narben bleiben.`;
          }},
        ],
      };
    },
    romanceLeak(g, fu) {
      const c = g.client(fu.cid);
      if (!c) return null;
      return {
        title: "Die Romanze fliegt auf",
        html: `<p>Ein Kolumnist enthüllt: Die große Liebesgeschichte von ${name(c)} war eine PR-Inszenierung.</p>`,
        choices: [
          { label: "Zugeben und lachen", fn: () => {
            if (chance(0.6)) { c.heat = clamp(c.heat + 2, -10, 10); return `„Natürlich war das Show — willkommen in Hollywood.“ Die Stadt lacht mit. Glück gehabt.`; }
            c.fame = clamp(c.fame - 3, 5, 100);
            return `Ein Teil des Publikums fühlt sich betrogen. Der Glanz bekommt Kratzer.`;
          }},
          { label: "Dementieren", fn: () => {
            c.heat = clamp(c.heat - 2, -10, 10);
            return `Das Dementi glaubt niemand so recht, aber die Geschichte verliert an Fahrt.`;
          }},
        ],
      };
    },
  };
})();
