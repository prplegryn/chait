import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_logger.dart';
import 'app_store.dart';
import 'ui/chait_app.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogger.instance.start();
      _installErrorLogging();
      AppLogger.instance.info('main', 'runApp');
      runApp(const ChaitBootstrap());
    },
    (error, stack) {
      AppLogger.instance.error('zone', error, stack);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        AppLogger.instance.debug('print', line);
        parent.print(zone, line);
      },
    ),
  );
}

void _installErrorLogging() {
  final previousDebugPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null && message.trim().isNotEmpty) {
      AppLogger.instance.debug('debugPrint', message);
    }
    previousDebugPrint(message, wrapWidth: wrapWidth);
  };

  FlutterError.onError = (details) {
    AppLogger.instance.error(
      'flutter',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.error('platform', error, stack);
    return true;
  };

  ErrorWidget.builder = (details) {
    AppLogger.instance.error(
      'error_widget',
      details.exception,
      details.stack,
    );
    return _FatalAppError(logPath: AppLogger.instance.bestVisiblePath);
  };
}

class ChaitBootstrap extends StatefulWidget {
  const ChaitBootstrap({super.key});

  @override
  State<ChaitBootstrap> createState() => _ChaitBootstrapState();
}

class _FatalAppError extends StatelessWidget {
  const _FatalAppError({required this.logPath});

  final String logPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '启动遇到问题，日志已经写入本地。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                if (logPath.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SelectableText(
                    logPath,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChaitBootstrapState extends State<ChaitBootstrap>
    with WidgetsBindingObserver {
  late final AppStore store;
  bool _loggedReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.instance.info('bootstrap', 'initState');
    store = AppStore();
    store.load();
  }

  @override
  void dispose() {
    AppLogger.instance.info('bootstrap', 'dispose');
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.instance.info('lifecycle', state.name);
  }

  @override
  Widget build(BuildContext context) {
    if (store.isReady && !_loggedReady) {
      _loggedReady = true;
      AppLogger.instance.info(
        'bootstrap',
        'store ready sessions=${store.sessions.length} '
            'assistants=${store.assistants.length} '
            'startupError=${store.startupError.isNotEmpty}',
      );
    }
    return ChaitApp(store: store);
  }
}
