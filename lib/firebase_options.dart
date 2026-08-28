import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web is not configured.');
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Firebase is not configured for $defaultTargetPlatform.',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIqSZ6Z24Job2fqE1xs238cCuHJia1lXM',
    appId: '1:421197495610:android:ebf40b27f118a360c12403',
    messagingSenderId: '421197495610',
    projectId: 'elbiblio-fae32',
    storageBucket: 'elbiblio-fae32.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB_Lt63ojPEIJx069qJzY_mr1dDGWdqLw4',
    appId: '1:421197495610:ios:c7cfb9ed30e59e25c12403',
    messagingSenderId: '421197495610',
    projectId: 'elbiblio-fae32',
    storageBucket: 'elbiblio-fae32.firebasestorage.app',
    iosBundleId: 'com.elbiblio.catholicdaily',
  );
}
