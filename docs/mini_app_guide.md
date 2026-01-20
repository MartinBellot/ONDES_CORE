# 👨‍💻 Guide du développeur Mini-App

Apprenez à créer votre première application pour l'écosystème Ondes.

## 🎯 Choisissez votre approche

| Approche | Technologies | Pour qui ? |
|----------|-------------|------------|
| 🌐 **Web classique** | HTML, CSS, JavaScript | Développeurs web, projets simples |
| 💙 **Flutter Web** | Dart, Flutter | Développeurs Flutter, apps complexes |

> 💡 Ce guide couvre l'approche **Web classique**. Pour Flutter, consultez le [SDK Flutter](sdk/flutter.md).

---

## Démarrage rapide (Web)

Créez votre première mini-app en 3 étapes simples :

### Étape 1 : Créer la structure

Créez un dossier pour votre projet avec les fichiers suivants :

```
mon-app/
├── index.html      # Point d'entrée (obligatoire)
├── manifest.json   # Métadonnées (obligatoire)
├── app.js          # Votre logique JavaScript
└── style.css       # Vos styles
```

### Étape 2 : Configurer le manifest

Le fichier `manifest.json` est la carte d'identité de votre app.

```json
{
    "id": "com.monentreprise.monapp",
    "name": "Ma Super App",
    "version": "1.0.0",
    "description": "Une description incroyable",
    "icon": "icon.png"
}
```

### Étape 3 : Écrire le code

**index.html** :
```html
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ma Super App</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>Bienvenue !</h1>
    <button id="btn">Dire bonjour</button>
    
    <script src="app.js"></script>
</body>
</html>
```

**app.js** :
```javascript
// On attend toujours que le SDK Ondes soit prêt
document.addEventListener('OndesReady', async () => {
    console.log('✅ Ondes SDK prêt !');
    
    // Exemple : Récupérer l'utilisateur courant
    const user = await Ondes.User.getProfile();
    
    document.getElementById('btn').addEventListener('click', () => {
        // Afficher un toast natif
        Ondes.UI.showToast({
            message: `Bonjour ${user.username} !`,
            type: 'success'
        });
    });
});
```

## Structure détaillée d'une Mini-App

| Fichier | Requis | Description |
|---------|--------|-------------|
| `index.html` | ✅ Oui | Le point d'entrée de votre application. C'est ce fichier qui est chargé par la WebView. |
| `manifest.json` | ✅ Oui | Contient les métadonnées essentielles (nom, version, permissions...). |
| `*.js` | Non | Vos scripts. Vous pouvez avoir plusieurs fichiers JS. |
| `*.css` | Non | Vos feuilles de styles. |
| `assets/` | Non | Dossier recommandé pour vos images, polices, sons, etc. |

## Le Manifest (`manifest.json`)

Le manifest décrit les propriétés de l'application.

```json
{
    "id": "com.domaine.nomapp",
    "name": "Nom Affiché",
    "version": "1.2.3",
    "description": "Description courte de l'app",
    "icon": "assets/icon.png",
    "author": "Votre Nom",
    "permissions": ["camera", "location", "storage"]
}
```

### Champs du manifest

| Champ | Type | Description |
|-------|------|-------------|
| `id` | String | **Unique**. Identifiant au format reverse-domain (ex: `com.google.maps`). |
| `name` | String | Nom affiché dans le store et sur l'écran d'accueil. |
| `version` | String | Version sémantique (MAJOR.MINOR.PATCH). **Incrémentez-la à chaque mise à jour.** |
| `description` | String | Description qui apparaîtra dans le store. |
| `icon` | String | Chemin relatif vers l'icône de l'app (PNG, 512x512 recommandé). |
| `author` | String | Nom du développeur ou de l'entreprise (optionnel). |
| `permissions` | Array | Liste des permissions requises (ex: `["camera"]`). (optionnel) |
