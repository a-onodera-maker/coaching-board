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
    required this.label, // 💡 タイプエラーの原因だった箇所を修正しました
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
    // 共通の白い車椅子画像に、ループで1〜5の文字を自動で割り振ります
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(
        id: 'white_$i', 
        label: '${i + 1}', 
        color: Colors.white, 
        imagePath: 'assets/wheelchair_white.png', 
        position: Offset.zero
      ));
    }
    // ボール
    pieces.add(BoardPiece(id: 'ball', label: '', color: Colors.orange, isBall: true, imagePath: '', position: Offset.zero));
    
    // 共通の黒い車椅子画像に、ループで1〜5の文字を自動で割り振ります
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(
        id: 'black_$i', 
        label: '${i + 1}', 
        color: Colors.black, 
        imagePath: 'assets/wheelchair_black.png', 
        position: Offset.zero
      ));
    }
  }

  // 白線に合わせて左右対称に5等分する関数
  void _arrangePiecesToFitScreen(double courtWidth, double courtHeight) {
    final pieceSize = courtWidth / 14;
    final leftStartX = 15.0; 
    final lastX = courtWidth - leftStartX - pieceSize;
    final spacing = (lastX - leftStartX) / 4;

    for (int i = 0; i < 5; i++) {
      final xPosition = leftStartX + (i * spacing);

      // 味方5台（白）：上側（コート奥）
      pieces[i].position = Offset(xPosition, 35.0);
      pieces[i].angle = 0.0;

      // 敵5台（黒）：下側（コート手前）
      pieces[6 + i].position = Offset(xPosition, courtHeight - pieceSize - 45.0);
      pieces[6 + i].angle = 0.0;
    }

    // ボールの配置
    final ballSize = pieceSize;
    final ballX = (courtWidth / 2) - (ballSize / 2); 
    final ballY = (courtHeight / 2) - (ballSize / 2);
    
    pieces[5].position = Offset(ballX, ballY);
    pieces[5].angle = 0.0;
  }

  void _resetToDefaultPositions(double courtWidth, double courtHeight) {
    setState(() {
      history.clear();
      currentPhase = 1;
      isRecording = false;
      isPlaying = false;
      isInitialPositionSaved = false;
      _arrangePiecesToFitScreen(courtWidth, courtHeight);
    });
  }

  void _clearAllDataAndReset(double courtWidth, double courtHeight) {
    setState(() {
      _resetToDefaultPositions(courtWidth, courtHeight);
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
            
            double courtWidth = mainConstraints.maxWidth; 
            double courtHeight = courtWidth;

            if (courtHeight > availableHeight) {
              courtHeight = availableHeight;
              courtWidth = courtHeight ;
            }

            if (!_isLayoutCalculated) {
              _arrangePiecesToFitScreen(courtWidth, courtHeight);
              _isLayoutCalculated = true;
            }

            final pieceSize = courtWidth / 14;

            return Column(
              children: [
                // 1. 上部コントローラー
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
                              height: 36, 
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: currentPhase == i ? Colors.orange : Colors.grey[700],
                                  foregroundColor: Colors.white,
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
                        onPressed: isPlaying ? null : () => _clearAllDataAndReset(courtWidth, courtHeight),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('クリア'),
                      ),
                    ],
                  ),
                ),

                // 2. メインエリア：ハーフコートと駒
                Expanded(
                  child: Center(
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
                              key: ValueKey(piece.id), 
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
                                child: _buildPieceWidget(piece, pieceSize),
                              ),
                            );
                          }),
                        ],
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
            style: TextStyle(fontSize: size * 0.6),
          ),
        ),
      );
    }

    final isWhiteTeam = piece.color == Colors.white;
    final numberTextColor = isWhiteTeam ? Colors.black : Colors.white;

    return Transform.rotate(
      angle: piece.angle,
      child: Stack(
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
            child: Text(
              piece.label,
              style: TextStyle(
                color: numberTextColor,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.35,
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
      ),
    );
  }
}