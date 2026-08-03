import 'package:flutter/foundation.dart';
import '../services/phone_call_service.dart';
import '../services/overlay_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// State management provider for phone call actions and overlay lifecycle.
///
/// Responsibilities:
/// - Delegating telephony operations to [PhoneCallService].
/// - Driving [OverlayService] to show/hide the floating return button.
/// - Exposing [pendingReviewContactId] so [ContactDetailScreen] knows when
///   the user has tapped the overlay button and navigation should fire.
/// - Tracking overlay permission state for the in-app permission banner.
///
/// Separation of concerns:
/// - [PhoneCallService] owns telephony hardware (making calls).
/// - [OverlayService] owns the MethodChannel bridge to the native overlay.
/// - This provider owns call and overlay state; it does NOT navigate directly.
class PhoneCallProvider extends ChangeNotifier {
  PhoneCallProvider({
    PhoneCallService? service,
    OverlayService? overlayService,
  })  : _service = service ?? PhoneCallService(),
        _overlayService = overlayService ?? OverlayService();

  final PhoneCallService _service;
  final OverlayService _overlayService;

  // ── Loading / error state ──────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  CallLaunchResult? _lastCallResult;
  CallLaunchResult? get lastCallResult => _lastCallResult;

  bool _isCallActive = false;
  bool get isCallActive => _isCallActive;

  // ── Overlay navigation signal ──────────────────────────────────────────

  /// Non-null when the user tapped the floating overlay button.
  ///
  /// [ContactDetailScreen] watches this field via an [addListener] subscription.
  /// When the value matches the screen's own contactId, the screen navigates
  /// to [PostCallReviewScreen] and calls [clearPendingReview] to consume it.
  String? _pendingReviewContactId;
  String? get pendingReviewContactId => _pendingReviewContactId;

  // ── Overlay permission state ───────────────────────────────────────────

  /// Cached result of the SYSTEM_ALERT_WINDOW permission check.
  ///
  /// `null` means not yet checked (optimistically treated as `true` so the
  /// permission banner does not flash on first render before the check runs).
  bool? _overlayPermissionGranted;

  /// Whether the SYSTEM_ALERT_WINDOW permission is currently granted.
  ///
  /// Defaults to `true` before the first [refreshOverlayPermission] call so
  /// the in-app banner does not flicker on initial load.
  bool get overlayPermissionGranted => _overlayPermissionGranted ?? true;

  // ── Initialisation ─────────────────────────────────────────────────────

  /// Registers the MethodChannel callback for overlay button taps.
  ///
  /// Must be called once immediately after construction (see [main.dart]).
  void initialize() {
    _overlayService.setOverlayButtonTappedHandler((contactId) {
      // The user tapped the floating button. Signal ContactDetailScreen to
      // navigate to PostCallReviewScreen for this contact.
      _pendingReviewContactId = contactId;
      _isCallActive = false;
      notifyListeners();
    });
  }

  // ── Call initiation ────────────────────────────────────────────────────

  /// Initiates a phone call to [phoneNumber] and shows the floating overlay
  /// button above the Phone dialer.
  ///
  /// [contactId] is passed to the overlay service so it knows which contact's
  /// review screen to open when the button is tapped.
  Future<bool> initiateCall(String phoneNumber, String contactId) async {
    _isLoading = true;
    _errorMessage = null;
    _lastCallResult = null;
    _isCallActive = true;
    _pendingReviewContactId = null;
    notifyListeners();

    try {
      final result = await _service.makeDirectPhoneCall(phoneNumber);
      _lastCallResult = result;
      _isLoading = false;
      notifyListeners();

      // Show the floating button so the user has a visible way to return
      // to the app after the call ends.
      await _overlayService.showOverlay(contactId);

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

  // ── Overlay management ─────────────────────────────────────────────────

  /// Hides the floating overlay button and resets call-active state.
  ///
  /// Called when the calling sequence is cancelled or completed, ensuring
  /// the button does not linger after the session ends.
  Future<void> dismissOverlay() async {
    await _overlayService.hideOverlay();
    _isCallActive = false;
    _pendingReviewContactId = null;
    notifyListeners();
  }

  /// Marks the pending navigation signal as consumed.
  ///
  /// Called by [ContactDetailScreen] immediately before scheduling navigation
  /// to prevent the listener from firing a second time.
  void clearPendingReview() {
    _pendingReviewContactId = null;
    // Intentionally not calling notifyListeners() — this is a one-way consume.
  }

  // ── Permission helpers ─────────────────────────────────────────────────

  /// Checks and caches whether SYSTEM_ALERT_WINDOW is granted.
  ///
  /// Triggers a rebuild via [notifyListeners] if the result changed, which
  /// shows or hides the permission banner in [ContactDetailScreen].
  Future<void> refreshOverlayPermission() async {
    final granted = await _overlayService.checkPermission();
    if (granted != _overlayPermissionGranted) {
      _overlayPermissionGranted = granted;
      notifyListeners();
    }
  }

  /// Opens the Android system settings screen to request the overlay permission,
  /// then re-checks the result after the user returns.
  Future<void> requestOverlayPermission() async {
    await _overlayService.requestPermission();
    // Give the OS time to process the settings change before re-querying.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await refreshOverlayPermission();
  }

  // ── Error management ───────────────────────────────────────────────────

  /// Clears any active error message or launch result notification.
  void clearError() {
    _errorMessage = null;
    _lastCallResult = null;
    notifyListeners();
  }
}
