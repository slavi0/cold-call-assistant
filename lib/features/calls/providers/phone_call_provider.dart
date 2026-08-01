import 'package:flutter/foundation.dart';
import '../services/phone_call_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// State management provider for phone call actions and lifecycle responses.
///
/// Handles call state (loading, error, fallback notifications) and delegates
/// telephony hardware operations to [PhoneCallService].
class PhoneCallProvider extends ChangeNotifier {
  PhoneCallProvider({PhoneCallService? service})
      : _service = service ?? PhoneCallService();

  final PhoneCallService _service;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  CallLaunchResult? _lastCallResult;
  CallLaunchResult? get lastCallResult => _lastCallResult;

  bool _isCallActive = false;
  bool get isCallActive => _isCallActive;

  /// Initiates a phone call to [phoneNumber].
  ///
  /// Uses direct calling (`Intent.ACTION_CALL`) if runtime permissions are granted,
  /// or falls back to system dialer if permission is denied.
  Future<bool> initiateCall(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _lastCallResult = null;
    _isCallActive = true;
    notifyListeners();

    try {
      final result = await _service.makeDirectPhoneCall(phoneNumber);
      _lastCallResult = result;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      _isCallActive = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to make call due to an unexpected error.';
      _isLoading = false;
      _isCallActive = false;
      notifyListeners();
      return false;
    }
  }

  /// Called when the application returns to the foreground (`AppLifecycleState.resumed`).
  ///
  /// Resets active call loading state so the user is immediately greeted with a fresh UI
  /// upon returning from a call.
  void handleAppResumed() {
    if (_isCallActive || _isLoading) {
      _isCallActive = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears any active error message or launch result notification.
  void clearError() {
    _errorMessage = null;
    _lastCallResult = null;
    notifyListeners();
  }
}
