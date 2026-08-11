// Basic smoke test for the movaze game.
//
// Verifies the app builds and that the maze board and on-screen
// directional controls are present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movaze/main.dart';

void main() {
  testWidgets('Maze game smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MovazeApp(skipSplash: true));

    expect(find.text('MOVAZE'), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(MazeGame), findsOneWidget);
  });

  testWidgets('D-pad controls are present', (WidgetTester tester) async {
    await tester.pumpWidget(const MovazeApp(skipSplash: true));

    expect(find.byIcon(Icons.arrow_upward), findsWidgets);
    expect(find.byIcon(Icons.arrow_downward), findsWidgets);
    expect(find.byIcon(Icons.arrow_back), findsWidgets);
    expect(find.byIcon(Icons.arrow_forward), findsWidgets);
  });

  testWidgets('Dark mode toggle switches theme', (WidgetTester tester) async {
    await tester.pumpWidget(const MovazeApp(skipSplash: true));

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.text('MOVAZE'), findsOneWidget);
  });
}
