import 'package:flutter/material.dart';
import 'base_handler.dart';

/// Handler for Ondes.App namespace
/// Manages mini-app lifecycle and information
class AppHandler extends BaseHandler {
  final String? appBundleId;
  final String? appVersion;
  final String? appName;
  final VoidCallback? onClose;

  AppHandler(
    BuildContext context, {
    this.appBundleId,
    this.appVersion,
    this.appName,
    this.onClose,
  }) : super(context);

  @override
  void registerHandlers() {
    _registerGetInfo();
    _registerClose();
    _registerGetManifest();
  }

  void _registerGetInfo() {
    addSyncHandler('Ondes.App.getInfo', (args) {
      return {
        'bundleId': appBundleId ?? 'unknown',
        'name': appName ?? 'Unknown App',
        'version': appVersion ?? '1.0.0',
        'platform': Theme.of(context).platform.toString().split('.').last,
        'sdkVersion': '1.0.0',
      };
    });
  }

  void _registerClose() {
    addSyncHandler('Ondes.App.close', (args) {
      if (onClose != null) {
        onClose!();
      } else {
        Navigator.pop(context);
      }
    });
  }

  void _registerGetManifest() {
    addHandler('Ondes.App.getManifest', (args) async {
      // This could load from actual manifest.json in future
      return {
        'id': appBundleId ?? 'unknown',
        'name': appName ?? 'Unknown App',
        'version': appVersion ?? '1.0.0',
      };
    });
  }
}
