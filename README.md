# 🌊 Ondes Core

Bienvenue sur la documentation officielle de **Ondes Core**, la plateforme de mini-applications web natives.

Ce dépôt contient le code source complet de l'écosystème :
- L'application hôte (Flutter)
- L'API backend (Django)
- Le SDK JavaScript (Bridge)
- Le SDK Flutter ([pub.dev/packages/ondes_sdk](https://pub.dev/packages/ondes_sdk))

---

## 📚 Documentation

Naviguez dans les fichiers Markdown directement ici :

### 🚀 Commencer ici
- **[Présentation](docs/introduction.md)** : Comprendre ce qu'est Ondes Core.
- **[Architecture](docs/architecture.md)** : Comment fonctionnent le Bridge, le WebView et le Backend.
- **[Installation](docs/installation.md)** : Guide pas-à-pas pour installer le projet sur votre machine.

### 👨‍💻 Créer une Mini-App
- **[Guide du développeur](docs/mini_app_guide.md)** : Créer sa première app, structure, manifest.json.
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

## ⚡ Quick Start - Développer une Mini-App Flutter

```bash
# 1. Créer un nouveau projet Flutter Web
flutter create --platforms=web my_ondes_app
cd my_ondes_app

# 2. Ajouter le SDK Ondes
flutter pub add ondes_sdk

# 3. Lancer le serveur de développement
flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0

# 4. Trouver votre IP locale
ifconfig | grep "inet " | grep -v 127.0.0.1

# 5. Dans Ondes Core (mobile) → Lab → Entrer http://VOTRE_IP:3000 → Lancer
```

Code minimal (`lib/main.dart`) :

```dart
import 'package:flutter/material.dart';
import 'package:ondes_sdk/ondes_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Ondes.ensureReady().catchError((_) {}); // Silencieux hors Ondes
  runApp(MaterialApp(home: Scaffold(body: Center(child: Text('Hello Ondes!')))));
}
```

📖 Guide complet : [SDK Flutter](docs/sdk/flutter.md) | 🧪 Debugging : [Ondes Lab](docs/lab.md)

---

## Statut du projet

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Django](https://img.shields.io/badge/Django-5.x-092E20?logo=django)](https://djangoproject.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---
<p align="center">
  <em>Créez. Distribuez. Connectez.</em>
</p>
