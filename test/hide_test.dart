import 'package:movaze/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every enemy arc contains a dead-end escape spot', () {
    for (var level in [1, 2, 3, 5, 8, 10]) {
      for (var rep = 0; rep < 40; rep++) {
        final size = 2 * level + 5;
        final maze = Maze(size, enemyCount: level);
        final route = maze.patrolRoute;
        final onRoute = {for (final p in route) p};
        final mid = size ~/ 2;

        bool isBranch(int nr, int nc) {
          if (nr < mid) return false;
          if (nr == size - 1 && nc == size - 1) return false;
          return !onRoute.contains((nr, nc));
        }

        final hideIdx = <int>[];
        for (var i = 0; i < route.length; i++) {
          final (r, c) = route[i];
          final cell = maze.cells[r][c];
          if (r > mid && !cell.top && isBranch(r - 1, c)) {
            hideIdx.add(i);
            continue;
          }
          if (r < size - 1 && !cell.bottom && isBranch(r + 1, c)) {
            hideIdx.add(i);
            continue;
          }
          if (c > 0 && !cell.left && isBranch(r, c - 1)) {
            hideIdx.add(i);
            continue;
          }
          if (c < size - 1 && !cell.right && isBranch(r, c + 1)) {
            hideIdx.add(i);
          }
        }
        final hideSet = hideIdx.toSet();
        if (hideIdx.isEmpty) continue;

        for (final e in maze.enemies) {
          var has = false;
          for (var i = e.startIndex; i <= e.endIndex; i++) {
            if (hideSet.contains(i)) {
              has = true;
              break;
            }
          }
          expect(has, isTrue,
              reason:
                  'level $level enemy (arc ${e.startIndex}-${e.endIndex}) has no '
                  'dead-end escape; total hide spots=${hideIdx.length}');
        }
      }
    }
  });
}
