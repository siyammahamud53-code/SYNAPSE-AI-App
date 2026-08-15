import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'services/call_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CallService().initCallListener();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..initApp(),
      child: const SynapseApp(),
    ),
  );
}

class SynapseApp extends StatelessWidget {
  const SynapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JARVIS System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF030A16),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            radialGradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                const Color(0xFF00F3FF).withOpacity(0.08),
                const Color(0xFF030A16),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 1. TOP HUD HEADER
                _buildTopHUDHeader(appState),
                const SizedBox(height: 20),

                // 2. MAIN 3D ARC-REACTOR & HUD DISPLAYS
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double reactorSize = isMobile ? constraints.maxWidth * 0.65 : 280;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Arc Reactor Visualizer
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer Rotating HUD Ring
                              RotationTransition(
                                turns: _rotationController,
                                child: Container(
                                  width: reactorSize,
                                  height: reactorSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00F3FF).withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00F3FF).withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              // Core Glow Circle
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: reactorSize * 0.7,
                                height: reactorSize * 0.7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: appState.isListening
                                      ? Colors.redAccent.withOpacity(0.2)
                                      : (appState.isSpeaking
                                          ? Colors.greenAccent.withOpacity(0.2)
                                          : const Color(0xFF00F3FF).withOpacity(0.15)),
                                  border: Border.all(
                                    color: appState.isListening
                                        ? Colors.redAccent
                                        : (appState.isSpeaking ? Colors.greenAccent : const Color(0xFF00F3FF)),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: appState.isListening
                                          ? Colors.redAccent.withOpacity(0.5)
                                          : (appState.isSpeaking ? Colors.greenAccent.withOpacity(0.5) : const Color(0xFF00F3FF).withOpacity(0.4)),
                                      blurRadius: 30,
                                    )
                                  ],
                                ),
                                child: Icon(
                                  appState.isListening ? Icons.mic : Icons.graphic_eq,
                                  size: reactorSize * 0.3,
                                  color: const Color(0xFF00F3FF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Dynamic Active Persona Indicator (Auto Detected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F3FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF00F3FF).withOpacity(0.3)),
                            ),
                            child: Text(
                              "ACTIVE PERSONA: ${appState.currentPersona.toUpperCase()}",
                              style: const TextStyle(
                                color: Color(0xFF00F3FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // AI Voice Response Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F3FF).withOpacity(0.05),
                              border: Border.all(color: const Color(0xFF00F3FF).withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              appState.lastResponse.isEmpty
                                  ? "> JARVIS AMBIENT SYSTEM ACTIVE. CALL 'MAYA' OR 'RAGNA' DIRECTLY..."
                                  : "> ${appState.lastResponse}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF00F3FF),
                                fontSize: 15,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 3. VOICE ACTION BUTTON
                _buildBottomControl(appState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Top Status Bar Component
  Widget _buildTopHUDHeader(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFF00F3FF).withOpacity(0.4), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "SYNAPSE CORE v4.0",
            style: TextStyle(color: Color(0xFF00F3FF), fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          Row(
            children: [
              Text(
                appState.isServiceRunning ? "24/7 ACTIVE" : "STANDBY",
                style: TextStyle(
                  color: appState.isServiceRunning ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: Icon(
                  appState.isServiceRunning ? Icons.bolt : Icons.power_settings_new,
                  color: appState.isServiceRunning ? Colors.greenAccent : Colors.redAccent,
                ),
                onPressed: () => appState.toggleBackgroundService(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bottom Control Button
  Widget _buildBottomControl(AppState appState) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: appState.isListening ? Colors.redAccent : const Color(0xFF00F3FF),
            width: 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: appState.isListening
              ? Colors.redAccent.withOpacity(0.2)
              : const Color(0xFF00F3FF).withOpacity(0.1),
        ),
        onPressed: () {
          if (appState.isListening) {
            appState.stopListening();
          } else {
            appState.startListening();
          }
        },
        icon: Icon(
          appState.isListening ? Icons.stop : Icons.mic_none,
          color: appState.isListening ? Colors.redAccent : const Color(0xFF00F3FF),
        ),
        label: Text(
          appState.isListening ? "VOICE OVERRIDE (STOP)" : "INITIALIZE VOICE COMMAND",
          style: TextStyle(
            color: appState.isListening ? Colors.redAccent : const Color(0xFF00F3FF),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
