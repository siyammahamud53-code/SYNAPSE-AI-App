import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:synapse_ai/providers/app_state.dart';
import 'package:synapse_ai/services/background_service.dart';
import 'package:synapse_ai/services/brain_service.dart';
import 'package:synapse_ai/services/call_service.dart';
import 'package:synapse_ai/services/vision_service.dart';
import 'package:synapse_ai/services/voice_engine.dart';
import 'package:synapse_ai/ui/screens/dashboard_screen.dart';
import 'package:synapse_ai/ui/screens/onboarding_screen.dart';
import 'package:synapse_ai/ui/theme/app_theme.dart';
import 'package:synapse_ai/ui/widgets/synapse_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await _initializeServices();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Run app
  runApp(const SynapseAI());
}

Future<void> _initializeServices() async {
  try {
    // Initialize SharedPreferences
    await SharedPreferences.getInstance();
    
    // Initialize WorkManager
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    
    // Register periodic tasks
    await Workmanager().registerPeriodicTask(
      'synapse_ai_sync',
      'syncTask',
      frequency: Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
    
    // Initialize background service
    await BackgroundService().initialize();
    
    // Initialize brain service
    await BrainService().initialize();
    
    // Initialize voice engine
    await VoiceEngine().initialize();
    
    // Initialize vision service
    await VisionService().initialize();
    
    // Initialize call service
    await CallService().initialize();
    
    debugPrint('All services initialized successfully');
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
    final brainService = BrainService();
    await brainService.processBackgroundTasks();
    debugPrint('Background sync completed');
  } catch (e) {
    debugPrint('Background sync failed: $e');
  }
}

Future<void> _backgroundTask() async {
  try {
    final backgroundService = BackgroundService();
    await backgroundService.processBackgroundQueue();
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
        ChangeNotifierProvider(create: (_) => BrainService()),
        ChangeNotifierProvider(create: (_) => VoiceEngine()),
        ChangeNotifierProvider(create: (_) => VisionService()),
        ChangeNotifierProvider(create: (_) => CallService()),
        ChangeNotifierProvider(create: (_) => BackgroundService()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'SYNAPSE AI v3.0.0',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],
            home: appState.isOnboardingComplete 
                ? const DashboardScreen()
                : const OnboardingScreen(),
            routes: {
              '/dashboard': (context) => const DashboardScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
            },
          );
        },
      ),
    );
  }
}
