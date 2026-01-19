import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:ondes_core/ui/widgets/liquid_glass.dart';
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
      home: LiquidGlassLayer(
        child: AuthWrapper(
          onAuthChange: () {
             // Hack to force rebuild entire app to update profile connection status everywhere
             setState(() {}); 
          }
        ),
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

    final List<NavigationItem> navItems = [
      NavigationItem(icon: Icons.science_outlined, activeIcon: Icons.science, label: "Lab"),
      NavigationItem(icon: Icons.grid_view, activeIcon: Icons.grid_view_rounded, label: "Apps"),
      NavigationItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: "Store"),
      NavigationItem(
          icon: isAuth ? Icons.person_outline : Icons.login, 
          activeIcon: isAuth ? Icons.person : Icons.login, 
          label: isAuth ? "Profil" : "Compte"
      ),
    ];

    Widget _buildLiquidGlassNavItem(
    NavigationItem item,
    bool isSelected,
    int index,
    ThemeData theme,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return GestureDetector(
          onTap: () => setState(() => _currentIndex = index),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                
                // Icône et label
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: 1.0 + (value * 0.15),
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: Color.lerp(
                          Colors.white.withOpacity(0.5),
                          Colors.white,
                          value,
                        ),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.label, style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: Color.lerp(
                        Colors.white.withOpacity(0.5),
                        Colors.white,
                        value,
                      )!,
                      letterSpacing: isSelected ? 0.5 : 0,
                    ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

      Widget _buildLiquidGlassBottomBar() {
    final theme = Theme.of(context);
    
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: SizedBox(
          height: 75,
          child: OndesLiquidGlass(child: 
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      navItems.length,
                      (index) {
                        final item = navItems[index];
                        final isSelected = _currentIndex == index;
                        
                        return _buildLiquidGlassNavItem(
                          item,
                          isSelected,
                          index,
                          theme,
                        );
                      },
                    ),
                ),
          ),
        ),
      
    );
  }
  
  return Scaffold(
    extendBody: true,
    body: Stack(
      children: [
        Positioned.fill(
          child: screens[_currentIndex]
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildLiquidGlassBottomBar(),
          ),
        ]
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
