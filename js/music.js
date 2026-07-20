// =====================================================================
// Hollywood Manager — Generative Epochen-Musik (WebAudio, keine Assets)
// =====================================================================

const Music = (function () {
  let ctx = null, master = null, filter = null;
  let timer = null, nextTime = 0, step = 0, presetKey = null;
  let enabled = true, volume = 0.35;

  // Akkorde als Halbton-Offsets über dem Grundton
  const CHORDS = {
    M: [0, 4, 7], M7: [0, 4, 7, 11], m: [0, 3, 7], m7: [0, 3, 7, 10],
    "7": [0, 4, 7, 10], m6: [0, 3, 7, 9], dim: [0, 3, 6, 9],
  };

  // prog: [Grundton-Offset (Halbtöne ab Preset-Root), Akkordtyp] — 1 Takt je Eintrag
  const PRESETS = {
    // Stummfilm: flottes Ragtime-Klavier
    ragtime: {
      tempo: 168, swing: 0, root: 48, cutoff: 3200, wave: "triangle", bassWave: "triangle",
      prog: [[0, "M"], [0, "M"], [5, "M"], [7, "7"], [0, "M"], [9, "7"], [2, "7"], [7, "7"]],
      stabs: [1, 3, 5, 7], stabLen: 0.09, melodyDensity: 0.55, melodyOct: 24, pad: false,
    },
    // Golden Age: langsamer Noir-Jazz
    noir: {
      tempo: 82, swing: 0.32, root: 45, cutoff: 1400, wave: "sine", bassWave: "sine",
      prog: [[0, "m7"], [5, "m7"], [3, "M7"], [10, "7"], [0, "m7"], [8, "M7"], [7, "7"], [7, "7"]],
      stabs: [0, 4], stabLen: 0.9, melodyDensity: 0.3, melodyOct: 24, pad: false,
    },
    // Blockbuster-Ära: Synth-Flächen mit Puls-Bass
    synth: {
      tempo: 102, swing: 0, root: 45, cutoff: 1800, wave: "sawtooth", bassWave: "square",
      prog: [[0, "m"], [0, "m"], [8, "M"], [3, "M"], [10, "M"], [10, "M"], [7, "m"], [8, "M"]],
      stabs: [0], stabLen: 2.2, melodyDensity: 0.35, melodyOct: 12, pad: true,
    },
    // Gegenwart: ruhiges Piano-Arpeggio
    modern: {
      tempo: 72, swing: 0, root: 48, cutoff: 2200, wave: "triangle", bassWave: "sine",
      prog: [[0, "m7"], [8, "M7"], [3, "M7"], [10, "M"], [0, "m7"], [8, "M7"], [5, "m7"], [7, "M"]],
      stabs: [], stabLen: 0.4, melodyDensity: 0.0, melodyOct: 12, pad: true, arp: true,
    },
  };

  function keyForYear(y) {
    if (y < 1935) return "ragtime";
    if (y < 1968) return "noir";
    if (y < 2000) return "synth";
    return "modern";
  }

  const midiHz = m => 440 * Math.pow(2, (m - 69) / 12);

  function note(midi, t, dur, wave, gainVal, glideCutoff) {
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = wave;
    osc.frequency.value = midiHz(midi);
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(gainVal, t + 0.015);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    osc.connect(g).connect(glideCutoff || filter);
    osc.start(t);
    osc.stop(t + dur + 0.05);
  }

  function scheduleStep(p, when, s) {
    const stepsPerBar = 8;
    const bar = Math.floor(s / stepsPerBar) % p.prog.length;
    const inBar = s % stepsPerBar;
    const [off, type] = p.prog[bar];
    const chord = CHORDS[type];
    const rootMidi = p.root + off;

    // Bass: Grundton / Quinte im Wechsel
    if (inBar % 2 === 0) {
      const b = inBar % 4 === 0 ? rootMidi : rootMidi + 7;
      note(b, when, p.tempo > 120 ? 0.16 : 0.5, p.bassWave, 0.22);
    }
    // Akkord-Stabs oder Pad
    if (p.pad && inBar === 0) {
      for (const iv of chord) note(rootMidi + 12 + iv, when, p.stabLen, p.wave, 0.05);
      if (p.wave === "sawtooth") for (const iv of chord) note(rootMidi + 12 + iv + 0.1, when, p.stabLen, p.wave, 0.03);
    } else if (p.stabs.includes(inBar)) {
      for (const iv of chord) note(rootMidi + 12 + iv, when, p.stabLen, p.wave, 0.07);
    }
    // Arpeggio (modern) oder Zufalls-Melodie
    if (p.arp) {
      const iv = chord[inBar % chord.length];
      note(rootMidi + 24 + iv, when, 0.9, "triangle", 0.06);
    } else if (Math.random() < p.melodyDensity) {
      const iv = chord[Math.floor(Math.random() * chord.length)];
      const oct = Math.random() < 0.3 ? 12 : 0;
      note(rootMidi + p.melodyOct + iv + oct, when, p.tempo > 120 ? 0.12 : 0.45, p.wave, 0.09);
    }
  }

  function tick() {
    if (!ctx || !enabled) return;
    const p = PRESETS[presetKey];
    const stepDur = 60 / p.tempo / 2; // Achtel
    while (nextTime < ctx.currentTime + 0.35) {
      const swingOff = (step % 2 === 1) ? p.swing * stepDur : 0;
      scheduleStep(p, nextTime + swingOff, step);
      nextTime += stepDur;
      step++;
    }
  }

  return {
    get enabled() { return enabled; },
    get volume() { return volume; },

    start(year) {
      if (!ctx) {
        ctx = new (window.AudioContext || window.webkitAudioContext)();
        master = ctx.createGain();
        filter = ctx.createBiquadFilter();
        filter.type = "lowpass";
        filter.connect(master).connect(ctx.destination);
      }
      if (ctx.state === "suspended") ctx.resume();
      this.setEra(year, true);
      master.gain.value = enabled ? volume : 0;
      if (!timer) timer = setInterval(tick, 90);
    },

    setEra(year, force) {
      const key = keyForYear(year);
      if (key === presetKey && !force) return;
      presetKey = key;
      step = 0;
      if (ctx) {
        nextTime = ctx.currentTime + 0.15;
        filter.frequency.value = PRESETS[key].cutoff;
      }
    },

    setVolume(v) {
      volume = v;
      if (master && enabled) master.gain.value = v;
    },

    toggle() {
      enabled = !enabled;
      if (master) master.gain.value = enabled ? volume : 0;
      return enabled;
    },
  };
})();

window.Music = Music;
