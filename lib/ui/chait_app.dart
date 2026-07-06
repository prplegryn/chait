import 'package:flutter/material.dart';

import '../app_store.dart';
import 'chat_screen.dart';

class ChaitApp extends StatelessWidget {
  const ChaitApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final mode = store.settings.appearanceMode;
        final color = Color(store.settings.themeColorValue);
        final fontScale = store.settings.fontScale.clamp(0.74, 1.28);
        return MaterialApp(
          title: 'Chait',
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode(mode),
          theme: _buildTheme(
            brightness: Brightness.light,
            userBubble: color,
            oled: false,
          ),
          darkTheme: _buildTheme(
            brightness: Brightness.dark,
            userBubble: color,
            oled: mode == 'oled',
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(fontScale.toDouble()),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: ChatScreen(store: store),
        );
      },
    );
  }
}

ThemeMode _themeMode(String mode) {
  if (mode == 'dark' || mode == 'oled') {
    return ThemeMode.dark;
  }
  return ThemeMode.light;
}

ThemeData _buildTheme({
  required Brightness brightness,
  required Color userBubble,
  required bool oled,
}) {
  final dark = brightness == Brightness.dark;
  final background = dark
      ? oled
          ? Colors.black
          : const Color(0xFF101010)
      : Colors.white;
  final surface = dark
      ? oled
          ? const Color(0xFF050505)
          : const Color(0xFF171717)
      : Colors.white;
  final onSurface = dark ? const Color(0xFFF3F3F3) : const Color(0xFF111111);
  final outline = dark ? const Color(0xFF2B2B2B) : const Color(0xFFE6E6E6);
  final scheme = ColorScheme.fromSeed(
    seedColor: userBubble,
    brightness: brightness,
  ).copyWith(
    primary: userBubble,
    onPrimary: _readableOn(userBubble),
    secondary: userBubble,
    onSecondary: _readableOn(userBubble),
    surface: surface,
    onSurface: onSurface,
    outline: outline,
    error: const Color(0xFFD92D20),
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    fontFamily: 'Inter',
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'Noto Sans SC',
      'Roboto',
      'sans-serif',
    ],
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 15.5, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14.5, height: 1.42),
      bodySmall: TextStyle(fontSize: 12.5, height: 1.35),
      labelLarge: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(
      color: outline,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF242424) : const Color(0xFF111111),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
  );
}

Color _readableOn(Color color) {
  return color.computeLuminance() > 0.54 ? const Color(0xFF111111) : Colors.white;
}
