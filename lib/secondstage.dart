// lib/secondstage.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SecondStagePage extends StatefulWidget {
  final String teamName;
  final String playerName;
  final int playerNumber;
  final Color shirtColor;
  final Color skinColor;

  const SecondStagePage({
    super.key,
    required this.teamName,
    required this.playerName,
    required this.playerNumber,
    required this.shirtColor,
    required this.skinColor,
  });

  @override
  State<SecondStagePage> createState() => _SecondStagePageState();
}


enum BallPhase { idle, shot, bounce }

class _SecondStagePageState extends State<SecondStagePage>
    with TickerProviderStateMixin {
  late AnimationController _ballController;
  Animation<Offset>? _ballAnimation;
  BallPhase _ballPhase = BallPhase.idle;
  
  int _bounceStep = 0;               // 0 › 1st bounce, 1 › 2nd, 2 › 3rd
  List<Offset>? _bouncePoints;       // [collision, b1, b2, b3]


  late AnimationController _keeperController;
  double _keeperT = 0.5;
  int _remainingShots = 3;
  bool _hasScored = false;


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
  
  // for curved free kick
	List<Offset> _swipePoints = [];

	Offset? _curveStart;  // p0
	Offset? _curveMid;    // p1
	Offset? _curveEnd;    // p2


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
  setState(() {
    if (_ballPhase == BallPhase.shot &&
        _curveStart != null &&
        _curveMid != null &&
        _curveEnd != null) {
      final t = _ballController.value.clamp(0.0, 1.0);
      _ballPos = _bezier2(_curveStart!, _curveMid!, _curveEnd!, t);
    } else {
      _ballPos = _ballAnimation?.value ?? _ballPos;
    }
  });
});
_ballController.addStatusListener((status) {
  if (status == AnimationStatus.completed) {
    if (_ballPhase == BallPhase.bounce) {
      // handle bounce steps only
      _bounceStep++;
      if (_bouncePoints != null && _bounceStep < 3) {
        _startBounceFromPoints();
      } else {
        _resetAfter();
      }
    } else {
      // any non-bounce completion (shot / safety) › evaluate result
      _evaluateShotResult();
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

  _dragStart = d.localPosition;
  _dragLast = d.localPosition;

  // start recording swipe path
  _swipePoints = [d.localPosition];
}


void _onPanUpdate(DragUpdateDetails d, Size size) {
  if (_isAnimating || _dragStart == null) return;

  _dragLast = d.localPosition;

  // keep adding points for curve
  _swipePoints.add(d.localPosition);
}

void _onPanEnd(DragEndDetails d, Size size) {
  if (_isAnimating) return;
  if (_dragStart == null || _dragLast == null) return;

  final direction = _dragLast! - _dragStart!;
  if (direction.distance < 20) {
    _dragStart = null;
    _dragLast = null;
    _swipePoints.clear();
    return;
  }

  // --- build Bézier from swipe path ---

  if (_swipePoints.length < 3) {
    // fallback: fake a simple slight curve using drag start/mid/end
    _swipePoints = [
      _dragStart!,
      (_dragStart! + _dragLast!) / 2,
      _dragLast!,
    ];
  }

  final localStart = _swipePoints.first;
  final localEnd = _swipePoints.last;
  final localMid = _swipePoints[_swipePoints.length ~/ 2];

  // convert to 0..1 fractions
  final p0 = _ballPos; // REAL start is the ball itself
  final p2 = Offset(localEnd.dx / size.width, localEnd.dy / size.height);
  final p1 = Offset(localMid.dx / size.width, localMid.dy / size.height);

  _curveStart = p0;
  _curveMid = p1;
  _curveEnd = p2;

  _lastShotStart = p0;
  _lastShotEnd = p2;

  // This is only used for timing (ball controller duration); end = curve end
  Offset targetFrac = p2;

  _pendingBallTargetFrac = targetFrac;

  // --- player run-up (same as before) ---
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
  _swipePoints.clear();
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
	
  final p0 = _curveStart ?? _lastShotStart!;
  final p2 = _curveEnd ?? _lastShotEnd!;
  final p1 = _curveMid ??
      Offset(
        (p0.dx + p2.dx) / 2,
        (p0.dy + p2.dy) / 2,
      );

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
		final pos = _bezier2(p0, p1, p2, t);
		final x = pos.dx;
		final y = pos.dy;


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
  // The shot was truncated to the wall front in _onPanEnd,
  // so the end point is effectively the collision point.
  final collision = _lastShotEnd ?? p1;

  // Slight vertical bounces in place (no horizontal drift)
  final c0 = collision;
  final c1 = Offset(collision.dx, (collision.dy - 0.05).clamp(0.0, 1.0));
  final c2 = Offset(collision.dx, (collision.dy - 0.02).clamp(0.0, 1.0));
  final c3 = collision;

  setState(() {
    _statusText = 'BLOCKED!';
    _ballPos = c0;
    _ballPhase = BallPhase.bounce;
    _bounceStep = 0;
    _bouncePoints = [c0, c1, c2, c3];
  });
  _registerAttempt(scored: false);
  _startBounceFromPoints();
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
	  _registerAttempt(scored: false);

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
	  _registerAttempt(scored: true);
      _resetAfter();
      return;
    }

    // 4) miss
    setState(() => _statusText = 'MISS!');
    _ballPhase = BallPhase.idle;
	_registerAttempt(scored: false);
    _resetAfter();
  }

  void _registerAttempt({required bool scored}) {
  setState(() {
    if (scored) {
      _hasScored = true;
    }

    if (_remainingShots > 0) {
      _remainingShots--;
    }
  });

  // If all chances used AND never scored › go back to first scene
  if (_remainingShots == 0 && !_hasScored) {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).pop(); // back to penalty scene (first page)
    });
  }
}

  void _startBounceFromPoints() {
  if (_bouncePoints == null || _bouncePoints!.length < 2) {
    _resetAfter();
    return;
  }

  final int nextIndex = _bounceStep + 1;
  if (nextIndex >= _bouncePoints!.length) {
    _resetAfter();
    return;
  }

  final begin = _bouncePoints![_bounceStep];
  final end = _bouncePoints![nextIndex];

  _ballAnimation = Tween<Offset>(
    begin: begin,
    end: end,
  ).animate(
    CurvedAnimation(
      parent: _ballController,
      curve: Curves.easeOut,
    ),
  );

  _ballController.forward(from: 0);
}

Offset _bezier2(Offset p0, Offset p1, Offset p2, double t) {
  final u = 1.0 - t;
  final x = u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx;
  final y = u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy;
  return Offset(x, y);
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
	_curveStart = _curveMid = _curveEnd = null;
    _swipePoints.clear();

  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);

        return Scaffold(
          body: GestureDetector(
            onPanStart: (d) => _onPanStart(d, size),
            onPanUpdate: (d) => _onPanUpdate(d, size),
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
					shirtColor: widget.shirtColor,
					playerName: widget.playerName,
					playerNumber: widget.playerNumber,
					
				  ),
				),
				// status text
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
						color:
							_statusText == 'GOAL!' ? Colors.yellow : Colors.white,
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
				// ?? electroboard with remaining shots
				Positioned(
				  top: 20,
				  right: 16,
				  child: SizedBox(
					width: 70,
					height: 40,
					child: CustomPaint(
					  painter: LedBoardPainter(value: _remainingShots),
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
  final Offset ballPos;      // 0..1
  final double keeperT;      // 0..1
  final double kickT;        // 0..1
  final Offset playerPos;    // 0..1
  final bool keeperHasBall;
  
  final Color shirtColor;
  final String playerName;
  final int playerNumber;

  FreeKickFieldPainter({
    required this.ballPos,
    required this.keeperT,
    required this.kickT,
    required this.playerPos,
    required this.keeperHasBall,
	required this.shirtColor,
    required this.playerName,
    required this.playerNumber,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSkyAndCrowd(canvas, size);
    _drawAds(canvas, size);
    _drawPitch(canvas, size);

    // Goal + net
    final goalRect = _drawGoalAndNet(canvas, size);

    // Keeper
    _drawKeeper(canvas, size, goalRect);

    // Wall player at fixed fraction (0.5, 0.63) – matches physics
    _drawWallPlayer(canvas, size);

    // Kicker (foreground)
    _drawKicker(canvas, size, playerPos, kickT);

    // Ball
    _drawBall(canvas, size, ballPos);
    _drawBallShadow(canvas, size, ballPos);
  }

  // ---------------------------------------------------------------------------
  // BACKGROUND: sky + crowd
  // ---------------------------------------------------------------------------

  void _drawSkyAndCrowd(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    // Sky
    final skyRect = Rect.fromLTWH(0, 0, w, h * 0.22);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF2F5FB8),
        Color(0xFF6795F2),
      ],
    ).createShader(skyRect);
    canvas.drawRect(skyRect, paint);

    // Crowd block
    final crowdTop = h * 0.07;
    final crowdHeight = h * 0.18;
    final crowdRect = Rect.fromLTWH(0, crowdTop, w, crowdHeight);

    paint.shader = null;
    paint.color = const Color(0xFF151824);
    canvas.drawRect(crowdRect, paint);

    // Dots / tiles to fake people
    final tileW = w / 26;
    final tileH = crowdHeight / 7;
    final colors = <Color>[
      const Color(0xFFF3D2A3),
      const Color(0xFFE8E8E8),
      const Color(0xFF2980B9),
      const Color(0xFF27AE60),
      const Color(0xFFE74C3C),
      const Color(0xFF95A5A6),
    ];

    final dotPaint = Paint();
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 26; c++) {
        dotPaint.color = colors[(r * 3 + c * 5) % colors.length];
        final x = c * tileW;
        final y = crowdTop + r * tileH;
        canvas.drawRect(
          Rect.fromLTWH(x + 1, y + 1, tileW - 2, tileH - 2),
          dotPaint,
        );
      }
    }

    // Light from top
    final overlay = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.25),
          Colors.transparent,
        ],
      ).createShader(crowdRect);
    canvas.drawRect(crowdRect, overlay);
  }

  // ---------------------------------------------------------------------------
  // ADS
  // ---------------------------------------------------------------------------

  void _drawAds(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final adsTop = h * 0.23;
    final adsHeight = h * 0.06;

    final baseRect = Rect.fromLTWH(0, adsTop, w, adsHeight);
    paint.color = const Color(0xFF1C1F2C);
    canvas.drawRect(baseRect, paint);

    final segments = 7;
    final segW = w / segments.toDouble();
    final adColors = <Color>[
      const Color(0xFFF4F4F4), // white
      const Color(0xFF1E90D7), // blue
      const Color(0xFFE9C417), // yellow
      const Color(0xFFCC1F2F), // red
      const Color(0xFF1E90D7),
      const Color(0xFFF4F4F4),
      const Color(0xFF333333),
    ];

    for (int i = 0; i < segments; i++) {
      paint.color = adColors[i % adColors.length];
      canvas.drawRect(
        Rect.fromLTWH(i * segW, adsTop, segW - 1, adsHeight),
        paint,
      );
    }

    // thin white trim on top
    paint
      ..color = Colors.white
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, adsTop),
      Offset(w, adsTop),
      paint,
    );
  }

  // ---------------------------------------------------------------------------
  // PITCH
  // ---------------------------------------------------------------------------

  void _drawPitch(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final pitchTop = h * 0.29;
    final pitchRect = Rect.fromLTWH(0, pitchTop, w, h - pitchTop);

    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF26A03B),
        Color(0xFF0B6A24),
      ],
    ).createShader(pitchRect);
    canvas.drawRect(pitchRect, paint);

    // Stripes with slight perspective
    final stripePaint = Paint()..color = const Color(0xFF0D7B2A);
    final stripes = 9;
    for (int i = 0; i < stripes; i++) {
      if (i.isOdd) {
        final tTop = i / stripes;
        final tBottom = (i + 1) / stripes;
        final yTop = pitchTop + (h - pitchTop) * tTop;
        final yBottom = pitchTop + (h - pitchTop) * tBottom;
        canvas.drawRect(
          Rect.fromLTRB(0, yTop, w, yBottom),
          stripePaint,
        );
      }
    }

    // Hint of halfway-ish line (angled)
    paint
      ..shader = null
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(0, h * 0.64),
      Offset(w, h * 0.60),
      paint,
    );
  }

  // ---------------------------------------------------------------------------
  // GOAL & NET
  // ---------------------------------------------------------------------------

  Rect _drawGoalAndNet(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    // Use similar fractions as physics in secondstage
    final goalWidth = w * 0.60;
    final goalHeight = h * 0.11;
    final goalLeft = (w - goalWidth) / 2;
    final goalTop = h * 0.19;
    final goalRect = Rect.fromLTWH(goalLeft, goalTop, goalWidth, goalHeight);

    // Posts & bar
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(goalRect, paint);

    // 2.5D net
    final depth = h * 0.045;
    final backTopLeft =
        Offset(goalLeft + w * 0.02, goalTop + depth * 0.3);
    final backTopRight =
        Offset(goalLeft + goalWidth - w * 0.02, goalTop + depth * 0.3);
    final backBottomLeft =
        Offset(goalLeft + w * 0.04, goalTop + goalHeight);
    final backBottomRight =
        Offset(goalLeft + goalWidth - w * 0.04, goalTop + goalHeight);

    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1;

    // side nets
    final leftSide = Path()
      ..moveTo(goalLeft, goalTop)
      ..lineTo(backTopLeft.dx, backTopLeft.dy)
      ..lineTo(backBottomLeft.dx, backBottomLeft.dy)
      ..lineTo(goalLeft, goalTop + goalHeight)
      ..close();
    canvas.drawPath(leftSide, netPaint);

    final rightSide = Path()
      ..moveTo(goalLeft + goalWidth, goalTop)
      ..lineTo(backTopRight.dx, backTopRight.dy)
      ..lineTo(backBottomRight.dx, backBottomRight.dy)
      ..lineTo(goalLeft + goalWidth, goalTop + goalHeight)
      ..close();
    canvas.drawPath(rightSide, netPaint);

    // vertical net lines
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
    // back horizontal
    for (int j = 1; j <= 4; j++) {
      final tj = j / 5;
      final y =
          backTopLeft.dy + (backBottomLeft.dy - backTopLeft.dy) * tj;
      canvas.drawLine(
        Offset(backTopLeft.dx, y),
        Offset(backTopRight.dx, y),
        netPaint,
      );
    }

    // goal line
    paint
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(goalLeft, goalTop + goalHeight),
      Offset(goalLeft + goalWidth, goalTop + goalHeight),
      paint,
    );

    return goalRect;
  }

  // ---------------------------------------------------------------------------
  // KEEPER
  // ---------------------------------------------------------------------------

  void _drawKeeper(Canvas canvas, Size size, Rect goalRect) {
    final h = size.height;
    final paint = Paint();

    final goalLeft = goalRect.left;
    final goalWidth = goalRect.width;
    final goalTop = goalRect.top;
    final goalHeight = goalRect.height;

    // Keeper horizontally in goal
    final minX = goalLeft + goalWidth * 0.18;
    final maxX = goalLeft + goalWidth * 0.82;
    final cx = minX + (maxX - minX) * keeperT;

    final feetY = goalTop + goalHeight * 0.95;
    final height = h * 0.17; // smaller than kicker
    final headR = height * 0.11;

    // head
    paint
      ..color = const Color(0xFFF4D0A1)
      ..style = PaintingStyle.fill;
    final headCenter =
        Offset(cx, feetY - height + headR * 1.0);
    canvas.drawCircle(headCenter, headR, paint);

    // hair
    paint.color = const Color(0xFF3C2A20);
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR),
      math.pi,
      math.pi,
      true,
      paint,
    );

    // jersey
	
    paint.color = const Color(0xFF3C2A20);
    final torsoW = height * 0.34;
    final torsoH = height * 0.45;
    final torsoRect = Rect.fromLTWH(
      cx - torsoW / 2,
      headCenter.dy + headR * 0.2,
      torsoW,
      torsoH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
      paint,
    );


    // arms
    paint
      ..color = const Color(0xFF3C2A20)
      ..strokeWidth = 4;
    final shoulderY = torsoRect.top + torsoH * 0.3;
    if (!keeperHasBall) {
      final span = torsoW * 1.8;
      canvas.drawLine(
        Offset(cx - span / 2, shoulderY),
        Offset(cx + span / 2, shoulderY),
        paint,
      );
    } else {
      final handsY = torsoRect.top + torsoH * 0.55;
      final leftShoulder = Offset(cx - torsoW * 0.8, shoulderY);
      final rightShoulder = Offset(cx + torsoW * 0.8, shoulderY);
      canvas.drawLine(leftShoulder, Offset(cx - 4, handsY), paint);
      canvas.drawLine(rightShoulder, Offset(cx + 4, handsY), paint);
    }

    // shorts
    paint.color = const Color(0xFF1E2A4C);
    final shortsH = height * 0.22;
    final shortsRect = Rect.fromLTWH(
      cx - torsoW / 2,
      torsoRect.bottom,
      torsoW,
      shortsH,
    );
    canvas.drawRect(shortsRect, paint);

  // --- LEGS (thicker) ---
  final legPaint = Paint()..color = Colors.redAccent.shade100;
  final hipY = shortsRect.bottom;
  final legLen = height * 0.42;
  final legW = torsoW * 0.18;

  final leftHip = Offset(cx - torsoW * 0.20, hipY);
  final rightHip = Offset(cx + torsoW * 0.20, hipY);
  final leftFoot = Offset(leftHip.dx, hipY + legLen);
  final rightFoot = Offset(rightHip.dx, hipY + legLen);

  final leftLegRect = Rect.fromLTRB(
    leftHip.dx - legW / 2,
    leftHip.dy,
    leftHip.dx + legW / 2,
    leftFoot.dy,
  );
  final rightLegRect = Rect.fromLTRB(
    rightHip.dx - legW / 2,
    rightHip.dy,
    rightHip.dx + legW / 2,
    rightFoot.dy,
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(leftLegRect, const Radius.circular(4)),
    legPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rightLegRect, const Radius.circular(4)),
    legPaint,
  );


    // boots
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

  // ---------------------------------------------------------------------------
  // WALL PLAYER
  // ---------------------------------------------------------------------------

void _drawWallPlayer(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;
  final paint = Paint();

  // Match physics: center at (0.5, 0.63)
  final cx = w * 0.5;
  final cy = h * 0.63;

  final height = h * 0.23;
  final headR = height * 0.11;

  // --- HEAD ---
  paint
    ..color = const Color(0xFFF4D0A1)
    ..style = PaintingStyle.fill;
  final headCenter = Offset(cx, cy - height * 0.7);
  canvas.drawCircle(headCenter, headR, paint);

  // hair (Beckham-ish: darker top + band)
  paint.color = const Color(0xFF3A2415);
  canvas.drawArc(
    Rect.fromCircle(center: headCenter, radius: headR),
    math.pi,
    math.pi,
    true,
    paint,
  );

  // hair band
  paint
    ..color = const Color(0xFFE6C85B)
    ..style = PaintingStyle.fill;
  canvas.drawRect(
    Rect.fromLTWH(
      headCenter.dx - headR,
      headCenter.dy - headR * 0.15,
      headR * 2,
      headR * 0.18,
    ),
    paint,
  );

  // facial details: eyes + brows + mouth
  final facePaint = Paint()..color = Colors.black87;
  final eyeOffsetX = headR * 0.45;
  final eyeOffsetY = headR * 0.10;

  // eyes
  canvas.drawCircle(
      Offset(headCenter.dx - eyeOffsetX, headCenter.dy - eyeOffsetY),
      headR * 0.09,
      facePaint);
  canvas.drawCircle(
      Offset(headCenter.dx + eyeOffsetX, headCenter.dy - eyeOffsetY),
      headR * 0.09,
      facePaint);

  // eyebrows
  facePaint.strokeWidth = headR * 0.08;
  canvas.drawLine(
    Offset(headCenter.dx - eyeOffsetX * 1.1,
        headCenter.dy - eyeOffsetY * 1.4),
    Offset(headCenter.dx - eyeOffsetX * 0.3,
        headCenter.dy - eyeOffsetY * 1.5),
    facePaint,
  );
  canvas.drawLine(
    Offset(headCenter.dx + eyeOffsetX * 0.3,
        headCenter.dy - eyeOffsetY * 1.5),
    Offset(headCenter.dx + eyeOffsetX * 1.1,
        headCenter.dy - eyeOffsetY * 1.4),
    facePaint,
  );

  // mouth (small line)
  facePaint.strokeWidth = headR * 0.06;
  canvas.drawLine(
    Offset(headCenter.dx - headR * 0.30, headCenter.dy + headR * 0.35),
    Offset(headCenter.dx + headR * 0.30, headCenter.dy + headR * 0.35),
    facePaint,
  );

  // --- TORSO (red jersey) ---
  paint.color = const Color(0xFFC0392B);
  final torsoW = height * 0.26;
  final torsoH = height * 0.50;
  final torsoRect = Rect.fromLTWH(
    cx - torsoW / 2,
    headCenter.dy + headR * 0.25,
    torsoW,
    torsoH,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
    paint,
  );

  // --- ARMS (Kaká-style, from shoulder to top of shorts) ---
  final armPaint = Paint()..color = const Color(0xFFF4D03F);
  final armW = torsoW * 0.18;

  // shoulders are just under the top of the jersey
  final shoulderY = torsoRect.top + torsoH * 0.05;

  // hands should end slightly above start of shorts
  final handY = torsoRect.bottom - torsoH * 0.05;

  final armH = handY - shoulderY;

  // left arm rectangle, starting at shoulder
  final leftArmRect = Rect.fromLTWH(
    torsoRect.left - armW * 0.9,   // attached to left edge
    shoulderY,
    armW,
    armH,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(leftArmRect, const Radius.circular(4)),
    armPaint,
  );

  // right arm rectangle, starting at shoulder
  final rightArmRect = Rect.fromLTWH(
    torsoRect.right,               // attached to right edge
    shoulderY,
    armW,
    armH,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rightArmRect, const Radius.circular(4)),
    armPaint,
  );

  // small darker cuffs at the end of sleeves (adds a bit of realism)
  final cuffPaint = Paint()..color = const Color(0xFFE0B400);
  final cuffH = armH * 0.12;
  canvas.drawRect(
    Rect.fromLTWH(leftArmRect.left, handY - cuffH, armW, cuffH),
    cuffPaint,
  );
  canvas.drawRect(
    Rect.fromLTWH(rightArmRect.left, handY - cuffH, armW, cuffH),
    cuffPaint,
  );


  // --- SHORTS (white) ---
  paint.color = const Color(0xFFE5E5E5);
  final shortsH = height * 0.22;
  final shortsRect = Rect.fromLTWH(
    cx - torsoW / 2,
    torsoRect.bottom,
    torsoW,
    shortsH,
  );
  canvas.drawRect(shortsRect, paint);

   // --- LEGS (thicker) ---
  final legPaint = Paint()..color = Colors.red;
  final hipY = shortsRect.bottom;
  final legLen = height * 0.42;
  final legW = torsoW * 0.24;

  final leftHip = Offset(cx - torsoW * 0.29, hipY);
  final rightHip = Offset(cx + torsoW * 0.29, hipY);
  final leftFoot = Offset(leftHip.dx, hipY + legLen);
  final rightFoot = Offset(rightHip.dx, hipY + legLen);

  final leftLegRect = Rect.fromLTRB(
    leftHip.dx - legW / 2,
    leftHip.dy,
    leftHip.dx + legW / 2,
    leftFoot.dy,
  );
  final rightLegRect = Rect.fromLTRB(
    rightHip.dx - legW / 2,
    rightHip.dy,
    rightHip.dx + legW / 2,
    rightFoot.dy,
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(leftLegRect, const Radius.circular(4)),
    legPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rightLegRect, const Radius.circular(4)),
    legPaint,
  );


  // --- BOOTS ---
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

  // ---------------------------------------------------------------------------
  // KICKER (foreground)
  // ---------------------------------------------------------------------------

void _drawKicker(
    Canvas canvas, Size size, Offset playerPosFrac, double kickT) {
  final w = size.width;
  final h = size.height;
  final paint = Paint();

  final px = playerPosFrac.dx * w;
  final py = playerPosFrac.dy * h;

  final height = h * 0.34;
  final headR = height * 0.11;

  // --- HEAD ---
  paint
    ..color = const Color(0xFFF4D0A1)
    ..style = PaintingStyle.fill;
  final headCenter = Offset(px, py - height + headR * 1.2);
  canvas.drawCircle(headCenter, headR, paint);

  // hair
  paint.color = const Color(0xFF2C1C11);
  canvas.drawArc(
    Rect.fromCircle(center: headCenter, radius: headR),
    math.pi,
    math.pi,
    true,
    paint,
  );

  // --- BODY (jersey) ---
	final jerseyColor = shirtColor;
    paint.color = jerseyColor;
  final torsoW = height * 0.34;
  final torsoH = height * 0.46;
  final torsoRect = Rect.fromLTWH(
    px - torsoW / 2,
    headCenter.dy + headR * 0.18,
    torsoW,
    torsoH,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(torsoRect, const Radius.circular(8)),
    paint,
  );
  
  	// Back name + number
final bool darkJersey = jerseyColor.computeLuminance() < 0.45;
final textColor = darkJersey ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.85);

// NAME
final namePainter = TextPainter(
  text: TextSpan(
    text: playerName.toUpperCase(),
    style: TextStyle(
      color: textColor,
      fontWeight: FontWeight.w800,
      fontSize: torsoH * 0.16,
      letterSpacing: 1.1,
    ),
  ),
  textAlign: TextAlign.center,
  textDirection: TextDirection.ltr,
  maxLines: 1,
  ellipsis: "…",
)..layout(maxWidth: torsoRect.width * 0.92);

namePainter.paint(
  canvas,
  Offset(torsoRect.center.dx - namePainter.width / 2, torsoRect.top + torsoRect.height * 0.18),
);

// NUMBER
final numberPainter = TextPainter(
  text: TextSpan(
    text: "$playerNumber",
    style: TextStyle(
      color: textColor,
      fontWeight: FontWeight.w900,
      fontSize: torsoH * 0.52,
      height: 0.95,
    ),
  ),
  textAlign: TextAlign.center,
  textDirection: TextDirection.ltr,
)..layout(maxWidth: torsoRect.width);

  // side shading
  final sidePaint = Paint()
    ..color = const Color(0xFFF7E47B)
    ..strokeWidth = 3;
  canvas.drawLine(
    Offset(torsoRect.left + 2, torsoRect.top + 4),
    Offset(torsoRect.left + 2, torsoRect.bottom - 4),
    sidePaint,
  );

  // --- ARMS (Kaká-style, from shoulder to top of shorts) ---
  final armPaint = Paint()..color = const Color(0xFFF4D03F);
  final armW = torsoW * 0.18;

  // shoulders are just under the top of the jersey
  final shoulderY = torsoRect.top + torsoH * 0.05;

  // hands should end slightly above start of shorts
  final handY = torsoRect.bottom - torsoH * 0.05;

  final armH = handY - shoulderY;

  // left arm rectangle, starting at shoulder
  final leftArmRect = Rect.fromLTWH(
    torsoRect.left - armW * 0.9,   // attached to left edge
    shoulderY,
    armW,
    armH,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(leftArmRect, const Radius.circular(4)),
    armPaint,
  );

  // right arm rectangle, starting at shoulder
  final rightArmRect = Rect.fromLTWH(
    torsoRect.right,               // attached to right edge
    shoulderY,
    armW,
    armH,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rightArmRect, const Radius.circular(4)),
    armPaint,
  );

  // small darker cuffs at the end of sleeves (adds a bit of realism)
  // small darker cuffs at the end of sleeves (adds a bit of realism)
  final cuffPaint = Paint()..color = const Color(0xFFE0B400);
  final cuffH = armH * 0.12;

  // cuffs
  final leftCuffRect =
      Rect.fromLTWH(leftArmRect.left, handY - cuffH, armW, cuffH);
  final rightCuffRect =
      Rect.fromLTWH(rightArmRect.left, handY - cuffH, armW, cuffH);

  canvas.drawRect(leftCuffRect, cuffPaint);
  canvas.drawRect(rightCuffRect, cuffPaint);

  // --- HANDS (skin, slightly below cuffs) ---
  final handPaint = Paint()..color = const Color(0xFFF4D0A1);
  final handR = armW * 0.35;

  final leftHandCenter = Offset(
    leftArmRect.left + armW / 2,
    handY + handR * 0.6,
  );
  final rightHandCenter = Offset(
    rightArmRect.left + armW / 2,
    handY + handR * 0.6,
  );

  canvas.drawCircle(leftHandCenter, handR, handPaint);
  canvas.drawCircle(rightHandCenter, handR, handPaint);



  // --- SHORTS ---
  paint.color = const Color(0xFF1F4E8C);
  final shortsH = height * 0.21;
  final shortsRect = Rect.fromLTWH(
    px - torsoW / 2,
    torsoRect.bottom,
    torsoW,
    shortsH,
  );
  canvas.drawRect(shortsRect, paint);

  // --- LEGS (thick socks instead of toothpicks) ---
  final sockPaint = Paint()..color = const Color(0xFFF7F7F7);
  final hipY = shortsRect.bottom;
  final legLen = height * 0.42;
  final legW = torsoW * 0.18;

  // support leg
  final leftHip = Offset(px - torsoW * 0.22, hipY);
  final leftFoot = Offset(leftHip.dx, hipY + legLen);
  final leftLegRect = Rect.fromLTRB(
    leftHip.dx - legW / 2,
    leftHip.dy,
    leftHip.dx + legW / 2,
    leftFoot.dy,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(leftLegRect, const Radius.circular(4)),
    sockPaint,
  );

  // kicking leg (animated)
  final rightHip = Offset(px + torsoW * 0.22, hipY);
  const startAngle = 1.6;
  const endAngle = 0.8;
  final eased = Curves.easeOut.transform(kickT.clamp(0.0, 1.0));
  final angle = startAngle + (endAngle - startAngle) * eased;
  final dx = legLen * math.cos(angle);
  final dy = legLen * math.sin(angle);
  final rightFoot = Offset(rightHip.dx + dx, rightHip.dy + dy);

  // approximate animated leg as a slanted rounded-rect between hip and foot
  final legVec = rightFoot - rightHip;
  final legDir = legVec / legVec.distance;
  final perp = Offset(-legDir.dy, legDir.dx); // 90° rotated
  final halfW = legW / 2;

  final p1 = rightHip + perp * halfW;
  final p2 = rightHip - perp * halfW;
  final p3 = rightFoot - perp * halfW;
  final p4 = rightFoot + perp * halfW;

  final path = Path()
    ..moveTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..lineTo(p3.dx, p3.dy)
    ..lineTo(p4.dx, p4.dy)
    ..close();
  canvas.drawPath(path, sockPaint);


  // --- BOOTS ---
  final bootsPaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 6;
  canvas.drawLine(
    leftFoot,
    Offset(leftFoot.dx - torsoW * 0.08, leftFoot.dy),
    bootsPaint,
  );
  canvas.drawLine(
    rightFoot,
    Offset(rightFoot.dx + torsoW * 0.10, rightFoot.dy),
    bootsPaint,
  );
}

  // ---------------------------------------------------------------------------
  // BALL
  // ---------------------------------------------------------------------------

  void _drawBall(Canvas canvas, Size size, Offset ballPosFrac) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final cx = ballPosFrac.dx * w;
    final cy = ballPosFrac.dy * h;
    final r = h * 0.026;

    // base
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // outline
    paint
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // panels
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.black87;
    canvas.drawCircle(Offset(cx, cy), r * 0.30, paint);

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
    final cy = ballPosFrac.dy * h + h * 0.01;

    final rx = h * 0.03;
    final ry = h * 0.011;

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
  bool shouldRepaint(covariant FreeKickFieldPainter old) {
    return old.ballPos != ballPos ||
        old.keeperT != keeperT ||
        old.kickT != kickT ||
        old.playerPos != playerPos ||
        old.keeperHasBall != keeperHasBall;
		old.shirtColor != shirtColor||
        old.playerName != playerName ||
        old.playerNumber != playerNumber;
		
  }
}

class LedBoardPainter extends CustomPainter {
  final int value; // 0–9

  LedBoardPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFF050608)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF333843)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);

    // 7-segment style coordinates
    final segOnPaint = Paint()
      ..color = const Color(0xFFFF0030)
      ..style = PaintingStyle.fill;

    final segOffPaint = Paint()
      ..color = const Color(0xFF550010)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final thickness = h * 0.16;
    final gap = thickness * 0.3;

    final top    = Rect.fromLTWH(gap, gap, w - 2 * gap, thickness);
    final middle = Rect.fromLTWH(gap, h / 2 - thickness / 2, w - 2 * gap, thickness);
    final bottom = Rect.fromLTWH(gap, h - thickness - gap, w - 2 * gap, thickness);

    final leftTop  = Rect.fromLTWH(gap, gap, thickness, h / 2 - gap);
    final leftBot  = Rect.fromLTWH(gap, h / 2, thickness, h / 2 - gap);
    final rightTop = Rect.fromLTWH(w - thickness - gap, gap, thickness, h / 2 - gap);
    final rightBot = Rect.fromLTWH(w - thickness - gap, h / 2, thickness, h / 2 - gap);

    // segments: 0=top, 1=top-right, 2=bottom-right, 3=bottom, 4=bottom-left, 5=top-left, 6=middle
    const digitToSegments = <int, List<int>>{
      0: [0, 1, 2, 3, 4, 5],
      1: [1, 2],
      2: [0, 1, 6, 4, 3],
      3: [0, 1, 6, 2, 3],
      4: [5, 6, 1, 2],
      5: [0, 5, 6, 2, 3],
      6: [0, 5, 6, 2, 3, 4],
      7: [0, 1, 2],
      8: [0, 1, 2, 3, 4, 5, 6],
      9: [0, 1, 2, 3, 5, 6],
    };

    final v = value.clamp(0, 9);
    final active = digitToSegments[v] ?? [];

    void drawSeg(int index, Rect r) {
      final isOn = active.contains(index);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        isOn ? segOnPaint : segOffPaint,
      );
    }

    drawSeg(0, top);
    drawSeg(1, rightTop);
    drawSeg(2, rightBot);
    drawSeg(3, bottom);
    drawSeg(4, leftBot);
    drawSeg(5, leftTop);
    drawSeg(6, middle);
  }

  @override
  bool shouldRepaint(covariant LedBoardPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
