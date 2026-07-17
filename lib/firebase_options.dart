// Placeholder generated-file shape.
//
// Run flutterfire configure from the project root before launching the app.
// FlutterFire will replace this file with the real values for your project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => ios,
      TargetPlatform.windows => web,
      TargetPlatform.linux => web,
      TargetPlatform.fuchsia => web,
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBHmGN4RDsn-KJY3BnMciYp8B6XuD8UD9I',
    appId: '1:412217920336:web:864d5f25ae304cb94a7a55',
    messagingSenderId: '412217920336',
    projectId: 'el-ezala',
    authDomain: 'el-ezala.firebaseapp.com',
    storageBucket: 'el-ezala.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJDFT2BxdP-1JBml2fz3d78ctSAezoNik',
    appId: '1:412217920336:android:cf920651d987ff0a4a7a55',
    messagingSenderId: '412217920336',
    projectId: 'el-ezala',
    storageBucket: 'el-ezala.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBCGiJtXhsHsIiscR_6CLjSSXcs_Bz0Ejw',
    appId: '1:412217920336:ios:b07c2e9d4e6d4c564a7a55',
    messagingSenderId: '412217920336',
    projectId: 'el-ezala',
    storageBucket: 'el-ezala.firebasestorage.app',
    iosBundleId: 'com.mmr.mmrCabinetsApp',
  );
}
