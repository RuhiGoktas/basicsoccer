// main.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'secondstage.dart';
import 'firststage.dart';


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
      home: const PickCountryWelcomePage(),
    );
  }
}

class PenaltyStagePage extends StatefulWidget {
  final String teamName;
  final String playerName;
  final int playerNumber;
  final Color shirtColor;
  final Color skinColor;

  const PenaltyStagePage({
    super.key,
    required this.teamName,
    required this.playerName,
    required this.playerNumber,
    required this.shirtColor,
	required this.skinColor,
  });

  @override
  State<PenaltyStagePage> createState() => _PenaltyStagePageState();
}


class _PenaltyStagePageState extends State<PenaltyStagePage>
    with TickerProviderStateMixin {
  late AnimationController _ballController;
  Animation<Offset>? _ballAnimation;

  late AnimationController _keeperController;
  double _keeperT = 0.5;
  double _lastShotPower = 0.0;


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
	
	_lastShotPower = power;

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

	const goalWidthFrac  = 0.55;
	const goalHeightFrac = 0.13;
	const goalLeftFrac   = (1.0 - goalWidthFrac) / 2.0; // 0.225
	const goalTopFrac    = 0.22;                        // same as painter
	const goalRightFrac  = goalLeftFrac + goalWidthFrac;
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

	final gL = goalLeftFrac  + ballR * 0.3;  // a bit inside left post
	final gR = goalRightFrac - ballR * 0.3;  // a bit inside right post
	final gT = goalTopFrac   + ballR * 0.6;  // BELOW the crossbar
	final gB = goalBottomFrac - ballR * 0.2; // ABOVE the ground / line

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
  // keeper logic unchanged
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

// define a "too strong" threshold
const maxReasonablePower = 450.0; // tweak this to taste
final isTooPowerful = _lastShotPower > maxReasonablePower;

if (hitGoal && !isTooPowerful) {
  // normal GOAL
  setState(() {
    _statusText = 'GOAL!';
  });

  Future.delayed(const Duration(milliseconds: 900), () {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>  SecondStagePage(
	teamName: widget.teamName,
      playerName: widget.playerName,
      playerNumber: widget.playerNumber,
      shirtColor: widget.shirtColor,
      skinColor: widget.skinColor,
		),
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

// either we never hit the goal box, or it was TOO POWERFUL
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
					shirtColor: widget.shirtColor,
					playerName: widget.playerName,
					playerNumber: widget.playerNumber,
					skinColor: widget.skinColor,

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
  final Color shirtColor;
  final String playerName;
  final int playerNumber;
  final Color skinColor;


  PenaltyFieldPainter({
    required this.ballPos,
    required this.keeperT,
    required this.kickT,
    required this.playerPos,
    required this.keeperHasBall,
	required this.shirtColor,
    required this.playerName,
    required this.playerNumber,
	required this.skinColor,

  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackgroundAndCrowd(canvas, size);
    _drawAds(canvas, size);

    // Pitch and lines
    _drawPitch(canvas, size);

    // Goal & net
    final goalInfo = _drawGoalAndNet(canvas, size);

    // Keeper in front of goal
    _drawKeeper(canvas, size, goalInfo);

    // Kicker (foreground player) – drawn after keeper so he appears closer
    _drawKicker(canvas, size, playerPos, kickT);

    // Ball – slightly in front of kicker by default
    _drawBall(canvas, size, ballPos);

    // Optional: soft shadow under ball
    _drawBallShadow(canvas, size, ballPos);
  }

  // ---------------------------------------------------------------------------
  // BACKGROUND / CROWD / ADS
  // ---------------------------------------------------------------------------

  void _drawBackgroundAndCrowd(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint();

    // Sky gradient
    final skyRect = Rect.fromLTWH(0, 0, w, h * 0.18);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF3D6CCF),
        Color(0xFF6FA3FF),
      ],
    ).createShader(skyRect);
    canvas.drawRect(skyRect, paint);

    // Crowd block (below sky)
    final crowdTop = h * 0.05;
    final crowdHeight = h * 0.17;
    final crowdRect = Rect.fromLTWH(0, crowdTop, w, crowdHeight);

    // Base dark crowd color
    paint.shader = null;
    paint.color = const Color(0xFF1F2336);
    canvas.drawRect(crowdRect, paint);

    // "People" as noisy tiles
    final tileW = w / 24;
    final tileH = crowdHeight / 6;
    final colors = <Color>[
      const Color(0xFFF4D0A1), // skin / faces
      const Color(0xFFECF0F1), // white shirts
      const Color(0xFF2ECC71), // green
      const Color(0xFF3498DB), // blue
      const Color(0xFFE74C3C), // red
      const Color(0xFFBDC3C7), // gray
    ];

    final personPaint = Paint();
    for (int r = 0; r < 6; r++) {
      for (int c = 0; c < 24; c++) {
        final x = c * tileW;
        final y = crowdTop + r * tileH;
        personPaint.color = colors[(r * 5 + c * 3) % colors.length];
        canvas.drawRect(
          Rect.fromLTWH(x + 1, y + 1, tileW - 2, tileH - 2),
          personPaint,
        );
      }
    }

    // Slight top highlight to simulate lights
    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.2),
          Colors.transparent,
        ],
      ).createShader(crowdRect);
    canvas.drawRect(crowdRect, overlayPaint);
  }

  void _drawAds(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final adsTop = h * 0.21;
    final adsHeight = h * 0.06;

    // Long ad strip
    final adsRect = Rect.fromLTWH(0, adsTop, w, adsHeight);
    paint.color = const Color(0xFFB81C24);
    canvas.drawRect(adsRect, paint);

    // Segment blocks
    final segments = 6;
    final segW = w / segments.toDouble();
    final adColors = <Color>[
      const Color(0xFF1482C6), // blue
      const Color(0xFFEAEAEA), // light
      const Color(0xFFDB2E2E), // red
      const Color(0xFF1482C6),
      const Color(0xFFF4F4F4),
      const Color(0xFFDB2E2E),
    ];

    for (int i = 0; i < segments; i++) {
      paint.color = adColors[i % adColors.length];
      final r = Rect.fromLTWH(i * segW, adsTop, segW, adsHeight);
      canvas.drawRect(r, paint);
    }

    // White line on top of boards
    paint
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, adsTop),
      Offset(w, adsTop),
      paint,
    );
  }

  // ---------------------------------------------------------------------------
  // PITCH & GOAL
  // ---------------------------------------------------------------------------

  void _drawPitch(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    // Pitch gradient
    final pitchTop = h * 0.24;
    final pitchRect = Rect.fromLTWH(0, pitchTop, w, h - pitchTop);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF1E8F35),
        Color(0xFF076D23),
      ],
    ).createShader(pitchRect);
    canvas.drawRect(pitchRect, paint);

    // Stripes with perspective: narrower near goal, wider in foreground
    final stripePaint = Paint()..color = const Color(0xFF0E6A21);
    final stripes = 9;
    for (int i = 0; i < stripes; i++) {
      final tTop = i / stripes;
      final tBottom = (i + 1) / stripes;
      final yTop = pitchTop + (h - pitchTop) * tTop;
      final yBottom = pitchTop + (h - pitchTop) * tBottom;
      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTRB(0, yTop, w, yBottom),
          stripePaint,
        );
      }
    }

    // Center line-ish (just hint)
    paint
      ..shader = null
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, h * 0.60),
      Offset(w, h * 0.55),
      paint,
    );
  }

  /// Returns (goalLeft, goalTop, goalWidth, goalHeight)
  Rect _drawGoalAndNet(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    // PES-like proportions
    final goalWidth = w * 0.55;
    final goalHeight = h * 0.13;
    final goalLeft = (w - goalWidth) / 2;
    final goalTop = h * 0.22;
    final goalRect = Rect.fromLTWH(goalLeft, goalTop, goalWidth, goalHeight);

    // Posts & bar
    paint
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawRect(goalRect, paint);

    // Net, slightly leaning back (2.5D)
    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1;

    final depth = h * 0.04;
    final backTopLeft =
        Offset(goalLeft + w * 0.02, goalTop + depth * 0.3);
    final backTopRight =
        Offset(goalLeft + goalWidth - w * 0.02, goalTop + depth * 0.3);
    final backBottomLeft =
        Offset(goalLeft + w * 0.04, goalTop + goalHeight);
    final backBottomRight =
        Offset(goalLeft + goalWidth - w * 0.04, goalTop + goalHeight);

    // Side polygons
    final path = Path()
      ..moveTo(goalLeft, goalTop)
      ..lineTo(backTopLeft.dx, backTopLeft.dy)
      ..lineTo(backBottomLeft.dx, backBottomLeft.dy)
      ..lineTo(goalLeft, goalTop + goalHeight)
      ..close();
    canvas.drawPath(path, netPaint);

    final pathR = Path()
      ..moveTo(goalLeft + goalWidth, goalTop)
      ..lineTo(backTopRight.dx, backTopRight.dy)
      ..lineTo(backBottomRight.dx, backBottomRight.dy)
      ..lineTo(goalLeft + goalWidth, goalTop + goalHeight)
      ..close();
    canvas.drawPath(pathR, netPaint);

    // Back net
    for (int i = 0; i <= 6; i++) {
      final t = i / 6;
      final yFront = goalTop + goalHeight * t;
      final yBack =
          backTopLeft.dy + (backBottomLeft.dy - backTopLeft.dy) * t;
      canvas.drawLine(
        Offset(goalLeft, yFront),
        Offset(backTopLeft.dx, yBack),
        netPaint,
      );
      canvas.drawLine(
        Offset(goalLeft + goalWidth, yFront),
        Offset(backTopRight.dx, yBack),
        netPaint,
      );
    }

    // Horizontal net lines at the back
    for (int j = 1; j <= 5; j++) {
      final tj = j / 6;
      final y = backTopLeft.dy +
          (backBottomLeft.dy - backTopLeft.dy) * tj;
      canvas.drawLine(
        Offset(backTopLeft.dx, y),
        Offset(backTopRight.dx, y),
        netPaint,
      );
    }

    // Goal line (on pitch)
    paint
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(goalLeft, goalTop + goalHeight),
      Offset(goalLeft + goalWidth, goalTop + goalHeight),
      paint,
    );

    return goalRect;
  }

  // ---------------------------------------------------------------------------
  // KEEPER / KICKER / BALL
  // ---------------------------------------------------------------------------

  void _drawKeeper(Canvas canvas, Size size, Rect goalRect) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final goalLeft = goalRect.left;
    final goalWidth = goalRect.width;
    final goalTop = goalRect.top;
    final goalHeight = goalRect.height;

    // Keeper center x based on keeperT
    final minX = goalLeft + goalWidth * 0.18;
    final maxX = goalLeft + goalWidth * 0.82;
    final cx = minX + (maxX - minX) * keeperT;

    final baseY = goalTop + goalHeight * 0.78; // feet on goal line
    final height = h * 0.16; // relatively small vs kicker
    final headRadius = height * 0.12;

    // Head
    paint
      ..color = const Color(0xFFF4D0A1)
      ..style = PaintingStyle.fill;
    final headCenter = Offset(cx, baseY - height + headRadius * 1.1);
    canvas.drawCircle(headCenter, headRadius, paint);

    // Hair
    paint.color = const Color(0xFF3C2A20);
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      math.pi,
      math.pi,
      true,
      paint,
    );

    // Torso – yellow jersey
    paint.color = const Color(0xFFF1C40F);
    final torsoW = height * 0.35;
    final torsoH = height * 0.45;
    final torsoRect = Rect.fromLTWH(
      cx - torsoW / 2,
      headCenter.dy + headRadius * 0.2,
      torsoW,
      torsoH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
      paint,
    );

    // Arms
    paint
      ..color = const Color(0xFFF1C40F)
      ..strokeWidth = 4;
    final shoulderY = torsoRect.top + torsoH * 0.3;

    if (!keeperHasBall) {
      final armSpan = torsoW * 1.7;
      canvas.drawLine(
        Offset(cx - armSpan / 2, shoulderY),
        Offset(cx + armSpan / 2, shoulderY),
        paint,
      );
    } else {
      // Embracing the ball
      final handsY = torsoRect.top + torsoH * 0.55;
      final leftShoulder = Offset(cx - torsoW * 0.8, shoulderY);
      final rightShoulder = Offset(cx + torsoW * 0.8, shoulderY);
      canvas.drawLine(leftShoulder, Offset(cx - 4, handsY), paint);
      canvas.drawLine(rightShoulder, Offset(cx + 4, handsY), paint);
    }

    // Shorts – blue
    paint.color = const Color(0xFF1F2C4C);
    final shortsH = height * 0.22;
    final shortsRect = Rect.fromLTWH(
      cx - torsoW / 2,
      torsoRect.bottom,
      torsoW,
      shortsH,
    );
    canvas.drawRect(shortsRect, paint);

    // Legs
    paint
      ..color = const Color(0xFFF7F7F7)
      ..strokeWidth = 4;
    final legTop = shortsRect.bottom;
    final legLen = height * 0.35;
    final leftHip = Offset(cx - torsoW * 0.18, legTop);
    final rightHip = Offset(cx + torsoW * 0.18, legTop);
    final leftFoot =
        Offset(leftHip.dx - torsoW * 0.08, legTop + legLen);
    final rightFoot =
        Offset(rightHip.dx + torsoW * 0.08, legTop + legLen);
    canvas.drawLine(leftHip, leftFoot, paint);
    canvas.drawLine(rightHip, rightFoot, paint);

    // Boots
    final bootsPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5;
    canvas.drawLine(
      leftFoot,
      Offset(leftFoot.dx - torsoW * 0.06, leftFoot.dy),
      bootsPaint,
    );
    canvas.drawLine(
      rightFoot,
      Offset(rightFoot.dx + torsoW * 0.06, rightFoot.dy),
      bootsPaint,
    );
  }

void _drawKicker(Canvas canvas, Size size, Offset playerPosFrac, double kickT) {
  final w = size.width;
  final h = size.height;
  final paint = Paint()..isAntiAlias = true;

  final px = playerPosFrac.dx * w;
  final py = playerPosFrac.dy * h;

  final height = h * 0.34;
  final headR = height * 0.115;

  final jerseyColor = shirtColor;

  // ======================
  // HEAD + NECK (skinColor)
  // ======================
  final headCenter = Offset(px, py - height + headR * 1.25);

  // Neck first (under head)
  final neckW = headR * 0.92;
  final neckH = headR * 0.65;
  final neckTop = headCenter.dy + headR * 0.75;

  paint.color = skinColor;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(px, neckTop + neckH * 0.5),
        width: neckW,
        height: neckH,
      ),
      Radius.circular(neckH * 0.35),
    ),
    paint,
  );

  // Head base (taller oval)
  final headRect = Rect.fromCenter(
    center: headCenter,
    width: headR * 2.05,
    height: headR * 2.25,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(headRect, Radius.circular(headR * 1.05)),
    paint,
  );

  // ======================
  // HAIR (covers BACK of head)
  // ======================
  final hairPaint = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFF2C1C11);

  // Big "back hair" oval — draws behind head top, looks like full coverage
  final hairBack = Rect.fromCenter(
    center: Offset(headCenter.dx, headCenter.dy - headR * 0.15),
    width: headR * 2.25,
    height: headR * 2.05,
  );
  canvas.drawOval(hairBack, hairPaint);

  // Then redraw face on top so hair only appears around/back
  paint.color = skinColor;
  canvas.drawRRect(
    RRect.fromRectAndRadius(headRect, Radius.circular(headR * 1.05)),
    paint,
  );

  // Hairline cap (top/front line)
  final hairLineY = headCenter.dy - headR * 0.55;
  final hairCap = Path()
    ..moveTo(headRect.left + headR * 0.15, hairLineY)
    ..quadraticBezierTo(headCenter.dx, headRect.top - headR * 0.10, headRect.right - headR * 0.15, hairLineY)
    ..lineTo(headRect.right - headR * 0.18, headRect.top + headR * 0.55)
    ..quadraticBezierTo(headCenter.dx, headRect.top + headR * 0.72, headRect.left + headR * 0.18, headRect.top + headR * 0.55)
    ..close();
  canvas.drawPath(hairCap, hairPaint);

  // ======================
  // TORSO (wider with shoulders)
  // ======================
  final torsoTop = neckTop + neckH * 0.55;
  final torsoW = height * 0.48;
  final torsoH = height * 0.46;

  final shoulderW = torsoW * 1.24;
  final shoulderH = torsoH * 0.32;

  paint.color = jerseyColor;
  final shouldersRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(px, torsoTop + shoulderH * 0.55),
      width: shoulderW,
      height: shoulderH,
    ),
    Radius.circular(shoulderH * 0.45),
  );
  canvas.drawRRect(shouldersRect, paint);

  final torsoRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      px - torsoW / 2,
      torsoTop + shoulderH * 0.25,
      torsoW,
      torsoH,
    ),
    Radius.circular(torsoW * 0.18),
  );
  canvas.drawRRect(torsoRect, paint);

  // shading
  final shadePaint = Paint()
    ..isAntiAlias = true
    ..color = Colors.black.withOpacity(0.18);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        torsoRect.left + 2,
        torsoRect.top + 2,
        torsoRect.width * 0.20,
        torsoRect.height - 4,
      ),
      Radius.circular(torsoW * 0.18),
    ),
    shadePaint,
  );

  // ======================
  // NAME + NUMBER ON BACK
  // ======================
  final bool darkJersey = jerseyColor.computeLuminance() < 0.45;
  final textColor = darkJersey ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.85);

  final namePainter = TextPainter(
    text: TextSpan(
      text: playerName.toUpperCase(),
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w800,
        fontSize: torsoH * 0.15,
        letterSpacing: 1.1,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: "…",
  )..layout(maxWidth: torsoW * 0.92);

  namePainter.paint(
    canvas,
    Offset(px - namePainter.width / 2, torsoRect.top + torsoH * 0.12),
  );

  final numberPainter = TextPainter(
    text: TextSpan(
      text: "$playerNumber",
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w900,
        fontSize: torsoH * 0.60,
        height: 0.95,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: torsoW);

  numberPainter.paint(
    canvas,
    Offset(px - numberPainter.width / 2, torsoRect.top + torsoH * 0.28),
  );

  // ======================
  // ARMS (longer + hands)
  // ======================
  // sleeves
  paint.color = jerseyColor.withOpacity(0.98);
  final sleeveW = torsoW * 0.32;
  final sleeveH = shoulderH * 0.82;

  final leftSleeveCenter = Offset(px - shoulderW * 0.48, shouldersRect.center.dy + shoulderH * 0.06);
  final rightSleeveCenter = Offset(px + shoulderW * 0.48, shouldersRect.center.dy + shoulderH * 0.06);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: leftSleeveCenter, width: sleeveW, height: sleeveH),
      Radius.circular(sleeveH * 0.45),
    ),
    paint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: rightSleeveCenter, width: sleeveW, height: sleeveH),
      Radius.circular(sleeveH * 0.45),
    ),
    paint,
  );

  // forearms
  paint.color = skinColor;
  final forearmW = sleeveW * 0.62;
  final forearmH = torsoH * 0.70; // longer
  final forearmTopY = leftSleeveCenter.dy + sleeveH * 0.42;

  final leftForearmRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(leftSleeveCenter.dx, forearmTopY + forearmH * 0.5),
      width: forearmW,
      height: forearmH,
    ),
    Radius.circular(forearmW * 0.55),
  );
  final rightForearmRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(rightSleeveCenter.dx, forearmTopY + forearmH * 0.5),
      width: forearmW,
      height: forearmH,
    ),
    Radius.circular(forearmW * 0.55),
  );

  canvas.drawRRect(leftForearmRect, paint);
  canvas.drawRRect(rightForearmRect, paint);

  // hands (simple rounded mitten)
  final handW = forearmW * 0.95;
  final handH = forearmW * 0.55;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(leftSleeveCenter.dx, leftForearmRect.bottom + handH * 0.45),
        width: handW,
        height: handH,
      ),
      Radius.circular(handH * 0.55),
    ),
    paint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rightSleeveCenter.dx, rightForearmRect.bottom + handH * 0.45),
        width: handW,
        height: handH,
      ),
      Radius.circular(handH * 0.55),
    ),
    paint,
  );

  // ======================
  // SHORTS
  // ======================
  final shortsH = height * 0.20;
  final shortsW = torsoW * 1.05;

  paint.color = const Color(0xFF1D2735);
  final shortsRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      px - shortsW / 2,
      torsoRect.bottom - 2,
      shortsW,
      shortsH,
    ),
    Radius.circular(shortsH * 0.25),
  );
  canvas.drawRRect(shortsRect, paint);

// ======================
// LEGS (support + realistic kick with knee)
// ======================
paint.color = const Color(0xFFF7F7F7);

final hipY = shortsRect.bottom;
final legLen = height * 0.44;
final legW = torsoW * 0.20;

final leftHip = Offset(px - shortsW * 0.18, hipY);
final rightHip = Offset(px + shortsW * 0.18, hipY);

// Support leg (left) — straight
final supportRect = RRect.fromRectAndRadius(
  Rect.fromLTWH(leftHip.dx - legW / 2, leftHip.dy, legW, legLen),
  Radius.circular(legW * 0.55),
);
canvas.drawRRect(supportRect, paint);

// ---- Kicking leg (right): thigh + calf with knee ----
final t = Curves.easeOut.transform(kickT.clamp(0.0, 1.0));

// Angles in radians: 0 = right, pi/2 = down.
// Start: mostly down. End: swings forward.
final thighAngle = (math.pi / 2) - (0.85 * t); // ~down -> forward
final kneeBend = 0.25 + 0.95 * t;              // knee bends more as kick happens

final thighLen = legLen * 0.55;
final calfLen = legLen * 0.50;

// Knee position
final knee = Offset(
  rightHip.dx + thighLen * math.cos(thighAngle),
  rightHip.dy + thighLen * math.sin(thighAngle),
);

// Calf angle extends from thigh angle (bend at knee)
final calfAngle = thighAngle - kneeBend;

// Foot position
final foot = Offset(
  knee.dx + calfLen * math.cos(calfAngle),
  knee.dy + calfLen * math.sin(calfAngle),
);

// Draw thigh (thick line with rounded cap)
final legPaint = Paint()
  ..isAntiAlias = true
  ..color = const Color(0xFFF7F7F7)
  ..strokeWidth = legW
  ..strokeCap = StrokeCap.round;

canvas.drawLine(rightHip, knee, legPaint);

// Slightly thinner calf
legPaint.strokeWidth = legW * 0.92;
canvas.drawLine(knee, foot, legPaint);

// Boots
final bootPaint = Paint()
  ..isAntiAlias = true
  ..color = Colors.black;

// Left boot
canvas.drawRRect(
  RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(leftHip.dx, leftHip.dy + legLen + legW * 0.05),
      width: legW * 1.45,
      height: legW * 0.55,
    ),
    Radius.circular(legW * 0.25),
  ),
  bootPaint,
);

// Right boot (at foot, rotated a bit toward kick direction)
final bootW = legW * 1.55;
final bootH = legW * 0.55;

canvas.save();
canvas.translate(foot.dx, foot.dy);
canvas.rotate(calfAngle - math.pi / 2); // align boot with shin direction
canvas.drawRRect(
  RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(0, 0),
      width: bootW,
      height: bootH,
    ),
    Radius.circular(legW * 0.25),
  ),
  bootPaint,
);
canvas.restore();

}

  void _drawBall(Canvas canvas, Size size, Offset ballPosFrac) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final cx = ballPosFrac.dx * w;
    final cy = ballPosFrac.dy * h;

    final r = h * 0.025; // looks good vs player size

    // Base white
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Outline
    paint
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Panels (simple classic pattern)
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.black87;
    canvas.drawCircle(Offset(cx, cy), r * 0.28, paint);

    const patches = 6;
    for (int i = 0; i < patches; i++) {
      final angle = 2 * math.pi * i / patches;
      final o = Offset(
        math.cos(angle) * r * 0.65,
        math.sin(angle) * r * 0.65,
      );
      canvas.drawCircle(Offset(cx, cy) + o, r * 0.18, paint);
    }
  }

  void _drawBallShadow(Canvas canvas, Size size, Offset ballPosFrac) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final cx = ballPosFrac.dx * w;
    final cy = ballPosFrac.dy * h + h * 0.008;

    final rx = h * 0.030;
    final ry = h * 0.010;

    paint
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1.0, ry / rx);
    canvas.drawCircle(Offset.zero, rx, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PenaltyFieldPainter old) {
    return ballPos != old.ballPos ||
        keeperT != old.keeperT ||
        kickT != old.kickT ||
        playerPos != old.playerPos ||
        keeperHasBall != old.keeperHasBall ||
        shirtColor != old.shirtColor ||
        playerName != old.playerName ||
        playerNumber != old.playerNumber;
  }
}
