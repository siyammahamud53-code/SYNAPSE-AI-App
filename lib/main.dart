import 'dart:async';
import 'dart:math' as math;
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

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background UAS Autonomous Task: $task');
    } catch (e) {
      debugPrint('Background Execution Notice: $e');
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init bypassed: $e');
    }

    await _initializeServicesSafely();
    runApp(const SynapseAI());
  }, (error, stack) {
    debugPrint('Global Protection Catch: $error');
  });
}

Future<void> _requestDevicePermissionsSafely() async {
  try {
    await [
      Permission.microphone,
      Permission.camera,
      Permission.phone,
      Permission.notification,
      Permission.systemAlertWindow,
    ].request();
  } catch (e) {
    debugPrint("Permission handling notice: $e");
  }
}

Future<void> _initializeServicesSafely() async {
  try {
    await SharedPreferences.getInstance();
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await BackgroundService().initialize();
  } catch (e) {
    debugPrint('Services init notice: $e');
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
            title: 'SYNAPSE AI - JARVIS CORE',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF02040A),
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
            home: const JarvisHomeScreen(),
          );
        },
      ),
    );
  }
}

class JarvisHomeScreen extends StatefulWidget {
  const JarvisHomeScreen({super.key});

  @override
  State<JarvisHomeScreen> createState() => _JarvisHomeScreenState();
}

class _JarvisHomeScreenState extends State<JarvisHomeScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestDevicePermissionsSafely();
    });

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Color _getPersonaColor(ActivePersona persona) {
    return persona == ActivePersona.ragna
        ? const Color(0xFF00F0FF) // Cyber Cyan for Ragna
        : const Color(0xFFFF007F); // Neon Magenta for Maya
  }

  void _handleSend(AppState appState) {
    final text = _inputController.text.trim();
    if (text.isNotEmpty) {
      _inputController.clear();
      appState.sendUserMessage(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final themeColor = _getPersonaColor(appState.currentPersona);

    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: JarvisHudBackgroundPainter(themeColor: themeColor),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SYNAPSE // UAS CORE v3.0",
                            style: TextStyle(
                              color: themeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "24/7 AUTONOMOUS MONITORING ACTIVE",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: themeColor),
                        ),
                        child: Text(
                          appState.currentPersona == ActivePersona.ragna ? "RAGNA ♂" : "MAYA ♀",
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_rotationController, _pulseController]),
                    builder: (context, child) {
                      return CustomPaint(
                        painter: JarvisArcReactorPainter(
                          rotationValue: _rotationController.value,
                          pulseValue: _pulseController.value,
                          themeColor: themeColor,
                        ),
                        child: const SizedBox(
                          width: 260,
                          height: 260,
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: themeColor.withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Text(
                          appState.activeSpeechContext,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: "Talk to Ragna or Maya...",
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                filled: true,
                                fillColor: Colors.black54,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(color: themeColor.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide(color: themeColor),
                                ),
                              ),
                              onSubmitted: (_) => _handleSend(appState),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _handleSend(appState),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: themeColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: themeColor.withOpacity(0.5),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.send, color: Colors.black, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JarvisArcReactorPainter extends CustomPainter {
  final double rotationValue;
  final double pulseValue;
  final Color themeColor;

  JarvisArcReactorPainter({
    required this.rotationValue,
    required this.pulseValue,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final glowPaint = Paint()
      ..color = themeColor.withOpacity(0.1 + (pulseValue * 0.15))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 10, glowPaint);

    final outerRing = Paint()
      ..color = themeColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 20, outerRing);

    final arcPaint = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    double startAngle = rotationValue * 2 * math.pi;
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 35),
        startAngle + (i * math.pi / 2),
        math.pi / 4,
        false,
        arcPaint,
      );
    }

    final innerArcPaint = Paint()
      ..color = themeColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    double reverseAngle = -rotationValue * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 55),
      reverseAngle,
      math.pi * 1.2,
      false,
      innerArcPaint,
    );

    final coreGlow = Paint()
      ..color = themeColor.withOpacity(0.4 + (pulseValue * 0.4))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, 28, coreGlow);

    final coreSolid = Paint()
      ..color = themeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, coreSolid);
  }

  @override
  bool shouldRepaint(covariant JarvisArcReactorPainter oldDelegate) => true;
}

class JarvisHudBackgroundPainter extends CustomPainter {
  final Color themeColor;

  JarvisHudBackgroundPainter({required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = themeColor.withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 28) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 28) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant JarvisHudBackgroundPainter oldDelegate) =>
      oldDelegate.themeColor != themeColor;
}
