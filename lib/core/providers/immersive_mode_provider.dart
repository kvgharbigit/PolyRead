// Immersive Mode Provider
// Manages immersive reading mode state across the app

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for immersive mode state
final immersiveModeProvider = StateNotifierProvider<ImmersiveModeNotifier, bool>((ref) {
  return ImmersiveModeNotifier();
});

class ImmersiveModeNotifier extends StateNotifier<bool> {
  ImmersiveModeNotifier() : super(false);

  void setImmersiveMode(bool isImmersive) {
    state = isImmersive;
  }

  void toggle() {
    state = !state;
  }
}