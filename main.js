/* Rahman & Fia — invitation behaviour.
   Three jobs: the "Buka Undangan" cover gate, the music, and reveal-on-scroll.
   No dependencies. */
(function () {
  'use strict';

  var body = document.body;
  var deck = document.getElementById('deck');
  var opener = document.getElementById('opener');
  var calm = window.matchMedia('(prefers-reduced-motion: reduce)');

  /* ── cover gate ──────────────────────────────────────────────────── */
  function open() {
    if (body.dataset.open === 'true') return;
    body.dataset.open = 'true';
    deck.focus({ preventScroll: true });
    play();
  }

  if (opener) {
    opener.addEventListener('click', open);
  } else {
    body.dataset.open = 'true';
  }

  /* Keep the deck pinned to screen 01 while the gate is closed — a bfcache
     restore or a mid-scroll reload would otherwise leave it part-way down. */
  deck.addEventListener('scroll', function () {
    if (body.dataset.open === 'false' && deck.scrollTop !== 0) deck.scrollTop = 0;
  }, { passive: true });

  window.addEventListener('pageshow', function () {
    if (body.dataset.open === 'false') deck.scrollTop = 0;
  });

  /* ── music ───────────────────────────────────────────────────────── */
  var song = document.getElementById('song');
  var toggle = document.getElementById('music');

  /* The track is normalised to -16 LUFS, so this is a stable background level
     rather than a guess about how loud the file happens to be. */
  var LEVEL = 0.45;
  var FADE = 1200;
  var ramp = null;
  var wanted = false;   /* what the guest asked for; the element may lag behind it */

  /* Ease the volume instead of cutting it, so the song arrives under the
     invitation rather than landing on top of it. */
  function rampTo(target, then) {
    if (ramp) cancelAnimationFrame(ramp);
    var from = song.volume;
    var t0 = performance.now();

    (function step(now) {
      var k = Math.min((now - t0) / FADE, 1);
      song.volume = from + (target - from) * k;
      if (k < 1) { ramp = requestAnimationFrame(step); return; }
      ramp = null;
      if (then) then();
    })(performance.now());
  }

  function paint() {
    toggle.setAttribute('aria-pressed', wanted ? 'true' : 'false');
    toggle.setAttribute('aria-label', wanted ? 'Matikan musik' : 'Nyalakan musik');
  }

  function play() {
    if (!song) return;
    wanted = true;
    paint();
    song.volume = 0;

    /* Older browsers return undefined here; only the promise can be rejected,
       and a rejection must never take the cover gate down with it. */
    var started = song.play();
    if (!started) { rampTo(LEVEL); return; }

    started.then(function () {
      rampTo(LEVEL);
    }, function () {
      wanted = false;
      paint();
    });
  }

  if (song && toggle) {
    toggle.addEventListener('click', function () {
      if (wanted) {
        wanted = false;
        paint();
        rampTo(0, function () { song.pause(); });
      } else {
        play();
      }
    });

    /* Nobody wants a tab they switched away from still singing. */
    document.addEventListener('visibilitychange', function () {
      if (!wanted) return;
      if (document.hidden) song.pause();
      else { var r = song.play(); if (r) r.catch(function () {}); }
    });
  }

  /* ── reveal on scroll ────────────────────────────────────────────── */
  var targets = document.querySelectorAll('[data-reveal]');

  if (calm.matches || !('IntersectionObserver' in window)) {
    targets.forEach(function (el) { el.classList.add('is-visible'); });
    return;
  }

  var seen = new WeakMap();

  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (!entry.isIntersecting) return;

      /* Stagger siblings within a screen so a section arrives as a sequence
         rather than all at once. */
      var screen = entry.target.closest('.screen');
      var n = seen.get(screen) || 0;
      seen.set(screen, n + 1);
      entry.target.style.setProperty('--delay', Math.min(n, 5) * 110 + 'ms');

      entry.target.classList.add('is-visible');
      io.unobserve(entry.target);
    });
  }, { root: deck, threshold: 0.15 });

  targets.forEach(function (el) { io.observe(el); });
})();
