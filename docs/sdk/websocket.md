# 🔌 Ondes.Websocket

Le module `Ondes.Websocket` permet de créer et gérer des connexions WebSocket bidirectionnelles depuis vos mini-apps. Idéal pour la communication en temps réel avec des serveurs, robots, ou tout autre dispositif.

---

## 📋 Fonctionnalités

- ✅ Connexions multiples simultanées
- ✅ Auto-reconnexion optionnelle
- ✅ Support texte et JSON
- ✅ Événements en temps réel (messages, status)
- ✅ Timeout configurable

---

## 🚀 Connexion

### `Ondes.Websocket.connect(url, options)`

Établit une connexion WebSocket.

**Paramètres :**

| Paramètre | Type | Description |
|-----------|------|-------------|
| `url` | `string` | URL WebSocket (`ws://` ou `wss://`) |
| `options.reconnect` | `boolean` | Auto-reconnexion (défaut: `false`) |
| `options.timeout` | `number` | Timeout en ms (défaut: `10000`) |

**Retour :** `Promise<Connection>`

```javascript
// Connexion simple
const conn = await Ondes.Websocket.connect('ws://192.168.1.42:8080');

// Avec options
const conn = await Ondes.Websocket.connect('ws://192.168.1.42:8080', {
    reconnect: true,  // Reconnexion automatique
    timeout: 5000     // Timeout 5 secondes
});

console.log('Connecté!', conn.id);
// { id: 'ws_1234567890_1', url: 'ws://...', status: 'connected', connectedAt: 1234567890 }
```

---

## 📤 Envoi de messages

### `Ondes.Websocket.send(connectionId, data)`

Envoie un message à travers une connexion WebSocket.

**Paramètres :**

| Paramètre | Type | Description |
|-----------|------|-------------|
| `connectionId` | `string` | ID de la connexion |
| `data` | `string \| object` | Données à envoyer |

**Retour :** `Promise<{success, id}>`

```javascript
// Envoyer une chaîne de caractères
await Ondes.Websocket.send(conn.id, '<100s50>');

// Envoyer un objet JSON (automatiquement stringifié)
await Ondes.Websocket.send(conn.id, {
    type: 'command',
    action: 'move',
    speed: 50
});
```

---

## 📥 Réception de messages

### `Ondes.Websocket.onMessage(connectionId, callback)`

Enregistre un callback pour recevoir les messages entrants.

**Paramètres :**

| Paramètre | Type | Description |
|-----------|------|-------------|
| `connectionId` | `string` | ID de la connexion |
| `callback` | `function` | Fonction appelée à chaque message |

**Retour :** `function` - Fonction pour se désabonner

```javascript
// Écouter les messages
const unsubscribe = Ondes.Websocket.onMessage(conn.id, (message) => {
    console.log('Message reçu:', message);
    
    // Parser si c'est du JSON
    if (typeof message === 'string' && message.startsWith('{')) {
        const data = JSON.parse(message);
        handleData(data);
    }
});

// Se désabonner plus tard
unsubscribe();
```

---

## 📊 État de la connexion

### `Ondes.Websocket.onStatusChange(connectionId, callback)`

Enregistre un callback pour les changements d'état.

**États possibles :**

| État | Description |
|------|-------------|
| `connecting` | Connexion en cours |
| `connected` | Connexion active |
| `disconnected` | Connexion fermée |
| `reconnecting` | Tentative de reconnexion |
| `error` | Erreur de connexion |

```javascript
Ondes.Websocket.onStatusChange(conn.id, (status, error) => {
    console.log('Nouvel état:', status);
    
    if (status === 'disconnected') {
        Ondes.UI.showToast({ message: 'Connexion perdue', type: 'warning' });
    }
    
    if (status === 'error') {
        console.error('Erreur:', error);
    }
    
    if (status === 'connected') {
        Ondes.UI.showToast({ message: 'Connecté!', type: 'success' });
    }
});
```

### `Ondes.Websocket.getStatus(connectionId)`

Récupère l'état actuel d'une connexion.

**Retour :** `Promise<Status>`

```javascript
const status = await Ondes.Websocket.getStatus(conn.id);
console.log(status);
// { id: 'ws_...', url: 'ws://...', status: 'connected', exists: true, connectedAt: ..., reconnect: true }
```

---

## 🔌 Déconnexion

### `Ondes.Websocket.disconnect(connectionId)`

Ferme une connexion WebSocket.

```javascript
await Ondes.Websocket.disconnect(conn.id);
console.log('Déconnecté');
```

### `Ondes.Websocket.disconnectAll()`

Ferme toutes les connexions WebSocket actives.

```javascript
const result = await Ondes.Websocket.disconnectAll();
console.log(`${result.disconnected} connexion(s) fermée(s)`);
```

---

## 📋 Lister les connexions

### `Ondes.Websocket.list()`

Liste toutes les connexions WebSocket actives.

**Retour :** `Promise<Array<Connection>>`

```javascript
const connections = await Ondes.Websocket.list();
connections.forEach(conn => {
    console.log(`${conn.id}: ${conn.url} (${conn.status})`);
});
```

---

## 💡 Exemple complet : Contrôle d'un robot

```javascript
document.addEventListener('OndesReady', async () => {
    let robotConnection = null;
    
    // === CONNEXION ===
    async function connectToRobot(ip) {
        try {
            robotConnection = await Ondes.Websocket.connect(`ws://${ip}:8080`, {
                reconnect: true,
                timeout: 5000
            });
            
            // Écouter les messages du robot
            Ondes.Websocket.onMessage(robotConnection.id, handleRobotMessage);
            
            // Écouter les changements d'état
            Ondes.Websocket.onStatusChange(robotConnection.id, handleStatusChange);
            
            Ondes.UI.showToast({ message: 'Robot connecté!', type: 'success' });
            
        } catch (error) {
            Ondes.UI.showToast({ message: 'Échec de connexion', type: 'error' });
            console.error(error);
        }
    }
    
    // === MESSAGES ENTRANTS ===
    function handleRobotMessage(message) {
        console.log('Robot dit:', message);
        
        // Parser le message du robot (format: <code/data>)
        if (message.startsWith('<') && message.endsWith('>')) {
            const content = message.slice(1, -1);
            
            // Exemple: Niveau de batterie
            if (content.startsWith('40s')) {
                const battery = parseInt(content.slice(3));
                updateBatteryUI(battery);
            }
            
            // Exemple: Capteurs
            if (content.startsWith('20f')) {
                const sensors = parseSensors(content);
                updateSensorsUI(sensors);
            }
        }
    }
    
    // === ÉTAT CONNEXION ===
    function handleStatusChange(status, error) {
        const statusElement = document.getElementById('connection-status');
        statusElement.textContent = status;
        statusElement.className = `status-${status}`;
        
        if (status === 'error') {
            console.error('Erreur WebSocket:', error);
        }
    }
    
    // === ENVOI DE COMMANDES ===
    async function sendCommand(command) {
        if (!robotConnection) {
            Ondes.UI.showToast({ message: 'Non connecté', type: 'warning' });
            return;
        }
        
        try {
            await Ondes.Websocket.send(robotConnection.id, command);
            console.log('Commande envoyée:', command);
        } catch (error) {
            console.error('Erreur envoi:', error);
        }
    }
    
    // === CONTRÔLES ===
    document.getElementById('btn-forward').onclick = () => sendCommand('<100s50>');
    document.getElementById('btn-backward').onclick = () => sendCommand('<100s-50>');
    document.getElementById('btn-left').onclick = () => sendCommand('<101s-30>');
    document.getElementById('btn-right').onclick = () => sendCommand('<101s30>');
    document.getElementById('btn-stop').onclick = () => sendCommand('<100s0>');
    
    // === DÉMARRAGE ===
    const robotIP = await Ondes.Storage.get('robot_ip') || '192.168.1.42';
    await connectToRobot(robotIP);
});
```

---

## ⚠️ Gestion des erreurs

```javascript
try {
    const conn = await Ondes.Websocket.connect('ws://invalid-host:8080', {
        timeout: 3000
    });
} catch (error) {
    console.error('Connexion échouée:', error.message);
    
    // Codes d'erreur possibles
    if (error.message.includes('timeout')) {
        Ondes.UI.showToast({ message: 'Timeout de connexion', type: 'error' });
    } else if (error.message.includes('refused')) {
        Ondes.UI.showToast({ message: 'Connexion refusée', type: 'error' });
    }
}
```

---

## 🔄 Bonnes pratiques

1. **Toujours utiliser `try/catch`** pour les opérations de connexion
2. **Activer `reconnect: true`** pour les connexions critiques
3. **Nettoyer les callbacks** avec la fonction de désabonnement
4. **Fermer les connexions** quand elles ne sont plus nécessaires
5. **Gérer les états** de connexion dans l'UI

```javascript
// Nettoyage à la fermeture de l'app
window.addEventListener('beforeunload', async () => {
    await Ondes.Websocket.disconnectAll();
});
```

---

## 📱 Version Flutter (SDK Dart)

Pour utiliser WebSocket avec le SDK Flutter, voir la [documentation Flutter](flutter.md#websocket).

```dart
// Exemple Flutter
final conn = await Ondes.websocket.connect(
  'ws://192.168.1.42:8080',
  options: WebsocketConnectOptions(reconnect: true),
);

Ondes.websocket.onMessage(conn.id).listen((message) {
  print('Message: $message');
});

await Ondes.websocket.send(conn.id, '<100s50>');
```
