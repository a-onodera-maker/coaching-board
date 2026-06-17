import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const WheelchairTacticsApp());
}

class WheelchairTacticsApp extends StatelessWidget {
  const WheelchairTacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '車椅子バスケ 作戦ボード',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const TacticsBoardScreen(),
    );
  }
}

class BoardPiece {
  final String id;
  final String label;
  final Color color;
  final bool isBall;
  final String imagePath;
  Offset position;
  double angle;

  BoardPiece({
    required this.id,
    required this.label,
    required this.color,
    this.isBall = false,
    required this.imagePath,
    required this.position,
    this.angle = 0.0,
  });

  BoardPiece clone() {
    return BoardPiece(
      id: id,
      label: label,
      color: color,
      isBall: isBall,
      imagePath: imagePath,
      position: Offset(position.dx, position.dy),
      angle: angle,
    );
  }
}

class TacticsBoardScreen extends StatefulWidget {
  const TacticsBoardScreen({super.key});

  @override
  State<TacticsBoardScreen> createState() => _TacticsBoardScreenState();
}

class _TacticsBoardScreenState extends State<TacticsBoardScreen> {
  List<BoardPiece> pieces = [];
  final Map<int, List<BoardPiece>> history = {};
  
  int currentPhase = 1;
  bool isRecording = false;
  bool isPlaying = false;
  bool isInitialPositionSaved = false;

  int animationSpeedMs = 1500;
  double _baseAngle = 0.0;
  
  bool _isLayoutCalculated = false;

  @override
  void initState() {
    super.initState();
    _setupDummyPositions();
  }

  void _setupDummyPositions() {
    pieces.clear();
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(id: 'white_$i', label: '${i + 1}', color: Colors.white, imagePath: 'assets/wheelchair_white.png', position: Offset.zero));
    }
    pieces.add(BoardPiece(id: 'ball', label: '🏀', color: Colors.orange, isBall: true, imagePath: '', position: Offset.zero));
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(id: 'black_$i', label: '${i + 1}', color: Colors.black, imagePath: 'assets/wheelchair_black.png', position: Offset.zero));
    }
  }

  void _arrangePiecesToFitScreen(double courtWidth) {
    final pieceSize = courtWidth / 15;
    final totalAvailableWidth = courtWidth - pieceSize;
    final spacing = totalAvailableWidth / 10;

    for (int i = 0; i < 5; i++) {
      pieces[i].position = Offset(i * spacing, 10.0);
      pieces[i].angle = 0.0;
    }
    pieces[5].position = Offset(5 * spacing + (pieceSize * 0.25), 10.0 + (pieceSize * 0.25));
    pieces[5].angle = 0.0;
    for (int i = 0; i < 5; i++) {
      pieces[6 + i].position = Offset((6 + i) * spacing, 10.0);
      pieces[6 + i].angle = 0.0;
    }
  }

  void _resetToDefaultPositions(double courtWidth) {
    setState(() {
      history.clear();
      currentPhase = 1;
      isRecording = false;
      isPlaying = false;
      isInitialPositionSaved = false;
      _arrangePiecesToFitScreen(courtWidth);
    });
  }

  void _clearAllDataAndReset(double courtWidth) {
    setState(() {
      _resetToDefaultPositions(courtWidth);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ 全ての保存データを削除し、初期画面にリセットしました')),
      );
    });
  }

  void _toggleRecording() {
    setState(() {
      if (isRecording) {
        history[currentPhase] = pieces.map((p) => p.clone()).toList();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('フェーズ $currentPhase の動きを記憶しました')),
        );
        isRecording = false;
      } else {
        if (currentPhase == 1 && !isInitialPositionSaved) {
          history[0] = pieces.map((p) => p.clone()).toList();
          isInitialPositionSaved = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚽️ 最初のスタート配置（初期位置）を固定しました')),
          );
        }
        isRecording = true;
      }
    });
  }

  void _playSimulation() async {
    if (!isInitialPositionSaved || history.isEmpty) return;
    
    setState(() => isPlaying = true);

    if (history.containsKey(0)) {
      setState(() {
        pieces = history[0]!.map((p) => p.clone()).toList();
      });
      await Future.delayed(Duration(milliseconds: animationSpeedMs + 200));
    }

    for (int phase = 1; phase <= 5; phase++) {
      if (history.containsKey(phase)) {
        if (!mounted) return;
        setState(() {
          currentPhase = phase;
          pieces = history[phase]!.map((p) => p.clone()).toList();
        });
        await Future.delayed(Duration(milliseconds: animationSpeedMs + 500));
      }
    }

    if (!mounted) return;
    setState(() => isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wheelchair Basketball Tactics Board',
        style: TextStyle(fontSize: 20,
        fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, mainConstraints) {
            final availableHeight = mainConstraints.maxHeight - 60; 
            
            double courtWidth = mainConstraints.maxWidth - 24; 
            double courtHeight = courtWidth * (14 / 15);

            if (courtHeight > availableHeight) {
              courtHeight = availableHeight;
              courtWidth = courtHeight * (15 / 14);
            }

            if (!_isLayoutCalculated) {
              _arrangePiecesToFitScreen(courtWidth);
              _isLayoutCalculated = true;
            }

            final pieceSize = courtWidth / 15;

            return Column(
              children: [
                // 1. 上部：コントローラーエリア
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.black26,
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: [
                      Wrap(
                        spacing: 4.0,
                        children: [
                          for (int i = 1; i <= 5; i++)
                            SizedBox(
                              width: 42,
                              height: 36, // 👈 縦伸びを絶対に防ぐ高さ固定
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: currentPhase == i ? Colors.orange : Colors.grey[700],
                                  foregroundColor: Colors.white,
                                  // 👈 ボタンの形を四角（少し丸角）に固定して縦長化を強制阻止
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                onPressed: isPlaying ? null : () {
                                  setState(() {
                                    currentPhase = i;
                                    if (history.containsKey(i)) {
                                      pieces = history[i]!.map((p) => p.clone()).toList();
                                    }
                                  });
                                },
                                child: Text('$i', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('作戦を保存しました')),
                          );
                        },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('保存'),
                      ),
                      ElevatedButton.icon(
                        onPressed: isPlaying ? null : _toggleRecording,
                        icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record, size: 18),
                        label: Text(isRecording ? 'ストップ' : 'フェーズ$currentPhase 記録'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRecording ? Colors.red : Colors.blue,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: isRecording || !isInitialPositionSaved ? null : _playSimulation,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('再生'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                        onPressed: isPlaying ? null : () => _clearAllDataAndReset(courtWidth),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('クリア'),
                      ),
                    ],
                  ),
                ),

                // 2. メインエリア：ハーフコートと駒
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        width: courtWidth,
                        height: courtHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          clipBehavior: Clip.hardEdge, 
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/court.png',
                                  fit: BoxFit.contain, 
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFF1E3A1E),
                                      child: const Center(
                                        child: Text('ハーフコート画像が見つかりません', style: TextStyle(color: Colors.grey)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            ...pieces.map((piece) {
                              final currentDuration = isPlaying 
                                  ? Duration(milliseconds: animationSpeedMs) 
                                  : Duration.zero;

                              return AnimatedPositioned(
                                duration: currentDuration,
                                curve: Curves.easeInOut,
                                left: piece.position.dx,
                                top: piece.position.dy,
                                child: GestureDetector(
                                  onScaleStart: (details) {
                                    _baseAngle = piece.angle;
                                  },
                                  onScaleUpdate: (details) {
                                    if (isPlaying) return;
                                    setState(() {
                                      if (details.pointerCount > 1) {
                                        piece.angle = _baseAngle + details.rotation;
                                      } else {
                                        double nextX = piece.position.dx + details.focalPointDelta.dx;
                                        double nextY = piece.position.dy + details.focalPointDelta.dy;

                                        nextX = nextX.clamp(0.0, courtWidth - pieceSize);
                                        nextY = nextY.clamp(0.0, courtHeight - pieceSize);

                                        piece.position = Offset(nextX, nextY);
                                      }
                                    });
                                  },
                                  onScaleEnd: (details) {
                                    if (!isRecording && currentPhase == 1 && !isInitialPositionSaved) {
                                      history[0] = pieces.map((p) => p.clone()).toList();
                                    }
                                  },
                                  onDoubleTap: () {
                                    if (isPlaying) return;
                                    setState(() {
                                      piece.angle += (math.pi / 4);
                                      if (!isRecording && currentPhase == 1 && !isInitialPositionSaved) {
                                        history[0] = pieces.map((p) => p.clone()).toList();
                                      }
                                    });
                                  },
                                  child: Transform.rotate(
                                    angle: piece.angle,
                                    child: _buildPieceWidget(piece, pieceSize),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPieceWidget(BoardPiece piece, double size) {
   if (piece.isBall) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '🏀', 
            style: TextStyle(
              fontSize: size * 0.6,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 3.0,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWhiteTeam = piece.color == Colors.white;
    final numberTextColor = isWhiteTeam ? Colors.black : Colors.white;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            piece.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.accessible, color: piece.color, size: size * 0.7);
            },
          ),
        ),
        Positioned(
          top: size * 0.3,
          child: Text(
            piece.label,
            style: TextStyle(
              color: numberTextColor,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.32,
              shadows: [
                Shadow(
                  offset: const Offset(1, 1),
                  blurRadius: 1.5,
                  color: isWhiteTeam ? Colors.white54 : Colors.black87,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}