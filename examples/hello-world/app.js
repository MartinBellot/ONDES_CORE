document.addEventListener('OndesReady', () => {
    console.log("Mini-App connectée à Ondes Core !");
    
    // Configure AppBar on launch
    Ondes.UI.configureAppBar({
        title: "Hello World",
        visible: true
    });
});

async function showNativeToast() {
    if (!window.Ondes) return alert("Mode Web Classique");
    
    await Ondes.UI.showToast({
        message: "Ceci vient du code JavaScript !",
        type: "success"
    });
}

function showNativeAlert() {
    if (!window.Ondes) return alert("Mode Web Classique");

    Ondes.UI.showAlert({
        title: "Ondes Core",
        message: "Le pont fonctionne parfaitement.",
        buttonText: "Super"
    });
}

async function loadProfile() {
    if (!window.Ondes) return;

    const user = await Ondes.User.getProfile();
    
    const container = document.getElementById('profileData');
    const img = document.getElementById('avatar');
    const name = document.getElementById('username');

    img.src = user.avatar;
    name.textContent = user.username + " (" + user.locale + ")";
    container.style.display = 'block';

    Ondes.Device.hapticFeedback('success');
}
