import 'package:flutter/services.dart';

class FeedbackHelper {
  static Future<void> onTagDetected() async {
    await HapticFeedback.selectionClick();
  }

  static void onCreated() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void onVerified() {
    HapticFeedback.selectionClick();
  }

  static void onConflict() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      HapticFeedback.heavyImpact();
    });
  }

  static void onQueued() {
    HapticFeedback.lightImpact();
  }

  static void onWarning() {
    HapticFeedback.mediumImpact();
  }

  static void onReassigned() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  static void onError() {
    HapticFeedback.lightImpact();
  }
}
