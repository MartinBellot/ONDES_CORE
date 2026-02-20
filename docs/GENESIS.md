# GENESIS — AI Mini-App Creator

## Overview

**GENESIS** is the AI-powered creation subsystem of ONDES CORE. It allows any user to describe a Mini-App in natural language and receive a fully functional, single-file HTML/JS/CSS application that runs natively inside the ONDES WebView — with complete access to the SDK v3.0 Bridge.

GENESIS is **monetised**: every user has a monthly creation quota enforced server-side before any LLM call. Upgrades and credit packs are handled through Stripe Checkout, with subscriptions managed via the Stripe Customer Portal.

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
│  + GenesisQuotaBadge     │  AppBar badge — remaining creations
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
             ▼  ① quota check (GenesisQuota.can_create())
┌─────────────────────────┐
│  GenesisQuota            │  models.py — per-user plan + counter
│  FREE: 5/mo  PRO: 50/mo  │  → HTTP 402 if quota exceeded
└────────────┬────────────┘
             │  ② LLM call (only if quota OK)
             ▼
┌─────────────────────────┐
│  GenesisAgent            │  services.py
│  (Anthropic Claude)      │
└────────────┬────────────┘
             │  System Prompt + conversation history
             ▼
┌─────────────────────────┐
│  Claude claude-sonnet-4-5│
│  (LLM)                   │
└────────────┬────────────┘
             │  raw HTML string
             ▼
┌─────────────────────────┐   ③ quota.consume_creation()
│  ProjectVersion          │  ← called AFTER html_code is persisted
│  html_code (TextField)   │
└────────────┬────────────┘
             │  response includes project + quota snapshot
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

GenesisQuota            (one per user — created on first access)
  ├── user              OneToOneField → auth.User
  ├── plan              'free' | 'pro'
  ├── creations_this_month  PositiveIntegerField (reset every 1st UTC)
  ├── month_reset_date  DateField
  ├── extra_credits     PositiveIntegerField  (pay-as-you-go)
  ├── stripe_customer_id     str (blank until first Checkout)
  ├── stripe_subscription_id str
  ├── subscription_period    'monthly' | 'yearly' | ''
  ├── subscription_end_date  DateTimeField (nullable)
  └── updated_at
```

### Quota business rules

| Plan | Creations / month | Iterations | Price |
|------|:-----------------:|:----------:|-------|
| FREE | 5 | ∞ | 0 € |
| PRO | 50 | ∞ | 7,99 €/mo · 59,99 €/yr |
| Pay-as-you-go | +1 per credit | — | 1,99 € / pack of 10 |

- Counter resets on the **1st of each month UTC** (lazy — checked on next request).
- **Iterations** (`/iterate/`) and **auto-fixes** (`/report_error/`) are **always free** — they never touch the quota.
- Quota is **checked before** the LLM call and **consumed after** the HTML is saved — so a failed generation never costs a credit.
- If a user has exhausted their monthly quota but owns extra credits, credits are deducted first.

---

## API Endpoints

### Core

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

### Monetisation

| Method | URL | Auth | Description |
|--------|-----|------|-------------|
| `GET`  | `/api/genesis/quota/` | Token | Current user's quota snapshot |
| `POST` | `/api/genesis/checkout/` | Token | Create Stripe Checkout session |
| `POST` | `/api/genesis/portal/` | Token | Open Stripe Customer Portal |
| `POST` | `/api/genesis/stripe/webhook/` | — (CSRF-exempt) | Stripe webhook handler |

### `POST /api/genesis/create/`

```json
{
  "prompt": "Une app météo avec animation de pluie et dégradé de couleur selon la météo",
  "title": "Météo App"   // optional
}
```

**Response (201)** — `GenesisProject` with `current_version.html_code`, `conversation`, and a `quota` field reflecting the updated state.

**Response (402)** — quota exceeded:

```json
{
  "error": "quota_exceeded",
  "message": "Tu as atteint ta limite de 5 créations ce mois-ci.",
  "plan": "free",
  "monthly_limit": 5,
  "remaining_creations": 0,
  "quota": { ... }
}
```

### `POST /api/genesis/{id}/iterate/`

```json
{ "feedback": "Change le fond en violet néon, ajoute un bouton pour partager sur le feed" }
```

Response includes a `quota` field. Iterations never consume quota.

### `POST /api/genesis/{id}/save_edit/`

Persists a hand-edited HTML as a new version. Intended for developer power-users.

```json
{
  "html_code": "<!DOCTYPE html>...",
  "description": "Correction manuelle du layout" // optional
}
```

**Response** — updated `GenesisProject` (same shape as other write endpoints).

### `GET /api/genesis/quota/`

Returns the current user's quota without making any change.

```json
{
  "plan": "free",
  "creations_this_month": 3,
  "monthly_limit": 5,
  "extra_credits": 0,
  "remaining_creations": 2,
  "month_reset_date": "2026-02-01",
  "subscription_period": "",
  "subscription_end_date": null
}
```

### `POST /api/genesis/checkout/`

Creates a Stripe Checkout session. Pass one of the three price IDs configured in `.env`.

```json
{
  "price_id": "price_xxx",
  "success_url": "https://ondes.app/genesis/success?session_id={CHECKOUT_SESSION_ID}",
  "cancel_url": "https://ondes.app/genesis/cancel"
}
```

```json
{ "checkout_url": "https://checkout.stripe.com/pay/cs_test_..." }
```

Mode is automatically set to `subscription` for PRO plans and `payment` for credit packs.

### `POST /api/genesis/portal/`

Opens the Stripe Customer Portal for the authenticated user.

```json
{ "return_url": "https://ondes.app/genesis" }
```

```json
{ "portal_url": "https://billing.stripe.com/p/session/..." }
```

### `POST /api/genesis/stripe/webhook/`

CSRF-exempt. Verified against `STRIPE_WEBHOOK_SECRET`. Handles:

| Event | Effect |
|-------|--------|
| `checkout.session.completed` | Sets `plan = pro` or adds 10 extra credits |
| `customer.subscription.deleted` | Downgrades to `free` |
| `invoice.payment_failed` | Downgrades to `free` |
| `customer.subscription.updated` | Records `subscription_end_date` if cancelled at period end |

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

## Monetisation — Flutter UI

### GenesisQuotaBadge

A compact widget displayed in the AppBar of both `GenesisScreen` and `GenesisWorkspace`. It shows the number of remaining creations for the current month with colour-coded urgency:

| Remaining | Colour |
|:---------:|--------|
| > 3 | Green `#00E676` |
| 1–3 | Orange `#FF9500` |
| 0 | Red `#FF2D55` |

A bolt icon turns purple for PRO users. Tapping the badge opens `GenesisPricingScreen` as a bottom sheet.

```dart
// Opened programmatically (e.g. from a 402 error):
GenesisQuotaBadge.openSheet(context, _quota);
```

### GenesisPricingScreen

A full dark-themed modal screen with a galactic animated header. Sections:

1. **Plan toggle** — switch between monthly and yearly pricing.
2. **FREE card** — 5 créations/mois, disabled CTA if already on free.
3. **PRO card** — animated rainbow-glow border, gradient CTA button, adapts price to toggle state.
4. **Credits card** — pay-as-you-go pack of 10 at 1,99 €.
5. **Why PRO?** — 2×2 feature grid.
6. **FAQ** — 3 glassmorphism `ExpansionTile` entries.
7. **Footer** — "Gérer mon abonnement" opens the Stripe Customer Portal (only visible for PRO users).

All purchase buttons show a `CircularProgressIndicator` while the Stripe Checkout URL is being fetched, then open the URL in the system browser via `url_launcher`.

### 402 error handling in GenesisWorkspace

When `/create/` returns HTTP 402 the workspace:
1. Parses the `quota` field from the error body and updates `_quota` state.
2. Displays the error message in the chat bubble.
3. Automatically opens `GenesisPricingScreen` as a bottom sheet.

```
User sends prompt
      │
      ▼  POST /api/genesis/create/
      │
      ├─ 201 OK → update project + quota badge
      │
      └─ 402 Quota exceeded
             │
             ▼  parse 'quota' from response body
             GenesisQuotaBadge.openSheet(context, _quota)
             → GenesisPricingScreen shown automatically
```

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
# 1. Install dependencies
pip install anthropic stripe

# 2. Add to .env
ANTHROPIC_API_KEY=sk-ant-...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRO_MONTHLY_PRICE_ID=price_...
STRIPE_PRO_YEARLY_PRICE_ID=price_...
STRIPE_CREDIT_PACK_PRICE_ID=price_...

# 3. Migrate
python manage.py migrate genesis

# 4. Run
python manage.py runserver

# 5. (dev) Forward Stripe webhooks to localhost
stripe listen --forward-to localhost:8000/api/genesis/stripe/webhook/
```

> **Stripe Products to create in the dashboard:**
> - PRO Monthly — recurring, 7,99 €/mo
> - PRO Yearly — recurring, 59,99 €/yr
> - Credit Pack — one-time payment, 1,99 € (10 credits per purchase)
>
> Copy each `price_xxx` ID into `.env`.

### Flutter

No additional packages required — uses existing `dio`, `flutter_inappwebview`, and `url_launcher` dependencies.

The `url_launcher` package is used by `GenesisPricingScreen` to open Stripe Checkout and the Customer Portal in the system browser.

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
├── admin.py           ← registers GenesisProject, GenesisQuota
├── models.py          ← GenesisProject, ProjectVersion, ConversationTurn, GenesisQuota
├── serializers.py     ← ProjectVersionListSerializer + GenesisQuotaSerializer
├── services.py        ← GenesisAgent (LLM wrapper — do not modify)
├── views.py           ← all REST endpoints + Stripe views + webhook
├── urls.py
└── migrations/
    ├── 0001_initial.py
    └── 0002_genesisquota.py

lib/
├── core/services/
│   └── genesis_service.dart    ← Dart HTTP client, all models incl. GenesisQuota
└── ui/genesis/
    ├── genesis_screen.dart         ← Project list + quota badge
    ├── genesis_workspace.dart      ← WebView + Chat + Version history + Code editor
    ├── genesis_quota_widget.dart   ← GenesisQuotaBadge (AppBar widget)
    └── genesis_pricing_screen.dart ← Pricing modal (plans + credits + FAQ)
```
