import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // クリップボード操作用
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
      home: const MainContainerScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// 選手データモデル
// ---------------------------------------------------------------------------
class Player {
  String number;
  String name;
  bool isSelected;

  Player({required this.number, required this.name, this.isSelected = false});
}

// ---------------------------------------------------------------------------
// 画面全体を管理するコンテナ (PageView - スワイプ無効化版)
// ---------------------------------------------------------------------------
class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  final PageController _pageController = PageController();

  // 登録選手リスト（初期値5人）
  List<Player> registeredPlayers = [
    Player(number: '4', name: '選手A', isSelected: true),
    Player(number: '5', name: '選手B', isSelected: true),
    Player(number: '6', name: '選手C', isSelected: true),
    Player(number: '7', name: '選手D', isSelected: true),
    Player(number: '8', name: '選手E', isSelected: true),
  ];

  // 選択されている白チーム5人の背番号リストを取得
  List<String> get selectedWhiteNumbers {
    final selected = registeredPlayers
        .where((p) => p.isSelected)
        .map((p) => p.number)
        .toList();

    // 5人に満たない場合は足らない分を「?」で補填
    while (selected.length < 5) {
      selected.add('${selected.length + 1}');
    }
    return selected.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        // スワイプ操作を無効化（ボタンでのみ画面移動）
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // ページ 1: 作戦ボード画面
          TacticsBoardScreen(
            whiteNumbers: selectedWhiteNumbers,
            onOpenRosterPage: () {
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),

          // ページ 2: 選手登録＆5人選択画面
          PlayerRosterScreen(
            players: registeredPlayers,
            onPlayersChanged: () {
              setState(() {}); // 白チームの番号更新を全体に伝える
            },
            onBackToBoardPage: () {
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 選手登録 ＆ 出場5人選択画面
// ---------------------------------------------------------------------------
class PlayerRosterScreen extends StatefulWidget {
  final List<Player> players;
  final VoidCallback onPlayersChanged;
  final VoidCallback onBackToBoardPage;

  const PlayerRosterScreen({
    super.key,
    required this.players,
    required this.onPlayersChanged,
    required this.onBackToBoardPage,
  });

  @override
  State<PlayerRosterScreen> createState() => _PlayerRosterScreenState();
}

class _PlayerRosterScreenState extends State<PlayerRosterScreen> {
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.players.where((p) => p.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('白チーム 選手管理 / 5人選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '作戦ボードへ戻る',
          onPressed: widget.onBackToBoardPage,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('新規選手追加',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _numberController,
                      decoration: const InputDecoration(
                        labelText: '背番号',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '名前',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('追加'),
                    onPressed: () {
                      if (_numberController.text.trim().isNotEmpty) {
                        setState(() {
                          widget.players.add(Player(
                            number: _numberController.text.trim(),
                            name: _nameController.text.trim().isEmpty
                                ? '選手'
                                : _nameController.text.trim(),
                          ));
                        });
                        _numberController.clear();
                        _nameController.clear();
                        widget.onPlayersChanged();
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('コート上に出す5人を選択',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '$selectedCount / 5 人選択中',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: selectedCount == 5 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.players.length,
                  itemBuilder: (context, index) {
                    final player = widget.players[index];
                    return Card(
                      color: player.isSelected
                          ? Colors.orange.withAlpha(40)
                          : Colors.grey[900],
                      child: CheckboxListTile(
                        title: Text('#${player.number} ${player.name}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        value: player.isSelected,
                        activeColor: Colors.orange,
                        onChanged: (bool? checked) {
                          if (checked == true && selectedCount >= 5) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('選択できるのは最大5人までです'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            player.isSelected = checked ?? false;
                          });
                          widget.onPlayersChanged();
                        },
                        secondary: IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.redAccent, size: 20),
                          onPressed: () {
                            setState(() {
                              widget.players.removeAt(index);
                            });
                            widget.onPlayersChanged();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: widget.onBackToBoardPage,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('作戦ボードへ戻る',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 作戦ボード画面
// ---------------------------------------------------------------------------
class PositionFrame {
  final Offset position;
  final double angle;
  PositionFrame({required this.position, required this.angle});

  Map<String, dynamic> toJson() => {
        'x': position.dx,
        'y': position.dy,
        'a': angle,
      };

  factory PositionFrame.fromJson(Map<String, dynamic> json) {
    return PositionFrame(
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      angle: (json['a'] as num).toDouble(),
    );
  }
}

class BoardPiece {
  final String id;
  String label;
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'color': color.toARGB32(),
      'isBall': isBall,
      'imagePath': imagePath,
      'x': position.dx,
      'y': position.dy,
      'angle': angle,
      'phaseTrails': phaseTrails.map((k, v) =>
          MapEntry(k.toString(), v.map((e) => e.toJson()).toList())),
    };
  }

  factory BoardPiece.fromJson(Map<String, dynamic> json) {
    final piece = BoardPiece(
      id: json['id'] as String,
      label: json['label'] as String,
      color: Color(json['color'] as int),
      isBall: json['isBall'] as bool? ?? false,
      imagePath: json['imagePath'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
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

    return piece;
  }
}

class TacticsBoardScreen extends StatefulWidget {
  final List<String> whiteNumbers;
  final VoidCallback onOpenRosterPage;

  const TacticsBoardScreen({
    super.key,
    required this.whiteNumbers,
    required this.onOpenRosterPage,
  });

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

  @override
  void didUpdateWidget(covariant TacticsBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyWhiteNumbers();
  }

  void _applyWhiteNumbers() {
    for (int i = 0; i < 5; i++) {
      if (i < widget.whiteNumbers.length && i < pieces.length) {
        pieces[i].label = widget.whiteNumbers[i];
      }
    }
  }

  void _applySelectedWhiteNumbersIfAvailable() {
    if (widget.whiteNumbers.length == 5) {
      for (int i = 0; i < 5; i++) {
        if (i < pieces.length) {
          pieces[i].label = widget.whiteNumbers[i];
        }
      }
    }
  }

  void _setupDummyPositions() {
    pieces.clear();
    for (int i = 0; i < 5; i++) {
      pieces.add(BoardPiece(
          id: 'white_$i',
          label: i < widget.whiteNumbers.length
              ? widget.whiteNumbers[i]
              : '${i + 1}',
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

    _applyWhiteNumbers();
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
        _applySelectedWhiteNumbersIfAvailable();
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
            _applySelectedWhiteNumbersIfAvailable();
          });
          await Future.delayed(Duration(milliseconds: playbackSpeedMs));
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (!mounted) return;
    setState(() => isPlaying = false);
  }

  // --- 保存処理 ---
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
        'history': history.map((k, v) => MapEntry(
            k.toString(), v.map((p) => p.toJson()).toList())),
      };

      await prefs.setString('formation_$name', jsonEncode(exportData));

      List<String> savedList =
          prefs.getStringList('saved_formations_list') ?? [];
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

  // --- 一覧・共有 ---
  Future<void> _showLoadDialog() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList =
        prefs.getStringList('saved_formations_list') ?? [];

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フォーメーション一覧'),
        content: SizedBox(
          width: double.maxFinite,
          child: savedList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('保存されているフォーメーションがありません'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: savedList.length,
                  itemBuilder: (context, index) {
                    final name = savedList[index];
                    return ListTile(
                      title: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share,
                                color: Colors.greenAccent),
                            tooltip: 'LINE用コードをコピー',
                            onPressed: () => _exportFormationToClipboard(name),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () async {
                              await prefs.remove('formation_$name');
                              savedList.remove(name);
                              await prefs.setStringList(
                                  'saved_formations_list', savedList);
                              Navigator.pop(context);
                              _showLoadDialog();
                            },
                          ),
                        ],
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

  Future<void> _exportFormationToClipboard(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('formation_$name');
      if (jsonString == null) return;

      final base64Code = base64UrlEncode(utf8.encode(jsonString));
      await Clipboard.setData(ClipboardData(text: base64Code));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📋 「$name」の共有コードをコピーしました！'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('共有エラー: $e')),
      );
    }
  }

  // --- LINE・Webからの取込 ---
  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LINE等から作戦を取り込む'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '送られてきた共有コードを下に貼り付けて「取り込む」を押してください。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'ここにコードを貼り付け...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                await _importFormationFromCode(text);
              }
            },
            child: const Text('取り込む'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFormationFromCode(String code) async {
    try {
      final cleanCode = code.trim();
      String decodedJsonString = "";

      if (cleanCode.startsWith('{')) {
        decodedJsonString = cleanCode;
      } else {
        decodedJsonString = utf8.decode(base64Url.decode(cleanCode));
      }

      final decoded = jsonDecode(decodedJsonString) as Map<String, dynamic>;

      final String name = decoded['name'] ?? '取り込み作戦';
      final historyData = decoded['history'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();

      String finalName = name;
      List<String> savedList =
          prefs.getStringList('saved_formations_list') ?? [];
      int count = 1;
      while (savedList.contains(finalName)) {
        finalName = '$name($count)';
        count++;
      }
      decoded['name'] = finalName;

      await prefs.setString('formation_$finalName', jsonEncode(decoded));
      savedList.add(finalName);
      await prefs.setStringList('saved_formations_list', savedList);

      setState(() {
        history.clear();
        isInitialPositionSaved = decoded['isInitialPositionSaved'] == true;
        currentFormationName = finalName;

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
        isPlaying = false;
        _applySelectedWhiteNumbersIfAvailable();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📥 「$finalName」を取り込みました。「再生」ボタンで再生できます')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ コードが無効か、取り込みに失敗しました')),
      );
    }
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
        isInitialPositionSaved = decoded['isInitialPositionSaved'] == true;
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
        isPlaying = false;
        _applySelectedWhiteNumbersIfAvailable();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📂 「$name」を読み込みました。「再生」ボタンで再生できます')),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (currentFormationName.isNotEmpty)
              Text(
                '作戦名: $currentFormationName',
                style: const TextStyle(
                    fontSize: 11, color: Colors.orangeAccent),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people, color: Colors.orangeAccent),
            tooltip: '選手管理 / 出場5人選択',
            onPressed: widget.onOpenRosterPage,
          ),
        ],
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
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10)),
                            onPressed: isPlaying || isRecording
                                ? null
                                : _showSaveDialog,
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('保存',
                                style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10)),
                            onPressed: isPlaying || isRecording
                                ? null
                                : _showLoadDialog,
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('一覧/共有',
                                style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10)),
                            onPressed: isPlaying || isRecording
                                ? null
                                : _showImportDialog,
                            icon: const Icon(Icons.input, size: 16),
                            label: const Text('LINEから取込',
                                style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[900],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10)),
                            onPressed: isPlaying
                                ? null
                                : () => _clearAllDataAndReset(
                                    courtWidth, courtHeight),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('リセット',
                                style: TextStyle(fontSize: 12)),
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
                                            style: TextStyle(
                                                color: Colors.grey))),
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
    final isWhite = piece.color == Colors.white;
    final numberTextColor = isWhite ? Colors.black : Colors.white;

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
                      color: isWhite ? Colors.white54 : Colors.black87),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}