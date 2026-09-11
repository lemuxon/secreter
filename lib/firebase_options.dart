import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Firebase yapilandirmasi (google-services.json degerlerinden uretildi).
/// Gradle google-services eklentisi yerine dogrudan Dart tarafinda verilir.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions yalnizca Android icin yapilandirildi.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBC_2k4S6jmvqqMLC1gePtOo3wO3GjWD3Q',
    appId: '1:403919128373:android:015d3fe827bb60f6f3ee7c',
    messagingSenderId: '403919128373',
    projectId: 'gizlichat-f2a99',
    storageBucket: 'gizlichat-f2a99.firebasestorage.app',
  );
}
