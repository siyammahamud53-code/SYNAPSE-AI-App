import 'package:flutter/foundation.dart';
import 'ldpc_network_service.dart';
import 'threegpp_cellular_service.dart';

class HybridBrainRouter {
  final LDPCNetworkService ldpcService = LDPCNetworkService();
  final ThreeGPPCellularService cellularService = ThreeGPPCellularService();

  Future<void> initRouter() async {
    await cellularService.initializeNativeStack();
    await ldpcService.connectLDPC();
  }

  Future<void> routeTask({required String taskName, required Map<String, dynamic> data, bool isHeavy = false}) async {
    if (isHeavy && ldpcService.isConnected) {
      debugPrint("Routing '$taskName' to LDPC Cloud Engine.");
      await ldpcService.sendHeavyPayload(data);
    } else {
      debugPrint("Routing '$taskName' to 3GPP Local Edge Stack.");
      await cellularService.executeFastDeviceTask(taskName);
    }
  }
}
