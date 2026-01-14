document.addEventListener('DOMContentLoaded', async () => {
    // Init UI
    Ondes.UI.setAppBar(true, "Météo Locale");
    
    const ui = {
        location: document.getElementById('location'),
        temp: document.getElementById('temp-val'),
        desc: document.getElementById('desc'),
        humidity: document.getElementById('humidity'),
        wind: document.getElementById('wind'),
        icon: document.getElementById('weather-icon'),
        btn: document.getElementById('refresh-btn')
    };

    const updateWeather = async () => {
        try {
            ui.btn.disabled = true;
            ui.btn.textContent = "Localisation...";
            
            // 1. Get GPS Position via Bridge
            // The bridge returns { latitude: double, longitude: double }
            const position = await Ondes.Device.getGPSPosition();
            console.log("Position received:", position);

            ui.location.textContent = `Lat: ${position.latitude.toFixed(2)}, Lng: ${position.longitude.toFixed(2)}`;
            ui.btn.textContent = "Chargement météo...";

            // 2. Simulate API Call (using mock data for demo robustness)
            // In a real app, you would fetch: 
            // `https://api.weather.com/v1?lat=${position.latitude}&lon=${position.longitude}`
            await new Promise(r => setTimeout(r, 800)); // Fake network delay
            const data = generateMockWeather(position.latitude, position.longitude);

            // 3. Update DOM
            ui.temp.textContent = data.temp;
            ui.desc.textContent = data.condition;
            ui.humidity.textContent = data.humidity + "%";
            ui.wind.textContent = data.wind + " km/h";
            ui.icon.textContent = data.icon;

            // Update background based on Mock Temp
            updateTheme(data.temp);

            // 4. Feedback
            Ondes.Device.hapticFeedback('medium');
            
        } catch (e) {
            console.error(e);
            ui.location.textContent = "Erreur de localisation";
            Ondes.Device.hapticFeedback('error');
            alert("Impossible de récupérer la position: " + e.message);
        } finally {
            ui.btn.disabled = false;
            ui.btn.textContent = "Actualiser ma position";
        }
    };

    // Helper: Fake Weather Generator
    function generateMockWeather(lat, lng) {
        // Deterministic random based on minimal coord changes
        const seed = Math.floor(Math.abs(lat + lng) * 100); 
        const conditions = [
            { text: "Ensoleillé", icon: "☀️" },
            { text: "Nuageux", icon: "☁️" },
            { text: "Pluvieux", icon: "🌧️" },
            { text: "Orage", icon: "⚡" }
        ];
        
        const condIndex = seed % conditions.length;
        const temp = 15 + (seed % 15); // 15 to 30 degrees
        
        return {
            temp: temp,
            condition: conditions[condIndex].text,
            icon: conditions[condIndex].icon,
            humidity: 40 + (seed % 50),
            wind: 5 + (seed % 60)
        };
    }

    function updateTheme(temp) {
        let gradient;
        if (temp > 25) {
            // Hot
            gradient = 'linear-gradient(180deg, #FF512F 0%, #DD2476 100%)';
        } else if (temp < 10) {
            // Cold
            gradient = 'linear-gradient(180deg, #1A2980 0%, #26D0CE 100%)';
        } else {
            // Mild
            gradient = 'linear-gradient(180deg, #4facfe 0%, #00f2fe 100%)';
        }
        document.body.style.background = gradient;
        
        // Update AppBar color via Bridge to match theme (Optional advanced feature)
        // If we implemented setAppBarColor(hex)
    }

    // Bind Event
    ui.btn.addEventListener('click', updateWeather);

    // Initial Load
    updateWeather();
});
