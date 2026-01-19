# 👥 Ondes.Friends - Gestion des Amis

Ce module permet de gérer le graphe social de l'utilisateur : liste d'amis, demandes, blocage, etc.

> 🔒 **Prérequis** : Toutes ces fonctions nécessitent que l'utilisateur soit connecté (`Ondes.User.isAuthenticated()`).

---

## Liste et Recherche

### `list()`
Récupère la liste des amis confirmés.

**Retourne** : `Promise<Array<Friend>>`

Structure `Friend` :
- `id` (Number): ID utilisateur.
- `username` (String): Nom.
- `avatar` (String): URL image.
- `friendsSince` (String): Date de début d'amitié.

```javascript
const myFriends = await Ondes.Friends.list();
console.log(`Vous avez ${myFriends.length} amis.`);
```

### `search(query)`
Recherche des utilisateurs par nom.

**Retourne** : `Promise<Array<UserSearchResult>>` avec statut d'amitié (`pending`, `accepted`, `none`, `blocked`).

```javascript
const results = await Ondes.Friends.search("Alice");
```

---

## Gestion des demandes

### `request(options)`
Envoie une demande d'amitié à un utilisateur.

| Option | Description |
|--------|-------------|
| `username` | Nom d'utilisateur cible. |
| `userId` | ID de l'utilisateur cible (alternative). |

```javascript
await Ondes.Friends.request({ username: "BobDylan" });
```

### `getPendingRequests()`
Liste les demandes reçues qui sont en attente de validation.

**Retourne** : `Promise<Array<Request>>`

### `accept(friendshipId)`
Accepte une demande d'amitié reçue.

```javascript
await Ondes.Friends.accept(12345);
```

### `reject(friendshipId)`
Refuse une demande d'amitié.

```javascript
await Ondes.Friends.reject(12345);
```

---

## Gestion des relations

### `remove(friendshipId)`
Supprime un ami de votre liste.

```javascript
await Ondes.Friends.remove(relationId);
```

### `block(options)`
Bloque un utilisateur pour qu'il ne puisse plus interagir avec vous.

```javascript
await Ondes.Friends.block({ username: "TrollUser" });
```

### `unblock(userId)`
Débloque un utilisateur précédemment bloqué.

```javascript
await Ondes.Friends.unblock(99);
```

### `getBlocked()`
Liste tous les utilisateurs bloqués.
