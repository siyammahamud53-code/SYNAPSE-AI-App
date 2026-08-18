import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SynapseApp());
}

class SynapseApp extends StatelessWidget {
  const SynapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SYNAPSE AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030A16),
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

class _HUDScreenState extends State<HUDScreen> {
  bool isCameraActive = false;
  bool isListening = false;
  String statusText = 'SYSTEM READY: Standby Mode';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF00F3FF), width: 0.5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SYNAPSE SMART-CORE v6.5", style: TextStyle(color: Color(0xFF00F3FF), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  Text("ONLINE", style: TextStyle(color: Color(0xFF00FF88), fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
            
            // Middle Reactor Display
            Expanded(
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isCameraActive ? const Color(0xFF00FF88) : const Color(0xFF00F3FF), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: (isCameraActive ? const Color(0xFF00FF88) : const Color(0xFF00F3FF)).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isCameraActive ? Icons.videocam : Icons.graphic_eq,
                      size: 60,
                      color: isCameraActive ? const Color(0xFF00FF88) : const Color(0xFF00F3FF),
                    ),
                  ),
                ),
              ),
            ),

            // System Status Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00F3FF).withOpacity(0.3)),
              ),
              child: Text("> $statusText", style: const TextStyle(color: Color(0xFF00F3FF), fontFamily: 'monospace', fontSize: 12)),
            ),

            const SizedBox(height: 12),

            // Controls Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0x1A00F3FF),
                        side: const BorderSide(color: Color(0xFF00F3FF)),
                      ),
                      onPressed: () {
                        setState(() {
                          isCameraActive = !isCameraActive;
                          statusText = isCameraActive ? "AIR GESTURE: ACTIVATED" : "AIR GESTURE: DEACTIVATED";
                        });
                      },
                      child: Text(isCameraActive ? "STOP CAMERA" : "START CAMERA", style: const TextStyle(color: Color(0xFF00F3FF), fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0x1A00FF88),
                        side: const BorderSide(color: Color(0xFF00FF88)),
                      ),
                      onPressed: () {
                        setState(() {
                          isListening = !isListening;
                          statusText = isListening ? "VOICE ENGINE: LISTENING..." : "VOICE ENGINE: STANDBY";
                        });
                      },
                      child: Text(isListening ? "STOP VOICE" : "START VOICE", style: const TextStyle(color: Color(0xFF00FF88), fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
