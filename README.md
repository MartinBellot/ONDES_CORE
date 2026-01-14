# 📘 OndesBridge SDK — Documentation Officielle v1.0

Bienvenue dans le SDK OndesBridge. Ce kit de développement permet à votre Mini-App (HTML/JS/CSS) de communiquer avec le noyau natif "Ondes Core" pour accéder aux fonctionnalités du smartphone, gérer l'utilisateur et stocker des données.

## 🚀 Initialisation

Le pont `window.Ondes` est injecté automatiquement au chargement de votre application dans le navigateur d'Ondes Core.

> **Bonne pratique :** Vérifiez toujours si l'environnement est disponible avant d'appeler une fonction.

```javascript
document.addEventListener('DOMContentLoaded', () => {
    if (window.Ondes) {
        console.log("✅ Ondes Core connectée");
    } else {
        console.warn("⚠️ Mode Web classique (Hors Ondes Core)");
    }
});
```

> **⚠️ Note Importante :** Toutes les méthodes du SDK sont **Asynchrones** et retournent des `Promise`. Utilisez `async/await` ou `.then()` pour gérer les réponses.

## 1. 🎨 Interface (Ondes.UI)

Contrôlez l'interface native qui entoure votre application.

### `Ondes.UI.showToast(options)`

Affiche une notification native temporaire (Snackbar) en bas de l'écran.

**options {Object}**
*   `message` (String) : Le texte à afficher.
*   `type` (String) : `'info'`, `'success'`, `'error'`, `'warning'`.

**Retourne :** `Promise<void>`

```javascript
Ondes.UI.showToast({
    message: "Connexion réussie",
    type: "success"
});
```

### `Ondes.UI.configureAppBar(options)`

Modifie la barre de navigation native située au-dessus de votre app.

**options {Object}**
*   `title` (String) : Titre de l'écran.
*   `visible` (Boolean) : Afficher ou cacher la barre.
*   `backgroundColor` (String) : Code Hex (ex: `#FFFFFF`).
*   `foregroundColor` (String) : Code Hex pour le texte (ex: `#000000`).

**Retourne :** `Promise<void>`

```javascript
Ondes.UI.configureAppBar({
    title: "Mon Panier",
    visible: true,
    backgroundColor: "#101010",
    foregroundColor: "#FFFFFF"
});
```

### `Ondes.UI.showAlert(options)`

Ouvre une modale de dialogue native (popup).

**options {Object}**
*   `title` (String) : Titre de la modale.
*   `message` (String) : Corps du message.
*   `buttonText` (String) : Texte du bouton (Défaut: "OK").

**Retourne :** `Promise<void>` (résolue quand l'utilisateur ferme la popup).

## 2. 👤 Utilisateur (Ondes.User)

Accédez à l'identité de l'utilisateur connecté.

### `Ondes.User.getProfile()`

Récupère les informations publiques de l'utilisateur courant.

**Retourne :** `Promise<Object>`
*   `id` (String) : Identifiant unique (UUID).
*   `username` (String) : Nom d'utilisateur.
*   `avatar` (String) : URL de l'avatar.
*   `locale` (String) : Langue (ex: `fr-FR`).

```javascript
const user = await Ondes.User.getProfile();
console.log(`Bonjour ${user.username}`);
```

### `Ondes.User.getAuthToken()`

Récupère le jeton de session (JWT) actif pour authentifier vos requêtes HTTP vers vos serveurs.

**Retourne :** `Promise<String>` (Le token JWT).

## 3. 📱 Matériel (Ondes.Device)

Interagissez avec les capteurs et le hardware du téléphone.

### `Ondes.Device.hapticFeedback(style)`

Déclenche une vibration physique.

**style (String) :**
*   `'light'`, `'medium'`, `'heavy'` (Impacts physiques)
*   `'success'`, `'error'`, `'warning'` (Notifications haptiques)

**Retourne :** `Promise<void>`

### `Ondes.Device.scanQRCode()`

Ouvre l'appareil photo en mode scanner plein écran.

**Retourne :** `Promise<String>` (Le contenu décodé du QR Code).
**Erreur :** Rejette si l'utilisateur annule ou refuse la permission.

```javascript
try {
    const code = await Ondes.Device.scanQRCode();
    alert("Produit scanné : " + code);
} catch (e) {
    console.log("Scan annulé");
}
```

### `Ondes.Device.getGPSPosition()`

Obtient la position précise (GPS).

**Retourne :** `Promise<Object>`
*   `latitude` (Number)
*   `longitude` (Number)
*   `accuracy` (Number)

## 4. 💾 Stockage (Ondes.Storage)

Base de données persistante, isolée et sécurisée pour votre app.

### `Ondes.Storage.set(key, value)`

Sauvegarde une valeur.

*   `key` (String) : Clé unique.
*   `value` (Any) : Objet JSON, String, Number, Boolean.

**Retourne :** `Promise<void>`

### `Ondes.Storage.get(key)`

Récupère une valeur.

*   `key` (String) : Clé unique.

**Retourne :** `Promise<Any>` (ou `null` si non trouvé).

### `Ondes.Storage.remove(key)`

Efface une valeur spécifique.

**Retourne :** `Promise<void>`

```javascript
// Exemple de sauvegarde de préférences
await Ondes.Storage.set('settings', { theme: 'dark', notifs: true });

// Récupération
const settings = await Ondes.Storage.get('settings');
```

## 5. ⚙️ Système (Ondes.App)

Gestion du cycle de vie de la mini-app.

### `Ondes.App.getInfo()`

Infos sur la mini-app courante.

**Retourne :** `Promise<Object>`
*   `version` (String) : Version actuelle (ex: "1.0.2").
*   `buildNumber` (Number).
*   `platform` (String) : "ios" ou "android".

### `Ondes.App.close()`

Ferme la mini-app et retourne à l'accueil Ondes Core.

**Retourne :** `Promise<void>`

## Gestion des Erreurs

Si une fonction native échoue (ex: pas de caméra, erreur disque), la Promise sera rejetée avec un objet erreur standard :

```javascript
{
  code: "PERMISSION_DENIED",
  message: "L'utilisateur a refusé l'accès à la caméra."
}
```
