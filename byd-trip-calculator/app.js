// BYD Atto 3 Trip Calculator

// EV model database: battery capacity (kWh) and real-world consumption rates (kWh/100km)
// Calibrated from BYD Atto 3 real data: QC to Paniqui Tarlac ROUND TRIP (~320km),
// 4 passengers, AC on, phone charging = 80% battery used → ~15.1 kWh/100km all-in,
// base ~12.2 kWh/100km. Other models scaled proportionally by efficiency class.
const EV_MODELS = {
    'byd-atto3': {
        name: 'BYD Atto 3',
        battery: 60.48,
        range: 420,
        consumption: { eco: 10.5, normal: 12.5, sport: 15.5 },
        motor: '150 kW / 201 hp',
        fastCharge: '80 kW (30-80% in 29 min)',
    },
    'byd-seal': {
        name: 'BYD Seal',
        battery: 82.56,
        range: 570,
        consumption: { eco: 10.0, normal: 12.0, sport: 15.0 },
        motor: '230 kW / 308 hp',
        fastCharge: '150 kW (30-80% in 26 min)',
    },
    'byd-dolphin': {
        name: 'BYD Dolphin',
        battery: 60.48,
        range: 427,
        consumption: { eco: 9.5, normal: 11.5, sport: 14.0 },
        motor: '150 kW / 201 hp',
        fastCharge: '80 kW (30-80% in 29 min)',
    },
    'byd-han': {
        name: 'BYD Han',
        battery: 85.44,
        range: 521,
        consumption: { eco: 11.5, normal: 13.5, sport: 16.5 },
        motor: '380 kW / 510 hp (AWD)',
        fastCharge: '120 kW (30-80% in 28 min)',
    },
    'tesla-model3-lr': {
        name: 'Tesla Model 3 Long Range',
        battery: 78.1,
        range: 629,
        consumption: { eco: 9.0, normal: 11.0, sport: 13.5 },
        motor: '366 kW / 491 hp (AWD)',
        fastCharge: '250 kW (30-80% in 22 min)',
    },
    'tesla-modely-lr': {
        name: 'Tesla Model Y Long Range',
        battery: 78.1,
        range: 533,
        consumption: { eco: 10.0, normal: 12.0, sport: 15.0 },
        motor: '378 kW / 507 hp (AWD)',
        fastCharge: '250 kW (30-80% in 25 min)',
    },
    'tesla-model3-sr': {
        name: 'Tesla Model 3 Standard Range',
        battery: 60.0,
        range: 513,
        consumption: { eco: 8.5, normal: 10.5, sport: 13.0 },
        motor: '208 kW / 279 hp',
        fastCharge: '170 kW (30-80% in 20 min)',
    },
    'mg4-lr': {
        name: 'MG4 Long Range',
        battery: 64.0,
        range: 450,
        consumption: { eco: 10.0, normal: 12.0, sport: 14.5 },
        motor: '150 kW / 201 hp',
        fastCharge: '135 kW (30-80% in 26 min)',
    },
    'hyundai-ioniq5-lr': {
        name: 'Hyundai Ioniq 5 Long Range',
        battery: 77.4,
        range: 507,
        consumption: { eco: 10.5, normal: 12.5, sport: 15.5 },
        motor: '225 kW / 302 hp',
        fastCharge: '240 kW (10-80% in 18 min)',
    },
    'kia-ev6-lr': {
        name: 'Kia EV6 Long Range',
        battery: 77.4,
        range: 528,
        consumption: { eco: 10.0, normal: 12.0, sport: 15.0 },
        motor: '229 kW / 307 hp',
        fastCharge: '240 kW (10-80% in 18 min)',
    },
    'nissan-leaf-eplus': {
        name: 'Nissan Leaf e+',
        battery: 62.0,
        range: 385,
        consumption: { eco: 11.0, normal: 13.5, sport: 16.5 },
        motor: '160 kW / 214 hp',
        fastCharge: '46 kW (30-80% in 45 min)',
    },
    'volvo-ex30': {
        name: 'Volvo EX30',
        battery: 69.0,
        range: 476,
        consumption: { eco: 10.0, normal: 12.0, sport: 14.5 },
        motor: '200 kW / 268 hp',
        fastCharge: '153 kW (10-80% in 26 min)',
    },
    'gac-aion-y-plus': {
        name: 'GAC Aion Y Plus',
        battery: 63.2,
        range: 490,
        consumption: { eco: 9.0, normal: 11.0, sport: 13.5 },
        motor: '150 kW / 201 hp',
        fastCharge: '80 kW (30-80% in 32 min)',
    },
    'chery-tiggo-8-pro-e': {
        name: 'Chery Tiggo 8 Pro e+',
        battery: 71.0,
        range: 410,
        consumption: { eco: 12.0, normal: 14.5, sport: 17.5 },
        motor: '155 kW / 208 hp',
        fastCharge: '80 kW (30-80% in 35 min)',
    },
    'geely-emgrand-ev': {
        name: 'Geely Emgrand EV',
        battery: 53.0,
        range: 400,
        consumption: { eco: 9.5, normal: 11.5, sport: 14.0 },
        motor: '100 kW / 134 hp',
        fastCharge: '60 kW (30-80% in 30 min)',
    },
    'geely-galaxy-e5': {
        name: 'Geely Galaxy E5',
        battery: 60.2,
        range: 440,
        consumption: { eco: 9.5, normal: 11.5, sport: 14.5 },
        motor: '160 kW / 215 hp',
        fastCharge: '115 kW (30-80% in 22 min)',
    },
    'zeekr-001-lr': {
        name: 'Zeekr 001 Long Range',
        battery: 100.0,
        range: 620,
        consumption: { eco: 11.0, normal: 13.5, sport: 16.5 },
        motor: '400 kW / 536 hp (AWD)',
        fastCharge: '200 kW (10-80% in 30 min)',
    },
    'zeekr-x': {
        name: 'Zeekr X',
        battery: 66.0,
        range: 440,
        consumption: { eco: 10.5, normal: 12.5, sport: 15.0 },
        motor: '200 kW / 268 hp',
        fastCharge: '150 kW (10-80% in 28 min)',
    },
    'denza-d9-ev': {
        name: 'Denza D9 EV',
        battery: 103.0,
        range: 570,
        consumption: { eco: 12.5, normal: 15.0, sport: 18.5 },
        motor: '230 kW / 308 hp',
        fastCharge: '166 kW (30-80% in 28 min)',
    },
    'xiaomi-su7': {
        name: 'Xiaomi SU7',
        battery: 73.6,
        range: 668,
        consumption: { eco: 8.0, normal: 10.0, sport: 12.5 },
        motor: '220 kW / 295 hp',
        fastCharge: '210 kW (10-80% in 24 min)',
    },
    'xiaomi-su7-max': {
        name: 'Xiaomi SU7 Max',
        battery: 101.0,
        range: 800,
        consumption: { eco: 9.0, normal: 11.0, sport: 14.0 },
        motor: '495 kW / 664 hp (AWD)',
        fastCharge: '210 kW (10-80% in 28 min)',
    },
};

let selectedModel = 'byd-atto3';

// Additional consumption factors
const AC_PENALTY = 2.0;           // kWh/100km extra with A/C (tropical climate)
const PASSENGER_PENALTY = 0.3;    // kWh/100km per extra passenger beyond 1

// State
let map;
let originMarker = null;
let destMarker = null;
let routeLine = null;
let originCoords = null;
let destCoords = null;
let clickMode = 'origin'; // 'origin' | 'dest' | null
let searchTimeout = null;

// DOM elements
const originInput = document.getElementById('origin-input');
const destInput = document.getElementById('dest-input');
const originSuggestions = document.getElementById('origin-suggestions');
const destSuggestions = document.getElementById('dest-suggestions');
const clearOriginBtn = document.getElementById('clear-origin');
const clearDestBtn = document.getElementById('clear-dest');
const swapBtn = document.getElementById('swap-btn');
const drivingStyleSelect = document.getElementById('driving-style');
const acToggle = document.getElementById('ac-toggle');
const passengersSelect = document.getElementById('passengers');
const batterySlider = document.getElementById('battery-level');
const batteryValue = document.getElementById('battery-value');
const resultsSection = document.getElementById('results-section');
const mapInstructions = document.getElementById('map-instructions');

// Initialize map
function initMap() {
    map = L.map('map', {
        center: [14.5995, 120.9842], // Manila, Philippines
        zoom: 12,
        zoomControl: true,
    });

    const cartoDark = L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; OpenStreetMap &copy; CARTO',
        maxZoom: 19,
    });

    const cartoVoyager = L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; OpenStreetMap &copy; CARTO',
        maxZoom: 19,
    });

    const osm = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19,
    });

    const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        attribution: '&copy; Esri &copy; Maxar',
        maxZoom: 19,
    });

    cartoDark.addTo(map);

    L.control.layers({
        'Dark': cartoDark,
        'Voyager': cartoVoyager,
        'Satellite': satellite,
        'OpenStreetMap': osm,
    }, null, { position: 'topright' }).addTo(map);

    map.on('click', onMapClick);
}

function createMarkerIcon(type) {
    return L.divIcon({
        className: '',
        html: `<div class="custom-marker ${type}"><span>${type === 'origin' ? 'A' : 'B'}</span></div>`,
        iconSize: [32, 32],
        iconAnchor: [16, 32],
    });
}

function onMapClick(e) {
    const { lat, lng } = e.latlng;

    if (clickMode === 'origin') {
        setOrigin(lat, lng);
        reverseGeocode(lat, lng, originInput);
        clickMode = 'dest';
        mapInstructions.innerHTML = 'Click the map to set <strong>Destination (B)</strong>';
    } else if (clickMode === 'dest') {
        setDestination(lat, lng);
        reverseGeocode(lat, lng, destInput);
        clickMode = null;
        mapInstructions.classList.add('hidden');
    } else {
        // After both set, clicking resets to origin
        clickMode = 'origin';
        setOrigin(lat, lng);
        reverseGeocode(lat, lng, originInput);
        clickMode = 'dest';
        mapInstructions.innerHTML = 'Click the map to set <strong>Destination (B)</strong>';
        mapInstructions.classList.remove('hidden');
    }
}

function setOrigin(lat, lng) {
    originCoords = [lat, lng];
    if (originMarker) map.removeLayer(originMarker);
    originMarker = L.marker([lat, lng], { icon: createMarkerIcon('origin') }).addTo(map);
    tryCalculateRoute();
}

function setDestination(lat, lng) {
    destCoords = [lat, lng];
    if (destMarker) map.removeLayer(destMarker);
    destMarker = L.marker([lat, lng], { icon: createMarkerIcon('dest') }).addTo(map);
    tryCalculateRoute();
}

// Geocoding via Nominatim (OpenStreetMap)
async function geocodeSearch(query, suggestionsEl, type) {
    if (query.length < 3) {
        suggestionsEl.classList.remove('active');
        return;
    }

    try {
        const res = await fetch(
            `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5&countrycodes=ph`,
            { headers: { 'Accept-Language': 'en' } }
        );
        const data = await res.json();

        suggestionsEl.innerHTML = '';
        if (data.length === 0) {
            suggestionsEl.classList.remove('active');
            return;
        }

        data.forEach((item) => {
            const div = document.createElement('div');
            div.className = 'suggestion-item';
            div.textContent = item.display_name;
            div.addEventListener('click', () => {
                const lat = parseFloat(item.lat);
                const lon = parseFloat(item.lon);
                if (type === 'origin') {
                    originInput.value = item.display_name;
                    setOrigin(lat, lon);
                    clickMode = destCoords ? null : 'dest';
                } else {
                    destInput.value = item.display_name;
                    setDestination(lat, lon);
                    clickMode = null;
                }
                suggestionsEl.classList.remove('active');
                map.setView([lat, lon], 13);
                updateMapInstructions();
            });
            suggestionsEl.appendChild(div);
        });
        suggestionsEl.classList.add('active');
    } catch (err) {
        console.error('Geocode error:', err);
    }
}

async function reverseGeocode(lat, lng, inputEl) {
    try {
        const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`,
            { headers: { 'Accept-Language': 'en' } }
        );
        const data = await res.json();
        if (data.display_name) {
            inputEl.value = data.display_name;
        } else {
            inputEl.value = `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
        }
    } catch {
        inputEl.value = `${lat.toFixed(5)}, ${lng.toFixed(5)}`;
    }
}

function updateMapInstructions() {
    if (!originCoords) {
        mapInstructions.innerHTML = 'Click the map to set <strong>Origin (A)</strong>';
        mapInstructions.classList.remove('hidden');
    } else if (!destCoords) {
        mapInstructions.innerHTML = 'Click the map to set <strong>Destination (B)</strong>';
        mapInstructions.classList.remove('hidden');
    } else {
        mapInstructions.classList.add('hidden');
    }
}

// Routing via OSRM
async function tryCalculateRoute() {
    if (!originCoords || !destCoords) return;

    try {
        const url = `https://router.project-osrm.org/route/v1/driving/${originCoords[1]},${originCoords[0]};${destCoords[1]},${destCoords[0]}?overview=full&geometries=geojson`;
        const res = await fetch(url);
        const data = await res.json();

        if (data.code !== 'Ok' || !data.routes.length) {
            console.error('Routing failed:', data);
            return;
        }

        const route = data.routes[0];
        const distanceKm = route.distance / 1000;
        const durationSec = route.duration;

        // Draw route on map
        if (routeLine) map.removeLayer(routeLine);
        routeLine = L.geoJSON(route.geometry, {
            style: {
                color: '#2196f3',
                weight: 5,
                opacity: 0.8,
            },
        }).addTo(map);

        // Fit map to route bounds
        const bounds = routeLine.getBounds().pad(0.1);
        map.fitBounds(bounds);

        // Calculate energy
        calculateEnergy(distanceKm, durationSec);
    } catch (err) {
        console.error('Route error:', err);
    }
}

function calculateEnergy(distanceKm, durationSec) {
    const model = EV_MODELS[selectedModel];
    const style = drivingStyleSelect.value;
    const acOn = acToggle.checked;
    const passengers = parseInt(passengersSelect.value);
    const batteryPercent = parseInt(batterySlider.value);

    // Compute effective consumption
    let consumption = model.consumption[style];
    if (acOn) consumption += AC_PENALTY;
    if (passengers > 1) consumption += (passengers - 1) * PASSENGER_PENALTY;

    const energyNeeded = (distanceKm * consumption) / 100;
    const availableEnergy = (batteryPercent / 100) * model.battery;
    const batteryUsedPercent = (energyNeeded / model.battery) * 100;
    const batteryRemainingPercent = batteryPercent - batteryUsedPercent;

    // Format duration
    const hours = Math.floor(durationSec / 3600);
    const minutes = Math.round((durationSec % 3600) / 60);
    let durationStr = '';
    if (hours > 0) durationStr += `${hours}h `;
    durationStr += `${minutes}m`;

    // Update UI
    document.getElementById('result-distance').textContent = `${distanceKm.toFixed(1)} km`;
    document.getElementById('result-duration').textContent = durationStr;
    document.getElementById('result-energy').textContent = `${energyNeeded.toFixed(1)} kWh`;
    document.getElementById('result-consumption').textContent = `${consumption.toFixed(1)} kWh/100km`;
    document.getElementById('result-battery-used').textContent = `${batteryUsedPercent.toFixed(1)}%`;
    document.getElementById('result-battery-remaining').textContent =
        batteryRemainingPercent > 0 ? `${batteryRemainingPercent.toFixed(1)}%` : '0%';

    // Range bar
    const usedWidth = Math.min(batteryUsedPercent, batteryPercent);
    const remainingWidth = Math.max(batteryRemainingPercent, 0);
    document.getElementById('range-bar-used').style.width = `${usedWidth}%`;
    document.getElementById('range-bar-remaining').style.width = `${remainingWidth}%`;

    // Warning
    const warning = document.getElementById('warning-message');
    if (batteryRemainingPercent < 0) {
        const deficit = Math.abs(batteryRemainingPercent * model.battery / 100).toFixed(1);
        warning.textContent = `Insufficient battery! You need ${deficit} kWh more. Charge before this trip.`;
        warning.className = 'warning danger';
    } else if (batteryRemainingPercent < 15) {
        warning.textContent = `Low battery warning: You'll arrive with only ${batteryRemainingPercent.toFixed(1)}% remaining.`;
        warning.className = 'warning';
    } else {
        warning.className = 'warning hidden';
    }

    resultsSection.classList.remove('hidden');
}

// Event listeners
originInput.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => geocodeSearch(originInput.value, originSuggestions, 'origin'), 400);
});

destInput.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => geocodeSearch(destInput.value, destSuggestions, 'dest'), 400);
});

// Close suggestions when clicking outside
document.addEventListener('click', (e) => {
    if (!e.target.closest('.input-group')) {
        originSuggestions.classList.remove('active');
        destSuggestions.classList.remove('active');
    }
});

clearOriginBtn.addEventListener('click', () => {
    originInput.value = '';
    originCoords = null;
    if (originMarker) { map.removeLayer(originMarker); originMarker = null; }
    if (routeLine) { map.removeLayer(routeLine); routeLine = null; }
    resultsSection.classList.add('hidden');
    clickMode = 'origin';
    updateMapInstructions();
});

clearDestBtn.addEventListener('click', () => {
    destInput.value = '';
    destCoords = null;
    if (destMarker) { map.removeLayer(destMarker); destMarker = null; }
    if (routeLine) { map.removeLayer(routeLine); routeLine = null; }
    resultsSection.classList.add('hidden');
    clickMode = 'dest';
    updateMapInstructions();
});

swapBtn.addEventListener('click', () => {
    const tmpCoords = originCoords;
    const tmpText = originInput.value;
    originCoords = destCoords;
    originInput.value = destInput.value;
    destCoords = tmpCoords;
    destInput.value = tmpText;

    if (originMarker) map.removeLayer(originMarker);
    if (destMarker) map.removeLayer(destMarker);
    originMarker = null;
    destMarker = null;

    if (originCoords) {
        originMarker = L.marker(originCoords, { icon: createMarkerIcon('origin') }).addTo(map);
    }
    if (destCoords) {
        destMarker = L.marker(destCoords, { icon: createMarkerIcon('dest') }).addTo(map);
    }

    tryCalculateRoute();
});

// Model selector
const modelSelect = document.getElementById('model-select');

function updateModelDisplay() {
    const model = EV_MODELS[selectedModel];

    // Update title
    document.getElementById('model-title').textContent = model.name;

    // Update driving style labels with model-specific consumption
    const options = drivingStyleSelect.options;
    options[0].textContent = `Eco (${model.consumption.eco.toFixed(1)} kWh/100km)`;
    options[1].textContent = `Normal (${model.consumption.normal.toFixed(1)} kWh/100km)`;
    options[2].textContent = `Sport (${model.consumption.sport.toFixed(1)} kWh/100km)`;

    // Update specs
    document.getElementById('spec-battery').textContent = `${model.battery} kWh`;
    document.getElementById('spec-range').textContent = `${model.range} km`;
    document.getElementById('spec-motor').textContent = model.motor;
    document.getElementById('spec-fastcharge').textContent = model.fastCharge;
}

modelSelect.addEventListener('change', () => {
    selectedModel = modelSelect.value;
    updateModelDisplay();
    tryCalculateRoute();
});

// Initialize model display
updateModelDisplay();

// Recalculate on settings change
drivingStyleSelect.addEventListener('change', tryCalculateRoute);
acToggle.addEventListener('change', tryCalculateRoute);
passengersSelect.addEventListener('change', tryCalculateRoute);
batterySlider.addEventListener('input', () => {
    batteryValue.textContent = `${batterySlider.value}%`;
    const pct = parseInt(batterySlider.value);
    if (pct > 50) batteryValue.style.color = '#4caf50';
    else if (pct > 20) batteryValue.style.color = '#ff9800';
    else batteryValue.style.color = '#f44336';
    tryCalculateRoute();
});

// Init
initMap();
