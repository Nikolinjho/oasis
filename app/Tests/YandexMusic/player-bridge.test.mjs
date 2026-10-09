import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const script = await readFile(new URL('../../Resources/YandexMusic/player-bridge.js', import.meta.url), 'utf8');
function fixture({ vibe = false, favorite = 'false', disabled = false, delayedLike = false, disabledPlay = false, disabledSeek = false, nestedDisabledSeek = false } = {}) {
  const state = { entityMeta: { id: 90111503, title: 'God Breathed', artists: [{ name: 'Ye' }], albums: [{ title: 'Donda' }], coverUri: 'avatars.yandex.net/a/%%' }, status: 'paused', position: 66, duration: 333.46, shuffle: false, repeatMode: 'none', canShuffle: !vibe, canChangeRepeatMode: true, canMoveForward: true, canMoveBackward: false, contextType: vibe ? 'vibe' : 'album' };
  const player = { playbackController: {}, state: { playerState: { progress: { value: { duration: 333.46, position: 66 } } } }, setProgress(p) { player.state.playerState.progress.value.position = p; }, setShuffle(v) { state.shuffle = v; }, setRepeatMode(v) { state.repeatMode = v; }, pause() { state.status = 'paused'; }, resume() { state.status = 'playing'; } };
  let clicks = 0;
  const like = { disabled, getAttribute: (name) => name === 'aria-pressed' ? favorite : disabled ? 'true' : 'false', click() { clicks++; const update = () => { favorite = favorite === 'true' ? 'false' : 'true'; }; if (delayedLike) setTimeout(update, 80); else update(); } };
  const panel = { querySelector: (q) => q.includes('LIKE_BUTTON') ? like : q.includes('PLAY_BUTTON') && disabledPlay ? { disabled: true, getAttribute: () => 'true' } : q.includes('TIMECODE_SLIDER') && disabledSeek ? { disabled: true, getAttribute: () => 'true' } : q.includes('TIMECODE_SLIDER') && nestedDisabledSeek ? { disabled: false, getAttribute: () => 'false', querySelector: () => ({ disabled: true, getAttribute: () => 'true' }) } : null, __reactFiber$test: { dependencies: { firstContext: { memoizedValue: { sonataState: state }, next: { memoizedValue: player } } } } };
  const sandbox = { document: { querySelector: (q) => q.includes(vibe ? 'VIBE_PLAYERBAR' : 'PLAYERBAR_DESKTOP') ? panel : null, documentElement: {} }, navigator: {}, MutationObserver: class { observe() {} disconnect() {} }, Date, setTimeout, clearTimeout, console };
  sandbox.window = sandbox; sandbox.top = sandbox; sandbox.location = { protocol: 'music-application:', hostname: 'desktop' }; vm.runInNewContext(script, sandbox);
  return { bridge: sandbox.__oasisYandexBridge, state, player, sandbox, clicks: () => clicks };
}
test('читает цельные метаданные, точную позицию и возможности альбома', () => {
  const { bridge } = fixture(); const s = bridge.snapshot();
  assert.equal(s.trackID, '90111503'); assert.equal(s.title, 'God Breathed'); assert.equal(s.position, 66);
  assert.equal(s.artworkURL, 'https://avatars.yandex.net/a/400x400'); assert.deepEqual([...s.capabilities.repeatModes], [1, 3, 2]);
});
test('Волна разрешает повтор одного трека и запрещает shuffle', async () => {
  const { bridge } = fixture({ vibe: true }); const s = bridge.snapshot();
  assert.deepEqual([...s.capabilities.repeatModes], [1, 2]); assert.deepEqual([...s.capabilities.shuffleModes], []);
  assert.equal((await bridge.command({ action: 'repeat', value: 3 })).ok, false);
});
test('seek принимает ноль и отклоняет устаревший id', async () => {
  const { bridge, player } = fixture();
  assert.equal((await bridge.command({ action: 'seek', value: 0, expectedTrackID: '90111503' })).ok, true);
  assert.equal(player.state.playerState.progress.value.position, 0);
  assert.equal((await bridge.command({ action: 'seek', value: 12, expectedTrackID: 'other' })).ok, false);
  assert.equal(player.state.playerState.progress.value.position, 0);
});
test('лайк неизвестного состояния и устаревшего трека не меняет аккаунт', async () => {
  const unknown = fixture({ favorite: null });
  assert.equal(unknown.bridge.snapshot().isFavorite, null);
  assert.equal((await unknown.bridge.command({ action: 'favorite', value: true, expectedTrackID: '90111503' })).ok, false);
  assert.equal(unknown.clicks(), 0);
  const f = fixture(); assert.equal((await f.bridge.command({ action: 'favorite', value: true, expectedTrackID: 'other' })).ok, false); assert.equal(f.clicks(), 0);
});
test('повторный желаемый лайк не кликает и ответ содержит фактический snapshot', async () => {
  const f = fixture(); const first = await f.bridge.command({ action: 'favorite', value: true, expectedTrackID: '90111503' });
  assert.equal(first.ok, true); assert.equal(first.snapshot.isFavorite, true);
  await f.bridge.command({ action: 'favorite', value: true, expectedTrackID: '90111503' }); assert.equal(f.clicks(), 1);
});

test('контекст альбома на Vibe-панели сохраняет повтор контекста', () => {
  const f = fixture({ vibe: true }); f.state.contextType = 'album';
  assert.deepEqual([...f.bridge.snapshot().capabilities.repeatModes], [1, 3, 2]);
});
test('обложка относится к entityMeta, а устаревшая mediaSession игнорируется', () => {
  const f = fixture(); f.sandbox.navigator.mediaSession = { metadata: { title: 'Previous', artwork: [{ src: 'https://old.test/art' }] } };
  assert.equal(f.bridge.snapshot().artworkURL, 'https://avatars.yandex.net/a/400x400');
  f.state.entityMeta.coverUri = null;
  assert.equal(f.bridge.snapshot().artworkURL, null);
});
test('disabled лайк не вызывает click', async () => {
  const f = fixture({ disabled: true });
  assert.equal(f.bridge.snapshot().capabilities.canFavorite, false);
  assert.equal((await f.bridge.command({ action: 'favorite', value: true, expectedTrackID: '90111503' })).ok, false); assert.equal(f.clicks(), 0);
});
test('ответ ждёт подтверждения лайка и режима, не повторяя действие', async () => {
  const f = fixture({ delayedLike: true });
  assert.equal((await f.bridge.command({ action: 'favorite', value: true, expectedTrackID: '90111503' })).ok, true); assert.equal(f.clicks(), 1);
  let calls = 0; f.player.setRepeatMode = value => { calls++; setTimeout(() => { f.state.repeatMode = value; }, 80); };
  const result = await f.bridge.command({ action: 'repeat', value: 3 });
  assert.equal(result.ok, true); assert.equal(result.snapshot.repeatMode, 3); assert.equal(calls, 1);
});
test('смена трека во время ожидания лайка завершает команду ошибкой', async () => {
  const f = fixture({ delayedLike: true }); setTimeout(() => { f.state.entityMeta.id = 99; }, 20);
  const result = await f.bridge.command({ action: 'favorite', value: true, expectedTrackID: '90111503' });
  assert.equal(result.ok, false); assert.equal(result.error, 'trackChanged'); assert.equal(f.clicks(), 1);
});

test('seek ждёт фактическую позицию, включая нормализацию нуля', async () => {
  const f = fixture(); let calls = 0;
  f.player.setProgress = p => { calls++; setTimeout(() => { f.player.state.playerState.progress.value.position = p === 0 ? 0.1 : p; }, 80); };
  const result = await f.bridge.command({ action: 'seek', value: 0, expectedTrackID: '90111503' });
  assert.equal(result.ok, true); assert.equal(result.snapshot.position, 0.1); assert.equal(calls, 1);
});
test('скрипт не внедряется в страницу авторизации', () => {
  const f = fixture(); f.sandbox.location.hostname = 'auth';
  vm.runInNewContext(script, f.sandbox);
  assert.equal(f.sandbox.__oasisYandexBridge, undefined);
});

test('недоступный трек не предлагает команды, disabled PLAY запрещает play', async () => {
  const unavailable = fixture(); unavailable.state.entityMeta.isAvailable = false;
  assert.equal(unavailable.bridge.snapshot().state, 'notReady');
  assert.equal((await unavailable.bridge.command({ action: 'play' })).ok, false);
  const disabled = fixture({ disabledPlay: true });
  assert.equal(disabled.bridge.snapshot().capabilities.canPlayPause, false);
  assert.equal((await disabled.bridge.command({ action: 'play' })).ok, false);
  assert.equal(disabled.state.status, 'paused');
});

test('disabled timecode запрещает seek даже при доступном setProgress', async () => {
  const f = fixture({ disabledSeek: true });
  assert.equal(f.bridge.snapshot().capabilities.canSeek, false);
  assert.equal((await f.bridge.command({ action: 'seek', value: 0, expectedTrackID: '90111503' })).ok, false);
  assert.equal(f.player.state.playerState.progress.value.position, 66);
});

test('вложенный disabled range блокирует seek при enabled контейнере Волны', async () => {
  const f = fixture({ vibe: true, nestedDisabledSeek: true });
  assert.equal(f.bridge.snapshot().capabilities.canSeek, false);
  assert.equal((await f.bridge.command({ action: 'seek', value: 0, expectedTrackID: '90111503' })).ok, false);
  assert.equal(f.player.state.playerState.progress.value.position, 66);
});

test('два последовательных toggle ждут фактическое состояние и возвращают его', async () => {
  const f = fixture();
  const calls = [];
  f.player.resume = async () => { calls.push('resume'); setTimeout(() => { f.state.status = 'playing'; }, 80); };
  f.player.pause = async () => { calls.push('pause'); setTimeout(() => { f.state.status = 'paused'; }, 80); };
  const first = await f.bridge.command({ action: 'toggle' });
  const second = await f.bridge.command({ action: 'toggle' });
  assert.deepEqual(calls, ['resume', 'pause']);
  assert.equal(first.ok, true); assert.equal(first.snapshot.isPlaying, true);
  assert.equal(second.ok, true); assert.equal(second.snapshot.isPlaying, false);
  assert.equal(f.state.status, 'paused');
});

test('dispose прерывает ожидание play без повторного resume', async () => {
  const f = fixture();
  let calls = 0;
  f.player.resume = async () => { calls++; };
  const pending = f.bridge.command({ action: 'play' });
  setTimeout(() => f.bridge.dispose(), 20);
  const result = await pending;
  assert.equal(result.ok, false); assert.equal(result.error, 'disposed');
  assert.equal(calls, 1);
});
