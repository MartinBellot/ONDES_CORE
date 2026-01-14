// Initialize
document.addEventListener('OndesReady', async () => {
    console.log("🌊 Ondes Full Demo Init");
    await loadAppInfo();
    Ondes.UI.configureAppBar({ title: "Ondes Demo", visible: true });
});

// --- System ---
async function loadAppInfo() {
    if (!window.Ondes) return;
    const info = await Ondes.App.getInfo();
    document.getElementById('appInfo').innerHTML = `
        <strong>Version:</strong> ${info.version} (${info.buildNumber})<br>
        <strong>Platform:</strong> ${info.platform}
    `;
}

function closeApp() {
    if (window.Ondes) Ondes.App.close();
}

// --- User ---
async function getUserToken() {
    if (!window.Ondes) return;
    try {
        const token = await Ondes.User.getAuthToken();
        document.getElementById('tokenDisplay').innerText = token ? (token.substring(0, 20) + "...") : "No Token";
        
        // Load Profile too
        const user = await Ondes.User.getProfile();
        const html = `
            <img src="${user.avatar}" class="user-avatar">
            <div>
                <div style="font-weight:bold">${user.username}</div>
                <div style="font-size:12px">${user.id} • ${user.locale}</div>
            </div>
        `;
        document.getElementById('userProfile').innerHTML = html;
        Ondes.Device.hapticFeedback('success');
    } catch (e) {
        alert("Erreur User: " + e);
    }
}

// --- UI ---
function showToast(type) {
    if (!window.Ondes) return;
    const msgs = {
        success: "Opération réussie !",
        error: "Une erreur est survenue.",
        warning: "Attention à cette action.",
        info: "Juste une information."
    };
    Ondes.UI.showToast({ message: msgs[type], type: type });
}

function showNativeAlert() {
    if (window.Ondes) {
        Ondes.UI.showAlert({
            title: "Titre Natif",
            message: "Ceci est une boîte de dialogue native contrôlée par le système.",
            buttonText: "Compris"
        });
    } else {
        alert("Alert Web Classique");
    }
}

function updateAppBar(title, bg, fg) {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ 
        title: title, 
        visible: true,
        backgroundColor: bg,
        foregroundColor: fg 
    });
}

function hideAppBar() {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ visible: false });
}

function showAppBar() {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ visible: true, title: "Ondes Demo" });
}

// --- Device ---
function haptic(style) {
    if (window.Ondes) Ondes.Device.hapticFeedback(style);
}

async function scanQR() {
    const el = document.getElementById('qrResult');
    el.innerText = "Scanning...";
    
    if (!window.Ondes) return el.innerText = "Pas de bridge détecté";

    try {
        const result = await Ondes.Device.scanQRCode();
        el.innerText = result;
        Ondes.Device.hapticFeedback('success');
    } catch (e) {
        el.innerText = "Annulé";
        Ondes.Device.hapticFeedback('error');
    }
}

async function getGPS() {
    const el = document.getElementById('gpsResult');
    el.innerText = "Localisation...";
    
    if (!window.Ondes) return el.innerText = "Pas de bridge détecté";

    try {
        const pos = await Ondes.Device.getGPSPosition();
        el.innerHTML = `Lat: ${pos.latitude}<br>Lng: ${pos.longitude}<br>Acc: ${pos.accuracy}m`;
        Ondes.Device.hapticFeedback('selection');
    } catch (e) {
        el.innerText = "Erreur ou refus GPS";
    }
}

// --- Storage ---
async function saveData() {
    const k = document.getElementById('storageKey').value;
    const v = document.getElementById('storageValue').value;
    if (!k) return;

    if (window.Ondes) {
        await Ondes.Storage.set(k, v);
        document.getElementById('storageOutput').innerText = `Sauvegardé [${k}]`;
        Ondes.UI.showToast({message: "Donnée enregistrée", type: "success"});
    }
}

async function loadData() {
    const k = document.getElementById('storageKey').value;
    if (!k) return;

    if (window.Ondes) {
        const val = await Ondes.Storage.get(k);
        document.getElementById('storageOutput').innerText = `Valeur: ${val}`;
        document.getElementById('storageValue').value = val || "";
    }
}

async function removeData() {
    const k = document.getElementById('storageKey').value;
    if (!k) return;

    if (window.Ondes) {
        await Ondes.Storage.remove(k);
        document.getElementById('storageOutput').innerText = `Effacé [${k}]`;
        document.getElementById('storageValue').value = "";
    }
}
