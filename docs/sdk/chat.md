# Ondes.Chat

Le module `Ondes.Chat` permet de créer des applications de messagerie avec **chiffrement de bout en bout (E2EE)** automatique. Tous les messages sont chiffrés localement avant d'être envoyés et déchiffrés à la réception, sans que les développeurs n'aient besoin de gérer la cryptographie.

!!! success "Chiffrement 100% Automatique"
    **Aucune configuration requise!** Les clés E2EE sont générées automatiquement dès que l'utilisateur se connecte à Ondes. Vous envoyez du texte clair, il est chiffré. Vous recevez des messages déjà déchiffrés.

## Sécurité

| Composant | Algorithme |
|-----------|------------|
| Échange de clés | X25519 (Curve25519) |
| Chiffrement | AES-256-GCM |
| Authentification | HMAC intégré (GCM) |

Les clés privées ne quittent **jamais** l'appareil de l'utilisateur. Le serveur ne voit que les messages chiffrés.

!!! info "Clés générées au login"
    Chaque utilisateur Ondes possède automatiquement une paire de clés E2EE créée lors de sa première connexion. Cela garantit que le chiffrement X25519 fonctionne toujours entre deux utilisateurs.

---

## Initialisation

### `Ondes.Chat.init()`

Connecte au service de chat temps réel (WebSocket).

**Retour:** `Promise<{success: boolean, userId: number}>`

```javascript
// Connecte au WebSocket pour recevoir les messages en temps réel
await Ondes.Chat.init();
```

!!! note "E2EE automatique"
    Les clés de chiffrement sont déjà configurées au login. Cette méthode établit simplement la connexion WebSocket pour les messages en temps réel.

### `Ondes.Chat.disconnect()`

Déconnecte du service de chat.

```javascript
await Ondes.Chat.disconnect();
```

### `Ondes.Chat.isReady()`

Vérifie si le chat est initialisé et connecté.

**Retour:** `boolean`

```javascript
if (Ondes.Chat.isReady()) {
    // Chat prêt
}
```

---

## Conversations

### `Ondes.Chat.getConversations()`

Récupère toutes les conversations de l'utilisateur.

**Retour:** `Promise<Array<Conversation>>`

```javascript
const conversations = await Ondes.Chat.getConversations();

for (const conv of conversations) {
    console.log(conv.name);
    console.log(conv.lastMessage?.content); // Déjà déchiffré!
}
```

**Structure Conversation:**
```typescript
interface Conversation {
    id: string;           // UUID unique
    name: string;         // Nom de la conversation
    type: 'private' | 'group';
    avatar?: string;
    members: Array<{
        id: number;
        username: string;
        avatar?: string;
    }>;
    lastMessage?: {
        content: string;  // Contenu déchiffré
        sender: string;
        createdAt: string;
    };
    unreadCount: number;
    updatedAt: string;
}
```

### `Ondes.Chat.getConversation(conversationId)`

Récupère une conversation spécifique.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `conversationId` | `string` | UUID de la conversation |

**Retour:** `Promise<Conversation>`

```javascript
const conv = await Ondes.Chat.getConversation('abc-123-def');
```

### `Ondes.Chat.startChat(user)`

Démarre une conversation privée avec un utilisateur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `user` | `string` ou `number` | Nom d'utilisateur ou ID |

**Retour:** `Promise<Conversation>`

```javascript
// Par nom d'utilisateur
const conv = await Ondes.Chat.startChat('alice');

// Par ID
const conv = await Ondes.Chat.startChat(42);
```

### `Ondes.Chat.createGroup(name, members)`

Crée un groupe de discussion.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `name` | `string` | Nom du groupe |
| `members` | `Array<string\|number>` | Membres (usernames ou IDs) |

**Retour:** `Promise<Conversation>`

```javascript
const group = await Ondes.Chat.createGroup('Projet Alpha', [
    'alice',
    'bob',
    42  // ID utilisateur
]);
```

---

## Messages

### `Ondes.Chat.send(conversationId, message, options?)`

Envoie un message dans une conversation.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `conversationId` | `string` | UUID de la conversation |
| `message` | `string` | Contenu du message (texte clair) |
| `options` | `object` | Options (optionnel) |

**Options:**
- `replyTo`: UUID du message auquel répondre
- `type`: Type de message (`'text'`, `'image'`, `'file'`)

**Retour:** `Promise<{success: boolean}>`

```javascript
// Message simple
await Ondes.Chat.send(conv.id, 'Salut!');

// Réponse à un message
await Ondes.Chat.send(conv.id, 'D\'accord!', {
    replyTo: 'message-uuid-123'
});
```

### `Ondes.Chat.getMessages(conversationId, options?)`

Récupère les messages d'une conversation.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `conversationId` | `string` | UUID de la conversation |
| `options.limit` | `number` | Nombre max (défaut: 50) |
| `options.before` | `string` | UUID pour pagination |

**Retour:** `Promise<Array<Message>>`

```javascript
// 50 derniers messages
const messages = await Ondes.Chat.getMessages(conv.id);

// Pagination
const olderMessages = await Ondes.Chat.getMessages(conv.id, {
    limit: 20,
    before: messages[0].id
});
```

**Structure Message:**
```typescript
interface Message {
    id: string;           // UUID unique
    conversationId: string;
    senderId: number;
    sender: string;       // Username
    content: string;      // Contenu DÉCHIFFRÉ
    type: string;         // 'text', 'image', etc.
    createdAt: string;
    editedAt?: string;
    isDeleted: boolean;
    replyTo?: string;
}
```

### `Ondes.Chat.editMessage(messageId, newContent, conversationId?)`

Modifie un message existant.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `messageId` | `string` | UUID du message à modifier |
| `newContent` | `string` | Nouveau contenu (texte clair) |
| `conversationId` | `string` | UUID de la conversation (optionnel, pour le chiffrement) |

```javascript
await Ondes.Chat.editMessage('msg-uuid', 'Nouveau contenu', 'conv-uuid');
```

!!! note "Chiffrement"
    Si `conversationId` est fourni, le nouveau contenu sera automatiquement chiffré.

### `Ondes.Chat.deleteMessage(messageId)`

Supprime un message.

```javascript
await Ondes.Chat.deleteMessage('msg-uuid');
```

### `Ondes.Chat.markAsRead(messageIds)`

Marque des messages comme lus.

```javascript
// Un message
await Ondes.Chat.markAsRead('msg-uuid');

// Plusieurs messages
await Ondes.Chat.markAsRead(['msg-1', 'msg-2', 'msg-3']);
```

---

## Indicateurs

### `Ondes.Chat.setTyping(conversationId, isTyping)`

Envoie un indicateur de frappe.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `conversationId` | `string` | UUID de la conversation |
| `isTyping` | `boolean` | `true` si en train d'écrire |

```javascript
// L'utilisateur commence à taper
Ondes.Chat.setTyping(conv.id, true);

// L'utilisateur a fini
Ondes.Chat.setTyping(conv.id, false);
```

---

## Événements

### `Ondes.Chat.onMessage(callback)`

Écoute les nouveaux messages.

**Callback:** `(message: Message) => void`

**Retour:** Fonction pour se désabonner

```javascript
const unsubscribe = Ondes.Chat.onMessage((msg) => {
    console.log(`${msg.sender}: ${msg.content}`);
    // Le message est déjà déchiffré!
});

// Plus tard, pour arrêter d'écouter:
unsubscribe();
```

### `Ondes.Chat.onTyping(callback)`

Écoute les indicateurs de frappe.

**Callback:** `({conversationId, userId, username, isTyping}) => void`

```javascript
Ondes.Chat.onTyping((data) => {
    if (data.isTyping) {
        showTypingIndicator(data.username);
    } else {
        hideTypingIndicator();
    }
});
```

### `Ondes.Chat.onReceipt(callback)`

Écoute les accusés de lecture.

**Callback:** `({messageId, userId, readAt}) => void`

```javascript
Ondes.Chat.onReceipt((data) => {
    markMessageAsRead(data.messageId);
});
```

### `Ondes.Chat.onConnectionChange(callback)`

Écoute les changements de connexion.

**Callback:** `(status: 'connected'|'disconnected'|'error') => void`

```javascript
Ondes.Chat.onConnectionChange((status) => {
    if (status === 'disconnected') {
        showReconnecting();
    }
});
```

---

## Exemple Complet

```javascript
// Initialisation
document.addEventListener('OndesReady', async () => {
    // 1. Initialiser le chat (E2EE automatique)
    await Ondes.Chat.init();
    
    // 2. Charger les conversations
    const conversations = await Ondes.Chat.getConversations();
    displayConversations(conversations);
    
    // 3. Écouter les nouveaux messages
    Ondes.Chat.onMessage((msg) => {
        // msg.content est déjà déchiffré!
        appendMessage(msg);
    });
    
    // 4. Écouter les indicateurs de frappe
    Ondes.Chat.onTyping((data) => {
        if (data.isTyping) {
            showTyping(data.username);
        }
    });
});

// Démarrer une nouvelle conversation
async function startNewChat(username) {
    const conv = await Ondes.Chat.startChat(username);
    selectConversation(conv);
}

// Envoyer un message
async function sendMessage(text) {
    await Ondes.Chat.send(currentConv.id, text);
    // C'est tout! Le chiffrement est automatique
}

// Charger l'historique
async function loadHistory(convId) {
    const messages = await Ondes.Chat.getMessages(convId);
    // Tous les messages sont déjà déchiffrés
    messages.forEach(displayMessage);
}
```

---

## Notes Techniques

### Stockage des Clés

Les clés sont stockées de manière persistante via `SharedPreferences`:

- **Clé privée X25519:** Générée automatiquement au premier login, réutilisée ensuite
- **Clés de conversation:** Dérivées via X25519 à partir des clés publiques des membres

### Échange de Clés X25519

Le système utilise exclusivement **X25519** pour l'échange de clés:

1. **Au login:** Une paire de clés X25519 est générée et la clé publique est enregistrée sur le serveur
2. **À la création d'une conversation:** Le secret partagé est calculé avec la clé publique de l'autre membre
3. **Résultat identique:** Les deux membres dérivent exactement la même clé symétrique (propriété de X25519)

!!! success "E2EE Garanti"
    Comme tous les utilisateurs Ondes ont une clé publique dès leur premier login, le chiffrement X25519 fonctionne toujours. Aucun fallback nécessaire!

### Performance

- Les clés de conversation sont mises en cache en mémoire
- Le déchiffrement est fait de manière asynchrone
- Les messages sont déchiffrés en batch lors du chargement

### Limitations

- Taille max message: 64 KB (avant chiffrement)
- Maximum 256 membres par groupe
- Historique: 10 000 messages par conversation

---

## Voir Aussi

- [WebSocket](websocket.md) - Communication WebSocket bas niveau
- [User](user.md) - Gestion de l'authentification
- [Friends](friends.md) - Gestion des amis
