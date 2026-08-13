import 'package:flutter/foundation.dart';
import '../services/brain_service.dart';
import '../services/voice_engine.dart';
import '../services/background_service.dart';

class AppState extends ChangeNotifier {
  final BrainService brainService = BrainService();
  final VoiceEngine voiceEngine = VoiceEngine();

  String _currentPersona = 'Ragna'; // Default Persona
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isServiceRunning = false;
  String _lastResponse = 'Synapse AI Ready';

  // Getters
  String get currentPersona => _currentPersona;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isServiceRunning => _isServiceRunning;
  String get lastResponse => _lastResponse;

  // ইনিশিয়ালাইজেশন
  Future<void> initApp() async {
    await voiceEngine.initVoice();
    await BackgroundService.initForegroundTask();
    
    // ব্রেইনে কানেক্ট করা
    brainService.connectBrain((response) {
      _lastResponse = response;
      _isSpeaking = true;
      notifyListeners();
      
      voiceEngine.speak(response).then((_) {
        _isSpeaking = false;
        notifyListeners();
      });
    });
  }

  // পার্সোনা চেঞ্জ করা (Ragna / Maya)
  Future<void> setPersona(String persona) async {
    _currentPersona = persona;
    notifyListeners();
    await brainService.switchPersona(persona);
  }

  // কথা বলা শুরু করা
  void startListening() {
    _isListening = true;
    notifyListeners();
    
    voiceEngine.startListening((userText) {
      _isListening = false;
      notifyListeners();
      if (userText.isNotEmpty) {
        brainService.sendToBrain(userText, _currentPersona);
      }
    });
  }

  void stopListening() {
    voiceEngine.stopListening();
    _isListening = false;
    notifyListeners();
  }

  // ব্যাকগ্রাউন্ড সার্ভিস টগল
  Future<void> toggleBackgroundService() async {
    if (_isServiceRunning) {
      await BackgroundService.stopService();
      _isServiceRunning = false;
    } else {
      await BackgroundService.startService();
      _isServiceRunning = true;
    }
    notifyListeners();
  }
}
