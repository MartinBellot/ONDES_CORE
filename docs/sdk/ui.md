# 🎨 Ondes.UI - Interface Utilisateur v3.0

Ce module permet de contrôler l'interface native de l'application hôte avec des options de personnalisation avancées.

---

## 📋 Table des Matières

- [Notifications & Toasts](#showtoastoptions)
- [Boîtes de Dialogue](#showAlertoptions)
- [Modales Ultra-Customisées](#showmodaloptions)
- [Action Sheets & Bottom Sheets](#showactionsheetoptions)
- [Système de Drawer](#configuredraweroptions)
- [AppBar Avancée](#configureappbaroptions)
- [Loading & Progress](#showloadingoptions)
- [Snackbar Avancé](#showsnackbaroptions)
- [Styles & Typographies](#styles--typographies)

---

## `showToast(options)`
Affiche une notification temporaire en bas de l'écran.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `message` | String | Texte à afficher. |
| `type` | String | Type de message : `'info'`, `'success'`, `'error'`, `'warning'`. |
| `duration` | Number | Durée d'affichage en ms (défaut: 3000). |
| `position` | String | Position : `'top'` ou `'bottom'` (défaut). |
| `backgroundColor` | String | Couleur personnalisée (hex). |
| `bold` | Boolean | Texte en gras. |
| `hideIcon` | Boolean | Masquer l'icône. |

```javascript
await Ondes.UI.showToast({
    message: "Sauvegarde effectuée !",
    type: "success",
    duration: 4000,
    bold: true
});
```

---

## `showAlert(options)`
Affiche une boîte de dialogue modale informative avec styles personnalisables.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre de la modale. |
| `message` | String | Contenu du message. |
| `buttonText` | String | Texte du bouton (défaut: "OK"). |
| `icon` | String | Nom de l'icône (voir liste des icônes). |
| `iconColor` | String | Couleur de l'icône (hex). |
| `borderRadius` | Number | Rayon des coins (défaut: 16). |
| `dismissible` | Boolean | Fermer en cliquant à l'extérieur (défaut: true). |
| `titleStyle` | Object | Style du titre (voir Styles). |
| `messageStyle` | Object | Style du message. |
| `buttonStyle` | Object | Style du bouton. |
| `buttonColor` | String | Couleur du bouton. |

```javascript
await Ondes.UI.showAlert({
    title: "Maintenance",
    message: "Le serveur sera indisponible ce soir.",
    buttonText: "J'ai compris",
    icon: "warning",
    iconColor: "#f59e0b",
    borderRadius: 20,
    titleStyle: {
        fontFamily: "Poppins",
        bold: true,
        fontSize: 20
    }
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
| `confirmColor` | String | Couleur du bouton de confirmation. |
| `cancelColor` | String | Couleur du bouton d'annulation. |
| `icon` | String | Icône affichée. |
| `iconColor` | String | Couleur de l'icône. |

**Retourne** : `Promise<Boolean>` - `true` si l'utilisateur confirme, `false` sinon.

```javascript
const ok = await Ondes.UI.showConfirm({
    title: "Supprimer",
    message: "Êtes-vous sûr de vouloir supprimer cet élément ?",
    confirmText: "Oui, supprimer",
    cancelText: "Annuler",
    confirmColor: "#ef4444",
    icon: "delete",
    iconColor: "#ef4444"
});

if (ok) {
    deleteItem();
}
```

---

## `showInputDialog(options)`
Affiche une boîte de dialogue avec un champ de saisie.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre. |
| `message` | String | Message explicatif. |
| `placeholder` | String | Texte indicatif dans le champ. |
| `label` | String | Label du champ. |
| `defaultValue` | String | Valeur par défaut. |
| `confirmText` | String | Texte de confirmation. |
| `cancelText` | String | Texte d'annulation. |
| `keyboardType` | String | Type de clavier : `'text'`, `'email'`, `'number'`, `'phone'`, `'url'`. |
| `obscureText` | Boolean | Masquer le texte (mot de passe). |
| `multiline` | Boolean | Champ multi-lignes. |
| `maxLength` | Number | Longueur maximale. |
| `prefixIcon` | String | Icône au début du champ. |

**Retourne** : `Promise<String|null>` - Texte saisi ou `null` si annulé.

```javascript
const name = await Ondes.UI.showInputDialog({
    title: "Nouveau dossier",
    message: "Entrez le nom du dossier",
    placeholder: "Mon dossier",
    prefixIcon: "folder",
    confirmText: "Créer",
    maxLength: 50
});

if (name) {
    createFolder(name);
}
```

---

## `showModal(options)` ⭐ NEW
Affiche une modale ultra-personnalisable avec header, sections et boutons.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre principal. |
| `message` | String | Message descriptif. |
| `icon` | String | Icône principale. |
| `iconColor` | String | Couleur de l'icône. |
| `iconBackgroundColor` | String | Couleur de fond de l'icône. |
| `iconSize` | Number | Taille de l'icône. |
| `header` | Object | Configuration du header (voir ci-dessous). |
| `sections` | Array | Sections de contenu. |
| `buttons` | Array | Boutons d'action. |
| `buttonsLayout` | String | `'horizontal'` ou `'vertical'`. |
| `borderRadius` | Number | Rayon des coins. |
| `backgroundColor` | String | Couleur de fond. |
| `barrierColor` | String | Couleur du fond assombri. |
| `centerContent` | Boolean | Centrer le contenu. |
| `padding` | Number | Espacement interne. |
| `maxWidth` | Number | Largeur maximale. |
| `maxHeight` | Number | Hauteur maximale. |
| `footerColor` | String | Couleur du footer. |
| `titleStyle` | Object | Style du titre. |
| `messageStyle` | Object | Style du message. |

### Header Configuration

```javascript
header: {
    title: "Titre du Header",
    icon: "settings",
    backgroundColor: "#1a73e8",
    iconColor: "#ffffff",
    titleStyle: { bold: true, color: "#ffffff" },
    showClose: true,
    closeColor: "#ffffff"
}
```

### Sections Configuration

```javascript
sections: [
    {
        title: "Section 1",
        titleStyle: { color: "#666", bold: true },
        content: "Texte de la section",
        items: [
            { icon: "check", text: "Item 1", value: "Valeur", valueColor: "#22c55e" },
            { icon: "check", text: "Item 2", value: "Autre" }
        ]
    }
]
```

### Buttons Configuration

```javascript
buttons: [
    { label: "Annuler", value: "cancel", outlined: true },
    { label: "Confirmer", value: "confirm", primary: true, icon: "check" },
    { label: "Supprimer", value: "delete", danger: true }
]
```

**Retourne** : `Promise<String|null>` - Valeur du bouton cliqué.

### Exemple Complet

```javascript
const result = await Ondes.UI.showModal({
    icon: "star",
    iconColor: "#f59e0b",
    iconBackgroundColor: "#fef3c7",
    iconSize: 56,
    title: "Nouvelle Fonctionnalité !",
    message: "Découvrez les modales ultra-personnalisables.",
    centerContent: true,
    borderRadius: 24,
    titleStyle: {
        fontFamily: "Poppins",
        fontSize: 24,
        bold: true
    },
    sections: [
        {
            title: "Nouveautés",
            items: [
                { icon: "check", text: "Feature 1", value: "✓" },
                { icon: "check", text: "Feature 2", value: "✓" }
            ]
        }
    ],
    buttons: [
        { label: "Plus tard", value: "later", outlined: true },
        { label: "Découvrir", value: "discover", primary: true }
    ]
});
```

---

## `showBottomSheet(options)`
Affiche un menu contextuel glissant depuis le bas de l'écran.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre du menu. |
| `subtitle` | String | Sous-titre. |
| `items` | Array | Liste des options. |
| `scrollable` | Boolean | Contenu scrollable. |
| `showDragHandle` | Boolean | Afficher la poignée de glissement. |
| `borderRadius` | Number | Rayon des coins. |
| `backgroundColor` | String | Couleur de fond. |
| `titleStyle` | Object | Style du titre. |

### Structure d'un Item

```javascript
{
    icon: "photo",
    label: "Galerie",
    subtitle: "Description optionnelle",
    value: "gallery",
    iconColor: "#22c55e",
    bold: true,
    danger: false,
    disabled: false,
    trailing: "→",
    badge: "3",
    badgeColor: "#ef4444"
}
```

### Items Spéciaux

```javascript
// Séparateur
{ type: "divider", height: 16, indent: 16 }

// En-tête de section
{ type: "section", title: "Catégorie", color: "#666" }
```

**Retourne** : `Promise<String|null>` - L'ID de l'option choisie, ou `null` si annulé.

```javascript
const choice = await Ondes.UI.showBottomSheet({
    title: "Ajouter un média",
    subtitle: "Choisissez une source",
    showDragHandle: true,
    borderRadius: 24,
    titleStyle: { fontFamily: "Poppins", bold: true },
    items: [
        { icon: "photo", label: "Galerie", value: "gallery", iconColor: "#22c55e" },
        { icon: "camera", label: "Appareil Photo", value: "camera", iconColor: "#3b82f6" },
        { type: "divider" },
        { icon: "delete", label: "Supprimer", value: "delete", danger: true }
    ]
});
```

---

## `showActionSheet(options)` ⭐ NEW
Affiche un action sheet style iOS.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre. |
| `message` | String | Message descriptif. |
| `actions` | Array | Liste des actions. |
| `cancelText` | String | Texte du bouton annuler. |

### Structure d'une Action

```javascript
{
    label: "Partager",
    value: "share",
    destructive: false,
    bold: false
}
```

**Retourne** : `Promise<String|null>` - Valeur de l'action choisie.

```javascript
const action = await Ondes.UI.showActionSheet({
    title: "Options",
    message: "Choisissez une action",
    actions: [
        { label: "Partager", value: "share" },
        { label: "Copier", value: "copy" },
        { label: "Supprimer", value: "delete", destructive: true }
    ],
    cancelText: "Annuler"
});
```

---

## `configureAppBar(options)` ⭐ ENHANCED
Configure la barre de navigation native avec options avancées.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre affiché. |
| `visible` | Boolean | Afficher/masquer la barre. |
| `backgroundColor` | String | Couleur de fond (hex). |
| `foregroundColor` | String | Couleur du texte/icônes (hex). |
| `height` | Number | Hauteur de la barre. |
| `elevation` | Number | Ombre (0 = aucune). |
| `centerTitle` | Boolean | Centrer le titre. |
| `titleBold` | Boolean | Titre en gras. |
| `titleSize` | Number | Taille du titre. |
| `fontFamily` | String | Police Google Fonts. |
| `showBackButton` | Boolean | Afficher le bouton retour. |
| `leading` | Object | Configuration du bouton gauche. |
| `actions` | Array | Boutons d'action à droite. |

### Leading Configuration

```javascript
// Bouton menu (pour ouvrir le drawer)
leading: { type: "menu" }

// Icône personnalisée
leading: { type: "icon", icon: "search" }

// Avatar
leading: { type: "avatar", image: "https://..." }
```

### Actions Configuration

```javascript
actions: [
    // Icône simple
    { type: "icon", icon: "search", value: "search" },
    
    // Icône avec badge
    { type: "badge", icon: "notifications", value: "notif", badge: 5, badgeColor: "#ef4444" },
    
    // Bouton texte
    { type: "text", label: "Save", value: "save", bold: true, color: "#ffffff" }
]
```

### Écouter les Actions

```javascript
// Écouter les clics sur les actions
Ondes.UI.onAppBarAction((data) => {
    console.log("Action cliquée:", data.value);
});

// Écouter le clic sur le leading
Ondes.UI.onAppBarLeading((data) => {
    console.log("Leading cliqué");
});
```

### Exemple Complet

```javascript
Ondes.UI.configureAppBar({
    title: "Mon Application",
    visible: true,
    backgroundColor: "#1e293b",
    foregroundColor: "#ffffff",
    fontFamily: "Poppins",
    titleBold: true,
    titleSize: 20,
    centerTitle: false,
    elevation: 4,
    height: 64,
    leading: { type: "menu" },
    actions: [
        { type: "icon", icon: "search", value: "search" },
        { type: "badge", icon: "notifications", value: "notif", badge: 3 },
        { type: "icon", icon: "settings", value: "settings" }
    ]
});
```

---

## `configureDrawer(options)` ⭐ NEW
Configure un drawer de navigation latéral.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `enabled` | Boolean | Activer le drawer. |
| `side` | String | `'left'` ou `'right'`. |
| `width` | Number | Largeur du drawer. |
| `backgroundColor` | String | Couleur de fond. |
| `borderRadius` | Number | Rayon des coins. |
| `header` | Object | Configuration du header. |
| `items` | Array | Éléments du menu. |
| `footer` | Object | Configuration du footer. |

### Header Configuration

```javascript
header: {
    backgroundColor: "#1a73e8",
    backgroundImage: "https://...", // Image de fond optionnelle
    avatar: "https://...",
    title: "John Doe",
    subtitle: "john@example.com",
    titleColor: "#ffffff",
    subtitleColor: "#e0e7ff"
}
```

### Items Configuration

```javascript
items: [
    // Item normal
    { icon: "home", label: "Accueil", value: "home", selected: true },
    
    // Item avec badge
    { icon: "message", label: "Messages", value: "messages", badge: "5", badgeColor: "#ef4444" },
    
    // Item avec sous-titre
    { icon: "settings", label: "Paramètres", subtitle: "Personnaliser", value: "settings" },
    
    // Item avec trailing
    { icon: "help", label: "Aide", value: "help", trailing: "→" },
    
    // Item désactivé
    { icon: "lock", label: "Premium", value: "premium", disabled: true },
    
    // Séparateur
    { type: "divider" },
    
    // En-tête de section
    { type: "section", title: "Autres", color: "#666" },
    
    // Item coloré
    { icon: "logout", label: "Déconnexion", value: "logout", iconColor: "#ef4444" }
]
```

### Footer Configuration

```javascript
// Texte simple
footer: {
    text: "Version 1.0.0"
}

// Icônes d'action
footer: {
    items: [
        { icon: "settings", value: "settings", label: "Paramètres" },
        { icon: "help", value: "help", label: "Aide" },
        { icon: "logout", value: "logout", label: "Déconnexion" }
    ]
}
```

### Écouter les Sélections

```javascript
Ondes.UI.onDrawerSelect((data) => {
    console.log("Item sélectionné:", data.value);
    
    switch(data.value) {
        case 'home':
            navigateTo('/');
            break;
        case 'settings':
            navigateTo('/settings');
            break;
    }
});
```

### Exemple Complet

```javascript
// Configurer le drawer
Ondes.UI.configureDrawer({
    enabled: true,
    side: "left",
    width: 300,
    backgroundColor: "#ffffff",
    header: {
        backgroundColor: "#1a73e8",
        avatar: "https://i.pravatar.cc/150",
        title: "John Doe",
        subtitle: "john@example.com"
    },
    items: [
        { icon: "home", label: "Accueil", value: "home", selected: true },
        { icon: "person", label: "Profil", value: "profile" },
        { icon: "settings", label: "Paramètres", value: "settings" },
        { type: "divider" },
        { icon: "logout", label: "Déconnexion", value: "logout", iconColor: "#ef4444" }
    ],
    footer: {
        text: "Ondes v3.0"
    }
});

// Configurer l'AppBar avec bouton menu
Ondes.UI.configureAppBar({
    title: "Mon App",
    visible: true,
    leading: { type: "menu" }
});
```

---

## `openDrawer(side)` ⭐ NEW
Ouvre le drawer programmatiquement.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `side` | String | `'left'` (défaut) ou `'right'`. |

```javascript
Ondes.UI.openDrawer('left');
```

---

## `closeDrawer()` ⭐ NEW
Ferme le drawer ouvert.

```javascript
Ondes.UI.closeDrawer();
```

---

## `showLoading(options)` ⭐ NEW
Affiche un overlay de chargement.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `message` | String | Message à afficher. |
| `spinnerColor` | String | Couleur du spinner. |
| `spinnerSize` | Number | Taille du spinner. |
| `backgroundColor` | String | Couleur du fond du popup. |
| `barrierColor` | String | Couleur de l'overlay. |
| `barrierOpacity` | Number | Opacité de l'overlay (0-1). |
| `messageStyle` | Object | Style du message. |

```javascript
// Afficher
Ondes.UI.showLoading({
    message: "Chargement en cours...",
    spinnerColor: "#1a73e8",
    spinnerSize: 48,
    messageStyle: { fontFamily: "Poppins" }
});

// Masquer
Ondes.UI.hideLoading();
```

---

## `hideLoading()` ⭐ NEW
Masque l'overlay de chargement.

```javascript
Ondes.UI.hideLoading();
```

---

## `showProgress(options)` ⭐ NEW
Affiche un dialogue de progression.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `title` | String | Titre. |
| `message` | String | Message. |
| `progress` | Number | Progression (0-100). |
| `color` | String | Couleur de la barre. |

```javascript
for (let i = 0; i <= 100; i += 10) {
    await Ondes.UI.showProgress({
        title: "Téléchargement",
        message: `${i}% complété`,
        progress: i,
        color: "#22c55e"
    });
    await sleep(500);
}
```

---

## `showSnackbar(options)` ⭐ NEW
Affiche un snackbar avancé avec action.

| Paramètre | Type | Description |
|-----------|------|-------------|
| `message` | String | Message principal. |
| `subtitle` | String | Sous-titre optionnel. |
| `icon` | String | Icône. |
| `iconColor` | String | Couleur de l'icône. |
| `backgroundColor` | String | Couleur de fond. |
| `duration` | Number | Durée en ms (défaut: 4000). |
| `borderRadius` | Number | Rayon des coins. |
| `action` | Object | Bouton d'action. |
| `messageStyle` | Object | Style du message. |

### Action Configuration

```javascript
action: {
    label: "Annuler",
    value: "undo",
    color: "#60a5fa"
}
```

**Retourne** : `Promise<String|null>` - Valeur de l'action si cliquée.

```javascript
const result = await Ondes.UI.showSnackbar({
    message: "Élément supprimé",
    subtitle: "Cliquez pour annuler",
    icon: "delete",
    backgroundColor: "#1e293b",
    duration: 5000,
    action: {
        label: "Annuler",
        value: "undo",
        color: "#60a5fa"
    }
});

if (result === 'undo') {
    restoreItem();
}
```

---

## Styles & Typographies

### TextStyle Object

Utilisez cet objet pour personnaliser le style du texte dans toutes les APIs.

| Propriété | Type | Description |
|-----------|------|-------------|
| `fontFamily` | String | Police Google Fonts (ex: "Poppins", "Roboto", "Pacifico"). |
| `fontSize` | Number | Taille de la police. |
| `bold` | Boolean | Texte en gras. |
| `fontWeight` | Number/String | Poids (100-900) ou "bold"/"normal". |
| `italic` | Boolean | Texte en italique. |
| `color` | String | Couleur (hex). |
| `letterSpacing` | Number | Espacement des lettres. |
| `lineHeight` | Number | Hauteur de ligne. |
| `underline` | Boolean | Texte souligné. |

```javascript
{
    fontFamily: "Poppins",
    fontSize: 18,
    bold: true,
    color: "#1e293b",
    letterSpacing: 0.5
}
```

### Polices Google Fonts Populaires

- **Sans-Serif** : Poppins, Roboto, Inter, Open Sans, Lato, Montserrat, Nunito
- **Serif** : Playfair Display, Merriweather, Lora, Crimson Text
- **Display** : Pacifico, Lobster, Bebas Neue, Righteous
- **Monospace** : Fira Code, JetBrains Mono, Source Code Pro

---

## 🎯 Liste des Icônes Disponibles

### Actions
`share`, `copy`, `delete`, `edit`, `save`, `add`, `remove`, `close`, `check`, `done`, `cancel`, `refresh`, `search`, `filter`, `sort`, `menu`, `more`, `more_horiz`

### Media
`camera`, `gallery`, `photo`, `video`, `music`, `mic`, `play`, `pause`, `stop`

### Communication
`message`, `chat`, `call`, `email`, `send`, `notifications`

### Navigation
`home`, `back`, `forward`, `up`, `down`, `left`, `right`, `expand`, `collapse`

### User
`person`, `user`, `people`, `group`, `profile`, `avatar`, `logout`, `login`

### Files
`file`, `folder`, `document`, `download`, `upload`, `attach`, `link`

### Status
`info`, `warning`, `error`, `success`, `help`, `question`, `star`, `heart`, `like`, `dislike`

### Settings
`settings`, `config`, `lock`, `unlock`, `key`, `security`, `privacy`

### Location
`location`, `map`, `navigation`, `compass`, `gps`

### Time
`time`, `clock`, `calendar`, `event`, `alarm`, `timer`

### Commerce
`cart`, `bag`, `store`, `payment`, `credit_card`, `money`

### Device
`phone`, `tablet`, `laptop`, `desktop`, `bluetooth`, `wifi`, `battery`, `brightness`, `volume`

### Weather
`sun`, `moon`, `cloud`, `rain`, `snow`, `thunder`

### Misc
`bookmark`, `flag`, `block`, `qrcode`, `fingerprint`, `face`, `emoji`, `gift`, `trophy`, `fire`, `flash`, `power`, `code`, `terminal`, `bug`, `analytics`, `dashboard`, `chart`
