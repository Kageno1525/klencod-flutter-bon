import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Neon Dodge',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // إعدادات اللعبة
  double playerX = 0.5; // موقع اللاعب (من 0 لـ 1)
  double playerSize = 0.1; // حجم اللاعب
  List<Rect> obstacles = []; // المربعات النازلة
  double score = 0;
  bool isGameOver = false;
  Random random = Random();
  double speed = 0.5; // سرعة النزول

  @override
  void initState() {
    super.initState();
    // محرك الحركة (60 فريم في الثانية)
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_updateGame)
      ..repeat();
  }

  void _updateGame() {
    if (isGameOver) return;

    setState(() {
      score += 0.1; // زيادة النقاط
      
      // زيادة السرعة بالتدريج
      if (score % 100 == 0 && speed < 2.0) speed += 0.05;

      // توليد عوائق جديدة بشكل عشوائي
      if (random.nextDouble() < 0.05) {
        obstacles.add(Rect.fromLTWH(random.nextDouble() * 0.9, -0.1, 0.1, 0.1));
      }

      // تحريك العوائق لتحت
      for (int i = 0; i < obstacles.length; i++) {
        obstacles[i] = Rect.fromLTWH(obstacles[i].left, obstacles[i].top + (speed * 0.01), obstacles[i].width, obstacles[i].height);
      }

      // إزالة العوائق اللي خرجت بره الشاشة
      obstacles.removeWhere((obs) => obs.top > 1.1);

      // اكتشاف التصادم (Collision Detection)
      Rect playerRect = Rect.fromLTWH(playerX - (playerSize / 2), 0.85, playerSize, playerSize);
      for (var obs in obstacles) {
        if (playerRect.overlaps(obs)) {
          isGameOver = true;
          _controller.stop();
          break;
        }
      }
    });
  }

  void _resetGame() {
    setState(() {
      playerX = 0.5;
      obstacles.clear();
      score = 0;
      speed = 0.5;
      isGameOver = false;
      _controller.repeat();
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
        onHorizontalDragUpdate: (details) {
          if (isGameOver) return;
          setState(() {
            // تحريك اللاعب بناءً على السحب
            playerX += details.delta.dx / MediaQuery.of(context).size.width;
            // تثبيت اللاعب جوه الشاشة
            playerX = playerX.clamp(playerSize / 2, 1.0 - (playerSize / 2));
          });
        },
        child: Stack(
          children: [
            // رسم اللعبة
            CustomPaint(
              size: Size.infinite,
              painter: GamePainter(
                playerX: playerX,
                playerSize: playerSize,
                obstacles: obstacles,
              ),
            ),
            
            // النقاط
            Positioned(
              top: 50,
              left: 20,
              child: Text(
                "SCORE: ${score.toInt()}",
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // شاشة النهاية
            if (isGameOver)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "GAME OVER",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                          shadows: [Shadow(color: Colors.red, blurRadius: 20)],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Score: ${score.toInt()}",
                        style: const TextStyle(color: Colors.white, fontSize: 24),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        ),
                        onPressed: _resetGame,
                        child: const Text("PLAY AGAIN", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

// كلاس مسؤول عن رسم الأشكال (النيون)
class GamePainter extends CustomPainter {
  final double playerX;
  final double playerSize;
  final List<Rect> obstacles;

  GamePainter({required this.playerX, required this.playerSize, required this.obstacles});

  @override
  void paint(Canvas canvas, Size size) {
    // رسم الخلفية السودة
    Paint bgPaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // رسم خطوط الشبكة (Grid) في الخلفية عشان شكل الـ Cyberpunk
    Paint gridPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.1)
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // رسم اللاعب (مربع نيون أزرق)
    Paint playerPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    
    // تأثير التوهج (Glow) للاعب
    canvas.drawRect(
      Rect.fromLTWH(
        (playerX * size.width) - (playerSize * size.width / 2),
        size.height * 0.85,
        playerSize * size.width,
        playerSize * size.width,
      ),
      Paint()..color = Colors.cyanAccent.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    
    canvas.drawRect(
      Rect.fromLTWH(
        (playerX * size.width) - (playerSize * size.width / 2),
        size.height * 0.85,
        playerSize * size.width,
        playerSize * size.width,
      ),
      playerPaint,
    );

    // رسم العوائق (مربعات نيون حمراء)
    Paint obsPaint = Paint()..color = Colors.redAccent;
    for (var obs in obstacles) {
      Rect rect = Rect.fromLTWH(
        obs.left * size.width,
        obs.top * size.height,
        obs.width * size.width,
        obs.height * size.height,
      );
      
      // تأثير التوهج للعوائق
      canvas.drawRect(
        rect,
        Paint()..color = Colors.redAccent.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawRect(rect, obsPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}