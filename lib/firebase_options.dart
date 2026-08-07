// 이 파일은 자리표시자(placeholder)입니다.
//
// 실제 실행을 위해서는 아래 명령으로 여러분의 Firebase 프로젝트에 맞는
// 값으로 이 파일을 다시 생성해야 합니다.
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// 위 명령을 프로젝트 루트에서 실행하면 Android / Web / Windows(웹 설정 재사용)
// 옵션이 자동으로 채워진 이 파일이 새로 생성됩니다. 자세한 안내는 README.md의
// "Firebase 설정" 섹션을 참고하세요.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions는 이 플랫폼을 위한 설정이 없습니다. '
          "'flutterfire configure'를 실행해 firebase_options.dart를 다시 생성하세요.",
        );
    }
  }

  // 아래 값들은 실제 Firebase 프로젝트 값이 아닙니다.
  // `flutterfire configure` 실행 후 자동으로 교체됩니다.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  // Windows/Linux 데스크톱은 공식 Firebase SDK 플랫폼 지원 대상이 아니므로
  // web 설정 값(REST 기반)을 재사용합니다. flutterfire configure로
  // --platforms=windows 를 명시하면 자동으로 채워집니다.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );
}
