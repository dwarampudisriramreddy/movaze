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
  _GameLaunch? _game;

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

  void _launch(_GameLaunch launch) {
    setState(() => _game = launch);
  }

  void _exitGame() {
    setState(() => _game = null);
  }

  void _toggleDark() {
    setState(() => _dark = !_dark);
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
      home: !_ready
          ? const SplashScreen()
          : _game == null
              ? HomeScreen(
                  isDark: _dark,
                  onToggleDark: _toggleDark,
                  onPlayLevel: (level) =>
                      _launch(_GameLaunch(level: level, daily: false)),
                  onPlayDaily: () =>
                      _launch(_GameLaunch(level: 1, daily: true)),
                  onPlayInfinity: () =>
                      _launch(_GameLaunch(level: 1, daily: false, infinity: true)),
                )
              : MazeGame(
                  isDark: _dark,
                  onToggleDark: _toggleDark,
                  onExit: _exitGame,
                  initialLevel: _game!.level,
                  dailyMode: _game!.daily,
                  infinityMode: _game!.infinity,
                ),
    );
  }
}

class _GameLaunch {
  final int level;
  final bool daily;
  final bool infinity;
  const _GameLaunch({
    required this.level,
    required this.daily,
    this.infinity = false,
  });
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
            const _GameLogo(size: 120),
            const SizedBox(height: 20),
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleDark,
    required this.onPlayLevel,
    required this.onPlayDaily,
    required this.onPlayInfinity,
  });

  final bool isDark;
  final VoidCallback onToggleDark;
  final void Function(int level) onPlayLevel;
  final VoidCallback onPlayDaily;
  final VoidCallback onPlayInfinity;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _maxLevel = 1;
  int _totalCoins = 0;
  int _infinityLevel = 26;
  bool _cleared25 = false;
  final Map<int, int> _stars = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final maxLevel = prefs.getInt('maxLevel') ?? 1;
    final coins = prefs.getInt('totalCoins') ?? 0;
    final infinityLevel = max(prefs.getInt('infinityLevel') ?? 26, 26);
    final cleared25 = prefs.getBool('cleared25') ?? false;
    final stars = <int, int>{};
    for (var i = 1; i <= maxLevel; i++) {
      stars[i] = prefs.getInt('level${i}_stars') ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _maxLevel = maxLevel;
      _totalCoins = coins;
      _infinityLevel = infinityLevel;
      _cleared25 = cleared25;
      _stars..clear()..addAll(stars);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _GameLogo(size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'MOVAZE',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_outlined,
                          color: Color(0xFFFFB300), size: 22),
                      const SizedBox(width: 4),
                      Text(
                        '$_totalCoins',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: scheme.onSurface, height: 12, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.onSurface,
                        foregroundColor: scheme.surface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: widget.onPlayDaily,
                      child: const Text(
                        'CHALLENGES',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.onSurface,
                        foregroundColor: scheme.surface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => widget.onPlayLevel(_maxLevel),
                      child: const Text(
                        'PLAY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _worldCount() + 1,
                itemBuilder: (context, index) => index < _worldCount()
                    ? _WorldCard(
                        world: index + 1,
                        stars: _stars,
                        maxLevel: _maxLevel,
                        onPlay: widget.onPlayLevel,
                      )
                    : _InfinityCard(
                        cleared25: _cleared25,
                        infinityLevel: _infinityLevel,
                        onPlay: _launchInfinity,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchInfinity() => widget.onPlayInfinity();

  int _worldCount() => 5;
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.stars,
    required this.maxLevel,
    required this.onPlay,
  });

  final int world;
  final Map<int, int> stars;
  final int maxLevel;
  final void Function(int level) onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = worldStart(world);
    final end = worldEnd(world);
    var total = 0;
    for (var l = start; l <= end; l++) {
      total += stars[l] ?? 0;
    }
    final unlockedLevels =
        (end <= maxLevel) ? 5 : (maxLevel >= start ? maxLevel - start + 1 : 0);
    final locked = unlockedLevels <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: locked ? 0.25 : 0.7),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WORLD $world',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    worldName(world),
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.star, color: Color(0xFFFFB300), size: 16),
              const SizedBox(width: 2),
              Text(
                '$total/15',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final level = start + i;
              final unlocked = level <= maxLevel;
              return _LevelTile(
                level: level,
                starCount: stars[level] ?? 0,
                unlocked: unlocked,
                onTap: unlocked ? () => onPlay(level) : null,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.starCount,
    required this.unlocked,
    required this.onTap,
  });

  final int level;
  final int starCount;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dim = unlocked ? 1.0 : 0.3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.5 * dim),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            if (unlocked)
              Text(
                '$level',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Icon(Icons.lock, color: scheme.onSurface.withValues(alpha: 0.3), size: 18),
            const SizedBox(height: 4),
            _StarRow(count: starCount, color: scheme.onSurface, size: 12),
          ],
        ),
      ),
    );
  }
}

class _InfinityCard extends StatelessWidget {
  const _InfinityCard({
    required this.cleared25,
    required this.infinityLevel,
    required this.onPlay,
  });

  final bool cleared25;
  final int infinityLevel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = cleared25;
    final bg =
        unlocked ? scheme.tertiaryContainer : scheme.surfaceContainerHighest;
    final fg =
        unlocked ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: bg,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: unlocked ? onPlay : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  unlocked ? Icons.all_inclusive : Icons.lock,
                  color: fg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INFINITY WORLD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unlocked
                            ? 'All worlds combined · Level $infinityLevel reached'
                            : 'Clear world 5 to unlock endless levels',
                        style: TextStyle(color: fg, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (unlocked) Icon(Icons.play_arrow, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  bool isBoss;

  Enemy(
    this.row,
    this.col,
    this.patrolIndex, {
    required this.startIndex,
    required this.endIndex,
    this.dir = 1,
    this.pace = 0.6,
    this.isBoss = false,
  });
}

class Maze {
  /// The boss abandons its patrol and hunts the player whenever the player is
  /// within this many cells (Manhattan distance).
  static const int bossChaseRadius = 4;

  final int size;
  final List<List<MazeCell>> cells;
  final Set<(int, int)> coins = {};
  final Set<(int, int)> keys = {};
  final Set<(int, int, int, int)> doors = {};
  final Set<(int, int)> explored = {};
  (int, int)? boostSpot;
  (int, int)? shieldSpot;
  int keysHeld = 0;
  bool hasShield = false;
  bool fogRemoved = false;
  bool keysRemoved = false;
  bool bossRemoved = false;
  Enemy? boss;
  int playerRow = 0;
  int playerCol = 0;
  final List<Enemy> enemies = [];
  late List<(int, int)> patrolRoute;
  late final Random _rng;
  final bool _keysEnabled;
  final bool _shieldEnabled;
  final bool _fogEnabled;
  final bool _bossEnabled;

  bool get hasKeys => _keysEnabled && !keysRemoved;
  bool get shieldEnabled => _shieldEnabled;
  bool get hasFog => _fogEnabled && !fogRemoved;
  bool get hasBoss => _bossEnabled && !bossRemoved;

  Maze(
    this.size, {
    int enemyCount = 0,
    int? seed,
    bool keys = false,
    bool shield = true,
    bool fog = false,
    bool boss = false,
    int doorCount = 0,
  }) : cells =
            List.generate(size, (_) => List.generate(size, (_) => MazeCell())),
       _keysEnabled = keys,
       _shieldEnabled = shield,
       _fogEnabled = fog,
       _bossEnabled = boss {
       _rng = Random(seed);
    _generateWithRetry(enemyCount);
    for (var attempt = 0; attempt < 60; attempt++) {
      _buildPatrolRoute();
      if (enemyCount <= 0) break;
      if (_hideIndices().length >= enemyCount && _routeHasLeafBeside()) break;
    }
    if (enemyCount > 0) _placeEnemies(enemyCount);
    if (_bossEnabled) _placeBoss();
    if (_keysEnabled) _placeKeysAndDoors(doorCount);
    _scatterPickups(enemyCount);
    explore(0, 0);
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

  /// True when at least one route cell sits directly beside a true dead-end
  /// leaf (open on only one side), so the player always has a dead-end hiding
  /// spot to duck into right on an enemy's path.
  bool _routeHasLeafBeside() {
    final onRoute = {for (final p in patrolRoute) p};
    bool isLeaf(int nr, int nc) {
      if (nr < size ~/ 2) return false;
      if (nr == size - 1 && nc == size - 1) return false;
      if (onRoute.contains((nr, nc))) return false;
      final n = cells[nr][nc];
      var open = 0;
      if (!n.top) open++;
      if (!n.bottom) open++;
      if (!n.left) open++;
      if (!n.right) open++;
      return open == 1;
    }

    for (var i = 0; i < patrolRoute.length; i++) {
      final (r, c) = patrolRoute[i];
      final cell = cells[r][c];
      if (r > size ~/ 2 && !cell.top && isLeaf(r - 1, c)) return true;
      if (r < size - 1 && !cell.bottom && isLeaf(r + 1, c)) return true;
      if (c > 0 && !cell.left && isLeaf(r, c - 1)) return true;
      if (c < size - 1 && !cell.right && isLeaf(r, c + 1)) return true;
    }
    return false;
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
    final rng = _rng;
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

  /// Scatters collectible coins and a single speed-boost pickup on reachable
  /// cells, never on the start, the goal, or an enemy's spawn point. The
  /// shield pickup prefers a dead-end hiding spot.
  void _scatterPickups(int enemyCount) {
    final seen = List.generate(size, (_) => List<bool>.filled(size, false));
    final queue = <(int, int)>[(0, 0)];
    seen[0][0] = true;
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      final cell = cells[r][c];
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

    final excluded = <(int, int)>{(0, 0), (size - 1, size - 1)};
    for (final e in enemies) {
      excluded.add((e.row, e.col));
    }
    if (boss != null) excluded.add((boss!.row, boss!.col));
    for (final k in keys) {
      excluded.add(k);
    }
    for (final d in doors) {
      excluded.add((d.$1, d.$2));
      excluded.add((d.$3, d.$4));
    }
    bool isDeadEnd(int r, int c) {
      final cell = cells[r][c];
      var open = 0;
      if (!cell.top) open++;
      if (!cell.bottom) open++;
      if (!cell.left) open++;
      if (!cell.right) open++;
      return open == 1;
    }

    final candidates = <(int, int)>[];
    final deadEnds = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (!seen[r][c] || excluded.contains((r, c))) continue;
        (isDeadEnd(r, c) ? deadEnds : candidates).add((r, c));
      }
    }
    candidates.shuffle(_rng);
    deadEnds.shuffle(_rng);

    final all = <(int, int)>[...candidates, ...deadEnds];
    final coinCount = min(2 + enemyCount, all.length);
    coins.addAll(all.take(coinCount));
    final used = <(int, int)>{...coins};

    (int, int)? takeDeadEnd() {
      for (final d in deadEnds) {
        if (!used.contains(d)) {
          used.add(d);
          return d;
        }
      }
      return null;
    }

    (int, int)? takeAny(int from) {
      if (from >= all.length) return null;
      for (var i = from; i < all.length; i++) {
        if (!used.contains(all[i])) {
          used.add(all[i]);
          return all[i];
        }
      }
      return null;
    }

    if (_shieldEnabled) shieldSpot = takeDeadEnd() ?? takeAny(coinCount);
    if (enemyCount > 0) boostSpot = takeDeadEnd() ?? takeAny(coinCount);
  }

  /// Consumes any pickup at [r],[c], reporting what was collected.
  ({bool coin, bool boost, bool key, bool shield}) takePickup(int r, int c) {
    final hadCoin = coins.remove((r, c));
    final hadBoost = boostSpot == (r, c);
    if (hadBoost) boostSpot = null;
    final hadKey = keys.remove((r, c));
    if (hadKey) keysHeld++;
    final hadShield = shieldSpot == (r, c);
    if (hadShield) {
      shieldSpot = null;
      hasShield = true;
    }
    return (coin: hadCoin, boost: hadBoost, key: hadKey, shield: hadShield);
  }

  /// Reveals cells within a short radius of [r],[c] for the fog of war.
  void explore(int r, int c) {
    for (var dr = -2; dr <= 2; dr++) {
      for (var dc = -2; dc <= 2; dc++) {
        if (dr.abs() + dc.abs() > 2) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        explored.add((nr, nc));
      }
    }
  }

  (int, int, int, int) _normDoor(int r1, int c1, int r2, int c2) {
    final a = r1 * size + c1;
    final b = r2 * size + c2;
    return a < b ? (r1, c1, r2, c2) : (r2, c2, r1, c1);
  }

  (int, int, int, int)? _doorAt(int r, int c, int nr, int nc) {
    final d = _normDoor(r, c, nr, nc);
    return doors.contains(d) ? d : null;
  }

  /// Unique solution path cells from start to goal, in order.
  List<(int, int)> _solutionPath() {
    final parent =
        List.generate(size, (_) => List<(int, int)?>.filled(size, null));
    final queue = <(int, int)>[(0, 0)];
    parent[0][0] = (0, 0);
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      if (r == size - 1 && c == size - 1) break;
      final cell = cells[r][c];
      void tryAdd(int nr, int nc) {
        if (parent[nr][nc] != null) return;
        parent[nr][nc] = (r, c);
        queue.add((nr, nc));
      }

      if (!cell.top) tryAdd(r - 1, c);
      if (!cell.right) tryAdd(r, c + 1);
      if (!cell.bottom) tryAdd(r + 1, c);
      if (!cell.left) tryAdd(r, c - 1);
    }
    final path = <(int, int)>[];
    var (sr, sc) = (size - 1, size - 1);
    while (parent[sr][sc] != null && parent[sr][sc] != (sr, sc)) {
      path.add((sr, sc));
      final p = parent[sr][sc]!;
      sr = p.$1;
      sc = p.$2;
    }
    path.add((0, 0));
    return path.reversed.toList();
  }

  /// Cells reachable from the start treating every locked door as a wall.
  List<List<bool>> _reachableIgnoringDoors() {
    final seen = List.generate(size, (_) => List<bool>.filled(size, false));
    final queue = <(int, int)>[(0, 0)];
    seen[0][0] = true;
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      final cell = cells[r][c];
      void tryAdd(int nr, int nc) {
        if (seen[nr][nc]) return;
        if (_doorAt(r, c, nr, nc) != null) return;
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

  /// Locks doors onto the solution path and scatters a matching number of
  /// keys on cells reachable from the start without opening any door, so the
  /// player always collects enough keys before hitting a locked door.
  void _placeKeysAndDoors(int doorCount) {
    if (doorCount <= 0) return;
    final path = _solutionPath();
    final L = path.length;
    if (L < 10) return;
    final lo = (L * 0.35).floor().clamp(1, L - 2);
    final hi = (L * 0.75).ceil().clamp(1, L - 2);
    if (hi <= lo) return;
    final chosen = <int>[];
    for (var i = 0; i < doorCount; i++) {
      var guard = 0;
      while (guard++ < 64) {
        final idx = lo + _rng.nextInt(hi - lo + 1);
        if (!chosen.contains(idx)) {
          chosen.add(idx);
          break;
        }
      }
    }
    chosen.sort();
    for (final k in chosen) {
      final (r1, c1) = path[k];
      final (r2, c2) = path[k + 1];
      doors.add(_normDoor(r1, c1, r2, c2));
    }

    final reachable = _reachableIgnoringDoors();
    final excluded = <(int, int)>{(0, 0), (size - 1, size - 1)};
    for (final d in doors) {
      excluded.add((d.$1, d.$2));
      excluded.add((d.$3, d.$4));
    }
    for (final e in enemies) {
      excluded.add((e.row, e.col));
    }
    if (boss != null) excluded.add((boss!.row, boss!.col));
    final candidates = <(int, int)>[];
    final deadEnds = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (!reachable[r][c] || excluded.contains((r, c))) continue;
        final cell = cells[r][c];
        var open = 0;
        if (!cell.top) open++;
        if (!cell.bottom) open++;
        if (!cell.left) open++;
        if (!cell.right) open++;
        (open == 1 ? deadEnds : candidates).add((r, c));
      }
    }
    candidates.shuffle(_rng);
    deadEnds.shuffle(_rng);

    if (doors.length > candidates.length + deadEnds.length) {
      final keep = doors.take(candidates.length + deadEnds.length).toList();
      doors
        ..clear()
        ..addAll(keep);
    }
    // Keys hide in dead-end cells first so grabbing one means exploring a
    // hiding spot, then fall back to any reachable cell.
    keys.addAll([...deadEnds, ...candidates].take(doors.length));
  }

  void _placeBoss() {
    if (patrolRoute.isEmpty) return;
    final used = {for (final e in enemies) e.patrolIndex};
    var idx = patrolRoute.length ~/ 2;
    for (var i = 0; i < patrolRoute.length; i++) {
      final cand = (patrolRoute.length ~/ 2 + i) % patrolRoute.length;
      if (!used.contains(cand)) {
        idx = cand;
        break;
      }
    }
    final (r, c) = patrolRoute[idx];
    boss = Enemy(
      r,
      c,
      idx,
      startIndex: 0,
      endIndex: patrolRoute.length - 1,
      dir: 1,
      pace: 1.0,
      isBoss: true,
    );
  }

  /// Length of the unique solution path from start to goal.
  int solutionLength() {
    final dist = List.generate(size, (_) => List<int>.filled(size, -1));
    final queue = <(int, int)>[(0, 0)];
    dist[0][0] = 0;
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeAt(0);
      if (r == size - 1 && c == size - 1) break;
      final cell = cells[r][c];
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
    return dist[size - 1][size - 1];
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

    // Patrol walk: a self-avoiding snake over the main backbone, so every cell
    // appears exactly once. Enemies own exclusive arcs of it, so they can never
    // share a cell or block each other. The goal is never patrolled so the
    // level can always be won. The walk is anchored in a bottom-half dead-end
    // cell (a real cul-de-sac) so the patrol always includes a dead end the
    // enemies walk into and turn around at.
    final rng = _rng;
    final starts = <(int, int)>[];
    for (var r = mid; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (main[r][c] && !(r == size - 1 && c == size - 1)) {
          starts.add((r, c));
        }
      }
    }
    final anchors = <(int, int)>[];
    for (var r = mid; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (r == size - 1 && c == size - 1) continue;
        final n = _openNeighbours(r, c);
        if (n.length != 1) continue;
        final (nr, nc) = n.single;
        if (nr == size - 1 && nc == size - 1) continue;
        anchors.add((r, c));
      }
    }
    var best = <(int, int)>[];
    for (var attempt = 0; attempt < 100; attempt++) {
      final visited =
          List.generate(size, (_) => List<bool>.filled(size, false));
      final start = anchors.isNotEmpty
          ? anchors[rng.nextInt(anchors.length)]
          : starts[rng.nextInt(starts.length)];
      final route = <(int, int)>[];
      var (r, c) = start;
      // Walk the dead-end spur from the anchor leaf out to the backbone, so
      // the patrol always begins in a real cul-de-sac.
      while (true) {
        route.add((r, c));
        visited[r][c] = true;
        if (main[r][c]) break;
        final open = _openNeighbours(r, c)
            .where((p) => !visited[p.$1][p.$2])
            .toList();
        if (open.length != 1) break;
        final (nr, nc) = open.single;
        if (nr == size - 1 && nc == size - 1) break;
        r = nr;
        c = nc;
      }
      if (main[r][c]) {
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
          if (options.isEmpty) {
            // If the walk gets stuck beside a dead-end hiding spot, end the
            // patrol there so the route finishes in a second cul-de-sac.
            final leaf = _deadEndBeside(r, c, visited);
            if (leaf != null) {
              visited[leaf.$1][leaf.$2] = true;
              route.add(leaf);
            }
            break;
          }
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
      }
      if (route.length > best.length) best = route;
    }
    patrolRoute = best;
  }

  List<(int, int)> _openNeighbours(int r, int c) {
    final cell = cells[r][c];
    final list = <(int, int)>[];
    if (r > 0 && !cell.top) list.add((r - 1, c));
    if (r < size - 1 && !cell.bottom) list.add((r + 1, c));
    if (c > 0 && !cell.left) list.add((r, c - 1));
    if (c < size - 1 && !cell.right) list.add((r, c + 1));
    return list;
  }

  /// A bottom-half dead-end cell next to [r],[c] whose only open neighbour is
  /// [r],[c] itself, or null if there is none.
  (int, int)? _deadEndBeside(int r, int c, List<List<bool>> visited) {
    for (final (nr, nc) in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]) {
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
      if (visited[nr][nc]) continue;
      if (nr == size - 1 && nc == size - 1) continue;
      final n = _openNeighbours(nr, nc);
      if (n.length == 1 && n.single == (r, c)) return (nr, nc);
    }
    return null;
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
    final rng = _rng;
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
    final door = _doorAt(playerRow, playerCol, nr, nc);
    if (door != null) {
      if (keysHeld <= 0) return false;
      keysHeld--;
      doors.remove(door);
    }
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
    final b = boss;
    if (b != null && b.row == r && b.col == c) return b;
    return null;
  }

  /// Distributed patrol AI: each enemy owns an exclusive arc of the patrol
  /// route and bounces along it, so enemies are spread across the map instead
  /// of all riding one side. If an enemy's next cell is occupied, it bounces
  /// back within its own arc so it never leaves it or overlaps a teammate.
  /// Off-route dead ends stay safe hiding spots.
  /// The boss patrols the same way, but while the player is within
  /// [bossChaseRadius] cells it abandons the route and hunts the player down.
  void advanceEnemy(Enemy e, {required Random rng}) {
    if (rng.nextDouble() >= e.pace) return;
    if (e.isBoss && _chasePlayer(e)) return;
    if (e.isBoss) _snapToRoute(e);
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

  /// If the boss is within chase range of the player, move it one BFS step
  /// toward the player and report that the move was a chase.
  bool _chasePlayer(Enemy e) {
    if (e.row == playerRow && e.col == playerCol) return false;
    final dist = (e.row - playerRow).abs() + (e.col - playerCol).abs();
    if (dist > bossChaseRadius) return false;
    final step = nextStepToward(e.row, e.col, playerRow, playerCol);
    if (step == null) return false;
    e.row = step.$1;
    e.col = step.$2;
    return true;
  }

  /// After a chase the boss may sit off the route; bring it back to the
  /// nearest free route cell so patrolling resumes without a long teleport.
  void _snapToRoute(Enemy e) {
    final cur = patrolRoute[e.patrolIndex];
    if (e.row == cur.$1 && e.col == cur.$2) return;
    var best = -1;
    var bestDist = 1 << 30;
    for (var i = e.startIndex; i <= e.endIndex; i++) {
      final p = patrolRoute[i];
      if (_enemyAtCell(p.$1, p.$2) != null) continue;
      final d = (p.$1 - e.row).abs() + (p.$2 - e.col).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    if (best < 0) return;
    e.patrolIndex = best;
    e.row = patrolRoute[best].$1;
    e.col = patrolRoute[best].$2;
  }
}

class MazePainter extends CustomPainter {
  final Maze maze;
  final Color fg;
  final Color bg;
  final double zoom;

  MazePainter({
    required this.maze,
    required this.fg,
    required this.bg,
    this.zoom = 1.0,
    required ValueNotifier<int> repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final baseCell = size.width / maze.size;
    if (zoom > 1.001) {
      // Show a window around the player, clamped to the maze bounds.
      final window = size.width / (baseCell * zoom);
      final half = window / 2;
      final pr = maze.playerRow + 0.5;
      final pc = maze.playerCol + 0.5;
      final centerR = pr.clamp(half, maze.size - half);
      final centerC = pc.clamp(half, maze.size - half);
      canvas.translate(
          -(centerC - half) * baseCell * zoom, -(centerR - half) * baseCell * zoom);
      canvas.scale(zoom, zoom);
    }
    final cell = baseCell;
    final fog = maze.hasFog;
    bool visible(int r, int c) => !fog || maze.explored.contains((r, c));
    final wall = Paint()
      ..color = fg
      ..strokeWidth = max(1.0, cell * 0.12)
      ..strokeCap = StrokeCap.square;

    if (fog) {
      final fogPaint = Paint()..color = bg;
      for (var r = 0; r < maze.size; r++) {
        for (var c = 0; c < maze.size; c++) {
          if (!visible(r, c)) {
            canvas.drawRect(
              Rect.fromLTWH(c * cell, r * cell, cell, cell),
              fogPaint,
            );
          }
        }
      }
    }

    for (int r = 0; r < maze.size; r++) {
      for (int c = 0; c < maze.size; c++) {
        final x = c * cell;
        final y = r * cell;
        final m = maze.cells[r][c];
        if (m.top && (visible(r, c) || (r > 0 && visible(r - 1, c)))) {
          canvas.drawLine(Offset(x, y), Offset(x + cell, y), wall);
        }
        if (m.left && (visible(r, c) || (c > 0 && visible(r, c - 1)))) {
          canvas.drawLine(Offset(x, y), Offset(x, y + cell), wall);
        }
        if (m.bottom && r == maze.size - 1 && visible(r, c)) {
          canvas.drawLine(Offset(x, y + cell), Offset(x + cell, y + cell), wall);
        }
        if (m.right && c == maze.size - 1 && visible(r, c)) {
          canvas.drawLine(Offset(x + cell, y), Offset(x + cell, y + cell), wall);
        }
      }
    }

    if (visible(maze.size - 1, maze.size - 1)) {
      final goal = Paint()
        ..color = fg
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, cell * 0.14);
      final gx = (maze.size - 1) * cell;
      final gy = (maze.size - 1) * cell;
      final gRect = Rect.fromLTWH(
          gx + cell * 0.22, gy + cell * 0.22, cell * 0.56, cell * 0.56);
      canvas.drawRect(gRect, Paint()..color = bg);
      canvas.drawRect(gRect, goal);
      canvas.drawRect(
        Rect.fromLTWH(
            gx + cell * 0.42, gy + cell * 0.42, cell * 0.16, cell * 0.16),
        Paint()..color = fg,
      );
    }

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
    final drawables = [
      ...maze.enemies,
      if (maze.boss != null && !maze.boss!.isBoss) maze.boss!,
    ];
    for (final e in drawables) {
      if (!visible(e.row, e.col)) continue;
      canvas.drawCircle(
        Offset(e.col * cell + cell * 0.5, e.row * cell + cell * 0.5),
        cell * 0.32,
        enemyPaint,
      );
    }

    final boss = maze.boss;
    if (boss != null && boss.isBoss && visible(boss.row, boss.col)) {
      final bcx = boss.col * cell + cell * 0.5;
      final bcy = boss.row * cell + cell * 0.5;
      final radius = Maze.bossChaseRadius * cell;
      final chasePath = Path()
        ..moveTo(bcx, bcy - radius)
        ..lineTo(bcx + radius, bcy)
        ..lineTo(bcx, bcy + radius)
        ..lineTo(bcx - radius, bcy)
        ..close();
      canvas.drawPath(
        chasePath,
        Paint()
          ..color = const Color(0xFFE53935).withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        chasePath,
        Paint()
          ..color = const Color(0xFFE53935).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, cell * 0.04),
      );
      canvas.drawCircle(
        Offset(bcx, bcy),
        cell * 0.4,
        Paint()..color = const Color(0xFFE53935),
      );
      canvas.drawCircle(
        Offset(bcx - cell * 0.14, bcy - cell * 0.05),
        cell * 0.09,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(bcx + cell * 0.14, bcy - cell * 0.05),
        cell * 0.09,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(bcx - cell * 0.12, bcy - cell * 0.04),
        cell * 0.045,
        Paint()..color = Colors.black,
      );
      canvas.drawCircle(
        Offset(bcx + cell * 0.16, bcy - cell * 0.04),
        cell * 0.045,
        Paint()..color = Colors.black,
      );
    }

    final coinPaint = Paint()..color = const Color(0xFFFFB300);
    for (final (r, c) in maze.coins) {
      if (!visible(r, c)) continue;
      canvas.drawCircle(
        Offset(c * cell + cell * 0.5, r * cell + cell * 0.5),
        cell * 0.18,
        coinPaint,
      );
    }

    final keyColor = const Color(0xFF795548);
    final keyStroke = Paint()
      ..color = keyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, cell * 0.07);
    final keyFill = Paint()..color = keyColor;
    for (final (r, c) in maze.keys) {
      if (!visible(r, c)) continue;
      final cx = c * cell + cell * 0.5;
      final cy = r * cell + cell * 0.5;
      canvas.drawCircle(Offset(cx - cell * 0.12, cy), cell * 0.1, keyStroke);
      canvas.drawLine(
          Offset(cx - cell * 0.02, cy), Offset(cx + cell * 0.2, cy), keyFill);
      canvas.drawLine(Offset(cx + cell * 0.12, cy),
          Offset(cx + cell * 0.12, cy + cell * 0.1), keyFill);
      canvas.drawLine(Offset(cx + cell * 0.2, cy),
          Offset(cx + cell * 0.2, cy + cell * 0.08), keyFill);
    }

    final lockedPaint = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = max(3.5, cell * 0.38)
      ..strokeCap = StrokeCap.round;
    // Once the player holds a key the doors read as open (a thin, faded line)
    // so collecting a key visibly unlocks them.
    final openPaint = Paint()
      ..color = const Color(0xFF795548).withValues(alpha: 0.5)
      ..strokeWidth = max(1.5, cell * 0.08)
      ..strokeCap = StrokeCap.round;
    final doorPaint = maze.keysHeld > 0 ? openPaint : lockedPaint;
    for (final d in maze.doors) {
      if (!visible(d.$1, d.$2) && !visible(d.$3, d.$4)) continue;
      if (d.$1 == d.$3) {
        final x = max(d.$2, d.$4) * cell;
        final y = d.$1 * cell;
        canvas.drawLine(Offset(x, y), Offset(x, y + cell), doorPaint);
      } else {
        final y = max(d.$1, d.$3) * cell;
        final x = d.$2 * cell;
        canvas.drawLine(Offset(x, y), Offset(x + cell, y), doorPaint);
      }
    }

    final boost = maze.boostSpot;
    if (boost != null && visible(boost.$1, boost.$2)) {
      final (br, bc) = boost;
      final cx = bc * cell + cell * 0.5;
      final cy = br * cell + cell * 0.5;
      // The exact Material "ac_unit" snowflake glyph, matching the FROZEN
      // indicator and the freeze buy chip.
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.ac_unit.codePoint),
          style: TextStyle(
            fontSize: cell * 0.55,
            fontFamily: Icons.ac_unit.fontFamily,
            package: Icons.ac_unit.fontPackage,
            color: const Color(0xFF26A69A),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }

    final shield = maze.shieldSpot;
    if (shield != null && visible(shield.$1, shield.$2)) {
      final (sr, sc) = shield;
      final cx = sc * cell + cell * 0.5;
      final cy = sr * cell + cell * 0.5;
      final r = cell * 0.28;
      final path = Path()
        ..moveTo(cx, cy - r)
        ..quadraticBezierTo(cx - r, cy - r * 0.7, cx - r, cy - r * 0.15)
        ..lineTo(cx - r, cy + r * 0.4)
        ..lineTo(cx, cy + r)
        ..lineTo(cx + r, cy + r * 0.4)
        ..lineTo(cx + r, cy - r * 0.15)
        ..quadraticBezierTo(cx + r, cy - r * 0.7, cx, cy - r)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF26A69A));
    }
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.fg != fg ||
      oldDelegate.bg != bg ||
      !identical(oldDelegate.maze, maze);
}

class MazeGame extends StatefulWidget {
  const MazeGame({
    super.key,
    required this.isDark,
    required this.onToggleDark,
    this.onExit,
    this.initialLevel = 1,
    this.dailyMode = false,
    this.dailySeed,
    this.infinityMode = false,
  });

  final bool isDark;
  final VoidCallback onToggleDark;
  final VoidCallback? onExit;
  final int initialLevel;
  final bool dailyMode;
  final int? dailySeed;
  final bool infinityMode;

  @override
  State<MazeGame> createState() => _MazeGameState();
}

int mazeSizeForLevel(int level) => 2 * level + 5;

int infinitySizeForLevel(int level) => 2 * level + 5;

int infinityEnemyCountForLevel(int level) => min(1 + (level - 1) ~/ 2, 10);

int infinityDoorCountForLevel(int level) => min(2 + (level - 1) ~/ 5, 3);

/// Each world has its own mechanic: 1=pure maze, 2=enemies,
/// 3=keys/doors, 4=fog, 5=boss world (fewer patrols, boss every level).
int enemyCountForLevel(int level) {
  final world = worldForLevel(level);
  if (world == 1) return level >= 3 ? 1 : 0;
  if (world >= 5) return max(1, level ~/ 2);
  return level;
}

int doorCountForLevel(int level) {
  final world = worldForLevel(level);
  if (world < 3) return 0;
  if (world < 4) return 2;
  return 3;
}

bool hasKeysForLevel(int level) => worldForLevel(level) >= 3;

bool hasFogForLevel(int level) => worldForLevel(level) >= 4;

bool hasBossForLevel(int level) => worldForLevel(level) >= 5;

bool hasShieldForLevel(int level) => true;

/// Display name of a world, matching its signature mechanic.
String worldName(int world) => switch (world) {
      1 => 'MEADOW',
      2 => 'HUNTED',
      3 => 'LOCKED',
      4 => 'FOGGY',
      _ => 'BOSSLAND',
    };

/// Number of stars a [level] sits inside, 1-based (level 5 is world 1).
int worldForLevel(int level) => (level - 1) ~/ 5 + 1;

/// First level of a [world].
int worldStart(int world) => (world - 1) * 5 + 1;

/// Last level of a [world].
int worldEnd(int world) => world * 5;

class _MazeGameState extends State<MazeGame> {
  late Maze _maze;
  static const String _rewardedAdUnitId =
      'ca-app-pub-3464757507183621/6929219436';

  int _level = 1;
  int _maxLevel = 1;
  int _totalCoins = 0;
  int _coinsThisLevel = 0;
  int _coinCount = 0;
  int _catches = 0;
  int _moves = 0;
  bool _solving = false;
  bool _vibrationEnabled = true;
  bool _boosted = false;
  bool _dailyMode = false;
  bool _infinityMode = false;
  bool _dailyDone = false;
  double _zoom = 1.0;
  int _dailyLevel = 1;
  int _savedLevel = 1;
  DateTime _graceUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _dailyDeadline = DateTime.fromMillisecondsSinceEpoch(0);
  int _dailySecondsLeft = 300;
  Timer? _dailyTimer;
  static const int _dailyTimeSeconds = 300;
  static const int _shieldCost = 10;
  static const int _freezeCost = 5;
  static const int _fogCost = 15;
  static const int _keysCost = 12;
  static const int _bossCost = 25;
  Timer? _enemyTimer;
  Timer? _boostTimer;
  RewardedAd? _rewardedAd;
  bool _rewardedAdLoading = false;
  final Map<int, int> _starsByLevel = {};
  final Map<int, int> _bestMovesByLevel = {};

  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _dailyMode = widget.dailyMode;
    _infinityMode = widget.infinityMode;
    _level = widget.initialLevel;
    _maxLevel = max(widget.initialLevel, 1);
    if (_dailyMode) {
      _dailyLevel = 1 + (widget.dailySeed ?? _dailySeed) % 25;
      _level = _dailyLevel;
    }
    _maze = _infinityMode
        ? _infinityMaze()
        : Maze(
            mazeSizeForLevel(_level),
            enemyCount: enemyCountForLevel(_level),
            keys: hasKeysForLevel(_level),
            shield: hasShieldForLevel(_level),
            fog: hasFogForLevel(_level),
            boss: hasBossForLevel(_level),
            doorCount: doorCountForLevel(_level),
          );
    _loadProgress();
    _focusNode.requestFocus();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _enemyTimer?.cancel();
    _boostTimer?.cancel();
    _dailyTimer?.cancel();
    _rewardedAd?.dispose();
    _revision.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _enemyIntervalMs {
    final ms = 520 - _level * 2;
    return ms < 300 ? 300 : ms;
  }

  bool get _graceActive => DateTime.now().isBefore(_graceUntil);

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  int get _dailySeed {
    if (widget.dailySeed != null) return widget.dailySeed!;
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMax = prefs.getInt('maxLevel');
    final savedInfinity = max(prefs.getInt('infinityLevel') ?? 26, 26);
    final totalCoins = prefs.getInt('totalCoins') ?? 0;
    final dailyDone = prefs.getBool('dailyDone_$_todayKey') ?? false;
    if (!mounted) return;
    setState(() {
      _maxLevel = min(max(savedMax ?? 1, widget.initialLevel), 25);
      if (_infinityMode) {
        _level = savedInfinity;
      } else if (!_dailyMode) {
        _level = widget.initialLevel.clamp(1, _maxLevel);
      }
      _totalCoins = totalCoins;
      _dailyDone = dailyDone;
    });
    for (var i = 1; i <= _maxLevel; i++) {
      _starsByLevel[i] = prefs.getInt('level${i}_stars') ?? 0;
      _bestMovesByLevel[i] = prefs.getInt('level${i}_bestMoves') ?? 0;
    }
    _newMaze();
    if (_dailyMode) _startDailyCountdown();
    if (_dailyMode || _infinityMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showModeHint());
    }
  }

  void _showModeHint() {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final title = _dailyMode ? 'CHALLENGES' : 'INFINITY WORLD';
    final body = _dailyMode
        ? 'Find the exit before the timer runs out and earn bonus coins.'
        : 'Every world combined into one endless maze. Reach the exit, level after level.';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: scheme.onSurface)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level', _level);
    await prefs.setInt('maxLevel', _maxLevel);
  }

  Future<void> _saveInfinity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('infinityLevel', max(_level, 26));
  }

  Future<void> _saveTotalCoins() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalCoins', _totalCoins);
  }

  void _goToLevel(int level) {
    if (_dailyMode) return;
    if (_infinityMode) {
      if (level < 26 || level == _level) return;
      setState(() => _level = level);
      _saveInfinity();
      _newMaze();
      return;
    }
    if (level < 1 || level > _maxLevel || level == _level) return;
    setState(() => _level = level);
    _saveProgress();
    _newMaze();
  }

  Maze _infinityMaze() => Maze(
        infinitySizeForLevel(_level),
        enemyCount: infinityEnemyCountForLevel(_level),
        keys: true,
        shield: true,
        fog: true,
        boss: true,
        doorCount: infinityDoorCountForLevel(_level),
      );

  void _newMaze({int? seed}) {
    _maze = _infinityMode
        ? _infinityMaze()
        : Maze(
            mazeSizeForLevel(_level),
            enemyCount: enemyCountForLevel(_level),
            seed: seed,
            keys: hasKeysForLevel(_level),
            shield: hasShieldForLevel(_level),
            fog: hasFogForLevel(_level),
            boss: hasBossForLevel(_level),
            doorCount: doorCountForLevel(_level),
          );
    _coinsThisLevel = 0;
    _coinCount = _maze.coins.length;
    _catches = 0;
    _moves = 0;
    _boosted = false;
    _zoom = _defaultZoom();
    _boostTimer?.cancel();
    _graceUntil = DateTime.fromMillisecondsSinceEpoch(0);
    if (_dailyMode && !_dailyDone) {
      _dailyDeadline =
          DateTime.now().add(const Duration(seconds: _dailyTimeSeconds));
      _dailySecondsLeft = _dailyTimeSeconds;
    }
    _revision.value++;
    _startEnemyTimer();
  }

  double _defaultZoom() {
    final cellPx = 340 / _maze.size;
    return (14 / cellPx).clamp(1.0, 3.0);
  }

  void _zoomIn() => setState(() => _zoom = (_zoom * 1.25).clamp(1.0, 4.0));

  void _zoomOut() => setState(() => _zoom = (_zoom / 1.25).clamp(1.0, 4.0));

  void _loadRewardedAd() {
    if (_rewardedAdLoading || _rewardedAd != null) return;
    _rewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAdLoading = false;
        },
      ),
    );
  }

  void _startEnemyTimer() {
    _enemyTimer?.cancel();
    _enemyTimer = Timer.periodic(
      Duration(milliseconds: _enemyIntervalMs),
      (_) {
        if (!mounted || _solving) return;
        if (_boosted) return;
        if (_advanceEnemies() && !_graceActive) _caught();
      },
    );
  }

  void _move(int dr, int dc) {
    if (_solving) return;
    if (!_maze.move(dr, dc)) return;
    setState(() {
      _revision.value++;
      _moves++;
      final pickup = _maze.takePickup(_maze.playerRow, _maze.playerCol);
      if (pickup.coin) {
        _coinsThisLevel++;
        _totalCoins++;
        _saveTotalCoins();
      }
      if (pickup.boost) {
        _boosted = true;
        _boostTimer?.cancel();
        _boostTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) setState(() => _boosted = false);
        });
      }
      _maze.explore(_maze.playerRow, _maze.playerCol);
    });
    _vibrate();
    if (_maze.isGoal()) {
      _levelComplete();
      return;
    }
    if (_playerOnEnemy() && !_graceActive) _caught();
  }

  Future<void> _vibrate() async {
    if (!_vibrationEnabled) return;
    try {
      await Vibration.vibrate(duration: 20);
    } catch (_) {}
  }

  bool _playerOnEnemy() {
    if (_maze.enemies
        .any((e) => e.row == _maze.playerRow && e.col == _maze.playerCol)) {
      return true;
    }
    final boss = _maze.boss;
    return boss != null &&
        boss.row == _maze.playerRow &&
        boss.col == _maze.playerCol;
  }

  bool _advanceEnemies() {
    final rng = Random();
    for (final e in _maze.enemies) {
      _maze.advanceEnemy(e, rng: rng);
    }
    final boss = _maze.boss;
    if (boss != null) _maze.advanceEnemy(boss, rng: rng);
    _revision.value++;
    return _playerOnEnemy();
  }

  void _buyShield() {
    if (_solving || _maze.hasShield) return;
    if (_totalCoins < _shieldCost) return;
    setState(() {
      _totalCoins -= _shieldCost;
      _maze.hasShield = true;
    });
    _saveTotalCoins();
    _vibrate();
  }

  void _buyFreeze() {
    if (_solving || _boosted || worldForLevel(_level) < 2) return;
    if (_totalCoins < _freezeCost) return;
    setState(() {
      _totalCoins -= _freezeCost;
      _boosted = true;
      _boostTimer?.cancel();
      _boostTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => _boosted = false);
      });
    });
    _saveTotalCoins();
    _vibrate();
  }

  void _buyRemoveFog() {
    if (_solving || !_maze.hasFog) return;
    if (_totalCoins < _fogCost) return;
    setState(() {
      _totalCoins -= _fogCost;
      _maze.fogRemoved = true;
      _maze.explore(_maze.playerRow, _maze.playerCol);
    });
    _saveTotalCoins();
    _vibrate();
  }

  void _buyRemoveKeys() {
    if (_solving || _maze.keys.isEmpty) return;
    if (_totalCoins < _keysCost) return;
    setState(() {
      _totalCoins -= _keysCost;
      _maze.keysRemoved = true;
      _maze.doors.clear();
      _maze.keys.clear();
      _maze.keysHeld = 0;
    });
    _saveTotalCoins();
    _vibrate();
  }

  void _buyRemoveBoss() {
    final boss = _maze.boss;
    if (_solving || boss == null || !boss.isBoss) return;
    if (_totalCoins < _bossCost) return;
    setState(() {
      _totalCoins -= _bossCost;
      boss.isBoss = false;
      boss.pace = 0.7;
      _maze.bossRemoved = true;
    });
    _saveTotalCoins();
    _vibrate();
  }

  Future<void> _caught() async {
    if (_maze.hasShield) {
      setState(() {
        _maze.hasShield = false;
        _maze.playerRow = 0;
        _maze.playerCol = 0;
        _maze.explore(0, 0);
        _graceUntil = DateTime.now().add(const Duration(seconds: 2));
      });
      _revision.value++;
      _vibrate();
      return;
    }
    _solving = true;
    _catches++;
    if (_rewardedAd == null) _loadRewardedAd();
    final scheme = Theme.of(context).colorScheme;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
    );
    if (retry != true) {
      _restartLevel();
      return;
    }
    await _showAdThenRetry();
  }

  Future<void> _showAdThenRetry() async {
    final ad = _rewardedAd;
    _rewardedAd = null;
    if (ad == null) {
      _restartLevel();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _loadRewardedAd();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) {});
    } catch (_) {}
    if (!mounted) return;
    _restartLevel();
  }

  void _restartLevel() {
    setState(() {
      _solving = false;
      _newMaze(seed: _dailyMode ? _dailySeed : null);
    });
    _focusNode.requestFocus();
  }

  void _toggleDaily() {
    if (_infinityMode) return;
    if (_dailyMode) {
      _exitDaily();
    } else {
      _enterDaily();
    }
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _enterDaily() {
    final seed = _dailySeed;
    setState(() {
      _savedLevel = _level;
      _dailyMode = true;
      _dailyLevel = 1 + seed % 25;
      _level = _dailyLevel;
    });
    _startDailyCountdown();
    _newMaze(seed: seed);
    _focusNode.requestFocus();
  }

  void _startDailyCountdown() {
    _dailyTimer?.cancel();
    if (!_dailyMode || _dailyDone) return;
    _dailyDeadline = DateTime.now().add(
      const Duration(seconds: _dailyTimeSeconds),
    );
    setState(() => _dailySecondsLeft = _dailyTimeSeconds);
    _dailyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _dailyDeadline.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        _dailyTimer?.cancel();
        _dailyTimeout();
        return;
      }
      setState(() => _dailySecondsLeft = left);
    });
  }

  Future<void> _dailyTimeout() async {
    _dailyTimer?.cancel();
    _solving = true;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: scheme.surface,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'TIME IS UP!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You ran out of time in the challenges.\nBonus coins were not earned.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _solving = false;
      _dailyMode = false;
      _level = _savedLevel.clamp(1, _maxLevel);
      _newMaze();
    });
  }

  void _exitDaily() {
    _dailyTimer?.cancel();
    setState(() {
      _dailyMode = false;
      _level =
          _infinityMode ? _savedLevel : _savedLevel.clamp(1, _maxLevel);
    });
    _newMaze();
    _focusNode.requestFocus();
  }

  int _parMoves() => _maze.solutionLength() * 2;

  Future<void> _levelComplete() async {
    _solving = true;
    final moves = _moves;
    final par = _parMoves();
    final noCatch = _catches == 0;
    final allCoins = _coinCount == 0 || _coinsThisLevel >= _coinCount;
    var stars = 1;
    if (noCatch && moves <= par) stars = 2;
    if (allCoins && noCatch && moves <= par) stars = 3;

    final prefs = await SharedPreferences.getInstance();
    final prevStars = _starsByLevel[_level] ?? 0;
    if (stars > prevStars) {
      _starsByLevel[_level] = stars;
      await prefs.setInt('level${_level}_stars', stars);
    }
    final prevMoves = _bestMovesByLevel[_level] ?? 0;
    if (prevMoves == 0 || moves < prevMoves) {
      _bestMovesByLevel[_level] = moves;
      await prefs.setInt('level${_level}_bestMoves', moves);
    }
    if (!_dailyMode && !_infinityMode && _level >= 25) {
      await prefs.setBool('cleared25', true);
    }

    var bonus = 0;
    if (_dailyMode && !_dailyDone) {
      _dailyDone = true;
      _dailyTimer?.cancel();
      bonus = 50;
      _totalCoins += bonus;
      await prefs.setBool('dailyDone_$_todayKey', true);
      await prefs.setInt('totalCoins', _totalCoins);
    }

    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final bestMoves = _bestMovesByLevel[_level] ?? moves;
    final title = _dailyMode ? 'CHALLENGES CLEAR!' : 'LEVEL CLEAR!';
    final replay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: scheme.surface,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StarRow(count: stars, color: scheme.onSurface, size: 34),
            const SizedBox(height: 12),
            Text(
              'Moves $moves  ·  Best $bestMoves',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Coins $_coinsThisLevel / $_coinCount',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface),
            ),
            if (!noCatch) ...[
              const SizedBox(height: 4),
              Text(
                'Got caught this run — no bonus stars',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface),
              ),
            ],
            if (_dailyMode && bonus > 0) ...[
              const SizedBox(height: 4),
              Text(
                '+$bonus daily coins!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFFFB300),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
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
              _dailyMode ? 'Done' : 'Next Level',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _solving = false;
      if (replay == true) {
        _newMaze(seed: _dailyMode ? _dailySeed : null);
      } else if (_dailyMode) {
        _dailyMode = false;
        _level = _savedLevel.clamp(1, _maxLevel);
        _newMaze();
      } else if (_infinityMode) {
        _level++;
        _saveInfinity();
        _newMaze();
      } else if (_level >= 25) {
        _maxLevel = 25;
        _infinityMode = true;
        _level = 26;
        _saveProgress();
        _saveInfinity();
        _newMaze();
      } else {
        if (_level >= _maxLevel) _maxLevel++;
        _level++;
        _saveProgress();
        _newMaze();
      }
    });
    _focusNode.requestFocus();
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
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        if (widget.onExit != null)
                          IconButton(
                            onPressed: widget.onExit,
                            icon: Icon(Icons.home_outlined,
                                color: scheme.onSurface),
                            tooltip: 'Home',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        IconButton(
                          onPressed: _dailyMode
                              ? null
                              : _infinityMode
                                  ? (_level > 26
                                      ? () => _goToLevel(_level - 1)
                                      : null)
                                  : (_level > 1
                                      ? () => _goToLevel(_level - 1)
                                      : null),
                          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                          disabledColor: scheme.onSurface.withValues(alpha: 0.35),
                          tooltip: 'Previous level',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(
                          _infinityMode
                              ? '∞ $_level'
                              : _dailyMode
                                  ? 'CHALLENGES $_level'
                                  : 'LEVEL $_level',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        if (!_dailyMode && !_infinityMode && _level < _maxLevel)
                          IconButton(
                            onPressed: () => _goToLevel(_level + 1),
                            icon: Icon(Icons.arrow_forward,
                                color: scheme.onSurface),
                            tooltip: 'Next level',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          ],
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
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() =>
                                _newMaze(seed: _dailyMode ? _dailySeed : null));
                            _focusNode.requestFocus();
                          },
                          icon: Icon(Icons.refresh, color: scheme.onSurface),
                          tooltip: 'New maze',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: scheme.onSurface, height: 12, thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_dailyMode) ...[
                      IconButton(
                        onPressed: _toggleDaily,
                        icon: Icon(Icons.check_circle_outline,
                            color: const Color(0xFF26A69A)),
                        tooltip: 'Exit challenges',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        _dailyDone ? 'Done' : 'Challenge',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (_dailyMode && !_dailyDone) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined,
                          color: scheme.onSurface, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        _formatCountdown(_dailySecondsLeft),
                        style: TextStyle(
                          color: _dailySecondsLeft <= 30
                              ? const Color(0xFFE53935)
                              : scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    _StarRow(
                      count: _starsByLevel[_level] ?? 0,
                      color: scheme.onSurface,
                      size: 18,
                    ),
                    const Spacer(),
                    const Icon(Icons.monetization_on_outlined,
                        color: Color(0xFFFFB300), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '$_totalCoins',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_maze.hasFog) ...[
                          const SizedBox(width: 6),
                          _BuyChip(
                            icon: Icons.visibility_off,
                            label: 'FOG',
                            cost: _fogCost,
                            enabled: _totalCoins >= _fogCost,
                            onTap: _buyRemoveFog,
                          ),
                        ],
                        if (_maze.boss != null && _maze.boss!.isBoss) ...[
                          const SizedBox(width: 6),
                          _BuyChip(
                            icon: Icons.warning_amber_rounded,
                            label: 'BOSS',
                            cost: _bossCost,
                            enabled: _totalCoins >= _bossCost,
                            onTap: _buyRemoveBoss,
                          ),
                        ],
                        if (_maze.keys.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _BuyChip(
                            icon: Icons.key,
                            label: '${_maze.keysHeld}',
                            cost: _keysCost,
                            enabled: _totalCoins >= _keysCost,
                            onTap: _buyRemoveKeys,
                          ),
                        ],
                        if (_maze.hasShield) ...[
                          const SizedBox(width: 6),
                          _IndicatorChip(
                            icon: Icons.shield,
                            label: 'SAVER',
                            color: const Color(0xFF26A69A),
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          _BuyChip(
                            icon: Icons.shield_outlined,
                            cost: _shieldCost,
                            enabled: _totalCoins >= _shieldCost,
                            onTap: _buyShield,
                          ),
                        ],
                        if (worldForLevel(_level) >= 2) ...[
                          if (_boosted) ...[
                            const SizedBox(width: 6),
                            _IndicatorChip(
                              icon: Icons.ac_unit,
                              label: 'FROZEN',
                              color: const Color(0xFF26A69A),
                            ),
                          ] else ...[
                            const SizedBox(width: 6),
                            _BuyChip(
                              icon: Icons.ac_unit,
                              cost: _freezeCost,
                              enabled: _totalCoins >= _freezeCost,
                              onTap: _buyFreeze,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: ClipRect(
                            child: CustomPaint(
                              painter: MazePainter(
                                maze: _maze,
                                fg: scheme.onSurface,
                                bg: scheme.surface,
                                zoom: _zoom,
                                repaint: _revision,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ZoomButton(
                            icon: Icons.add,
                            onTap: _zoomIn,
                          ),
                          _ZoomButton(
                            icon: Icons.remove,
                            onTap: _zoomOut,
                          ),
                        ],
                      ),
                    ],
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
                  moves: _moves,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameLogo extends StatelessWidget {
  const _GameLogo({this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/icon/logo.png',
        width: size,
        height: size,
      );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: scheme.onSurface),
      tooltip: icon == Icons.add ? 'Zoom in' : 'Zoom out',
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
    this.moves,
  });

  static const double padW = 80;
  static const double padH = 66;
  static const double gap = 10;

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final int? moves;

  Widget _button(ColorScheme scheme, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: padW,
        height: padH,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.onSurface, width: 2),
        ),
        child: Icon(icon, color: scheme.onSurface, size: 30),
      ),
    );
  }

  Widget _moves(ColorScheme scheme) {
    return Container(
      width: padW,
      height: padH,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.onSurface, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'MOVES',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          Text(
            '$moves',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
            moves == null ? SizedBox(width: padW, height: padH) : _moves(scheme),
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

class _StarRow extends StatelessWidget {
  const _StarRow({required this.count, required this.color, this.size = 22});

  final int count;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: filled
              ? const Color(0xFFFFB300)
              : color.withValues(alpha: 0.3),
          size: size,
        );
      }),
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyChip extends StatelessWidget {
  const _BuyChip({
    required this.icon,
    required this.cost,
    required this.enabled,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String? label;
  final int cost;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dim = enabled ? 1.0 : 0.35;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: scheme.onSurface.withValues(alpha: dim), size: 14),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(
                label!,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: dim),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(width: 3),
            const Icon(Icons.monetization_on_outlined,
                color: Color(0xFFFFB300), size: 12),
            const SizedBox(width: 1),
            Text(
              '$cost',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: dim),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
