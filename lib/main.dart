import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF45A2)),
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

  final Random _rng = Random();
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
        child: Padding(
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
                                  gradient: LinearGradient(
                                    colors: [colors.boardTop, colors.boardBottom],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: colors.border, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.shadow,
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
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
                fontSize: 32,
                color: colors.title,
                letterSpacing: 1.2,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderLight),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 8),
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
              letterSpacing: 1.1,
              color: colors.subtitle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
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
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.borderLight),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 20,
                offset: const Offset(0, 10),
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
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.text,
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderLight),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: colors.subtitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colors.subtitle,
                inactiveTrackColor: colors.borderLight,
                thumbColor: Colors.white,
                overlayColor: colors.subtitle.withOpacity(0.12),
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
  });

  final int gridSize;
  final List<Point<int>> snake;
  final Point<int> food;
  final _PinkThemeColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;
    final gridPaint = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;

    for (var i = 1; i < gridSize; i += 1) {
      final pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    final foodPaint = Paint()..color = colors.food;
    final foodGlow = Paint()
      ..color = colors.foodGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final foodCenter = Offset(
      food.x * cellSize + cellSize / 2,
      food.y * cellSize + cellSize / 2,
    );
    canvas.drawCircle(foodCenter, cellSize * 0.28, foodGlow);
    canvas.drawCircle(foodCenter, cellSize * 0.24, foodPaint);

    for (var i = 0; i < snake.length; i += 1) {
      final segment = snake[i];
      final rect = Rect.fromLTWH(
        segment.x * cellSize + 2,
        segment.y * cellSize + 2,
        cellSize - 4,
        cellSize - 4,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.22));
      final paint = Paint()..color = i == 0 ? colors.head : colors.snake;
      canvas.drawRRect(rrect, paint);

      if (i == 0) {
        final eyeOffset = cellSize * 0.16;
        final eyeRadius = cellSize * 0.06;
        final pupilRadius = cellSize * 0.03;
        final eyePaint = Paint()..color = colors.text;
        final pupilPaint = Paint()..color = Colors.black;
        final eyeY = rect.top + rect.height * 0.35;

        if (_direction.x != 0) {
          final eyeX = rect.left + rect.width * 0.65;
          final topEye = Offset(eyeX, rect.top + eyeOffset);
          final bottomEye = Offset(eyeX, rect.bottom - eyeOffset);
          canvas.drawCircle(topEye, eyeRadius, eyePaint);
          canvas.drawCircle(bottomEye, eyeRadius, eyePaint);
          canvas.drawCircle(topEye, pupilRadius, pupilPaint);
          canvas.drawCircle(bottomEye, pupilRadius, pupilPaint);
        } else {
          final leftEye = Offset(rect.left + eyeOffset, eyeY);
          final rightEye = Offset(rect.right - eyeOffset, eyeY);
          canvas.drawCircle(leftEye, eyeRadius, eyePaint);
          canvas.drawCircle(rightEye, eyeRadius, eyePaint);
          canvas.drawCircle(leftEye, pupilRadius, pupilPaint);
          canvas.drawCircle(rightEye, pupilRadius, pupilPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) {
    return oldDelegate.snake != snake || oldDelegate.food != food;
  }
}

class _PinkThemeColors {
  final Color background = const Color(0xFFFFE3F2);
  final Color boardTop = const Color(0xFFFFB6D8);
  final Color boardBottom = const Color(0xFFFF7DBB);
  final Color border = const Color(0xFFFF9CCC);
  final Color borderLight = const Color(0xFFFFC7E2);
  final Color shadow = const Color(0x332B0518);
  final Color card = const Color(0xFFFFF6FB);
  final Color title = const Color(0xFFC90F70);
  final Color subtitle = const Color(0xFFF3178A);
  final Color text = const Color(0xFF2B0518);
  final Color grid = const Color(0x33FFFFFF);
  final Color snake = const Color(0xFFFFF1F8);
  final Color head = Colors.white;
  final Color food = const Color(0xFFF3178A);
  final Color foodGlow = const Color(0xFFFF9CCC);
  final Color hint = const Color(0xFF8F0A50);
  final Color overlay = const Color(0xD9FFE6F4);
}
