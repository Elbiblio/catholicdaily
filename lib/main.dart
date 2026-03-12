import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/services/theme_preferences.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final themePreferences = await ThemePreferences.getInstance();

  runApp(CatholicDailyApp(themePreferences: themePreferences));
}

/// Premium Catholic Daily App with 2026 design standards
class CatholicDailyApp extends StatefulWidget {
  const CatholicDailyApp({super.key, required this.themePreferences});

  final ThemePreferences themePreferences;

  @override
  State<CatholicDailyApp> createState() => _CatholicDailyAppState();
}

class _CatholicDailyAppState extends State<CatholicDailyApp> {
  late ThemeMode _themeMode;
  late AppThemeStyle _themeStyle;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themePreferences.getThemeMode();
    _themeStyle = widget.themePreferences.getThemeStyle();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catholic Daily',
      debugShowCheckedModeBanner: false,
      theme: _buildPremiumTheme(Brightness.light, _themeStyle),
      darkTheme: _buildPremiumTheme(Brightness.dark, _themeStyle),
      themeMode: _themeMode,
      home: HomeScreen(
        themeMode: _themeMode,
        themeStyle: _themeStyle,
        onThemeModeChanged: _handleThemeModeChanged,
        onThemeStyleChanged: _handleThemeStyleChanged,
      ),
    );
  }

  Future<void> _handleThemeModeChanged(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await widget.themePreferences.setThemeMode(mode);
  }

  Future<void> _handleThemeStyleChanged(AppThemeStyle style) async {
    setState(() {
      _themeStyle = style;
    });
    await widget.themePreferences.setThemeStyle(style);
  }

  ThemeData _buildPremiumTheme(Brightness brightness, AppThemeStyle themeStyle) {
    final colorScheme = _buildPremiumColorScheme(brightness, themeStyle);
    final textTheme = _buildPremiumTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,

      // Premium typography with 2026 standards
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // Enhanced AppBar theme
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // Premium card theme
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 4 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),

      // Enhanced navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.7),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.7),
            size: 24,
          );
        }),
      ),

      // Premium button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Enhanced input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        ),
      ),

      // Enhanced divider theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.2),
        thickness: 1,
        space: 1,
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: Colors.transparent,
        selectedTileColor: colorScheme.primaryContainer,
        iconColor: colorScheme.onSurface.withValues(alpha: 0.7),
        textColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        brightness: brightness,
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainer.withValues(alpha: 0.5),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        modalElevation: 8,
        clipBehavior: Clip.antiAlias,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.8),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  ColorScheme _buildPremiumColorScheme(Brightness brightness, AppThemeStyle themeStyle) {
    final primaryColor = themeStyle == AppThemeStyle.parchment
        ? const Color(0xFF8C1D2F)
        : const Color(0xFF8C1D2F);

    if (brightness == Brightness.light) {
      if (themeStyle == AppThemeStyle.parchment) {
        return ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          surface: const Color(0xFFF8F1E3),
          onSurface: const Color(0xFF231A13),
          surfaceContainer: const Color(0xFFFFFBF4),
          onSurfaceVariant: const Color(0xFF6D5B4D),
          outline: const Color(0xFFD8C6B1),
          outlineVariant: const Color(0xFFEADCCB),
          primaryContainer: const Color(0xFFF3DDD8),
          onPrimaryContainer: const Color(0xFF461018),
          secondary: const Color(0xFFB08D57),
          secondaryContainer: const Color(0xFFF6E8C9),
          onSecondaryContainer: const Color(0xFF5A4520),
          tertiaryContainer: const Color(0xFFEADCCB),
          onTertiaryContainer: const Color(0xFF47372A),
        );
      }

      return ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: const Color(0xFFFDFCF0), // Missal page color
        onSurface: const Color(0xFF1A1A1A),
        surfaceContainer: const Color(0xFFFFFFFF),
        onSurfaceVariant: const Color(0xFF6B6B73),
        outline: const Color(0xFFEAE6D8),
        outlineVariant: const Color(0xFFF2F2F7),
        primaryContainer: const Color(0xFFFDECEE),
        onPrimaryContainer: const Color(0xFF5A101C),
        secondaryContainer: const Color(0xFFFDF8E8),
        onSecondaryContainer: const Color(0xFF6B4E2A), // Gold accent
        tertiaryContainer: const Color(0xFFFFF4E6),
        onTertiaryContainer: const Color(0xFF6B4E2A),
      );
    } else {
      if (themeStyle == AppThemeStyle.parchment) {
        return ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF17120E),
          onSurface: const Color(0xFFF6EBDD),
          surfaceContainer: const Color(0xFF231C17),
          onSurfaceVariant: const Color(0xFFD1C1AF),
          outline: const Color(0xFF6A594B),
          outlineVariant: const Color(0xFF3C3128),
          primaryContainer: const Color(0xFF5B1B24),
          onPrimaryContainer: const Color(0xFFF8E5E1),
          secondary: const Color(0xFFD4AF37),
          secondaryContainer: const Color(0xFF473718),
          onSecondaryContainer: const Color(0xFFF8E9B3),
          tertiaryContainer: const Color(0xFF4B3B2F),
          onTertiaryContainer: const Color(0xFFF1E1CF),
        );
      }

      return ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: const Color(0xFF0F1013),
        onSurface: const Color(0xFFFDFCF0),
        surfaceContainer: const Color(0xFF1A1C22),
        onSurfaceVariant: const Color(0xFFAEAEB2),
        outline: const Color(0xFF3A3A3C),
        outlineVariant: const Color(0xFF2C2C2E),
        primaryContainer: const Color(0xFF5A101C),
        onPrimaryContainer: const Color(0xFFFDECEE),
        secondaryContainer: const Color(0xFF2A2211),
        onSecondaryContainer: const Color(0xFFD4AF37), // Gold accent
        tertiaryContainer: const Color(0xFF6B4E2A),
        onTertiaryContainer: const Color(0xFFFFF4E6),
      );
    }
  }

  TextTheme _buildPremiumTextTheme(Brightness brightness) {
    final baseColor = brightness == Brightness.light
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF5F5F7);
    final secondaryColor = brightness == Brightness.light
        ? const Color(0xFF6B6B73)
        : const Color(0xFFAEAEB2);

    return TextTheme(
      // Display styles
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: baseColor,
        height: 1.08,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: baseColor,
        height: 1.12,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: baseColor,
        height: 1.14,
      ),

      // Headline styles
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: baseColor,
        height: 1.18,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: baseColor,
        height: 1.22,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: baseColor,
        height: 1.24,
      ),

      // Title styles
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: baseColor,
        height: 1.28,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        color: baseColor,
        height: 1.32,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: baseColor,
        height: 1.3,
      ),

      // Body styles
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: baseColor,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: baseColor,
        height: 1.55,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: secondaryColor,
        height: 1.45,
      ),

      // Label styles
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: baseColor,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: baseColor,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: secondaryColor,
        height: 1.3,
      ),
    );
  }
}
