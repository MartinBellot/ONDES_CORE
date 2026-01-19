# 🖥️ API Backend Django

Le backend de Ondes Core expose une API REST complète. Voici un résumé des modules côté serveur.

## Structure des Applications Django

Le projet est divisé en 3 applications principales :

1.  **`store`** : Gestion du marché d'applications et de l'espace développeur.
2.  **`friends`** : Gestion stricte des relations d'amitié (confirmées).
3.  **`social`** : Réseau social, feed, médias, interactions.

## Endpoints Principaux

### Authentication
- `POST /api/auth/register/` : Inscription.
- `POST /api/auth/login/` : Connexion (retourne un token).

### Store & Studio
- `GET /api/apps/` : Listing public des mini-apps.
- `POST /api/studio/apps/` : Créer une nouvelle app (développeur).
- `POST /api/studio/apps/<id>/versions/` : Uploader un nouveau .zip.

### Social Graph
- `GET /api/friends/` : Liste d'amis.
- `POST /api/social/follow/` : Suivre un utilisateur.

### Content
- `GET /api/social/posts/` : Récupérer le feed.
- `POST /api/social/posts/` : Publier.

## Traitement des Médias

Le backend effectue des traitements lourds en background :

| Type | Traitement effectué |
|------|---------------------|
| **Images** | Redimensionnement (max 1920x1920) et compression JPEG (85%). |
| **Vidéos** | Transcodage FFmpeg vers HLS (HTTP Live Streaming) avec génération de variantes (360p, 480p, 720p, 1080p). |

Cela garantit que le contenu est délivré de manière optimale sur les réseaux mobiles.
