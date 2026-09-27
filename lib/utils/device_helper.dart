import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceHelper {
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('device_id');
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    String? id;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        const androidIdPlugin = AndroidId();
        id = await androidIdPlugin.getId();
      } catch (e) {
        debugPrint('Error getting androidId: $e');
      }
    }

    if (id == null || id.isEmpty) {
      id = 'dev-${const Uuid().v4().substring(0, 8)}';
    }

    await prefs.setString('device_id', id);
    return id;
  }
}
