# GENESIS — AI Mini-App Creator

## Overview

**GENESIS** is the AI-powered creation subsystem of ONDES CORE. It allows any user to describe a Mini-App in natural language and receive a fully functional, single-file HTML/JS/CSS application that runs natively inside the ONDES WebView — with complete access to the SDK v3.0 Bridge.

---

## Architecture Overview

```
User (Flutter UI)
        │
        │  "Crée une app météo avec animation de pluie"
        ▼
┌─────────────────────────┐
│  GenesisWorkspace        │  Flutter screen
│  (Chat + WebView)        │
└────────────┬────────────┘
             │  POST /api/genesis/create/
             │  POST /api/genesis/{id}/iterate/
             │  POST /api/genesis/{id}/report_error/
             ▼
┌─────────────────────────┐
│  Django API              │
│  genesis.views           │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  GenesisAgent            │  services.py
│  (Anthropic Claude)      │
└────────────┬────────────┘
             │  LLM call with System Prompt + history
             ▼
┌─────────────────────────┐
│  Claude claude-sonnet-4-5         │
│  (LLM)                   │
└────────────┬────────────┘
             │  raw HTML string
             ▼
┌─────────────────────────┐
│  ProjectVersion          │  models.py — persisted
│  html_code (TextField)   │
└────────────┬────────────┘
             │  returned in API response
             ▼
┌─────────────────────────┐
│  InAppWebView (Flutter)  │
│  loadData(html)          │
│  + Bridge injection      │
│  + Error capture JS      │
└─────────────────────────┘
```

---

## Data Model

```
GenesisProject          (one per AI-created app)
  ├── id                UUID primary key
  ├── user              FK → auth.User
  ├── title             str
  ├── is_deployed       bool  (toggled by /deploy/)
  ├── created_at
  └── updated_at

ProjectVersion          (immutable snapshot per iteration)
  ├── project           FK → GenesisProject
  ├── version_number    int   (1, 2, 3 …)
  ├── html_code         TextField
  └── change_description str

ConversationTurn        (full history for context window)
  ├── project           FK → GenesisProject
  ├── role              'user' | 'assistant' | 'system'
  ├── content           str
  └── timestamp
```

---

## API Endpoints

| Method | URL | Description |
|--------|-----|-------------|
| `GET`  | `/api/genesis/` | List current user's projects |
| `POST` | `/api/genesis/create/` | Create project from first prompt |
| `GET`  | `/api/genesis/{id}/` | Fetch project detail (incl. version history) |
| `DELETE` | `/api/genesis/{id}/` | Delete project |
| `POST` | `/api/genesis/{id}/iterate/` | Request a code change |
| `POST` | `/api/genesis/{id}/report_error/` | Auto-fix a JS error |
| `POST` | `/api/genesis/{id}/deploy/` | Mark version as production |
| `GET`  | `/api/genesis/{id}/versions/{version_id}/` | Fetch one version's full HTML |
| `POST` | `/api/genesis/{id}/save_edit/` | Save a manually-edited HTML as new version |

### `POST /api/genesis/create/`

```json
{
  "prompt": "Une app météo avec animation de pluie et dégradé de couleur selon la météo",
  "title": "Météo App"   // optional
}
```

**Response** — `GenesisProject` with `current_version.html_code` and `conversation`.

### `POST /api/genesis/{id}/iterate/`

```json
{ "feedback": "Change le fond en violet néon, ajoute un bouton pour partager sur le feed" }
```

### `POST /api/genesis/{id}/save_edit/`

Persists a hand-edited HTML as a new version. Intended for developer power-users.

```json
{
  "html_code": "<!DOCTYPE html>...",
  "description": "Correction manuelle du layout" // optional
}
```

**Response** — updated `GenesisProject` (same shape as other write endpoints).

---

## Version History

Every AI-generated (or manually edited) snapshot is stored as a `ProjectVersion` row. Versions are numbered sequentially starting from 1. The `current_version` field of a project always points to the highest version number.

The `GenesisProjectDetail` response now includes a `versions` array (lightweight — no `html_code`) alongside `current_version` (full, with `html_code`). Fetching the HTML of an arbitrary historical version requires a separate call to `GET /api/genesis/{id}/versions/{version_id}/`.

### Flutter UX

A **history icon button** (🕐) appears in the `GenesisWorkspace` AppBar whenever the project has at least one version. Tapping it opens a bottom sheet listing all versions in descending order:

- The **current version** is highlighted with a gradient badge and an `actuelle` chip.
- Tapping any **past version** fetches its HTML and loads it in the WebView.
- A **purple banner** overlays the top of the preview pane to signal that a historical snapshot is being displayed. It shows the version number, description, and two actions:
  - **Restaurer** — saves the viewed HTML as a new version and returns to live state.
  - **✕** — dismisses the preview and reloads the current version.

---

## HTML Code Editor

A subtle developer feature — accessible via the **`</>`** icon button in the AppBar (visible when a project has generated code).

Opens a full-height `DraggableScrollableSheet` containing:

- An optional **description field** (e.g. "Fix layout du header").
- A **monospace code editor** (`TextField`) pre-filled with the HTML currently displayed in the WebView (live version _or_ historical preview).
- A **Sauvegarder** button that calls `POST /api/genesis/{id}/save_edit/`, creates a new version, and reloads the WebView.

This allows developers to:
- Make precise one-line corrections without going through the LLM.
- Inject custom scripts or styles.
- Restore and tweak a historical version in a single workflow.

---

## Conversation Flow (LLM context window)

Every call to the LLM includes:

1. **System Prompt** — `GENESIS_SYSTEM_PROMPT` (immutable, defined in `services.py`).
2. **Message history** — all past `ConversationTurn` rows (role `user` / `assistant`) for the project, ordered by timestamp.
3. **New user message** — either the initial prompt, a feedback request, or an error report with the current HTML embedded.

This gives GENESIS full context of every past iteration when generating new code.

---

## System Prompt (exact)

> Tu es GENESIS, l'Architecte IA d'ONDES CORE.  
> Ta tâche : Générer une Mini-App (HTML/JS/CSS) autonome en un seul fichier.
>
> **RÈGLES TECHNIQUES STRICTES :**
> 1. **Format :** Un seul fichier HTML. CSS dans `<style>`, JS dans `<script>`. Pas de CDN externes sauf si indispensable (préférer le CSS pur).
> 2. **Initialisation :** Attends l'événement `document.addEventListener('OndesReady', ...)` avant d'utiliser le SDK.
> 3. **SDK ONDES v3.0 (OBLIGATOIRE) :** Utilise `window.Ondes`. Modules disponibles : UI, Device, Storage, Social, Chat, Websocket, UDP.
> 4. **Design :** Style 'Cyberpunk / Glassmorphism'. Fond sombre (#121212), textes néons, éléments translucides.
> 5. **Gestion d'Erreur :** `try...catch` global → `Ondes.UI.showToast` en cas d'erreur.
>
> **SORTIE :** Renvoie UNIQUEMENT le code HTML brut. Pas de markdown.

---

## Flutter Integration

### WebView HTML loading

Generated HTML is loaded via `InAppWebView.loadData()` (data URI) to isolate the app from any origin. Two JS scripts are injected on `onLoadStop`:

1. **`ondesBridgeJs`** — the full Ondes SDK Bridge (`window.Ondes`).  
2. **`_errorCaptureJs`** — installs `window.onerror` + `unhandledrejection` listeners that forward errors to Flutter via a named JS handler (`Genesis.reportError`).

### Error auto-fix loop

```
JS runtime error
      │
      ▼  (via window.onerror → JS handler)
Flutter: GenesisWorkspace._handleError()
      │
      ▼  POST /api/genesis/{id}/report_error/
Django: GenesisReportErrorView
      │
      ▼  GenesisAgent.fix_error(current_html, history, error_msg)
Claude: returns corrected HTML
      │
      ▼  new ProjectVersion saved
Flutter: WebView reloaded with fixed HTML
```

---

## Setup

### Backend

```bash
# 1. Install anthropic SDK
pip install anthropic

# 2. Add to .env
ANTHROPIC_API_KEY=sk-ant-...

# 3. Migrate
python manage.py migrate genesis

# 4. Run
python manage.py runserver
```

### Flutter

No additional packages required — uses existing `dio` and `flutter_inappwebview` dependencies.

Navigate to GENESIS from anywhere in the app:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const GenesisScreen(),
));
```

Or open directly in creation mode:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const GenesisWorkspace(),
  fullscreenDialog: true,
));
```

---

## File Structure

```
api/genesis/
├── __init__.py
├── apps.py
├── admin.py
├── models.py          ← GenesisProject, ProjectVersion, ConversationTurn
├── serializers.py     ← ProjectVersionListSerializer (no html_code) + full
├── services.py        ← GenesisAgent (LLM wrapper)
├── views.py           ← REST endpoints incl. VersionDetail + SaveEdit
├── urls.py
└── migrations/
    └── 0001_initial.py

lib/
├── core/services/
│   └── genesis_service.dart    ← Dart HTTP client + VersionSummary model
└── ui/genesis/
    ├── genesis_screen.dart     ← Project list
    └── genesis_workspace.dart  ← WebView + Chat + Version history + Code editor
```
