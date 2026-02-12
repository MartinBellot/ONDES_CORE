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
import 'core/services/webview_pool_service.dart';
import 'core/services/permission_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Service de Pool WebView (Warmer)
  await WebViewPoolService().init();
  
  // Init Permissions
  await PermissionManagerService().init();

  // Init Auth
  await AuthService().init();

  // Gestion sécurisée des permissions au démarrage
  try {
    if (Platform.isAndroid) {
      await [Permission.camera, Permission.storage].request();
    } else if (Platform.isIOS) {
      await [Permission.camera].request();
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
  ThemeData get ultraDarkTheme {
    const surfaceColor = Color(0xFF0A0A0A);
    const primarySurface = Color(0xFF1C1C1E);
    const secondarySurface = Color(0xFF2C2C2E);
    const tertiaryColor = Color(0xFF3A3A3C);
    const accentBlue = Color(0xFF007AFF);
    const accentTeal = Color(0xFF5AC8FA);
    const accentPurple = Color(0xFFAF52DE);
    const textPrimary = Color(0xFFFFFFFF);
    const textSecondary = Color(0xFFEBEBF5);
    const textTertiary = Color(0xFF8E8E93);

    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: textPrimary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textTertiary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: accentBlue,
        onPrimary: textPrimary,
        primaryContainer: Color(0xFF1D4ED8),
        onPrimaryContainer: textPrimary,
        secondary: accentTeal,
        onSecondary: textPrimary,
        secondaryContainer: Color(0xFF0891B2),
        onSecondaryContainer: textPrimary,
        tertiary: accentPurple,
        onTertiary: textPrimary,
        tertiaryContainer: Color(0xFF7C3AED),
        onTertiaryContainer: textPrimary,
        error: Color(0xFFFF453A),
        onError: textPrimary,
        errorContainer: Color(0xFF8B0000),
        onErrorContainer: textPrimary,
        outline: Color(0xFF545458),
        outlineVariant: Color(0xFF3A3A3C),
        surface: surfaceColor,
        onSurface: textPrimary,
        surfaceVariant: primarySurface,
        onSurfaceVariant: textSecondary,
        inverseSurface: textPrimary,
        onInverseSurface: surfaceColor,
        inversePrimary: accentBlue,
        shadow: Color(0xFF000000),
        scrim: Color(0xFF000000),
        surfaceTint: accentBlue,
        surfaceContainerHighest: tertiaryColor,
        surfaceContainerHigh: secondarySurface,
        surfaceContainer: primarySurface,
        surfaceContainerLow: Color(0xFF161618),
        surfaceContainerLowest: Color(0xFF0C0C0E),
        surfaceBright: primarySurface,
        surfaceDim: Color(0xFF1A1A1C),
      ),

      // Text theme
      textTheme: textTheme,

      // App Bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
        actionsIconTheme: const IconThemeData(color: textPrimary, size: 22),
      ),

      // Card theme
      cardTheme: const CardThemeData(
        color: primarySurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primarySurface.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: tertiaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF453A), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF453A), width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: const Color(0xFFFF453A),
        ),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: accentBlue.withOpacity(0.1),
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: primarySurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: primarySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 0,
      ),

      // Floating Action Button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentBlue,
        foregroundColor: textPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: tertiaryColor.withOpacity(0.3),
        thickness: 0.5,
        space: 1,
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentBlue;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(textPrimary),
        side: BorderSide(color: textTertiary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      // Snack bar theme - Ultra stylé  style
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primarySurface.withOpacity(0.95),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: tertiaryColor.withOpacity(0.3), width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        actionTextColor: accentBlue,
        closeIconColor: textSecondary,
        showCloseIcon: false,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        dismissDirection: DismissDirection.horizontal,
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentBlue,
        linearTrackColor: tertiaryColor,
        circularTrackColor: tertiaryColor,
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: accentBlue,
        inactiveTrackColor: tertiaryColor,
        thumbColor: accentBlue,
        overlayColor: accentBlue.withOpacity(0.2),
        valueIndicatorColor: accentBlue,
        valueIndicatorTextStyle: textTheme.bodySmall?.copyWith(
          color: textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ondes Core',
      debugShowCheckedModeBanner: false,
      theme: ultraDarkTheme,
      home: AuthWrapper(key: authWrapperKey),
    );
  }
}

/// GlobalKey pour accéder à l'AuthWrapper depuis n'importe où
final GlobalKey<AuthWrapperState> authWrapperKey =
    GlobalKey<AuthWrapperState>();

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {
  int _currentIndex = 0;

  /// Méthode publique pour changer d'onglet
  void navigateToTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  /// Méthode pour rafraîchir l'état d'authentification
  void refreshAuthState() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuth = AuthService().isAuthenticated;

    final List<Widget> screens = [
      const MyAppsScreen(),
      const StoreScreen(),
      // Profile Tab Logic
      isAuth
          ? const ProfileScreen()
          : LoginScreen(
              onLoginSuccess: () {
                setState(() {}); // Rebuild to switch to ProfileScreen
              },
            ),
      const LabScreen(),
    ];

    final List<NavigationItem> navItems = [
      NavigationItem(
        icon: Icons.grid_view,
        activeIcon: Icons.grid_view_rounded,
        label: "Apps",
      ),
      NavigationItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: "Store",
      ),
      NavigationItem(
        icon: isAuth ? Icons.person_outline : Icons.login,
        activeIcon: isAuth ? Icons.person : Icons.login,
        label: isAuth ? "Profil" : "Compte",
      ),
      NavigationItem(
        icon: Icons.science_outlined,
        activeIcon: Icons.science,
        label: "Lab",
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
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = _currentIndex == index;

                return _buildLiquidGlassNavItem(item, isSelected, index, theme);
              }),
            ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: screens[_currentIndex]),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildLiquidGlassBottomBar(),
          ),
        ],
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
