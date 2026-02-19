import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Jedyna definicja sharedPrefsProvider w projekcie.
/// Nadpisywana w ProviderScope w main.dart:
///   overrides: [sharedPrefsProvider.overrideWithValue(prefs)]
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'sharedPrefsProvider nie został nadpisany w ProviderScope'),
);