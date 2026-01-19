# 🎨 Ondes.UI - Interface Utilisateur

Ce module permet de contrôler l'interface native de l'application hôte.

---

## `showToast(options)`
Affiche une notification temporaire en bas de l'écran.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `message` | String | Texte à afficher. |
| `type` | String | Type de message : `'info'`, `'success'`, `'error'`, `'warning'`. |

```javascript
await Ondes.UI.showToast({
    message: "Sauvegarde effectuée !",
    type: "success"
});
```

---

## `showAlert(options)`
Affiche une boîte de dialogue modale informative.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre de la modale. |
| `message` | String | Contenu du message. |
| `buttonText` | String | Texte du bouton (défaut: "OK"). |

```javascript
await Ondes.UI.showAlert({
    title: "Maintenance",
    message: "Le serveur sera indisponible ce soir.",
    buttonText: "J'ai compris"
});
```

---

## `showConfirm(options)`
Affiche une boîte de confirmation avec deux choix.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre. |
| `message` | String | Question posée à l'utilisateur. |
| `confirmText` | String | Texte du bouton de validation. |
| `cancelText` | String | Texte du bouton d'annulation. |

**Retourne** : `Promise<Boolean>` - `true` si l'utilisateur confirme, `false` sinon.

```javascript
const ok = await Ondes.UI.showConfirm({
    title: "Supprimer",
    message: "Êtes-vous sûr de vouloir supprimer cet élément ?",
    confirmText: "Oui, supprimer",
    cancelText: "Annuler"
});

if (ok) {
    deleteItem();
}
```

---

## `showBottomSheet(options)`
Affiche un menu contextuel glissant depuis le bas de l'écran.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre du menu. |
| `options` | Array | Liste des options disponibles. |

Structure d'une option : `{ id: "unique_id", label: "Texte visible", icon: "emoji_ou_nom" }`

**Retourne** : `Promise<String|null>` - L'ID de l'option choisie, ou `null` si annulé.

```javascript
const choice = await Ondes.UI.showBottomSheet({
    title: "Choisir une action",
    options: [
        { id: "edit", label: "Modifier", icon: "✏️" },
        { id: "share", label: "Partager", icon: "📤" },
        { id: "delete", label: "Supprimer", icon: "🗑️" }
    ]
});
```

---

## `configureAppBar(options)`
Configure la barre de navigation native (en haut de l'écran).

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre affiché. |
| `visible` | Boolean | `true` pour afficher, `false` pour masquer la barre. |
| `backgroundColor` | String | Couleur de fond (code hexadécimal). |
| `foregroundColor` | String | Couleur du texte et des icônes (code hexadécimal). |

```javascript
await Ondes.UI.configureAppBar({
    title: "Mon Espace",
    visible: true,
    backgroundColor: "#FF5722",
    foregroundColor: "#FFFFFF"
});
```
