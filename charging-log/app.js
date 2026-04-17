const LS_KEY = "ev_charging_log_v1";

const state = {
  vehicles: [],
  charging: [],
  editId: null,
};

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

function load() {
  const raw = localStorage.getItem(LS_KEY);
  if (raw) {
    try {
      const data = JSON.parse(raw);
      state.vehicles = data.vehicles || [];
      state.charging = data.charging || [];
      return;
    } catch (e) {
      console.warn("Bad localStorage, resetting", e);
    }
  }
  state.vehicles = [{ model: "BYD Atto3", battery_kwh: 60.5, range_km: 477.95 }];
  state.charging = [];
}

function save() {
  localStorage.setItem(
    LS_KEY,
    JSON.stringify({ vehicles: state.vehicles, charging: state.charging }),
  );
}

function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
}

function parseChargerKw(s) {
  if (!s) return null;
  const m = String(s).match(/([\d.]+)/);
  return m ? parseFloat(m[1]) : null;
}

function formatDate(iso) {
  if (!iso) return "";
  return iso.slice(0, 10);
}

function hoursBetween(a, b) {
  if (!a || !b) return null;
  const ms = new Date(b) - new Date(a);
  return ms > 0 ? ms / 3600000 : null;
}

function formatHours(h) {
  if (h == null) return "";
  const hh = Math.floor(h);
  const mm = Math.round((h - hh) * 60);
  return `${hh}h ${mm}m`;
}

function num(v, digits = 2) {
  if (v == null || isNaN(v)) return "";
  return Number(v).toFixed(digits);
}

function enrich(entries) {
  const sorted = [...entries].sort((a, b) => {
    const da = a.time_start || a.date;
    const db = b.time_start || b.date;
    return new Date(da) - new Date(db);
  });

  let prev = null;
  for (const e of sorted) {
    const battery = vehicleBattery(e.vehicle);
    if (
      battery &&
      e.actual_charged_pct != null &&
      (e.actual_kwh == null || e.actual_kwh === "")
    ) {
      e.actual_kwh = battery * e.actual_charged_pct;
    }
    if (e.actual_hours == null) {
      e.actual_hours = hoursBetween(e.time_start, e.actual_end);
    }
    if (
      e.actual_kw == null &&
      e.actual_kwh != null &&
      e.actual_hours != null &&
      e.actual_hours > 0
    ) {
      e.actual_kw = e.actual_kwh / e.actual_hours;
    }

    if (prev && prev.odo != null && e.odo != null) {
      e.km_since_last = e.odo - prev.odo;
      const prevDate = new Date(prev.date);
      const curDate = new Date(e.date);
      e.days_since_last = Math.round(
        (curDate - prevDate) / (1000 * 60 * 60 * 24),
      );
      if (prev.actual_kwh && prev.actual_kwh > 0 && e.km_since_last > 0) {
        prev.km_per_kwh = e.km_since_last / prev.actual_kwh;
      }
    }
    prev = e;
  }
  return sorted;
}

function vehicleBattery(model) {
  const v = state.vehicles.find((x) => x.model === model);
  return v && v.battery_kwh ? v.battery_kwh : null;
}

function renderVehicles() {
  const list = $("#vehicle-list");
  list.innerHTML = "";
  state.vehicles.forEach((v, i) => {
    const li = document.createElement("li");
    const meta = [
      v.battery_kwh ? `${v.battery_kwh} kWh` : null,
      v.range_km ? `${v.range_km} km` : null,
    ]
      .filter(Boolean)
      .join(" · ");
    li.innerHTML = `<span><strong>${v.model}</strong> <span class="meta">${meta}</span></span>
      <button class="ghost" data-action="del-vehicle" data-idx="${i}">✕</button>`;
    list.appendChild(li);
  });

  const sel = $("#vehicle-select");
  sel.innerHTML = state.vehicles
    .map((v) => `<option value="${v.model}">${v.model}</option>`)
    .join("");
}

function renderStats() {
  const el = $("#stats");
  const all = state.charging;
  const totalKwh = all.reduce((s, e) => s + (e.actual_kwh || 0), 0);
  const totalCost = all.reduce((s, e) => s + (e.cost_php || 0), 0);
  const costPerKwh = totalKwh > 0 ? totalCost / totalKwh : null;
  const withEff = all.filter((e) => e.km_per_kwh > 0).map((e) => e.km_per_kwh);
  const avgEff =
    withEff.length > 0 ? withEff.reduce((a, b) => a + b, 0) / withEff.length : null;
  const odos = all.map((e) => e.odo).filter((o) => o != null);
  const lifetimeKm = odos.length >= 2 ? Math.max(...odos) - Math.min(...odos) : null;
  const sessions = all.length;

  const cards = [
    { label: "Sessions", value: sessions, sub: "total logged" },
    { label: "Total kWh", value: num(totalKwh, 1), sub: "lifetime" },
    { label: "Total spend", value: `₱${num(totalCost, 0)}`, sub: "all chargers" },
    {
      label: "Avg ₱/kWh",
      value: costPerKwh ? `₱${num(costPerKwh, 2)}` : "—",
      sub: "overall cost",
    },
    {
      label: "Avg km/kWh",
      value: avgEff ? num(avgEff, 2) : "—",
      sub: "efficiency",
    },
    {
      label: "Distance tracked",
      value: lifetimeKm ? `${lifetimeKm} km` : "—",
      sub: "from ODO entries",
    },
  ];

  el.innerHTML = cards
    .map(
      (c) => `<div class="stat">
        <div class="label">${c.label}</div>
        <div class="value">${c.value}</div>
        <div class="sub">${c.sub}</div>
      </div>`,
    )
    .join("");
}

function renderHistory() {
  const tbody = $("#history-table tbody");
  const rows = enrich(state.charging).slice().reverse();
  tbody.innerHTML = "";
  rows.forEach((e) => {
    const tr = document.createElement("tr");
    const startEnd =
      e.start_pct != null && e.actual_final_pct != null
        ? `${Math.round(e.start_pct * 100)}→${Math.round(e.actual_final_pct * 100)}%`
        : e.start_pct != null
        ? `${Math.round(e.start_pct * 100)}%`
        : "";
    tr.innerHTML = `
      <td>${formatDate(e.date)}</td>
      <td>${e.vehicle || ""}</td>
      <td>${e.odo ?? ""}</td>
      <td>${startEnd}</td>
      <td>${num(e.actual_kwh, 2)}</td>
      <td>${num(e.actual_kw, 2)}</td>
      <td>${formatHours(e.actual_hours)}</td>
      <td>${e.location || ""}</td>
      <td>${e.cost_php != null ? num(e.cost_php, 2) : ""}</td>
      <td>${num(e.km_per_kwh, 2)}</td>
      <td>${e.km_since_last ?? ""}</td>
      <td>${e.notes || ""}</td>
      <td class="row-actions">
        <button class="ghost" data-action="edit" data-id="${e.id}">✎</button>
        <button class="danger" data-action="del" data-id="${e.id}">✕</button>
      </td>`;
    tbody.appendChild(tr);
  });
}

function render() {
  renderVehicles();
  renderStats();
  renderHistory();
}

function normalizePct(v) {
  if (v == null || v === "") return null;
  const n = parseFloat(v);
  if (isNaN(n)) return null;
  return n > 1 ? n / 100 : n;
}

function readForm() {
  const f = $("#charge-form");
  const fd = new FormData(f);
  const get = (k) => {
    const v = fd.get(k);
    return v === "" ? null : v;
  };
  const numOrNull = (k) => {
    const v = get(k);
    return v == null ? null : parseFloat(v);
  };

  const start = normalizePct(get("start_pct"));
  const target = normalizePct(get("target_pct"));
  const final = normalizePct(get("actual_final_pct"));

  const entry = {
    id: state.editId || uid(),
    date: get("date") ? new Date(get("date")).toISOString() : null,
    vehicle: get("vehicle"),
    odo: numOrNull("odo"),
    start_pct: start,
    target_pct: target,
    needed_pct: target != null && start != null ? +(target - start).toFixed(4) : null,
    charger: get("charger"),
    time_start: get("time_start") ? new Date(get("time_start")).toISOString() : null,
    actual_end: get("actual_end") ? new Date(get("actual_end")).toISOString() : null,
    actual_final_pct: final,
    actual_charged_pct:
      final != null && start != null ? +(final - start).toFixed(4) : null,
    location: get("location"),
    cost_php: numOrNull("cost_php"),
    notes: get("notes"),
  };
  const battery = vehicleBattery(entry.vehicle);
  if (battery) {
    if (entry.needed_pct != null) entry.kwh_needed = +(battery * entry.needed_pct).toFixed(3);
    if (entry.actual_charged_pct != null)
      entry.actual_kwh = +(battery * entry.actual_charged_pct).toFixed(3);
  }
  const kw = parseChargerKw(entry.charger);
  if (kw && entry.kwh_needed) {
    entry.est_hours = +(entry.kwh_needed / kw).toFixed(3);
  }
  entry.actual_hours = hoursBetween(entry.time_start, entry.actual_end);
  if (entry.actual_kwh && entry.actual_hours && entry.actual_hours > 0) {
    entry.actual_kw = +(entry.actual_kwh / entry.actual_hours).toFixed(3);
  }
  return entry;
}

function fillForm(entry) {
  const f = $("#charge-form");
  const toDateInput = (iso) => (iso ? iso.slice(0, 10) : "");
  const toDatetimeInput = (iso) => {
    if (!iso) return "";
    const d = new Date(iso);
    const pad = (n) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };
  f.date.value = toDateInput(entry.date);
  f.vehicle.value = entry.vehicle || "";
  f.odo.value = entry.odo ?? "";
  f.start_pct.value = entry.start_pct != null ? Math.round(entry.start_pct * 100) : "";
  f.target_pct.value = entry.target_pct != null ? Math.round(entry.target_pct * 100) : "";
  f.actual_final_pct.value =
    entry.actual_final_pct != null ? Math.round(entry.actual_final_pct * 100) : "";
  f.charger.value = entry.charger || "";
  f.time_start.value = toDatetimeInput(entry.time_start);
  f.actual_end.value = toDatetimeInput(entry.actual_end);
  f.cost_php.value = entry.cost_php ?? "";
  f.location.value = entry.location || "";
  f.notes.value = entry.notes || "";
}

function resetForm() {
  $("#charge-form").reset();
  $("#charge-form").date.valueAsDate = new Date();
  state.editId = null;
  $("#cancel-edit").hidden = true;
}

function handleSubmit(e) {
  e.preventDefault();
  const entry = readForm();
  if (state.editId) {
    const idx = state.charging.findIndex((x) => x.id === state.editId);
    if (idx >= 0) state.charging[idx] = entry;
  } else {
    state.charging.push(entry);
  }
  save();
  resetForm();
  render();
}

function handleTableClick(e) {
  const btn = e.target.closest("button[data-action]");
  if (!btn) return;
  const id = btn.dataset.id;
  if (btn.dataset.action === "del") {
    if (confirm("Delete this entry?")) {
      state.charging = state.charging.filter((x) => x.id !== id);
      save();
      render();
    }
  } else if (btn.dataset.action === "edit") {
    const entry = state.charging.find((x) => x.id === id);
    if (entry) {
      state.editId = id;
      fillForm(entry);
      $("#cancel-edit").hidden = false;
      $("#charge-form").scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }
}

function handleVehicleSubmit(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  const model = fd.get("model").trim();
  if (!model) return;
  const existing = state.vehicles.findIndex((v) => v.model === model);
  const record = {
    model,
    battery_kwh: fd.get("battery_kwh") ? parseFloat(fd.get("battery_kwh")) : null,
    range_km: fd.get("range_km") ? parseFloat(fd.get("range_km")) : null,
  };
  if (existing >= 0) state.vehicles[existing] = record;
  else state.vehicles.push(record);
  save();
  e.target.reset();
  render();
}

function handleVehicleListClick(e) {
  const btn = e.target.closest("button[data-action='del-vehicle']");
  if (!btn) return;
  const idx = parseInt(btn.dataset.idx, 10);
  const v = state.vehicles[idx];
  if (!v) return;
  if (confirm(`Remove vehicle "${v.model}"?`)) {
    state.vehicles.splice(idx, 1);
    save();
    render();
  }
}

function exportJSON() {
  const blob = new Blob(
    [JSON.stringify({ vehicles: state.vehicles, charging: state.charging }, null, 2)],
    { type: "application/json" },
  );
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `ev-charging-log-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

function importJSON(file) {
  const reader = new FileReader();
  reader.onload = (ev) => {
    try {
      const data = JSON.parse(ev.target.result);
      if (!confirm("Replace current data with imported file?")) return;
      state.vehicles = data.vehicles || [];
      state.charging = (data.charging || []).map((e) => ({ ...e, id: e.id || uid() }));
      save();
      render();
    } catch (err) {
      alert("Invalid JSON file");
    }
  };
  reader.readAsText(file);
}

async function loadSeed() {
  if (
    state.charging.length > 0 &&
    !confirm("This will merge seed data with existing entries. Continue?")
  ) {
    return;
  }
  try {
    const r = await fetch("seed.json");
    const data = await r.json();
    const existingIds = new Set(state.charging.map((x) => x.id));
    for (const e of data.charging || []) {
      if (!e.id) e.id = uid();
      if (!existingIds.has(e.id)) state.charging.push(e);
    }
    for (const v of data.vehicles || []) {
      if (!state.vehicles.find((x) => x.model === v.model)) state.vehicles.push(v);
    }
    save();
    render();
  } catch (err) {
    alert("Could not load seed.json");
  }
}

function clearAll() {
  if (!confirm("Delete ALL entries and vehicles?")) return;
  state.vehicles = [];
  state.charging = [];
  save();
  load();
  render();
}

function init() {
  load();
  render();
  resetForm();

  $("#charge-form").addEventListener("submit", handleSubmit);
  $("#cancel-edit").addEventListener("click", resetForm);
  $("#history-table").addEventListener("click", handleTableClick);
  $("#vehicle-form").addEventListener("submit", handleVehicleSubmit);
  $("#vehicle-list").addEventListener("click", handleVehicleListClick);
  $("#export-btn").addEventListener("click", exportJSON);
  $("#import-input").addEventListener("change", (e) => {
    if (e.target.files[0]) importJSON(e.target.files[0]);
    e.target.value = "";
  });
  $("#load-seed-btn").addEventListener("click", loadSeed);
  $("#clear-btn").addEventListener("click", clearAll);
}

document.addEventListener("DOMContentLoaded", init);
