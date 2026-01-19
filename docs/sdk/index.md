# 📚 SDK OndesBridge

Le SDK `OndesBridge` permet à votre code JavaScript de communiquer avec les fonctionnalités natives de l'appareil et de l'application hôte. Il est injecté automatiquement dans l'objet global `window.Ondes`.

## Initialisation

L'objet `Ondes` n'est pas disponible immédiatement au chargement de la page. Vous devez écouter l'événement `OndesReady`.

```javascript
// ✅ RECOMMANDÉ
document.addEventListener('OndesReady', () => {
    console.log("SDK chargé et prêt à l'emploi");
    initApp();
});

// ❌ À ÉVITER
// Peut échouer si le bridge n'est pas encore injecté
console.log(Ondes.User.getProfile()); 
```

## Modules disponibles

Le SDK est divisé en plusieurs modules thématiques :

- [**Ondes.UI**](ui.md) : Gestion de l'interface (Toasts, Modales, Navigation).
- [**Ondes.User**](user.md) : Informations sur l'utilisateur connecté.
- [**Ondes.Device**](device.md) : Accès matériel (Vibration, GPS, Caméra).
- [**Ondes.Storage**](storage.md) : Stockage de données persistant.
- [**Ondes.App**](app.md) : Infos sur l'application et cycle de vie.
- [**Ondes.Friends**](friends.md) : Gestion des amis et du graphe social.
- [**Ondes.Social**](social.md) : Fonctionnalités de réseau social (Feed, Posts, Stories).

## Gestion des erreurs

Toutes les méthodes du SDK sont asynchrones et retournent des `Promise`. Il est important de gérer les erreurs, notamment pour les permissions ou les problèmes réseaux.

### Codes d'erreur courants

| Code | Description |
|------|-------------|
| `PERMISSION_DENIED` | L'utilisateur a refusé la permission demandée. |
| `NOT_SUPPORTED` | La fonctionnalité n'est pas disponible sur cet appareil. |
| `CANCELLED` | L'utilisateur a annulé l'action (ex: scan QR code). |
| `NETWORK_ERROR` | Problème de connexion internet. |
| `AUTH_REQUIRED` | L'utilisateur doit être connecté. |
| `NOT_FOUND` | La ressource demandée n'existe pas. |

### Pattern recommandé

Utilisez `try/catch` pour capturer les erreurs proprement.

```javascript
async function safeAction() {
    try {
        const result = await Ondes.Device.scanQRCode();
        console.log("Résultat:", result);
    } catch (error) {
        console.warn('Erreur:', error.message);
        
        if (error.code === 'PERMISSION_DENIED') {
            Ondes.UI.showToast({
                message: "Accès caméra refusé",
                type: "error"
            });
        }
    }
}
```
