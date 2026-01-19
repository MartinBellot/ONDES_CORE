import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../ui/common/scanner_screen.dart';
import 'base_handler.dart';

/// Handler for Ondes.Device namespace
/// Manages device hardware (haptics, camera, GPS)
class DeviceHandler extends BaseHandler {
  DeviceHandler(BuildContext context) : super(context);

  @override
  void registerHandlers() {
    _registerHapticFeedback();
    _registerScanQRCode();
    _registerGetGPSPosition();
    _registerGetDeviceInfo();
    _registerVibrate();
  }

  void _registerHapticFeedback() {
    addSyncHandler('Ondes.Device.hapticFeedback', (args) {
      final style = args.isNotEmpty ? args[0] as String : 'light';
      switch (style) {
        case 'light':
          HapticFeedback.lightImpact();
          break;
        case 'medium':
          HapticFeedback.mediumImpact();
          break;
        case 'heavy':
          HapticFeedback.heavyImpact();
          break;
        case 'success':
        case 'error':
        case 'warning':
          HapticFeedback.vibrate();
          break;
        default:
          HapticFeedback.selectionClick();
      }
    });
  }

  void _registerVibrate() {
    addHandler('Ondes.Device.vibrate', (args) async {
      // Note: Duration control requires platform channels or vibration plugin
      // Duration parameter available for future implementation
      // ignore: unused_local_variable
      final duration = args.isNotEmpty ? (args[0] as num).toInt() : 100;
      HapticFeedback.vibrate();
      return null;
    });
  }

  void _registerScanQRCode() {
    addHandler('Ondes.Device.scanQRCode', (args) async {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const CodeScannerScreen()),
      );

      if (result != null) {
        return result;
      } else {
        throw Exception("User cancelled scan");
      }
    });
  }

  void _registerGetGPSPosition() {
    addHandler('Ondes.Device.getGPSPosition', (args) async {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition();
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'timestamp': position.timestamp.millisecondsSinceEpoch,
      };
    });
  }

  void _registerGetDeviceInfo() {
    addHandler('Ondes.Device.getInfo', (args) async {
      return {
        'platform': Theme.of(context).platform.toString().split('.').last,
        'brightness': MediaQuery.of(context).platformBrightness.toString().split('.').last,
        'screenWidth': MediaQuery.of(context).size.width,
        'screenHeight': MediaQuery.of(context).size.height,
        'pixelRatio': MediaQuery.of(context).devicePixelRatio,
      };
    });
  }
}

