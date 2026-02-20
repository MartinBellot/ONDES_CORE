import 'package:flutter/material.dart';
import '../../core/services/genesis_service.dart';
import 'genesis_pricing_screen.dart';

/// Compact quota badge shown in AppBar — taps open GenesisPricingScreen.
class GenesisQuotaBadge extends StatelessWidget {
  final GenesisQuota quota;
  final bool isCompact; // If true, shows only the bolt icon without text (used in workspace AppBar)

  const GenesisQuotaBadge({super.key, required this.quota, this.isCompact = false});

  Color get _countColor {
    if (quota.remainingCreations == 0) return const Color(0xFFFF2D55);
    if (quota.remainingCreations <= 3) return const Color(0xFFFF9500);
    return const Color(0xFF00E676);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPricing(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: quota.isPro
                ? const Color(0xFFAF52DE).withOpacity(0.5)
                : Colors.white.withOpacity(0.12),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
    
            Icon(
              Icons.bolt,
              size: 14,
              color: quota.isPro ? const Color(0xFFAF52DE) : Colors.white70,
            ),
            
              const SizedBox(width: 4),
              Text(
                '${quota.remainingCreations} ${!isCompact ? 'restantes' : ''}',
                  style: TextStyle(
                    color: _countColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                ),
              
              ),

            
          ]
        )
      ),
    );
  }

  void _openPricing(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GenesisPricingScreen(currentQuota: quota),
    );
  }

  /// Opens the pricing sheet externally — e.g. from a 402 error handler.
  static void openSheet(BuildContext context, GenesisQuota? quota) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GenesisPricingScreen(currentQuota: quota),
    );
  }
}
