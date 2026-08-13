import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class BrainService {
  final String baseUrl = 'https://siyammahamud53-synapse-ai-core.hf.space';
  final String wsUrl = 'wss://siyammahamud53-synapse-ai-core.hf.space/ws';
  
  WebSocketChannel? _channel;
  bool isConnected = false;
  
  // ব্রেইনের সাথে WebSocket কানেকশন স্থাপন
  void connectBrain(Function(String) onMessageReceived) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      isConnected = true;
      
      _channel!.stream.listen(
        (data) {
          final decoded = jsonDecode(data);
          if (decoded.containsKey('response')) {
            onMessageReceived(decoded['response']);
          }
        },
        onError: (error) {
          isConnected = false;
          print("Brain WebSocket Error: $error");
        },
        onDone: () {
          isConnected = false;
          print("Brain WebSocket Connection Closed");
        },
      );
    } catch (e) {
      isConnected = false;
      print("Brain Connection Failed: $e");
    }
  }

  // পার্সোনা সুইচ (Ragna / Maya / Jarvis) এর জন্য ব্রেইনে নোটিফাই করা
  Future<bool> switchPersona(String personaName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/persona/switch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'persona': personaName}),
      );
      
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print("Error switching persona: $e");
    }
    return false;
  }

  // ব্রেইনে টেক্সট/ভয়েস প্রম্পট পাঠানো
  void sendToBrain(String userInput, String activePersona) {
    if (isConnected && _channel != null) {
      final payload = jsonEncode({
        'user_input': userInput,
        'persona': activePersona,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _channel!.sink.add(payload);
    } else {
      print("Brain disconnected. Reconnecting...");
    }
  }

  void closeConnection() {
    _channel?.sink.close();
    isConnected = false;
  }
}
