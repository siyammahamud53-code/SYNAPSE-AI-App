import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceEngine {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool isListening = false;

  Future<bool> initVoice() async {
    bool available = await _speech.initialize(
      onError: (val) => print('STT Error: $val'),
      onStatus: (val) => print('STT Status: $val'),
    );
    
    await _tts.setLanguage("bn-BD"); // বাংলা ভয়েস আউটপুট
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    return available;
  }

  // কথা শোনা শুরু করা
  void startListening(Function(String) onResult) async {
    if (!isListening) {
      isListening = true;
      await _speech.listen(
        onResult: (val) {
          if (val.finalResult) {
            isListening = false;
            onResult(val.recognizedWords);
          }
        },
      );
    }
  }

  // কথা শোনা থামানো
  void stopListening() async {
    if (isListening) {
      await _speech.stop();
      isListening = false;
    }
  }

  // AI-এর উত্তর মুখে বলা (TTS)
  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _tts.stop();
      await _tts.speak(text);
    }
  }

  // ভয়েস বন্ধ করা
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
