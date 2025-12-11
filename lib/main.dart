// main.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'secondstage.dart';

void main() {
  runApp(const PenaltyGameApp());
}

class PenaltyGameApp extends StatelessWidget {
  const PenaltyGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retro Penalty Game',
      debugShowCheckedModeBanner: false,
      home: const PenaltyStagePage(),
    );
  }
}

class PenaltyStagePage extends StatefulWidget {
  const PenaltyStagePage({super.key});

  @override
  State<PenaltyStagePage> createState() => _PenaltyStagePageState();
}

class _PenaltyStagePageState extends State<PenaltyStagePage>
    with TickerProviderStateMixin {
  late AnimationController _ballController;
  Animation<Offset>? _ballAnimation;

  late AnimationController _keeperController;
  double _keeperT = 0.5;

  late AnimationController _playerRunController;
  Animation<Offset>? _playerRunAnimation;

  late AnimationController _playerKickController;
  double _kickT = 0.0;

  final Offset _initialBallPos = const Offset(0.5, 0.77);
  final Offset _initialPlayerPos = const Offset(0.47, 0.88);

  Offset _ballPos = const Offset(0.5, 0.77);
  Offset _playerPos = const Offset(0.47, 0.88);

  Offset? _pendingBallTargetFrac;
  Offset? _lastShotStart;
  Offset? _lastShotEnd;

  Offset? _dragStart;
  Offset? _dragLast;

  bool _isAnimating = false;
  bool _keeperHasBall = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();

    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _ballController.addListener(() {
      if (_ballAnimation != null) {
        setState(() {
          _ballPos = _ballAnimation!.value;
        });
      }
    });

    _ballController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _evaluateShotResult();
      }
    });

    _keeperController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _keeperController.addListener(() {
      setState(() {
        _keeperT = _keeperController.value;
      });
    });

    _playerRunController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _playerRunController.addListener(() {
      if (_playerRunAnimation != null) {
        setState(() {
          _playerPos = _playerRunAnimation!.value;
        });
      }
    });

    _playerRunController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startKickAndBall();
      }
    });

    _playerKickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _playerKickController.addListener(() {
      setState(() {
        _kickT = _playerKickController.value;
      });
    });

    _playerKickController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _playerKickController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _ballController.dispose();
    _keeperController.dispose();
    _playerRunController.dispose();
    _playerKickController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details, Size size) {
    if (_isAnimating) return;

    setState(() {
      _statusText = '';
    });

    final local = details.localPosition;
    _dragStart = local;
    _dragLast = local;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    _dragLast = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details, Size size) {
    if (_isAnimating) return;
    if (_dragStart == null || _dragLast == null) return;

    final direction = _dragLast! - _dragStart!;
    if (direction.distance < 20) {
      _dragStart = null;
      _dragLast = null;
      return;
    }

    final ballPx = Offset(
      _ballPos.dx * size.width,
      _ballPos.dy * size.height,
    );

    final dirNorm = direction / direction.distance;
    final power = direction.distance.clamp(150.0, 600.0);
    final targetPx = ballPx + dirNorm * power * 1.4;

    final targetFrac = Offset(
      (targetPx.dx / size.width).clamp(0.0, 1.0),
      (targetPx.dy / size.height).clamp(0.0, 1.0),
    );

    _pendingBallTargetFrac = targetFrac;
    _lastShotStart = _ballPos;
    _lastShotEnd = targetFrac;

    final runTarget = Offset(
      (_ballPos.dx - 0.03).clamp(0.0, 1.0),
      (_ballPos.dy + 0.02).clamp(0.0, 1.0),
    );

    _playerRunAnimation = Tween<Offset>(
      begin: _playerPos,
      end: runTarget,
    ).animate(
      CurvedAnimation(
        parent: _playerRunController,
        curve: Curves.easeOut,
      ),
    );

    _isAnimating = true;
    _playerRunController.forward(from: 0);

    _dragStart = null;
    _dragLast = null;
  }

  void _startKickAndBall() {
    if (_pendingBallTargetFrac == null) {
      _isAnimating = false;
      return;
    }

    _ballAnimation = Tween<Offset>(
      begin: _ballPos,
      end: _pendingBallTargetFrac!,
    ).animate(
      CurvedAnimation(
        parent: _ballController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _ballController.forward(from: 0);
    _playerKickController.forward(from: 0);
  }

  void _evaluateShotResult() {
    if (_lastShotStart == null || _lastShotEnd == null) {
      setState(() {
        _statusText = 'MISS!';
      });
      _scheduleReset();
      return;
    }

    final p0 = _lastShotStart!;
    final p1 = _lastShotEnd!;

    const goalWidthFrac = 0.6;
    const goalHeightFrac = 0.15;
    const goalLeftFrac = (1.0 - goalWidthFrac) / 2.0;
    const goalTopFrac = 0.18; // slightly below stands
    const goalRightFrac = goalLeftFrac + goalWidthFrac;
    const goalBottomFrac = goalTopFrac + goalHeightFrac;

    const keeperWidthFrac = goalWidthFrac * 0.23;
    const keeperHeightFrac = goalHeightFrac * 0.8;
    const minCenterX = goalLeftFrac + keeperWidthFrac / 2;
    const maxCenterX = goalRightFrac - keeperWidthFrac / 2;
    final keeperCenterX = minCenterX + (maxCenterX - minCenterX) * _keeperT;
    final keeperLeft = keeperCenterX - keeperWidthFrac / 2;
    final keeperRight = keeperCenterX + keeperWidthFrac / 2;
    final keeperTop = goalTopFrac + goalHeightFrac * 0.18;
    final keeperBottom = keeperTop + keeperHeightFrac;

    const ballR = 0.018;
    final kL = keeperLeft - ballR;
    final kR = keeperRight + ballR;
    final kT = keeperTop - ballR;
    final kB = keeperBottom + ballR;

    final gL = goalLeftFrac + ballR * 0.3;
    final gR = goalRightFrac - ballR * 0.3;
    final gT = goalTopFrac - ballR * 0.4;
    final gB = goalBottomFrac + ballR * 0.4;

    const steps = 40;
    bool hitKeeper = false;
    bool hitGoal = false;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = p0.dx + (p1.dx - p0.dx) * t;
      final y = p0.dy + (p1.dy - p0.dy) * t;

      if (x >= kL && x <= kR && y >= kT && y <= kB) {
        hitKeeper = true;
        break;
      }

      if (x >= gL && x <= gR && y >= gT && y <= gB) {
        hitGoal = true;
      }
    }

    if (hitKeeper) {
      final chestY = keeperTop + keeperHeightFrac * 0.45;
      final savedPos = Offset(keeperCenterX, chestY);

      setState(() {
        _statusText = 'SAVED!';
        _ballPos = savedPos;
        _keeperHasBall = true;
      });

      _keeperController.stop();

      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          _ballPos = _initialBallPos;
          _playerPos = _initialPlayerPos;
          _kickT = 0.0;
          _statusText = '';
          _keeperHasBall = false;
        });
        _keeperController.repeat(reverse: true);
        _isAnimating = false;
      });
      return;
    }

    if (hitGoal) {
      setState(() {
        _statusText = 'GOAL!';
      });

      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SecondStagePage(),
          ),
        );
        // reset this stage in background
        setState(() {
          _ballPos = _initialBallPos;
          _playerPos = _initialPlayerPos;
          _kickT = 0.0;
          _statusText = '';
          _keeperHasBall = false;
          _isAnimating = false;
        });
      });
      return;
    }

    setState(() {
      _statusText = 'MISS!';
    });
    _scheduleReset();
  }

  void _scheduleReset() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _ballPos = _initialBallPos;
        _playerPos = _initialPlayerPos;
        _kickT = 0.0;
        _statusText = '';
        _keeperHasBall = false;
      });
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);

        return Scaffold(
          body: GestureDetector(
            onPanStart: (d) => _onPanStart(d, size),
            onPanUpdate: _onPanUpdate,
            onPanEnd: (d) => _onPanEnd(d, size),
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: PenaltyFieldPainter(
                    ballPos: _ballPos,
                    keeperT: _keeperT,
                    kickT: _kickT,
                    playerPos: _playerPos,
                    keeperHasBall: _keeperHasBall,
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _statusText == 'GOAL!'
                            ? Colors.yellow
                            : Colors.white,
                        shadows: const [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PenaltyFieldPainter extends CustomPainter {
  final Offset ballPos;
  final double keeperT;
  final double kickT;
  final Offset playerPos;
  final bool keeperHasBall;

  PenaltyFieldPainter({
    required this.ballPos,
    required this.keeperT,
    required this.kickT,
    required this.playerPos,
    required this.keeperHasBall,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Sky
    paint.color = const Color(0xFF1D4F91);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.18),
      paint,
    );

    // Stands with “crowd”
    final standsTop = size.height * 0.05;
    final standsHeight = size.height * 0.13;
    paint.color = const Color(0xFF3B3B6D);
    canvas.drawRect(
      Rect.fromLTWH(0, standsTop, size.width, standsHeight),
      paint,
    );

    final crowdPaint = Paint();
    final crowdCellW = size.width / 20;
    final crowdCellH = standsHeight / 4;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 20; c++) {
        final x = c * crowdCellW;
        final y = standsTop + r * crowdCellH;
        crowdPaint.color = [
          const Color(0xFFEAD7A4),
          const Color(0xFFB0E0F8),
          const Color(0xFF5FC86F),
          const Color(0xFFF3B0B5),
        ][(r + c) % 4];
        canvas.drawRect(
          Rect.fromLTWH(x + 1, y + 1, crowdCellW - 2, crowdCellH - 2),
          crowdPaint,
        );
      }
    }

    // Barrier / ads
    paint.color = const Color(0xFFD71F26);
    final adsHeight = size.height * 0.06;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.18, size.width, adsHeight),
      paint,
    );

    // Pitch
    paint.color = const Color(0xFF137F2B);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.24, size.width, size.height * 0.76),
      paint,
    );

    // Pitch pattern (simple checker)
    final patternPaint = Paint()..color = const Color(0xFF0E6A21);
    final cellW = size.width / 16;
    final cellH = size.height * 0.02;
    for (int r = 0; r < 30; r++) {
      for (int c = 0; c < 16; c++) {
        if ((r + c) % 2 == 0) continue;
        final x = c * cellW;
        final y = size.height * 0.24 + r * cellH;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellW, cellH),
          patternPaint,
        );
      }
    }

    // Goal
    final goalWidth = size.width * 0.6;
    final goalHeight = size.height * 0.12;
    final goalLeft = (size.width - goalWidth) / 2;
    final goalTop = size.height * 0.18;
    final goalRect = Rect.fromLTWH(goalLeft, goalTop, goalWidth, goalHeight);

    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(goalRect, paint);

    // Net
    paint
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1;
    const netRows = 5;
    const netCols = 8;
    for (int i = 1; i < netRows; i++) {
      final y = goalTop + goalHeight * (i / netRows);
      canvas.drawLine(
        Offset(goalLeft, y),
        Offset(goalLeft + goalWidth, y),
        paint,
      );
    }
    for (int j = 1; j < netCols; j++) {
      final x = goalLeft + goalWidth * (j / netCols);
      canvas.drawLine(
        Offset(x, goalTop),
        Offset(x, goalTop + goalHeight),
        paint,
      );
    }

    // Penalty box
    final boxWidth = size.width * 0.8;
    final boxHeight = size.height * 0.28;
    final boxLeft = (size.width - boxWidth) / 2;
    final boxTop = goalTop + goalHeight;
    paint
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
      paint,
    );

    // 6-yard box
    final sixWidth = goalWidth * 0.6;
    final sixHeight = boxHeight * 0.4;
    final sixLeft = (size.width - sixWidth) / 2;
    final sixTop = goalTop + goalHeight;
    canvas.drawRect(
      Rect.fromLTWH(sixLeft, sixTop, sixWidth, sixHeight),
      paint,
    );

    // Penalty spot
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.77),
      4,
      paint,
    );

    // Keeper, player, ball
    _drawKeeper(canvas, size, goalLeft, goalTop, goalWidth, goalHeight);
    _drawPlayer(canvas, size, kickT, playerPos);
    _drawBall(canvas, size, ballPos);
  }

  void _drawKeeper(Canvas canvas, Size size, double goalLeft, double goalTop,
      double goalWidth, double goalHeight) {
    final paint = Paint();

    final keeperWidth = goalWidth * 0.23;
    final keeperHeight = goalHeight * 0.8;

    final minCenterX = goalLeft + keeperWidth / 2;
    final maxCenterX = goalLeft + goalWidth - keeperWidth / 2;
    final cx = minCenterX + (maxCenterX - minCenterX) * keeperT;

    final top = goalTop + goalHeight * 0.18;

    final headRadius = keeperWidth * 0.13;
    paint
      ..color = const Color(0xFFF4D0A1)
      ..style = PaintingStyle.fill;
    final headCenter = Offset(cx, top + headRadius);
    canvas.drawCircle(headCenter, headRadius, paint);

    // simple hair line
    paint.color = const Color(0xFF5B3A24);
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      math.pi,
      math.pi,
      true,
      paint,
    );

    // torso (jersey)
    paint.color = const Color(0xFF0054A6);
    final torsoWidth = keeperWidth * 0.55;
    final torsoHeight = keeperHeight * 0.5;
    final torsoRect = Rect.fromLTWH(
      cx - torsoWidth / 2,
      headCenter.dy + headRadius * 0.2,
      torsoWidth,
      torsoHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
      paint,
    );

    // arms
    paint
      ..color = const Color(0xFF0054A6)
      ..strokeWidth = 4;
    final shoulderY = torsoRect.top + torsoHeight * 0.25;

    if (!keeperHasBall) {
      final armSpan = torsoWidth * 1.8;
      canvas.drawLine(
        Offset(cx - armSpan / 2, shoulderY),
        Offset(cx + armSpan / 2, shoulderY),
        paint,
      );
    } else {
      final handsY = torsoRect.top + torsoHeight * 0.45;
      final leftShoulder = Offset(cx - torsoWidth * 0.6, shoulderY);
      final rightShoulder = Offset(cx + torsoWidth * 0.6, shoulderY);
      canvas.drawLine(leftShoulder, Offset(cx - 4, handsY), paint);
      canvas.drawLine(rightShoulder, Offset(cx + 4, handsY), paint);
    }

    // shorts + legs
    final shortsHeight = keeperHeight * 0.22;
    paint.color = const Color(0xFF222222);
    final shortsRect = Rect.fromLTWH(
      cx - torsoWidth / 2,
      torsoRect.bottom,
      torsoWidth,
      shortsHeight,
    );
    canvas.drawRect(shortsRect, paint);

    paint
      ..color = Colors.white
      ..strokeWidth = 4;

    final legTop = shortsRect.bottom;
    final legLength = keeperHeight * 0.35;

    final leftHip = Offset(cx - torsoWidth * 0.18, legTop);
    final rightHip = Offset(cx + torsoWidth * 0.18, legTop);

    // white socks
    canvas.drawLine(
      leftHip,
      Offset(leftHip.dx - torsoWidth * 0.1, legTop + legLength),
      paint,
    );
    canvas.drawLine(
      rightHip,
      Offset(rightHip.dx + torsoWidth * 0.1, legTop + legLength),
      paint,
    );

    // black boots
    final bootsPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(leftHip.dx - torsoWidth * 0.1, legTop + legLength),
      Offset(leftHip.dx - torsoWidth * 0.18, legTop + legLength),
      bootsPaint,
    );
    canvas.drawLine(
      Offset(rightHip.dx + torsoWidth * 0.1, legTop + legLength),
      Offset(rightHip.dx + torsoWidth * 0.18, legTop + legLength),
      bootsPaint,
    );
  }

  void _drawPlayer(
      Canvas canvas, Size size, double kickT, Offset playerPosFrac) {
    final paint = Paint();

    final px = playerPosFrac.dx * size.width;
    final py = playerPosFrac.dy * size.height;

    final bodyHeight = size.height * 0.18;
    final headRadius = bodyHeight * 0.12;

    // head
    paint
      ..color = const Color(0xFFF4D0A1)
      ..style = PaintingStyle.fill;
    final headCenter = Offset(px, py - bodyHeight * 0.7);
    canvas.drawCircle(headCenter, headRadius, paint);

    // hair
    paint.color = const Color(0xFF6B3C1E);
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      math.pi,
      math.pi,
      true,
      paint,
    );

    // torso (white shirt)
    paint.color = Colors.white;
    final torsoWidth = bodyHeight * 0.26;
    final torsoHeight = bodyHeight * 0.48;
    final torsoRect = Rect.fromLTWH(
      px - torsoWidth / 2,
      headCenter.dy + headRadius * 0.2,
      torsoWidth,
      torsoHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
      paint,
    );

    // arms (simple)
    paint
      ..color = Colors.white
      ..strokeWidth = 3.5;
    final armY = torsoRect.top + torsoHeight * 0.3;
    final armSpan = torsoWidth * 1.7;
    canvas.drawLine(
      Offset(px - armSpan / 2, armY),
      Offset(px + armSpan / 2, armY),
      paint,
    );

    // shorts
    paint.color = const Color(0xFF777777);
    final shortsHeight = bodyHeight * 0.22;
    final shortsRect = Rect.fromLTWH(
      px - torsoWidth / 2,
      torsoRect.bottom,
      torsoWidth,
      shortsHeight,
    );
    canvas.drawRect(shortsRect, paint);

    // legs
    paint
      ..color = Colors.white
      ..strokeWidth = 4;

    final hipY = shortsRect.bottom;
    final legLength = bodyHeight * 0.45;

    final leftHip = Offset(px - torsoWidth * 0.22, hipY);
    final leftFoot =
        Offset(leftHip.dx - torsoWidth * 0.08, hipY + legLength);
    canvas.drawLine(leftHip, leftFoot, paint);

    final rightHip = Offset(px + torsoWidth * 0.22, hipY);
    const startAngle = 1.6;
    const endAngle = 0.7;
    final eased = Curves.easeOut.transform(kickT.clamp(0.0, 1.0));
    final angle = startAngle + (endAngle - startAngle) * eased;
    final dx = legLength * math.cos(angle);
    final dy = legLength * math.sin(angle);
    final rightFoot = Offset(rightHip.dx + dx, rightHip.dy + dy);
    canvas.drawLine(rightHip, rightFoot, paint);

    // boots
    final bootsPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5;
    canvas.drawLine(
      leftFoot,
      Offset(leftFoot.dx - torsoWidth * 0.07, leftFoot.dy),
      bootsPaint,
    );
    canvas.drawLine(
      rightFoot,
      Offset(rightFoot.dx + torsoWidth * 0.07, rightFoot.dy),
      bootsPaint,
    );
  }

  void _drawBall(Canvas canvas, Size size, Offset ballPos) {
    final paint = Paint();
    final r = size.width * 0.018;
    final c = Offset(ballPos.dx * size.width, ballPos.dy * size.height);

    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, paint);

    paint
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, r, paint);

    paint
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    canvas.drawCircle(c, r * 0.25, paint);

    const patches = 6;
    for (int i = 0; i < patches; i++) {
      final angle = 2 * math.pi * i / patches;
      final o = Offset(
        math.cos(angle) * r * 0.6,
        math.sin(angle) * r * 0.6,
      );
      canvas.drawCircle(c + o, r * 0.18, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PenaltyFieldPainter old) {
    return old.ballPos != ballPos ||
        old.keeperT != keeperT ||
        old.kickT != kickT ||
        old.playerPos != playerPos ||
        old.keeperHasBall != keeperHasBall;
  }
}
