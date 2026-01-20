# 📱 SDK Flutter - Ondes SDK

Ce guide explique comment créer une mini-application **Flutter Web** qui s'exécute dans l'environnement Ondes Core.

> 💡 **Différence avec le SDK JavaScript** : Le SDK Flutter permet de développer des mini-apps en Dart/Flutter au lieu de HTML/JS, tout en bénéficiant des mêmes fonctionnalités natives.

---

## 🎯 Prérequis

- Flutter SDK 3.24+ installé
- Un appareil avec l'app Ondes Core installée
- Les deux appareils sur le même réseau WiFi (pour le développement)

---

## 📦 Installation

### 1. Créer un nouveau projet Flutter

```bash
flutter create --platforms=web my_ondes_app
cd my_ondes_app
```

### 2. Ajouter la dépendance `ondes_sdk`

```bash
flutter pub add ondes_sdk
```

Ou manuellement dans votre `pubspec.yaml` :

```yaml
dependencies:
  flutter:
    sdk: flutter
  ondes_sdk: ^1.1.0
```

Puis exécutez :

```bash
flutter pub get
```

---

## 🚀 Première Mini-App Flutter

### Code minimal

Remplacez le contenu de `lib/main.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:ondes_sdk/ondes_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ⚠️ IMPORTANT : Attendre que le bridge soit prêt
  try {
    await Ondes.ensureReady();
    print('✅ Ondes SDK connecté !');
  } catch (e) {
    print('⚠️ Mode développement (hors Ondes) : $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Mini-App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _username = 'Chargement...';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (!Ondes.isReady) {
      setState(() => _username = 'Mode développement');
      return;
    }

    final profile = await Ondes.user.getProfile();
    setState(() {
      _username = profile?.username ?? 'Non connecté';
    });
  }

  Future<void> _showToast() async {
    if (!Ondes.isReady) return;
    
    await Ondes.ui.showToast(
      message: 'Bonjour depuis Flutter ! 🎉',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Mini-App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bienvenue, $_username !',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showToast,
              icon: const Icon(Icons.celebration),
              label: const Text('Afficher un Toast'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🔧 Développement et Test

### Méthode 1 : Serveur de développement Flutter (Recommandé)

#### Étape 1 : Lancer le serveur web Flutter

```bash
# Dans le dossier de votre projet
flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0
```

> 📝 **Explications des options :**
> - `-d web-server` : Lance un serveur web au lieu d'un navigateur
> - `--web-port=3000` : Port du serveur (modifiable)
> - `--web-hostname=0.0.0.0` : Écoute sur toutes les interfaces réseau (nécessaire pour accès depuis mobile)

#### Étape 2 : Trouver votre adresse IP

```bash
# macOS / Linux
ifconfig | grep "inet " | grep -v 127.0.0.1

# Windows
ipconfig
```

Notez votre IP locale (ex: `192.168.1.42`).

#### Étape 3 : Connecter depuis Ondes Lab

1. Ouvrez l'app **Ondes Core** sur votre mobile
2. Allez dans l'onglet **Lab** 
3. Entrez l'URL : `http://192.168.1.42:3000`
4. Appuyez sur **Lancer**

🎉 Votre app Flutter s'affiche dans Ondes avec accès à toutes les APIs natives !

> 💡 **Hot Reload** : Flutter Web supporte le hot reload. Les modifications de code se reflètent automatiquement.

---

### Méthode 2 : Build de production + serveur statique

#### Étape 1 : Compiler en mode release

```bash
flutter build web --release
```

Les fichiers sont générés dans `build/web/`.

#### Étape 2 : Lancer un serveur local

```bash
# Avec Python 3
cd build/web
python3 -m http.server 3000

# Ou avec Node.js (http-server)
npx http-server build/web -p 3000

# Ou avec PHP
cd build/web
php -S 0.0.0.0:3000
```

#### Étape 3 : Connecter depuis Ondes Lab

Même procédure que la Méthode 1.

---

### Méthode 3 : QR Code (Plus rapide)

1. Générez un QR code contenant votre URL (ex: `http://192.168.1.42:3000`)
2. Dans Ondes Lab, appuyez sur **Scanner un QR Code**
3. Scannez le code → L'app se lance automatiquement

> 🔧 **Astuce** : Utilisez [qr-code-generator.com](https://www.qr-code-generator.com/) ou la commande `qrencode` :
> ```bash
> qrencode -o qr.png "http://192.168.1.42:3000"
> ```

---

## 📚 Référence API

### Initialisation

```dart
import 'package:ondes_sdk/ondes_sdk.dart';

// Attendre que le bridge soit prêt (obligatoire)
await Ondes.ensureReady();

// Vérifier si on est dans Ondes
if (Ondes.isReady) {
  // Utiliser les APIs Ondes
}
```

### 🎨 UI - Interface native

```dart
// Toast
await Ondes.ui.showToast(
  message: "Message affiché",
  type: ToastType.success, // info, success, error, warning
);

// Alerte
await Ondes.ui.showAlert(
  title: "Titre",
  message: "Contenu du message",
  buttonText: "OK",
);

// Confirmation
final confirmed = await Ondes.ui.showConfirm(
  title: "Supprimer ?",
  message: "Cette action est irréversible.",
  confirmText: "Oui, supprimer",
  cancelText: "Annuler",
);
if (confirmed) {
  // Supprimer...
}

// Menu contextuel (Bottom Sheet)
final choice = await Ondes.ui.showBottomSheet(
  title: "Actions",
  items: [
    BottomSheetItem(label: "Modifier", value: "edit", icon: "edit"),
    BottomSheetItem(label: "Partager", value: "share", icon: "share"),
    BottomSheetItem(label: "Supprimer", value: "delete", icon: "delete"),
  ],
);
print("Choix: $choice"); // "edit", "share", "delete" ou null

// Configurer la barre de navigation
await Ondes.ui.configureAppBar(
  title: "Mon titre",
  visible: true,
  backgroundColor: "#2196F3",
  foregroundColor: "#FFFFFF",
);
```

### 👤 User - Utilisateur

```dart
// Vérifier l'authentification
if (await Ondes.user.isAuthenticated()) {
  // Récupérer le profil
  final profile = await Ondes.user.getProfile();
  print("Utilisateur: ${profile?.username}");
  print("Email: ${profile?.email}");
  print("Avatar: ${profile?.avatar}");
  
  // Récupérer le token pour vos propres APIs
  final token = await Ondes.user.getAuthToken();
}
```

### 📱 Device - Matériel

```dart
// Retour haptique
await Ondes.device.hapticFeedback(HapticStyle.success);
// Styles: light, medium, heavy, success, warning, error

// Vibration
await Ondes.device.vibrate(200); // durée en ms

// Scanner un QR Code
try {
  final code = await Ondes.device.scanQRCode();
  print("Code scanné: $code");
} catch (e) {
  print("Scan annulé ou refusé");
}

// Position GPS
final pos = await Ondes.device.getGPSPosition();
print("Latitude: ${pos.latitude}");
print("Longitude: ${pos.longitude}");
print("Précision: ${pos.accuracy}m");

// Infos appareil
final info = await Ondes.device.getInfo();
print("Plateforme: ${info.platform}"); // iOS, android, etc.
print("Mode sombre: ${info.isDarkMode}");
print("Écran: ${info.screenWidth}x${info.screenHeight}");
```

### 💾 Storage - Stockage persistant

```dart
// Sauvegarder des données (JSON)
await Ondes.storage.set('preferences', {
  'theme': 'dark',
  'notifications': true,
  'language': 'fr',
});

// Récupérer des données
final prefs = await Ondes.storage.get<Map<String, dynamic>>('preferences');
print(prefs?['theme']); // 'dark'

// Lister les clés
final keys = await Ondes.storage.getKeys();

// Supprimer une clé
await Ondes.storage.remove('preferences');

// Tout effacer
await Ondes.storage.clear();
```

### 📦 App - Cycle de vie

```dart
// Infos sur la mini-app
final info = await Ondes.app.getInfo();
print("Nom: ${info.name}");
print("Version: ${info.version}");
print("Bundle ID: ${info.bundleId}");

// Récupérer le manifest
final manifest = await Ondes.app.getManifest();

// Fermer la mini-app
await Ondes.app.close();
```

### 👥 Friends - Amis

```dart
// Liste des amis
final friends = await Ondes.friends.list();
for (final friend in friends) {
  print("${friend.username} - ami depuis ${friend.friendsSince}");
}

// Envoyer une demande d'ami
await Ondes.friends.request(username: 'john_doe');

// Demandes en attente (reçues)
final pending = await Ondes.friends.getPendingRequests();
print("${pending.length} demandes en attente");

// Accepter/Refuser
await Ondes.friends.accept(requestId);
await Ondes.friends.reject(requestId);

// Bloquer/Débloquer
await Ondes.friends.block(username: 'spammer');
await Ondes.friends.unblock(userId);

// Rechercher des utilisateurs
final results = await Ondes.friends.search('john');
```

### 🌍 Social - Réseau social

```dart
// Récupérer le feed
final posts = await Ondes.social.getFeed(
  limit: 20,
  offset: 0,
  type: FeedType.main, // main, discover, video
);

// Publier un post
final post = await Ondes.social.publish(
  content: "Mon premier post depuis Flutter ! 🚀",
  visibility: PostVisibility.followers,
  tags: ['flutter', 'ondes'],
);

// Liker / Unliker
await Ondes.social.likePost(post.uuid);
await Ondes.social.unlikePost(post.uuid);

// Commenter
await Ondes.social.addComment(post.uuid, "Super post !");

// Récupérer les commentaires
final comments = await Ondes.social.getComments(post.uuid);

// Bookmarks (favoris)
await Ondes.social.bookmarkPost(post.uuid);
final saved = await Ondes.social.getBookmarks();

// Stories
final stories = await Ondes.social.getStories();
await Ondes.social.viewStory(storyUuid);
await Ondes.social.createStory(mediaPath, duration: 5);

// Follow / Unfollow
await Ondes.social.follow(username: 'influencer');
await Ondes.social.unfollow(userId: 123);

// Sélecteur de média natif
final media = await Ondes.social.pickMedia(
  multiple: true,
  allowVideo: true,
  maxFiles: 10,
);
for (final file in media) {
  print("${file.type}: ${file.path}");
}
```

### 🔌 Websocket - Connexions temps réel {#websocket}

```dart
// Connexion à un serveur WebSocket
final conn = await Ondes.websocket.connect(
  'ws://192.168.1.42:8080',
  options: WebsocketConnectOptions(
    reconnect: true,  // Auto-reconnexion
    timeout: 5000,    // Timeout 5 secondes
  ),
);
print('Connecté: ${conn.id}');

// Écouter les messages entrants
Ondes.websocket.onMessage(conn.id).listen((message) {
  print('Message reçu: $message');
  // Parser le message si nécessaire
  if (message is String && message.startsWith('<')) {
    handleRobotMessage(message);
  }
});

// Écouter les changements d'état
Ondes.websocket.onStatusChange(conn.id).listen((event) {
  print('État: ${event.status.name}');
  if (event.status == WebsocketStatus.error) {
    print('Erreur: ${event.error}');
  }
});

// Envoyer des messages
await Ondes.websocket.send(conn.id, '<100s50>');  // Texte
await Ondes.websocket.send(conn.id, {             // JSON
  'type': 'command',
  'action': 'move',
});

// Obtenir le statut d'une connexion
final status = await Ondes.websocket.getStatus(conn.id);
if (status != null) {
  print('URL: ${status.url}, État: ${status.status.name}');
}

// Lister toutes les connexions
final connections = await Ondes.websocket.list();
print('${connections.length} connexion(s) active(s)');

// Déconnecter
await Ondes.websocket.disconnect(conn.id);

// Déconnecter toutes les connexions
final count = await Ondes.websocket.disconnectAll();
print('$count connexion(s) fermée(s)');
```

---

### 📡 UDP - Découverte réseau {#udp}

Le module UDP permet la découverte de périphériques et la communication réseau via sockets UDP.

```dart
// Créer un socket UDP
final socket = await Ondes.udp.bind(
  options: UdpBindOptions(
    port: 12345,      // Port local (0 = aléatoire)
    broadcast: true,  // Autoriser le broadcast
  ),
);
print('Socket lié sur le port ${socket.port}');

// Écouter les messages entrants
Ondes.udp.onMessage(socket.id).listen((message) {
  print('Reçu de ${message.address}:${message.port}');
  print('Message: ${message.message}');
});

// Envoyer un message
await Ondes.udp.send(socket.id, 'DISCOVER_ROBOT', '192.168.1.100', 12345);

// Broadcast vers plusieurs adresses
final result = await Ondes.udp.broadcast(
  socket.id,
  'DISCOVER_ROBOT',
  [
    '192.168.1.255',
    '192.168.4.255',
    '192.168.4.1',
  ],
  12345,
);
print('Broadcast vers ${result.results.length} adresses');

// Infos sur le socket
final info = await Ondes.udp.getInfo(socket.id);
print('Messages reçus: ${info.messagesReceived}');

// Lister tous les sockets
final sockets = await Ondes.udp.list();
print('${sockets.length} socket(s) actif(s)');

// Fermer le socket
await Ondes.udp.close(socket.id);

// Fermer tous les sockets
final closedCount = await Ondes.udp.closeAll();
print('$closedCount socket(s) fermé(s)');
```

#### Exemple : Découverte de robots IoT

```dart
Future<List<Map<String, String>>> discoverRobots() async {
  final robots = <Map<String, String>>[];
  
  final socket = await Ondes.udp.bind(
    options: UdpBindOptions(port: 12345, broadcast: true),
  );
  
  final subscription = Ondes.udp.onMessage(socket.id).listen((msg) {
    final match = RegExp(r'<(.+)>').firstMatch(msg.message);
    if (match == null) return;
    
    final parts = match.group(1)!.split(',');
    if (parts[0] == 'DISCOVER_ROBOT') return; // Ignorer nos messages
    
    final robot = {
      'ip': parts[0],
      'name': parts.length > 1 ? parts[1] : parts[0],
    };
    
    if (!robots.any((r) => r['ip'] == robot['ip'])) {
      robots.add(robot);
    }
  });
  
  await Ondes.udp.broadcast(
    socket.id,
    'DISCOVER_ROBOT',
    ['192.168.1.255', '192.168.4.255', '192.168.4.1'],
    12345,
  );
  
  await Future.delayed(Duration(seconds: 4));
  await subscription.cancel();
  await Ondes.udp.close(socket.id);
  
  return robots;
}
```

---

## ⚠️ Gestion des erreurs

```dart
import 'package:ondes_sdk/ondes_sdk.dart';

try {
  final pos = await Ondes.device.getGPSPosition();
} on OndesException catch (e) {
  switch (e.code) {
    case 'PERMISSION_DENIED':
      print('Permission GPS refusée');
      break;
    case 'AUTH_REQUIRED':
      print('Connexion requise');
      break;
    case 'CANCELLED':
      print('Action annulée');
      break;
    case 'NOT_FOUND':
      print('Ressource introuvable');
      break;
    default:
      print('Erreur: ${e.message}');
  }
}
```

---

## 🎨 Bonnes pratiques

### 1. Toujours vérifier `Ondes.isReady`

```dart
Future<void> _doSomething() async {
  if (!Ondes.isReady) {
    // Fallback pour le développement hors Ondes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité non disponible')),
    );
    return;
  }
  
  // Code Ondes...
}
```

### 2. Configurer l'AppBar au démarrage

```dart
@override
void initState() {
  super.initState();
  _configureAppBar();
}

Future<void> _configureAppBar() async {
  if (!Ondes.isReady) return;
  
  await Ondes.ui.configureAppBar(
    title: 'Mon App',
    backgroundColor: '#673AB7',
    foregroundColor: '#FFFFFF',
  );
}
```

### 3. Gérer le cycle de vie

```dart
@override
void dispose() {
  // Nettoyage si nécessaire
  super.dispose();
}

Future<void> _closeApp() async {
  if (Ondes.isReady) {
    await Ondes.app.close();
  } else {
    Navigator.of(context).pop();
  }
}
```

---

## 🚀 Publication

Une fois votre app prête, vous pouvez la publier sur le Store Ondes via le **Studio** :

1. Compilez en mode release : `flutter build web --release`
2. Créez un fichier `manifest.json` à la racine de `build/web/`
3. Zippez le contenu du dossier `build/web/`
4. Uploadez via Ondes Studio (onglet Lab → Ouvrir le Studio)

Voir [Guide de publication](../mini_app_guide.md#publication) pour plus de détails.

---

## 📝 Exemple complet

Un exemple fonctionnel est disponible dans le dépôt :

```bash
cd packages/ondes_sdk/example
flutter pub get
flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0
```

Puis connectez-vous depuis Ondes Lab avec l'URL de votre machine.
