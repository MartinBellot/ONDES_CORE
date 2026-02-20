import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/genesis_service.dart';

// ─── Stripe Price IDs — remplace par les vraies valeurs depuis ton dashboard ─
const _kProMonthlyPriceId = 'price_CHANGE_ME_monthly';
const _kProYearlyPriceId = 'price_CHANGE_ME_yearly';
const _kCreditPackPriceId = 'price_CHANGE_ME_credits';

// ─── Couleurs GENESIS ────────────────────────────────────────────────────────
const _kPurple = Color(0xFFAF52DE);
const _kCyan = Color(0xFF5AC8FA);
const _kBg = Color(0xFF06040F);
const _kSurface = Color(0xFF100C1E);
const _kBorder = Color(0xFF2A1F4A);

class GenesisPricingScreen extends StatefulWidget {
  final GenesisQuota? currentQuota;

  const GenesisPricingScreen({super.key, this.currentQuota});

  @override
  State<GenesisPricingScreen> createState() => _GenesisPricingScreenState();
}

class _GenesisPricingScreenState extends State<GenesisPricingScreen>
    with TickerProviderStateMixin {
  bool _yearlyToggle = false;
  bool _loadingCheckout = false;
  bool _loadingPortal = false;
  String? _errorMessage;

  late AnimationController _bgController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  // ── Stripe actions ────────────────────────────────────────────────────────

  Future<void> _handlePurchase(String priceId) async {
    setState(() {
      _loadingCheckout = true;
      _errorMessage = null;
    });
    try {
      const successUrl =
          'https://ondes.app/genesis/success?session_id={CHECKOUT_SESSION_ID}';
      const cancelUrl = 'https://ondes.app/genesis/cancel';
      final url = await GenesisService().getCheckoutUrl(
        priceId: priceId,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loadingCheckout = false);
    }
  }

  Future<void> _handleManageSubscription() async {
    setState(() => _loadingPortal = true);
    try {
      const returnUrl = 'https://ondes.app/genesis';
      final url = await GenesisService().getPortalUrl(returnUrl: returnUrl);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: const Color(0xFF2D1B4D),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPortal = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isPro => widget.currentQuota?.isPro == true;

  String get _currentPriceId =>
      _yearlyToggle ? _kProYearlyPriceId : _kProMonthlyPriceId;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Scaffold(
        backgroundColor: _kBg,
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildToggle(),
                    const SizedBox(height: 20),
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildFreeCard(),
                    const SizedBox(height: 12),
                    _buildProCard(),
                    const SizedBox(height: 12),
                    _buildCreditsCard(),
                    const SizedBox(height: 32),
                    _buildFeaturesGrid(),
                    const SizedBox(height: 32),
                    _buildFAQ(),
                    const SizedBox(height: 32),
                    _buildFooter(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      backgroundColor: _kBg,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _bgController,
          builder: (_, __) {
            final angle = _bgController.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Galactic gradient rotating slowly
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        math.cos(angle) * 0.4,
                        math.sin(angle) * 0.4,
                      ),
                      radius: 1.4,
                      colors: const [
                        Color(0xFF3A0E6B),
                        Color(0xFF0A061A),
                        Color(0xFF06040F),
                      ],
                    ),
                  ),
                ),
                // Stars
                ...List.generate(20, (i) {
                  final rng = math.Random(i * 7);
                  return Positioned(
                    left: rng.nextDouble() * 400,
                    top: rng.nextDouble() * 220,
                    child: Container(
                      width: rng.nextDouble() * 2 + 1,
                      height: rng.nextDouble() * 2 + 1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(rng.nextDouble() * 0.6 + 0.2),
                      ),
                    ),
                  );
                }),
                // Title
                Align(
                  alignment: const Alignment(0, 0.2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [_kPurple, _kCyan],
                        ).createShader(b),
                        child: const Text(
                          'GENESIS PRO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPlanBadge(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlanBadge() {
    final label = _isPro ? '✦ PRO' : 'FREE';
    final color = _isPro ? _kPurple : Colors.white30;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        'Plan actuel : $label',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Toggle mensuel / annuel ───────────────────────────────────────────────

  Widget _buildToggle() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleOption('Mensuel', !_yearlyToggle, () => setState(() => _yearlyToggle = false)),
            _toggleOption('Annuel  −25 %', _yearlyToggle, () => setState(() => _yearlyToggle = true)),
          ],
        ),
      ),
    );
  }

  Widget _toggleOption(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: [_kPurple, _kCyan])
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2D55).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.3)),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Color(0xFFFF2D55), fontSize: 13),
      ),
    );
  }

  // ── FREE Card ─────────────────────────────────────────────────────────────

  Widget _buildFreeCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge('FREE', Colors.white30, Colors.white54),
              const Spacer(),
              const Text('0 €', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          ..._features(['5 créations / mois', 'Itérations illimitées', '1 projet actif']),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                foregroundColor: Colors.white38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Plan actuel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── PRO Card ──────────────────────────────────────────────────────────────

  Widget _buildProCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (_, child) {
        final angle = _glowController.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: SweepGradient(
              startAngle: angle,
              endAngle: angle + 2 * math.pi,
              colors: const [
                _kPurple,
                _kCyan,
                Color(0xFF00E676),
                _kPurple,
              ],
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(19),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badge('POPULAIRE', _kPurple, Colors.white),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _yearlyToggle ? '59,99 €' : '7,99 €',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _yearlyToggle ? '/an' : '/mois',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._features([
              '50 créations / mois',
              'Itérations illimitées',
              'Projets illimités',
              'Support prioritaire',
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _isPro
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kPurple.withOpacity(0.4)),
                        foregroundColor: _kPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Plan actuel ✦', style: TextStyle(fontWeight: FontWeight.w700)),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_kPurple, _kCyan]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _loadingCheckout ? null : () => _handlePurchase(_currentPriceId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loadingCheckout
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Passer à PRO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Credits Card ──────────────────────────────────────────────────────────

  Widget _buildCreditsCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge('FLEXIBLE', _kCyan, Colors.black),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text('1,99 €', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  Text('pack de 10 crédits', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Chaque crédit = 1 génération. Sans engagement.',
            style: TextStyle(color: Color(0xFF8899AA), fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loadingCheckout ? null : () => _handlePurchase(_kCreditPackPriceId),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kCyan),
                foregroundColor: _kCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loadingCheckout
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: _kCyan, strokeWidth: 2),
                    )
                  : const Text('Acheter des crédits', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Features Grid ─────────────────────────────────────────────────────────

  Widget _buildFeaturesGrid() {
    final items = [
      (Icons.bolt, '50 générations/mois', '10× plus que le plan gratuit'),
      (Icons.history, 'Historique illimité', 'Toutes vos versions conservées'),
      (Icons.auto_awesome, 'Apps plus complexes', 'Budget de tokens élargi'),
      (Icons.support_agent, 'Support prioritaire', 'Réponse en moins de 24h'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pourquoi PRO ?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: items
              .map((e) => _featureBlock(e.$1, e.$2, e.$3))
              .toList(),
        ),
      ],
    );
  }

  Widget _featureBlock(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kPurple, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: Color(0xFF6B7D9E), fontSize: 11)),
        ],
      ),
    );
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────

  Widget _buildFAQ() {
    final items = [
      ('Puis-je annuler à tout moment ?', 'Oui, depuis votre espace Stripe sans engagement.'),
      (
        'Que se passe-t-il si je dépasse mon quota ?',
        'Vous pouvez acheter des crédits bonus ou attendre le renouvellement mensuel.'
      ),
      ('Les itérations comptent-elles ?', 'Non, seules les créations initiales consomment votre quota.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FAQ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 12),
        ...items.map((e) => _faqTile(e.$1, e.$2)),
      ],
    );
  }

  Widget _faqTile(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: _kPurple,
          collapsedIconColor: Colors.white38,
          title: Text(q, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(a, style: const TextStyle(color: Color(0xFF8899AA), fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Column(
      children: [
        if (_isPro)
          TextButton.icon(
            onPressed: _loadingPortal ? null : _handleManageSubscription,
            icon: _loadingPortal
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2),
                  )
                : const Icon(Icons.manage_accounts_outlined, size: 18, color: _kPurple),
            label: const Text(
              'Gérer mon abonnement',
              style: TextStyle(color: _kPurple, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Paiement sécurisé via Stripe · Annulation à tout moment',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: child,
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bg.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  List<Widget> _features(List<String> items) {
    return items
        .map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: _kCyan),
                const SizedBox(width: 8),
                Text(f, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        )
        .toList();
  }
}
