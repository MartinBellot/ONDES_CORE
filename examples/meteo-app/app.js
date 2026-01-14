document.addEventListener('OndesReady', async () => {
    // Init UI
    if (window.Ondes) {
        Ondes.UI.configureAppBar({ visible: true }); // Fullscreen style
    }
    
    // UI Refs
    const ui = {
        city: document.getElementById('city-name'),
        location: document.getElementById('location'),
        temp: document.getElementById('temp-val'),
        desc: document.getElementById('desc'),
        humidity: document.getElementById('humidity'),
        wind: document.getElementById('wind'),
        accuracy: document.querySelector('#accuracy') || createPlaceholder(),
        altitude: document.querySelector('#altitude') || createPlaceholder(),
        icon: document.getElementById('weather-icon'),
        btn: document.getElementById('refresh-btn'),
        themeBtn: document.getElementById('theme-toggle')
    };

    function createPlaceholder() { return { textContent: "" }; }

    // Theme Management
    let isDark = true;
    const toggleTheme = () => {
        isDark = !isDark;
        document.body.classList.toggle('dark', isDark);
        ui.themeBtn.textContent = isDark ? "🌙" : "☀️";
        Ondes.Device.hapticFeedback('light');
    };
    ui.themeBtn.addEventListener('click', toggleTheme);
    // Init theme based on system (or default dark as set in HTML)
    ui.themeBtn.textContent = document.body.classList.contains('dark') ? "🌙" : "☀️";

    
    // Main Function
    const updateWeather = async () => {
        try {
            ui.btn.disabled = true;
            ui.btn.style.opacity = "0.7";
            ui.btn.innerHTML = '<span class="btn-icon">🛰️</span> Connexion satellite...';
            
            // 1. Get Real GPS
            const position = await Ondes.Device.getGPSPosition();
            console.log("GPS:", position);
            
            ui.location.textContent = `Lat: ${position.latitude.toFixed(4)}, Lng: ${position.longitude.toFixed(4)}`;
            if (ui.accuracy) ui.accuracy.textContent = `±${Math.round(position.accuracy)}m`;
            if (ui.altitude) ui.altitude.textContent = `${Math.round(position.altitude)}m`;

            ui.btn.innerHTML = '<span class="btn-icon">☁️</span> Téléchargement météo...';

            // 2. Call Open-Meteo API (Real Data)
            const url = `https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto`;
            
            const response = await fetch(url);
            if (!response.ok) throw new Error("API Error");
            const data = await response.json();
            
            const current = data.current;
            
            // 3. Update UI
            ui.temp.textContent = Math.round(current.temperature_2m);
            ui.desc.textContent = getWeatherDesc(current.weather_code);
            ui.icon.textContent = getWeatherIcon(current.weather_code);
            ui.humidity.textContent = `${current.relative_humidity_2m}%`;
            ui.wind.textContent = `${Math.round(current.wind_speed_10m)} km/h`;
            
            // Try Reverse Geocoding via external free API (Optional, minimal implementation)
            ui.city.textContent = "Position actuelle"; 
            fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=fr`)
                .then(r => r.json())
                .then(geo => {
                    if(geo.city || geo.locality) ui.city.textContent = geo.city || geo.locality;
                })
                .catch(() => {});

            Ondes.Device.hapticFeedback('success');

        } catch (e) {
            console.error(e);
            ui.desc.textContent = "Erreur réseau";
            ui.location.textContent = e.message;
            Ondes.Device.hapticFeedback('error');
            alert("Erreur: " + e.message);
        } finally {
            ui.btn.disabled = false;
            ui.btn.style.opacity = "1";
            ui.btn.innerHTML = '<span class="btn-icon">📍</span> Actualiser ma position';
        }
    };

    // WMO Weather Codes to Text/Icon
    function getWeatherDesc(code) {
        const codes = {
            0: "Ciel dégagé",
            1: "Principalement clair", 2: "Partiellement nuageux", 3: "Couvert",
            45: "Brouillard", 48: "Brouillard givrant",
            51: "Bruine légère", 53: "Bruine modérée", 55: "Bruine dense",
            61: "Pluie faible", 63: "Pluie modérée", 65: "Pluie forte",
            71: "Neige faible", 73: "Neige modérée", 75: "Neige forte",
            95: "Orage", 96: "Orage avec grêle"
        };
        return codes[code] || "Inconnu";
    }

    function getWeatherIcon(code) {
        if (code === 0) return "☀️";
        if (code <= 3) return "⛅";
        if (code <= 48) return "🌫️";
        if (code <= 55) return "💧";
        if (code <= 65) return "🌧️";
        if (code <= 77) return "❄️";
        if (code >= 95) return "⚡";
        return "🌡️";
    }

    // Auto load on start
    ui.btn.addEventListener('click', updateWeather);
    // No timeout needed with OndesReady
    updateWeather();
});
