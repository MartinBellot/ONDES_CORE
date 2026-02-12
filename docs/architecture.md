# 🏛️ Architecture du projet

Ondes Core repose sur une architecture hybride combinant un shell natif Flutter et des mini-apps web, le tout supporté par un backend Django robuste.

## Diagramme d'architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ONDES CORE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────────────────────────────┐     │
│  │  Mini-App   │    │          Flutter App                │     │
│  │  (WebView)  │◄──►│  ┌─────────────────────────────┐    │     │
│  │             │    │  │      Bridge Controller      │    │     │
│  │  HTML/JS/   │    │  ├─────────────────────────────┤    │     │
│  │    CSS      │    │  │ ┌─────┐ ┌─────┐ ┌────────┐  │    │     │
│  └─────────────┘    │  │ │ UI  │ │User │ │ Device │  │    │     │
│        │            │  │ └─────┘ └─────┘ └────────┘  │    │     │
│        │            │  │ ┌─────┐ ┌─────┐ ┌────────┐  │    │     │
│        ▼            │  │ │Store│ │ App │ │Friends │  │    │     │
│  window.Ondes       │  │ └─────┘ └─────┘ └────────┘  │    │     │
│                     │  │ ┌────────────────────────┐  │    │     │
│                     │  │ │        Social          │  │    │     │
│                     │  │ └────────────────────────┘  │    │     │
│                     │  └─────────────────────────────┘    │     │
│                     └─────────────────────────────────────┘     │
│                                      │                          │
│                                      ▼                          │
│                     ┌─────────────────────────────────────┐     │
│                     │          Django API                 │     │
│                     │  ┌─────────┐    ┌─────────────┐     │     │
│                     │  │  Store  │    │   Friends   │     │     │
│                     │  │  (apps) │    │ (relations) │     │     │
│                     │  └─────────┘    └─────────────┘     │     │
│                     │  ┌─────────────────────────────┐    │     │
│                     │  │   Social (posts, feed,      │    │     │
│                     │  │   stories, media, HLS)      │    │     │
│                     │  └─────────────────────────────┘    │     │
│                     └─────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Stack technique détaillée

| Couche | Technologie | Rôle |
|--------|-------------|------|
| **Frontend natif** | **Flutter** | Sert de "coquille" (Shell). Gère le WebView, l'interface native (barre de navigation, modales) et les appels systèmes via les Platform Channels. |
| **Mini-Apps** | **HTML/CSS/JS** | Applications développées par les utilisateurs. Elles tournent dans le WebView. |
| **Bridge** | **JavaScript Injection** | Mécanisme de communication bidirectionnel entre le JavaScript de la WebView et le Dart de Flutter. |
| **Backend** | **Django REST Framework** | API centrale. Gère l'authentification, le stockage des apps (.zip), les relations sociales et les médias. |
| **Base de données** | **SQLite** (Dev) | Stocke les données utilisateurs, les métadonnées des apps et le graphe social. |

## ⚡️ Optimisations de Performance

### Cold Start & WebView Pool

Pour garantir une expérience fluide (60fps) et éliminer le délai d'initialisation des WebViews (200-500ms), Ondes Core implémente un système de **"WebView Pool"**.

*   **Problème** : Instancier un moteur de navigateur (`WKWebView` / `Android WebView`) est coûteux. Le faire à l'ouverture de chaque mini-app crée un écran blanc perceptible (Cold Start).
*   **Solution** :
    *   Le système maintient des instances `HeadlessInAppWebView` "chaudes" en arrière-plan (`lib/core/services/webview_pool_service.dart`).
    *   Ces instances chargent préventivement le contexte (Bridge JS).
    *   Au clic utilisateur, une vue préchauffée est immédiatement attachée à l'interface via l'API `KeepAlive`.
    *   À la fermeture, la vue est recyclée et le pool est re-complété automatiquement.
