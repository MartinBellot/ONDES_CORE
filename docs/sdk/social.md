# 🌍 Ondes.Social - Réseau Social

Le module le plus riche du SDK. Il gère le fil d'actualité, les posts, les likes, les commentaires, et les stories type Instagram/TikTok.

> 📹 **Smart Media** : Les vidéos uploadées sont automatiquement converties en format HLS pour un streaming adaptatif. Les images sont optimisées.

---

## Fil d'actualité (Feed)

### `getFeed(options)`
Récupère une liste de posts pour l'utilisateur.

| Paramètre | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | Number | 20 | Nombre de posts à récupérer. |
| `algorithm` | String | `'trending'` | `'chronological'` ou `'trending'`. |
| `media_type` | String | `null` | Filtrer par `'image'` ou `'video'`. |

```javascript
// Feed standard
const feed = await Ondes.Social.getFeed();

// Feed "TikTok style" (vidéos uniquement)
const videos = await Ondes.Social.getFeed({
    media_type: 'video',
    limit: 10
});
```

---

## Publications (Posts)

### `publish(options)`
Crée un nouveau post.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `content` | String | Légende du post. |
| `media` | Array<String> | Chemins locaux des fichiers à uploader. |
| `visibility` | String | `'public'`, `'followers'`, `'private'`. |

```javascript
await Ondes.Social.publish({
    content: "Coucher de soleil magnifique ! 🌅",
    media: ["/path/to/sunset.jpg"],
    visibility: "public"
});
```

### `deletePost(postUuid)`
Supprime un post existant.

### `getPost(postUuid)`
Récupère les détails d'un post (nombre de likes, état, etc.).

---

## Interactions

### `like(postUuid)` / `unlike(postUuid)`
Ajoute ou retire un "J'aime" sur un contenu.

### `comment(postUuid, content, parentUuid)`
Ajoute un commentaire à un post. Si `parentUuid` est fourni, c'est une réponse à un autre commentaire.

### `bookmark(postUuid)` / `removeBookmark(postUuid)`
Sauvegarde un post dans les favoris privés de l'utilisateur.

---

## Stories (éphémères 24h)

### `createStory(options)`
Publie une photo ou vidéo visible 24h.

```javascript
await Ondes.Social.createStory({
    media: '/path/to/video.mp4',
    media_type: 'video'
});
```

### `getStories()`
Récupère les stories des amis, groupées par utilisateur.

---

## Relations (Follow)

Contrairement à `Ondes.Friends` (amitié bidirectionnelle), `Ondes.Social` gère le système de Followers/Following (unidirectionnel).

- **`follow(userUuid)`** : Suivre un créateur.
- **`unfollow(userUuid)`** : Arrêter de suivre.
- **`getFollowers(userUuid)`** : Voir qui suit un utilisateur.
- **`getFollowing(userUuid)`** : Voir qui un utilisateur suit.

---

## Médias

### `pickMedia(options)`
Ouvre la galerie native pour laisser l'utilisateur choisir des photos ou vidéos.

| Option | Description |
|--------|-------------|
| `multiple` | Autoriser plusieurs fichiers. |
| `maxFiles` | Nombre max de fichiers. |
| `allowVideo` | Autoriser les vidéos. |

```javascript
const files = await Ondes.Social.pickMedia({
    multiple: true,
    maxFiles: 5
});
// files = [{ path: "...", mime: "image/jpeg" }, ...]
```
