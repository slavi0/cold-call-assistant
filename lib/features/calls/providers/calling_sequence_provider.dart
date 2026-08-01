import 'package:flutter/foundation.dart';
import '../../contacts/models/contact_model.dart';

/// Manages the state of a sequential calling session.
///
/// When the user presses "Start Calling", a sequence is created from the
/// full contact list and this provider tracks progress through it.
///
/// Separation of concerns:
/// - [PhoneCallProvider] handles the telephony hardware (making/ending calls).
/// - [CallingSequenceProvider] handles workflow progression (which contact is
///   next, when the session is done, auto-advance on call end).
///
/// This split means neither provider has two responsibilities and neither
/// needs to know about the other.
class CallingSequenceProvider extends ChangeNotifier {
  List<ContactModel> _contacts = [];
  int _currentIndex = 0;
  bool _isSequenceActive = false;

  /// True when the user started a calling session via "Start Calling".
  bool get isSequenceActive => _isSequenceActive;

  /// Zero-based index of the contact currently being called.
  int get currentIndex => _currentIndex;

  /// Total number of contacts in the active sequence.
  int get totalContacts => _contacts.length;

  /// The contact currently on-screen. Null when no sequence is active.
  ContactModel? get currentContact =>
      _isSequenceActive && _currentIndex < _contacts.length
          ? _contacts[_currentIndex]
          : null;

  /// True when the current contact is the last one in the sequence.
  bool get isLastContact =>
      _isSequenceActive && _currentIndex >= _contacts.length - 1;

  /// Begins a new calling sequence with [contacts], starting from the first.
  ///
  /// If a sequence is already active it is replaced.
  void startSequence(List<ContactModel> contacts) {
    assert(contacts.isNotEmpty, 'Cannot start a sequence with an empty list.');
    _contacts = List.of(contacts); // defensive copy
    _currentIndex = 0;
    _isSequenceActive = true;
    notifyListeners();
  }

  /// Advances to the next contact in the sequence.
  ///
  /// Returns the next [ContactModel] if one exists, or `null` if the sequence
  /// is complete. Automatically stops the sequence when the last contact is
  /// passed.
  ContactModel? advanceToNext() {
    if (!_isSequenceActive) return null;

    _currentIndex++;
    if (_currentIndex >= _contacts.length) {
      _stopSequence();
      return null;
    }

    notifyListeners();
    return _contacts[_currentIndex];
  }

  /// Ends the sequence early (e.g. user navigates away manually).
  void cancelSequence() {
    _stopSequence();
  }

  void _stopSequence() {
    _isSequenceActive = false;
    _contacts = [];
    _currentIndex = 0;
    notifyListeners();
  }
}
