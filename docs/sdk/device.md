# 📱 Ondes.Device - Matériel

Ce module fournit un accès aux capteurs et fonctionnalités matérielles de l'appareil.

---

## `hapticFeedback(style)`
Déclenche un retour haptique (vibration précise) pour donner un feedback physique à l'utilisateur.

| Style | Description |
|-------|-------------|
| `'light'` | Vibration très légère et courte. |
| `'medium'` | Vibration standard. |
| `'heavy'` | Vibration plus lourde. |
| `'success'` | Séquence indiquant un succès. |
| `'warning'` | Séquence indiquant un avertissement. |
| `'error'` | Séquence indiquant une erreur. |

```javascript
// Lors d'un succès
await Ondes.Device.hapticFeedback('success');
```

---

## `vibrate(duration)`
Fait vibrer l'appareil pendant une durée donnée (méthode plus brute que le retour haptique).

| Paramètre | Type | Description |
|-----------|------|-------------|
| `duration` | Number | Durée en millisecondes. |

```javascript
await Ondes.Device.vibrate(500); // Vibre pendant une demi-seconde
```

---

## `scanQRCode()`
Ouvre une interface caméra native pour scanner un QR Code.

**Retourne** : `Promise<String>` - Le contenu texte du code scanné.

**Erreurs possibles** : `PERMISSION_DENIED`, `CANCELLED`.

```javascript
try {
    const content = await Ondes.Device.scanQRCode();
    console.log("Code trouvé :", content);
} catch (e) {
    if (e.code === 'CANCELLED') {
        console.log("Lecture annulée par l'utilisateur");
    }
}
```

---

## `getGPSPosition()`
Récupère la position géographique actuelle de l'appareil.

**Retourne** :
```javascript
{
    latitude: 48.8566,
    longitude: 2.3522,
    accuracy: 10.5 // Précision du signal en mètres
}
```

```javascript
const pos = await Ondes.Device.getGPSPosition();
showMapAt(pos.latitude, pos.longitude);
```

---

## `getInfo()`
Obtient des informations techniques sur l'appareil et le système.

**Retourne** :

| Champ | Type | Description |
|-------|------|-------------|
| `platform` | String | `'ios'`, `'android'`, `'macos'`, `'windows'`, etc. |
| `version` | String | Version du système d'exploitation. |
| `model` | String | Modèle de l'appareil (ex: "iPhone 13"). |

```javascript
const info = await Ondes.Device.getInfo();
if (info.platform === 'ios') {
    // Adapter l'UI pour iOS
}
```

