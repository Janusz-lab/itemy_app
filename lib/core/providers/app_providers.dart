import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jedyna definicja sharedPrefsProvider w projekcie.
/// Nadpisywana w ProviderScope w main.dart:
///   overrides: [sharedPrefsProvider.overrideWithValue(prefs)]
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'sharedPrefsProvider nie został nadpisany w ProviderScope'),
);

/// true = skaner kamerowy, false = wpisywanie ręczne
final scannerModeProvider = StateNotifierProvider<ScannerModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return ScannerModeNotifier(prefs);
});

class ScannerModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const _key = 'scanner_camera_mode';

  ScannerModeNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  void toggle() {
    state = !state;
    _prefs.setBool(_key, state);
  }

  void set(bool value) {
    state = value;
    _prefs.setBool(_key, value);
  }
}