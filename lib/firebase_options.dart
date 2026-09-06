import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBTr6_tLfW52ex9BXEAfqSZGG4VEqqlw54',
    authDomain: 'metamorphosis-66fd1.firebaseapp.com',
    storageBucket: 'metamorphosis-66fd1.firebasestorage.app',
    appId: '1:5863588128:web:9a27a2db40e98ff00b1745',
    messagingSenderId: '5863588128',
    projectId: 'metamorphosis-66fd1',
  );

  static FirebaseOptions get currentPlatform => web;
}