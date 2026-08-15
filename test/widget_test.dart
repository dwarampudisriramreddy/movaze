// Smoke tests for the movaze app: home screen, navigation into a game, and
// the feature indicators shown for high levels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movaze/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget app() => const MovazeApp(skipSplash: true);

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
  }

  testWidgets('Home screen shows daily challenge, play and worlds',
      (WidgetTester tester) async {
    await pumpHome(tester);

    expect(find.text('MOVAZE'), findsOneWidget);
    expect(find.text('CHALLENGES'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('WORLD 1'), findsOneWidget);
    expect(find.byType(MazeGame), findsNothing);
  });

  testWidgets('PLAY starts the game with D-pad and moves counter',
      (WidgetTester tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(MazeGame), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsWidgets);
    expect(find.byIcon(Icons.arrow_downward), findsWidgets);
    expect(find.text('MOVES'), findsOneWidget);
  });

  testWidgets('tapping a level tile starts at that level, not the saved one',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'maxLevel': 25,
      'level': 25,
    });

    await pumpHome(tester);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(MazeGame), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);
  });

  testWidgets('Level 3 shows shield buy chip but no FOG/BOSS/keys',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        initialLevel: 3,
      ),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.shield_outlined), findsWidgets);
    expect(find.text('FOG'), findsNothing);
    expect(find.text('BOSS'), findsNothing);
    expect(find.byIcon(Icons.key), findsNothing);
  });

  testWidgets('Level 16 shows FOG, keys and shield indicators',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        initialLevel: 16,
      ),
    ));
    await tester.pump();

    expect(find.text('FOG'), findsOneWidget);
    expect(find.text('BOSS'), findsNothing);
    expect(find.byIcon(Icons.key), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsWidgets);
  });

  testWidgets('Dark mode toggle switches theme on the home screen',
      (WidgetTester tester) async {
    await pumpHome(tester);

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.text('MOVAZE'), findsOneWidget);
  });

  testWidgets('Infinity mode shows ∞ HUD, all features and its entry hint',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        infinityMode: true,
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('∞ 26'), findsOneWidget);
    expect(find.text('FOG'), findsOneWidget);
    expect(find.text('BOSS'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsWidgets);
    expect(find.text('INFINITY WORLD'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsNothing);
  });

  testWidgets('Infinity mode resumes from the last reached level',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'infinityLevel': 42});

    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        infinityMode: true,
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('∞ 42'), findsOneWidget);
  });

  testWidgets('Daily challenge shows its entry hint dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        dailyMode: true,
        dailySeed: 20250101,
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('CHALLENGES'), findsOneWidget);
    expect(find.text('CHALLENGES 2'), findsOneWidget);
  });

  MazePainter mazePainter(WidgetTester tester) {
    final cp = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is MazePainter));
    return cp.painter as MazePainter;
  }

  testWidgets('Big mazes default to a zoomed player view with zoom buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        initialLevel: 12,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(mazePainter(tester).zoom, greaterThan(1.0));
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);

    final before = mazePainter(tester).zoom;
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(mazePainter(tester).zoom, greaterThan(before));

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(mazePainter(tester).zoom, before);
  });

  testWidgets('Small mazes show the whole board (zoom stays 1)',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        initialLevel: 1,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(mazePainter(tester).zoom, 1.0);
  });

  testWidgets('no right overflow on a narrow screen with all features',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: MazeGame(
        isDark: false,
        onToggleDark: () {},
        initialLevel: 21,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('FOG'), findsOneWidget);
    expect(find.text('BOSS'), findsOneWidget);
  });
}
