import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'services/call_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // কল সার্ভিস চালু করা
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
      title: 'Synapse AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synapse AI Core'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              appState.isServiceRunning ? Icons.flash_on : Icons.flash_off,
              color: appState.isServiceRunning ? Colors.green : Colors.red,
            ),
            onPressed: () => appState.toggleBackgroundService(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAlignment.center,
          children: [
            // পার্সোনা সিলেক্টর (Ragna / Maya)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Ragna'),
                  selected: appState.currentPersona == 'Ragna',
                  onSelected: (_) => appState.setPersona('Ragna'),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Maya'),
                  selected: appState.currentPersona == 'Maya',
                  onSelected: (_) => appState.setPersona('Maya'),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // এআই ডিসপ্লে ও স্ট্যাটাস
            CircleAvatar(
              radius: 60,
              backgroundColor: appState.isListening 
                  ? Colors.redAccent 
                  : (appState.isSpeaking ? Colors.greenAccent : Colors.blueAccent),
              child: Icon(
                appState.isListening ? Icons.mic : Icons.smart_toy,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // ব্রেইনের দেওয়া লেটেস্ট রেসপন্স
            Text(
              appState.lastResponse,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),

            // ভয়েস মাইক্রোফোন বাটন
            ElevatedButton.icon(
              onPressed: () {
                if (appState.isListening) {
                  appState.stopListening();
                } else {
                  appState.startListening();
                }
              },
              icon: Icon(appState.isListening ? Icons.stop : Icons.mic),
              label: Text(appState.isListening ? 'কথা থামা' : 'কথা বলো'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
