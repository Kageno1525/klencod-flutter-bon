import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Neon Orbit',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

// ==========================================
// 1. إعدادات اللعبة والعناصر
// ==========================================

class OrbitRing {
  double x;
  double y;
  double radius;
  double gapAngle; // زاوية الفراغ (بالبريان)
  double gapSize; // حجم الفراغ (بالبريان)
  double rotationSpeed;
  double currentRotation;
  Color color;

  OrbitRing({
    required this.x,
    required this.y,
    required this.radius,
    required this.gapAngle,
    required this.gapSize,
    required this.rotationSpeed,
    required this.color,
  }) : currentRotation = 0;
}

class Particle {
  double x, y, vx, vy, life;
  Color color;
  Particle({required this.x, required this.y, required this.vx, required this.vy, required this.color, this.life = 1.0});
}

// ==========================================
// 2. شاشة اللعبة
// ==========================================

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // إعدادات اللاعب
  double playerX = 0.2; // موقع اللاعب ثابت على الشمال
  double playerY = 0.5;
  double playerVelocity = 0;
  final double gravity = 0.0015; // الجاذبية
  final double jumpForce = -0.012; // قوة الطيران
  final double playerRadius = 0.03; // حجم اللاعب (نسبة من الشاشة)

  // إعدادات العالم
  List<OrbitRing> rings = [];
  List<Particle> particles = [];
  double score = 0;
  bool isGameOver = false;
  bool isGameStarted = false;
  Random random = Random();
  
  // شاشة الرجة (Screen Shake)
  double shakeOffsetX = 0;
  double shakeOffsetY = 0;
  int shakeTimer = 0;

  @override
  void initState() {
    super.initState();
    // محرك اللعبة 60 فريم في الثانية
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_update)
      ..repeat();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      playerY = 0.5;
      playerVelocity = 0;
      rings.clear();
      particles.clear();
      score = 0;
      isGameOver = false;
      isGameStarted = false;
      shakeTimer = 0;
      _spawnRing(1.5); // أول دايرة
    });
  }

  void _spawnRing(double startX) {
    rings.add(OrbitRing(
      x: startX,
      y: 0.3 + random.nextDouble() * 0.4, // تظهر في مكان عشوائي في النص
      radius: 0.2,
      gapAngle: random.nextDouble() * pi * 2, // مكان الفراغ عشوائي
      gapSize: pi / 2.5, // حجم الفراغ (حوالي 72 درجة)
      rotationSpeed: (random.nextDouble() - 0.5) * 0.03, // سرعة الدوران
      color: HSLColor.fromAHSL(1.0, random.nextDouble() * 360, 1.0, 0.6).toColor(),
    ));
  }

  void _jump() {
    if (isGameOver) return;
    if (!isGameStarted) {
      isGameStarted = true;
    }
    // تطبيق قوة الطيران
    playerVelocity = jumpForce;
  }

  void _update() {
    if (isGameOver || !isGameStarted) return;

    setState(() {
      // 1. تحديث فيزياء اللاعب
      playerVelocity += gravity;
      // تحديد أقصى سرعة للسقوط عشان ميبقاش سريع أوي
      if (playerVelocity > 0.02) playerVelocity = 0.02; 
      playerY += playerVelocity;

      // حدود الشاشة (لو خبط فوق أو تحت يخسر)
      if (playerY - playerRadius < 0 || playerY + playerRadius > 1.0) {
        _gameOver();
        return;
      }

      // 2. تحديث الدواير
      for (int i = rings.length - 1; i >= 0; i--) {
        var ring = rings[i];
        ring.x -= 0.005; // سرعة تحرك الدواير للشمال
        ring.currentRotation += ring.rotationSpeed;

        // خروج الدايرة من الشاشة
        if (ring.x < -0.5) {
          rings.removeAt(i);
          score++;
          // توليد دايرة جديدة
          _spawnRing(1.2 + random.nextDouble() * 0.5);
          continue;
        }

        // 3. فحص التصادم (Collision Detection) - الثغرة اللي كنا خايفين منها
        double dx = playerX - ring.x;
        double dy = playerY - ring.y;
        double distance = sqrt(dx * dx + dy * dy);

        // لو اللاعب قريب من حيطة الدايرة
        if ((distance > ring.radius - 0.02) && (distance < ring.radius + 0.02)) {
          // نحسب زاوية اللاعب بالنسبة لمركز الدايرة
          double angle = atan2(dy, dx);
          // نحول الزاوية لـ (0 لـ 2 باي) عشان نسهل الحساب
          if (angle < 0) angle += 2 * pi;
          
          // نجيب مكان الفراغ الحالي بعد الدوران
          double currentGap = (ring.gapAngle + ring.currentRotation) % (2 * pi);
          double gapStart = currentGap - (ring.gapSize / 2);
          double gapEnd = currentGap + (ring.gapSize / 2);

          // التعامل مع الالتفاف حول 2 باي (عشان الزوايا)
          bool inGap = false;
          if (gapStart < 0) {
            inGap = (angle > gapStart + 2 * pi || angle < gapEnd);
          } else if (gapEnd > 2 * pi) {
            inGap = (angle > gapStart || angle < gapEnd - 2 * pi);
          } else {
            inGap = (angle > gapStart && angle < gapEnd);
          }

          // لو مش في الفراغ = تصادم
          if (!inGap) {
            _gameOver();
            return;
          }
        }
      }

      // 4. تحديث الشظايا (Particles)
      for (int i = particles.length - 1; i >= 0; i--) {
        var p = particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.life -= 0.05;
        if (p.life <= 0) particles.removeAt(i);
      }

      // 5. تحديث الرجة
      if (shakeTimer > 0) {
        shakeOffsetX = (random.nextDouble() - 0.5) * 0.02;
        shakeOffsetY = (random.nextDouble() - 0.5) * 0.02;
        shakeTimer--;
      } else {
        shakeOffsetX = 0;
        shakeOffsetY = 0;
      }
    });
  }

  void _gameOver() {
    setState(() {
      isGameOver = true;
      shakeTimer = 20; // رجة قوية لمدة قصيرة
      // توليد شظايا انفجار
      for (int i = 0; i < 30; i++) {
        particles.add(Particle(
          x: playerX,
          y: playerY,
          vx: (random.nextDouble() - 0.5) * 0.05,
          vy: (random.nextDouble() - 0.5) * 0.05,
          color: Colors.cyanAccent,
        ));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTapDown: (_) => _jump(), // أي دوسة في الشاشة تخلي اللاعب يطير
        child: ClipRect(
          child: CustomPaint(
            size: Size.infinite,
            painter: GamePainter(
              playerX: playerX,
              playerY: playerY,
              playerRadius: playerRadius,
              rings: rings,
              particles: particles,
              score: score,
              isGameStarted: isGameStarted,
              isGameOver: isGameOver,
              shakeX: shakeOffsetX,
              shakeY: shakeOffsetY,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. محرك الرسم (الشكل الجامد)
// ==========================================

class GamePainter extends CustomPainter {
  final double playerX, playerY, playerRadius, shakeX, shakeY;
  final List<OrbitRing> rings;
  final List<Particle> particles;
  final double score;
  final bool isGameStarted, isGameOver;

  GamePainter({
    required this.playerX,
    required this.playerY,
    required this.playerRadius,
    required this.rings,
    required this.particles,
    required this.score,
    required this.isGameStarted,
    required this.isGameOver,
    required this.shakeX,
    required this.shakeY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // تطبيق الرجة (Screen Shake)
    canvas.translate(shakeX * size.width, shakeY * size.height);

    // 1. رسم الخلفية (شبكة نيون خفيفة)
    Paint bgPaint = Paint()..color = const Color(0xFF050505); // أسود غامق
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    Paint gridPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.05)
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // 2. رسم الدواير
    for (var ring in rings) {
      double cx = ring.x * size.width;
      double cy = ring.y * size.height;
      double r = ring.radius * size.width;
      
      Paint ringPaint = Paint()
        ..color = ring.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0
        ..strokeCap = StrokeCap.round;

      // تأثير التوهج (Glow)
      Paint glowPaint = Paint()
        ..color = ring.color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      // حساب بداية ونهاية القوس (عشان نرسم الدايرة ما عدا الفراغ)
      double startAngle = ring.gapAngle + ring.currentRotation + (ring.gapSize / 2);
      double sweepAngle = (2 * pi) - ring.gapSize;

      // رسم القوس
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), startAngle, sweepAngle, false, glowPaint);
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), startAngle, sweepAngle, false, ringPaint);
    }

    // 3. رسم اللاعب (دايرة نيون)
    if (!isGameOver) {
      double px = playerX * size.width;
      double py = playerY * size.height;
      double pr = playerRadius * size.width;

      // هالة اللاعب
      Paint playerGlow = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(px, py), pr, playerGlow);

      // جسم اللاعب
      Paint playerPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(px, py), pr * 0.8, playerPaint);
    }

    // 4. رسم الشظايا (Particles)
    for (var p in particles) {
      Paint pPaint = Paint()
        ..color = p.color.withOpacity(p.life)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), 4 * p.life, pPaint);
    }

    // 5. النصوص (النقاط وبداية اللعبة)
    _drawText(canvas, size, "SCORE: ${score.toInt()}", Offset(size.width / 2, 60), Colors.cyanAccent, 30, TextAlign.center);

    if (!isGameStarted) {
      _drawText(canvas, size, "TAP TO FLY", Offset(size.width / 2, size.height / 2), Colors.white, 40, TextAlign.center);
      _drawText(canvas, size, "Hold to go up, release to fall", Offset(size.width / 2, size.height / 2 + 50), Colors.grey, 18, TextAlign.center);
    }

    if (isGameOver) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black.withOpacity(0.7));
      _drawText(canvas, size, "GAME OVER", Offset(size.width / 2, size.height / 2 - 50), Colors.redAccent, 50, TextAlign.center);
      _drawText(canvas, size, "Score: ${score.toInt()}", Offset(size.width / 2, size.height / 2 + 20), Colors.white, 30, TextAlign.center);
      _drawText(canvas, size, "Tap to Restart", Offset(size.width / 2, size.height / 2 + 100), Colors.cyanAccent, 24, TextAlign.center);
    }
  }

  void _drawText(Canvas canvas, Size size, String text, Offset offset, Color color, double fontSize, TextAlign align) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        shadows: [Shadow(color: color, blurRadius: 10)],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(minWidth: 0, maxWidth: size.width);
    // تعديل الإحداثيات عشان النص يتوسّط
    double dx = offset.dx - textPainter.width / 2;
    double dy = offset.dy - textPainter.height / 2;
    textPainter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}