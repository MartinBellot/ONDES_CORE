# 🧪 Ondes Lab - Environnement de développement

Le **Lab** est l'environnement de développement intégré à Ondes Core. Il vous permet de tester vos mini-applications en temps réel sur votre appareil, avec accès complet aux APIs natives.

---

## 🎯 Pourquoi utiliser le Lab ?

| Sans le Lab | Avec le Lab |
|-------------|-------------|
| Compiler → Zipper → Uploader → Tester | Coder → Sauvegarder → Tester instantanément |
| Rechargement manuel à chaque modification | Hot Reload automatique |
| Debugging difficile | Console de debug native |
| Pas d'accès aux APIs Ondes en développement | Toutes les APIs accessibles |

---

## 🚀 Démarrage rapide

### Prérequis

- L'app **Ondes Core** installée sur votre téléphone/tablette
- Votre ordinateur et appareil sur le **même réseau WiFi**

### Workflow général

```
┌─────────────────┐       WiFi        ┌─────────────────┐
│   Ordinateur    │◄────────────────►│  Téléphone      │
│                 │                   │  Ondes Core     │
│  Serveur local  │   http://IP:port  │                 │
│  (port 3000)    │──────────────────►│  Lab → WebView  │
└─────────────────┘                   └─────────────────┘
```

---

## 🌐 Apps JavaScript (HTML/CSS/JS)

### Méthode 1 : Extension VS Code Live Server (Recommandé)

#### 1. Installer l'extension

Dans VS Code, installez l'extension **"Live Server"** de Ritwick Dey.

#### 2. Configurer pour accès réseau

Dans les paramètres VS Code (`settings.json`) :

```json
{
  "liveServer.settings.host": "0.0.0.0",
  "liveServer.settings.port": 3000
}
```

#### 3. Lancer le serveur

1. Ouvrez votre projet dans VS Code
2. Clic droit sur `index.html` → **"Open with Live Server"**
3. Notez l'URL affichée (ex: `http://192.168.1.42:3000`)

#### 4. Connecter depuis Ondes Lab

1. Ouvrez **Ondes Core** sur votre mobile
2. Allez dans l'onglet **Lab** 
3. Entrez l'URL de votre serveur
4. Appuyez sur **Lancer**

> ✨ **Hot Reload** : Chaque modification de fichier rafraîchit automatiquement l'app !

---

### Méthode 2 : Serveur Python

```bash
# Dans le dossier de votre projet
cd mon-app

# Python 3
python3 -m http.server 3000 --bind 0.0.0.0

# Ou Python 2
python -m SimpleHTTPServer 3000
```

Puis trouvez votre IP :

```bash
# macOS / Linux
ifconfig | grep "inet " | grep -v 127.0.0.1

# Windows (PowerShell)
(Get-NetIPAddress -AddressFamily IPv4).IPAddress
```

---

### Méthode 3 : Node.js (http-server)

```bash
# Installation globale (une seule fois)
npm install -g http-server

# Lancer le serveur
cd mon-app
http-server -p 3000 --host 0.0.0.0
```

---

## 💙 Apps Flutter Web

### Méthode 1 : Serveur de développement Flutter (Recommandé)

C'est la méthode la plus efficace, avec Hot Reload intégré.

#### 1. Lancer le serveur

```bash
cd mon_projet_flutter

flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0
```

**Explications des options :**

| Option | Description |
|--------|-------------|
| `-d web-server` | Lance un serveur web au lieu d'ouvrir un navigateur |
| `--web-port=3000` | Port d'écoute (modifiable) |
| `--web-hostname=0.0.0.0` | Écoute sur toutes les interfaces (obligatoire pour accès mobile) |

#### 2. Trouver votre IP locale

```bash
# macOS
ipconfig getifaddr en0

# Linux
hostname -I | awk '{print $1}'

# Windows (PowerShell)
(Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4).IPAddress
```

#### 3. Connecter depuis Ondes Lab

Entrez l'URL dans le Lab : `http://VOTRE_IP:3000`

> 🔥 **Hot Reload** : Appuyez sur `r` dans le terminal pour recharger, ou `R` pour redémarrer.

---

### Méthode 2 : Build de production

Pour tester la version finale avant publication :

#### 1. Compiler en mode release

```bash
flutter build web --release
```

Les fichiers sont générés dans `build/web/`.

#### 2. Servir les fichiers

```bash
cd build/web

# Avec Python
python3 -m http.server 3000 --bind 0.0.0.0

# Ou avec Node.js
npx http-server -p 3000 --host 0.0.0.0
```

---

## 📱 Scanner QR Code

Le Lab intègre un scanner QR pour connexion rapide.

### Générer un QR Code

#### En ligne
Utilisez [qr-code-generator.com](https://www.qr-code-generator.com/) ou [goqr.me](https://goqr.me/).

#### En ligne de commande

```bash
# macOS (avec Homebrew)
brew install qrencode
qrencode -o qr.png "http://192.168.1.42:3000"
open qr.png

# Linux
sudo apt install qrencode
qrencode -o qr.png "http://192.168.1.42:3000"

# Avec Node.js (multi-plateforme)
npx qrcode-terminal "http://192.168.1.42:3000"
```

### Utilisation

1. Dans Ondes Lab, appuyez sur **"Scanner un QR Code"**
2. Visez le QR code avec la caméra
3. L'app se lance automatiquement

---

## 🐛 Debugging

### Console JavaScript

Les `console.log()` de votre mini-app sont visibles dans la console de développement de Flutter (si vous exécutez Ondes Core en mode debug).

### Logs Flutter

Pour les apps Flutter Web, utilisez les outils de debug habituels :

```bash
# Lancer avec logs détaillés
flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0 -v
```

### Vérifier la connexion

Si l'app ne se charge pas :

1. **Vérifier le réseau** : Les deux appareils sont-ils sur le même WiFi ?
2. **Vérifier le firewall** : Le port est-il ouvert ?
   ```bash
   # macOS - Ouvrir temporairement le port 3000
   sudo pfctl -d
   ```
3. **Tester l'URL** : Ouvrez l'URL dans le navigateur de votre téléphone
4. **Vérifier l'IP** : L'IP change-t-elle en fonction du réseau ?

---

## 🔄 Workflow recommandé

```
┌─────────────────────────────────────────────────────────┐
│                    DÉVELOPPEMENT                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. Coder sur votre ordinateur                          │
│  2. Lancer le serveur local (port 3000)                 │
│  3. Connecter via Ondes Lab                             │
│  4. Modifier le code → Auto-refresh                     │
│  5. Tester les APIs natives sur l'appareil              │
│                                                          │
├─────────────────────────────────────────────────────────┤
│                    PUBLICATION                           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  6. flutter build web --release  (ou zipper le dossier) │
│  7. Créer/vérifier manifest.json                        │
│  8. Zipper le contenu                                   │
│  9. Uploader via Ondes Studio                           │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## ⚠️ Problèmes courants

### "Impossible de se connecter"

| Cause | Solution |
|-------|----------|
| Firewall bloque le port | Désactiver temporairement ou autoriser le port |
| Appareils sur réseaux différents | Vérifier la connexion WiFi |
| Serveur non démarré | Vérifier que le terminal affiche le serveur actif |
| Mauvaise IP | Réexécuter `ifconfig` / `ipconfig` |

### "Page blanche"

| Cause | Solution |
|-------|----------|
| Erreur JavaScript | Vérifier la console du navigateur |
| `index.html` manquant | Vérifier la structure du projet |
| CORS bloqué | Ajouter les headers CORS si nécessaire |

### "SDK Ondes non disponible"

Le SDK n'est injecté que lorsque l'app tourne dans Ondes Core :

```javascript
// JavaScript
document.addEventListener('OndesReady', () => {
  // Ondes disponible ici
});

// Fallback pour test navigateur
if (typeof Ondes === 'undefined') {
  console.log('Mode développement hors Ondes');
}
```

```dart
// Flutter
if (!Ondes.isReady) {
  // Mode développement hors Ondes
}
```

---

## 📚 Ressources

- [Guide du développeur Mini-App](mini_app_guide.md)
- [SDK JavaScript](sdk/index.md)
- [SDK Flutter](sdk/flutter.md)
- [Exemples de mini-apps](examples.md)
