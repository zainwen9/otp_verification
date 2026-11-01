import 'package:flutter_test/flutter_test.dart';

import 'package:otp_verification/main.dart';
import 'package:otp_verification/otp_verification_screen.dart';

void main() {
  testWidgets('OTP screen renders', (WidgetTester tester) async {
    otpUseGoogleFonts = false;
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Verify your number'), findsOneWidget);
    expect(find.text('Fill'), findsOneWidget);
  });
}
