# 📦 Ondes.App - Système Application

Ce module fournit des informations sur la mini-application elle-même et permet d'en contrôler le cycle de vie.

---

## `getInfo()`
Récupère les métadonnées de l'application en cours d'exécution.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `bundleId` | String | L'identifiant unique (défini dans le manifest). |
| `name` | String | Nom de l'application. |
| `version` | String | Version actuelle. |
| `platform` | String | Plateforme hôte. |
| `sdkVersion` | String | Version du SDK Ondes utilisé. |

```javascript
const info = await Ondes.App.getInfo();
console.log(`Application: ${info.name} (v${info.version})`);
```

---

## `getManifest()`
Récupère l'intégralité du contenu du fichier `manifest.json`.

**Retourne** : `Promise<Object>`

```javascript
const manifest = await Ondes.App.getManifest();
if (manifest.permissions.includes('camera')) {
    showCameraIcon();
}
```

---

## `close()`
Ferme la mini-application et renvoie l'utilisateur à l'écran d'accueil d'Ondes Core.

> Il est recommandé de demander confirmation à l'utilisateur avant d'appeler cette fonction s'il y a des changements non sauvegardés.

```javascript
document.getElementById('quit-btn').addEventListener('click', async () => {
    const shouldQuit = await Ondes.UI.showConfirm({
        title: "Quitter ?",
        message: "Toute progression non sauvegardée sera perdue."
    });

    if (shouldQuit) {
        await Ondes.App.close();
    }
});
```
