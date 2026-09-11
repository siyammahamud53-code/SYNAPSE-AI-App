import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:synapse_ai/providers/app_state.dart';
import 'package:synapse_ai/services/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await _initializeServices();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const SynapseAI());
}

Future<void> _initializeServices() async {
  try {
    await SharedPreferences.getInstance();
    
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
    
    await BackgroundService().initialize();
    
    debugPrint('Basic services initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Service initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
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
      appBar: AppBar(
        title: const Text('SYNAPSE AI'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Synapse AI Ready & Running!',
          style: TextStyle(fontSize: 18, color: Colors.greenAccent),
        ),
      ),
    );
  }
}
