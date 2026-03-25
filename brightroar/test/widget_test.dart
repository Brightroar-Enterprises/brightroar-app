import 'package:flutter_test/flutter_test.dart';
import 'package:brightroar/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BrightroarApp());

    // Verify the splash screen branding is present
    expect(find.text('BRIGHTROAR CORP.'), findsOneWidget);
    expect(find.text('ASSET MANAGER'), findsOneWidget);

    // Verify the two main action buttons exist
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });
}
