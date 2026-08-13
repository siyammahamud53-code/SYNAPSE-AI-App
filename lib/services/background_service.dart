import 'dart:async';
import 'dart:ui';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ব্যাকগ্রাউন্ড টাস্ক এর আসল হ্যান্ডলার
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyBackgroundTaskHandler());
}

class MyBackgroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // ব্যাকগ্রাউন্ড কাজ শুরুর লজিক
    print("Synapse AI Background Service Started at $timestamp");
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    // ব্যাকগ্রাউন্ডে কোনো কাজ রানিং রাখার সময়
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print("Background Service Destroyed");
  }

  @override
  void ButtonPressed(String id) {
    // নোটিফিকেশনের বাটনে প্রেস করলে কি হবে
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}

class BackgroundService {
  static Future<void> initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'synapse_bg_channel',
        channelName: 'Synapse AI Service',
        channelDescription: 'Running ambient listening & brain sync',
        channelImportance: NotificationImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'Synapse AI Active',
        notificationText: 'Listening in background & Synced with Brain',
        callback: startCallback,
      );
    }
  }

  static Future<bool> stopService() async {
    return FlutterForegroundTask.stopService();
  }
}
