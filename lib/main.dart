// ============================================================
// SYNAPSE AI - DYNAMIC CAMERA & CALL-AWARE HUD INTERFACE
// Features: On-Demand Gesture Camera & Smart Call Hardware Release
// Fixed: Runtime Exception & Initialization Crash
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum CallState { idle, incomingCall, activeCall }

class AppState extends ChangeNotifier {
  String currentPersona = 'MAYA';
  bool isListening = false;
  bool isSpeaking = false;
  
  bool isCameraGestureActive = false;
  String lastDetectedGesture = 'CAMERA OFF';
  CallState currentCallState = CallState.idle;

  double cpuUsage = 12.0;
  double gpuUsage = 8.0;

  String lastResponse = 'SYSTEM READY: Say "Open Gesture" to activate No-Touch Control.';

  void activateGestureOnCommand() {
    if (currentCallState != CallState.idle) {
      lastResponse = '⚠️ CALL IN PROGRESS: Camera gesture locked for Call Privacy!';
      notifyListeners();
      return;
    }
    
    isCameraGestureActive = true;
    gpuUsage = 45.0;
    lastDetectedGesture = 'WAITING FOR HAND...';
    lastResponse = '🖐️ AIR GESTURE ACTIVATED: Move hand 1-2 ft away!';
    notifyListeners();
  }

  void deactivateGesture() {
    isCameraGestureActive = false;
    gpuUsage = 8.0;
    lastDetectedGesture = 'CAMERA RELEASED';
    lastResponse = '🍃 GESTURE OFF: Camera released for standard system use.';
    notifyListeners();
  }

  void handleCallEvent(CallState state) {
    currentCallState = state;
    if (state != CallState.idle) {
      isCameraGestureActive = false;
      lastDetectedGesture = 'CAMERA BUSY (IN-CALL)';
      lastResponse = '📞 CALL DETECTED: Camera & Mic released to Call Service.';
    } else {
      lastResponse = '📞 CALL ENDED: Background Ambient Engine Restored.';
    }
    notifyListeners();
  }

  void toggleListening() {
    isListening = !isListening;
    lastResponse = isListening ? '🎤 LISTENING...' : '🔇 STANDBY...';
    notifyListeners();
  }
}

class HUDTheme {
  static const Color background = Color(0xFF030A16);
  static const Color neonCyan = Color(0xFF00F3FF);
  static const Color neonRed = Color(0xFFFF0044);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonYellow = Color(0xFFFFCC00);
  static const String fontFamily = 'monospace';

  static BoxDecoration glassCard() => BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neonCyan.withOpacity(0.2), width: 0.8),
      );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const SynapseApp(),
    ),
  );
}

class SynapseApp extends StatelessWidget {
  const SynapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SYNAPSE CALL-SAFE HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: HUDTheme.background,
      ),
      home: const HUDScreen(),
    );
  }
}

class HUDScreen extends StatefulWidget {
  const HUDScreen({super.key});

  @override
  State<HUDScreen> createState() => _HUDScreenState();
}

class _HUDScreenState extends State<HUDScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    
    // Safety delay to prevent UI thread crash on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rotationController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(appState),
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: _buildArcReactor(appState, size.width < 600 ? 210 : 280),
                  ),
                  Positioned(
                    top: 15,
                    right: 15,
                    child: _buildCameraHardwareCard(appState),
                  ),
                ],
              ),
            ),
            _buildCallSimulatorBar(appState),
            _buildBottomBar(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HUDTheme.neonCyan.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("SYNAPSE SMART-CORE v6.5", style: TextStyle(color: HUDTheme.neonCyan, fontFamily: HUDTheme.fontFamily, fontWeight: FontWeight.bold)),
          Text(
            "GPU LOAD: ${appState.gpuUsage}%",
            style: const TextStyle(color: HUDTheme.neonGreen, fontSize: 11, fontFamily: HUDTheme.fontFamily),
          ),
        ],
      ),
    );
  }

  Widget _buildArcReactor(AppState appState, double size) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: HUDTheme.glassCard(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("PERSONA: ${appState.currentPersona}", style: const TextStyle(color: HUDTheme.neonCyan, fontFamily: HUDTheme.fontFamily)),
          const SizedBox(height: 10),
          SizedBox(
            width: size,
            height: size,
            child: RotationTransition(
              turns: _rotationController,
              child: CustomPaint(
                painter: ArcReactorPainter(isActive: appState.isCameraGestureActive),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraHardwareCard(AppState appState) {
    Color statusColor = appState.isCameraGestureActive ? HUDTheme.neonGreen : Colors.white38;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: HUDTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_front, color: statusColor, size: 16),
              const SizedBox(width: 6),
              Text("AIR SENSOR", style: TextStyle(color: statusColor, fontSize: 10, fontFamily: HUDTheme.fontFamily)),
            ],
          ),
          const SizedBox(height: 4),
          Text(appState.lastDetectedGesture, style: TextStyle(color: statusColor, fontSize: 9, fontFamily: HUDTheme.fontFamily)),
        ],
      ),
    );
  }

  Widget _buildCallSimulatorBar(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("CALL SIMULATOR: ", style: TextStyle(fontSize: 10, fontFamily: HUDTheme.fontFamily, color: Colors.white54)),
          TextButton(
            onPressed: () => appState.handleCallEvent(CallState.incomingCall),
            child: const Text("RECEIVE CALL", style: TextStyle(color: HUDTheme.neonYellow, fontSize: 10, fontFamily: HUDTheme.fontFamily)),
          ),
          TextButton(
            onPressed: () => appState.handleCallEvent(CallState.idle),
            child: const Text("END CALL", style: TextStyle(color: HUDTheme.neonRed, fontSize: 10, fontFamily: HUDTheme.fontFamily)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: HUDTheme.neonCyan.withOpacity(0.3)))),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: HUDTheme.glassCard(),
            child: Text("> ${appState.lastResponse}", style: const TextStyle(color: HUDTheme.neonCyan, fontSize: 11, fontFamily: HUDTheme.fontFamily)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (appState.isCameraGestureActive) {
                      appState.deactivateGesture();
                    } else {
                      appState.activateGestureOnCommand();
                    }
                  },
                  child: Text(
                    appState.isCameraGestureActive ? "RELEASE CAMERA" : "AIR GESTURE (ON DEMAND)",
                    style: const TextStyle(color: HUDTheme.neonCyan, fontSize: 10, fontFamily: HUDTheme.fontFamily),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => appState.toggleListening(),
                  child: Text(
                    appState.isListening ? "STOP VOICE" : "VOICE CONTROL",
                    style: TextStyle(color: appState.isListening ? HUDTheme.neonRed : HUDTheme.neonGreen, fontSize: 10, fontFamily: HUDTheme.fontFamily),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ArcReactorPainter extends CustomPainter {
  final bool isActive;
  ArcReactorPainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final color = isActive ? HUDTheme.neonGreen : HUDTheme.neonCyan;

    final paintRing = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius * 0.9, paintRing);
  }

  @override
  bool shouldRepaint(covariant ArcReactorPainter oldDelegate) => oldDelegate.isActive != isActive;
}
