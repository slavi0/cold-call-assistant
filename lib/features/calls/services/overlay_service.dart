import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter-side wrapper around the Android [FloatingOverlayService] MethodChannel.
///
/// Responsible for:
/// - Starting / stopping the native overlay via [showOverlay] / [hideOverlay].
/// - Checking and requesting the SYSTEM_ALERT_WINDOW permission.
/// - Wiring up the callback that fires when the user taps the overlay button.
///
/// All methods are silent no-ops on non-Android platforms.
/// This class is a pure service — no UI, no state, no ChangeNotifier.
/// It is injected into [PhoneCallProvider] and owned by that provider.
class OverlayService {
  static const _channel = MethodChannel(
    'com.example.cold_call_assistant/overlay',
  );

  /// Registers [handler] as the callback invoked when the user taps the
  /// floating overlay button.
  ///
  /// The native side forwards a `contactId` string so the handler can open
  /// the correct post-call review screen. This must be called once during
  /// app initialisation (see [PhoneCallProvider.initialize]).
  void setOverlayButtonTappedHandler(void Function(String contactId) handler) {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOverlayButtonTapped') {
        final contactId = call.arguments as String?;
        if (contactId != null && contactId.isNotEmpty) {
          handler(contactId);
        }
      }
    });
  }

  /// Returns `true` if the Android SYSTEM_ALERT_WINDOW permission is granted.
  ///
  /// Always returns `true` on non-Android platforms (the overlay is not used).
  Future<bool> checkPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final result = await _channel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the Android system settings screen where the user can grant
  /// the SYSTEM_ALERT_WINDOW ("Display over other apps") permission.
  ///
  /// This is the only way to request this permission on Android 6+ (API 23+).
  Future<void> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on PlatformException {
      // The settings intent failed — nothing more we can do.
    }
  }

  /// Starts the native [FloatingOverlayService], showing the floating button
  /// above all other apps.
  ///
  /// [contactId] is stored by the native service so that when the button is
  /// tapped, it can tell Flutter which contact's review screen to open.
  ///
  /// Silently fails if the SYSTEM_ALERT_WINDOW permission is not granted.
  Future<void> showOverlay(String contactId) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(
        'showOverlay',
        {'contactId': contactId},
      );
    } on PlatformException {
      // Permission not granted or service unavailable — degrade silently.
      // The user can still return to the app manually.
    }
  }

  /// Stops the native [FloatingOverlayService], removing the floating button.
  Future<void> hideOverlay() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('hideOverlay');
    } on PlatformException {
      // Already hidden or not running — silently ignore.
    }
  }
}
