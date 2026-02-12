# 🛡️ Sécurité & Permissions

Ondes Core sécurise l'accès aux fonctionnalités natives du téléphone grâce à son architecture de **Sandbox**.

## Le manifeste de sécurité

Chaque Mini-App doit déclarer ses besoins dans son fichier `manifest.json`. Si une fonctionnalité sensible est utilisée sans être déclarée, l'API `Ondes` retournera une erreur de permission.

### Exemple de manifest.json

```json
{
    "id": "com.monapp.explore",
    "name": "Explorateur",
    "version": "1.0.0",
    "permissions": [
        "camera",
        "location",
        "storage"
    ]
}
```

## Liste des permissions

Voici les clés de permissions supportées par le système :

| Clé | Description |
| :--- | :--- |
| `camera` | Accès à la caméra (Scanner QR, photos) |
| `microphone` | Accès au micro |
| `location` | Accès à la position GPS |
| `storage` | Lecture/Écriture de fichiers |
| `contacts` | Accès au carnet d'adresses |
| `friends` | Accès à la liste d'amis et au graphe social |
| `social` | Interactions sociales (Like, Follow, Feed) |
| `notifications` | Droit d'envoyer des notifications |
| `bluetooth` | Accès Bluetooth |

## Flux d'approbation

1.  **Téléchargement** : L'utilisateur télécharge l'app depuis le Store.
2.  **Lancement** : Au premier lancement, Ondes Core détecte les permissions requises dans le manifest.
3.  **Consentement** : Une modale système (Glassmorphism UI) liste les permissions demandées.
    *   **Accepter** : Les permissions sont stockées de manière persistante et l'app se lance.
    *   **Refuser** : Le lancement est annulé.
4.  **Exécution** : Lors des appels API (ex: `Ondes.Device.getGPSPosition()`), le Bridge vérifie l'autorisation.

## Bonnes pratiques

*   **Minimisez les demandes** : Ne demandez pas `location` si vous n'affichez pas de carte.
*   **Gérez les erreurs** : Même si la permission est dans le manifest, l'utilisateur peut la révoquer dans les paramètres du système OS (iOS/Android) pour l'application Ondes Core elle-même.
