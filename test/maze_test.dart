// Tests for the maze generator: the maze must always be a perfect maze
// (fully connected, one unique path), solvable from start to goal, with a
// long winding solution and plenty of dead-end branches to mislead the player.

import 'dart:math';

import 'package:movaze/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Maze is fully connected, solvable, winding and full of dead ends', () {
    for (final size in [7, 9, 11, 21, 31]) {
      for (var trial = 0; trial < 10; trial++) {
        final maze = Maze(size);
        final total = size * size;

        final reached =
            List.generate(size, (_) => List<bool>.filled(size, false));
        final dist = List.generate(size, (_) => List<int>.filled(size, -1));
        final queue = <(int, int)>[(0, 0)];
        reached[0][0] = true;
        dist[0][0] = 0;
        var reachable = 0;
        var deadEnds = 0;

        while (queue.isNotEmpty) {
          final (r, c) = queue.removeAt(0);
          reachable++;
          final cell = maze.cells[r][c];
          var open = 0;
          if (!cell.top) {
            open++;
            if (!reached[r - 1][c]) {
              reached[r - 1][c] = true;
              dist[r - 1][c] = dist[r][c] + 1;
              queue.add((r - 1, c));
            }
          }
          if (!cell.bottom) {
            open++;
            if (!reached[r + 1][c]) {
              reached[r + 1][c] = true;
              dist[r + 1][c] = dist[r][c] + 1;
              queue.add((r + 1, c));
            }
          }
          if (!cell.left) {
            open++;
            if (!reached[r][c - 1]) {
              reached[r][c - 1] = true;
              dist[r][c - 1] = dist[r][c] + 1;
              queue.add((r, c - 1));
            }
          }
          if (!cell.right) {
            open++;
            if (!reached[r][c + 1]) {
              reached[r][c + 1] = true;
              dist[r][c + 1] = dist[r][c] + 1;
              queue.add((r, c + 1));
            }
          }
          if (open == 1) deadEnds++;
        }

        expect(reachable, total, reason: 'size $size not fully connected');
        expect(reached[size - 1][size - 1], isTrue,
            reason: 'size $size not solvable');
        expect(dist[size - 1][size - 1] / total, greaterThan(0.4),
            reason: 'size $size solution path too short');
        expect(deadEnds / total, greaterThan(0.1),
            reason: 'size $size too few dead ends');
      }
    }
  });

  test('Player movement respects walls and bounds', () {
    final maze = Maze(9);
    expect(maze.move(-1, 0), isFalse, reason: 'cannot move off the top');
    expect(maze.move(0, -1), isFalse, reason: 'cannot move off the left');

    final start = maze.cells[0][0];
    final canGoRight = !start.right;
    final canGoDown = !start.bottom;
    if (canGoRight) {
      final moved = maze.move(0, 1);
      expect(moved, isTrue);
      expect(maze.playerCol, 1);
    } else if (canGoDown) {
      final moved = maze.move(1, 0);
      expect(moved, isTrue);
      expect(maze.playerRow, 1);
    } else {
      fail('start cell should connect to the maze');
    }
  });

  test('Enemy BFS takes one step along the shortest path', () {
    int bfsDistance(Maze maze, int tr, int tc, int a, int b) {
      final seen = List.generate(
        maze.size,
        (_) => List<bool>.filled(maze.size, false),
      );
      final queue = <(int, int)>[(a, b)];
      seen[a][b] = true;
      var depth = 0;
      while (queue.isNotEmpty) {
        for (var k = 0, n = queue.length; k < n; k++) {
          final (r, c) = queue.removeAt(0);
          if (r == tr && c == tc) return depth;
          final cell = maze.cells[r][c];
          if (!cell.top && !seen[r - 1][c]) {
            seen[r - 1][c] = true;
            queue.add((r - 1, c));
          }
          if (!cell.bottom && !seen[r + 1][c]) {
            seen[r + 1][c] = true;
            queue.add((r + 1, c));
          }
          if (!cell.left && !seen[r][c - 1]) {
            seen[r][c - 1] = true;
            queue.add((r, c - 1));
          }
          if (!cell.right && !seen[r][c + 1]) {
            seen[r][c + 1] = true;
            queue.add((r, c + 1));
          }
        }
        depth++;
      }
      return -1;
    }

    final rng = Random(42);
    for (final size in [7, 9, 11]) {
      for (var trial = 0; trial < 3; trial++) {
        final maze = Maze(size);
        for (var i = 0; i < 20; i++) {
          final fr = rng.nextInt(size);
          final fc = rng.nextInt(size);
          final tr = rng.nextInt(size);
          final tc = rng.nextInt(size);

          final step = maze.nextStepToward(fr, fc, tr, tc);
          if (fr == tr && fc == tc) {
            expect(step, isNull);
            continue;
          }
          expect(step, isNotNull);
          final (sr, sc) = step!;
          final open = (sr == fr - 1 && sc == fc && !maze.cells[fr][fc].top) ||
              (sr == fr + 1 && sc == fc && !maze.cells[fr][fc].bottom) ||
              (sr == fr && sc == fc - 1 && !maze.cells[fr][fc].left) ||
              (sr == fr && sc == fc + 1 && !maze.cells[fr][fc].right);
          expect(open, isTrue, reason: 'enemy step is not an open neighbor');
          expect(
            bfsDistance(maze, tr, tc, sr, sc) + 1,
            bfsDistance(maze, tr, tc, fr, fc),
            reason: 'enemy step must reduce distance by one',
          );
        }
      }
    }
  });

  test('Enemy patrols its own arc and never leaves the bottom half', () {
    for (final size in [7, 11, 21]) {
      for (var trial = 0; trial < 5; trial++) {
        final maze = Maze(size, enemyCount: 1);
        final e = maze.enemies.first;
        final mid = size ~/ 2;
        expect(e.row, greaterThanOrEqualTo(mid),
            reason: 'enemy must spawn in its half of the maze');
        expect(e.patrolIndex, inInclusiveRange(e.startIndex, e.endIndex));
        expect(maze.patrolRoute[e.patrolIndex], (e.row, e.col));

        final rng = Random(7);
        for (var step = 0; step < 120; step++) {
          maze.advanceEnemy(e, rng: rng);
          expect(e.row, greaterThanOrEqualTo(mid),
              reason: 'enemy crossed the middle while patrolling');
          expect(maze.patrolRoute[e.patrolIndex], (e.row, e.col),
              reason: 'enemy is not following its patrol arc');
          expect(e.patrolIndex, inInclusiveRange(e.startIndex, e.endIndex),
              reason: 'enemy left its assigned patrol arc');
        }
      }
    }
  });

  test('Enemies patrol independent arcs and stay spread out', () {
    var spread = 0;
    for (final size in [11, 15, 21]) {
      for (var trial = 0; trial < 5; trial++) {
        final maze = Maze(size, enemyCount: 3);
        final rng = Random(trial);
        final arcs = <(int, int)>{};
        for (final e in maze.enemies) {
          arcs.add((e.startIndex, e.endIndex));
        }
        // Each enemy owns a distinct arc of the route.
        expect(arcs.length, maze.enemies.length,
            reason: 'enemies share a patrol arc');
        for (var step = 0; step < 300; step++) {
          for (final e in maze.enemies) {
            maze.advanceEnemy(e, rng: rng);
          }
        }
        final positions = {
          for (final e in maze.enemies) (e.row, e.col),
        };
        if (positions.length == maze.enemies.length) spread++;
      }
    }
    expect(spread, greaterThan(0),
        reason: 'enemies never spread to distinct positions');
  });

  test('Enemy patrols the main corridors and leaves dead ends as hiding spots',
      () {
    for (final size in [11, 21, 31]) {
      for (var trial = 0; trial < 5; trial++) {
        final maze = Maze(size, enemyCount: 1);
        final e = maze.enemies.first;
        final mid = size ~/ 2;

        // Unique solution path from start to goal.
        final parent =
            List.generate(size, (_) => List<(int, int)?>.filled(size, null));
        final onSolution =
            List.generate(size, (_) => List<bool>.filled(size, false));
        final queue = <(int, int)>[(0, 0)];
        parent[0][0] = (0, 0);
        while (queue.isNotEmpty) {
          final (r, c) = queue.removeAt(0);
          if (r == size - 1 && c == size - 1) break;
          final cell = maze.cells[r][c];
          if (!cell.top && parent[r - 1][c] == null) {
            parent[r - 1][c] = (r, c);
            queue.add((r - 1, c));
          }
          if (!cell.bottom && parent[r + 1][c] == null) {
            parent[r + 1][c] = (r, c);
            queue.add((r + 1, c));
          }
          if (!cell.left && parent[r][c - 1] == null) {
            parent[r][c - 1] = (r, c);
            queue.add((r, c - 1));
          }
          if (!cell.right && parent[r][c + 1] == null) {
            parent[r][c + 1] = (r, c);
            queue.add((r, c + 1));
          }
        }
        var (sr, sc) = (size - 1, size - 1);
        while (parent[sr][sc] != null && parent[sr][sc] != (sr, sc)) {
          onSolution[sr][sc] = true;
          final p = parent[sr][sc]!;
          sr = p.$1;
          sc = p.$2;
        }
        onSolution[0][0] = true;

        // Expected backbone: half cells with dead-end branches peeled off.
        final main =
            List.generate(size, (_) => List<bool>.filled(size, false));
        final openCount =
            List.generate(size, (_) => List<int>.filled(size, 0));
        final peel = <(int, int)>[];
        for (var r = mid; r < size; r++) {
          for (var c = 0; c < size; c++) {
            final cell = maze.cells[r][c];
            var count = 0;
            if (r > mid && !cell.top) count++;
            if (r < size - 1 && !cell.bottom) count++;
            if (c > 0 && !cell.left) count++;
            if (c < size - 1 && !cell.right) count++;
            openCount[r][c] = count;
            main[r][c] = true;
            if (count <= 1 && !onSolution[r][c]) peel.add((r, c));
          }
        }
        while (peel.isNotEmpty) {
          final (r, c) = peel.removeAt(0);
          if (!main[r][c] || onSolution[r][c]) continue;
          if (openCount[r][c] > 1) continue;
          main[r][c] = false;
          final cell = maze.cells[r][c];
          if (r > mid && !cell.top && main[r - 1][c]) {
            openCount[r - 1][c]--;
            if (openCount[r - 1][c] <= 1 && !onSolution[r - 1][c]) {
              peel.add((r - 1, c));
            }
          }
          if (r < size - 1 && !cell.bottom && main[r + 1][c]) {
            openCount[r + 1][c]--;
            if (openCount[r + 1][c] <= 1 && !onSolution[r + 1][c]) {
              peel.add((r + 1, c));
            }
          }
          if (c > 0 && !cell.left && main[r][c - 1]) {
            openCount[r][c - 1]--;
            if (openCount[r][c - 1] <= 1 && !onSolution[r][c - 1]) {
              peel.add((r, c - 1));
            }
          }
          if (c < size - 1 && !cell.right && main[r][c + 1]) {
            openCount[r][c + 1]--;
            if (openCount[r][c + 1] <= 1 && !onSolution[r][c + 1]) {
              peel.add((r, c + 1));
            }
          }
        }

        expect(main.any((row) => row.any((v) => v)), isTrue,
            reason: 'patrol backbone is empty');
        expect(main[size - 1][size - 1], isTrue,
            reason: 'goal must stay on the patrol backbone');

        final visited = <(int, int)>{};
        final rng = Random(9);
        for (var step = 0; step < maze.patrolRoute.length * 4; step++) {
          maze.advanceEnemy(e, rng: rng);
          expect(e.row, greaterThanOrEqualTo(mid),
              reason: 'enemy crossed the middle while patrolling');
          expect(maze.patrolRoute[e.patrolIndex], (e.row, e.col),
              reason: 'enemy is not following its patrol route');
          expect(e.patrolIndex, inInclusiveRange(e.startIndex, e.endIndex),
              reason: 'enemy left its assigned patrol arc');
          visited.add((e.row, e.col));
        }

        final expected = <(int, int)>{};
        for (var r = mid; r < size; r++) {
          for (var c = 0; c < size; c++) {
            if (main[r][c]) expected.add((r, c));
          }
        }
        expect(visited, isNotEmpty,
            reason: 'enemy never moved while patrolling');
        expect(visited.difference(expected).isEmpty, isTrue,
            reason: 'patrol entered a dead-end hiding spot');
        final totalHalf = size * (size - mid);
        expect(expected.length, lessThan(totalHalf),
            reason: 'dead-end hiding spots were not left unpatrolled');

        final routeHasDeadEnd = maze.patrolRoute.any((p) {
          final cell = maze.cells[p.$1][p.$2];
          var open = 0;
          if (!cell.top) open++;
          if (!cell.bottom) open++;
          if (!cell.left) open++;
          if (!cell.right) open++;
          return open == 1;
        });
        expect(routeHasDeadEnd, isFalse,
            reason: 'patrol route includes a dead-end hiding spot');
        expect(
            maze.patrolRoute.any((p) => p == (size - 1, size - 1)), isFalse,
            reason: 'goal cell is patrolled, so the level cannot be won');

        // At least one dead-end hiding spot must exist off the patrol route.
        final routeCells = <(int, int)>{};
        for (final p in maze.patrolRoute) {
          routeCells.add(p);
        }
        final safeSpots = <(int, int)>{};
        for (var r = mid; r < size; r++) {
          for (var c = 0; c < size; c++) {
            if (r == size - 1 && c == size - 1) continue;
            if (routeCells.contains((r, c))) continue;
            final cell = maze.cells[r][c];
            var open = 0;
            if (!cell.top) open++;
            if (!cell.bottom) open++;
            if (!cell.left) open++;
            if (!cell.right) open++;
            if (open == 1) safeSpots.add((r, c));
          }
        }
        expect(safeSpots, isNotEmpty,
            reason: 'no dead-end hiding spot exists off the patrol route');
      }
    }
  });
}
