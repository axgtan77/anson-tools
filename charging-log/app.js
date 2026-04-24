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

function getChargerValue() {
  const preset = $("#charger-preset");
  if (preset.value === "__other__") {
    return $("#charger-custom").value.trim() || null;
  }
  return preset.value || null;
}

function setChargerValue(value) {
  const preset = $("#charger-preset");
  const custom = $("#charger-custom");
  if (!value) {
    preset.value = "6.1 Kw";
    custom.hidden = true;
    custom.value = "";
    return;
  }
  const match = [...preset.options].find(
    (o) => o.value !== "__other__" && o.value === value,
  );
  if (match) {
    preset.value = value;
    custom.hidden = true;
    custom.value = "";
  } else {
    preset.value = "__other__";
    custom.hidden = false;
    custom.value = value;
  }
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

function getLastOdo(model, excludeId) {
  const candidates = state.charging
    .filter((e) => e.vehicle === model && e.odo != null && e.id !== excludeId)
    .sort((a, b) => {
      const da = new Date(a.time_start || a.date);
      const db = new Date(b.time_start || b.date);
      if (da - db !== 0) return db - da;
      return (b.odo || 0) - (a.odo || 0);
    });
  return candidates[0] || null;
}

function updateEndHint() {
  const el = $("#end-hint");
  if (!el) return;
  const f = $("#charge-form");
  const s = f.time_start.value;
  const e = f.actual_end.value;
  if (!s || !e) {
    el.textContent = "";
    return;
  }
  const [sh, sm] = s.split(":").map(Number);
  const [eh, em] = e.split(":").map(Number);
  if (eh * 60 + em < sh * 60 + sm) {
    el.textContent = "→ next day";
    el.className = "hint warn";
  } else {
    el.textContent = "";
  }
}

function getDCEffectiveRate(maxKw, soc) {
  if (soc < 20) return maxKw * 0.85;
  if (soc < 50) return maxKw;
  if (soc < 65) return maxKw * 0.9;
  if (soc < 80) return maxKw * 0.65;
  if (soc < 90) return maxKw * 0.35;
  return maxKw * 0.18;
}

function updateEstEndTime() {
  const el = $("#est-end-hint");
  if (!el) return;
  const f = $("#charge-form");
  const startTime = f.time_start.value;
  const startPct = parseFloat(f.start_pct.value);
  const targetPct = parseFloat(f.target_pct.value);
  const chargerStr = getChargerValue();
  const kw = parseChargerKw(chargerStr);
  const battery = vehicleBattery(f.vehicle.value);

  if (!startTime || isNaN(startPct) || isNaN(targetPct) || !kw || !battery || targetPct <= startPct) {
    el.textContent = "";
    return;
  }

  const fromFrac = startPct / 100;
  const toFrac = targetPct / 100;
  const isDC = kw > 22;
  let totalMinutes = 0;

  if (isDC) {
    for (let soc = fromFrac * 100; soc < toFrac * 100; soc += 1) {
      const energyStep = (1 / 100) * battery;
      const rate = getDCEffectiveRate(kw, soc);
      totalMinutes += (energyStep / rate) * 60;
    }
  } else {
    const energyNeeded = (toFrac - fromFrac) * battery;
    totalMinutes = (energyNeeded / kw) * 60;
  }

  const [sh, sm] = startTime.split(":").map(Number);
  const endTotalMin = sh * 60 + sm + Math.round(totalMinutes);
  const endH = Math.floor(endTotalMin / 60) % 24;
  const endM = endTotalMin % 60;
  const nextDay = endTotalMin >= 1440;

  const hours = Math.floor(totalMinutes / 60);
  const mins = Math.round(totalMinutes % 60);
  let durStr = "";
  if (hours > 0) durStr += `${hours}h `;
  durStr += `${mins}m`;

  const endStr = `${String(endH).padStart(2, "0")}:${String(endM).padStart(2, "0")}`;
  el.textContent = `Est. ${durStr} → ready by ${endStr}${nextDay ? " (+1 day)" : ""}`;
  el.className = "hint est";
}

function updateOdoHint() {
  const hint = $("#odo-hint");
  if (!hint) return;
  const f = $("#charge-form");
  const model = f.vehicle.value;
  const last = getLastOdo(model, state.editId);
  if (!last) {
    hint.textContent = "No previous ODO logged for this vehicle.";
    hint.className = "hint";
    return;
  }
  const dateStr = formatDate(last.date);
  const cur = parseFloat(f.odo.value);
  let text = `Last: ${last.odo} km on ${dateStr}`;
  let cls = "hint";
  if (!isNaN(cur)) {
    if (cur < last.odo) {
      text += ` — current is ${last.odo - cur} km LESS than last`;
      cls = "hint error";
    } else if (cur > last.odo) {
      text += ` — +${cur - last.odo} km since`;
    }
  }
  hint.textContent = text;
  hint.className = cls;
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
  const cardsEl = $("#history-cards");
  const rows = enrich(state.charging).slice().reverse();
  tbody.innerHTML = "";
  cardsEl.innerHTML = "";

  if (rows.length === 0) {
    cardsEl.innerHTML = `<p style="color:var(--text-dim);text-align:center;padding:20px">No entries yet. Add one in the <strong>Log</strong> tab, or tap <strong>Load Seed</strong> above.</p>`;
  }

  rows.forEach((e) => {
    const startEnd =
      e.start_pct != null && e.actual_final_pct != null
        ? `${Math.round(e.start_pct * 100)}→${Math.round(e.actual_final_pct * 100)}%`
        : e.start_pct != null
        ? `${Math.round(e.start_pct * 100)}%`
        : "";

    const tr = document.createElement("tr");
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

    const card = document.createElement("div");
    card.className = "entry";
    card.innerHTML = `
      <div class="entry-top">
        <span class="entry-date">${formatDate(e.date)}</span>
        <span class="entry-badge">${e.vehicle || ""}${e.location ? " · " + e.location : ""}</span>
      </div>
      <div class="entry-row">
        <div><div class="k">Charge</div><div class="v">${startEnd || "—"}</div></div>
        <div><div class="k">kWh</div><div class="v">${num(e.actual_kwh, 2) || "—"}</div></div>
        <div><div class="k">Cost</div><div class="v">${e.cost_php != null ? "₱" + num(e.cost_php, 0) : "—"}</div></div>
        <div><div class="k">Duration</div><div class="v">${formatHours(e.actual_hours) || "—"}</div></div>
        <div><div class="k">Rate</div><div class="v">${e.actual_kw ? num(e.actual_kw, 1) + " kW" : "—"}</div></div>
        <div><div class="k">km/kWh</div><div class="v">${num(e.km_per_kwh, 2) || "—"}</div></div>
        <div><div class="k">ODO</div><div class="v">${e.odo ?? "—"}</div></div>
        <div><div class="k">km since</div><div class="v">${e.km_since_last ?? "—"}</div></div>
        <div><div class="k">Days</div><div class="v">${e.days_since_last ?? "—"}</div></div>
      </div>
      ${e.notes ? `<div class="entry-notes">${e.notes}</div>` : ""}
      <div class="entry-actions">
        <button class="ghost" data-action="edit" data-id="${e.id}">✎ Edit</button>
        <button class="danger" data-action="del" data-id="${e.id}">✕ Delete</button>
      </div>`;
    cardsEl.appendChild(card);
  });
}

function render() {
  renderVehicles();
  renderStats();
  renderHistory();
  renderCharts();
  updateOdoHint();
  updateEndHint();
  updateEstEndTime();
}

const chartRefs = {};

function monthKey(iso) {
  if (!iso) return null;
  return iso.slice(0, 7);
}

function groupMonthly(entries, valueFn) {
  const map = new Map();
  entries.forEach((e) => {
    const k = monthKey(e.date);
    if (!k) return;
    const v = valueFn(e);
    if (v == null || isNaN(v)) return;
    map.set(k, (map.get(k) || 0) + v);
  });
  return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
}

function renderCharts() {
  if (typeof Chart === "undefined") return;
  const data = enrich(state.charging);
  const palette = {
    accent: "#4cc38a",
    accentDim: "rgba(76, 195, 138, 0.35)",
    warn: "#e0b04c",
    warnDim: "rgba(224, 176, 76, 0.35)",
    text: "#9aa0a6",
    grid: "#2a2f3a",
  };
  Chart.defaults.color = palette.text;
  Chart.defaults.borderColor = palette.grid;
  Chart.defaults.font.family =
    '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';

  // Cost per month
  const costByMonth = groupMonthly(data, (e) => e.cost_php);
  upsertChart("chart-cost", "bar", {
    labels: costByMonth.map(([k]) => k),
    datasets: [{
      label: "₱",
      data: costByMonth.map(([, v]) => Math.round(v)),
      backgroundColor: palette.accentDim,
      borderColor: palette.accent,
      borderWidth: 1,
    }],
  });

  // kWh per month
  const kwhByMonth = groupMonthly(data, (e) => e.actual_kwh);
  upsertChart("chart-kwh", "bar", {
    labels: kwhByMonth.map(([k]) => k),
    datasets: [{
      label: "kWh",
      data: kwhByMonth.map(([, v]) => +v.toFixed(1)),
      backgroundColor: palette.warnDim,
      borderColor: palette.warn,
      borderWidth: 1,
    }],
  });

  // Efficiency trend (per-session km/kWh)
  const effRows = data
    .filter((e) => e.km_per_kwh > 0)
    .sort((a, b) => new Date(a.date) - new Date(b.date));
  upsertChart("chart-eff", "line", {
    labels: effRows.map((e) => formatDate(e.date)),
    datasets: [{
      label: "km/kWh",
      data: effRows.map((e) => +e.km_per_kwh.toFixed(2)),
      borderColor: palette.accent,
      backgroundColor: palette.accentDim,
      tension: 0.3,
      pointRadius: 3,
      fill: true,
    }],
  });

  // Cost by location
  const locMap = new Map();
  data.forEach((e) => {
    if (!e.location || e.cost_php == null) return;
    locMap.set(e.location, (locMap.get(e.location) || 0) + e.cost_php);
  });
  const locEntries = [...locMap.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8);
  upsertChart("chart-loc", "bar", {
    labels: locEntries.map(([k]) => k),
    datasets: [{
      label: "₱",
      data: locEntries.map(([, v]) => Math.round(v)),
      backgroundColor: palette.accentDim,
      borderColor: palette.accent,
      borderWidth: 1,
    }],
  }, { indexAxis: "y" });
}

function upsertChart(canvasId, type, data, extraOpts = {}) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;
  if (chartRefs[canvasId]) {
    chartRefs[canvasId].data = data;
    Object.assign(chartRefs[canvasId].options, extraOpts);
    chartRefs[canvasId].update();
    return;
  }
  chartRefs[canvasId] = new Chart(canvas, {
    type,
    data,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: "rgba(255,255,255,0.06)" } },
        y: { grid: { color: "rgba(255,255,255,0.06)" }, beginAtZero: true },
      },
      ...extraOpts,
    },
  });
}

function combineDateTime(dateStr, timeStr, startTimeStr) {
  if (!dateStr || !timeStr) return null;
  const [y, m, d] = dateStr.split("-").map(Number);
  const [hh, mm] = timeStr.split(":").map(Number);
  const dt = new Date(y, m - 1, d, hh, mm, 0, 0);
  if (startTimeStr) {
    const [sh, sm] = startTimeStr.split(":").map(Number);
    const startMinutes = sh * 60 + sm;
    const endMinutes = hh * 60 + mm;
    if (endMinutes < startMinutes) {
      dt.setDate(dt.getDate() + 1);
    }
  }
  return dt.toISOString();
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
    charger: getChargerValue(),
    time_start: combineDateTime(get("date"), get("time_start")),
    actual_end: combineDateTime(get("date"), get("actual_end"), get("time_start")),
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
  const toTimeInput = (iso) => {
    if (!iso) return "";
    const d = new Date(iso);
    const pad = (n) => String(n).padStart(2, "0");
    return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };
  f.date.value = toDateInput(entry.date);
  f.vehicle.value = entry.vehicle || "";
  f.odo.value = entry.odo ?? "";
  f.start_pct.value = entry.start_pct != null ? Math.round(entry.start_pct * 100) : "";
  f.target_pct.value = entry.target_pct != null ? Math.round(entry.target_pct * 100) : "";
  f.actual_final_pct.value =
    entry.actual_final_pct != null ? Math.round(entry.actual_final_pct * 100) : "";
  setChargerValue(entry.charger);
  f.time_start.value = toTimeInput(entry.time_start);
  f.actual_end.value = toTimeInput(entry.actual_end);
  f.cost_php.value = entry.cost_php ?? "";
  f.location.value = entry.location || "";
  f.notes.value = entry.notes || "";
  updateOdoHint();
  updateEstEndTime();
}

function resetForm() {
  $("#charge-form").reset();
  $("#charge-form").date.valueAsDate = new Date();
  setChargerValue(null);
  state.editId = null;
  $("#cancel-edit").hidden = true;
  updateOdoHint();
}

function duplicateLast() {
  if (state.charging.length === 0) {
    alert("No previous entries to copy from.");
    return;
  }
  const sorted = [...state.charging].sort(
    (a, b) => new Date(b.time_start || b.date) - new Date(a.time_start || a.date),
  );
  const last = sorted[0];
  resetForm();
  const f = $("#charge-form");
  f.vehicle.value = last.vehicle || "";
  f.location.value = last.location || "";
  setChargerValue(last.charger);
  updateOdoHint();
  f.odo.focus();
}

function handleSubmit(e) {
  e.preventDefault();
  const entry = readForm();
  const wasEditing = !!state.editId;
  if (state.editId) {
    const idx = state.charging.findIndex((x) => x.id === state.editId);
    if (idx >= 0) state.charging[idx] = entry;
  } else {
    state.charging.push(entry);
  }
  save();
  resetForm();
  render();
  if (!wasEditing) switchTab("history");
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
      switchTab("log");
    }
  }
}

function switchTab(name) {
  $$(".tab").forEach((t) =>
    t.classList.toggle("active", t.dataset.tab === name),
  );
  $$(".tab-panel").forEach((p) =>
    p.classList.toggle("active", p.dataset.panel === name),
  );
  window.scrollTo({ top: 0 });
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
  $("#duplicate-last").addEventListener("click", duplicateLast);
  $("#history-table").addEventListener("click", handleTableClick);
  $("#history-cards").addEventListener("click", handleTableClick);
  $("#tabs").addEventListener("click", (e) => {
    const tab = e.target.closest(".tab");
    if (tab) switchTab(tab.dataset.tab);
  });
  $("#charge-form").vehicle.addEventListener("change", () => { updateOdoHint(); updateEstEndTime(); });
  $("#charge-form").odo.addEventListener("input", updateOdoHint);
  $("#charge-form").time_start.addEventListener("input", () => { updateEndHint(); updateEstEndTime(); });
  $("#charge-form").actual_end.addEventListener("input", updateEndHint);
  $("#charge-form").start_pct.addEventListener("input", updateEstEndTime);
  $("#charge-form").target_pct.addEventListener("input", updateEstEndTime);
  $("#charger-preset").addEventListener("change", (e) => {
    const custom = $("#charger-custom");
    if (e.target.value === "__other__") {
      custom.hidden = false;
      custom.focus();
    } else {
      custom.hidden = true;
      custom.value = "";
    }
    updateEstEndTime();
  });
  $("#charger-custom").addEventListener("input", updateEstEndTime);
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

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch((err) => {
      console.warn("Service worker registration failed:", err);
    });
  });
}
