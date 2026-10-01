import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daily_app/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Daily Quest app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyQuestApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('DAILY QUEST'), findsOneWidget);
  });
}
