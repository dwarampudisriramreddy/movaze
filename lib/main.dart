import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MovazeApp());
}

class MovazeApp extends StatefulWidget {
  const MovazeApp({super.key, this.skipSplash = false});

  final bool skipSplash;

  @override
  State<MovazeApp> createState() => _MovazeAppState();
}

class _MovazeAppState extends State<MovazeApp> {
  bool _dark = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (!widget.skipSplash) {
      try {
        await MobileAds.instance.initialize();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1600));
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'movaze',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.black,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.white,
          onSecondary: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
      ),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: _ready
          ? MazeGame(
              isDark: _dark,
              onToggleDark: () => setState(() => _dark = !_dark),
            )
          : const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MOVAZE',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 240,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.value,
                    minHeight: 6,
                    color: scheme.onSurface,
                    backgroundColor:
                        scheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MazeCell {
  bool top = true;
  bool right = true;
  bool bottom = true;
  bool left = true;
}

class TopBanner extends StatefulWidget {
  const TopBanner({super.key});

  @override
  State<TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<TopBanner> {
  static const String _adUnitId = 'ca-app-pub-3464757507183621/3007304227';

  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _loaded ? _ad : null;
    return SizedBox(
      height: 60,
      child: Center(child: ad == null ? null : AdWidget(ad: ad)),
    );
  }
}

class Enemy {
  int row;
  int col;
  int patrolIndex;
  int startIndex;
  int endIndex;
  int dir;
  double pace;

  Enemy(
    this.row,
    this.col,
    this.patrolIndex, {
    required this.startIndex,
    required this.endIndex,
    this.dir = 1,
    this.pace = 0.6,
  });
}

class Maze {
  final int size;
  final List<List<MazeCell>> cells;
  int playerRow = 0;
  int playerCol = 0;
  final List<Enemy> enemies = [];
  late List<(int, int)> patrolRoute;

  Maze(this.size, {int enemyCount = 0})
      : cells =
            List.generate(size, (_) => List.generate(size, (_) => MazeCell())) {
    _generateWithRetry(enemyCount);
    for (var attempt = 0; attempt < 20; attempt++) {
      _buildPatrolRoute();
      if (enemyCount <= 0 || _hideIndices().length >= enemyCount) break;
    }
    if (enemyCount > 0) _placeEnemies(enemyCount);
  }

  void _generateWithRetry(int enemyCount) {
    for (var attempt = 0; attempt < 200; attempt++) {
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          cells[r][c] = MazeCell();
        }
      }
      _generate();
      _connectHalf();
      if (_solutionRatio() >= 0.45 && _hasSafeHidingSpot(enemyCount)) return;
    }
  }

  /// True when the patrol-route cell at [r],[c] has an off-route dead-end
  /// branch right beside it, i.e. a hiding spot whose entrance sits directly
  /// on an enemy's path.
  bool _hasDeadEndBeside(int r, int c, Set<(int, int)> onRoute) {
    final mid = size ~/ 2;
    final cell = cells[r][c];
    bool isBranchCell(int nr, int nc) {
      if (nr < mid) return false;
      if (nr == size - 1 && nc == size - 1) return false;
      return !onRoute.contains((nr, nc));
    }

    if (r > mid && !cell.top && isBranchCell(r - 1, c)) return true;
    if (r < size - 1 && !cell.bottom && isBranchCell(r + 1, c)) return true;
    if (c > 0 && !cell.left && isBranchCell(r, c - 1)) return true;
    if (c < size - 1 && !cell.right && isBranchCell(r, c + 1)) return true;
    return false;
  }

  /// Route positions whose cell sits right next to a dead-end hiding spot.
  List<int> _hideIndices() {
    final onRoute = {for (final p in patrolRoute) p};
    final hide = <int>[];
    for (var i = 0; i < patrolRoute.length; i++) {
      final (r, c) = patrolRoute[i];
      if (_hasDeadEndBeside(r, c, onRoute)) hide.add(i);
    }
    return hide;
  }

  /// True when the bottom half has enough dead-end hiding spots for every
  /// enemy. Three leaves are required per enemy: each dead-end branch hangs
  /// off a junction corridor that hosts at most three branches, so three
  /// leaves guarantee at least one distinct entrance corridor per enemy, and
  /// the patrol walk visits every entrance.
  bool _hasSafeHidingSpot(int enemyCount) {
    final mid = size ~/ 2;
    final needed = enemyCount > 0 ? enemyCount * 3 : 3;
    var count = 0;
    for (var r = mid; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (r == size - 1 && c == size - 1) continue;
        final cell = cells[r][c];
        var open = 0;
        if (!cell.top) open++;
        if (!cell.bottom) open++;
        if (!cell.left) open++;
        if (!cell.right) open++;
        if (open == 1 && ++count >= needed) return true;
      }
    }
    return false;
  }

  double _solutionRatio() {
    final dist = List.generate(size, (_) => List<int>.filled(size, -1));
    final queue = <(int, int)>[(0, 0)];
    dist[0][0] = 0;
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      final cell = cells[r][c];
      if (!cell.top && dist[r - 1][c] == -1) {
        dist[r - 1][c] = dist[r][c] + 1;
        queue.add((r - 1, c));
      }
      if (!cell.bottom && dist[r + 1][c] == -1) {
        dist[r + 1][c] = dist[r][c] + 1;
        queue.add((r + 1, c));
      }
      if (!cell.left && dist[r][c - 1] == -1) {
        dist[r][c - 1] = dist[r][c] + 1;
        queue.add((r, c - 1));
      }
      if (!cell.right && dist[r][c + 1] == -1) {
        dist[r][c + 1] = dist[r][c] + 1;
        queue.add((r, c + 1));
      }
    }
    return dist[size - 1][size - 1] / (size * size);
  }

  void _placeEnemies(int count) {
    final rng = Random();
    final L = patrolRoute.length;

    // Route positions that sit right next to an off-route dead-end hiding spot.
    final hideIdx = _hideIndices();

    // Give every enemy an arc that contains its own distinct hiding spot by
    // anchoring arcs at dead-end positions, so each enemy passes a dead end.
    final starts = <int>[];
    final ends = <int>[];
    if (hideIdx.length >= count) {
      final anchors = <int>[];
      for (var j = 0; j < count; j++) {
        anchors.add(hideIdx[(j * hideIdx.length) ~/ count]);
      }
      for (var j = 0; j < count; j++) {
        starts.add(j == 0 ? 0 : (anchors[j - 1] + anchors[j]) ~/ 2 + 1);
        ends.add(j == count - 1 ? L - 1 : (anchors[j] + anchors[j + 1]) ~/ 2);
      }
    } else {
      // Fallback: equal arcs (rare; only if the maze has too few dead ends).
      final perArc = L ~/ count;
      if (perArc < 1) {
        for (var j = 0; j < count; j++) {
          starts.add(j);
          ends.add(j);
        }
      } else {
        for (var j = 0; j < count; j++) {
          starts.add(j * perArc);
          ends.add(j == count - 1 ? L - 1 : (j + 1) * perArc - 1);
        }
      }
    }

    final used = <(int, int)>{};
    for (var i = 0; i < count; i++) {
      var start = starts[i];
      var end = ends[i];
      if (end < start) {
        start = i * L ~/ count;
        end = start;
      }
      var idx = start + rng.nextInt(end - start + 1);
      if (used.contains(patrolRoute[idx])) {
        for (var offset = 1; offset <= end - start; offset++) {
          final candidates = [idx - offset, idx + offset];
          var found = false;
          for (final cand in candidates) {
            if (cand < start || cand > end) continue;
            if (!used.contains(patrolRoute[cand])) {
              idx = cand;
              found = true;
              break;
            }
          }
          if (found) break;
        }
      }
      used.add(patrolRoute[idx]);
      final (r, c) = patrolRoute[idx];
      enemies.add(Enemy(
        r,
        c,
        idx,
        startIndex: start,
        endIndex: end,
        dir: rng.nextBool() ? 1 : -1,
        pace: 0.6 + rng.nextDouble() * 0.3,
      ));
    }
  }

  void _buildPatrolRoute() {
    final mid = size ~/ 2;

    // The unique solution path from start to goal.
    final parent = List.generate(size, (_) => List<(int, int)?>.filled(size, null));
    final onSolution = List.generate(size, (_) => List<bool>.filled(size, false));
    final queue = <(int, int)>[(0, 0)];
    parent[0][0] = (0, 0);
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      if (r == size - 1 && c == size - 1) break;
      final cell = cells[r][c];
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
    while (parent[sr][sc] != null && !(parent[sr][sc] == (sr, sc))) {
      onSolution[sr][sc] = true;
      final p = parent[sr][sc]!;
      sr = p.$1;
      sc = p.$2;
    }
    onSolution[0][0] = true;

    // Main backbone: every half cell except dead-end branches that hang off
    // the solution path. Peeling: remove cells with one or zero open half
    // neighbours, but never the solution path itself.
    final openCount =
        List.generate(size, (_) => List<int>.filled(size, 0));
    final main = List.generate(size, (_) => List<bool>.filled(size, false));
    final peel = <(int, int)>[];
    for (var r = mid; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final cell = cells[r][c];
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
      final cell = cells[r][c];
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

    // Dead-end branches stay off the patrol route so they are safe hiding
    // spots for the player, and the goal cell is never patrolled either so
    // the level can always be won.

    // Patrol walk: a self-avoiding snake over the main backbone, so every cell
    // appears exactly once. Enemies own exclusive arcs of it, so they can never
    // share a cell or block each other. The goal is never patrolled so the
    // level can always be won.
    final rng = Random();
    final starts = <(int, int)>[];
    for (var r = mid; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (main[r][c] && !(r == size - 1 && c == size - 1)) {
          starts.add((r, c));
        }
      }
    }
    var best = <(int, int)>[];
    for (var attempt = 0; attempt < 100; attempt++) {
      final visited =
          List.generate(size, (_) => List<bool>.filled(size, false));
      final start = starts[rng.nextInt(starts.length)];
      final route = <(int, int)>[start];
      visited[start.$1][start.$2] = true;
      var (r, c) = start;
      while (true) {
        final cell = cells[r][c];
        final options = <(int, int)>[];
        if (r > mid && !visited[r - 1][c] && !cell.top && main[r - 1][c]) {
          options.add((r - 1, c));
        }
        if (c < size - 1 &&
            !visited[r][c + 1] &&
            !cell.right &&
            main[r][c + 1]) {
          options.add((r, c + 1));
        }
        if (r < size - 1 &&
            !visited[r + 1][c] &&
            !cell.bottom &&
            main[r + 1][c]) {
          options.add((r + 1, c));
        }
        if (c > 0 && !visited[r][c - 1] && !cell.left && main[r][c - 1]) {
          options.add((r, c - 1));
        }
        options.removeWhere((p) => p == (size - 1, size - 1));
        if (options.isEmpty) break;
        options.sort(
          (a, b) => _onwardCount(a.$1, a.$2, visited, main, mid).compareTo(
                _onwardCount(b.$1, b.$2, visited, main, mid),
              ),
        );
        final n = options[rng.nextInt(min(2, options.length))];
        r = n.$1;
        c = n.$2;
        visited[r][c] = true;
        route.add((r, c));
      }
      if (route.length > best.length) best = route;
    }
    patrolRoute = best;
  }

  int _onwardCount(
    int r,
    int c,
    List<List<bool>> visited,
    List<List<bool>> main,
    int mid,
  ) {
    final cell = cells[r][c];
    var count = 0;
    if (r > mid && !visited[r - 1][c] && !cell.top && main[r - 1][c]) count++;
    if (c < size - 1 && !visited[r][c + 1] && !cell.right && main[r][c + 1]) {
      count++;
    }
    if (r < size - 1 && !visited[r + 1][c] && !cell.bottom && main[r + 1][c]) {
      count++;
    }
    if (c > 0 && !visited[r][c - 1] && !cell.left && main[r][c - 1]) count++;
    return count;
  }

  void _generate() {
    final visited =
        List.generate(size, (_) => List<bool>.filled(size, false));
    final rng = Random();
    final mid = size ~/ 2;
    var visitedCount = 0;
    final total = size * size;

    void markVisited(int r, int c) {
      visited[r][c] = true;
      visitedCount++;
    }

    void carveBetween(int r, int c, int nr, int nc, int dir) {
      switch (dir) {
        case 0:
          cells[r][c].top = false;
          cells[nr][nc].bottom = false;
        case 1:
          cells[r][c].right = false;
          cells[nr][nc].left = false;
        case 2:
          cells[r][c].bottom = false;
          cells[nr][nc].top = false;
        default:
          cells[r][c].left = false;
          cells[nr][nc].right = false;
      }
    }

    int distToGoal(int r, int c) =>
        (size - 1 - r).abs() + (size - 1 - c).abs();

    // Phase 1: carve a long winding solution from (0,0) to (size-1,size-1).
    // Most steps move away from the goal so the route snakes across the board;
    // once a good share of the board is covered, head for the goal to finish.
    final path = <(int, int)>[(0, 0)];
    markVisited(0, 0);
    var pr = 0;
    var pc = 0;
    while (pr != size - 1 || pc != size - 1) {
      final options = <(int, int, int)>[];
      if (pr > mid && !visited[pr - 1][pc]) options.add((pr - 1, pc, 0));
      if (pc < size - 1 && !visited[pr][pc + 1]) options.add((pr, pc + 1, 1));
      if (pr < size - 1 && !visited[pr + 1][pc]) options.add((pr + 1, pc, 2));
      if (pc > 0 && !visited[pr][pc - 1]) options.add((pr, pc - 1, 3));

      final sameHalf = <(int, int, int)>[];
      final cross = <(int, int, int)>[];
      for (final o in options) {
        if (pr >= mid) {
          (o.$1 >= mid ? sameHalf : cross).add(o);
        } else {
          (o.$1 < mid ? sameHalf : cross).add(o);
        }
      }
      final pool = sameHalf.isNotEmpty ? sameHalf : cross;

      if (pool.isEmpty) {
        if (path.length == 1) break;
        path.removeLast();
        (pr, pc) = path.last;
        continue;
      }

      final (nr, nc, dir) = _pickNext(
        pool,
        towardGoal: visitedCount >= total * 0.6,
        rng: rng,
        distToGoal: distToGoal,
      );
      carveBetween(pr, pc, nr, nc, dir);
      pr = nr;
      pc = nc;
      markVisited(pr, pc);
      path.add((pr, pc));
    }

    // Phase 2: fill every remaining cell with short dead-end branches off the
    // solution path, using Prim-style growth for lots of wrong turns.
    final inFrontier =
        List.generate(size, (_) => List<bool>.filled(size, false));
    final frontier = <(int, int)>[];

    void addFrontier(int r, int c) {
      if (r < 0 || r >= size || c < 0 || c >= size) return;
      if (visited[r][c] || inFrontier[r][c]) return;
      inFrontier[r][c] = true;
      frontier.add((r, c));
    }

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (visited[r][c]) continue;
        final hasVisited = (r > 0 && visited[r - 1][c]) ||
            (c < size - 1 && visited[r][c + 1]) ||
            (r < size - 1 && visited[r + 1][c]) ||
            (c > 0 && visited[r][c - 1]);
        if (hasVisited) addFrontier(r, c);
      }
    }

    while (frontier.isNotEmpty) {
      final (r, c) = frontier.removeAt(rng.nextInt(frontier.length));
      inFrontier[r][c] = false;
      if (visited[r][c]) continue;

      final visitedNeighbors = <(int, int, int)>[];
      if (r > 0 && visited[r - 1][c]) visitedNeighbors.add((r - 1, c, 0));
      if (c < size - 1 && visited[r][c + 1]) visitedNeighbors.add((r, c + 1, 1));
      if (r < size - 1 && visited[r + 1][c]) visitedNeighbors.add((r + 1, c, 2));
      if (c > 0 && visited[r][c - 1]) visitedNeighbors.add((r, c - 1, 3));
      if (visitedNeighbors.isEmpty) continue;

      final inHalf = r >= mid;
      final sameHalf =
          visitedNeighbors.where((n) => (n.$1 >= mid) == inHalf).toList();
      final pool = sameHalf.isNotEmpty ? sameHalf : visitedNeighbors;
      final (nr, nc, dir) = pool[rng.nextInt(pool.length)];
      carveBetween(r, c, nr, nc, dir);
      markVisited(r, c);
      addFrontier(r - 1, c);
      addFrontier(r, c + 1);
      addFrontier(r + 1, c);
      addFrontier(r, c - 1);
    }
  }

  void _connectHalf() {
    final mid = size ~/ 2;

    List<List<int>> halfComponents() {
      final comp = List.generate(size, (_) => List<int>.filled(size, -1));
      var nextId = 0;
      for (var r = mid; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (comp[r][c] != -1) continue;
          final queue = <(int, int)>[(r, c)];
          comp[r][c] = nextId;
          while (queue.isNotEmpty) {
            final (cr, cc) = queue.removeAt(0);
            final cell = cells[cr][cc];
            if (!cell.top && cr > mid && comp[cr - 1][cc] == -1) {
              comp[cr - 1][cc] = nextId;
              queue.add((cr - 1, cc));
            }
            if (!cell.bottom && cr < size - 1 && comp[cr + 1][cc] == -1) {
              comp[cr + 1][cc] = nextId;
              queue.add((cr + 1, cc));
            }
            if (!cell.left && cc > 0 && comp[cr][cc - 1] == -1) {
              comp[cr][cc - 1] = nextId;
              queue.add((cr, cc - 1));
            }
            if (!cell.right && cc < size - 1 && comp[cr][cc + 1] == -1) {
              comp[cr][cc + 1] = nextId;
              queue.add((cr, cc + 1));
            }
          }
          nextId++;
        }
      }
      return comp;
    }

    void carveWall(int r, int c, int nr, int nc, bool open) {
      if (nr == r - 1) {
        cells[r][c].top = open;
        cells[nr][nc].bottom = open;
      } else if (nr == r + 1) {
        cells[r][c].bottom = open;
        cells[nr][nc].top = open;
      } else if (nc == c - 1) {
        cells[r][c].left = open;
        cells[nr][nc].right = open;
      } else {
        cells[r][c].right = open;
        cells[nr][nc].left = open;
      }
    }

    int solutionLength() {
      final dist = List.generate(size, (_) => List<int>.filled(size, -1));
      final queue = <(int, int)>[(0, 0)];
      dist[0][0] = 0;
      while (queue.isNotEmpty) {
        final (r, c) = queue.removeAt(0);
        final cell = cells[r][c];
        if (!cell.top && dist[r - 1][c] == -1) {
          dist[r - 1][c] = dist[r][c] + 1;
          queue.add((r - 1, c));
        }
        if (!cell.bottom && dist[r + 1][c] == -1) {
          dist[r + 1][c] = dist[r][c] + 1;
          queue.add((r + 1, c));
        }
        if (!cell.left && dist[r][c - 1] == -1) {
          dist[r][c - 1] = dist[r][c] + 1;
          queue.add((r, c - 1));
        }
        if (!cell.right && dist[r][c + 1] == -1) {
          dist[r][c + 1] = dist[r][c] + 1;
          queue.add((r, c + 1));
        }
      }
      return dist[size - 1][size - 1];
    }

    while (true) {
      final comp = halfComponents();
      var componentCount = 0;
      for (var r = mid; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (comp[r][c] > componentCount) componentCount = comp[r][c];
        }
      }
      componentCount++;
      if (componentCount <= 1) break;

      final baseLen = solutionLength();
      var bestLen = -1;
      (int, int, int, int)? best;
      for (var r = mid; r < size; r++) {
        for (var c = 0; c < size; c++) {
          final candidates = <(int, int)>[
            if (r > mid) (r - 1, c),
            if (r < size - 1) (r + 1, c),
            if (c > 0) (r, c - 1),
            if (c < size - 1) (r, c + 1),
          ];
          for (final (nr, nc) in candidates) {
            if (comp[nr][nc] == comp[r][c]) continue;
            carveWall(r, c, nr, nc, false);
            final len = solutionLength();
            carveWall(r, c, nr, nc, true);
            if (len == baseLen && len > bestLen) {
              bestLen = len;
              best = (r, c, nr, nc);
            }
          }
        }
      }
      if (best == null) break;
      final (r, c, nr, nc) = best;
      carveWall(r, c, nr, nc, false);
    }
  }

  (int, int, int) _pickNext(
    List<(int, int, int)> options, {
    required bool towardGoal,
    required Random rng,
    required int Function(int, int) distToGoal,
  }) {
    if (towardGoal) {
      var best = options.first;
      var bestDist = distToGoal(best.$1, best.$2);
      var tied = <(int, int, int)>[best];
      for (final o in options.skip(1)) {
        final d = distToGoal(o.$1, o.$2);
        if (d < bestDist) {
          bestDist = d;
          best = o;
          tied = [o];
        } else if (d == bestDist) {
          tied.add(o);
        }
      }
      return tied[rng.nextInt(tied.length)];
    }
    if (rng.nextDouble() < 0.7) {
      var best = options.first;
      var bestDist = distToGoal(best.$1, best.$2);
      var tied = <(int, int, int)>[best];
      for (final o in options.skip(1)) {
        final d = distToGoal(o.$1, o.$2);
        if (d > bestDist) {
          bestDist = d;
          tied = [o];
        } else if (d == bestDist) {
          tied.add(o);
        }
      }
      return tied[rng.nextInt(tied.length)];
    }
    return options[rng.nextInt(options.length)];
  }

  bool isGoal() =>
      playerRow == size - 1 && playerCol == size - 1;

  bool move(int dr, int dc) {
    final nr = playerRow + dr;
    final nc = playerCol + dc;
    if (nr < 0 || nr >= size || nc < 0 || nc >= size) return false;
    final cur = cells[playerRow][playerCol];
    if (dr == -1 && cur.top) return false;
    if (dr == 1 && cur.bottom) return false;
    if (dc == -1 && cur.left) return false;
    if (dc == 1 && cur.right) return false;
    playerRow = nr;
    playerCol = nc;
    return true;
  }

  (int, int)? nextStepToward(int fromR, int fromC, int toR, int toC) {
    if (fromR == toR && fromC == toC) return null;
    final visited = List.generate(size, (_) => List<bool>.filled(size, false));
    final prevRow = List.generate(size, (_) => List<int>.filled(size, -1));
    final prevCol = List.generate(size, (_) => List<int>.filled(size, -1));
    final queue = <(int, int)>[(fromR, fromC)];
    visited[fromR][fromC] = true;

    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      if (r == toR && c == toC) {
        var cr = r;
        var cc = c;
        while (prevRow[cr][cc] != fromR || prevCol[cr][cc] != fromC) {
          final pr = prevRow[cr][cc];
          final pc = prevCol[cr][cc];
          cr = pr;
          cc = pc;
        }
        return (cr, cc);
      }
      final cell = cells[r][c];
      if (!cell.top && !visited[r - 1][c]) {
        visited[r - 1][c] = true;
        prevRow[r - 1][c] = r;
        prevCol[r - 1][c] = c;
        queue.add((r - 1, c));
      }
      if (!cell.right && !visited[r][c + 1]) {
        visited[r][c + 1] = true;
        prevRow[r][c + 1] = r;
        prevCol[r][c + 1] = c;
        queue.add((r, c + 1));
      }
      if (!cell.bottom && !visited[r + 1][c]) {
        visited[r + 1][c] = true;
        prevRow[r + 1][c] = r;
        prevCol[r + 1][c] = c;
        queue.add((r + 1, c));
      }
      if (!cell.left && !visited[r][c - 1]) {
        visited[r][c - 1] = true;
        prevRow[r][c - 1] = r;
        prevCol[r][c - 1] = c;
        queue.add((r, c - 1));
      }
    }
    return null;
  }

  Enemy? _enemyAtCell(int r, int c) {
    for (final e in enemies) {
      if (e.row == r && e.col == c) return e;
    }
    return null;
  }

  /// Distributed patrol AI: each enemy owns an exclusive arc of the patrol
  /// route and bounces along it, so enemies are spread across the map instead
  /// of all riding one side. If an enemy's next cell is occupied, it bounces
  /// back within its own arc so it never leaves it or overlaps a teammate.
  /// Off-route dead ends stay safe hiding spots.
  void advanceEnemy(Enemy e, {required Random rng}) {
    if (rng.nextDouble() >= e.pace) return;
    if (e.startIndex == e.endIndex) return;
    var next = e.patrolIndex + e.dir;
    if (next < e.startIndex || next > e.endIndex) {
      e.dir = -e.dir;
      next = e.patrolIndex + e.dir;
    }
    final target = patrolRoute[next];
    if (_enemyAtCell(target.$1, target.$2) != null) {
      final back = e.patrolIndex - e.dir;
      if (back < e.startIndex || back > e.endIndex) return;
      final behind = patrolRoute[back];
      if (_enemyAtCell(behind.$1, behind.$2) != null) return;
      e.dir = -e.dir;
      e.patrolIndex = back;
      e.row = behind.$1;
      e.col = behind.$2;
      return;
    }
    e.patrolIndex = next;
    e.row = target.$1;
    e.col = target.$2;
  }
}

class MazePainter extends CustomPainter {
  final Maze maze;
  final Color fg;
  final Color bg;

  MazePainter({
    required this.maze,
    required this.fg,
    required this.bg,
    required ValueNotifier<int> repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / maze.size;
    final wall = Paint()
      ..color = fg
      ..strokeWidth = max(1.0, cell * 0.12)
      ..strokeCap = StrokeCap.square;

    for (int r = 0; r < maze.size; r++) {
      for (int c = 0; c < maze.size; c++) {
        final x = c * cell;
        final y = r * cell;
        final m = maze.cells[r][c];
        if (m.top) {
          canvas.drawLine(Offset(x, y), Offset(x + cell, y), wall);
        }
        if (m.left) {
          canvas.drawLine(Offset(x, y), Offset(x, y + cell), wall);
        }
        if (m.bottom && r == maze.size - 1) {
          canvas.drawLine(Offset(x, y + cell), Offset(x + cell, y + cell), wall);
        }
        if (m.right && c == maze.size - 1) {
          canvas.drawLine(Offset(x + cell, y), Offset(x + cell, y + cell), wall);
        }
      }
    }

    final goal = Paint()
      ..color = fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, cell * 0.14);
    final gx = (maze.size - 1) * cell;
    final gy = (maze.size - 1) * cell;
    final gRect =
        Rect.fromLTWH(gx + cell * 0.22, gy + cell * 0.22, cell * 0.56, cell * 0.56);
    canvas.drawRect(gRect, Paint()..color = bg);
    canvas.drawRect(gRect, goal);
    canvas.drawRect(
      Rect.fromLTWH(gx + cell * 0.42, gy + cell * 0.42, cell * 0.16, cell * 0.16),
      Paint()..color = fg,
    );

    final playerRect = Rect.fromLTWH(
      maze.playerCol * cell + cell * 0.14,
      maze.playerRow * cell + cell * 0.14,
      cell * 0.72,
      cell * 0.72,
    );
    canvas.drawRect(playerRect, Paint()..color = bg);
    canvas.drawRect(
      playerRect,
      Paint()
        ..color = fg
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, cell * 0.12),
    );

    final enemyPaint = Paint()..color = fg;
    for (final e in maze.enemies) {
      canvas.drawCircle(
        Offset(e.col * cell + cell * 0.5, e.row * cell + cell * 0.5),
        cell * 0.32,
        enemyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) =>
      oldDelegate.fg != fg ||
      oldDelegate.bg != bg ||
      !identical(oldDelegate.maze, maze);
}

class MazeGame extends StatefulWidget {
  const MazeGame({super.key, required this.isDark, required this.onToggleDark});

  final bool isDark;
  final VoidCallback onToggleDark;

  @override
  State<MazeGame> createState() => _MazeGameState();
}

class _MazeGameState extends State<MazeGame> {
  late Maze _maze;
  int _level = 1;
  int _maxLevel = 1;
  bool _solving = false;
  bool _vibrationEnabled = true;
  Timer? _enemyTimer;

  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _maze = Maze(
      _mazeSizeForLevel(_level),
      enemyCount: _enemyCountForLevel(_level),
    );
    _loadProgress();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _enemyTimer?.cancel();
    _revision.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _enemyIntervalMs {
    final ms = 520 - _level * 2;
    return ms < 300 ? 300 : ms;
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMax = prefs.getInt('maxLevel') ?? 1;
    final saved = prefs.getInt('level') ?? savedMax;
    if (!mounted) return;
    setState(() {
      _maxLevel = max(savedMax, 1);
      _level = saved.clamp(1, _maxLevel);
    });
    _newMaze();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level', _level);
    await prefs.setInt('maxLevel', _maxLevel);
  }

  void _goToLevel(int level) {
    if (level < 1 || level > _maxLevel || level == _level) return;
    setState(() => _level = level);
    _saveProgress();
    _newMaze();
  }

  void _newMaze() {
    _maze = Maze(
      _mazeSizeForLevel(_level),
      enemyCount: _enemyCountForLevel(_level),
    );
    _revision.value++;
    _startEnemyTimer();
  }

  void _startEnemyTimer() {
    _enemyTimer?.cancel();
    _enemyTimer = Timer.periodic(
      Duration(milliseconds: _enemyIntervalMs),
      (_) {
        if (!mounted || _solving) return;
        if (_advanceEnemies()) _caught();
      },
    );
  }

  int _mazeSizeForLevel(int level) => 2 * level + 5;

  int _enemyCountForLevel(int level) => level;

  void _move(int dr, int dc) {
    if (_solving) return;
    if (!_maze.move(dr, dc)) return;
    setState(() {
      _revision.value++;
    });
    _vibrate();
    if (_maze.isGoal()) {
      _levelComplete();
      return;
    }
    if (_playerOnEnemy()) _caught();
  }

  Future<void> _vibrate() async {
    if (!_vibrationEnabled) return;
    try {
      await Vibration.vibrate(duration: 20);
    } catch (_) {}
  }

  bool _playerOnEnemy() => _maze.enemies.any(
        (e) => e.row == _maze.playerRow && e.col == _maze.playerCol,
      );

  bool _advanceEnemies() {
    if (_maze.enemies.isEmpty) return false;
    final rng = Random();
    for (final e in _maze.enemies) {
      _maze.advanceEnemy(e, rng: rng);
    }
    _revision.value++;
    return _playerOnEnemy();
  }

  void _caught() {
    _solving = true;
    final scheme = Theme.of(context).colorScheme;
    showDialog<bool>(
      context: context,
      barrierColor: scheme.surface,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'CAUGHT!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'An enemy cornered you.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Retry',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      setState(() {
        _solving = false;
        _newMaze();
      });
      _focusNode.requestFocus();
    });
  }

  void _levelComplete() {
    _solving = true;
    final scheme = Theme.of(context).colorScheme;
    showDialog<bool>(
      context: context,
      barrierColor: scheme.surface,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'LEVEL CLEAR!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Replay',
              style: TextStyle(color: scheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Next Level',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).then((replay) {
      setState(() {
        _solving = false;
        if (replay != true) {
          if (_level >= _maxLevel) _maxLevel++;
          _level++;
          _saveProgress();
        }
        _newMaze();
      });
      _focusNode.requestFocus();
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _move(0, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _move(0, 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final mazeSize = _maze.size;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: _handleKey,
          child: Column(
            children: [
              const TopBanner(),
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _level > 1
                              ? () => _goToLevel(_level - 1)
                              : null,
                          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                          disabledColor: scheme.onSurface.withValues(alpha: 0.35),
                          tooltip: 'Previous level',
                        ),
                        Text(
                          'LEVEL $_level',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        IconButton(
                          onPressed: _level < _maxLevel
                              ? () => _goToLevel(_level + 1)
                              : null,
                          icon: Icon(Icons.arrow_forward, color: scheme.onSurface),
                          disabledColor: scheme.onSurface.withValues(alpha: 0.35),
                          tooltip: 'Next level',
                        ),
                      ],
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'MOVAZE',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: widget.onToggleDark,
                          icon: Icon(
                            widget.isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            color: scheme.onSurface,
                          ),
                          tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _vibrationEnabled = !_vibrationEnabled,
                          ),
                          icon: Icon(
                            _vibrationEnabled
                                ? Icons.vibration
                                : Icons.vibration_outlined,
                            color: scheme.onSurface.withValues(
                              alpha: _vibrationEnabled ? 1 : 0.35,
                            ),
                          ),
                          tooltip: _vibrationEnabled
                              ? 'Vibration off'
                              : 'Vibration on',
                        ),
                        IconButton(
                          onPressed: () {
                            setState(_newMaze);
                            _focusNode.requestFocus();
                          },
                          icon: Icon(Icons.refresh, color: scheme.onSurface),
                          tooltip: 'New maze',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: scheme.onSurface, height: 12, thickness: 1),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CustomPaint(
                        painter: MazePainter(
                          maze: _maze,
                          fg: scheme.onSurface,
                          bg: scheme.surface,
                          repaint: _revision,
                        ),
                        size: Size.square(mazeSize.toDouble()),
                      ),
                    ),
                  ),
                ),
              ),
              Divider(color: scheme.onSurface, height: 12, thickness: 1),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: DPad(
                  onUp: () => _move(-1, 0),
                  onDown: () => _move(1, 0),
                  onLeft: () => _move(0, -1),
                  onRight: () => _move(0, 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DPad extends StatelessWidget {
  const DPad({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  static const double pad = 56;
  static const double gap = 10;

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  Widget _button(ColorScheme scheme, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: pad,
        height: pad,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.onSurface, width: 2),
        ),
        child: Icon(icon, color: scheme.onSurface, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(scheme, Icons.arrow_upward, onUp),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(scheme, Icons.arrow_back, onLeft),
            SizedBox(width: gap),
            SizedBox(width: pad, height: pad),
            SizedBox(width: gap),
            _button(scheme, Icons.arrow_forward, onRight),
          ],
        ),
        SizedBox(height: gap),
        _button(scheme, Icons.arrow_downward, onDown),
      ],
    );
  }
}
