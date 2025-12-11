// lib/secondstage.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SecondStagePage extends StatefulWidget {
  const SecondStagePage({super.key});

  @override
  State<SecondStagePage> createState() => _SecondStagePageState();
}

enum BallPhase { idle, shot, bounce }

class _SecondStagePageState extends State<SecondStagePage>
    with TickerProviderStateMixin {
  late AnimationController _ballController;
  Animation<Offset>? _ballAnimation;
  BallPhase _ballPhase = BallPhase.idle;

  late AnimationController _keeperController;
  double _keeperT = 0.5;

  late AnimationController _playerRunController;
  Animation<Offset>? _playerRunAnimation;

  late AnimationController _playerKickController;
  double _kickT = 0.0;

  final Offset _initialBallPos = const Offset(0.35, 0.78);
  final Offset _initialPlayerPos = const Offset(0.30, 0.88);

  Offset _ballPos = const Offset(0.35, 0.78);
  Offset _playerPos = const Offset(0.30, 0.88);

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
      duration: const Duration(milliseconds: 650),
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
        if (_ballPhase == BallPhase.shot) {
          _evaluateShotResult();
        } else if (_ballPhase == BallPhase.bounce) {
          _ballPhase = BallPhase.idle;
          _resetAfter();
        }
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
      duration: const Duration(milliseconds: 280),
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
      duration: const Duration(milliseconds: 330),
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

  void _onPanStart(DragStartDetails d, Size size) {
    if (_isAnimating) return;
    setState(() {
      _statusText = '';
    });
    final local = d.localPosition;
    _dragStart = local;
    _dragLast = local;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isAnimating) return;
    _dragLast = d.localPosition;
  }

  void _onPanEnd(DragEndDetails d, Size size) {
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

    _ballPhase = BallPhase.shot;
    _ballController.forward(from: 0);
    _playerKickController.forward(from: 0);
  }

  void _evaluateShotResult() {
    if (_lastShotStart == null || _lastShotEnd == null) {
      setState(() => _statusText = 'MISS!');
      _resetAfter();
      return;
    }

    final p0 = _lastShotStart!;
    final p1 = _lastShotEnd!;

    // goal and keeper geometry
    const goalWidthFrac = 0.6;
    const goalHeightFrac = 0.15;
    const goalLeftFrac = (1.0 - goalWidthFrac) / 2.0;
    const goalTopFrac = 0.18;
    const goalRightFrac = goalLeftFrac + goalWidthFrac;
    const goalBottomFrac = goalTopFrac + goalHeightFrac;

    const keeperWidthFrac = goalWidthFrac * 0.23;
    const keeperHeightFrac = goalHeightFrac * 0.8;
    const minCenterX = goalLeftFrac + keeperWidthFrac / 2;
    const maxCenterX = goalRightFrac - keeperWidthFrac / 2;
    final keeperCenterX =
        minCenterX + (maxCenterX - minCenterX) * _keeperT;
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

    // wall
    const wallX = 0.5;
    const wallY = 0.63;
    const wallW = 0.045;
    const wallH = 0.18;
    final wL = wallX - wallW / 2 - ballR;
    final wR = wallX + wallW / 2 + ballR;
    final wT = wallY - wallH / 2 - ballR;
    final wB = wallY + wallH / 2 + ballR;

    const steps = 40;
    bool hitKeeper = false;
    bool hitGoal = false;
    bool hitWall = false;
    double wallHitT = 0.0;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = p0.dx + (p1.dx - p0.dx) * t;
      final y = p0.dy + (p1.dy - p0.dy) * t;

      if (x >= wL && x <= wR && y >= wT && y <= wB) {
        hitWall = true;
        wallHitT = t;
        break;
      }

      if (x >= kL && x <= kR && y >= kT && y <= kB) {
        hitKeeper = true;
        break;
      }

      if (x >= gL && x <= gR && y >= gT && y <= gB) {
        hitGoal = true;
      }
    }

    // 1) wall bounce
    if (hitWall) {
      final collision = Offset(
        p0.dx + (p1.dx - p0.dx) * wallHitT,
        p0.dy + (p1.dy - p0.dy) * wallHitT,
      );
      final dir = p1 - p0;
      final len = dir.distance == 0 ? 1 : dir.distance;
      final dirNorm = dir / len.toDouble(); // <-- fixed cast
      final reflected = Offset(-dirNorm.dx, dirNorm.dy);
      final bounceLen = (len * 0.3).clamp(0.06, 0.5);
      var bounceTarget = collision + reflected * bounceLen;
      bounceTarget = Offset(
        bounceTarget.dx.clamp(0.0, 1.0),
        bounceTarget.dy.clamp(0.0, 1.0),
      );

      setState(() {
        _statusText = 'BLOCKED!';
        _ballPos = collision;
      });

      _ballAnimation = Tween<Offset>(
        begin: collision,
        end: bounceTarget,
      ).animate(
        CurvedAnimation(
          parent: _ballController,
          curve: Curves.easeOut,
        ),
      );

      _ballPhase = BallPhase.bounce;
      _ballController.forward(from: 0);
      return;
    }

    // 2) keeper save
    if (hitKeeper) {
      final chestY = keeperTop + keeperHeightFrac * 0.45;
      final savedPos = Offset(keeperCenterX, chestY);

      setState(() {
        _statusText = 'SAVED!';
        _ballPos = savedPos;
        _keeperHasBall = true;
      });

      _keeperController.stop();
      _ballPhase = BallPhase.idle;

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

    // 3) goal
    if (hitGoal) {
      setState(() => _statusText = 'GOAL!');
      _ballPhase = BallPhase.idle;
      _resetAfter();
      return;
    }

    // 4) miss
    setState(() => _statusText = 'MISS!');
    _ballPhase = BallPhase.idle;
    _resetAfter();
  }

  void _resetAfter() {
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
                  painter: FreeKickFieldPainter(
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
                        fontSize: 28,
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

class FreeKickFieldPainter extends CustomPainter {
  final Offset ballPos;
  final double keeperT;
  final double kickT;
  final Offset playerPos;
  final bool keeperHasBall;

  FreeKickFieldPainter({
    required this.ballPos,
    required this.keeperT,
    required this.kickT,
    required this.playerPos,
    required this.keeperHasBall,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // --- background: sky ---
    paint.color = const Color(0xFF1D4F91);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.18),
      paint,
    );

    // --- stands with crowd ---
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

    // --- ads ---
    paint.color = const Color(0xFFD71F26);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.06),
      paint,
    );

    // --- pitch ---
    paint.color = const Color(0xFF137F2B);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.24, size.width, size.height * 0.76),
      paint,
    );

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

    // --- goal ---
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

    // net
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

    // penalty area
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

    // free kick mark
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.78),
      3,
      paint,
    );

    // elements
    _drawWallPlayer(canvas, size);
    _drawKeeper(canvas, size, goalLeft, goalTop, goalWidth, goalHeight);
    _drawPlayer(canvas, size, kickT, playerPos);
    _drawBall(canvas, size, ballPos);
  }

  // --- keeper (same style as penalty scene) ---
  void _drawKeeper(Canvas canvas, Size size, double goalLeft, double goalTop,
      double goalWidth, double goalHeight) {
    final paint = Paint();

    final keeperWidth = goalWidth * 0.23;
    final keeperHeight = goalHeight * 0.8;

    final minCenterX = goalLeft + keeperWidth / 2;
    final maxCenterX = goalLeft + goalWidth - keeperWidth / 2;
    final cx = minCenterX + (maxCenterX - minCenterX) * keeperT;

    final top = goalTop + goalHeight * 0.18;

    // head
    final headRadius = keeperWidth * 0.13;
    paint
      ..color = const Color(0xFFF4D0A1)
      ..style = PaintingStyle.fill;
    final headCenter = Offset(cx, top + headRadius);
    canvas.drawCircle(headCenter, headRadius, paint);

    // hair
    paint.color = const Color(0xFF5B3A24);
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      math.pi,
      math.pi,
      true,
      paint,
    );

    // torso
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

    // shorts
    paint.color = const Color(0xFF222222);
    final shortsHeight = keeperHeight * 0.22;
    final shortsRect = Rect.fromLTWH(
      cx - torsoWidth / 2,
      torsoRect.bottom,
      torsoWidth,
      shortsHeight,
    );
    canvas.drawRect(shortsRect, paint);

    // legs
    paint
      ..color = Colors.white
      ..strokeWidth = 4;
    final legTop = shortsRect.bottom;
    final legLength = keeperHeight * 0.35;

    final leftHip = Offset(cx - torsoWidth * 0.18, legTop);
    final rightHip = Offset(cx + torsoWidth * 0.18, legTop);
    final leftFoot =
        Offset(leftHip.dx - torsoWidth * 0.1, legTop + legLength);
    final rightFoot =
        Offset(rightHip.dx + torsoWidth * 0.1, legTop + legLength);

    canvas.drawLine(leftHip, leftFoot, paint);
    canvas.drawLine(rightHip, rightFoot, paint);

    // boots
    final bootsPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5;
    canvas.drawLine(
      leftFoot,
      Offset(leftFoot.dx - torsoWidth * 0.08, leftFoot.dy),
      bootsPaint,
    );
    canvas.drawLine(
      rightFoot,
      Offset(rightFoot.dx + torsoWidth * 0.08, rightFoot.dy),
      bootsPaint,
    );
  }

  // --- wall player protecting balls, two legs ---
  void _drawWallPlayer(Canvas canvas, Size size) {
    final paint = Paint();

    final x = size.width * 0.5;
    final y = size.height * 0.63;

    final bodyHeight = size.height * 0.16;
    final headRadius = bodyHeight * 0.12;

    // head
    paint
      ..color = const Color(0xFFF4D0A1)
      ..style = PaintingStyle.fill;
    final headCenter = Offset(x, y - bodyHeight * 0.7);
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

    // torso
    paint.color = const Color(0xFF0FA655);
    final torsoWidth = bodyHeight * 0.24;
    final torsoHeight = bodyHeight * 0.5;
    final torsoRect = Rect.fromLTWH(
      x - torsoWidth / 2,
      headCenter.dy + headRadius * 0.2,
      torsoWidth,
      torsoHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
      paint,
    );

    // arms covering balls
    paint
      ..color = const Color(0xFF0FA655)
      ..strokeWidth = 3.8;
    final shoulderY = torsoRect.top + torsoHeight * 0.25;
    final shoulderLeft = x - torsoWidth * 0.55;
    final shoulderRight = x + torsoWidth * 0.55;
    final handsY = torsoRect.bottom - torsoHeight * 0.05;
    final handsX = x;
    canvas.drawLine(
      Offset(shoulderLeft, shoulderY),
      Offset(handsX - 3, handsY),
      paint,
    );
    canvas.drawLine(
      Offset(shoulderRight, shoulderY),
      Offset(handsX + 3, handsY),
      paint,
    );

    // shorts
    paint.color = const Color(0xFF146B3A);
    final shortsHeight = bodyHeight * 0.23;
    final shortsRect = Rect.fromLTWH(
      x - torsoWidth / 2,
      torsoRect.bottom,
      torsoWidth,
      shortsHeight,
    );
    canvas.drawRect(shortsRect, paint);

    // two legs
    paint
      ..color = Colors.white
      ..strokeWidth = 4;
    final hipY = shortsRect.bottom;
    final legLength = bodyHeight * 0.42;

    final leftHip = Offset(x - torsoWidth * 0.2, hipY);
    final rightHip = Offset(x + torsoWidth * 0.2, hipY);
    final leftFoot =
        Offset(leftHip.dx - torsoWidth * 0.05, hipY + legLength);
    final rightFoot =
        Offset(rightHip.dx + torsoWidth * 0.05, hipY + legLength);

    canvas.drawLine(leftHip, leftFoot, paint);
    canvas.drawLine(rightHip, rightFoot, paint);

    final bootsPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5;
    canvas.drawLine(
      leftFoot,
      Offset(leftFoot.dx - torsoWidth * 0.05, leftFoot.dy),
      bootsPaint,
    );
    canvas.drawLine(
      rightFoot,
      Offset(rightFoot.dx + torsoWidth * 0.05, rightFoot.dy),
      bootsPaint,
    );
  }

  // --- kicker ---
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

    // shirt
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

    // arms
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

    // support leg
    final leftHip = Offset(px - torsoWidth * 0.22, hipY);
    final leftFoot =
        Offset(leftHip.dx - torsoWidth * 0.08, hipY + legLength);
    canvas.drawLine(leftHip, leftFoot, paint);

    // kicking leg
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

  // --- ball ---
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
  bool shouldRepaint(covariant FreeKickFieldPainter old) {
    return old.ballPos != ballPos ||
        old.keeperT != keeperT ||
        old.kickT != kickT ||
        old.playerPos != playerPos ||
        old.keeperHasBall != keeperHasBall;
  }
}
