import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/exceptions/app_exception.dart';

/// Result status of a phone call attempt.
enum CallLaunchResult {
  /// The call was initiated directly via Intent.ACTION_CALL without dialer confirmation.
  directCallPlaced,

  /// Direct calling permission was denied or unsupported; opened system dialer as fallback.
  fallbackDialerOpened,
}

/// Service responsible for interacting with system telephony intents.
///
/// Isolated from the UI and state management layers per MVVM rules.
class PhoneCallService {
  /// Attempts to place a direct phone call to [phoneNumber] without dialer confirmation.
  ///
  /// Requests [Permission.phone] (`CALL_PHONE`) at runtime.
  /// If permission is granted, initiates call via [FlutterPhoneDirectCaller].
  /// If permission is denied or direct call fails, falls back to opening the system dialer.
  Future<CallLaunchResult> makeDirectPhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');

    try {
      // 1. Check and request CALL_PHONE runtime permission
      final status = await Permission.phone.request();

      if (status.isGranted) {
        final directSuccess =
            await FlutterPhoneDirectCaller.callNumber(cleanNumber);
        if (directSuccess == true) {
          return CallLaunchResult.directCallPlaced;
        }
      }

      // 2. Fallback to system dialer if direct call permission denied or unsupported
      await makeDialerPhoneCall(cleanNumber);
      return CallLaunchResult.fallbackDialerOpened;
    } catch (e) {
      if (e is DeviceException) rethrow;

      // Fallback attempt
      try {
        await makeDialerPhoneCall(cleanNumber);
        return CallLaunchResult.fallbackDialerOpened;
      } catch (fallbackError) {
        throw DeviceException(
          'Failed to place phone call to $phoneNumber.',
          cause: e,
        );
      }
    }
  }

  /// Opens the system dialer application with [phoneNumber] pre-filled (`tel:` scheme).
  Future<void> makeDialerPhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        throw DeviceException(
          'This device cannot place phone calls to $phoneNumber. Dialer application not available.',
        );
      }

      final launched = await launchUrl(uri);
      if (!launched) {
        throw DeviceException(
          'Failed to launch system dialer for $phoneNumber.',
        );
      }
    } on DeviceException {
      rethrow;
    } catch (e) {
      throw DeviceException(
        'An unexpected error occurred while launching phone call.',
        cause: e,
      );
    }
  }
}
