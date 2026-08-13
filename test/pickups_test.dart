import 'package:movaze/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same seed produces an identical maze', () {
    final a = Maze(11, enemyCount: 3, seed: 12345);
    final b = Maze(11, enemyCount: 3, seed: 12345);
    expect(a.patrolRoute, b.patrolRoute);
    expect(a.coins, b.coins);
    expect(a.boostSpot, b.boostSpot);
    expect(a.enemies.length, b.enemies.length);
    for (var i = 0; i < a.enemies.length; i++) {
      expect(a.enemies[i].row, b.enemies[i].row);
      expect(a.enemies[i].col, b.enemies[i].col);
      expect(a.enemies[i].startIndex, b.enemies[i].startIndex);
      expect(a.enemies[i].endIndex, b.enemies[i].endIndex);
    }
    for (var r = 0; r < a.size; r++) {
      for (var c = 0; c < a.size; c++) {
        expect(a.cells[r][c].top, b.cells[r][c].top);
        expect(a.cells[r][c].right, b.cells[r][c].right);
        expect(a.cells[r][c].bottom, b.cells[r][c].bottom);
        expect(a.cells[r][c].left, b.cells[r][c].left);
      }
    }
  });

  test('coins and boost are reachable from the start', () {
    for (final level in [1, 3, 5, 8]) {
      final size = 2 * level + 5;
      for (var rep = 0; rep < 6; rep++) {
        final maze = Maze(size, enemyCount: level);
        final seen = List.generate(size, (_) => List<bool>.filled(size, false));
        final queue = <(int, int)>[(0, 0)];
        seen[0][0] = true;
        while (queue.isNotEmpty) {
          final (r, c) = queue.removeAt(0);
          final cell = maze.cells[r][c];
          if (!cell.top && !seen[r - 1][c]) {
            seen[r - 1][c] = true;
            queue.add((r - 1, c));
          }
          if (!cell.right && !seen[r][c + 1]) {
            seen[r][c + 1] = true;
            queue.add((r, c + 1));
          }
          if (!cell.bottom && !seen[r + 1][c]) {
            seen[r + 1][c] = true;
            queue.add((r + 1, c));
          }
          if (!cell.left && !seen[r][c - 1]) {
            seen[r][c - 1] = true;
            queue.add((r, c - 1));
          }
        }
        for (final (r, c) in maze.coins) {
          expect(seen[r][c], isTrue,
              reason: 'coin at ($r,$c) unreachable (level $level)');
        }
        final boost = maze.boostSpot;
        if (boost != null) {
          expect(seen[boost.$1][boost.$2], isTrue,
              reason: 'boost at ${boost.$1},${boost.$2} unreachable');
        }
      }
    }
  });

  test('pickups are consumed exactly once', () {
    final maze = Maze(9, enemyCount: 2);
    expect(maze.coins, isNotEmpty);

    final coin = maze.coins.first;
    expect(maze.takePickup(coin.$1, coin.$2).coin, isTrue);
    expect(maze.takePickup(coin.$1, coin.$2).coin, isFalse);

    final boost = maze.boostSpot;
    if (boost != null) {
      expect(maze.takePickup(boost.$1, boost.$2).boost, isTrue);
      expect(maze.takePickup(boost.$1, boost.$2).boost, isFalse);
    }
  });

  test('freeze boost sits in a dead-end hiding spot', () {
    for (final level in [1, 3, 5, 8]) {
      final size = 2 * level + 5;
      for (var rep = 0; rep < 10; rep++) {
        final maze = Maze(size, enemyCount: level);
        final boost = maze.boostSpot;
        expect(boost, isNotNull, reason: 'level $level no boost spot');
        final cell = maze.cells[boost!.$1][boost.$2];
        var open = 0;
        if (!cell.top) open++;
        if (!cell.bottom) open++;
        if (!cell.left) open++;
        if (!cell.right) open++;
        expect(open, 1,
            reason: 'level $level boost not in a dead end '
                '(boost at ${boost.$1},${boost.$2})');
      }
    }
  });
}
