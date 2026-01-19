import 'package:url_launcher/url_launcher.dart'; // Ensure url_launcher is in pubspec, otherwise use simple webview push or check imports.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import 'dev_studio_screen.dart';
import '../widgets/liquid_glass.dart';
import '../webview_screen.dart';
import '../common/scanner_screen.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({Key? key}) : super(key: key);

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  final TextEditingController _ipController = TextEditingController(text: "http://192.168.1.15:3000");

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('lab_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        _ipController.text = savedUrl;
      });
    }
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lab_url', url);
  }

  void _launchLiveServer() {
    final url = _ipController.text.trim();
    if (url.isNotEmpty) {
      _saveUrl(url);
      Navigator.push(context, MaterialPageRoute(builder: (c) => WebViewScreen(url: url)));
    }
  }

  void _scanQrCode() async {
    final code = await Navigator.push<String>(
      context, 
      MaterialPageRoute(builder: (context) => const CodeScannerScreen())
    );

    if (code != null) {
        if (code.startsWith("http")) {
            setState(() {
              _ipController.text = code;
            });
            _launchLiveServer();
        } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("QR Code invalide (Pas une URL)")));
        }
    }
  }

  void _openStudio() {
    if (!AuthService().isAuthenticated) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connectez-vous d'abord (Onglet Compte)")));
       return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (c) => const DevStudioScreen()));
  }

  void _openDocumentation() async {
     const url = 'https://martinbellot.github.io/ONDES_CORE/';
     final uri = Uri.parse(url);
     if (await canLaunchUrl(uri)) {
       await launchUrl(uri, mode: LaunchMode.externalApplication);
     } else {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le lien")));
     }
  }

  @override
  Widget build(BuildContext context) {
    // Cyber/Abstract Background
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.network(
              "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop", 
              fit: BoxFit.cover,
            ),
          ),
          
          // Content
          SingleChildScrollView(
            child: Column(
              children: [
                OndesLiquidGlass(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Connecter un serveur local", 
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 8),
                        Text("Remplacez le rechargement manuel. Connectez votre serveur de développement (via QR Code ou IP) pour tester en temps réel.",
                          style: TextStyle(color: Colors.white70)
                        ),
                        const SizedBox(height: 32),
                        
                        // Input Section
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24)
                          ),
                          child: TextField(
                            controller: _ipController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              icon: Icon(Icons.link, color: Colors.blueAccent),
                              hintText: "ex: http://192.168.1.15:3000",
                              hintStyle: TextStyle(color: Colors.white30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                             Expanded(
                               child: ElevatedButton.icon(
                                icon: Icon(Icons.qr_code_scanner),
                                label: Text("Scanner un QR Code"),
                                onPressed: _scanQrCode,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white, padding: EdgeInsets.all(16)),
                               ),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: ElevatedButton.icon(
                                icon: Icon(Icons.rocket_launch),
                                label: Text("Lancer"),
                                onPressed: _launchLiveServer,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: EdgeInsets.all(16)),
                               ),
                             )
                          ],
                        ),
                         
                        const Divider(height: 40, color: Colors.white24),
                        
                        // Dev Studio Section
                        Text("Ondes Studio", 
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 8),
                        Text("Gérez vos applications, publiez des mises à jour et suivez vos déploiements.",
                          style: TextStyle(color: Colors.white70)
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Documentation Link
                        Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.menu_book, color: Colors.white70, size: 18),
                            label: const Text("Documentation officielle", style: TextStyle(color: Colors.white70)),
                            onPressed: _openDocumentation,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                           width: double.infinity,
                           child: ElevatedButton.icon(
                              icon: const Icon(Icons.build_circle),
                              label: const Text("Ouvrir le Studio"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                              onPressed: _openStudio,
                           ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
