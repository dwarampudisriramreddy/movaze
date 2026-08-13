// Tests for the progression features: level gating, keys + locked doors,
// shield pickup, boss patroller and fog of war.

import 'dart:math';

import 'package:movaze/main.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<bool>> reachableIgnoringDoors(Maze maze) {
  final seen =
      List.generate(maze.size, (_) => List<bool>.filled(maze.size, false));
  final queue = <(int, int)>[(0, 0)];
  seen[0][0] = true;
  while (queue.isNotEmpty) {
    final (r, c) = queue.removeAt(0);
    final cell = maze.cells[r][c];
    void tryAdd(int nr, int nc) {
      if (nr < 0 || nr >= maze.size || nc < 0 || nc >= maze.size) return;
      if (seen[nr][nc]) return;
      final isDoor = maze.doors.any(
        (d) =>
            (d.$1 == r && d.$2 == c && d.$3 == nr && d.$4 == nc) ||
            (d.$1 == nr && d.$2 == nc && d.$3 == r && d.$4 == c),
      );
      if (isDoor) return;
      seen[nr][nc] = true;
      queue.add((nr, nc));
    }

    if (!cell.top) tryAdd(r - 1, c);
    if (!cell.right) tryAdd(r, c + 1);
    if (!cell.bottom) tryAdd(r + 1, c);
    if (!cell.left) tryAdd(r, c - 1);
  }
  return seen;
}

bool doorWallIsOpen(Maze m, (int, int, int, int) d) {
  if (d.$1 == d.$3) {
    final lo = d.$2 < d.$4 ? d.$2 : d.$4;
    final hi = d.$2 > d.$4 ? d.$2 : d.$4;
    return !m.cells[d.$1][lo].right && !m.cells[d.$1][hi].left;
  }
  final lo = d.$1 < d.$3 ? d.$1 : d.$3;
  final hi = d.$1 > d.$3 ? d.$1 : d.$3;
  return !m.cells[lo][d.$2].bottom && !m.cells[hi][d.$2].top;
}

int bfsDistance(Maze m, int sr, int sc, int tr, int tc) {
  final dist = List.generate(m.size, (_) => List<int>.filled(m.size, -1));
  final queue = <(int, int)>[(sr, sc)];
  dist[sr][sc] = 0;
  while (queue.isNotEmpty) {
    final (r, c) = queue.removeAt(0);
    if (r == tr && c == tc) return dist[r][c];
    final cell = m.cells[r][c];
    if (!cell.top && dist[r - 1][c] == -1) {
      dist[r - 1][c] = dist[r][c] + 1;
      queue.add((r - 1, c));
    }
    if (!cell.right && dist[r][c + 1] == -1) {
      dist[r][c + 1] = dist[r][c] + 1;
      queue.add((r, c + 1));
    }
    if (!cell.bottom && dist[r + 1][c] == -1) {
      dist[r + 1][c] = dist[r][c] + 1;
      queue.add((r + 1, c));
    }
    if (!cell.left && dist[r][c - 1] == -1) {
      dist[r][c - 1] = dist[r][c] + 1;
      queue.add((r, c - 1));
    }
  }
  return -1;
}

void main() {
  group('level gating', () {
    test('feature thresholds match the spec', () {
      expect(hasKeysForLevel(4), isFalse);
      expect(hasKeysForLevel(5), isTrue);
      expect(hasKeysForLevel(9), isTrue);

      expect(hasFogForLevel(9), isFalse);
      expect(hasFogForLevel(10), isTrue);

      expect(hasBossForLevel(4), isFalse);
      expect(hasBossForLevel(5), isTrue);
      expect(hasBossForLevel(9), isFalse);
      expect(hasBossForLevel(10), isTrue);

      expect(hasShieldForLevel(1), isTrue);

      expect(doorCountForLevel(4), 0);
      expect(doorCountForLevel(5), 2);
      expect(doorCountForLevel(10), 3);

      expect(enemyCountForLevel(4), 4);
      expect(enemyCountForLevel(5), lessThan(5));
      expect(enemyCountForLevel(10), lessThan(10));

      expect(mazeSizeForLevel(1), 7);
      expect(worldForLevel(5), 1);
      expect(worldForLevel(6), 2);
      expect(worldStart(2), 6);
      expect(worldEnd(2), 10);
    });

    test('every level builds a valid maze with its features', () {
      for (var level = 1; level <= 15; level++) {
        final maze = Maze(
          mazeSizeForLevel(level),
          enemyCount: enemyCountForLevel(level),
          keys: hasKeysForLevel(level),
          shield: hasShieldForLevel(level),
          fog: hasFogForLevel(level),
          boss: hasBossForLevel(level),
          doorCount: doorCountForLevel(level),
        );
        expect(maze.hasKeys, hasKeysForLevel(level), reason: 'level $level');
        expect(maze.hasFog, hasFogForLevel(level), reason: 'level $level');
        expect(maze.hasBoss, hasBossForLevel(level), reason: 'level $level');
        if (hasKeysForLevel(level)) {
          expect(maze.keys, isNotEmpty, reason: 'level $level has no keys');
          expect(maze.doors, isNotEmpty, reason: 'level $level has no doors');
        } else {
          expect(maze.keys, isEmpty, reason: 'level $level');
          expect(maze.doors, isEmpty, reason: 'level $level');
        }
        if (hasBossForLevel(level)) {
          expect(maze.boss, isNotNull, reason: 'level $level has no boss');
        } else {
          expect(maze.boss, isNull, reason: 'level $level');
        }
        expect(maze.shieldSpot, isNotNull, reason: 'level $level no shield');
        // Goal stays reachable (doors sit on the solution path and are
        // passable once keys are collected).
        final dist = bfsDistance(maze, 0, 0, maze.size - 1, maze.size - 1);
        expect(dist, greaterThan(0), reason: 'level $level unsolvable');
      }
    });
  });

  group('keys and locked doors', () {
    test('keys are reachable, doors block until a key, then stay open',
        () {
      for (var trial = 0; trial < 12; trial++) {
        final maze = Maze(15, enemyCount: 1, keys: true, doorCount: 2);
        expect(maze.doors, isNotEmpty);
        expect(maze.keys.length, maze.doors.length,
            reason: 'one key must be collectable per door');

        final seen = reachableIgnoringDoors(maze);
        for (final k in maze.keys) {
          expect(seen[k.$1][k.$2], isTrue,
              reason: 'key at $k is behind a locked door');
        }
        for (final d in maze.doors) {
          expect(doorWallIsOpen(maze, d), isTrue,
              reason: 'door $d sits on a solid wall');
        }

        // Pick a door; approach from the side reachable without any key.
        final d = maze.doors.first;
        final approachR = seen[d.$1][d.$2] ? d.$1 : d.$3;
        final approachC = seen[d.$1][d.$2] ? d.$2 : d.$4;
        final toR = approachR == d.$1 ? d.$3 : d.$1;
        final toC = approachC == d.$2 ? d.$4 : d.$2;
        maze.playerRow = approachR;
        maze.playerCol = approachC;

        final dr = toR - approachR;
        final dc = toC - approachC;
        expect(maze.move(dr, dc), isFalse,
            reason: 'door must block movement without a key');
        expect(maze.keysHeld, 0);

        maze.keysHeld = 1;
        expect(maze.move(dr, dc), isTrue);
        expect(maze.keysHeld, 0, reason: 'passing a door consumes a key');
        expect(maze.doors.contains(d), isFalse,
            reason: 'door must open permanently');
        expect(maze.playerRow, toR);
        expect(maze.playerCol, toC);
      }
    });

    test('player can walk the whole maze to the goal once keys are held', () {
      for (var trial = 0; trial < 8; trial++) {
        final maze = Maze(17, enemyCount: 2, keys: true, doorCount: 2);
        maze.keysHeld = maze.keys.length;
        var steps = 0;
        while (!maze.isGoal()) {
          final step =
              maze.nextStepToward(maze.playerRow, maze.playerCol,
                  maze.size - 1, maze.size - 1);
          expect(step, isNotNull, reason: 'no route to the goal');
          final (sr, sc) = step!;
          expect(maze.move(sr - maze.playerRow, sc - maze.playerCol), isTrue,
              reason: 'solution path blocked by a door');
          expect(++steps, lessThan(1000), reason: 'stuck in a loop');
        }
      }
    });
  });

  group('shield pickup', () {
    test('shield is placed on every level and consumed once', () {
      for (var level = 1; level <= 8; level++) {
        final maze = Maze(
          mazeSizeForLevel(level),
          enemyCount: enemyCountForLevel(level),
        );
        expect(maze.shieldSpot, isNotNull, reason: 'level $level no shield');
        final s = maze.shieldSpot!;
        expect(maze.takePickup(s.$1, s.$2).shield, isTrue);
        expect(maze.hasShield, isTrue);
        expect(maze.takePickup(s.$1, s.$2).shield, isFalse);
      }
    });

    test('shield hides in a dead-end cell', () {
      for (var level = 1; level <= 8; level++) {
        for (var rep = 0; rep < 20; rep++) {
          final maze = Maze(
            mazeSizeForLevel(level),
            enemyCount: enemyCountForLevel(level),
          );
          final s = maze.shieldSpot;
          if (s == null) continue;
          int open(int r, int c) {
            final cell = maze.cells[r][c];
            var o = 0;
            if (!cell.top) o++;
            if (!cell.bottom) o++;
            if (!cell.left) o++;
            if (!cell.right) o++;
            return o;
          }

          expect(open(s.$1, s.$2), 1,
              reason: 'shield at $s (level $level) is not in a dead end');
        }
      }
    });
  });

  group('keys in dead ends', () {
    test('every key sits in a dead-end cell', () {
      for (var level = 5; level <= 10; level++) {
        for (var rep = 0; rep < 20; rep++) {
          final maze = Maze(
            mazeSizeForLevel(level),
            enemyCount: enemyCountForLevel(level),
            keys: true,
            doorCount: doorCountForLevel(level),
          );
          expect(maze.keys, isNotEmpty, reason: 'level $level has no keys');
          int open(int r, int c) {
            final cell = maze.cells[r][c];
            var o = 0;
            if (!cell.top) o++;
            if (!cell.bottom) o++;
            if (!cell.left) o++;
            if (!cell.right) o++;
            return o;
          }

          for (final k in maze.keys) {
            expect(open(k.$1, k.$2), 1,
                reason: 'key at $k (level $level) is not in a dead end');
          }
        }
      }
    });
  });

  group('boss', () {
    test('boss is a fast patroller that never chases or leaves the route', () {
      for (var trial = 0; trial < 6; trial++) {
        final maze = Maze(15, enemyCount: 2, boss: true);
        final boss = maze.boss!;
        expect(boss.isBoss, isTrue);
        expect(boss.startIndex, 0);
        expect(boss.endIndex, maze.patrolRoute.length - 1);
        expect(maze.patrolRoute[boss.patrolIndex], (boss.row, boss.col));

        final onRoute = {for (final p in maze.patrolRoute) p};
        var moved = false;
        for (var step = 0; step < 40; step++) {
          final before = (boss.row, boss.col);
          maze.advanceEnemy(boss, rng: Random(step));
          if ((boss.row, boss.col) != before) moved = true;
          expect(onRoute.contains((boss.row, boss.col)), isTrue,
              reason: 'boss left the patrol route');
          expect(
            boss.patrolIndex,
            inInclusiveRange(0, maze.patrolRoute.length - 1),
          );
        }
        expect(moved, isTrue, reason: 'boss should move fast along its path');
      }
    });

    test('boss stays on the route even with the player close by', () {
      for (var trial = 0; trial < 6; trial++) {
        final maze = Maze(15, enemyCount: 2, boss: true);
        final boss = maze.boss!;
        // Park the player on the boss so the old chase AI would have run.
        maze.playerRow = boss.row;
        maze.playerCol = boss.col;
        final onRoute = {for (final p in maze.patrolRoute) p};
        for (var step = 0; step < 30; step++) {
          maze.advanceEnemy(boss, rng: Random(step));
          expect(onRoute.contains((boss.row, boss.col)), isTrue,
              reason: 'boss must patrol, never chase');
        }
      }
    });
  });

  group('patrol dead ends', () {
    test('the patrol route always includes at least one real dead end', () {
      for (var level = 1; level <= 8; level++) {
        for (var rep = 0; rep < 30; rep++) {
          final maze = Maze(
            mazeSizeForLevel(level),
            enemyCount: enemyCountForLevel(level),
          );
          expect(maze.patrolRoute, isNotEmpty);
          int open(int r, int c) {
            final cell = maze.cells[r][c];
            var o = 0;
            if (!cell.top) o++;
            if (!cell.bottom) o++;
            if (!cell.left) o++;
            if (!cell.right) o++;
            return o;
          }

          final deadEnds = maze.patrolRoute
              .where((p) => open(p.$1, p.$2) == 1)
              .length;
          expect(deadEnds, greaterThanOrEqualTo(1),
              reason: 'level $level patrol route has no dead end');
        }
      }
    });
  });

  group('fog of war', () {
    test('only fog levels hide the board and exploration reveals cells', () {
      final plain = Maze(9);
      expect(plain.hasFog, isFalse);

      final maze = Maze(11, fog: true);
      expect(maze.hasFog, isTrue);
      expect(maze.explored, contains((0, 0)));

      final before = maze.explored.length;
      maze.explore(0, 1);
      expect(maze.explored.length, greaterThan(before),
          reason: 'exploring a new area must add cells');
      expect(maze.explored, contains((0, 1)));
    });
  });

  group('infinity', () {
    test('every infinity level mixes all mechanics on a growing maze', () {
      for (var level = 1; level <= 20; level++) {
        final size = infinitySizeForLevel(level);
        final enemyCount = infinityEnemyCountForLevel(level);
        final doorCount = infinityDoorCountForLevel(level);
        final maze = Maze(
          size,
          enemyCount: enemyCount,
          keys: true,
          shield: true,
          fog: true,
          boss: true,
          doorCount: doorCount,
        );
        expect(maze.hasFog, isTrue, reason: 'infinity level $level');
        expect(maze.boss, isNotNull, reason: 'infinity level $level');
        expect(maze.shieldEnabled, isTrue, reason: 'infinity level $level');
        expect(maze.shieldSpot, isNotNull,
            reason: 'infinity level $level no shield spot');
        expect(maze.patrolRoute, isNotEmpty,
            reason: 'infinity level $level no patrol route');
        expect(maze.explored.length, lessThan(size * size),
            reason: 'infinity level $level fog must hide the board');

        if (maze.solutionLength() >= 10) {
          expect(maze.keys.length, doorCount,
              reason: 'infinity level $level keys vs doors');
          expect(maze.doors.length, doorCount,
              reason: 'infinity level $level doors');
          int open(int r, int c) {
            final cell = maze.cells[r][c];
            var o = 0;
            if (!cell.top) o++;
            if (!cell.bottom) o++;
            if (!cell.left) o++;
            if (!cell.right) o++;
            return o;
          }

          for (final k in maze.keys) {
            expect(open(k.$1, k.$2), 1,
                reason: 'infinity level $level key $k not in a dead end');
          }
        }
      }
    });
  });
}
