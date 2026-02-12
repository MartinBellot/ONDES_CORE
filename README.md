# 🌊 Ondes Core

> 📘 **Documentation en ligne :** [**https://martinbellot.github.io/ONDES_CORE/**](https://martinbellot.github.io/ONDES_CORE/)

Bienvenue sur la documentation officielle de **Ondes Core**, la plateforme de mini-applications web natives.

Ce dépôt contient le code source complet de l'écosystème :
- L'application hôte (Flutter)
- L'API backend (Django)
- Le SDK JavaScript (Bridge)
- Le SDK Flutter ([pub.dev/packages/ondes_sdk](https://pub.dev/packages/ondes_sdk))

---

## 📚 Documentation

Pour une expérience de lecture optimale, consultez **[notre site de documentation](https://martinbellot.github.io/ONDES_CORE/)**.

Sinon, naviguez dans les fichiers Markdown directement ici :

### 🚀 Commencer ici
- **[Présentation](docs/introduction.md)** : Comprendre ce qu'est Ondes Core.
- **[Architecture](docs/architecture.md)** : Comment fonctionnent le Bridge, le WebView et le Backend.
- **[Installation](docs/installation.md)** : Guide pas-à-pas pour installer le projet sur votre machine.

### 👨‍💻 Créer une Mini-App
- **[Guide du développeur](docs/mini_app_guide.md)** : Créer sa première app, structure, manifest.json.
- **[🔒 Sécurité & Permissions](SECURITY.md)** : Modèle de permissions "Sandbox", cycle de vie et bonnes pratiques.
- **[🧪 Ondes Lab](docs/lab.md)** : Environnement de développement, serveur local, debugging.
- **[Exemples](docs/examples.md)** : Liste des applications de démonstration fournies.

### 🛠️ SDK - Référence API

Deux SDKs sont disponibles selon votre technologie :

#### 🌐 SDK JavaScript (HTML/CSS/JS)
L'objet `window.Ondes` est votre porte d'entrée vers le natif.

- **[Introduction au SDK](docs/sdk/index.md)** : Initialisation et bonnes pratiques.
- **Modules :**
  - 🎨 **[Interface (UI)](docs/sdk/ui.md)** : Toasts, Modales, Navigation.
  - 👤 **[Utilisateur (User)](docs/sdk/user.md)** : Profil et authentification.
  - 📱 **[Matériel (Device)](docs/sdk/device.md)** : Caméra, GPS, Vibration.
  - 💾 **[Stockage (Storage)](docs/sdk/storage.md)** : Données persistantes.
  - 📦 **[Application (App)](docs/sdk/app.md)** : Infos et cycle de vie.
  - 👥 **[Amis (Friends)](docs/sdk/friends.md)** : Gestion du graphe d'amitié.
  - 🌍 **[Social (Social)](docs/sdk/social.md)** : Feed, Posts, Stories et Médias.

#### 💙 SDK Flutter (Dart)
Package Flutter pour créer des mini-apps en Dart.

- **[SDK Flutter](docs/sdk/flutter.md)** : Guide complet, installation, et API.

### 🖥️ Backend
- **[API Django](docs/backend.md)** : Structure du serveur et endpoints.

---

## 🆚 Comparatif : Pourquoi Ondes Core ?

Ondes Core n'est pas juste une alternative technique, c'est un changement de paradigme. Vous ne construisez pas une "App", vous construisez un **Écosystème**.

### 1. ONDES_CORE vs Capacitor / Cordova
> *L'analogie : Capacitor est un outil de construction de maison. ONDES est un quartier résidentiel géré.*

* **Capacitor :** Vous créez une application autonome (`.ipa` / `.apk`). Vous êtes responsable de tout : l'authentification, le backend, la soumission aux stores, et les mises à jour sont lentes.
* **ONDES_CORE :**
    *   **Distribution instantanée :** Vous publiez une Mini-App sur votre Store interne. Elle est disponible immédiatement pour tous les utilisateurs.
    *   **Infrastructure fournie :** L'authentification, le profil utilisateur, et le stockage sont déjà gérés par le Core.

### 2. ONDES_CORE vs Flutter "Pur"
> *L'analogie : Flutter est le moteur de la voiture. ONDES est la voiture complète où les passagers (mini-apps) peuvent monter.*

* **Flutter Pur :** Produit un binaire monolithique. Pour ajouter une fonctionnalité, vous devez l'intégrer au code source, recompiler et redéployer.
* **ONDES_CORE :**
    *   **Démocratisation du code :** Le shell est en Flutter (robuste), mais les Mini-Apps peuvent être écrites en HTML/JS simple (accessible).
    *   **Isolation :** Si une Mini-App plante, le Core survit.
    *   **Hot-Reload en Prod :** Vous pouvez mettre à jour une partie de l'application sans toucher au reste.

### 3. ONDES_CORE vs PWA (Progressive Web Apps)
> *L'analogie : Une PWA est un site web mobile. ONDES est un site web avec des super-pouvoirs natifs.*

* **PWA :** Tourne dans un navigateur générique. Elle est isolée du système et ne connait pas l'utilisateur.
* **ONDES_CORE :**
    *   **Contexte Social (Killer Feature) :** Une Mini-App sait *qui* est l'utilisateur et qui sont ses *amis*. Elle peut poster sur son mur et accéder à son graphe social.
    *   **Pont Natif Avancé :** `OndesBridge` expose des fonctionnalités natives (HLS streaming, UI native).

### 📊 En résumé

| Fonctionnalité | **Capacitor / Cordova** 🐢 | **Flutter Pur** 🏎️ | **PWA** 🌐 | **ONDES CORE** 🌊 |
| :--- | :--- | :--- | :--- | :--- |
| **Modèle** | Constructeur d'App | Moteur Natif | Site Mobile | **OS de Mini-Apps** |
| **Distribution** | Stores (Apple/Google) | Stores (Apple/Google) | URL (Web) | **Store Interne Instantané** |
| **Mise à jour** | Lente (Validation Store) | Lente (Validation Store) | Instantanée | **Instantanée & Chaude** |
| **Isolation** | Monolithique | Monolithique | Isolée (Sandbox) | **Sandboxed & Connectée** |
| **Social** | À construire (0%) | À construire (0%) | Nul (pas d'identité) | **Natif (Feed, Amis, Graph)** |

### 🏆 Pourquoi choisir ONDES_CORE ?

1.  **L'effet Réseau (Social Graph) 🤝** : Vos mini-apps naissent connectées.
2.  **Développement Décentralisé 🧩** : Plusieurs équipes peuvent travailler sur des apps différentes sans toucher au Shell.
3.  **Time-to-Market ⚡** : Pas de compilation native ni de validation store pour les mini-apps.

---

## Statut du projet

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Django](https://img.shields.io/badge/Django-5.x-092E20?logo=django)](https://djangoproject.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---
<p align="center">
  <em>Créez. Distribuez. Connectez.</em>
</p>
