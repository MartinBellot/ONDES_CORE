# 👤 Ondes.User - Utilisateur

Ce module permet d'accéder aux informations de l'utilisateur actuellement connecté à l'application principale.

---

## `getProfile()`
Récupère les informations publiques du profil utilisateur.

**Retourne** : `Promise<UserProfile>`

| Champ | Type | Description |
|-------|------|-------------|
| `id` | Number | Identifiant unique interne. |
| `username` | String | Nom d'utilisateur (handle). |
| `email` | String | Adresse email. |
| `avatar` | String | URL complète de l'image de profil. |
| `bio` | String | Biographie de l'utilisateur. |

```javascript
const user = await Ondes.User.getProfile();
document.getElementById('welcome').innerText = `Bonjour, ${user.username}`;
```

---

## ~~`getAuthToken()`~~ (SUPPRIMÉ - Raisons de sécurité)

> ⚠️ **IMPORTANT : Cette méthode a été supprimée pour des raisons de sécurité.**

**Pourquoi cette suppression ?**

Les tokens d'authentification donnent un accès complet au compte utilisateur. Exposer ce token aux mini-applications représente un risque de sécurité majeur :

- 🚨 Une mini-app malveillante pourrait voler le token
- 🚨 Le token volé permettrait d'usurper l'identité de l'utilisateur
- 🚨 L'attaquant aurait accès complet au compte (posts, messages, amis, etc.)

**Alternative sécurisée :**

Toutes les fonctionnalités nécessaires sont disponibles via des API du bridge qui gèrent l'authentification de manière sécurisée en interne :

- **Social** : `Ondes.Social.*` pour les posts, likes, commentaires, stories
- **Friends** : `Ondes.Friends.*` pour la gestion des amis
- **Storage** : `Ondes.Storage.*` pour le stockage persistant
- **Device** : `Ondes.Device.*` pour les fonctionnalités matérielles

Si votre mini-app a besoin d'accéder à des API externes, ces appels doivent être effectués côté serveur backend, pas depuis le client.

```javascript
// ❌ ANCIEN CODE (ne fonctionne plus)
// const token = await Ondes.User.getAuthToken();
// fetch('https://api.backend.com/data', {
//     headers: { 'Authorization': `Token ${token}` }
// });

// ✅ NOUVEAU CODE (utilisez les APIs du bridge)
const posts = await Ondes.Social.getFeed({ limit: 20 });
const friends = await Ondes.Friends.list();
```

---

## `isAuthenticated()`
Vérifie rapidement si une session utilisateur est active.

**Retourne** : `Promise<Boolean>`

```javascript
if (await Ondes.User.isAuthenticated()) {
    showDashboard();
} else {
    showLoginPrompt();
}
```
