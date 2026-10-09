(() => {
  'use strict';
  window.__oasisYandexBridge?.dispose();
  delete window.__oasisYandexBridge;
  if (window.location.protocol !== 'music-application:' || window.location.hostname !== 'desktop' || window.top !== window) return null;
  let disposed = false;
  let scheduled = null;
  const waiters = new Set();
  const wait = () => new Promise(resolve => {
    const entry = { resolve, timer: setTimeout(() => { waiters.delete(entry); resolve(); }, 50) };
    waiters.add(entry);
  });
  const button = (panel, id) => panel?.querySelector(`[data-test-id="${id}"]`);
  const enabled = target => !!target && !target.disabled && target.getAttribute?.('aria-disabled') !== 'true';
  const models = () => {
    const panel = document.querySelector('[data-test-id="VIBE_PLAYERBAR"]') || document.querySelector('[data-test-id="PLAYERBAR_DESKTOP"]');
    if (!panel) return { panel: null };
    const key = Object.keys(panel).find(k => k.startsWith('__reactFiber$'));
    let fiber = panel[key], root, player;
    for (let depth = 0; fiber && depth < 20; depth++, fiber = fiber.return) {
      let context = fiber.dependencies?.firstContext;
      for (let count = 0; context && count < 30; count++, context = context.next) {
        const value = context.memoizedValue;
        if (value?.sonataState) root = value;
        if (value?.playbackController && typeof value.setProgress === 'function') player = value;
      }
      if (root && player) break;
    }
    return { panel, root, player };
  };
  const numeric = value => typeof value === 'number' && Number.isFinite(value) ? value : null;
  function snapshot() {
    const { panel, root, player } = models();
    const base = { version: 1, sampledAt: Date.now() / 1000 };
    if (!panel) return { ...base, state: 'notReady' };
    if (!root || !player) return { ...base, state: 'incompatibleVersion' };
    const s = root.sonataState, meta = s.entityMeta;
    if (!meta?.id || typeof meta.title !== 'string' || !meta.title || meta.isAvailable === false || meta.isRemoved === true) return { ...base, state: 'notReady' };
    const progress = player.state?.playerState?.progress?.value;
    const duration = numeric(progress?.duration) ?? numeric(s.duration);
    const position = numeric(progress?.position) ?? numeric(s.position);
    const like = button(panel, 'LIKE_BUTTON');
    const pressed = like?.getAttribute('aria-pressed');
    const playControl = button(panel, s.status === 'playing' ? 'PAUSE_BUTTON' : 'PLAY_BUTTON') || button(panel, 'PLAY_BUTTON');
    const seekControl = button(panel, 'TIMECODE_SLIDER') || button(panel, 'VIBE_PLAYERBAR_TIMECODE_SLIDER');
    const seekInput = seekControl?.querySelector?.('input[type=range]');
    const seekEnabled = (!seekControl || enabled(seekControl)) && (!seekInput || enabled(seekInput));
    const isFavorite = pressed === 'true' ? true : pressed === 'false' ? false : null;
    const vibe = s.contextType === 'vibe';
    const media = navigator.mediaSession?.metadata;
    const artist = Array.isArray(meta.artists) ? meta.artists.map(a => a.name).filter(Boolean).join(', ') : null;
    const mediaMatches = media?.title === meta.title && media?.artist === artist && media?.album === meta.albums?.[0]?.title;
    const cover = meta.coverUri || (mediaMatches ? media.artwork?.find(a => a.src)?.src : null);
    const artworkURL = typeof cover === 'string' ? (/^https?:\/\//.test(cover) ? cover : `https://${cover.replace(/^\/\//, '')}`).replace(/%%/g, '400x400') : null;
    return {
      ...base, state: 'ready', trackID: String(meta.id), title: meta.title,
      artist,
      album: meta.albums?.[0]?.title ?? null, isPlaying: s.status === 'playing', duration, position,
      artworkURL, isFavorite, shuffleMode: s.shuffle ? 3 : 1,
      repeatMode: s.repeatMode === 'one' ? 2 : s.repeatMode === 'context' ? 3 : 1,
      capabilities: {
        canPlayPause: playControl ? enabled(playControl) : typeof player.pause === 'function' && typeof player[s.status === 'idle' ? 'play' : 'resume'] === 'function',
        canNext: s.canMoveForward === true, canPrevious: s.canMoveBackward === true,
        canSeek: seekEnabled && duration > 0 && position !== null && typeof player.setProgress === 'function',
        canFavorite: isFavorite !== null && enabled(like),
        shuffleModes: s.canShuffle === true ? [1, 3] : [],
        repeatModes: s.canChangeRepeatMode === true ? (vibe ? [1, 2] : [1, 3, 2]) : []
      }
    };
  }
  function expected(request, s) {
    return typeof request.expectedTrackID === 'string' && request.expectedTrackID === s.trackID;
  }
  async function command(request) {
    try {
      if (disposed) throw Error('disposed');
      const before = snapshot();
      if (before.state !== 'ready') throw Error(before.state);
      const { player, panel, root } = models(), caps = before.capabilities;
      const invoke = async (method, fallback, ...args) => {
        if (typeof player[method] === 'function') await player[method](...args);
        else { const target = button(panel, fallback); if (!enabled(target)) throw Error('unsupported'); target.click(); }
      };
      let seekTarget;
      let expectedPlaying;
      switch (request.action) {
        case 'play': case 'pause': case 'toggle': {
          if (!caps.canPlayPause) throw Error('unsupported');
          const play = request.action === 'play' || request.action === 'toggle' && !before.isPlaying;
          expectedPlaying = play;
          const playMethod = root.sonataState.status === 'idle' ? 'play' : 'resume';
          await invoke(play ? playMethod : 'pause', play ? 'PLAY_BUTTON' : (button(panel, 'PAUSE_BUTTON') ? 'PAUSE_BUTTON' : 'PLAY_BUTTON')); break;
        }
        case 'next': case 'previous':
          if (!(request.action === 'next' ? caps.canNext : caps.canPrevious)) throw Error('unsupported');
          await invoke(request.action === 'next' ? 'moveForward' : 'moveBackward', request.action === 'next' ? 'NEXT_TRACK_BUTTON' : 'PREVIOUS_TRACK_BUTTON'); break;
        case 'seek':
          if (!expected(request, before)) throw Error('trackChanged');
          if (!caps.canSeek || numeric(request.value) === null) throw Error('unsupported');
          seekTarget = Math.max(0, Math.min(request.value, before.duration));
          await player.setProgress(seekTarget); break;
        case 'shuffle':
          if (!caps.shuffleModes.includes(request.value) || typeof player.setShuffle !== 'function') throw Error('unsupported');
          await player.setShuffle(request.value === 3); break;
        case 'repeat':
          if (!caps.repeatModes.includes(request.value) || typeof player.setRepeatMode !== 'function') throw Error('unsupported');
          await player.setRepeatMode(request.value === 2 ? 'one' : request.value === 3 ? 'context' : 'none'); break;
        case 'favorite': {
          if (!expected(request, before)) throw Error('trackChanged');
          if (!caps.canFavorite || typeof request.value !== 'boolean') throw Error('unsupported');
          const fresh = snapshot();
          if (!expected(request, fresh)) throw Error('trackChanged');
          if (fresh.isFavorite !== request.value) { const target = button(models().panel, 'LIKE_BUTTON'); if (!enabled(target)) throw Error('unsupported'); target.click(); }
          break;
        }
        default: throw Error('unsupported');
      }
      let after = snapshot();
      const confirmed = s => {
        switch (request.action) {
          case 'play': case 'pause': case 'toggle': return s.isPlaying === expectedPlaying;
          case 'favorite': return s.isFavorite === request.value;
          case 'shuffle': return s.shuffleMode === request.value;
          case 'repeat': return s.repeatMode === request.value;
          case 'seek': return typeof s.position === 'number' && Math.abs(s.position - seekTarget) <= 0.35;
          default: return true;
        }
      };
      const deadline = Date.now() + 1500;
      while (true) {
        if (disposed) throw Error('disposed');
        if (['seek', 'favorite', 'shuffle', 'repeat'].includes(request.action) && after.trackID !== before.trackID) throw Error('trackChanged');
        if (confirmed(after)) break;
        if (Date.now() >= deadline) throw Error('notConfirmed');
        await wait();
        after = snapshot();
      }
      return { ok: true, snapshot: after };
    } catch (error) { return { ok: false, error: String(error.message || error), snapshot: snapshot() }; }
  }
  const publish = () => { scheduled = null; if (!disposed && typeof window.oasisYandexChanged === 'function') window.oasisYandexChanged(JSON.stringify(snapshot())); };
  const observer = new MutationObserver(() => { if (!disposed && scheduled === null) scheduled = setTimeout(publish, 50); });
  observer.observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ['aria-pressed', 'data-test-id', 'disabled', 'aria-disabled'] });
  window.__oasisYandexBridge = { snapshot, command, dispose() { disposed = true; observer.disconnect(); if (scheduled !== null) clearTimeout(scheduled); for (const entry of waiters) { clearTimeout(entry.timer); entry.resolve(); } waiters.clear(); } };
  return snapshot();
})();
