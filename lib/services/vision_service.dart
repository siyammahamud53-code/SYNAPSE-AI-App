import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:image/image.dart' as img;

class VisionService {
  static Uint8List? _lastFrameBytes;
  static final Battery _battery = Battery();
  static DateTime _lastProcessTime = DateTime.now();

  /// মিলি-সেকেন্ড আল্ট্রা-ফাস্ট গেমিং ভিশন সার্ভিস
  static Future<Uint8List?> processFrameLocally(Uint8List rawFrameBytes) async {
    int batteryLevel = await _battery.batteryLevel;
    DateTime now = DateTime.now();

    // মিলি-সেকেন্ড স্কেল লজিক
    int minIntervalMs = 100; // নরমাল মোড: ১০০ মিলি-সেকেন্ড (১ সেকেন্ডে ১০ ফ্রেম - আল্ট্রা ফাস্ট)

    if (batteryLevel < 15) {
      minIntervalMs = 500; // চার্জ ১৫% এর নিচে নামলে ৫০০ মিলি-সেকেন্ড (০.৫ সেকেন্ড)
    } else if (batteryLevel < 30) {
      minIntervalMs = 250; // চার্জ ৩০% এর নিচে নামলে ২৫০ মিলি-সেকেন্ড (০.২৫ সেকেন্ড)
    }

    // ১০০ মিলি-সেকেন্ডের আগে পরবর্তী ফ্রেম প্রসেস করবে না (ফোন অতিরিক্ত হিট আটকাবে)
    if (now.difference(_lastProcessTime).inMilliseconds < minIntervalMs) {
      return null;
    }

    _lastProcessTime = now;
    return compute(_optimizeAndCompare, rawFrameBytes);
  }

  /// আলাদা আইসোলেটে ফোনের CPU/RAM/GPU ব্যবহার করে প্রসেস
  static Uint8List? _optimizeAndCompare(Uint8List bytes) {
    img.Image? decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) return null;

    // রেজোলিউশন ৩৬০ পিক্সেল (রেসপন্স দ্রুত ও জিপিইউ কোটা কমানোর জন্য)
    img.Image resized = img.copyResize(decodedImage, width: 360);
    Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 60));

    // ফ্রেম পার্থক্য চেক (যদি ফ্রেমে কোনো এনিমি বা নড়াচড়া না থাকে তবে হাগিং ফেসে যাবে না)
    if (_lastFrameBytes != null) {
      bool isSignificantChange = _hasSignificantChange(_lastFrameBytes!, compressedBytes);
      if (!isSignificantChange) {
        return null; // অনর্থক রিকোয়েস্ট বন্ধ -> কোটা ও ব্যাটারি ২টাই সেইভ!
      }
    }

    _lastFrameBytes = compressedBytes;
    return compressedBytes;
  }

  // মিলি-সেকেন্ড পিক্সেল কালার ও মুভমেন্ট ডিটেকশন
  static bool _hasSignificantChange(Uint8List oldFrame, Uint8List newFrame) {
    if (oldFrame.length != newFrame.length) return true;
    int diffCount = 0;
    for (int i = 0; i < oldFrame.length; i += 80) { // মিলি-সেকেন্ড স্যাম্পলিং
      if ((oldFrame[i] - newFrame[i]).abs() > 25) {
        diffCount++;
      }
      if (diffCount > 20) return true; // চোখের পলকে সামান্য নড়াচড়া ধরলেই অ্যাকশন!
    }
    return false;
  }
}
