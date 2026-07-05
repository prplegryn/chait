import 'dart:async';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'ui/chait_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => const _FatalAppError();
  runZonedGuarded(
    () => runApp(const ChaitBootstrap()),
    (error, stack) {},
  );
}

class ChaitBootstrap extends StatefulWidget {
  const ChaitBootstrap({super.key});

  @override
  State<ChaitBootstrap> createState() => _ChaitBootstrapState();
}

class _FatalAppError extends StatelessWidget {
  const _FatalAppError();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              '启动遇到问题，请重启应用或清除应用数据后再试。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChaitBootstrapState extends State<ChaitBootstrap> {
  late final AppStore store;

  @override
  void initState() {
    super.initState();
    store = AppStore();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChaitApp(store: store);
  }
}
