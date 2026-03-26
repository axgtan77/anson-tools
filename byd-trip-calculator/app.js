// BYD Atto 3 Trip Calculator

const BATTERY_CAPACITY = 60.48; // kWh

// Base consumption rates in kWh/100km
const CONSUMPTION_RATES = {
    eco: 14.0,
    normal: 16.5,
    sport: 19.5,
};

// Additional consumption factors
const AC_PENALTY = 1.5;           // kWh/100km extra with A/C
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
    const style = drivingStyleSelect.value;
    const acOn = acToggle.checked;
    const passengers = parseInt(passengersSelect.value);
    const batteryPercent = parseInt(batterySlider.value);

    // Compute effective consumption
    let consumption = CONSUMPTION_RATES[style];
    if (acOn) consumption += AC_PENALTY;
    if (passengers > 1) consumption += (passengers - 1) * PASSENGER_PENALTY;

    const energyNeeded = (distanceKm * consumption) / 100;
    const availableEnergy = (batteryPercent / 100) * BATTERY_CAPACITY;
    const batteryUsedPercent = (energyNeeded / BATTERY_CAPACITY) * 100;
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
        const deficit = Math.abs(batteryRemainingPercent * BATTERY_CAPACITY / 100).toFixed(1);
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
