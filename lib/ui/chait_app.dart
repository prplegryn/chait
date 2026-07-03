import 'package:flutter/material.dart';

import '../app_store.dart';
import 'chat_screen.dart';

class ChaitApp extends StatelessWidget {
  const ChaitApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chait',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF111111),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF111111),
          outline: Color(0xFFE6E6E6),
        ),
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
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111111),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEDEDED),
          thickness: 1,
          space: 1,
        ),
      ),
      home: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (!store.isReady) {
            return const _LoadingScreen();
          }
          return ChatScreen(store: store);
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}
