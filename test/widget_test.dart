import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amber_list/app.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AmberListApp(),
      ),
    );
    // 验证应用正常启动
    expect(find.text('琥珀清单'), findsWidgets);
  });
}
