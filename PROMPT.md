# PROMPT D'IMPLÉMENTATION — Monétisation GENESIS (Quotas + Stripe + Paywall Screen)

Tu es un expert Flutter (3.x / Dart 3) et Django 5 REST Framework.
Tu vas implémenter le système de monétisation complet de GENESIS, le créateur de Mini-Apps IA d'une app Flutter appelée **ONDES CORE**.

---

## CONTEXTE CODEBASE EXISTANT

### BACKEND (Django 5.0.1 + DRF 3.14)

1. **`api/store/models.py`** — `UserProfile` (OneToOneField → User) avec `avatar` et `bio` uniquement.
2. **`api/genesis/models.py`** — `GenesisProject`, `ProjectVersion`, `ConversationTurn`. Aucune notion de quota.
3. **`api/genesis/views.py`** — `GenesisCreateView`, `GenesisIterateView`, `GenesisReportErrorView`, `GenesisDeployView`, etc. Auth via Token DRF (`IsAuthenticated`). Aucune vérification de quota.
4. **`api/genesis/services.py`** — `GenesisAgent` wrappant Claude Sonnet. MAX_TOKENS = 50 000. Streaming async. Ne pas toucher.
5. **`api/genesis/urls.py`** — routes genesis sous `api/genesis/`.
6. **`api/ondes_backend/urls.py`** — inclut genesis sous `path('api/genesis/', include('genesis.urls'))`.
7. **`api/requirements.txt`** — `Django==5.0.1`, `djangorestframework==3.14.0`, `python-decouple==3.8`, `anthropic>=0.40.0`, `gunicorn==21.2.0`. **Stripe n'est pas encore installé.**

### FLUTTER

8. **`lib/core/services/auth_service.dart`** — singleton. `_currentUser` Map chargée via `fetchProfile()` → GET `/api/auth/profile/`. Appelée au login/register/init.
9. **`lib/core/services/genesis_service.dart`** — singleton. Méthodes : `listProjects()`, `createProject()`, `getProject()`, `iterate()`, `reportError()`, `deploy()`, `getVersion()`, `saveEdit()`, `deleteProject()`.
10. **`lib/ui/genesis/genesis_workspace.dart`** — screen principal (1313 lignes). `_handleSend()` appelle `createProject()` ou `iterate()`. Gère les erreurs via `setState(() => _errorMessage = ...)`.
11. **`lib/ui/genesis/genesis_screen.dart`** — liste les projets, bouton "Nouvelle App".
12. **`lib/ui/store/store_screen.dart`** — store ultra-complet avec `AnimationController` multiples, glassmorphism, fond `#0A0A0A`, couleurs : `_accentPurple = Color(0xFFAF52DE)`, `_highlightColor = Color(0xFF007AFF)`, `_accentTeal = Color(0xFF5AC8FA)`.
13. **`pubspec.yaml`** — packages disponibles : `flutter`, `dio ^5.7.0`, `provider ^6.1.2`, `shared_preferences ^2.3.3`, `flutter_secure_storage ^10.0.0`, `url_launcher ^6.3.2`, `google_fonts ^8.0.2`. **Pas de stripe_flutter, pas de in_app_purchase.**

---

## RÈGLES MÉTIER

| Plan | Créations/mois | Itérations | Prix |
|---|---|---|---|
| FREE | 5 | Illimitées | 0 € |
| PRO | 50 | Illimitées | 7,99 €/mois ou 59,99 €/an |
| Pay-as-you-go | +1 par crédit | — | 0,20 €/crédit (pack de 10 = 1,99 €) |

- Le compteur de créations se **reset le 1er de chaque mois UTC**.
- Les itérations (`/iterate/`) et corrections d'erreurs (`/report_error/`) sont **toujours gratuites**.
- La vérification quota se fait **AVANT** l'appel LLM.
- `consume_creation()` se fait **APRÈS** sauvegarde du HTML en DB.

---

## PARTIE 1 — BACKEND DJANGO

### 1.1 Installer Stripe

```bash
pip install stripe
```

Ajouter dans `requirements.txt` :
```
stripe>=8.0.0
```

Ajouter dans `api/ondes_backend/settings.py` (via decouple) :
```python
STRIPE_SECRET_KEY = config('STRIPE_SECRET_KEY', default='')
STRIPE_WEBHOOK_SECRET = config('STRIPE_WEBHOOK_SECRET', default='')
STRIPE_PRO_MONTHLY_PRICE_ID = config('STRIPE_PRO_MONTHLY_PRICE_ID', default='')
STRIPE_PRO_YEARLY_PRICE_ID = config('STRIPE_PRO_YEARLY_PRICE_ID', default='')
STRIPE_CREDIT_PACK_PRICE_ID = config('STRIPE_CREDIT_PACK_PRICE_ID', default='')
```

Ajouter dans `.env` (et `.env.example`) :
```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRO_MONTHLY_PRICE_ID=price_...
STRIPE_PRO_YEARLY_PRICE_ID=price_...
STRIPE_CREDIT_PACK_PRICE_ID=price_...
```

---

### 1.2 Nouveau modèle dans `api/genesis/models.py`

Ajouter en tête du fichier :
```python
from datetime import date
from django.contrib.auth.models import User
```

Ajouter à la fin du fichier (ne pas toucher aux modèles existants) :

```python
class GenesisQuota(models.Model):
    """Tracks monthly creation quota, plan, and Stripe subscription for each user."""

    PLAN_FREE = 'free'
    PLAN_PRO = 'pro'
    PLAN_CHOICES = [('free', 'Free'), ('pro', 'Pro')]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='genesis_quota')
    plan = models.CharField(max_length=10, choices=PLAN_CHOICES, default=PLAN_FREE)

    # Monthly counter — reset automatically when month changes
    creations_this_month = models.PositiveIntegerField(default=0)
    month_reset_date = models.DateField(default=date.today)

    # Pay-as-you-go credits (each credit = 1 extra creation beyond quota)
    extra_credits = models.PositiveIntegerField(default=0)

    # Stripe
    stripe_customer_id = models.CharField(max_length=64, blank=True)
    stripe_subscription_id = models.CharField(max_length=64, blank=True)
    subscription_period = models.CharField(
        max_length=10,
        choices=[('monthly', 'Monthly'), ('yearly', 'Yearly'), ('', 'None')],
        blank=True,
        default='',
    )
    subscription_end_date = models.DateTimeField(null=True, blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Genesis Quota"

    @property
    def monthly_limit(self) -> int:
        return 50 if self.plan == self.PLAN_PRO else 5

    def _refresh_month(self):
        today = date.today()
        if today.year > self.month_reset_date.year or today.month > self.month_reset_date.month:
            self.creations_this_month = 0
            self.month_reset_date = today

    def can_create(self) -> bool:
        self._refresh_month()
        return self.creations_this_month < self.monthly_limit or self.extra_credits > 0

    def consume_creation(self):
        """Increments counter or deducts an extra credit. Saves immediately."""
        self._refresh_month()
        if self.creations_this_month < self.monthly_limit:
            self.creations_this_month += 1
        elif self.extra_credits > 0:
            self.extra_credits -= 1
            self.creations_this_month += 1
        else:
            raise ValueError("Quota épuisé")
        self.save()

    @property
    def remaining_creations(self) -> int:
        self._refresh_month()
        return max(0, self.monthly_limit - self.creations_this_month) + self.extra_credits

    def __str__(self):
        return f"{self.user.username} [{self.plan}] {self.creations_this_month}/{self.monthly_limit}"
```

---

### 1.3 Migration

Créer `api/genesis/migrations/0002_genesisquota.py` (générée via `python manage.py makemigrations genesis`).

---

### 1.4 Admin dans `api/genesis/admin.py`

```python
from django.contrib import admin
from .models import GenesisProject, ProjectVersion, ConversationTurn, GenesisQuota

@admin.register(GenesisQuota)
class GenesisQuotaAdmin(admin.ModelAdmin):
    list_display = [
        'user', 'plan', 'creations_this_month', 'monthly_limit',
        'extra_credits', 'month_reset_date', 'stripe_customer_id', 'updated_at',
    ]
    list_editable = ['plan', 'extra_credits']
    search_fields = ['user__username', 'stripe_customer_id']
    readonly_fields = ['stripe_customer_id', 'stripe_subscription_id', 'updated_at']
```

---

### 1.5 Serializers dans `api/genesis/serializers.py`

Ajouter à la fin :

```python
class GenesisQuotaSerializer(serializers.ModelSerializer):
    monthly_limit = serializers.IntegerField(read_only=True)
    remaining_creations = serializers.IntegerField(read_only=True)

    class Meta:
        model = GenesisQuota
        fields = [
            'plan', 'creations_this_month', 'monthly_limit',
            'extra_credits', 'remaining_creations', 'month_reset_date',
            'subscription_period', 'subscription_end_date',
        ]
```

---

### 1.6 Vues dans `api/genesis/views.py`

#### Imports à ajouter en tête :
```python
import stripe
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.http import HttpResponse
from django.utils import timezone
from .models import GenesisQuota
from .serializers import GenesisQuotaSerializer

stripe.api_key = settings.STRIPE_SECRET_KEY
```

#### Helper à ajouter après les imports :
```python
def _get_or_create_quota(user):
    quota, _ = GenesisQuota.objects.get_or_create(user=user)
    return quota

def _quota_response_data(project, user):
    """Helper to add quota info to any project response."""
    data = GenesisProjectDetailSerializer(project).data
    data['quota'] = GenesisQuotaSerializer(_get_or_create_quota(user)).data
    return data
```

#### Modifier `GenesisCreateView.post()` :

AVANT la création du projet, ajouter :
```python
quota = _get_or_create_quota(request.user)
if not quota.can_create():
    return Response(
        {
            'error': 'quota_exceeded',
            'message': f"Tu as atteint ta limite de {quota.monthly_limit} créations ce mois-ci.",
            'plan': quota.plan,
            'monthly_limit': quota.monthly_limit,
            'remaining_creations': quota.remaining_creations,
            'quota': GenesisQuotaSerializer(quota).data,
        },
        status=status.HTTP_402_PAYMENT_REQUIRED,
    )
```

APRÈS `ProjectVersion.objects.create(...)` et `ConversationTurn.objects.create(...)`, ajouter :
```python
try:
    quota.consume_creation()
except ValueError:
    pass  # should not happen — we checked can_create() above
```

Remplacer la ligne `return Response(serializer.data, ...)` par :
```python
return Response(
    _quota_response_data(project, request.user),
    status=status.HTTP_201_CREATED,
)
```

Faire de même dans `GenesisIterateView.post()` pour inclure le quota dans la réponse :
```python
return Response(_quota_response_data(project, request.user))
```

#### Nouvelle vue `GenesisQuotaView` :
```python
class GenesisQuotaView(APIView):
    """GET /api/genesis/quota/"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        quota = _get_or_create_quota(request.user)
        return Response(GenesisQuotaSerializer(quota).data)
```

#### Nouvelle vue `GenesisCheckoutView` (Stripe Checkout) :
```python
class GenesisCheckoutView(APIView):
    """
    POST /api/genesis/checkout/
    Body: { "price_id": "price_xxx", "success_url": "...", "cancel_url": "..." }
    Returns: { "checkout_url": "https://checkout.stripe.com/..." }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        price_id = request.data.get('price_id', '').strip()
        success_url = request.data.get('success_url', '').strip()
        cancel_url = request.data.get('cancel_url', '').strip()

        if not price_id or not success_url or not cancel_url:
            return Response({'error': 'price_id, success_url and cancel_url are required'}, status=400)

        quota = _get_or_create_quota(request.user)

        # Get or create Stripe customer
        if not quota.stripe_customer_id:
            customer = stripe.Customer.create(
                email=request.user.email,
                metadata={'user_id': str(request.user.id), 'username': request.user.username},
            )
            quota.stripe_customer_id = customer.id
            quota.save(update_fields=['stripe_customer_id'])

        try:
            # Determine mode: subscription for Pro plans, payment for credit packs
            pro_price_ids = [
                settings.STRIPE_PRO_MONTHLY_PRICE_ID,
                settings.STRIPE_PRO_YEARLY_PRICE_ID,
            ]
            mode = 'subscription' if price_id in pro_price_ids else 'payment'

            session = stripe.checkout.Session.create(
                customer=quota.stripe_customer_id,
                line_items=[{'price': price_id, 'quantity': 1}],
                mode=mode,
                success_url=success_url,
                cancel_url=cancel_url,
                metadata={
                    'user_id': str(request.user.id),
                    'price_id': price_id,
                },
            )
            return Response({'checkout_url': session.url})
        except stripe.StripeError as e:
            return Response({'error': str(e)}, status=502)
```

#### Nouvelle vue `GenesisPortalView` (Stripe Customer Portal) :
```python
class GenesisPortalView(APIView):
    """
    POST /api/genesis/portal/
    Body: { "return_url": "..." }
    Returns: { "portal_url": "https://billing.stripe.com/..." }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        quota = _get_or_create_quota(request.user)
        if not quota.stripe_customer_id:
            return Response({'error': 'No Stripe customer found'}, status=400)

        return_url = request.data.get('return_url', '')
        try:
            session = stripe.billing_portal.Session.create(
                customer=quota.stripe_customer_id,
                return_url=return_url,
            )
            return Response({'portal_url': session.url})
        except stripe.StripeError as e:
            return Response({'error': str(e)}, status=502)
```

#### Nouvelle vue `GenesisStripeWebhookView` :
```python
@method_decorator(csrf_exempt, name='dispatch')
class GenesisStripeWebhookView(APIView):
    """
    POST /api/genesis/stripe/webhook/
    Handles: checkout.session.completed, customer.subscription.deleted,
             customer.subscription.updated, invoice.payment_failed
    """
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE', '')

        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
            )
        except (ValueError, stripe.SignatureVerificationError):
            return HttpResponse(status=400)

        data = event['data']['object']

        if event['type'] == 'checkout.session.completed':
            user_id = data.get('metadata', {}).get('user_id')
            price_id = data.get('metadata', {}).get('price_id')
            if not user_id:
                return HttpResponse(status=200)

            try:
                from django.contrib.auth.models import User
                user = User.objects.get(id=user_id)
                quota = _get_or_create_quota(user)

                if price_id == settings.STRIPE_PRO_MONTHLY_PRICE_ID:
                    quota.plan = GenesisQuota.PLAN_PRO
                    quota.subscription_period = 'monthly'
                    quota.stripe_subscription_id = data.get('subscription', '')
                elif price_id == settings.STRIPE_PRO_YEARLY_PRICE_ID:
                    quota.plan = GenesisQuota.PLAN_PRO
                    quota.subscription_period = 'yearly'
                    quota.stripe_subscription_id = data.get('subscription', '')
                elif price_id == settings.STRIPE_CREDIT_PACK_PRICE_ID:
                    # Pack of 10 credits
                    quota.extra_credits += 10

                quota.save()
            except Exception:
                pass

        elif event['type'] in ('customer.subscription.deleted', 'invoice.payment_failed'):
            sub_id = data.get('id') or data.get('subscription', '')
            if sub_id:
                GenesisQuota.objects.filter(stripe_subscription_id=sub_id).update(
                    plan=GenesisQuota.PLAN_FREE,
                    stripe_subscription_id='',
                    subscription_period='',
                    subscription_end_date=timezone.now(),
                )

        elif event['type'] == 'customer.subscription.updated':
            sub_id = data.get('id', '')
            cancel_at = data.get('cancel_at_period_end', False)
            if cancel_at:
                import datetime
                end_ts = data.get('current_period_end')
                if end_ts:
                    GenesisQuota.objects.filter(stripe_subscription_id=sub_id).update(
                        subscription_end_date=timezone.datetime.fromtimestamp(end_ts, tz=timezone.utc)
                    )

        return HttpResponse(status=200)
```

---

### 1.7 URLs dans `api/genesis/urls.py`

Importer et ajouter :
```python
from .views import (
    # ... (existing imports) ...
    GenesisQuotaView,
    GenesisCheckoutView,
    GenesisPortalView,
    GenesisStripeWebhookView,
)

urlpatterns = [
    # ... (existing patterns) ...
    path('quota/', GenesisQuotaView.as_view(), name='genesis-quota'),
    path('checkout/', GenesisCheckoutView.as_view(), name='genesis-checkout'),
    path('portal/', GenesisPortalView.as_view(), name='genesis-portal'),
    path('stripe/webhook/', GenesisStripeWebhookView.as_view(), name='genesis-stripe-webhook'),
]
```

---

## PARTIE 2 — FLUTTER

### 2.1 Modèles dans `lib/core/services/genesis_service.dart`

Ajouter avant la classe `GenesisService` :

```dart
class GenesisQuota {
  final String plan;
  final int creationsThisMonth;
  final int monthlyLimit;
  final int extraCredits;
  final int remainingCreations;
  final DateTime monthResetDate;
  final String subscriptionPeriod; // 'monthly' | 'yearly' | ''
  final DateTime? subscriptionEndDate;

  GenesisQuota({
    required this.plan,
    required this.creationsThisMonth,
    required this.monthlyLimit,
    required this.extraCredits,
    required this.remainingCreations,
    required this.monthResetDate,
    this.subscriptionPeriod = '',
    this.subscriptionEndDate,
  });

  factory GenesisQuota.fromJson(Map<String, dynamic> json) {
    return GenesisQuota(
      plan: json['plan'] as String,
      creationsThisMonth: json['creations_this_month'] as int,
      monthlyLimit: json['monthly_limit'] as int,
      extraCredits: json['extra_credits'] as int,
      remainingCreations: json['remaining_creations'] as int,
      monthResetDate: DateTime.parse(json['month_reset_date'] as String),
      subscriptionPeriod: json['subscription_period'] as String? ?? '',
      subscriptionEndDate: json['subscription_end_date'] != null
          ? DateTime.parse(json['subscription_end_date'] as String)
          : null,
    );
  }

  bool get isPro => plan == 'pro';
  bool get canCreate => remainingCreations > 0;
  double get usagePercent =>
      monthlyLimit == 0 ? 1.0 : (creationsThisMonth / monthlyLimit).clamp(0.0, 1.0);
}
```

Modifier la classe `GenesisProject` pour ajouter le champ `quota` :
```dart
// Ajouter le champ :
final GenesisQuota? quota;

// Dans le constructeur nommé, ajouter :
this.quota,

// Dans fromJson, ajouter :
quota: json['quota'] != null
    ? GenesisQuota.fromJson(json['quota'] as Map<String, dynamic>)
    : null,
```

Ajouter dans `GenesisService` :
```dart
Future<GenesisQuota> getQuota() async {
  final response = await _dio.get(
    '$_base/quota/',
    options: Options(headers: _headers),
  );
  return GenesisQuota.fromJson(response.data as Map<String, dynamic>);
}

/// Opens Stripe Checkout and returns the checkout URL.
/// [priceId] — one of the STRIPE_*_PRICE_ID values.
Future<String> getCheckoutUrl({
  required String priceId,
  required String successUrl,
  required String cancelUrl,
}) async {
  final response = await _dio.post(
    '$_base/checkout/',
    data: {
      'price_id': priceId,
      'success_url': successUrl,
      'cancel_url': cancelUrl,
    },
    options: Options(headers: _headers),
  );
  return response.data['checkout_url'] as String;
}

/// Opens the Stripe Customer Portal and returns the portal URL.
Future<String> getPortalUrl({required String returnUrl}) async {
  final response = await _dio.post(
    '$_base/portal/',
    data: {'return_url': returnUrl},
    options: Options(headers: _headers),
  );
  return response.data['portal_url'] as String;
}
```

---

### 2.2 Nouveau fichier `lib/ui/genesis/genesis_pricing_screen.dart`

Créer un **StatefulWidget** `GenesisPricingScreen` qui prend un `GenesisQuota? currentQuota` en paramètre optionnel.

C'est un **écran complet ultra-moderne** inspiré de l'esthétique de `store_screen.dart` mais avec l'identité visuelle GENESIS (violet/cyan).

#### Design de l'écran :

**Fond et structure :**
- `Scaffold` avec fond `Color(0xFF06040F)` (légèrement plus violet que le store).
- `CustomScrollView` avec un `SliverAppBar` flexible.
- Le `SliverAppBar` en `expandedHeight: 220` affiche :
  - Un fond avec `AnimatedBuilder` sur un `AnimationController` qui fait tourner lentement un dégradé radial (effet galactique).
  - Le titre "GENESIS PRO" en grand avec `ShaderMask` gradient violet→cyan et `letterSpacing: 4`.
  - Sous le titre, le plan actuel de l'utilisateur en badge glassmorphism.

**Section "Offres" (3 cards) :**

Card 1 — **FREE** :
- Badge gris glassmorphism.
- Prix : "0 €" en grand.
- Liste des features avec icône `Icons.check_circle_outline` : "5 créations/mois", "Itérations illimitées", "1 projet actif".
- Si l'utilisateur est déjà FREE, afficher un bouton grisé "Plan actuel".

Card 2 — **PRO Mensuel** — Mettre en avant avec un effet `border` animé arc-en-ciel (gradient qui tourne, comme un glow).
- Badge "POPULAIRE" en néon violet.
- Prix : "7,99 €" avec "/mois" en petit.
- `AnimatedSwitcher` entre mensuel/annuel via un toggle en haut de la section.
- Liste des features : "50 créations/mois", "Itérations illimitées", "Projets illimités", "Support prioritaire".
- Bouton principal `"Passer à PRO"` avec gradient violet→cyan, hauteur 52, `BorderRadius.circular(16)`, texte en gras.

Card 3 — **Crédits Bonus** (Pay-as-you-go) :
- Badge "FLEXIBLE" en néon cyan.
- Prix : "1,99 €" avec "pack de 10 crédits" en sous-titre.
- Explication : "Chaque crédit = 1 génération. Sans engagement."
- Bouton "Acheter des crédits" avec style outlined violet.

**Section "Pourquoi PRO ?" :**
- 4 blocs de features avec icône + titre + description, affichés en grille 2×2.
  - `Icons.bolt` — "50 générations/mois" — "10× plus que le plan gratuit"
  - `Icons.history` — "Historique illimité" — "Toutes vos versions conservées"
  - `Icons.auto_awesome` — "Apps plus complexes" — "Budget de tokens élargi"
  - `Icons.support_agent` — "Support prioritaire" — "Réponse en moins de 24h"

**Section "FAQ" :**
- 3 `ExpansionTile` glassmorphism :
  - "Puis-je annuler à tout moment ?" → "Oui, depuis votre espace Stripe sans engagement."
  - "Que se passe-t-il si je dépasse mon quota ?" → "Vous pouvez acheter des crédits bonus ou attendre le renouvellement."
  - "Les itérations comptent-elles ?" → "Non, seules les créations initiales consomment votre quota."

**Footer :**
- Lien "Gérer mon abonnement" (ouvre le Customer Portal Stripe via `url_launcher`).
- Mentions légales minimalistes en gris.

#### Logique :

```dart
// State fields:
bool _yearlyToggle = false; // mensuel/annuel toggle
bool _loadingCheckout = false;
String? _errorMessage;

// Stripe price IDs — à récupérer depuis une config ou hardcodés en const :
static const _proMonthlyPriceId = 'price_CHANGE_ME_monthly';
static const _proYearlyPriceId  = 'price_CHANGE_ME_yearly';
static const _creditPackPriceId = 'price_CHANGE_ME_credits';

Future<void> _handlePurchase(String priceId) async {
  setState(() { _loadingCheckout = true; _errorMessage = null; });
  try {
    // Deep-link de retour vers l'app
    const successUrl = 'https://ondes.app/genesis/success?session_id={CHECKOUT_SESSION_ID}';
    const cancelUrl  = 'https://ondes.app/genesis/cancel';

    final url = await GenesisService().getCheckoutUrl(
      priceId: priceId,
      successUrl: successUrl,
      cancelUrl: cancelUrl,
    );
    // Ouvre Stripe Checkout dans le navigateur externe
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    setState(() => _errorMessage = e.toString());
  } finally {
    if (mounted) setState(() => _loadingCheckout = false);
  }
}

Future<void> _handleManageSubscription() async {
  try {
    const returnUrl = 'https://ondes.app/genesis';
    final url = await GenesisService().getPortalUrl(returnUrl: returnUrl);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    // Afficher un SnackBar d'erreur
  }
}
```

---

### 2.3 Nouveau fichier `lib/ui/genesis/genesis_quota_widget.dart`

Créer un `StatelessWidget` `GenesisQuotaBadge` :

```dart
// Paramètre : GenesisQuota quota
// Affiché dans les AppBar de GenesisScreen et GenesisWorkspace

// Apparence :
// - Row(icône + texte) compacte avec padding 6×12
// - Container avec border-radius 20, background glassmorphism (blanc 5% opaque)
// - Icône : Icons.bolt (violet si pro, blanc sinon)
// - Texte : "${quota.remainingCreations} restantes"
//   - Couleur : vert (#00E676) si > 3, orange (#FF9500) si ≤ 3, rouge (#FF2D55) si 0
// - GestureDetector qui ouvre GenesisPricingScreen en modal

// Méthode statique pour usage externe :
static Widget buildUpgradeSheet(BuildContext context, GenesisQuota? quota) {
  // Retourne GenesisPricingScreen(currentQuota: quota) 
  // dans un DraggableScrollableSheet thème sombre
}
```

---

### 2.4 Modifier `lib/ui/genesis/genesis_workspace.dart`

#### Ajouter state :
```dart
GenesisQuota? _quota;
```

#### Dans `initState()` après `_bridge = OndesBridgeController(...)` :
```dart
_loadQuota();
```

#### Ajouter méthode :
```dart
Future<void> _loadQuota() async {
  try {
    final quota = await GenesisService().getQuota();
    if (mounted) setState(() => _quota = quota);
  } catch (_) {}
}
```

#### Dans `_handleSend()`, après la définition de `updated` :
```dart
if (updated.quota != null && mounted) {
  setState(() => _quota = updated.quota);
}
```

#### Dans `_handleSend()`, dans le `catch(e)`, remplacer le setState existant par :
```dart
} catch (e) {
  GenesisIslandService().fail(e.toString());
  if (!mounted) return;

  String errorMsg = e.toString();
  if (e is DioException && e.response?.statusCode == 402) {
    final data = e.response?.data as Map<String, dynamic>?;
    errorMsg = data?['message'] as String? ?? 'Quota de créations épuisé.';
    if (data?['quota'] != null) {
      setState(() => _quota = GenesisQuota.fromJson(data!['quota'] as Map<String, dynamic>));
    }
    _loadQuota();
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => GenesisPricingScreen(currentQuota: _quota),
      );
    }
  }
  setState(() => _errorMessage = errorMsg);
}
```

#### Dans `build()`, dans les `actions:` de l'AppBar, ajouter EN PREMIER :
```dart
if (_quota != null)
  Padding(
    padding: const EdgeInsets.only(right: 4),
    child: GenesisQuotaBadge(quota: _quota!),
  ),
```

---

### 2.5 Modifier `lib/ui/genesis/genesis_screen.dart`

#### Ajouter state :
```dart
GenesisQuota? _quota;
```

#### Modifier `_load()` pour charger quota en parallèle :
```dart
Future<void> _load() async {
  setState(() => _loading = true);
  try {
    final results = await Future.wait([
      GenesisService().listProjects(),
      GenesisService().getQuota(),
    ]);
    _projects = results[0] as List<GenesisProject>;
    _quota = results[1] as GenesisQuota;
  } catch (e) {
    AppLogger.error('GenesisScreen', 'load failed', e);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

#### Dans `build()`, dans les `actions:` de l'AppBar :
```dart
if (_quota != null)
  Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GenesisQuotaBadge(quota: _quota!),
  ),
```

---

## PARTIE 3 — AJOUTS PUBSPEC.YAML

Aucun nouveau package n'est nécessaire. `url_launcher` est déjà dans le pubspec.
Vérifier que l'import `package:url_launcher/url_launcher.dart` est bien disponible.

---

## FICHIERS À CRÉER / MODIFIER

### Créer :
- `api/genesis/migrations/0002_genesisquota.py` ← via `makemigrations`
- `lib/ui/genesis/genesis_pricing_screen.dart` ← écran pricing complet
- `lib/ui/genesis/genesis_quota_widget.dart` ← badge quota AppBar

### Modifier :
- `api/requirements.txt` ← ajouter `stripe>=8.0.0`
- `api/ondes_backend/settings.py` ← ajouter les 5 clés Stripe
- `api/.env` et `.env.example` ← ajouter les variables Stripe
- `api/genesis/models.py` ← ajouter `GenesisQuota`
- `api/genesis/admin.py` ← enregistrer `GenesisQuota`
- `api/genesis/serializers.py` ← ajouter `GenesisQuotaSerializer`
- `api/genesis/views.py` ← quota check + 4 nouvelles vues
- `api/genesis/urls.py` ← 4 nouvelles routes
- `lib/core/services/genesis_service.dart` ← `GenesisQuota` model + 3 méthodes
- `lib/ui/genesis/genesis_workspace.dart` ← state quota + badge + gestion 402
- `lib/ui/genesis/genesis_screen.dart` ← badge quota + chargement parallèle

---

## CONTRAINTES TECHNIQUES

1. Ne pas toucher à `GenesisProject`, `ProjectVersion`, `ConversationTurn`, `GenesisAgent`.
2. La vérification quota → retourner HTTP 402 **AVANT** l'appel LLM.
3. `consume_creation()` → **APRÈS** sauvegarde html_code en DB.
4. Le webhook Stripe est exempt de CSRF (décorateur `@csrf_exempt`).
5. Style Flutter cohérent avec `store_screen.dart` : fond sombre, glassmorphism, gradients. Adapter la palette vers violet/cyan plutôt que le bleu iOS du store.
6. Le bouton PRO sur `GenesisPricingScreen` doit avoir un **glow animé** (bordure gradient tournante) pour attirer l'œil.
7. L'écran pricing doit être dismissable en modal (utilisé depuis `GenesisQuotaBadge` ET depuis la gestion du 402).
8. Gérer les états de chargement sur tous les boutons de paiement avec `CircularProgressIndicator`.
9. Les price IDs Stripe dans le Flutter sont des `const String` en haut du fichier, faciles à changer.
10. Tester le webhook en local avec `stripe listen --forward-to localhost:8000/api/genesis/stripe/webhook/`.
