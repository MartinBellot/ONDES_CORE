import 'package:flutter/material.dart';
import 'base_handler.dart';

/// Handler for Ondes.UI namespace
/// Manages native UI components (toast, alerts, app bar)
class UIHandler extends BaseHandler {
  final Function(Map<String, dynamic>)? onAppBarConfig;

  UIHandler(BuildContext context, {this.onAppBarConfig}) : super(context);

  @override
  void registerHandlers() {
    _registerShowToast();
    _registerShowAlert();
    _registerConfigureAppBar();
    _registerShowConfirm();
    _registerShowBottomSheet();
  }

  void _registerShowToast() {
    addSyncHandler('Ondes.UI.showToast', (args) {
      final options = args[0] as Map<String, dynamic>;
      final message = options['message'] ?? '';
      final type = options['type'] ?? 'info';

      Color bgColor = Colors.black87;
      IconData? icon;

      switch (type) {
        case 'error':
          bgColor = Colors.red.shade700;
          icon = Icons.error_outline;
          break;
        case 'success':
          bgColor = Colors.green.shade700;
          icon = Icons.check_circle_outline;
          break;
        case 'warning':
          bgColor = Colors.orange.shade700;
          icon = Icons.warning_amber_outlined;
          break;
        default:
          bgColor = Colors.blueGrey.shade800;
          icon = Icons.info_outline;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  void _registerShowAlert() {
    addHandler('Ondes.UI.showAlert', (args) async {
      final options = args[0] as Map<String, dynamic>;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(options['title'] ?? 'Alert'),
          content: Text(options['message'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(options['buttonText'] ?? 'OK'),
            )
          ],
        ),
      );
      return null;
    });
  }

  void _registerShowConfirm() {
    addHandler('Ondes.UI.showConfirm', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(options['title'] ?? 'Confirm'),
          content: Text(options['message'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(options['cancelText'] ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(options['confirmText'] ?? 'Confirm'),
            ),
          ],
        ),
      );
      return result ?? false;
    });
  }

  void _registerConfigureAppBar() {
    addSyncHandler('Ondes.UI.configureAppBar', (args) {
      if (args.isNotEmpty && onAppBarConfig != null) {
        onAppBarConfig!(args[0] as Map<String, dynamic>);
      }
    });
  }

  void _registerShowBottomSheet() {
    addHandler('Ondes.UI.showBottomSheet', (args) async {
      final options = args[0] as Map<String, dynamic>;
      final items = (options['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      final result = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (options['title'] != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    options['title'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ...items.map((item) => ListTile(
                leading: item['icon'] != null 
                    ? Icon(_parseIcon(item['icon'])) 
                    : null,
                title: Text(item['label'] ?? ''),
                onTap: () => Navigator.pop(ctx, item['value']?.toString()),
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      return result;
    });
  }

  IconData _parseIcon(String? iconName) {
    // Simple icon mapping
    switch (iconName) {
      case 'share': return Icons.share;
      case 'copy': return Icons.copy;
      case 'delete': return Icons.delete;
      case 'edit': return Icons.edit;
      case 'save': return Icons.save;
      case 'camera': return Icons.camera_alt;
      case 'gallery': return Icons.photo_library;
      default: return Icons.circle;
    }
  }
}
