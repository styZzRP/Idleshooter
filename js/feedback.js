/* Vibration and short synthesised blips, both gated on settings and throttled
   so a bullet-hell frame can't fire hundreds of them. */
(function (global) {
  'use strict';

  var CUES = {
    purchase: { freq: 660, to: 990, dur: 0.09, type: 'triangle', gain: 0.16 },
    ability:  { freq: 220, to: 720, dur: 0.22, type: 'sawtooth', gain: 0.14 },
    travel:   { freq: 420, to: 880, dur: 0.30, type: 'sine', gain: 0.14 },
    denied:   { freq: 200, to: 130, dur: 0.14, type: 'square', gain: 0.09 },
    rebirth:  { freq: 320, to: 1200, dur: 0.45, type: 'sine', gain: 0.16 },
    pop:      { freq: 880, to: 1320, dur: 0.05, type: 'sine', gain: 0.07 }
  };

  var Feedback = {
    hapticsEnabled: true,
    soundEnabled: true,
    _ctx: null,
    _lastHaptic: 0,
    _lastSound: 0,
    /** Browsers reject vibration and audio until the page has been tapped. */
    _gestureSeen: false,

    /** Browsers only allow audio after a user gesture; call this from one. */
    unlock: function () {
      this._gestureSeen = true;
      if (!this._ctx) {
        var Ctx = global.AudioContext || global.webkitAudioContext;
        if (!Ctx) return;
        try { this._ctx = new Ctx(); } catch (e) { this._ctx = null; return; }
      }
      if (this._ctx.state === 'suspended') this._ctx.resume();
    },

    tap: function (strength, throttle) {
      if (!this.hapticsEnabled || !this._gestureSeen) return;
      if (!global.navigator || !navigator.vibrate) return;
      // Chrome logs a console error if we call this before a real gesture.
      if (navigator.userActivation && !navigator.userActivation.hasBeenActive) return;
      var now = performance.now();
      var gap = (throttle === undefined ? 0.05 : throttle) * 1000;
      if (now - this._lastHaptic < gap) return;
      this._lastHaptic = now;
      var ms = strength === 'heavy' ? 22 : (strength === 'medium' ? 12 : 7);
      try { navigator.vibrate(ms); } catch (e) { /* not supported */ }
    },

    select: function () { this.tap('light', 0.02); },
    success: function () { this.tap('medium', 0.02); },

    play: function (cueName, throttle) {
      if (!this.soundEnabled) return;
      var now = performance.now();
      var gap = (throttle === undefined ? 0.08 : throttle) * 1000;
      if (now - this._lastSound < gap) return;
      this._lastSound = now;

      this.unlock();
      var ctx = this._ctx;
      if (!ctx || ctx.state !== 'running') return;

      var cue = CUES[cueName];
      if (!cue) return;

      var osc = ctx.createOscillator();
      var gain = ctx.createGain();
      var t = ctx.currentTime;

      osc.type = cue.type;
      osc.frequency.setValueAtTime(cue.freq, t);
      osc.frequency.exponentialRampToValueAtTime(Math.max(20, cue.to), t + cue.dur);

      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.exponentialRampToValueAtTime(cue.gain, t + 0.012);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + cue.dur);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + cue.dur + 0.02);
    }
  };

  global.Feedback = Feedback;
})(window);
