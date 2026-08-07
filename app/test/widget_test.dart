import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famil_app/screens/auth/login_screen.dart';
import 'package:famil_app/services/kst_time.dart';

void main() {
  KstTime.init();

  testWidgets('로그인 화면이 렌더링된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('로그인'), findsWidgets);
    expect(find.text('아이디'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
  });
}
