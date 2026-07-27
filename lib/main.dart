import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const WheelchairTacticsApp());
}

class WheelchairTacticsApp extends StatelessWidget {
  const WheelchairTacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '車椅子バスケ 作戦ボード',
      debugShowCheckedModeBanner: false,
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

  Map<String, dynamic> toJson() => {
        'dx': position.dx,
        'dy': position.dy,
        'angle': angle,
      };

  factory PositionFrame.fromJson(Map<String, dynamic> json) {
    return PositionFrame(
      position: Offset(
        (json['dx'] as num).toDouble(),
        (json['dy'] as num).toDouble(),
      ),
      angle: (json['angle'] as num).toDouble(),
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

  Map<int, List<PositionFrame>> phaseTrails = {};
  Map<int, bool> isRecordedInPhase = {};

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
    final piece = BoardPiece(
      id: id,
      label: label,
      color: color,
      isBall: isBall,
      imagePath: imagePath,
      position: Offset(position.dx, position.dy),
      angle: angle,
    );
    phaseTrails.forEach((key, value) {
      piece.phaseTrails[key] = List<PositionFrame>.from(value);
    });
    piece.isRecordedInPhase = Map<int, bool>.from(isRecordedInPhase);
    return piece;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'color': color.toARGB32(),
        'isBall': isBall,
        'imagePath': imagePath,
        'dx': position.dx,
        'dy': position.dy,
        'angle': angle,
        'phaseTrails': phaseTrails.map((k, v) =>
            MapEntry(k.toString(), v.map((e) => e.toJson()).toList())),
        'isRecordedInPhase':
            isRecordedInPhase.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory BoardPiece.fromJson(Map<String, dynamic> json) {
    final piece = BoardPiece(
      id: json['id'] as String,
      label: json['label'] as String,
      color: Color(json['color'] as int),
      isBall: json['isBall'] as bool? ?? false,
      imagePath: json['imagePath'] as String,
      position: Offset(
        (json['dx'] as num).toDouble(),
        (json['dy'] as num).toDouble(),
      ),
      angle: (json['angle'] as num).toDouble(),
    );

    final trailsJson = json['phaseTrails'] as Map<String, dynamic>? ?? {};
    trailsJson.forEach((key, value) {
      final list = (value as List)
          .map((e) => PositionFrame.fromJson(e as Map<String, dynamic>))
          .toList();
      piece.phaseTrails[int.parse(key)] = list;
    });

    final recordedJson =
        json['isRecordedInPhase'] as Map<String, dynamic>? ?? {};
    recordedJson.forEach((key, value) {
      piece.isRecordedInPhase[int.parse(key)] = value as bool;
    });

    return piece;
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
  String currentFormationName = '';

  @override
  void initState() {
    super.initState();
    _setupDummyPositions();
  }

  void _setupDummyPositions() {
    pieces.clear();
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(
          id: 'white_$i',
          label: '${i + 1}',
          color: Colors.white,
          imagePath: 'assets/wheelchair_white.png',
          position: Offset.zero));
    }
    pieces.add(BoardPiece(
        id: 'ball',
        label: '',
        color: Colors.orange,
        isBall: true,
        imagePath: '',
        position: Offset.zero));
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(
          id: 'black_$i',
          label: '${i + 1}',
          color: Colors.black,
          imagePath: 'assets/wheelchair_black.png',
          position: Offset.zero));
    }
  }

  void _arrangePiecesToFitScreen(double courtWidth, double courtHeight) {
    final pieceSize = courtWidth / 14;
    final leftStartX = 15.0;
    final lastX = courtWidth - leftStartX - pieceSize;
    final spacing = (lastX - leftStartX) / 4;

    for (int i = 0; i < 5; i++) {
      final xPosition = leftStartX + (i * spacing);
      pieces[i].position = Offset(xPosition, 35.0);
      pieces[i].angle = 0.0;
      pieces[i].phaseTrails.clear();
      pieces[i].isRecordedInPhase.clear();

      pieces[6 + i].position =
          Offset(xPosition, courtHeight - pieceSize - 45.0);
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
      currentFormationName = '';
      _arrangePiecesToFitScreen(courtWidth, courtHeight);
    });
  }

  void _clearAllDataAndReset(double courtWidth, double courtHeight) {
    setState(() {
      _resetToDefaultPositions(courtWidth, courtHeight);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ 盤面をリセットしました')),
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
          if (!p.phaseTrails.containsKey(currentPhase) ||
              p.phaseTrails[currentPhase]!.isEmpty) {
            p.phaseTrails[currentPhase] = List.generate(maxLen,
                (_) => PositionFrame(position: p.position, angle: p.angle));
          } else {
            final trail = p.phaseTrails[currentPhase]!;
            final lastFrame = trail.last;
            while (trail.length < maxLen) {
              trail.add(PositionFrame(
                  position: lastFrame.position, angle: lastFrame.angle));
            }
          }
        }

        history[currentPhase] = pieces.map((p) => p.clone()).toList();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('フェーズ $currentPhase に動きを記録しました')),
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

  // --- 本体ストレージへの永久保存機能 ---
  Future<void> _showSaveDialog() async {
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存するデータがありません。先にフェーズを記録してください')),
      );
      return;
    }

    final controller = TextEditingController(text: currentFormationName);
    final formationName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フォーメーションの保存'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'フォーメーション名',
            hintText: '例: 2-1-2 ゾーンアタック',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (formationName != null && formationName.isNotEmpty) {
      await _saveFormationToStorage(formationName);
    }
  }

  Future<void> _saveFormationToStorage(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> exportData = {
        'name': name,
        'isInitialPositionSaved': isInitialPositionSaved,
        'history': history.map((k, v) =>
            MapEntry(k.toString(), v.map((p) => p.toJson()).toList())),
      };

      await prefs.setString('formation_$name', jsonEncode(exportData));
      
      // 保存済み名の一覧を更新
      List<String> savedList = prefs.getStringList('saved_formations_list') ?? [];
      if (!savedList.contains(name)) {
        savedList.add(name);
        await prefs.setStringList('saved_formations_list', savedList);
      }

      setState(() {
        currentFormationName = name;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('💾 「$name」を保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    }
  }

  // --- 保存済みフォーメーションの読み込み機能 ---
  Future<void> _showLoadDialog() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('saved_formations_list') ?? [];

    if (savedList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存されているフォーメーションがありません')),
      );
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フォーメーション一覧'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: savedList.length,
            itemBuilder: (context, index) {
              final name = savedList[index];
              return ListTile(
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    await prefs.remove('formation_$name');
                    savedList.remove(name);
                    await prefs.setStringList('saved_formations_list', savedList);
                    Navigator.pop(context);
                    _showLoadDialog(); // 再表示
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _loadFormationFromStorage(name);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFormationFromStorage(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('formation_$name');
      if (jsonString == null) return;

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final historyData = decoded['history'] as Map<String, dynamic>;

      setState(() {
        history.clear();
        isInitialPositionSaved = decoded['isInitialPositionSaved'] ?? false;
        currentFormationName = name;

        historyData.forEach((key, value) {
          final phaseKey = int.parse(key);
          final pieceList = (value as List)
              .map((e) => BoardPiece.fromJson(e as Map<String, dynamic>))
              .toList();
          history[phaseKey] = pieceList;
        });

        if (history.containsKey(0)) {
          pieces = history[0]!.map((p) => p.clone()).toList();
        } else if (history.containsKey(1)) {
          pieces = history[1]!.map((p) => p.clone()).toList();
        }
        currentPhase = 1;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📂 「$name」を読み込みました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読み込みエラー: $e')),
      );
    }
  }

  double _normalizeAngle(double angle) {
    while (angle > math.pi) angle -= 2 * math.pi;
    while (angle < -math.pi) angle += 2 * math.pi;
    return angle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wheelchair Basketball Tactics Board',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (currentFormationName.isNotEmpty)
              Text(
                '作戦名: $currentFormationName',
                style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
              ),
          ],
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
                  padding: const EdgeInsets.symmetric(
                      vertical: 6.0, horizontal: 8.0),
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
                                      backgroundColor: currentPhase == i
                                          ? Colors.orange
                                          : Colors.grey[700],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                    onPressed: isPlaying
                                        ? null
                                        : () {
                                            setState(() {
                                              currentPhase = i;
                                              if (history.containsKey(i)) {
                                                pieces = history[i]!
                                                    .map((p) => p.clone())
                                                    .toList();
                                              } else {
                                                for (var p in pieces) {
                                                  p.phaseTrails.remove(i);
                                                  p.isRecordedInPhase.remove(i);
                                                }
                                              }
                                            });
                                          },
                                    child: Text('$i',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 2),
                          ElevatedButton.icon(
                            onPressed: isPlaying ? null : _toggleRecording,
                            icon: Icon(
                                isRecording
                                    ? Icons.stop
                                    : Icons.fiber_manual_record,
                                size: 16),
                            label: Text(
                                isRecording
                                    ? 'ストップ'
                                    : 'フェーズ$currentPhase 記録',
                                style: const TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isRecording ? Colors.red : Colors.blue,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                          ElevatedButton.icon(
                            onPressed: isRecording || !isInitialPositionSaved
                                ? null
                                : _playSimulation,
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label:
                                const Text('再生', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.yellowAccent,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12.0,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14)),
                            onPressed:
                                isPlaying || isRecording ? null : _showSaveDialog,
                            icon: const Icon(Icons.save, size: 16),
                            label:
                                const Text('名前をつけて保存', style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14)),
                            onPressed: isPlaying || isRecording
                                ? null
                                : _showLoadDialog,
                            icon: const Icon(Icons.folder_open, size: 16),
                            label:
                                const Text('呼び出し', style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[900],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14)),
                            onPressed: isPlaying
                                ? null
                                : () => _clearAllDataAndReset(
                                    courtWidth, courtHeight),
                            icon: const Icon(Icons.refresh, size: 16),
                            label:
                                const Text('リセット', style: TextStyle(fontSize: 12)),
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
                                    child: const Center(
                                        child: Text('ハーフコート画像が見つかりません',
                                            style:
                                                TextStyle(color: Colors.grey))),
                                  );
                                },
                              ),
                            ),
                          ),
                          ...pieces.map((piece) {
                            final currentDuration =
                                (_isDragging || isPlaying || isRecording)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200);

                            return AnimatedPositioned(
                              key: ValueKey(piece.id),
                              duration: currentDuration,
                              curve: Curves.linear,
                              left: piece.position.dx,
                              top: piece.position.dy,
                              child: GestureDetector(
                                onPanStart: isPlaying
                                    ? null
                                    : (details) {
                                        setState(() {
                                          _isDragging = true;
                                          if (isRecording) {
                                            _currentlyActivePieceId = piece.id;
                                            piece.isRecordedInPhase[
                                                currentPhase] = true;
                                            piece.phaseTrails[currentPhase] = [];
                                          }
                                        });
                                      },
                                onPanUpdate: isPlaying
                                    ? null
                                    : (details) {
                                        setState(() {
                                          final deltaX = details.delta.dx;
                                          final deltaY = details.delta.dy;
                                          final moveDistance = math.sqrt(
                                              deltaX * deltaX +
                                                  deltaY * deltaY);

                                          if (piece.isBall) {
                                            double nextX =
                                                piece.position.dx + deltaX;
                                            double nextY =
                                                piece.position.dy + deltaY;
                                            nextX = nextX.clamp(
                                                0.0, courtWidth - pieceSize);
                                            nextY = nextY.clamp(
                                                0.0, courtHeight - pieceSize);
                                            piece.position =
                                                Offset(nextX, nextY);
                                          } else {
                                            if (moveDistance > 1.5) {
                                              double targetAngle = math.atan2(
                                                      deltaY, deltaX) -
                                                  (math.pi / 2);
                                              if (piece.color == Colors.black) {
                                                targetAngle += math.pi;
                                              }

                                              double angleDiff =
                                                  _normalizeAngle(targetAngle -
                                                      piece.angle);

                                              const double maxRotationPerFrame =
                                                  0.25;
                                              angleDiff = angleDiff.clamp(
                                                  -maxRotationPerFrame,
                                                  maxRotationPerFrame);

                                              piece.angle = piece.angle +
                                                  (angleDiff * 0.35);
                                            }

                                            double nextX =
                                                piece.position.dx + deltaX;
                                            double nextY =
                                                piece.position.dy + deltaY;
                                            nextX = nextX.clamp(
                                                0.0, courtWidth - pieceSize);
                                            nextY = nextY.clamp(
                                                0.0, courtHeight - pieceSize);
                                            piece.position =
                                                Offset(nextX, nextY);
                                          }

                                          if (isRecording &&
                                              _currentlyActivePieceId ==
                                                  piece.id) {
                                            piece.phaseTrails[currentPhase]!
                                                .add(PositionFrame(
                                                    position: piece.position,
                                                    angle: piece.angle));
                                          }
                                        });
                                      },
                                onPanEnd: isPlaying
                                    ? null
                                    : (details) {
                                        setState(() {
                                          _isDragging = false;
                                        });
                                        if (!isRecording &&
                                            currentPhase == 1 &&
                                            !isInitialPositionSaved) {
                                          history[0] = pieces
                                              .map((p) => p.clone())
                                              .toList();
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
        child: Center(
            child: Text('🏀', style: TextStyle(fontSize: size * 0.6))),
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
                return Icon(Icons.accessible,
                    color: piece.color, size: size * 0.7);
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
                      color: isWhiteTeam ? Colors.white54 : Colors.black87),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}