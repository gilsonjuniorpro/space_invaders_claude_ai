import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SpaceInvadersApp());
}

class SpaceInvadersApp extends StatelessWidget {
  const SpaceInvadersApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Space Invaders',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  // Game objects
  late Player player;
  List<Enemy> enemies = [];
  List<Bullet> bullets = [];
  List<Explosion> explosions = [];

  // Game state
  bool gameRunning = false;
  int score = 0;
  int lives = 3;
  int level = 1;

  // Game dimensions
  late double screenWidth;
  late double screenHeight;

  // Game timing
  late Timer gameTimer;
  int enemyMovementDirection = 1;
  int tickCounter = 0;
  int autoFireCounter = 0;

  // Enemy formation parameters
  final int enemyRows = 4;
  final int enemyCols = 8;
  final double enemyHorizontalSpacing = 50.0;
  final double enemyVerticalSpacing = 40.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      screenWidth = MediaQuery.of(context).size.width;
      screenHeight = MediaQuery.of(context).size.height;
      startGame();
    });
  }

  void startGame() {
    setState(() {
      // Reset game state
      player = Player(screenWidth / 2, screenHeight * 0.85, 50, 30);
      enemies.clear();
      bullets.clear();
      explosions.clear();
      score = 0;
      lives = 3;
      level = 1;
      autoFireCounter = 0;

      // Create enemy formation
      createEnemies();

      // Start game loop
      gameRunning = true;
      gameTimer = Timer.periodic(const Duration(milliseconds: 16), gameLoop);
    });
  }

  void createEnemies() {
    double startX = (screenWidth - (enemyCols * enemyHorizontalSpacing)) / 2 + 25;
    double startY = 50.0;

    for (int row = 0; row < enemyRows; row++) {
      for (int col = 0; col < enemyCols; col++) {
        double x = startX + col * enemyHorizontalSpacing;
        double y = startY + row * enemyVerticalSpacing;
        int pointValue = (enemyRows - row) * 10; // Higher rows worth more points
        enemies.add(Enemy(x, y, 40, 30, pointValue));
      }
    }
  }

  void firePlayerBullet() {
    bullets.add(Bullet(
      player.x + player.width / 2 - 1.5,
      player.y,
      3,
      10,
      true,
    ));
  }

  void gameLoop(Timer timer) {
    if (!gameRunning) return;

    tickCounter++;
    autoFireCounter++;

    // Auto-fire bullet every second (approximately 60 ticks at 16ms per tick)
    if (autoFireCounter >= 20) {
      firePlayerBullet();
      autoFireCounter = 0;
    }

    // Update player
    if (player.movingLeft && player.x > 0) {
      player.x -= 5;
    }
    if (player.movingRight && player.x < screenWidth - player.width) {
      player.x += 5;
    }

    // Update bullets
    for (int i = bullets.length - 1; i >= 0; i--) {
      bullets[i].update();

      // Remove bullets that go off screen
      if (bullets[i].y < 0 || bullets[i].y > screenHeight) {
        bullets.removeAt(i);
        continue;
      }

      // Check for collisions between bullets and enemies or player
      if (bullets[i].fromPlayer) {
        for (int j = enemies.length - 1; j >= 0; j--) {
          if (checkCollision(bullets[i], enemies[j])) {
            // Add explosion
            explosions.add(Explosion(
                enemies[j].x + enemies[j].width / 2,
                enemies[j].y + enemies[j].height / 2,
                30,
                30
            ));

            // Update score
            score += enemies[j].pointValue;

            // Remove enemy and bullet
            enemies.removeAt(j);
            bullets.removeAt(i);
            break;
          }
        }
      } else {
        // Enemy bullets hitting player
        if (checkCollision(bullets[i], player)) {
          explosions.add(Explosion(
              player.x + player.width / 2,
              player.y + player.height / 2,
              40,
              40
          ));
          bullets.removeAt(i);
          lives--;

          if (lives <= 0) {
            endGame();
          } else {
            // Reset player position
            player.x = screenWidth / 2;
          }
        }
      }
    }

    // Update explosions and remove completed ones
    for (int i = explosions.length - 1; i >= 0; i--) {
      explosions[i].update();
      if (explosions[i].frameCount >= 20) {
        explosions.removeAt(i);
      }
    }

    // Move enemies
    if (tickCounter % (20 - min(level * 2, 15)) == 0) {
      bool shouldChangeDirection = false;

      for (var enemy in enemies) {
        enemy.x += 5 * enemyMovementDirection;

        // Check if any enemy hits the edge
        if ((enemy.x <= 0 && enemyMovementDirection < 0) ||
            (enemy.x + enemy.width >= screenWidth && enemyMovementDirection > 0)) {
          shouldChangeDirection = true;
        }
      }

      if (shouldChangeDirection) {
        enemyMovementDirection *= -1;
        for (var enemy in enemies) {
          enemy.y += 10; // Move down when hitting edge
        }
      }
    }

    // Enemy shooting
    if (enemies.isNotEmpty && tickCounter % 60 == 0) {
      // Randomly select enemies to shoot
      int shootingEnemies = min(level, 3);
      for (int i = 0; i < shootingEnemies; i++) {
        if (enemies.isEmpty) break;

        int randomIndex = Random().nextInt(enemies.length);
        Enemy shooter = enemies[randomIndex];

        bullets.add(Bullet(
          shooter.x + shooter.width / 2,
          shooter.y + shooter.height,
          3,
          10,
          false,
        ));
      }
    }

    // Check if player won the level
    if (enemies.isEmpty) {
      level++;
      createEnemies();
    }

    // Check if enemies reached the bottom
    for (var enemy in enemies) {
      if (enemy.y + enemy.height > player.y) {
        endGame();
        break;
      }
    }

    setState(() {});
  }

  bool checkCollision(GameObject a, GameObject b) {
    return a.x < b.x + b.width &&
        a.x + a.width > b.x &&
        a.y < b.y + b.height &&
        a.y + a.height > b.y;
  }

  void endGame() {
    gameRunning = false;
    gameTimer.cancel();
  }

  @override
  void dispose() {
    if (gameTimer.isActive) {
      gameTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (!gameRunning) {
                startGame();
              }
            },
            child: Stack(
              children: [
                // Draw player
                Positioned(
                  left: player.x,
                  top: player.y,
                  child: Container(
                    width: player.width,
                    height: player.height,
                    color: Colors.green,
                    child: const Center(
                      child: Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Draw enemies
                ...enemies.map((enemy) => Positioned(
                  left: enemy.x,
                  top: enemy.y,
                  child: Container(
                    width: enemy.width,
                    height: enemy.height,
                    color: Colors.red,
                    child: const Center(
                      child: Text(
                        '👾',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                )),

                // Draw bullets
                ...bullets.map((bullet) => Positioned(
                  left: bullet.x,
                  top: bullet.y,
                  child: Container(
                    width: bullet.width,
                    height: bullet.height,
                    color: bullet.fromPlayer ? Colors.green : Colors.red,
                  ),
                )),

                // Draw explosions
                ...explosions.map((explosion) => Positioned(
                  left: explosion.x - explosion.width / 2,
                  top: explosion.y - explosion.height / 2,
                  child: Opacity(
                    opacity: 1 - (explosion.frameCount / 20),
                    child: Container(
                      width: explosion.width,
                      height: explosion.height,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                )),

                // Game UI
                Positioned(
                  top: 10,
                  left: 10,
                  child: Text(
                    'Score: $score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Text(
                    'Lives: $lives Level: $level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),

                // Game over screen
                if (!gameRunning)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Game Over',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.redAccent.withOpacity(0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Final Score: $score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'Play Again',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Control buttons (positioned at the bottom of the screen)
          if (gameRunning)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Left button - using GestureDetector instead of ElevatedButton for better control
                  GestureDetector(
                    onTapDown: (_) {
                      setState(() {
                        player.movingLeft = true;
                        player.movingRight = false;
                      });
                    },
                    onTapUp: (_) {
                      setState(() {
                        player.movingLeft = false;
                      });
                    },
                    onTapCancel: () {
                      setState(() {
                        player.movingLeft = false;
                      });
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),

                  // Right button - using GestureDetector instead of ElevatedButton
                  GestureDetector(
                    onTapDown: (_) {
                      setState(() {
                        player.movingRight = true;
                        player.movingLeft = false;
                      });
                    },
                    onTapUp: (_) {
                      setState(() {
                        player.movingRight = false;
                      });
                    },
                    onTapCancel: () {
                      setState(() {
                        player.movingRight = false;
                      });
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Base class for game objects
class GameObject {
  double x;
  double y;
  double width;
  double height;

  GameObject(this.x, this.y, this.width, this.height);
}

class Player extends GameObject {
  bool movingLeft = false;
  bool movingRight = false;

  Player(double x, double y, double width, double height)
      : super(x, y, width, height);
}

class Enemy extends GameObject {
  final int pointValue;

  Enemy(double x, double y, double width, double height, this.pointValue)
      : super(x, y, width, height);
}

class Bullet extends GameObject {
  final bool fromPlayer;
  final double speed = 8.0;

  Bullet(double x, double y, double width, double height, this.fromPlayer)
      : super(x, y, width, height);

  void update() {
    if (fromPlayer) {
      y -= speed;
    } else {
      y += speed / 2;
    }
  }
}

class Explosion extends GameObject {
  int frameCount = 0;

  Explosion(double x, double y, double width, double height)
      : super(x, y, width, height);

  void update() {
    frameCount++;
  }
}