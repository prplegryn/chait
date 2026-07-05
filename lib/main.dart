import 'package:flutter/material.dart';

import 'app_store.dart';
import 'ui/chait_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChaitBootstrap());
}

class ChaitBootstrap extends StatefulWidget {
  const ChaitBootstrap({super.key});

  @override
  State<ChaitBootstrap> createState() => _ChaitBootstrapState();
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
