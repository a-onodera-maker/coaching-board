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

class PositionFrame {
  final Offset position;
  final double angle;
  PositionFrame({required this.position, required this.angle});
}

class BoardPiece {
  final String id;
  final String label;
  final Color color;
  final bool isBall;
  final String imagePath;
  Offset position;
  double angle;
  
  // 各フェーズごとの軌跡データを保持するマップ (キー: phaseId)
  Map<int, List<PositionFrame>> phaseTrails = {};
  // そのフェーズで過去に動かしたことがあるか
  Map<int, bool> isRecordedInPhase = {};

  BoardPiece({
    required this.id,
    required this.label,
    required this.color,
    this.isBall = false,
    required this.imagePath,
    required this.position,
    this.angle = 0.0,
    Map<int, List<PositionFrame>>? phaseTrails,
    Map<int, bool>? isRecordedInPhase,
  }) {
    this.phaseTrails = phaseTrails ?? {};
    this.isRecordedInPhase = isRecordedInPhase ?? {};
  }

  BoardPiece clone() {
    final Map<int, List<PositionFrame>> clonedTrails = {};
    phaseTrails.forEach((key, value) {
      clonedTrails[key] = List<PositionFrame>.from(value);
    });
    return BoardPiece(
      id: id,
      label: label,
      color: color,
      isBall: isBall,
      imagePath: imagePath,
      position: Offset(position.dx, position.dy),
      angle: angle,
      phaseTrails: clonedTrails,
      isRecordedInPhase: Map<int, bool>.from(isRecordedInPhase),
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

  int playbackSpeedMs = 20; 
  bool _isLayoutCalculated = false;
  bool _isDragging = false;

  String? _currentlyActivePieceId;

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
    pieces.add(BoardPiece(id: 'ball', label: '', color: Colors.orange, isBall: true, imagePath: '', position: Offset.zero));
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(id: 'black_$i', label: '${i + 1}', color: Colors.black, imagePath: 'assets/wheelchair_black.png', position: Offset.zero));
    }
  }

  void _arrangePiecesToFitScreen(double courtWidth, double courtHeight) {
    final pieceSize = courtWidth / 14;
    final leftStartX = 15.0;
    final lastX = courtWidth - leftStartX - pieceSize;
    final spacing = (lastX - leftStartX) / 4;

    for (int i = 0; i < 5; i++) {
      final xPosition = leftStartX + (i * spacing);
      // 白チーム（元々上向き）
      pieces[i].position = Offset(xPosition, 35.0);
      pieces[i].angle = 0.0;
      pieces[i].phaseTrails.clear();
      pieces[i].isRecordedInPhase.clear();

      // 黒チーム（💡 画像自体が最初から下向きなので、角度は0.0のまま配置します）
      pieces[6 + i].position = Offset(xPosition, courtHeight - pieceSize - 45.0);
      pieces[6 + i].angle = 0.0; 
      pieces[6 + i].phaseTrails.clear();
      pieces[6 + i].isRecordedInPhase.clear();
    }

    final ballSize = pieceSize;
    final ballX = (courtWidth / 2) - (ballSize / 2);
    final ballY = (courtHeight / 2) - (ballSize / 2);
    pieces[5].position = Offset(ballX, ballY);
    pieces[5].angle = 0.0;
    pieces[5].phaseTrails.clear();
    pieces[5].isRecordedInPhase.clear();
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
        isRecording = false;
        _currentlyActivePieceId = null;

        int maxLen = 0;
        for (var p in pieces) {
          final trail = p.phaseTrails[currentPhase];
          if (trail != null && trail.length > maxLen) {
            maxLen = trail.length;
          }
        }
        if (maxLen == 0) maxLen = 1;

        for (var p in pieces) {
          if (!p.phaseTrails.containsKey(currentPhase) || p.phaseTrails[currentPhase]!.isEmpty) {
            p.phaseTrails[currentPhase] = List.generate(maxLen, (_) => PositionFrame(position: p.position, angle: p.angle));
          } else {
            final trail = p.phaseTrails[currentPhase]!;
            final lastFrame = trail.last;
            while (trail.length < maxLen) {
              trail.add(PositionFrame(position: lastFrame.position, angle: lastFrame.angle));
            }
          }
        }

        history[currentPhase] = pieces.map((p) => p.clone()).toList();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('フェーズ $currentPhase に動きを上乗せ記録しました')),
        );
      } else {
        if (currentPhase == 1 && !isInitialPositionSaved) {
          history[0] = pieces.map((p) => p.clone()).toList();
          isInitialPositionSaved = true;
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
      await Future.delayed(const Duration(milliseconds: 300));
    }

    for (int phase = 1; phase <= 8; phase++) {
      if (history.containsKey(phase)) {
        if (!mounted) return;
        setState(() => currentPhase = phase);

        final phasePieces = history[phase]!;
        int maxSteps = phasePieces.first.phaseTrails[phase]?.length ?? 0;

        for (int step = 0; step < maxSteps; step++) {
          if (!mounted) return;
          setState(() {
            for (int i = 0; i < pieces.length; i++) {
              final targetPiece = phasePieces[i];
              final trail = targetPiece.phaseTrails[phase];
              if (trail != null && step < trail.length) {
                pieces[i].position = trail[step].position;
                pieces[i].angle = trail[step].angle;
              }
            }
          });
          await Future.delayed(Duration(milliseconds: playbackSpeedMs));
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (!mounted) return;
    setState(() => isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wheelchair Basketball Tactics Board',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, mainConstraints) {
            final availableHeight = mainConstraints.maxHeight - 110;
            double courtWidth = mainConstraints.maxWidth;
            double courtHeight = courtWidth;

            if (courtHeight > availableHeight) {
              courtHeight = availableHeight;
              courtWidth = courtHeight;
            }

            if (!_isLayoutCalculated) {
              _arrangePiecesToFitScreen(courtWidth, courtHeight);
              _isLayoutCalculated = true;
            }

            final pieceSize = courtWidth / 13;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                  color: Colors.black26,
                  width: double.infinity,
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          Wrap(
                            spacing: 3.0,
                            children: [
                              for (int i = 1; i <= 8; i++) 
                                SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: currentPhase == i ? Colors.orange : Colors.grey[700],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    onPressed: isPlaying ? null : () {
                                      setState(() {
                                        currentPhase = i;
                                        if (history.containsKey(i)) {
                                          pieces = history[i]!.map((p) => p.clone()).toList();
                                        } else {
                                          for (var p in pieces) {
                                            p.phaseTrails.remove(i);
                                            p.isRecordedInPhase.remove(i);
                                          }
                                        }
                                      });
                                    },
                                    child: Text('$i', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 2),
                          ElevatedButton.icon(
                            onPressed: isPlaying ? null : _toggleRecording,
                            icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record, size: 16),
                            label: Text(isRecording ? 'ストップ' : 'フェーズ$currentPhase 記録', style: const TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: isRecording ? Colors.red : Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                          ElevatedButton.icon(
                            onPressed: isRecording || !isInitialPositionSaved ? null : _playSimulation,
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('再生', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 20.0,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('作戦を保存しました')));
                            },
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('保存', style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], padding: const EdgeInsets.symmetric(horizontal: 16)),
                            onPressed: isPlaying ? null : () => _clearAllDataAndReset(courtWidth, courtHeight),
                            icon: const Icon(Icons.delete_forever, size: 16),
                            label: const Text('クリア', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

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
                                    child: const Center(child: Text('ハーフコート画像が見つかりません', style: TextStyle(color: Colors.grey))),
                                  );
                                },
                              ),
                            ),
                          ),

                          ...pieces.map((piece) {
                            final currentDuration = (_isDragging || isPlaying || isRecording)
                                ? Duration.zero
                                : const Duration(milliseconds: 200);

                            return AnimatedPositioned(
                              key: ValueKey(piece.id),
                              duration: currentDuration,
                              curve: Curves.linear, 
                              left: piece.position.dx,
                              top: piece.position.dy,
                              child: GestureDetector(
                                onPanStart: isPlaying ? null : (details) {
                                  setState(() { 
                                    _isDragging = true;
                                    if (isRecording) {
                                      _currentlyActivePieceId = piece.id;
                                      piece.isRecordedInPhase[currentPhase] = true;
                                      piece.phaseTrails[currentPhase] = [];
                                    }
                                  });
                                },
                                // （前後の共通部分はそのまま、 GestureDetector 内の onPanUpdate のみ修正しています）

                                onPanUpdate: isPlaying ? null : (details) {
                                  setState(() {
                                    final deltaX = details.delta.dx;
                                    final deltaY = details.delta.dy;

                                    if (piece.isBall) {
                                      double nextX = piece.position.dx + deltaX;
                                      double nextY = piece.position.dy + deltaY;
                                      nextX = nextX.clamp(0.0, courtWidth - pieceSize);
                                      nextY = nextY.clamp(0.0, courtHeight - pieceSize);
                                      piece.position = Offset(nextX, nextY);
                                    } 
                                    else {
                                      // 💡 ドラッグで動かした「進行方向」の角度を計算
                                      if (deltaX.abs() > 0.5 || deltaY.abs() > 0.5) {
                                        double baseAngle = math.atan2(deltaY, deltaX) - (math.pi / 2);
                                        
                                        // 💡 【ここが超重要修正】
                                        // 黒チームは「最初から下向きの画像」なので、
                                        // そのまま進めるとバックしてしまうため、角度を180度（math.pi）ひっくり返して前を向かせます。
                                        if (piece.color == Colors.black) {
                                          piece.angle = baseAngle + math.pi;
                                        } else {
                                          piece.angle = baseAngle;
                                        }
                                      }

                                      double nextX = piece.position.dx + deltaX;
                                      double nextY = piece.position.dy + deltaY;
                                      nextX = nextX.clamp(0.0, courtWidth - pieceSize);
                                      nextY = nextY.clamp(0.0, courtHeight - pieceSize);
                                      piece.position = Offset(nextX, nextY);
                                    }

                                    if (isRecording && _currentlyActivePieceId == piece.id) {
                                      piece.phaseTrails[currentPhase]!.add(
                                        PositionFrame(position: piece.position, angle: piece.angle)
                                      );
                                    }
                                  });
                                },
                                onPanEnd: isPlaying ? null : (details) {
                                  setState(() { _isDragging = false; });
                                  if (!isRecording && currentPhase == 1 && !isInitialPositionSaved) {
                                    history[0] = pieces.map((p) => p.clone()).toList();
                                  }
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
        child: Center(child: Text('🏀', style: TextStyle(fontSize: size * 0.6))),
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
                  Shadow(offset: const Offset(1, 1), blurRadius: 1.5, color: isWhiteTeam ? Colors.white54 : Colors.black87),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}