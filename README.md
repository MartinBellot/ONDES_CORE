# 🌊 Ondes Core

**La plateforme de mini-applications pour créer, distribuer et exécuter des apps web légères avec accès aux fonctionnalités natives.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Django](https://img.shields.io/badge/Django-5.x-092E20?logo=django)](https://djangoproject.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📑 Table des matières

- [Présentation](#-présentation)
- [Architecture](#-architecture)
- [Installation](#-installation)
- [Guide du développeur Mini-App](#-guide-du-développeur-mini-app)
  - [Démarrage rapide](#démarrage-rapide)
  - [Structure d'une Mini-App](#structure-dune-mini-app)
  - [Le Manifest](#le-manifest)
- [SDK OndesBridge - Référence API](#-sdk-ondesbridge---référence-api)
  - [Initialisation](#initialisation)
  - [Ondes.UI - Interface utilisateur](#1-ondesui---interface-utilisateur)
  - [Ondes.User - Utilisateur](#2-ondesuser---utilisateur)
  - [Ondes.Device - Matériel](#3-ondesdevice---matériel)
  - [Ondes.Storage - Stockage](#4-ondesstorage---stockage)
  - [Ondes.App - Système](#5-ondesapp---système)
  - [Ondes.Friends - Système social](#6-ondesfriends---système-social)
  - [Ondes.Social - Réseau social & Médias](#7-ondessocial---réseau-social--médias)
- [API Backend Django](#-api-backend-django)
- [Exemples](#-exemples)
- [Gestion des erreurs](#-gestion-des-erreurs)

---

## 🎯 Présentation

**Ondes Core** est un écosystème complet permettant de :

| Fonctionnalité | Description |
|----------------|-------------|
| 🏗️ **Créer** | Développez des mini-apps en HTML/CSS/JS |
| 📦 **Distribuer** | Publiez via le Dev Studio intégré |
| 🚀 **Exécuter** | Les apps tournent dans un WebView sécurisé |
| 🔌 **Connecter** | Accès aux APIs natives via le pont JavaScript |

### Cas d'usage

- Applications légères sans installation
- Prototypage rapide
- Apps internes d'entreprise
- Jeux HTML5
- Outils utilitaires

---

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ONDES CORE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────────────────────────────┐     │
│  │  Mini-App   │    │          Flutter App                │     │
│  │  (WebView)  │◄──►│  ┌─────────────────────────────┐    │     │
│  │             │    │  │      Bridge Controller      │    │     │
│  │  HTML/JS/   │    │  ├─────────────────────────────┤    │     │
│  │    CSS      │    │  │ ┌─────┐ ┌─────┐ ┌────────┐  │    │     │
│  └─────────────┘    │  │ │ UI  │ │User │ │ Device │  │    │     │
│        │            │  │ └─────┘ └─────┘ └────────┘  │    │     │
│        │            │  │ ┌─────┐ ┌─────┐ ┌────────┐  │    │     │
│        ▼            │  │ │Store│ │ App │ │Friends │  │    │     │
│  window.Ondes       │  │ └─────┘ └─────┘ └────────┘  │    │     │
│                     │  │ ┌────────────────────────┐  │    │     │
│                     │  │ │        Social          │  │    │     │
│                     │  │ └────────────────────────┘  │    │     │
│                     │  └─────────────────────────────┘    │     │
│                     └─────────────────────────────────────┘     │
│                                      │                          │
│                                      ▼                          │
│                     ┌─────────────────────────────────────┐     │
│                     │          Django API                 │     │
│                     │  ┌─────────┐    ┌─────────────┐     │     │
│                     │  │  Store  │    │   Friends   │     │     │
│                     │  │  (apps) │    │ (relations) │     │     │
│                     │  └─────────┘    └─────────────┘     │     │
│                     │  ┌─────────────────────────────┐    │     │
│                     │  │   Social (posts, feed,      │    │     │
│                     │  │   stories, media, HLS)      │    │     │
│                     │  └─────────────────────────────┘    │     │
│                     └─────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Stack technique

| Couche | Technologie | Rôle |
|--------|-------------|------|
| **Frontend natif** | Flutter | Shell applicatif, WebView, handlers natifs |
| **Mini-Apps** | HTML/CSS/JS | Applications utilisateur |
| **Bridge** | JavaScript injection | Communication WebView ↔ Flutter |
| **Backend** | Django REST Framework | API, authentification, stockage apps |
| **Base de données** | SQLite | Données utilisateurs, apps, amitiés |

---

## 🔧 Installation

### Prérequis

- Flutter 3.x
- Python 3.10+
- pip & virtualenv

### 1. Cloner le projet

```bash
git clone https://github.com/votre-repo/ondes-core.git
cd ondes-core
```

### 2. Configuration du Backend Django

```bash
# Créer l'environnement virtuel
python -m venv venv
source venv/bin/activate  # macOS/Linux
# ou: venv\Scripts\activate  # Windows

# Installer les dépendances
cd api
pip install -r requirements.txt

# Appliquer les migrations
python manage.py migrate

# Créer un superuser (admin)
python manage.py createsuperuser

# Lancer le serveur
python manage.py runserver
```

### 3. Lancer l'application Flutter

```bash
cd ..  # Retour à la racine
flutter pub get
flutter run
```

### 4. Accès

| Service | URL |
|---------|-----|
| API | http://127.0.0.1:8000/api/ |
| Admin Django | http://127.0.0.1:8000/admin/ |
| App Flutter | Émulateur ou appareil |

---

## 👨‍💻 Guide du développeur Mini-App

### Démarrage rapide

Créez votre première mini-app en 3 étapes :

#### Étape 1 : Créer la structure

```
mon-app/
├── index.html      # Point d'entrée (obligatoire)
├── manifest.json   # Métadonnées (obligatoire)
├── app.js          # Logique
└── style.css       # Styles
```

#### Étape 2 : Configurer le manifest

```json
{
    "id": "com.monentreprise.monapp",
    "name": "Ma Super App",
    "version": "1.0.0",
    "description": "Description de mon application",
    "icon": "icon.png"
}
```

#### Étape 3 : Écrire le code

```html
<!-- index.html -->
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ma Super App</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>Bienvenue !</h1>
    <button id="btn">Dire bonjour</button>
    
    <script src="app.js"></script>
</body>
</html>
```

```javascript
// app.js
document.addEventListener('OndesReady', async () => {
    console.log('✅ Ondes SDK prêt !');
    
    // Récupérer l'utilisateur
    const user = await Ondes.User.getProfile();
    
    // Événement bouton
    document.getElementById('btn').addEventListener('click', () => {
        Ondes.UI.showToast({
            message: `Bonjour ${user.username} !`,
            type: 'success'
        });
    });
});
```

### Structure d'une Mini-App

| Fichier | Requis | Description |
|---------|--------|-------------|
| `index.html` | ✅ Oui | Point d'entrée HTML |
| `manifest.json` | ✅ Oui | Métadonnées de l'app |
| `*.js` | Non | Scripts JavaScript |
| `*.css` | Non | Feuilles de style |
| `assets/` | Non | Images, polices, etc. |

### Le Manifest

Le fichier `manifest.json` décrit votre application :

```json
{
    "id": "com.domaine.nomapp",
    "name": "Nom Affiché",
    "version": "1.2.3",
    "description": "Description courte de l'app",
    "icon": "assets/icon.png",
    "author": "Votre Nom",
    "permissions": ["camera", "location", "storage"]
}
```

| Champ | Type | Description |
|-------|------|-------------|
| `id` | String | Identifiant unique (format reverse-domain) |
| `name` | String | Nom affiché dans le store |
| `version` | String | Version sémantique (MAJOR.MINOR.PATCH) |
| `description` | String | Description de l'application |
| `icon` | String | Chemin vers l'icône (PNG, 512x512 recommandé) |
| `author` | String | Nom de l'auteur (optionnel) |
| `permissions` | Array | Permissions requises (optionnel) |

> ⚠️ **Important** : Incrémentez `version` à chaque mise à jour pour que le Studio accepte votre nouveau build.

---

## 📚 SDK OndesBridge - Référence API

### Initialisation

Le SDK `window.Ondes` est injecté automatiquement. Attendez l'événement `OndesReady` :

```javascript
// ✅ CORRECT - Attendre OndesReady
document.addEventListener('OndesReady', () => {
    // Le SDK est prêt
    initApp();
});

// ❌ INCORRECT - Risque d'erreur
document.addEventListener('DOMContentLoaded', () => {
    Ondes.UI.showToast(...); // Peut échouer !
});
```

---

### 1. Ondes.UI - Interface utilisateur

Contrôlez l'interface native de l'application.

#### `showToast(options)`

Affiche une notification temporaire en bas de l'écran.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `message` | String | Texte à afficher |
| `type` | String | `'info'` \| `'success'` \| `'error'` \| `'warning'` |

```javascript
await Ondes.UI.showToast({
    message: "Opération réussie !",
    type: "success"
});
```

---

#### `showAlert(options)`

Affiche une boîte de dialogue modale.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre de la modale |
| `message` | String | Corps du message |
| `buttonText` | String | Texte du bouton (défaut: "OK") |

```javascript
await Ondes.UI.showAlert({
    title: "Attention",
    message: "Voulez-vous vraiment continuer ?",
    buttonText: "Compris"
});
```

---

#### `showConfirm(options)`

Affiche une boîte de confirmation avec deux boutons.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre |
| `message` | String | Message |
| `confirmText` | String | Texte du bouton confirmer |
| `cancelText` | String | Texte du bouton annuler |

**Retourne** : `Promise<Boolean>` - `true` si confirmé, `false` sinon

```javascript
const confirmed = await Ondes.UI.showConfirm({
    title: "Suppression",
    message: "Supprimer cet élément ?",
    confirmText: "Supprimer",
    cancelText: "Annuler"
});

if (confirmed) {
    // Procéder à la suppression
}
```

---

#### `showBottomSheet(options)`

Affiche un menu contextuel depuis le bas.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre du menu |
| `options` | Array | Liste des options `[{id, label, icon?}]` |

**Retourne** : `Promise<String|null>` - L'ID de l'option sélectionnée

```javascript
const choice = await Ondes.UI.showBottomSheet({
    title: "Partager via",
    options: [
        { id: "email", label: "Email", icon: "📧" },
        { id: "sms", label: "SMS", icon: "💬" },
        { id: "copy", label: "Copier le lien", icon: "📋" }
    ]
});

if (choice === "email") {
    // Partager par email
}
```

---

#### `configureAppBar(options)`

Configure la barre de navigation native.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre affiché |
| `visible` | Boolean | Afficher/masquer la barre |
| `backgroundColor` | String | Couleur de fond (hex) |
| `foregroundColor` | String | Couleur du texte (hex) |

```javascript
await Ondes.UI.configureAppBar({
    title: "Paramètres",
    visible: true,
    backgroundColor: "#1a1a2e",
    foregroundColor: "#ffffff"
});
```

---

### 2. Ondes.User - Utilisateur

Accédez aux informations de l'utilisateur connecté.

#### `getProfile()`

Récupère le profil de l'utilisateur courant.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `id` | Number | ID unique |
| `username` | String | Nom d'utilisateur |
| `email` | String | Adresse email |
| `avatar` | String | URL de l'avatar |
| `bio` | String | Biographie |

```javascript
const user = await Ondes.User.getProfile();
console.log(`Connecté en tant que ${user.username}`);
```

---

#### `getAuthToken()`

Récupère le token d'authentification pour vos appels API.

**Retourne** : `Promise<String>` - Token JWT/Bearer

```javascript
const token = await Ondes.User.getAuthToken();

// Utiliser dans vos requêtes
fetch('https://votre-api.com/data', {
    headers: {
        'Authorization': `Token ${token}`
    }
});
```

---

#### `isAuthenticated()`

Vérifie si l'utilisateur est connecté.

**Retourne** : `Promise<Boolean>`

```javascript
const loggedIn = await Ondes.User.isAuthenticated();
if (!loggedIn) {
    showLoginScreen();
}
```

---

### 3. Ondes.Device - Matériel

Interagissez avec le hardware du téléphone.

#### `hapticFeedback(style)`

Déclenche un retour haptique.

| Style | Description |
|-------|-------------|
| `'light'` | Vibration légère |
| `'medium'` | Vibration moyenne |
| `'heavy'` | Vibration forte |
| `'success'` | Pattern succès |
| `'error'` | Pattern erreur |
| `'warning'` | Pattern avertissement |

```javascript
await Ondes.Device.hapticFeedback('success');
```

---

#### `vibrate(duration)`

Fait vibrer l'appareil.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `duration` | Number | Durée en millisecondes |

```javascript
await Ondes.Device.vibrate(500); // Vibre 500ms
```

---

#### `scanQRCode()`

Ouvre le scanner QR Code.

**Retourne** : `Promise<String>` - Contenu décodé

```javascript
try {
    const code = await Ondes.Device.scanQRCode();
    console.log("Code scanné:", code);
} catch (error) {
    console.log("Scan annulé");
}
```

---

#### `getGPSPosition()`

Obtient la position GPS actuelle.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `latitude` | Number | Latitude |
| `longitude` | Number | Longitude |
| `accuracy` | Number | Précision en mètres |

```javascript
const pos = await Ondes.Device.getGPSPosition();
console.log(`Position: ${pos.latitude}, ${pos.longitude}`);
```

---

#### `getInfo()`

Récupère les informations de l'appareil.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `platform` | String | `'ios'` \| `'android'` \| `'macos'` |
| `version` | String | Version de l'OS |
| `model` | String | Modèle de l'appareil |

```javascript
const device = await Ondes.Device.getInfo();
console.log(`Plateforme: ${device.platform}`);
```

---

### 4. Ondes.Storage - Stockage

Base de données persistante et isolée par application.

> 💡 Chaque app a son propre espace de stockage. Les données sont préfixées automatiquement par l'ID de l'app.

#### `set(key, value)`

Sauvegarde une valeur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `key` | String | Clé unique |
| `value` | Any | Valeur (String, Number, Boolean, Object, Array) |

```javascript
// Stocker des préférences
await Ondes.Storage.set('preferences', {
    theme: 'dark',
    notifications: true,
    language: 'fr'
});

// Stocker une valeur simple
await Ondes.Storage.set('lastLogin', Date.now());
```

---

#### `get(key)`

Récupère une valeur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `key` | String | Clé à récupérer |

**Retourne** : `Promise<Any>` - La valeur ou `null`

```javascript
const prefs = await Ondes.Storage.get('preferences');
if (prefs?.theme === 'dark') {
    enableDarkMode();
}
```

---

#### `remove(key)`

Supprime une valeur.

```javascript
await Ondes.Storage.remove('tempData');
```

---

#### `clear()`

Efface toutes les données de l'application.

```javascript
await Ondes.Storage.clear();
```

---

#### `getKeys()`

Liste toutes les clés stockées.

**Retourne** : `Promise<Array<String>>`

```javascript
const keys = await Ondes.Storage.getKeys();
console.log("Clés stockées:", keys);
```

---

### 5. Ondes.App - Système

Gestion du cycle de vie de la mini-app.

#### `getInfo()`

Informations sur l'application courante.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `bundleId` | String | Identifiant de l'app |
| `name` | String | Nom de l'app |
| `version` | String | Version actuelle |
| `platform` | String | Plateforme hôte |
| `sdkVersion` | String | Version du SDK Ondes |

```javascript
const info = await Ondes.App.getInfo();
console.log(`${info.name} v${info.version}`);
```

---

#### `getManifest()`

Récupère le manifest complet de l'app.

**Retourne** : `Promise<Object>` - Contenu du manifest.json

```javascript
const manifest = await Ondes.App.getManifest();
console.log("Permissions:", manifest.permissions);
```

---

#### `close()`

Ferme la mini-app et retourne à l'accueil.

```javascript
const quit = await Ondes.UI.showConfirm({
    title: "Quitter",
    message: "Voulez-vous fermer l'application ?"
});

if (quit) {
    await Ondes.App.close();
}
```

---

### 6. Ondes.Friends - Système social

Gestion complète des relations d'amitié entre utilisateurs.

> 🔐 Toutes ces fonctions nécessitent une authentification.

#### `list()`

Récupère la liste de vos amis.

**Retourne** : `Promise<Array<Friend>>`

| Champ | Type | Description |
|-------|------|-------------|
| `id` | Number | ID de l'utilisateur |
| `username` | String | Nom d'utilisateur |
| `avatar` | String | URL de l'avatar |
| `bio` | String | Biographie |
| `friendshipId` | Number | ID de la relation |
| `friendsSince` | String | Date ISO d'acceptation |

```javascript
const friends = await Ondes.Friends.list();

friends.forEach(friend => {
    console.log(`👤 ${friend.username}`);
});
```

---

#### `request(options)`

Envoie une demande d'amitié.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `username` | String | Nom d'utilisateur cible |
| `userId` | Number | **OU** ID de l'utilisateur |

```javascript
// Par nom d'utilisateur
await Ondes.Friends.request({ username: "alice" });

// Par ID
await Ondes.Friends.request({ userId: 42 });
```

---

#### `getPendingRequests()`

Récupère les demandes reçues en attente.

**Retourne** : `Promise<Array<FriendshipRequest>>`

```javascript
const pending = await Ondes.Friends.getPendingRequests();

pending.forEach(req => {
    console.log(`Demande de ${req.fromUser.username}`);
});
```

---

#### `getSentRequests()`

Récupère les demandes que vous avez envoyées.

**Retourne** : `Promise<Array<FriendshipRequest>>`

---

#### `accept(friendshipId)`

Accepte une demande d'amitié.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `friendshipId` | Number | ID de la demande |

```javascript
await Ondes.Friends.accept(123);
Ondes.UI.showToast({ message: "Ami ajouté !", type: "success" });
```

---

#### `reject(friendshipId)`

Refuse une demande d'amitié.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `friendshipId` | Number | ID de la demande |

```javascript
await Ondes.Friends.reject(123);
```

---

#### `remove(friendshipId)`

Supprime un ami de votre liste.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `friendshipId` | Number | ID de la relation (via `list()`) |

```javascript
const friends = await Ondes.Friends.list();
const target = friends.find(f => f.username === "bob");

if (target) {
    await Ondes.Friends.remove(target.friendshipId);
}
```

---

#### `block(options)`

Bloque un utilisateur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `username` | String | Nom d'utilisateur |
| `userId` | Number | **OU** ID de l'utilisateur |

```javascript
await Ondes.Friends.block({ username: "spammer" });
```

---

#### `unblock(userId)`

Débloque un utilisateur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `userId` | Number | ID de l'utilisateur |

```javascript
await Ondes.Friends.unblock(42);
```

---

#### `getBlocked()`

Liste les utilisateurs bloqués.

**Retourne** : `Promise<Array<Object>>`

```javascript
const blocked = await Ondes.Friends.getBlocked();
console.log(`${blocked.length} utilisateur(s) bloqué(s)`);
```

---

#### `search(query)`

Recherche des utilisateurs.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `query` | String | Terme de recherche (min. 2 caractères) |

**Retourne** : `Promise<Array<UserSearchResult>>`

| Champ | Type | Description |
|-------|------|-------------|
| `id` | Number | ID de l'utilisateur |
| `username` | String | Nom d'utilisateur |
| `avatar` | String | URL de l'avatar |
| `bio` | String | Biographie |
| `friendshipStatus` | String \| null | `'pending'`, `'accepted'`, `'blocked'`, ou `null` |
| `friendshipId` | Number \| null | ID de la relation existante |

```javascript
const results = await Ondes.Friends.search("ali");

results.forEach(user => {
    const status = user.friendshipStatus || "non ami";
    console.log(`${user.username} (${status})`);
});
```

---

#### `getPendingCount()`

Compte les demandes en attente (pour badges de notification).

**Retourne** : `Promise<Number>`

```javascript
const count = await Ondes.Friends.getPendingCount();

if (count > 0) {
    badge.textContent = count;
    badge.style.display = 'block';
}
```

---

### 7. Ondes.Social - Réseau social & Médias

Module complet de réseau social avec support des posts, stories, followers et traitement média avancé (compression d'images, conversion HLS pour vidéos).

> 🔐 Toutes ces fonctions nécessitent une authentification.
> 
> 📹 Les vidéos sont automatiquement converties en HLS (HTTP Live Streaming) pour un streaming adaptatif.
> 
> 🖼️ Les images sont compressées automatiquement (max 1920x1920, qualité 85%).

#### Relations (Followers)

##### `follow(userUuid)`

Suivre un utilisateur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `userUuid` | String | UUID de l'utilisateur à suivre |

```javascript
await Ondes.Social.follow('user_uuid_456');
Ondes.UI.showToast({ message: "Utilisateur suivi !", type: "success" });
```

---

##### `unfollow(userUuid)`

Arrêter de suivre un utilisateur.

```javascript
await Ondes.Social.unfollow('user_uuid_456');
```

---

##### `getFollowers(userUuid?, options?)`

Liste des followers d'un utilisateur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `userUuid` | String | UUID (optionnel, défaut: utilisateur courant) |
| `options.limit` | Number | Nombre de résultats (défaut: 20) |
| `options.offset` | Number | Décalage pour pagination |

```javascript
// Mes followers
const myFollowers = await Ondes.Social.getFollowers();

// Followers d'un autre utilisateur
const theirFollowers = await Ondes.Social.getFollowers('user_uuid', { limit: 50 });
```

---

##### `getFollowing(userUuid?, options?)`

Liste des utilisateurs suivis.

```javascript
const following = await Ondes.Social.getFollowing();
console.log(`Vous suivez ${following.length} utilisateurs`);
```

---

##### `getFollowStats(userUuid?)`

Statistiques de suivi.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `followers_count` | Number | Nombre de followers |
| `following_count` | Number | Nombre de suivis |
| `mutual_count` | Number | Nombre d'amis mutuels |

```javascript
const stats = await Ondes.Social.getFollowStats();
console.log(`${stats.followers_count} followers, ${stats.following_count} suivis`);
```

---

#### Publications (Posts)

##### `publish(options)`

Publie un nouveau post avec médias.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `content` | String | Texte du post |
| `media` | Array<String> | Chemins des fichiers médias |
| `visibility` | String | `'public'` \| `'followers'` \| `'private'` \| `'local_mesh'` |
| `tags` | Array<String> | Hashtags (sans #) |
| `location` | String | Lieu (optionnel) |

```javascript
// Publier un post avec image
await Ondes.Social.publish({
    content: "Ma super photo !",
    media: ["/path/to/image.jpg"],
    visibility: "public",
    tags: ["travel", "summer"]
});

// Publier une vidéo (convertie automatiquement en HLS)
await Ondes.Social.publish({
    content: "Nouveau clip 🎬",
    media: ["/path/to/video.mp4"],
    visibility: "followers"
});
```

> 💡 Les images sont automatiquement compressées et les vidéos converties en streaming adaptatif HLS.

---

##### `getFeed(options?)`

Récupère le fil d'actualité personnalisé.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `limit` | Number | Nombre de posts (défaut: 20) |
| `offset` | Number | Décalage pour pagination |
| `algorithm` | String | `'chronological'` \| `'trending'` (défaut) |
| `following_only` | Boolean | Uniquement les suivis |
| `media_type` | String | Filtrer par type: `'image'` \| `'video'` |

**Retourne** : `Promise<Array<Post>>`

| Champ | Type | Description |
|-------|------|-------------|
| `uuid` | String | Identifiant unique |
| `author` | Object | Informations auteur |
| `content` | String | Texte du post |
| `media` | Array | Fichiers médias (avec URLs HLS si vidéo) |
| `likes_count` | Number | Nombre de likes |
| `comments_count` | Number | Nombre de commentaires |
| `user_has_liked` | Boolean | L'utilisateur a liké |
| `user_has_bookmarked` | Boolean | Post sauvegardé |
| `created_at` | String | Date ISO de création |

```javascript
// Feed par défaut (algorithme trending)
const feed = await Ondes.Social.getFeed();

// Feed chronologique des suivis uniquement
const chronoFeed = await Ondes.Social.getFeed({
    algorithm: 'chronological',
    following_only: true,
    limit: 30
});

// Feed vidéos uniquement (style TikTok)
const videoFeed = await Ondes.Social.getFeed({
    media_type: 'video',
    algorithm: 'trending'
});
```

---

##### `getPost(postUuid)`

Récupère un post spécifique.

```javascript
const post = await Ondes.Social.getPost('post_uuid_123');
console.log(`${post.likes_count} likes`);
```

---

##### `deletePost(postUuid)`

Supprime un de vos posts.

```javascript
const confirmed = await Ondes.UI.showConfirm({
    title: "Supprimer",
    message: "Supprimer ce post ?"
});

if (confirmed) {
    await Ondes.Social.deletePost('post_uuid_123');
}
```

---

##### `getUserPosts(userUuid?, options?)`

Posts d'un utilisateur.

```javascript
// Mes posts
const myPosts = await Ondes.Social.getUserPosts();

// Posts d'un autre utilisateur
const theirPosts = await Ondes.Social.getUserPosts('user_uuid', { limit: 20 });
```

---

#### Interactions (Likes, Commentaires, Bookmarks)

##### `like(postUuid)`

Like un post.

```javascript
await Ondes.Social.like('post_uuid_123');
```

---

##### `unlike(postUuid)`

Retire le like.

```javascript
await Ondes.Social.unlike('post_uuid_123');
```

---

##### `comment(postUuid, content, parentUuid?)`

Ajoute un commentaire.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `postUuid` | String | UUID du post |
| `content` | String | Texte du commentaire |
| `parentUuid` | String | UUID du commentaire parent (réponse) |

```javascript
// Commentaire direct
await Ondes.Social.comment('post_uuid', "Super post !");

// Réponse à un commentaire
await Ondes.Social.comment('post_uuid', "@user merci !", 'parent_comment_uuid');
```

---

##### `getComments(postUuid, options?)`

Liste les commentaires d'un post.

```javascript
const comments = await Ondes.Social.getComments('post_uuid');

comments.forEach(c => {
    console.log(`${c.author.username}: ${c.content}`);
});
```

---

##### `likeComment(commentUuid)`

Like un commentaire.

```javascript
await Ondes.Social.likeComment('comment_uuid');
```

---

##### `deleteComment(commentUuid)`

Supprime un de vos commentaires.

```javascript
await Ondes.Social.deleteComment('comment_uuid');
```

---

##### `bookmark(postUuid)`

Sauvegarde un post.

```javascript
await Ondes.Social.bookmark('post_uuid');
Ondes.UI.showToast({ message: "Post sauvegardé", type: "info" });
```

---

##### `removeBookmark(postUuid)`

Retire un post des favoris.

```javascript
await Ondes.Social.removeBookmark('post_uuid');
```

---

##### `getBookmarks(options?)`

Liste vos posts sauvegardés.

```javascript
const saved = await Ondes.Social.getBookmarks({ limit: 50 });
```

---

#### Stories

##### `createStory(options)`

Crée une story (24h de visibilité).

| Paramètre | Type | Description |
|-----------|------|-------------|
| `media` | String | Chemin du fichier média |
| `media_type` | String | `'image'` \| `'video'` |
| `duration` | Number | Durée d'affichage en secondes (optionnel) |

```javascript
await Ondes.Social.createStory({
    media: '/path/to/photo.jpg',
    media_type: 'image'
});
```

---

##### `getStories()`

Récupère les stories des utilisateurs suivis.

**Retourne** : `Promise<Array<UserStories>>`

```javascript
const stories = await Ondes.Social.getStories();

stories.forEach(userStory => {
    console.log(`${userStory.user.username} a ${userStory.stories.length} stories`);
});
```

---

##### `viewStory(storyUuid)`

Marque une story comme vue.

```javascript
await Ondes.Social.viewStory('story_uuid');
```

---

##### `deleteStory(storyUuid)`

Supprime une de vos stories.

```javascript
await Ondes.Social.deleteStory('story_uuid');
```

---

#### Profil

##### `getProfile(userUuid?)`

Récupère un profil utilisateur.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `uuid` | String | UUID unique |
| `username` | String | Nom d'utilisateur |
| `display_name` | String | Nom affiché |
| `bio` | String | Biographie |
| `profile_picture` | String | URL de l'avatar |
| `posts_count` | Number | Nombre de posts |
| `followers_count` | Number | Nombre de followers |
| `following_count` | Number | Nombre de suivis |
| `is_following` | Boolean | Est-ce que vous suivez |
| `follows_you` | Boolean | Est-ce qu'il vous suit |

```javascript
// Mon profil
const me = await Ondes.Social.getProfile();

// Profil d'un autre utilisateur
const user = await Ondes.Social.getProfile('user_uuid');
```

---

##### `updateProfile(data)`

Met à jour votre profil.

```javascript
await Ondes.Social.updateProfile({
    display_name: "Nouveau Nom",
    bio: "Ma nouvelle bio 🚀"
});
```

---

#### Médias

##### `pickMedia(options)`

Sélectionne des médias depuis la galerie.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `multiple` | Boolean | Sélection multiple (défaut: false) |
| `maxFiles` | Number | Maximum de fichiers |
| `allowVideo` | Boolean | Autoriser les vidéos |
| `videoOnly` | Boolean | Uniquement les vidéos |

**Retourne** : `Promise<Array<MediaFile>>`

```javascript
// Sélectionner plusieurs images
const images = await Ondes.Social.pickMedia({
    multiple: true,
    maxFiles: 10
});

// Sélectionner une vidéo
const video = await Ondes.Social.pickMedia({
    multiple: false,
    allowVideo: true,
    videoOnly: true
});
```

---

#### Exemple complet : Mini Instagram

```javascript
document.addEventListener('OndesReady', async () => {
    // Charger le feed
    const feed = await Ondes.Social.getFeed({ limit: 20 });
    
    feed.forEach(post => {
        renderPost(post);
    });
    
    // Suivre quelqu'un
    async function followUser(uuid) {
        await Ondes.Social.follow(uuid);
        Ondes.UI.showToast({ message: "Suivi !", type: "success" });
    }
    
    // Publier un post
    async function createPost() {
        const media = await Ondes.Social.pickMedia({ 
            multiple: true, 
            maxFiles: 10,
            allowVideo: true
        });
        
        if (media.length > 0) {
            await Ondes.Social.publish({
                content: document.getElementById('caption').value,
                media: media.map(m => m.path),
                visibility: 'public'
            });
            
            Ondes.UI.showToast({ message: "Publié !", type: "success" });
        }
    }
    
    // Double-tap pour liker
    function onDoubleTap(postUuid) {
        Ondes.Social.like(postUuid);
        showHeartAnimation();
    }
});
```

---

## 🖥️ API Backend Django

L'API REST est structurée en trois applications Django :

### App `store` - Gestion des applications

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/apps/` | GET | Liste toutes les mini-apps |
| `/api/auth/register/` | POST | Créer un compte |
| `/api/auth/login/` | POST | Connexion (retourne token) |
| `/api/auth/profile/` | GET/PUT | Profil utilisateur |
| `/api/studio/apps/` | GET/POST | Gérer ses apps (Dev Studio) |
| `/api/studio/apps/<id>/` | GET/PUT/DELETE | Détails d'une app |
| `/api/studio/apps/<id>/versions/` | POST | Upload nouvelle version |

### App `friends` - Système social

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/friends/` | GET | Liste des amis |
| `/api/friends/request/` | POST | Envoyer une demande |
| `/api/friends/pending/` | GET | Demandes reçues |
| `/api/friends/sent/` | GET | Demandes envoyées |
| `/api/friends/<id>/accept/` | POST | Accepter une demande |
| `/api/friends/<id>/reject/` | POST | Refuser une demande |
| `/api/friends/<id>/remove/` | POST | Supprimer un ami |
| `/api/friends/block/` | POST | Bloquer un utilisateur |
| `/api/friends/unblock/` | POST | Débloquer |
| `/api/friends/blocked/` | GET | Liste des bloqués |
| `/api/friends/search/` | GET | Rechercher des utilisateurs |

### App `social` - Réseau social & Médias

#### Relations (Follow)

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/social/follow/` | POST | Suivre un utilisateur |
| `/api/social/unfollow/` | POST | Ne plus suivre |
| `/api/social/followers/` | GET | Liste des followers |
| `/api/social/followers/<uuid>/` | GET | Followers d'un utilisateur |
| `/api/social/following/` | GET | Utilisateurs suivis |
| `/api/social/following/<uuid>/` | GET | Suivis d'un utilisateur |
| `/api/social/follow-stats/` | GET | Statistiques de suivi |

#### Publications

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/social/posts/` | GET | Feed personnalisé |
| `/api/social/posts/` | POST | Publier un post (multipart) |
| `/api/social/posts/<uuid>/` | GET | Détails d'un post |
| `/api/social/posts/<uuid>/` | DELETE | Supprimer un post |
| `/api/social/posts/user/` | GET | Mes posts |
| `/api/social/posts/user/<uuid>/` | GET | Posts d'un utilisateur |

#### Interactions

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/social/posts/<uuid>/like/` | POST | Liker un post |
| `/api/social/posts/<uuid>/unlike/` | POST | Retirer le like |
| `/api/social/posts/<uuid>/comments/` | GET | Commentaires d'un post |
| `/api/social/posts/<uuid>/comments/` | POST | Ajouter un commentaire |
| `/api/social/comments/<uuid>/like/` | POST | Liker un commentaire |
| `/api/social/comments/<uuid>/` | DELETE | Supprimer un commentaire |
| `/api/social/posts/<uuid>/bookmark/` | POST | Sauvegarder un post |
| `/api/social/posts/<uuid>/unbookmark/` | POST | Retirer des favoris |
| `/api/social/bookmarks/` | GET | Posts sauvegardés |

#### Stories

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/social/stories/` | GET | Stories des suivis |
| `/api/social/stories/` | POST | Créer une story |
| `/api/social/stories/<uuid>/view/` | POST | Marquer comme vue |
| `/api/social/stories/<uuid>/` | DELETE | Supprimer une story |

#### Profil

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/social/profile/` | GET | Mon profil |
| `/api/social/profile/` | PUT | Mettre à jour mon profil |
| `/api/social/profile/<uuid>/` | GET | Profil d'un utilisateur |

### Traitement des médias

Les médias uploadés sont traités automatiquement :

| Type | Traitement |
|------|------------|
| **Images** | Compression (max 1920×1920, qualité 85%, JPEG) |
| **Vidéos** | Conversion HLS avec variantes adaptatives (360p/480p/720p/1080p) |

#### Structure des fichiers vidéo HLS

```
media/
└── posts/
    └── <post_uuid>/
        └── <media_uuid>/
            ├── original.mp4
            ├── master.m3u8      # Playlist principale
            ├── 360p.m3u8        # Variante 360p
            ├── 480p.m3u8        # Variante 480p
            ├── 720p.m3u8        # Variante 720p
            ├── 1080p.m3u8       # Variante 1080p
            └── *.ts             # Segments vidéo
```

### Authentification

Toutes les requêtes authentifiées nécessitent le header :

```http
Authorization: Token <votre_token>
```

---

## 📂 Exemples

Le dossier `examples/` contient plusieurs mini-apps de démonstration :

| Exemple | Description |
|---------|-------------|
| `hello-world/` | App minimale |
| `full-demo/` | Démo complète de toutes les APIs |
| `camera-demo/` | Scanner QR Code |
| `map-app/` | Utilisation du GPS |
| `meteo-app/` | App météo avec API externe |
| `friends-demo/` | Système social complet |
| `instagram-demo/` | 📸 Clone Instagram avec Ondes.Social (posts, stories, likes, commentaires) |
| `tiktok-demo/` | 🎬 Clone TikTok avec feed vidéo vertical et streaming HLS |

### Lancer un exemple

1. Copiez le dossier de l'exemple
2. Zippez-le
3. Uploadez via le Dev Studio
4. Lancez l'app depuis l'accueil

---

## ⚠️ Gestion des erreurs

Toutes les fonctions du SDK retournent des Promises. En cas d'erreur :

```javascript
try {
    const result = await Ondes.Device.scanQRCode();
} catch (error) {
    console.error(error);
    // { code: "PERMISSION_DENIED", message: "..." }
}
```

### Codes d'erreur courants

| Code | Description |
|------|-------------|
| `PERMISSION_DENIED` | L'utilisateur a refusé la permission |
| `NOT_SUPPORTED` | Fonctionnalité non disponible sur cet appareil |
| `CANCELLED` | L'utilisateur a annulé l'action |
| `NETWORK_ERROR` | Erreur de connexion réseau |
| `AUTH_REQUIRED` | Authentification requise |
| `NOT_FOUND` | Ressource non trouvée |
| `INVALID_PARAMS` | Paramètres invalides |

### Pattern recommandé

```javascript
async function safeCall(fn, fallback = null) {
    try {
        return await fn();
    } catch (error) {
        console.warn('Erreur:', error.message);
        
        if (error.code === 'PERMISSION_DENIED') {
            Ondes.UI.showAlert({
                title: "Permission requise",
                message: "Veuillez autoriser l'accès pour continuer."
            });
        }
        
        return fallback;
    }
}

// Utilisation
const position = await safeCall(
    () => Ondes.Device.getGPSPosition(),
    { latitude: 0, longitude: 0 }
);
```

---

## 📄 Licence

MIT License - Voir [LICENSE](LICENSE)

---

<p align="center">
  <strong>🌊 Ondes Core</strong><br>
  <em>Créez. Distribuez. Connectez.</em>
</p>
