import 'package:flutter_phone_state/flutter_phone_state.dart';
import 'brain_service.dart';

class CallService {
  final BrainService _brainService = BrainService();

  void initCallListener() {
    // অ্যান্ড্রয়েডের ইনকামিং কল ট্র্যাক করার লিসেনার
    FlutterPhoneState.phoneCallEvents.listen((PhoneCallEvent event) {
      if (event.status == PhoneCallStatus.incoming) {
        print("Incoming call from: ${event.phoneNumber}");
        
        // ইনকামিং কলের কথা ব্রেইনকে জানানো
        _brainService.sendToBrain(
          "Incoming call detected from ${event.phoneNumber}", 
          "Ragna"
        );
      } else if (event.status == PhoneCallStatus.disconnected) {
        print("Call ended");
      }
    });
  }
}
