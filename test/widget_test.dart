import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_weather_app_v2/main.dart';

void main() {
  testWidgets('Home page renders', (WidgetTester tester) async {
    // Use a phone-sized surface so the layout has room.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Forecasts'), findsOneWidget);
  });
}
