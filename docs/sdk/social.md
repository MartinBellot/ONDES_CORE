# 🌍 Ondes.Social - Réseau Social

Le module le plus riche du SDK. Il gère le fil d'actualité, les posts, les likes, les commentaires, les stories et le système de follow/followers type Instagram/TikTok.

> 📹 **Smart Media** : Les vidéos uploadées sont automatiquement converties en format HLS pour un streaming adaptatif. Les images sont optimisées (max 1920×1920, JPEG 85%).

---

## Profil

### `getProfile(options?)`
Récupère le profil d'un utilisateur. Sans paramètre, retourne le profil de l'utilisateur connecté.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `userId` | Number | ID de l'utilisateur (optionnel). |
| `username` | String | Nom d'utilisateur (optionnel). |

```javascript
// Mon profil
const me = await Ondes.Social.getProfile();

// Profil d'un autre utilisateur
const user = await Ondes.Social.getProfile({ userId: 42 });
const user2 = await Ondes.Social.getProfile({ username: 'alice' });
```

**Retour :** Objet avec `id`, `username`, `avatar`, `bio`, `followers_count`, `following_count`, `posts_count`, `is_following`.

### `searchUsers(query)`
Recherche des utilisateurs par nom ou pseudo.

```javascript
const users = await Ondes.Social.searchUsers('alice');
// [{ id, username, avatar, bio, followers_count, is_following }, ...]
```

---

## Fil d'actualité (Feed)

### `getFeed(options?)`
Récupère une liste de posts selon l'algorithme sélectionné.

| Paramètre | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | String | `'main'` | Type de feed : `'main'`, `'discover'`, `'friends'`, `'video'`. |
| `limit` | Number | `50` | Nombre de posts à récupérer. |
| `offset` | Number | `0` | Décalage pour la pagination. |

```javascript
// Feed principal (algorithme scoring)
const feed = await Ondes.Social.getFeed();

// Feed découverte (posts publics populaires)
const discover = await Ondes.Social.getFeed({ type: 'discover', limit: 30 });

// Feed amis only (amitié bidirectionnelle)
const friends = await Ondes.Social.getFeed({ type: 'friends' });

// Feed vidéo "TikTok style"
const videos = await Ondes.Social.getFeed({ type: 'video', limit: 10 });
```

**Retour :** Liste de posts (voir structure Post ci-dessous).

### `getUserPosts(userId, options?)`
Récupère les publications d'un utilisateur spécifique.

| Paramètre | Type | Default | Description |
|-----------|------|---------|-------------|
| `userId` | Number | — | ID de l'utilisateur (obligatoire, arg positionnel). |
| `limit` | Number | `30` | Nombre de posts. |
| `offset` | Number | `0` | Pagination. |

```javascript
const posts = await Ondes.Social.getUserPosts(42, { limit: 20, offset: 0 });
```

---

## Publications (Posts)

### `publish(options)`
Crée un nouveau post (avec ou sans média).

| Paramètre | Type | Description |
|-----------|------|-------------|
| `content` | String | Légende du post. |
| `media` | Array\<String\> | Chemins locaux des fichiers à uploader. |
| `visibility` | String | `'public'`, `'followers'`, `'private'`. |
| `tags` | Array\<String\> | Tags associés au post. |
| `latitude` | Number | Latitude (géolocalisation optionnelle). |
| `longitude` | Number | Longitude. |
| `locationName` | String | Nom du lieu affiché. |

```javascript
await Ondes.Social.publish({
    content: "Coucher de soleil magnifique ! 🌅",
    media: ["/path/to/sunset.jpg"],
    visibility: "public",
    tags: ["sunset", "photography"]
});
```

### `getPost(postUuid)`
Récupère les détails complets d'un post.

```javascript
const post = await Ondes.Social.getPost('abc-123');
```

### `deletePost(postUuid)`
Supprime un post existant (auteur uniquement).

---

## Interactions

### `likePost(postUuid)` / `unlikePost(postUuid)`
Ajoute ou retire un "J'aime" sur un post.

```javascript
await Ondes.Social.likePost('post-uuid');
await Ondes.Social.unlikePost('post-uuid');
```

### `getPostLikers(postUuid)`
Récupère la liste des utilisateurs ayant aimé un post.

```javascript
const likers = await Ondes.Social.getPostLikers('post-uuid');
// [{ id, username, avatar, is_following }, ...]
```

### `addComment(postUuid, content, parentUuid?)`
Ajoute un commentaire à un post. Si `parentUuid` est fourni, c'est une réponse à un autre commentaire (commentaires imbriqués).

```javascript
// Commentaire principal
await Ondes.Social.addComment('post-uuid', 'Super photo !');

// Réponse à un commentaire
await Ondes.Social.addComment('post-uuid', 'Merci !', 'parent-comment-uuid');
```

### `getComments(postUuid, options?)`
Récupère les commentaires d'un post.

| Paramètre | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | Number | `50` | Nombre de commentaires. |
| `offset` | Number | `0` | Pagination. |

```javascript
const comments = await Ondes.Social.getComments('post-uuid', { limit: 20 });
// [{ uuid, user, content, likes_count, is_liked, replies_count, created_at }, ...]
```

### `getCommentReplies(commentUuid)`
Récupère les réponses à un commentaire spécifique.

```javascript
const replies = await Ondes.Social.getCommentReplies('comment-uuid');
```

### `likeComment(commentUuid)`
Ajoute un "J'aime" sur un commentaire.

### `deleteComment(commentUuid)`
Supprime un commentaire (auteur uniquement).

### `bookmarkPost(postUuid)` / `unbookmarkPost(postUuid)`
Sauvegarde ou retire un post des favoris privés de l'utilisateur.

```javascript
await Ondes.Social.bookmarkPost('post-uuid');
await Ondes.Social.unbookmarkPost('post-uuid');
```

### `getBookmarks(options?)`
Récupère la liste des posts sauvegardés par l'utilisateur.

| Paramètre | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | Number | `50` | Nombre de posts. |
| `offset` | Number | `0` | Pagination. |

```javascript
const bookmarks = await Ondes.Social.getBookmarks({ limit: 30 });
```

---

## Stories (éphémères 24h)

### `createStory(mediaPath, duration?)`
Publie une photo ou vidéo visible pendant 24h.

| Paramètre | Type | Default | Description |
|-----------|------|---------|-------------|
| `mediaPath` | String | — | Chemin local vers le fichier média. |
| `duration` | Number | `5.0` | Durée d'affichage en secondes (images). |

```javascript
await Ondes.Social.createStory('/path/to/photo.jpg');
await Ondes.Social.createStory('/path/to/video.mp4', 15);
```

### `getStories()`
Récupère les stories des utilisateurs suivis, groupées par auteur.

```javascript
const storyGroups = await Ondes.Social.getStories();
// [{ user: {...}, stories: [...], hasUnviewed: true }, ...]
```

Chaque story contient : `uuid`, `author`, `media_url`, `hls_url`, `media_type`, `duration`, `views_count`, `is_viewed`, `created_at`, `expires_at`.

### `viewStory(storyUuid)`
Marque une story comme vue (incrémente le compteur).

```javascript
await Ondes.Social.viewStory('story-uuid');
// { success: true, viewsCount: 42 }
```

### `deleteStory(storyUuid)`
Supprime une de ses propres stories.

---

## Relations (Follow)

Contrairement à `Ondes.Friends` (amitié bidirectionnelle), `Ondes.Social` gère le système de **Followers/Following** (unidirectionnel).

### `follow(options)` / `unfollow(options)`
Suivre ou ne plus suivre un utilisateur.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `userId` | Number | ID de l'utilisateur. |
| `username` | String | Ou nom d'utilisateur (alternatif). |

```javascript
await Ondes.Social.follow({ userId: 42 });
await Ondes.Social.unfollow({ username: 'alice' });
```

### `getFollowers(userId?)`
Récupère la liste des abonnés d'un utilisateur. Sans argument, retourne ses propres abonnés.

### `getFollowing(userId?)`
Récupère la liste des abonnements d'un utilisateur.

```javascript
const myFollowers = await Ondes.Social.getFollowers();
const aliceFollowing = await Ondes.Social.getFollowing(42);
// [{ id, username, avatar, bio, is_following }, ...]
```

---

## Médias

### `pickMedia(options?)`
Ouvre la galerie native pour laisser l'utilisateur choisir des photos ou vidéos.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `multiple` | Boolean | `false` | Autoriser plusieurs fichiers. |
| `maxFiles` | Number | `10` | Nombre max de fichiers. |
| `allowVideo` | Boolean | `false` | Autoriser les vidéos. |
| `videoOnly` | Boolean | `false` | Vidéos uniquement. |

```javascript
const files = await Ondes.Social.pickMedia({
    multiple: true,
    maxFiles: 5,
    allowVideo: true
});
// [{ path: "/local/path", type: "image", name: "photo.jpg", previewUrl: "data:..." }, ...]
```

---

## Structure des données

### Post
```javascript
{
    uuid: "abc-123",
    author: { id, username, avatar, bio, followers_count, following_count, is_following },
    content: "Ma légende",
    visibility: "public",
    tags: ["tag1", "tag2"],
    media: [
        {
            uuid: "...",
            media_type: "image" | "video",
            display_url: "https://...",
            thumbnail_url: "https://...",
            hls_url: "https://..." | null,       // Présent pour les vidéos HLS-ready
            width: 1920, height: 1080,
            duration: 30.5,                       // Secondes (vidéos)
            processing_status: "completed",
            hls_ready: true,
            order: 0
        }
    ],
    likes_count: 42,
    comments_count: 5,
    shares_count: 0,
    views_count: 120,
    user_has_liked: true,
    user_has_bookmarked: false,
    comments_preview: [/* premiers commentaires */],
    latitude: 48.8566, longitude: 2.3522,
    location_name: "Paris, France",
    created_at: "2026-01-15T14:30:00Z",
    relevance_score: 0.85
}
```
