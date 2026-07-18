import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/startup_error.dart';
import 'core/theme_controller.dart';
import 'firebase_options.dart';

const String appVersion = 'V1.0.7';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();

  Object? startupError;
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.apiKey.startsWith('REPLACE_')) {
    startupError = const FirebaseSetupRequired();
  } else {
    try {
      await Firebase.initializeApp(options: options);
    } catch (error) {
      startupError = error;
    }
  }

  runApp(EzlaProjectApp(startupError: startupError));
}
