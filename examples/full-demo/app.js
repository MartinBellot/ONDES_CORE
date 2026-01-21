// Initialize
document.addEventListener('OndesReady', async () => {
    console.log("🌊 Ondes Full Demo Init - v3.0");
    await loadAppInfo();
    
    // Configure initial AppBar with Google Font
    Ondes.UI.configureAppBar({ 
        title: "Ondes Demo", 
        visible: true,
        fontFamily: "Poppins",
        titleBold: true,
        titleSize: 20,
        centerTitle: true
    });
    
    // Setup drawer select listener
    Ondes.UI.onDrawerSelect((data) => {
        console.log("Drawer item selected:", data.value);
        Ondes.UI.showToast({ message: `Selected: ${data.value}`, type: "info" });
    });
    
    // Setup appbar action listener
    Ondes.UI.onAppBarAction((data) => {
        console.log("AppBar action:", data.value);
        if (data.value === 'search') {
            showInputDialog();
        } else if (data.value === 'notifications') {
            Ondes.UI.showToast({ message: "No new notifications", type: "info" });
        } else if (data.value === 'settings') {
            showSettingsModal();
        }
    });
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
    Ondes.UI.showToast({ 
        message: msgs[type], 
        type: type,
        duration: 3000,
        bold: type === 'error'
    });
}

function showNativeAlert() {
    if (!window.Ondes) return alert("Alert Web Classique");
    
    Ondes.UI.showAlert({
        title: "Titre Natif",
        message: "Ceci est une boîte de dialogue native contrôlée par le système.",
        buttonText: "Compris",
        icon: "info",
        iconColor: "#1a73e8",
        borderRadius: 20,
        titleStyle: {
            fontFamily: "Poppins",
            bold: true,
            fontSize: 20
        },
        messageStyle: {
            fontSize: 16,
            color: "#666666"
        }
    });
}

async function showConfirmDialog() {
    if (!window.Ondes) return;
    
    const result = await Ondes.UI.showConfirm({
        title: "Confirmer l'action",
        message: "Êtes-vous sûr de vouloir continuer ? Cette action est irréversible.",
        confirmText: "Oui, continuer",
        cancelText: "Annuler",
        icon: "warning",
        iconColor: "#f59e0b",
        confirmColor: "#22c55e",
        cancelColor: "#6b7280",
        borderRadius: 16
    });
    
    Ondes.UI.showToast({ 
        message: result ? "Confirmé !" : "Annulé", 
        type: result ? "success" : "info" 
    });
}

async function showInputDialog() {
    if (!window.Ondes) return;
    
    const result = await Ondes.UI.showInputDialog({
        title: "Recherche",
        message: "Entrez votre terme de recherche",
        placeholder: "Tapez ici...",
        label: "Recherche",
        prefixIcon: "search",
        confirmText: "Rechercher",
        cancelText: "Annuler",
        confirmColor: "#1a73e8",
        borderRadius: 16,
        titleStyle: {
            fontFamily: "Poppins",
            bold: true
        }
    });
    
    if (result) {
        Ondes.UI.showToast({ message: `Recherche: "${result}"`, type: "info" });
    }
}

async function showCustomModal() {
    if (!window.Ondes) return;
    
    const result = await Ondes.UI.showModal({
        icon: "star",
        iconColor: "#f59e0b",
        iconBackgroundColor: "#fef3c7",
        iconSize: 56,
        title: "Nouvelle Fonctionnalité !",
        message: "Découvrez les modales ultra-personnalisables d'Ondes UI v3.0. Vous pouvez maintenant créer des interfaces riches et modernes.",
        centerContent: true,
        borderRadius: 24,
        backgroundColor: "#ffffff",
        padding: 24,
        titleStyle: {
            fontFamily: "Poppins",
            fontSize: 24,
            bold: true,
            color: "#1e293b"
        },
        messageStyle: {
            fontSize: 16,
            color: "#64748b",
            lineHeight: 1.5
        },
        sections: [
            {
                title: "Nouveautés",
                titleStyle: { color: "#1a73e8", bold: true },
                items: [
                    { icon: "check", text: "Google Fonts intégrés", value: "✓" },
                    { icon: "check", text: "Drawers personnalisables", value: "✓" },
                    { icon: "check", text: "AppBar avancée", value: "✓" },
                    { icon: "check", text: "Modales riches", value: "✓" }
                ]
            }
        ],
        buttons: [
            { label: "Plus tard", value: "later", outlined: true },
            { label: "Découvrir", value: "discover", primary: true, icon: "arrow_forward" }
        ],
        buttonsLayout: "horizontal",
        footerColor: "#f8fafc"
    });
    
    if (result === 'discover') {
        Ondes.UI.showToast({ message: "Bienvenue dans Ondes UI v3.0 !", type: "success" });
    }
}

async function showSettingsModal() {
    if (!window.Ondes) return;
    
    await Ondes.UI.showModal({
        header: {
            title: "Paramètres",
            icon: "settings",
            backgroundColor: "#1e293b",
            showClose: true
        },
        title: "Préférences de l'application",
        message: "Configurez votre expérience Ondes selon vos préférences.",
        borderRadius: 20,
        sections: [
            {
                title: "Apparence",
                items: [
                    { icon: "sun", text: "Mode clair", value: "Activé", valueColor: "#22c55e" },
                    { icon: "moon", text: "Mode sombre", value: "Auto" }
                ]
            },
            {
                title: "Notifications",
                items: [
                    { icon: "notifications", text: "Push", value: "On", valueColor: "#22c55e" },
                    { icon: "email", text: "Email", value: "Off", valueColor: "#ef4444" }
                ]
            }
        ],
        buttons: [
            { label: "Fermer", value: "close", primary: true }
        ]
    });
}

async function showActionSheet() {
    if (!window.Ondes) return;
    
    const result = await Ondes.UI.showActionSheet({
        title: "Actions disponibles",
        message: "Choisissez une action à effectuer",
        actions: [
            { label: "Partager", value: "share" },
            { label: "Copier le lien", value: "copy" },
            { label: "Modifier", value: "edit" },
            { label: "Supprimer", value: "delete", destructive: true }
        ],
        cancelText: "Annuler"
    });
    
    if (result) {
        Ondes.UI.showToast({ message: `Action: ${result}`, type: "info" });
        Ondes.Device.hapticFeedback('selection');
    }
}

async function showBottomSheet() {
    if (!window.Ondes) return;
    
    const result = await Ondes.UI.showBottomSheet({
        title: "Options",
        subtitle: "Sélectionnez une option ci-dessous",
        showDragHandle: true,
        borderRadius: 24,
        titleStyle: {
            fontFamily: "Poppins",
            bold: true,
            fontSize: 20
        },
        items: [
            { icon: "photo", label: "Galerie Photo", subtitle: "Choisir depuis la galerie", value: "gallery", iconColor: "#22c55e" },
            { icon: "camera", label: "Appareil Photo", subtitle: "Prendre une nouvelle photo", value: "camera", iconColor: "#3b82f6" },
            { icon: "file", label: "Documents", subtitle: "Parcourir les fichiers", value: "files", iconColor: "#f59e0b" },
            { type: "divider" },
            { icon: "delete", label: "Supprimer", value: "delete", danger: true }
        ]
    });
    
    if (result) {
        Ondes.UI.showToast({ message: `Choix: ${result}`, type: "success" });
    }
}

async function showLoadingDemo() {
    if (!window.Ondes) return;
    
    Ondes.UI.showLoading({
        message: "Chargement en cours...",
        spinnerColor: "#1a73e8",
        backgroundColor: "#ffffff",
        spinnerSize: 48,
        messageStyle: {
            fontFamily: "Poppins",
            fontSize: 16
        }
    });
    
    // Hide after 2 seconds
    setTimeout(() => {
        Ondes.UI.hideLoading();
        Ondes.UI.showToast({ message: "Chargement terminé !", type: "success" });
    }, 2000);
}

async function showSnackbarDemo() {
    if (!window.Ondes) return;
    
    const result = await Ondes.UI.showSnackbar({
        message: "Élément supprimé",
        subtitle: "Cliquez pour annuler",
        icon: "delete",
        iconColor: "#ffffff",
        backgroundColor: "#1e293b",
        duration: 5000,
        borderRadius: 12,
        action: {
            label: "Annuler",
            value: "undo",
            color: "#60a5fa"
        }
    });
    
    if (result === 'undo') {
        Ondes.UI.showToast({ message: "Action annulée !", type: "success" });
    }
}

function updateAppBar(title, bg, fg) {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ 
        title: title, 
        visible: true,
        backgroundColor: bg,
        foregroundColor: fg,
        titleBold: true,
        elevation: 2
    });
}

function updateAppBarFancy() {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ 
        title: "✨ Fancy Style",
        visible: true,
        backgroundColor: "#7c3aed",
        foregroundColor: "#ffffff",
        fontFamily: "Pacifico",
        titleSize: 24,
        titleBold: false,
        centerTitle: true,
        elevation: 4,
        height: 64
    });
    Ondes.Device.hapticFeedback('success');
}

function updateAppBarWithActions() {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ 
        title: "Actions Demo",
        visible: true,
        backgroundColor: "#1e293b",
        foregroundColor: "#ffffff",
        fontFamily: "Poppins",
        titleBold: true,
        centerTitle: false,
        elevation: 0,
        leading: {
            type: "menu"
        },
        actions: [
            { type: "icon", icon: "search", value: "search" },
            { type: "badge", icon: "notifications", value: "notifications", badge: 3, badgeColor: "#ef4444" },
            { type: "icon", icon: "settings", value: "settings" }
        ]
    });
}

function hideAppBar() {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ visible: false });
}

function showAppBar() {
    if (!window.Ondes) return;
    Ondes.UI.configureAppBar({ 
        visible: true, 
        title: "Ondes Demo",
        fontFamily: "Poppins",
        titleBold: true
    });
}

function setupDrawer() {
    if (!window.Ondes) return;
    
    Ondes.UI.configureDrawer({
        enabled: true,
        side: "left",
        width: 300,
        backgroundColor: "#ffffff",
        borderRadius: 0,
        header: {
            backgroundColor: "#1a73e8",
            avatar: "https://i.pravatar.cc/150?img=3",
            title: "John Doe",
            subtitle: "john@example.com",
            titleColor: "#ffffff",
            subtitleColor: "#e0e7ff"
        },
        items: [
            { icon: "home", label: "Accueil", value: "home", selected: true },
            { icon: "person", label: "Mon Profil", value: "profile" },
            { icon: "settings", label: "Paramètres", value: "settings", trailing: "→" },
            { type: "divider" },
            { type: "section", title: "Autres" },
            { icon: "help", label: "Aide", value: "help", badge: "2", badgeColor: "#3b82f6" },
            { icon: "info", label: "À propos", value: "about" },
            { type: "divider" },
            { icon: "logout", label: "Déconnexion", value: "logout", iconColor: "#ef4444" }
        ],
        footer: {
            text: "Ondes v3.0 • Made with ❤️"
        }
    });
    
    // Also setup leading button
    Ondes.UI.configureAppBar({
        visible: true,
        title: "Ondes Demo",
        fontFamily: "Poppins",
        titleBold: true,
        leading: { type: "menu" }
    });
    
    Ondes.UI.showToast({ message: "Drawer configuré ! Cliquez sur ☰ pour l'ouvrir", type: "success" });
}

function openDrawer() {
    if (!window.Ondes) return;
    Ondes.UI.openDrawer('left');
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
