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
  
  // コートのサイズが確定したかどうかを管理するフラグ
  bool _isLayoutCalculated = false;

  @override
  void initState() {
    super.initState();
    // 最初のダミー位置（あとでコートサイズを元に自動再配置されます）
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

  // ★ 改良点：画面サイズ（コートの幅）に合わせて11個のパーツを完璧に等間隔に並べる関数
  void _arrangePiecesToFitScreen(double courtWidth) {
    // 全11個（白5、ボール1、黒5）のパーツを等間隔に並べるための隙間を計算
    // 駒のサイズが courtWidth / 15 なので、残りのスペースを10等分します
    final pieceSize = courtWidth / 15;
    final totalAvailableWidth = courtWidth - pieceSize;
    final spacing = totalAvailableWidth / 10;

    // 白チーム (0〜4番目)
    for (int i = 0; i < 5; i++) {
      pieces[i].position = Offset(i * spacing, 10.0);
      pieces[i].angle = 0.0;
    }
    // ボール (5番目)
    pieces[5].position = Offset(5 * spacing + (pieceSize * 0.25), 10.0 + (pieceSize * 0.25));
    pieces[5].angle = 0.0;
    // 黒チーム (6〜10番目)
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
            // まず全体のサイズからコートサイズをあらかじめ計算する
            // 縦のコントローラー部分を除いたエリアで計算
            final availableHeight = mainConstraints.maxHeight - 60; // ざっくりボタンエリア分を引く
            
            double courtWidth = mainConstraints.maxWidth - 24; // パディング分
            double courtHeight = courtWidth * (14 / 15);

            if (courtHeight > availableHeight) {
              courtHeight = availableHeight;
              courtWidth = courtHeight * (15 / 14);
            }

            // ★ アプリ起動直後に、計算されたコート幅を使って一回だけ初期配置を自動整列させる
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
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: currentPhase == i ? Colors.orange : Colors.grey[700],
                                  foregroundColor: Colors.white,
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
                      // クリアボタン（完全に初期状態にリセット）
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
                          clipBehavior: Clip.hardEdge, // コート外はみ出しカット
                          children: [
                            // コート背景画像
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

                            // 駒の描画
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

                                        // コート内からはみ出さないガード
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

  // 駒パーツの描画
  Widget _buildPieceWidget(BoardPiece piece, double size) {
   if (piece.isBall) {
      // ボールのサイズ自体を「size（車椅子と同じ大きさ）」に変更
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            '🏀', 
            // 絵文字のサイズを限界まで大きく（0.85倍）し、見やすく立体的な影をつけました
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