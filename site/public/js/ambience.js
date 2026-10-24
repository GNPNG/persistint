// Site ambience: the title theme, quietly, with a toggle (the browser needs a click or key before
// sound may start, so it begins on the visitor's first interaction unless they turned it off
// before), and a gentle rain of hearts from the top of the page on clicks and scrolling.
(() => {
  'use strict';
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---------------------------------------------------------------- music
  const btn = document.querySelector('.music-toggle');
  const KEY = 'persistint.music';
  const VOLUME = 0.04; // the author's call: very subtle, about a fifth of the first setting
  let audio = null;
  let fadeId = 0;
  const saved = (() => { try { return localStorage.getItem(KEY); } catch (_) { return null; } })();
  const save = (v) => { try { localStorage.setItem(KEY, v); } catch (_) { /* private mode */ } };
  const setUI = (on) => {
    if (!btn) return;
    btn.setAttribute('aria-pressed', String(on));
    btn.classList.toggle('on', on);
    btn.title = on ? 'Music is on. Click to mute.' : 'Music is muted. Click to play the title theme, quietly.';
  };
  const ensure = () => {
    if (!audio) {
      audio = new Audio('/audio/title_theme.mp3');
      audio.loop = true;
      audio.preload = 'none';
      audio.volume = 0;
    }
    return audio;
  };
  const fadeTo = (target, ms, done) => {
    const a = ensure();
    const from = a.volume;
    const t0 = performance.now();
    const id = ++fadeId;
    const step = (t) => {
      if (id !== fadeId) return;
      const k = Math.min(1, (t - t0) / ms);
      a.volume = from + (target - from) * k;
      if (k < 1) requestAnimationFrame(step); else if (done) done();
    };
    requestAnimationFrame(step);
  };
  const play = async () => {
    const a = ensure();
    try { await a.play(); } catch (_) { setUI(false); return false; }
    fadeTo(VOLUME, 2500);
    setUI(true);
    return true;
  };
  const stop = () => {
    if (!audio) return;
    fadeTo(0, 500, () => audio.pause());
    setUI(false);
  };
  if (btn) {
    setUI(false);
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (btn.getAttribute('aria-pressed') === 'true') { stop(); save('off'); }
      else play().then((ok) => { if (ok) save('on'); });
    });
    if (saved !== 'off') {
      const once = () => {
        document.removeEventListener('pointerdown', once);
        document.removeEventListener('keydown', once);
        play();
      };
      document.addEventListener('pointerdown', once);
      document.addEventListener('keydown', once);
    }
    document.addEventListener('visibilitychange', () => {
      if (!audio || btn.getAttribute('aria-pressed') !== 'true') return;
      if (document.hidden) audio.pause(); else audio.play().catch(() => {});
    });
  }

  // ---------------------------------------------------------------- hearts
  if (reduceMotion) return;
  const cv = document.createElement('canvas');
  cv.className = 'heart-rain';
  cv.setAttribute('aria-hidden', 'true');
  document.body.appendChild(cv);
  const ctx = cv.getContext('2d');
  let W = 0, H = 0;
  const resize = () => {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = window.innerWidth; H = window.innerHeight;
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  resize();
  addEventListener('resize', resize);

  const COLOURS = ['#ff8fb1', '#ffb3c8', '#c9b8f2', '#ffe59a'];
  const OUTLINE = '#8a5a5a';
  const MAX = 14;
  const hearts = [];
  let running = false, last = 0;
  const rand = (a, b) => a + Math.random() * (b - a);

  const spawn = (n, x) => {
    for (let i = 0; i < n && hearts.length < MAX; i++) {
      hearts.push({
        x: x == null ? rand(0, W) : Math.min(W, Math.max(0, x + rand(-60, 60))),
        y: rand(-30, -10),
        s: rand(6, 11),                // half-width in px
        v: rand(55, 90),               // px per second
        t: rand(0, Math.PI * 2),       // sway phase
        sw: rand(10, 22),              // sway width
        rot: rand(-0.35, 0.35),
        age: 0,
        c: COLOURS[Math.floor(Math.random() * COLOURS.length)],
      });
    }
    if (!running) { running = true; last = performance.now(); requestAnimationFrame(tick); }
  };

  const heartPath = (s) => {
    ctx.beginPath();
    ctx.moveTo(0, s * 0.9);
    ctx.bezierCurveTo(-s * 1.6, -s * 0.3, -s * 0.8, -s * 1.3, 0, -s * 0.45);
    ctx.bezierCurveTo(s * 0.8, -s * 1.3, s * 1.6, -s * 0.3, 0, s * 0.9);
    ctx.closePath();
  };

  const tick = (now) => {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    ctx.clearRect(0, 0, W, H);
    for (let i = hearts.length - 1; i >= 0; i--) {
      const h = hearts[i];
      h.age += dt;
      h.y += h.v * dt;
      h.t += dt * 1.6;
      const x = h.x + Math.sin(h.t) * h.sw;
      const fadeIn = Math.min(1, h.age / 0.6);
      const fadeOut = h.y > H * 0.45 ? Math.max(0, 1 - (h.y - H * 0.45) / (H * 0.3)) : 1;
      // Scrolling back up: the hearts have nowhere sensible to fall to, so they fade out fast.
      if (h.dying) h.die = Math.min(1, (h.die || 0) + dt * 4);
      const alpha = 0.6 * fadeIn * fadeOut * (1 - (h.die || 0));
      if (h.y > H + 20 || alpha <= 0.01 && h.age > 1) { hearts.splice(i, 1); continue; }
      ctx.save();
      ctx.translate(x, h.y);
      ctx.rotate(h.rot + Math.sin(h.t * 0.7) * 0.15);
      ctx.globalAlpha = alpha;
      heartPath(h.s);
      ctx.fillStyle = h.c;
      ctx.fill();
      ctx.lineWidth = 1.2;
      ctx.strokeStyle = OUTLINE;
      ctx.stroke();
      ctx.restore();
    }
    if (hearts.length) requestAnimationFrame(tick); else { running = false; ctx.clearRect(0, 0, W, H); }
  };

  document.addEventListener('pointerdown', (e) => {
    if (e.button !== 0) return;
    spawn(2, e.clientX);
  });
  let scrollAcc = 0, lastY = window.scrollY, lastSpawn = 0;
  addEventListener('scroll', () => {
    const y = window.scrollY;
    const dy = y - lastY;
    lastY = y;
    if (dy < 0) {
      for (const h of hearts) h.dying = true;
      scrollAcc = 0;
      return;
    }
    scrollAcc += dy;
    const now = performance.now();
    if (scrollAcc >= 320 && now - lastSpawn > 400) {
      spawn(1);
      scrollAcc = 0;
      lastSpawn = now;
    }
  }, { passive: true });
})();
