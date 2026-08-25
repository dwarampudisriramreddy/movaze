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
    test('feature thresholds match the world spec', () {
      // World 1 (1-5) pure mazes, world 2 (6-10) enemies: no keys yet.
      expect(hasKeysForLevel(10), isFalse);
      // World 3 (11-15) introduces keys + locked doors.
      expect(hasKeysForLevel(11), isTrue);
      expect(hasKeysForLevel(16), isTrue);

      // World 4 (16-20) introduces fog.
      expect(hasFogForLevel(15), isFalse);
      expect(hasFogForLevel(16), isTrue);

      // World 5 (21-25) is the boss world.
      expect(hasBossForLevel(20), isFalse);
      expect(hasBossForLevel(21), isTrue);
      expect(hasBossForLevel(25), isTrue);

      expect(hasShieldForLevel(1), isTrue);

      expect(doorCountForLevel(10), 0);
      expect(doorCountForLevel(11), 2);
      expect(doorCountForLevel(16), 3);

      // World 1 has enemies starting at level 2; worlds 2-4 scale with level;
      // world 5 is boss-heavy so patrols are halved.
      expect(enemyCountForLevel(1), 0);
      expect(enemyCountForLevel(2), 1);
      expect(enemyCountForLevel(4), 2);
      expect(enemyCountForLevel(5), 3);
      expect(enemyCountForLevel(10), 10);
      expect(enemyCountForLevel(21), lessThan(21));

      expect(mazeSizeForLevel(1), 7);
      expect(worldForLevel(5), 1);
      expect(worldForLevel(6), 2);
      expect(worldStart(2), 6);
      expect(worldEnd(2), 10);
    });

    test('every level builds a valid maze with its world features', () {
      for (var level = 1; level <= 25; level++) {
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
      for (var level = 11; level <= 16; level++) {
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
    test('boss patrols the route when the player is out of chase range', () {
      for (var trial = 0; trial < 6; trial++) {
        final maze = Maze(15, enemyCount: 2, boss: true);
        final boss = maze.boss!;
        expect(boss.isBoss, isTrue);
        expect(boss.pace, 1.0, reason: 'boss should move every tick');

        final onRoute = {for (final p in maze.patrolRoute) p};
        // Player stays at the start; the boss may only leave the route while
        // the player is within chase range.
        maze.playerRow = 0;
        maze.playerCol = 0;
        for (var step = 0; step < 100; step++) {
          maze.advanceEnemy(boss, rng: Random(step));
          final dist =
              (boss.row - maze.playerRow).abs() + (boss.col - maze.playerCol).abs();
          if (dist > Maze.bossChaseRadius) {
            expect(onRoute.contains((boss.row, boss.col)), isTrue,
                reason: 'boss must patrol when out of range (dist $dist)');
          }
        }
      }
    });

    test('boss abandons its route to chase a nearby player into a hiding spot',
        () {
      Maze? maze;
      for (var attempt = 0; attempt < 30 && maze == null; attempt++) {
        final m = Maze(15, enemyCount: 2, boss: true);
        final onRoute = {for (final p in m.patrolRoute) p};
        int open(int r, int c) {
          final cell = m.cells[r][c];
          var o = 0;
          if (!cell.top) o++;
          if (!cell.bottom) o++;
          if (!cell.left) o++;
          if (!cell.right) o++;
          return o;
        }

        outer:
        for (var i = 0; i < m.patrolRoute.length; i++) {
          final (r, c) = m.patrolRoute[i];
          for (final nb in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
            if (nb.$1 < 0 || nb.$1 >= m.size || nb.$2 < 0 || nb.$2 >= m.size) {
              continue;
            }
            if (onRoute.contains(nb)) continue;
            if (open(nb.$1, nb.$2) != 1) continue;
            final cell = m.cells[r][c];
            final openToNb = (nb == (r - 1, c) && !cell.top) ||
                (nb == (r + 1, c) && !cell.bottom) ||
                (nb == (r, c - 1) && !cell.left) ||
                (nb == (r, c + 1) && !cell.right);
            if (!openToNb) continue;
            final boss = m.boss!;
            boss.row = r;
            boss.col = c;
            boss.patrolIndex = i;
            m.playerRow = nb.$1;
            m.playerCol = nb.$2;
            maze = m;
            break outer;
          }
        }
      }

      expect(maze, isNotNull,
          reason: 'no off-route dead end found next to the patrol route');
      final m = maze!;
      final boss = m.boss!;
      final onRoute = {for (final p in m.patrolRoute) p};
      expect(onRoute.contains((boss.row, boss.col)), isTrue);
      expect(onRoute.contains((m.playerRow, m.playerCol)), isFalse);

      var caught = false;
      for (var step = 0; step < 30; step++) {
        m.advanceEnemy(boss, rng: Random(step));
        if (boss.row == m.playerRow && boss.col == m.playerCol) {
          caught = true;
          break;
        }
      }
      expect(caught, isTrue,
          reason: 'boss should chase the player into the dead end');
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
