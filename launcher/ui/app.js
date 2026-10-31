const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;
let state = null;

const get = (o, path) => path.split('.').reduce((a, k) => a[k], o);
const set = (o, path, v) => { const ks = path.split('.'); const last = ks.pop(); ks.reduce((a, k) => a[k], o)[last] = v; };
const $ = (id) => document.getElementById(id);
const msg = (t) => { $('msg').textContent = t; };

async function refresh() {
  state = await invoke('get_state');
  $('arma').textContent = state.arma_dir ? `Arma 3: ${state.arma_dir}` : `Arma 3 not found: ${state.error}`;
  $('release').textContent = state.release ? `Release ${state.release}` : 'No release synced';
  $('server').textContent = state.server ? `${state.server.name} · ${state.server.host}:${state.server.port}` : '—';
  $('lo').classList.toggle('hidden', state.launch_options_ok);
  $('cdn').value = state.cdn_base; $('channel').value = state.channel; $('password').value = state.password;
  document.querySelectorAll('[data-t]').forEach((el) => {
    const v = get(state.toggles, el.dataset.t);
    if (el.type === 'checkbox') el.checked = !!v; else el.value = v === null || v === undefined ? '' : String(v);
  });
  const p = $('preset'); p.innerHTML = '';
  for (const pr of state.presets) { const o = document.createElement('option'); o.value = pr.id; o.textContent = pr.name; p.appendChild(o); }
  p.value = state.toggles.preset;
  $('launch').disabled = !state.release || !state.arma_dir;
}

async function save() {
  document.querySelectorAll('[data-t]').forEach((el) => {
    let v = el.type === 'checkbox' ? el.checked : el.value;
    if (el.dataset.opt && v === '') v = null;
    else if (el.dataset.num) v = Number(v);
    set(state.toggles, el.dataset.t, v);
  });
  if ($('preset').value) state.toggles.preset = $('preset').value;
  await invoke('save_settings', { toggles: state.toggles, cdnBase: $('cdn').value, channel: $('channel').value, password: $('password').value });
  await refresh();
}

document.querySelectorAll('input, select').forEach((el) => el.addEventListener('change', save));
listen('sync-progress', (e) => { const { done, total, path } = e.payload; $('bar').classList.remove('hidden'); $('bar').max = total || 1; $('bar').value = done; msg(path); });
$('sync').onclick = async () => { msg('Syncing…'); try { msg(`Synced ${await invoke('sync')}`); } catch (e) { msg(`Sync failed: ${e}`); } $('bar').classList.add('hidden'); refresh(); };
$('launch').onclick = async () => { $('launch').disabled = true; msg('Arma running — the game folder is restored when it exits…');
  try { const r = await invoke('launch'); msg(r === 'exited' ? 'Session ended, game folder restored.' : 'Arma did not start; session files removed.'); }
  catch (e) { msg(`Launch failed: ${e}`); } refresh(); };
$('repair').onclick = async () => { msg((await invoke('repair')) ? 'Cleaned a leftover session.' : 'Nothing to repair.'); };
$('fix').onclick = async () => { try { await invoke('apply_launch_options'); msg('Launch options updated.'); } catch (e) { msg(String(e)); } refresh(); };
refresh();
