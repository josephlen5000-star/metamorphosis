import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB2PSSD3G67G76J2qq78Co6RhMMFj1GE5k',
    authDomain: 'metamorphosis-66fd1.firebaseapp.com',
    storageBucket: 'metamorphosis-66fd1.firebasestorage.app',
    appId: '1:5863588128:web:9a27a2db40e98ff00b1745',
    messagingSenderId: '5863588128',
    projectId: 'metamorphosis-66fd1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGR4iRDiZOmoNhMD_Zsgheg87fR3H_Lz8',
    appId: '1:5863588128:android:605fbe0341c0aec00b1745',
    messagingSenderId: '5863588128',
    projectId: 'metamorphosis-66fd1',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA41XGMzb1jlRcLn0LV5Boi-abZ2Pt8PdA',
    appId: '1:5863588128:ios:c839d377080796170b1745',
    messagingSenderId: '5863588128',
    projectId: 'metamorphosis-66fd1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY',
    appId: 'YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_LINUX_API_KEY',
    appId: 'YOUR_LINUX_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
  );

  static FirebaseOptions get currentPlatform {
    // ignore: deprecated_member_use
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return web;
    }
  }
}
