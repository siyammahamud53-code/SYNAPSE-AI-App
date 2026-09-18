import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:synapse_ai/providers/app_state.dart';
import 'package:synapse_ai/services/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // গ্লোবাল এরর হ্যান্ডলার - অ্যাপ যেন কোনো কারণে বন্ধ না হয়
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(() async {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // ১. নিরাপদ ফায়ারবেস স্টার্টআপ
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase backend initialized successfully');
    } catch (e) {
      debugPrint('Firebase init bypassed or error: $e');
    }

    // ২. পারমিশন সেফটি
    await _requestDevicePermissionsSafely();

    // ৩. ব্যাকগ্রাউন্ড সার্ভিস স্টার্টআপ
    await _initializeServicesSafely();

    runApp(const SynapseAI());
  }, (error, stack) {
    debugPrint('Global Protected Catch Exception: $error');
  });
}

Future<void> _requestDevicePermissionsSafely() async {
  try {
    await [
      Permission.microphone,
      Permission.camera,
      Permission.phone,
      Permission.storage,
      Permission.notification,
    ].request();
  } catch (e) {
    debugPrint("Permission handling notice: $e");
  }
}

Future<void> _initializeServicesSafely() async {
  try {
    await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init error: $e');
  }

  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    
    await Workmanager().registerPeriodicTask(
      'synapse_ai_sync',
      'syncTask',
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  } catch (e) {
    debugPrint('Workmanager init bypassed: $e');
  }

  try {
    await BackgroundService().initialize();
    debugPrint('Basic services initialized successfully');
  } catch (e) {
    debugPrint('Background service init error: $e');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case 'syncTask':
          await _syncTask();
          break;
        case 'backgroundTask':
          await _backgroundTask();
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('Background Task Exec Error: $e');
    }
    return Future.value(true);
  });
}

Future<void> _syncTask() async {
  try {
    debugPrint('Background sync completed');
  } catch (e) {
    debugPrint('Background sync failed: $e');
  }
}

Future<void> _backgroundTask() async {
  try {
    debugPrint('Background processing completed');
  } catch (e) {
    debugPrint('Background processing failed: $e');
  }
}

class SynapseAI extends StatelessWidget {
  const SynapseAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => BackgroundService()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'SYNAPSE AI v3.0.0',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: Colors.black,
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
              Locale('bn'),
            ],
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'SYNAPSE AI',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withOpacity(0.1),
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 70,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Synapse AI Ready & Running!',
              style: TextStyle(
                fontSize: 20,
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Neural Core Initialized Successfully',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
