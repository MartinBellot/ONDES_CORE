import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ui/lab/lab_screen.dart';
import 'ui/store/store_screen.dart';
import 'ui/my_apps/my_apps_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/profile/profile_screen.dart';
import 'core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Init Auth
  await AuthService().init();
  
  // Gestion sécurisée des permissions au démarrage
  try {
    if (Platform.isAndroid) {
      await [
        Permission.camera,
        Permission.storage,
      ].request();
    } else if (Platform.isIOS) {
       await [
        Permission.camera,
      ].request();
    } else if (Platform.isMacOS) {
      // Sur macOS, les permissions sont demandées à la volée par l'OS
      // lors de la première utilisation (ex: Scanner QR).
      // On ne bloque pas le démarrage.
    }
  } catch (e) {
    print("⚠️ Erreur lors de l'initialisation des permissions : $e");
  }

  runApp(const OndesCoreApp());
}

class OndesCoreApp extends StatefulWidget {
  const OndesCoreApp({super.key});

  @override
  State<OndesCoreApp> createState() => _OndesCoreAppState();
}

class _OndesCoreAppState extends State<OndesCoreApp> {
  // Use a method to rebuild screens based on auth state if needed, 
  // or wrap the profile tab in a reactive widget.
  // Ideally use a ValueListenable or StreamBuilder.
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ondes Core',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: AuthWrapper(
        onAuthChange: () {
           // Hack to force rebuild entire app to update profile connection status everywhere
           setState(() {}); 
        }
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final VoidCallback onAuthChange;
  const AuthWrapper({super.key, required this.onAuthChange});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
   int _currentIndex = 0;

   @override
  Widget build(BuildContext context) {
    final bool isAuth = AuthService().isAuthenticated;

    final List<Widget> screens = [
      const LabScreen(),
      const MyAppsScreen(),
      const StoreScreen(),
      // Profile Tab Logic
      isAuth 
         ? const ProfileScreen()
         : LoginScreen(onLoginSuccess: () {
            setState(() {}); // Rebuild to switch to ProfileScreen
         }),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black87,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.science), label: "Lab"),
            const BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "Apps"),
            const BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Store"),
            BottomNavigationBarItem(
              icon: Icon(isAuth ? Icons.person : Icons.login), 
              label: isAuth ? "Profil" : "Compte"
            ),
          ],
      ),
    );
  }
}
