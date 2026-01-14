document.addEventListener('OndesReady', async () => {
    
    // --- CONFIGURATION ---
    const STYLES = {
        standard: 'https://tiles.openfreemap.org/styles/liberty', 
        satellite: {
            version: 8,
            sources: {
                'satellite-source': {
                    'type': 'raster',
                    'tiles': [
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    ],
                    'tileSize': 256
                }
            },
            layers: [
                {
                    'id': 'satellite-layer',
                    'type': 'raster',
                    'source': 'satellite-source',
                    'paint': {}
                }
            ]
        }
    };

    // --- 1. SETUP NATIVE UI ---
    if (window.Ondes) {
        // Cache la barre native pour une immersion totale
        Ondes.UI.configureAppBar({ 
            visible: true,
            backgroundColor: "#00000000",
            foregroundColor: "#FFFFFF",
            title: "Map"
        });
    }

    // --- 2. INIT MAP ---
    const map = new maplibregl.Map({
        container: 'map',
        style: STYLES.standard,
        center: [2.3522, 48.8566], // Paris par défaut
        zoom: 12,
        attributionControl: false
    });

    // Fix: Handle missing icons in the style to prevent console errors
    map.on('styleimagemissing', (e) => {
        // Load a transparent 1x1 image for any missing icon
        const image = {
            width: 1,
            height: 1,
            data: new Uint8Array([0, 0, 0, 0])
        };
        if (!map.hasImage(e.id)) {
            map.addImage(e.id, image);
        }
    });

    // UI References
    const ui = {
        title: document.getElementById('loc-title'),
        coords: document.getElementById('loc-coords'),
        accuracy: document.getElementById('loc-accuracy'),
        altitude: document.getElementById('loc-altitude'),
        fab: document.getElementById('locate-btn'),
        toggleBtns: document.querySelectorAll('.toggle-btn'),
        searchInput: document.getElementById('search-input'),
        suggestions: document.getElementById('suggestions'),
        transportToggle: document.getElementById('transport-mode'),
        modeBtns: document.querySelectorAll('.mode-btn')
    };

    let userMarker = null;
    let destinationMarker = null;
    let routeLayerId = 'route';
    let currentMode = 'driving'; // driving | walking

    // Helper: Add Route Layer
    const addRouteLayer = (coords) => {
        if (map.getSource('route')) {
            map.getSource('route').setData({
                type: 'Feature',
                properties: {},
                geometry: {
                    type: 'LineString',
                    coordinates: coords
                }
            });
        } else {
            map.addSource('route', {
                type: 'geojson',
                data: {
                    type: 'Feature',
                    properties: {},
                    geometry: {
                        type: 'LineString',
                        coordinates: coords
                    }
                }
            });
            map.addLayer({
                id: routeLayerId,
                type: 'line',
                source: 'route',
                layout: {
                    'line-join': 'round',
                    'line-cap': 'round'
                },
                paint: {
                    'line-color': '#007AFF', // Will be updated dynamically
                    'line-width': 6,
                    'line-opacity': 0.8
                }
            });
        }
    };

    // Helper: Fetch Route (Using OSRM Demo API)
    const getRoute = async (start, end) => {
        
        // Select the best free OSRM server based on mode
        // routing.openstreetmap.de is generally more reliable for Europe
        let baseUrl;
        let profile;

        if (currentMode === 'walking') {
            baseUrl = 'https://routing.openstreetmap.de/routed-foot/route/v1';
            profile = 'foot';
        } else {
            baseUrl = 'https://routing.openstreetmap.de/routed-car/route/v1';
            profile = 'driving';
        }
        
        console.log(`Fetching route: ${profile} from ${start} to ${end}`);

        try {
            // Add timestamp to prevent caching
            const url = `${baseUrl}/${profile}/${start[0]},${start[1]};${end[0]},${end[1]}?overview=full&geometries=geojson&alternatives=false&steps=true&ts=${Date.now()}`;
            
            const query = await fetch(url);
            const json = await query.json();
            
            if (json.code !== 'Ok' || !json.routes || json.routes.length === 0) {
                console.error("Routing Error Code:", json.code);
                if (window.Ondes) Ondes.UI.showToast({ message: "Itinéraire introuvable (" + json.code + ")", type: "error" });
                return;
            }

            const data = json.routes[0];
            const route = data.geometry.coordinates;
            
            // Add Route to Map
            addRouteLayer(route);
            
            // Update line style
            if(map.getLayer(routeLayerId)) {
                const isWalking = currentMode === 'walking';
                
                // Colors
                map.setPaintProperty(routeLayerId, 'line-color', isWalking ? '#34C759' : '#007AFF');
                
                // Dash Array: [0, 2] for dots, [1] (or null) for solid
                // Note: null resets property to default
                map.setPaintProperty(routeLayerId, 'line-dasharray', isWalking ? [0, 2] : null);
            }

            // Fit bounds to show entire route
            const bounds = route.reduce((bounds, coord) => {
                return bounds.extend(coord);
            }, new maplibregl.LngLatBounds(route[0], route[0]));

            map.fitBounds(bounds, { padding: 50 });

            // Update UI Info
            const minutes = Math.round(data.duration / 60);
            const hours = Math.floor(minutes / 60);
            const minsRef = minutes % 60;
            let timeStr = minutes + " min";
            if (hours > 0) timeStr = `${hours}h ${minsRef > 0 ? minsRef : ''}`;

            const modeIcon = currentMode === 'walking' ? '🚶' : '🚗';
            
            // Extra info for walking to confirm it's different
            const distanceStr = (data.distance / 1000).toFixed(2);
            ui.coords.textContent = `${modeIcon} ${timeStr} • ${distanceStr} km`;
            ui.title.textContent = isWalking ? "Itinéraire Piéton" : "Itinéraire Voiture";

        } catch (e) {
            console.error("Routing Error:", e);
        }
    };

    // --- 3. STYLE & MODE SWITCHER ---
    
    // Map Style
    ui.toggleBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            ui.toggleBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            map.setStyle(STYLES[btn.dataset.style]);
            if (window.Ondes) Ondes.Device.hapticFeedback('light');
        });
    });

    // Transport Mode
    ui.modeBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            ui.modeBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            const newMode = btn.dataset.mode;
            if(currentMode !== newMode) {
                currentMode = newMode;
                // Re-calculate route if we have a destination and user location
                if(destinationMarker && userMarker) {
                    getRoute(userMarker.getLngLat().toArray(), destinationMarker.getLngLat().toArray());
                }
                if (window.Ondes) Ondes.Device.hapticFeedback('light');
            }
        });
    });

    // --- 4. GPS LOGIC (Hybrid: Native + Browser Fallback) ---
    const locateUser = async () => {
        try {
            ui.coords.textContent = "Acquisition signal...";
            if (window.Ondes) Ondes.Device.hapticFeedback('medium');

            let pos;

            if (window.Ondes && Ondes.Device && Ondes.Device.getGPSPosition) {
                // Utilisation du SDK Ondes
                console.log("Using Ondes Native GPS");
                pos = await Ondes.Device.getGPSPosition();
            } else if (navigator.geolocation) {
                // Fallback Navigateur Web Classique (pour tests sur desktop)
                console.log("Using Browser Fallback GPS");
                pos = await new Promise((resolve, reject) => {
                    navigator.geolocation.getCurrentPosition(
                        (p) => resolve({
                            latitude: p.coords.latitude,
                            longitude: p.coords.longitude,
                            accuracy: p.coords.accuracy,
                            altitude: p.coords.altitude || 0
                        }),
                        (err) => reject(err),
                        { enableHighAccuracy: true }
                    );
                });
            } else {
                throw new Error("Aucun module GPS détecté");
            }

            // Update UI
            ui.title.textContent = "Position Actuelle";
            ui.coords.textContent = `${pos.latitude.toFixed(5)}, ${pos.longitude.toFixed(5)}`;
            ui.accuracy.textContent = `±${Math.round(pos.accuracy)}m`;
            ui.altitude.textContent = pos.altitude ? `${Math.round(pos.altitude)}m` : "--";

            const lngLat = [pos.longitude, pos.latitude];

            // Fly to location
            map.flyTo({
                center: lngLat,
                zoom: 16,
                speed: 1.5,
                curve: 1.42
            });

            // Update Marker
            if (!userMarker) {
                const el = document.createElement('div');
                el.className = 'user-marker';
                el.style.width = '20px';
                el.style.height = '20px';
                el.style.backgroundColor = '#007AFF';
                el.style.borderRadius = '50%';
                el.style.border = '3px solid white';
                el.style.boxShadow = '0 0 10px rgba(0,122,255,0.5)';
                
                userMarker = new maplibregl.Marker({ element: el })
                    .setLngLat(lngLat)
                    .addTo(map);
            } else {
                userMarker.setLngLat(lngLat);
            }

            if (window.Ondes) Ondes.Device.hapticFeedback('success');

        } catch (e) {
            console.error("Erreur GPS:", e);
            const msg = e.message || "Erreur inconnue";
            
            if (window.Ondes) {
                Ondes.UI.showToast({ message: "Erreur GPS: " + msg, type: "error" });
                Ondes.Device.hapticFeedback('error');
            } else {
                // Keep UI clean in browser or show simple alert
                console.warn(msg);
            }
            
            ui.coords.textContent = "Signal perdu / GPS inaccessible";
        }
    };

    // --- 5. SEARCH INPUT LOGIC ---
    // Using Nominatim (OpenStreetMap) for geocoding suggestions
    let debounceTimer;
    ui.searchInput.addEventListener('input', (e) => {
        const query = e.target.value;
        
        clearTimeout(debounceTimer);
        ui.suggestions.style.display = 'none';

        if(query.length < 3) return;

        debounceTimer = setTimeout(async () => {
            try {
                const response = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5`);
                const results = await response.json();
                
                ui.suggestions.innerHTML = '';
                if(results.length > 0) {
                    ui.suggestions.style.display = 'block';
                    results.forEach(place => {
                        const li = document.createElement('li');
                        li.innerHTML = `<span class="suggestion-icon">📍</span> ${place.display_name.split(',')[0]}`;
                        li.addEventListener('click', async () => {
                            // 1. Select Place
                            ui.searchInput.value = place.display_name.split(',')[0];
                            ui.suggestions.style.display = 'none';
                            
                            const destLngLat = [parseFloat(place.lon), parseFloat(place.lat)];
                            
                            // 2. Add Destination Marker
                            if(destinationMarker) destinationMarker.remove();
                            destinationMarker = new maplibregl.Marker({ color: '#FF3B30' })
                                .setLngLat(destLngLat)
                                .addTo(map);

                             // Show Transport Toggle
                            ui.transportToggle.style.display = 'flex';

                            // 3. Calculate Route if user location is known
                            let startPos = null;
                            if (userMarker) {
                                startPos = userMarker.getLngLat().toArray();
                            } else {
                                // Try to get location silently if not available
                                try {
                                    // Normally we would wait for locateUser()
                                    // For now, let's just zoom to destination if no user pos
                                } catch(e) {}
                            }

                            if (startPos) {
                                await getRoute(startPos, destLngLat);
                            } else {
                                map.flyTo({ center: destLngLat, zoom: 14 });
                            }

                            if (window.Ondes) Ondes.Device.hapticFeedback('success');
                        });
                        ui.suggestions.appendChild(li);
                    });
                }
            } catch(e) {
                console.error("Search error", e);
            }
        }, 500); // Debounce 500ms
    });

    // Close suggestions on click outside
    document.addEventListener('click', (e) => {
        if(e.target !== ui.searchInput) {
            ui.suggestions.style.display = 'none';
        }
    });

    ui.fab.addEventListener('click', locateUser);

    // Démarrage auto différé
    setTimeout(locateUser, 1000);
});
