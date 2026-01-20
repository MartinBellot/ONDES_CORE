# 🌊 Ondes Core - Documentation

Bienvenue sur la documentation officielle de **Ondes Core**, la plateforme de mini-applications web natives.

Ce site documente l'écosystème complet :
- L'application hôte (Flutter)
- L'API backend (Django)
- Le SDK JavaScript (Bridge)
- Le SDK Flutter (`packages/ondes_sdk`)

---

## 📚 Sections

Nous avons divisé la documentation pour une navigation plus fluide.

### 🚀 Commencer ici
- **[Présentation](introduction.md)** : Comprendre ce qu'est Ondes Core.
- **[Architecture](architecture.md)** : Comment fonctionnent le Bridge, le WebView et le Backend.
- **[Installation](installation.md)** : Guide pas-à-pas pour installer le projet sur votre machine.

### 👨‍💻 Créer une Mini-App
- **[Guide du développeur](mini_app_guide.md)** : Créer sa première app, structure, manifest.json.
- **[🧪 Ondes Lab](lab.md)** : Environnement de développement, serveur local, debugging.
- **[Exemples](examples.md)** : Liste des applications de démonstration fournies.

### 🛠️ SDK - Référence API

Deux technologies sont supportées pour créer des mini-apps :

#### 🌐 SDK JavaScript (HTML/CSS/JS)
L'objet `window.Ondes` est votre porte d'entrée vers le natif.

- **[Introduction au SDK](sdk/index.md)** : Initialisation et bonnes pratiques.
- **Modules :**
  - 🎨 **[Interface (UI)](sdk/ui.md)** : Toasts, Modales, Navigation.
  - 👤 **[Utilisateur (User)](sdk/user.md)** : Profil et authentification.
  - 📱 **[Matériel (Device)](sdk/device.md)** : Caméra, GPS, Vibration.
  - 💾 **[Stockage (Storage)](sdk/storage.md)** : Données persistantes.
  - 📦 **[Application (App)](sdk/app.md)** : Infos et cycle de vie.
  - 👥 **[Amis (Friends)](sdk/friends.md)** : Gestion du graphe d'amitié.
  - 🌍 **[Social (Social)](sdk/social.md)** : Feed, Posts, Stories et Médias.

#### 💙 SDK Flutter (Dart)
Package Flutter pour créer des mini-apps avec toute la puissance de Flutter.

- **[SDK Flutter](sdk/flutter.md)** : Installation, guide complet, et référence API.

### 🖥️ Backend
- **[API Django](backend.md)** : Structure du serveur et endpoints.

---

<p align="center">
  <em>Créez. Distribuez. Connectez.</em>
</p>
