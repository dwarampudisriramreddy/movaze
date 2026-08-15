import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:movaze/main.dart';

void main() {
  test('no enemy is blocked by another for long or ever overlaps', () {
    final issues = <String>[];
    outer:
    for (var size = 7; size <= 25; size += 2) {
      for (final count in [2, 3, 4]) {
        if (count >= size ~/ 2) continue;
        for (var trial = 0; trial < 60; trial++) {
          final maze = Maze(size, enemyCount: count);
          final rng = Random(trial);
          final blockedTicks = List<int>.filled(count, 0);
          for (var step = 0; step < 3000; step++) {
            for (var i = 0; i < count; i++) {
              final e = maze.enemies[i];
              // Single-cell arcs never move (matches Maze.advanceEnemy).
              if (e.startIndex == e.endIndex) continue;
              var next = e.patrolIndex + e.dir;
              if (next < e.startIndex || next > e.endIndex) {
                next = e.patrolIndex - e.dir;
              }
              final target = maze.patrolRoute[next];
              final blocked =
                  maze.enemies.any((o) => o.row == target.$1 && o.col == target.$2);
              if (blocked) {
                blockedTicks[i]++;
                if (blockedTicks[i] > 6) {
                  issues.add('BLOCKED size=$size count=$count trial=$trial '
                      'enemy=$i idx=${e.patrolIndex} range=${e.startIndex}-${e.endIndex} '
                      'dir=${e.dir} step=$step');
                  break outer;
                }
              } else {
                blockedTicks[i] = 0;
              }
              maze.advanceEnemy(e, rng: rng);
            }
            for (var a = 0; a < count; a++) {
              for (var b = a + 1; b < count; b++) {
                if (maze.enemies[a].row == maze.enemies[b].row &&
                    maze.enemies[a].col == maze.enemies[b].col) {
                  issues.add('OVERLAP size=$size count=$count trial=$trial '
                      'e$a@${maze.enemies[a].patrolIndex} '
                      'e$b@${maze.enemies[b].patrolIndex} step=$step');
                  break outer;
                }
              }
            }
          }
        }
      }
    }
    expect(issues, isEmpty, reason: issues.take(5).join('\n'));
  });
}
