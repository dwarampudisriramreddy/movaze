import 'package:movaze/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enemy count equals level and patrol covers the half', () {
    for (var level in [1, 2, 5, 100]) {
      final size = 2 * level + 5;
      final maze = Maze(size, enemyCount: level);
      expect(maze.enemies.length, level,
          reason: 'level $level should have $level enemies');

      final mid = size ~/ 2;
      final halfCells = size * (size - mid);
      final seen = List.generate(size, (_) => List<bool>.filled(size, false));
      final queue = <(int, int)>[(size - 1, size - 1)];
      seen[size - 1][size - 1] = true;
      var component = 0;
      while (queue.isNotEmpty) {
        final (r, c) = queue.removeAt(0);
        component++;
        final cell = maze.cells[r][c];
        if (!cell.top && r > mid && !seen[r - 1][c]) {
          seen[r - 1][c] = true;
          queue.add((r - 1, c));
        }
        if (!cell.bottom && r < size - 1 && !seen[r + 1][c]) {
          seen[r + 1][c] = true;
          queue.add((r + 1, c));
        }
        if (!cell.left && c > 0 && !seen[r][c - 1]) {
          seen[r][c - 1] = true;
          queue.add((r, c - 1));
        }
        if (!cell.right && c < size - 1 && !seen[r][c + 1]) {
          seen[r][c + 1] = true;
          queue.add((r, c + 1));
        }
      }
      expect(component / halfCells, greaterThanOrEqualTo(0.9),
          reason: 'level $level patrol territory covers under 90% of the half');
    }
  });
}
