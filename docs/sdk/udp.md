# Ondes.UDP

Le module **UDP** permet de gérer des sockets UDP pour la découverte de périphériques et la communication réseau dans vos mini-apps.

## Vue d'ensemble

UDP (User Datagram Protocol) est un protocole de communication idéal pour :

- **Découverte de périphériques** sur un réseau local (broadcast)
- **Communication légère** sans établissement de connexion
- **Messages à faible latence** où la fiabilité n'est pas critique

## API Reference

### `bind(options?)`

Crée et lie un socket UDP à un port local.

```javascript
const socket = await Ondes.UDP.bind({
  port: 12345,        // Port local (0 = port aléatoire)
  broadcast: true,    // Autoriser le broadcast (défaut: true)
  reuseAddress: true  // Permettre la réutilisation de l'adresse (défaut: true)
});

console.log(`Socket créé: ${socket.id} sur le port ${socket.port}`);
```

**Retourne:**
```javascript
{
  id: "udp_1705761234567_1",  // ID unique du socket
  port: 12345,                 // Port effectif
  broadcast: true,             // Broadcast activé
  status: "bound"              // Statut du socket
}
```

---

### `send(socketId, message, address, port)`

Envoie un message UDP à une adresse et un port spécifiques.

```javascript
const result = await Ondes.UDP.send(
  socket.id,
  "DISCOVER_ROBOT",
  "192.168.1.100",
  12345
);

if (result.success) {
  console.log(`Envoyé ${result.bytesSent} octets`);
}
```

**Retourne:**
```javascript
{
  success: true,
  bytesSent: 14,
  address: "192.168.1.100",
  port: 12345
}
```

---

### `broadcast(socketId, message, addresses, port?)`

Envoie un message UDP à plusieurs adresses simultanément.

```javascript
const result = await Ondes.UDP.broadcast(
  socket.id,
  "DISCOVER_ROBOT",
  [
    "192.168.1.255",    // Broadcast réseau local
    "192.168.4.255",    // Point d'accès WiFi
    "192.168.4.1",      // Gateway du mode AP
    "172.20.10.1"       // Partage de connexion
  ],
  12345
);

console.log(`Broadcast vers ${result.results.length} adresses`);
result.results.forEach(r => {
  console.log(`${r.address}: ${r.success ? 'OK' : r.error}`);
});
```

**Retourne:**
```javascript
{
  socketId: "udp_123...",
  messageLength: 14,
  port: 12345,
  results: [
    { address: "192.168.1.255", success: true, bytesSent: 14 },
    { address: "192.168.4.255", success: true, bytesSent: 14 },
    { address: "192.168.4.1", success: false, error: "Network unreachable" }
  ]
}
```

---

### `close(socketId)`

Ferme un socket UDP.

```javascript
await Ondes.UDP.close(socket.id);
console.log("Socket fermé");
```

---

### `getInfo(socketId)`

Récupère les informations d'un socket.

```javascript
const info = await Ondes.UDP.getInfo(socket.id);
console.log(`Port: ${info.port}, Messages reçus: ${info.messagesReceived}`);
```

**Retourne:**
```javascript
{
  id: "udp_123...",
  port: 12345,
  broadcast: true,
  createdAt: 1705761234567,
  messagesReceived: 5
}
```

---

### `list()`

Liste tous les sockets UDP actifs.

```javascript
const sockets = await Ondes.UDP.list();
sockets.forEach(s => {
  console.log(`Socket ${s.id}: port ${s.port}`);
});
```

---

### `closeAll()`

Ferme tous les sockets UDP.

```javascript
const result = await Ondes.UDP.closeAll();
console.log(`${result.closedCount} sockets fermés`);
```

---

### `onMessage(socketId, callback)`

Enregistre un callback pour les messages entrants.

```javascript
const unsubscribe = Ondes.UDP.onMessage(socket.id, (data) => {
  console.log(`Message de ${data.address}:${data.port}`);
  console.log(`Contenu: ${data.message}`);
  
  // data contient:
  // - socketId: ID du socket
  // - message: Contenu du message (string)
  // - data: Données brutes (array d'octets)
  // - address: Adresse IP de l'expéditeur
  // - port: Port de l'expéditeur
  // - timestamp: Horodatage de réception
});

// Pour arrêter l'écoute:
unsubscribe();
```

---

### `onClose(socketId, callback)`

Enregistre un callback pour la fermeture du socket.

```javascript
const unsubscribe = Ondes.UDP.onClose(socket.id, (data) => {
  console.log(`Socket ${data.socketId} fermé`);
});
```

---

## Exemple complet : Découverte de robots

```javascript
async function discoverRobots() {
  const robots = [];
  
  // 1. Créer un socket UDP
  const socket = await Ondes.UDP.bind({ port: 12345, broadcast: true });
  console.log(`Socket lié sur le port ${socket.port}`);
  
  // 2. Écouter les réponses
  Ondes.UDP.onMessage(socket.id, (data) => {
    // Parser le message: <IP,Nom,ID,Couleur>
    const match = data.message.match(/<(.+)>/);
    if (!match) return;
    
    const content = match[1];
    if (content.startsWith("DISCOVER_ROBOT")) return; // Ignorer nos propres messages
    
    const parts = content.split(',');
    const robot = {
      ip: parts[0],
      name: parts[1] || parts[0],
      id: parts[2] || '',
      color: parts[3] || ''
    };
    
    // Éviter les doublons
    if (!robots.find(r => r.ip === robot.ip)) {
      robots.push(robot);
      console.log(`Robot trouvé: ${robot.name} (${robot.ip})`);
    }
  });
  
  // 3. Envoyer le broadcast de découverte
  const addresses = [
    '192.168.1.255',    // Réseau local
    '192.168.4.255',    // Mode AP
    '192.168.137.255',  // Partage Windows
    '192.168.3.255',    // Autre réseau
    '192.168.4.1',      // Gateway AP
    '172.20.10.1',      // Partage iPhone
    '172.20.10.2',
    '172.20.10.3'
  ];
  
  await Ondes.UDP.broadcast(socket.id, 'DISCOVER_ROBOT', addresses, 12345);
  
  // 4. Attendre les réponses
  await new Promise(resolve => setTimeout(resolve, 4000));
  
  // 5. Fermer le socket
  await Ondes.UDP.close(socket.id);
  
  return robots;
}

// Utilisation
discoverRobots().then(robots => {
  if (robots.length === 0) {
    console.log("Aucun robot trouvé");
  } else {
    console.log(`${robots.length} robot(s) trouvé(s)`);
    robots.forEach(r => console.log(`- ${r.name}: ${r.ip}`));
  }
});
```

## Exemple Flutter (SDK)

```dart
import 'package:ondes_sdk/ondes_sdk.dart';

Future<List<Map<String, String>>> discoverRobots() async {
  final robots = <Map<String, String>>[];
  
  // Bind le socket
  final socket = await Ondes.udp.bind(
    options: UdpBindOptions(port: 12345, broadcast: true),
  );
  
  // Écouter les messages
  final subscription = Ondes.udp.onMessage(socket.id).listen((message) {
    final match = RegExp(r'<(.+)>').firstMatch(message.message);
    if (match == null) return;
    
    final content = match.group(1)!;
    if (content.startsWith('DISCOVER_ROBOT')) return;
    
    final parts = content.split(',');
    final robot = {
      'ip': parts[0],
      'name': parts.length > 1 ? parts[1] : parts[0],
      'id': parts.length > 2 ? parts[2] : '',
      'color': parts.length > 3 ? parts[3] : '',
    };
    
    if (!robots.any((r) => r['ip'] == robot['ip'])) {
      robots.add(robot);
      print('Robot trouvé: ${robot['name']} (${robot['ip']})');
    }
  });
  
  // Broadcast
  await Ondes.udp.broadcast(
    socket.id,
    'DISCOVER_ROBOT',
    [
      '192.168.1.255',
      '192.168.4.255',
      '192.168.4.1',
      '172.20.10.1',
    ],
    12345,
  );
  
  // Attendre les réponses
  await Future.delayed(Duration(seconds: 4));
  
  // Cleanup
  await subscription.cancel();
  await Ondes.udp.close(socket.id);
  
  return robots;
}
```

## Notes importantes

### Sécurité réseau

- Les sockets UDP sont créés par le host natif (Ondes Core)
- Votre mini-app n'a pas d'accès direct au réseau
- Le host peut limiter les ports/adresses autorisés

### Limitations Web

- UDP n'est **pas disponible** directement dans les navigateurs
- Ce module fonctionne uniquement dans Ondes Core
- Sur un site web classique, utilisez WebSocket ou HTTP

### Bonnes pratiques

1. **Toujours fermer** les sockets après utilisation
2. **Limiter le temps** de découverte (timeout)
3. **Gérer les erreurs** de réseau (Network unreachable)
4. **Éviter les broadcasts** excessifs

## Voir aussi

- [Ondes.Websocket](websocket.md) - Pour les connexions persistantes
- [Ondes.Device](device.md) - Pour les infos réseau
