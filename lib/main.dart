import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SnakeApp());
}

class SnakeApp extends StatelessWidget {
  const SnakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pink Snake',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4FA3),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: const SnakeHome(),
    );
  }
}

class SnakeHome extends StatefulWidget {
  const SnakeHome({super.key});

  @override
  State<SnakeHome> createState() => _SnakeHomeState();
}

class _SnakeHomeState extends State<SnakeHome> {
  static const int defaultGridSize = 20;
  static const int minGridSize = 12;
  static const int maxGridSize = 40;
  static const int gridStep = 2;

  static const int defaultStepMs = 240;
  static const int minStepMs = 80;
  static const int maxStepMs = 400;
  static const int stepMsStep = 20;
  static const int scoreStep = 10;
  static const String _bestScoreKey = 'best_score';

  final Random _rng = Random();
  SharedPreferences? _prefs;
  final List<Point<int>> _snake = [];
  Point<int> _direction = const Point(1, 0);
  Point<int> _nextDirection = const Point(1, 0);
  Point<int> _food = const Point(5, 5);
  int _gridSize = defaultGridSize;
  Duration _stepDuration = const Duration(milliseconds: defaultStepMs);
  int _score = 0;
  int _best = 0;

  Timer? _timer;
  bool _running = false;
  bool _paused = false;
  bool _gameOver = false;

  Offset? _panStart;
  bool _swipeConsumed = false;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _resetGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    _snake
      ..clear()
      ..addAll([
        Point(_gridSize ~/ 2, _gridSize ~/ 2),
        Point(_gridSize ~/ 2 - 1, _gridSize ~/ 2),
      ]);
    _direction = const Point(1, 0);
    _nextDirection = const Point(1, 0);
    _score = 0;
    _gameOver = false;
    _spawnFood();
    setState(() {});
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    final storedBest = prefs.getInt(_bestScoreKey) ?? 0;
    if (!mounted) {
      return;
    }
    final nextBest = max(_best, storedBest);
    setState(() {
      _prefs = prefs;
      _best = nextBest;
    });
    if (nextBest != storedBest) {
      unawaited(prefs.setInt(_bestScoreKey, nextBest));
    }
  }

  void _persistBestScore() {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    unawaited(prefs.setInt(_bestScoreKey, _best));
  }

  void _spawnFood() {
    while (true) {
      final candidate = Point(_rng.nextInt(_gridSize), _rng.nextInt(_gridSize));
      final hit = _snake.any((segment) => segment == candidate);
      if (!hit) {
        _food = candidate;
        break;
      }
    }
  }

  void _startGame() {
    if (_running) {
      return;
    }
    _running = true;
    _paused = false;
    _gameOver = false;
    _timer?.cancel();
    _timer = Timer.periodic(_stepDuration, (_) => _tick());
    setState(() {});
  }

  void _togglePause() {
    if (!_running) {
      return;
    }
    _paused = !_paused;
    if (_paused) {
      _timer?.cancel();
    } else {
      _timer?.cancel();
      _timer = Timer.periodic(_stepDuration, (_) => _tick());
    }
    setState(() {});
  }

  void _stopGame() {
    _timer?.cancel();
    _running = false;
    _paused = false;
    _gameOver = true;
    setState(() {});
  }

  void _tick() {
    if (!_running || _paused) {
      return;
    }

    _direction = _nextDirection;
    final head = _snake.first;
    final next = Point(head.x + _direction.x, head.y + _direction.y);

    if (next.x < 0 || next.x >= _gridSize || next.y < 0 || next.y >= _gridSize) {
      _stopGame();
      return;
    }

    if (_snake.any((segment) => segment == next)) {
      _stopGame();
      return;
    }

    _snake.insert(0, next);

    if (next == _food) {
      _score += scoreStep;
      if (_score > _best) {
        _best = _score;
        _persistBestScore();
      }
      _spawnFood();
    } else {
      _snake.removeLast();
    }

    setState(() {});
  }

  void _setDirection(Point<int> direction) {
    if (_direction.x == -direction.x && _direction.y == -direction.y) {
      return;
    }
    _nextDirection = direction;
  }

  void _handleTap() {
    if (_gameOver) {
      _resetGame();
      _startGame();
      return;
    }

    if (!_running) {
      _startGame();
      return;
    }

    _togglePause();
  }

  void _handlePanStart(DragStartDetails details) {
    _panStart = details.localPosition;
    _swipeConsumed = false;

    if (!_running && !_gameOver) {
      _startGame();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_panStart == null || _swipeConsumed) {
      return;
    }
    final delta = details.localPosition - _panStart!;
    final dx = delta.dx;
    final dy = delta.dy;
    final absX = dx.abs();
    final absY = dy.abs();
    const threshold = 12.0;

    if (absX < threshold && absY < threshold) {
      return;
    }

    if (absX > absY) {
      _setDirection(dx > 0 ? const Point(1, 0) : const Point(-1, 0));
    } else {
      _setDirection(dy > 0 ? const Point(0, 1) : const Point(0, -1));
    }

    _swipeConsumed = true;
  }

  void _handlePanEnd(DragEndDetails details) {
    _panStart = null;
    _swipeConsumed = false;
  }

  void _updateGridSize(double value) {
    final newSize = value.round();
    if (newSize == _gridSize) {
      return;
    }

    _timer?.cancel();
    _running = false;
    _paused = false;
    _gameOver = false;
    _gridSize = newSize;
    _resetGame();
  }

  void _updateSpeed(double value) {
    final newMs = value.round();
    if (_stepDuration.inMilliseconds == newMs) {
      return;
    }

    _stepDuration = Duration(milliseconds: newMs);
    if (_running && !_paused) {
      _timer?.cancel();
      _timer = Timer.periodic(_stepDuration, (_) => _tick());
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PinkThemeColors();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'Courier New',
            fontFamilyFallback: ['Courier', 'monospace'],
            letterSpacing: 1.4,
            height: 1.1,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ScanlinePainter(color: colors.scanline),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Header(
                      score: _score,
                      best: _best,
                      colors: colors,
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boardSize = min(constraints.maxWidth, constraints.maxHeight);

                          return Center(
                            child: SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _handleTap,
                                onPanStart: _handlePanStart,
                                onPanUpdate: _handlePanUpdate,
                                onPanEnd: _handlePanEnd,
                                child: Stack(
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.boardTop,
                                        borderRadius: BorderRadius.zero,
                                        border: Border.all(color: colors.border, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.shadow,
                                            blurRadius: 0,
                                            offset: const Offset(6, 6),
                                          ),
                                        ],
                                      ),
                                      child: SizedBox.expand(
                                        child: CustomPaint(
                                          painter: _GamePainter(
                                            gridSize: _gridSize,
                                            snake: List.unmodifiable(_snake),
                                            food: _food,
                                            colors: colors,
                                            direction: _direction,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!_running || _paused || _gameOver)
                                      _Overlay(
                                        paused: _paused,
                                        gameOver: _gameOver,
                                        colors: colors,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SliderCard(
                      label: 'GRID',
                      value: _gridSize.toDouble(),
                      min: minGridSize.toDouble(),
                      max: maxGridSize.toDouble(),
                      divisions: ((maxGridSize - minGridSize) / gridStep).round(),
                      onChanged: _updateGridSize,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    _SliderCard(
                      label: 'SPEED',
                      value: _stepDuration.inMilliseconds.toDouble(),
                      min: minStepMs.toDouble(),
                      max: maxStepMs.toDouble(),
                      divisions: ((maxStepMs - minStepMs) / stepMsStep).round(),
                      onChanged: _updateSpeed,
                      colors: colors,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Swipe to steer. Tap to start or pause.',
                      style: TextStyle(color: colors.hint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.score,
    required this.best,
    required this.colors,
  });

  final int score;
  final int best;
  final _PinkThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Snake',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 28,
                color: colors.title,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: colors.shadow,
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
        ),
        Row(
          children: [
            _StatCard(label: 'Score', value: score, colors: colors),
            const SizedBox(width: 12),
            _StatCard(label: 'Best', value: best, colors: colors),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final int value;
  final _PinkThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: colors.borderLight, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: colors.subtitle,
              shadows: [
                Shadow(
                  color: colors.shadow,
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
              shadows: [
                Shadow(
                  color: colors.shadow,
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.paused,
    required this.gameOver,
    required this.colors,
  });

  final bool paused;
  final bool gameOver;
  final _PinkThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final title = gameOver
        ? 'Game over'
        : paused
            ? 'Paused'
            : 'Ready?';
    final subtitle = gameOver
        ? 'Tap to play again'
        : paused
            ? 'Tap to resume'
            : 'Tap to start';

    return Container(
      decoration: BoxDecoration(
        color: colors.overlay,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: colors.border, width: 3),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: colors.borderLight, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 0,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.title,
                  letterSpacing: 1.6,
                  shadows: [
                    Shadow(
                      color: colors.shadow,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.text,
                  letterSpacing: 1.4,
                  shadows: [
                    Shadow(
                      color: colors.shadow,
                      offset: const Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.colors,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final _PinkThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: colors.borderLight, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: colors.subtitle,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: colors.shadow,
                  offset: const Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colors.subtitle,
                inactiveTrackColor: colors.borderLight,
                trackHeight: 6,
                thumbColor: colors.title,
                activeTickMarkColor: colors.border,
                inactiveTickMarkColor: colors.borderLight,
                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
                overlayColor: Colors.transparent,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.gridSize,
    required this.snake,
    required this.food,
    required this.colors,
    required this.direction,
  });

  final int gridSize;
  final List<Point<int>> snake;
  final Point<int> food;
  final _PinkThemeColors colors;
  final Point<int> direction;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;
    final gridPaint = Paint()
      ..color = colors.grid
      ..strokeWidth = 1
      ..isAntiAlias = false;

    for (var i = 1; i < gridSize; i += 1) {
      final pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    final segmentInset = max(1.0, cellSize * 0.12);
    final foodInset = max(1.0, cellSize * 0.22);
    final snakePaint = Paint()
      ..color = colors.snake
      ..isAntiAlias = false;
    final headPaint = Paint()
      ..color = colors.head
      ..isAntiAlias = false;
    final headHighlightPaint = Paint()
      ..color = colors.borderLight
      ..isAntiAlias = false;
    final headOutlinePaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;
    final foodPaint = Paint()
      ..color = colors.food
      ..isAntiAlias = false;
    final foodOutline = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;

    final foodRect = Rect.fromLTWH(
      food.x * cellSize + foodInset,
      food.y * cellSize + foodInset,
      cellSize - foodInset * 2,
      cellSize - foodInset * 2,
    );
    canvas.drawRect(foodRect, foodPaint);
    canvas.drawRect(foodRect, foodOutline);

    for (var i = 0; i < snake.length; i += 1) {
      final segment = snake[i];
      final rect = Rect.fromLTWH(
        segment.x * cellSize + segmentInset,
        segment.y * cellSize + segmentInset,
        cellSize - segmentInset * 2,
        cellSize - segmentInset * 2,
      );
      final paint = i == 0 ? headPaint : snakePaint;
      canvas.drawRect(rect, paint);

      if (i == 0) {
        canvas.drawRect(rect, headOutlinePaint);
        final highlightInset = max(1.0, cellSize * 0.28);
        final highlightRect = rect.deflate(highlightInset);
        if (highlightRect.width > 0 && highlightRect.height > 0) {
          canvas.drawRect(highlightRect, headHighlightPaint);
        }

        final eyeSize = max(1.0, cellSize * 0.18);
        final pupilSize = max(1.0, cellSize * 0.08);
        final eyePaint = Paint()
          ..color = colors.text
          ..isAntiAlias = false;
        final pupilPaint = Paint()
          ..color = Colors.black
          ..isAntiAlias = false;

        if (direction.x != 0) {
          final eyeX = rect.left + rect.width * 0.62;
          final topEye = Rect.fromLTWH(
            eyeX,
            rect.top + rect.height * 0.18,
            eyeSize,
            eyeSize,
          );
          final bottomEye = Rect.fromLTWH(
            eyeX,
            rect.bottom - rect.height * 0.18 - eyeSize,
            eyeSize,
            eyeSize,
          );
          canvas.drawRect(topEye, eyePaint);
          canvas.drawRect(bottomEye, eyePaint);
          canvas.drawRect(
            Rect.fromLTWH(
              topEye.left + (eyeSize - pupilSize) / 2,
              topEye.top + (eyeSize - pupilSize) / 2,
              pupilSize,
              pupilSize,
            ),
            pupilPaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(
              bottomEye.left + (eyeSize - pupilSize) / 2,
              bottomEye.top + (eyeSize - pupilSize) / 2,
              pupilSize,
              pupilSize,
            ),
            pupilPaint,
          );
        } else {
          final eyeY = rect.top + rect.height * 0.38;
          final leftEye = Rect.fromLTWH(
            rect.left + rect.width * 0.18,
            eyeY,
            eyeSize,
            eyeSize,
          );
          final rightEye = Rect.fromLTWH(
            rect.right - rect.width * 0.18 - eyeSize,
            eyeY,
            eyeSize,
            eyeSize,
          );
          canvas.drawRect(leftEye, eyePaint);
          canvas.drawRect(rightEye, eyePaint);
          canvas.drawRect(
            Rect.fromLTWH(
              leftEye.left + (eyeSize - pupilSize) / 2,
              leftEye.top + (eyeSize - pupilSize) / 2,
              pupilSize,
              pupilSize,
            ),
            pupilPaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(
              rightEye.left + (eyeSize - pupilSize) / 2,
              rightEye.top + (eyeSize - pupilSize) / 2,
              pupilSize,
              pupilSize,
            ),
            pupilPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) {
    return oldDelegate.snake != snake ||
        oldDelegate.food != food ||
        oldDelegate.direction != direction;
  }
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({required this.color, this.spacing = 6});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.spacing != spacing;
  }
}

class _PinkThemeColors {
  final Color background = const Color(0xFF1A0A12);
  final Color boardTop = const Color(0xFF2A0F1E);
  final Color boardBottom = const Color(0xFF2A0F1E);
  final Color border = const Color(0xFFFF4FA3);
  final Color borderLight = const Color(0xFFFF9FCD);
  final Color shadow = const Color(0x99000000);
  final Color card = const Color(0xFF2A0F1E);
  final Color title = const Color(0xFFFFB3DD);
  final Color subtitle = const Color(0xFFFF6BB6);
  final Color text = const Color(0xFFFFE6F3);
  final Color grid = const Color(0x33FF6BB6);
  final Color snake = const Color(0xFFFFC7E6);
  final Color head = const Color(0xFFFFF2FA);
  final Color food = const Color(0xFFFF4FA3);
  final Color foodGlow = const Color(0x66FF4FA3);
  final Color hint = const Color(0xFFFF8FCB);
  final Color overlay = const Color(0xCC1A0A12);
  final Color scanline = const Color(0x1AFFFFFF);
}
