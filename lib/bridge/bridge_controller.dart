import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../ui/common/scanner_screen.dart';
import '../core/services/auth_service.dart';

class OndesBridgeController {
  final BuildContext context;
  InAppWebViewController? webViewController;
  final Function(Map<String, dynamic>)? onAppBarConfig;

  OndesBridgeController(this.context, {this.onAppBarConfig});

  void setController(InAppWebViewController controller) {
    webViewController = controller;
    _registerHandlers();
  }

  void _registerHandlers() {
    if (webViewController == null) return;

    // --- 1. UI ---
    webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.UI.showToast',
      callback: (args) {
        final options = args[0] as Map<String, dynamic>;
        final message = options['message'] ?? '';
        final type = options['type'] ?? 'info';
        
        Color bgColor = Colors.black87;
        if (type == 'error') bgColor = Colors.red;
        if (type == 'success') bgColor = Colors.green;
        if (type == 'warning') bgColor = Colors.orange;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.UI.showAlert',
      callback: (args) async {
        final options = args[0] as Map<String, dynamic>;
        return showDialog(
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
      },
    );

     webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.UI.configureAppBar',
      callback: (args) {
        if (args.isNotEmpty && onAppBarConfig != null) {
           onAppBarConfig!(args[0] as Map<String, dynamic>);
        }
      },
    );

    // --- 2. User ---
    webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.User.getProfile',
      callback: (args) {
        final user = AuthService().currentUser;
         if (user != null) {
          // Construct absolute avatar URL if needed
          // user['avatar'] is relative path from Django /media/...
          String? avatarUrl = user['avatar'];
          if (avatarUrl != null && !avatarUrl.startsWith('http')) {
             avatarUrl = "http://127.0.0.1:8000$avatarUrl";
          }

          return {
            'id': user['id'].toString(), // User ID
            'username': user['username'],
            'email': user['email'],
            'avatar': avatarUrl ?? 'https://api.dicebear.com/7.x/avataaars/png?seed=${user['username']}',
            'bio': user['bio'] ?? ""
          };
        }
        return null; // Not logged in
      },
    );

    webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.User.getAuthToken',
      callback: (args) {
        return AuthService().token;
      },
    );

    // --- 3. Device ---
    webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.Device.hapticFeedback',
      callback: (args) {
        final style = args[0] as String;
        switch (style) {
          case 'light': HapticFeedback.lightImpact(); break;
          case 'medium': HapticFeedback.mediumImpact(); break;
          case 'heavy': HapticFeedback.heavyImpact(); break;
          case 'success': HapticFeedback.vibrate(); break; // System sound/haptic
          default: HapticFeedback.selectionClick();
        }
      },
    );

    webViewController!.addJavaScriptHandler(
        handlerName: 'Ondes.Device.scanQRCode',
        callback: (args) async {
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (context) => const CodeScannerScreen()),
          );
          
          if (result != null) {
            return result;
          } else {
             throw Exception("User cancelled scan");
          }
        }
    );

    webViewController!.addJavaScriptHandler(
        handlerName: 'Ondes.Device.getGPSPosition',
        callback: (args) async {
          bool serviceEnabled;
          LocationPermission permission;

          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            throw Exception('Location services are disabled.');
          }

          permission = await Geolocator.checkPermission();
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
            'altitude': position.altitude
          };
        }
    );

     // --- 4. Storage ---
     // TODO: Implement Persistent Storage with SharedPreferences/Hive
     Map<String, dynamic> mockStorage = {}; 
     
     webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.Storage.set',
      callback: (args) {
        final argsList = args[0] as List; // JS might send [key, val] as first arg if wrapped, or args[0], args[1]
        // Based on JS wrapper: callHandler('Ondes.Storage.set', [key, value]) -> args[0] is [key, value]
        // Wait, callHandler('name', [a, b]) -> callback receives [ [a, b] ] ? or [a, b]?
        // Flutter InAppWebView behavior: callHandler args are passed as a List. 
        // My JS: callHandler('name', [key, value]) -> Dart args: [ [key, value] ]
        // My JS: callHandler('name', key) -> Dart args: [ key ]
        
        // Let's correct the JS wrapper or adjust here. 
        // In JS: callHandler('Ondes.Storage.set', [key, value]) passes a single array argument.
        // So args[0] is the list [key, value].
        
        if (args.isEmpty) return;
        final params = args[0] as List;
        if (params.length >= 2) {
             mockStorage[params[0].toString()] = params[1];
        }
      },
    );

    webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.Storage.get',
      callback: (args) {
         final key = args[0].toString();
         return mockStorage[key];
      },
    );

    // --- 5. App ---
    webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.App.close',
      callback: (args) {
        Navigator.pop(context); // Close WebView screen
      },
    );
     webViewController!.addJavaScriptHandler(
      handlerName: 'Ondes.App.getInfo',
      callback: (args) {
        return {
            "version": "1.0.0",
            "buildNumber": 1,
            "platform": Theme.of(context).platform.toString()
        };
      },
    );
  }
}
