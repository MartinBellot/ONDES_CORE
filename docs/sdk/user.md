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
