import '../../core/models/game_over_result.dart';

/// Immutable representation of a Tic-Tac-Toe move.
class TicTacToeMove {
  final int index;
  final String player; // 'X' or 'O'

  const TicTacToeMove({required this.index, required this.player});

  Map<String, dynamic> toJson() => {
        'index': index,
        'player': player,
      };

  factory TicTacToeMove.fromJson(Map<String, dynamic> json) {
    return TicTacToeMove(
      index: json['index'] as int,
      player: json['player'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicTacToeMove &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          player == other.player;

  @override
  int get hashCode => Object.hash(index, player);

  @override
  String toString() => 'TicTacToeMove($player at $index)';
}

/// Immutable representation of the Tic-Tac-Toe game state supporting
/// 3x3 (3 to win), 6x6 (4 to win), and 9x9 (5 to win).
class TicTacToeState {
  /// Grid dimension N (e.g. 3 for 3x3, 6 for 6x6, 9 for 9x9).
  final int gridSize;

  /// Number of consecutive marks required to win (3, 4, or 5).
  final int winLength;

  /// Board array of length gridSize * gridSize, storing 'X', 'O', or null.
  final List<String?> board;

  /// Player whose turn it is: 'X' or 'O'.
  final String currentTurn;

  /// Number of moves made so far.
  final int moveCount;

  /// The cell index of the most recent move (if any).
  final int? lastMoveIndex;

  const TicTacToeState({
    this.gridSize = 3,
    this.winLength = 3,
    required this.board,
    required this.currentTurn,
    this.moveCount = 0,
    this.lastMoveIndex,
  });

  factory TicTacToeState.initial({int gridSize = 3}) {
    final winLength = TicTacToeLogic.winLengthForGrid(gridSize);
    return TicTacToeState(
      gridSize: gridSize,
      winLength: winLength,
      board: List<String?>.filled(gridSize * gridSize, null),
      currentTurn: 'X',
      moveCount: 0,
      lastMoveIndex: null,
    );
  }

  int get totalCells => gridSize * gridSize;

  TicTacToeState copyWith({
    int? gridSize,
    int? winLength,
    List<String?>? board,
    String? currentTurn,
    int? moveCount,
    int? lastMoveIndex,
  }) {
    return TicTacToeState(
      gridSize: gridSize ?? this.gridSize,
      winLength: winLength ?? this.winLength,
      board: board ?? List<String?>.from(this.board),
      currentTurn: currentTurn ?? this.currentTurn,
      moveCount: moveCount ?? this.moveCount,
      lastMoveIndex: lastMoveIndex ?? this.lastMoveIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'winLength': winLength,
        'board': board,
        'currentTurn': currentTurn,
        'moveCount': moveCount,
        'lastMoveIndex': lastMoveIndex,
      };

  factory TicTacToeState.fromJson(Map<String, dynamic> json) {
    final gridSize = json['gridSize'] as int? ?? 3;
    final winLength = json['winLength'] as int? ??
        TicTacToeLogic.winLengthForGrid(gridSize);
    final totalCells = gridSize * gridSize;

    return TicTacToeState(
      gridSize: gridSize,
      winLength: winLength,
      board: (json['board'] as List<dynamic>?)
              ?.map((e) => e as String?)
              .toList() ??
          List<String?>.filled(totalCells, null),
      currentTurn: json['currentTurn'] as String? ?? 'X',
      moveCount: json['moveCount'] as int? ?? 0,
      lastMoveIndex: json['lastMoveIndex'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TicTacToeState) return false;
    if (gridSize != other.gridSize ||
        winLength != other.winLength ||
        currentTurn != other.currentTurn ||
        moveCount != other.moveCount ||
        lastMoveIndex != other.lastMoveIndex) {
      return false;
    }
    if (board.length != other.board.length) return false;
    for (int i = 0; i < board.length; i++) {
      if (board[i] != other.board[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        gridSize,
        winLength,
        Object.hashAll(board),
        currentTurn,
        moveCount,
        lastMoveIndex,
      );
}

/// Pure business logic for generalized Tic-Tac-Toe rules.
/// Supports 3x3 (3 dots), 6x6 (4 dots), and 9x9 (5 dots).
class TicTacToeLogic {
  static final Map<int, List<List<int>>> _winLinesCache = {};

  /// Returns required dots in a row to win for a given grid size.
  /// 3x3 -> 3 dots
  /// 6x6 -> 4 dots
  /// 9x9 -> 5 dots
  static int winLengthForGrid(int gridSize) {
    switch (gridSize) {
      case 6:
        return 4;
      case 9:
        return 5;
      case 3:
      default:
        return 3;
    }
  }

  static TicTacToeState initialState({int gridSize = 3}) =>
      TicTacToeState.initial(gridSize: gridSize);

  /// Computes or retrieves cached winning lines for (gridSize, winLength).
  static List<List<int>> getWinLines(int gridSize, int winLength) {
    final key = gridSize * 100 + winLength;
    final cached = _winLinesCache[key];
    if (cached != null) return cached;

    final lines = <List<int>>[];
    final n = gridSize;
    final k = winLength;

    // Horizontal rows
    for (int r = 0; r < n; r++) {
      for (int c = 0; c <= n - k; c++) {
        final line = <int>[];
        for (int i = 0; i < k; i++) {
          line.add(r * n + c + i);
        }
        lines.add(line);
      }
    }

    // Vertical columns
    for (int c = 0; c < n; c++) {
      for (int r = 0; r <= n - k; r++) {
        final line = <int>[];
        for (int i = 0; i < k; i++) {
          line.add((r + i) * n + c);
        }
        lines.add(line);
      }
    }

    // Diagonal down-right (\)
    for (int r = 0; r <= n - k; r++) {
      for (int c = 0; c <= n - k; c++) {
        final line = <int>[];
        for (int i = 0; i < k; i++) {
          line.add((r + i) * n + (c + i));
        }
        lines.add(line);
      }
    }

    // Diagonal down-left (/)
    for (int r = 0; r <= n - k; r++) {
      for (int c = k - 1; c < n; c++) {
        final line = <int>[];
        for (int i = 0; i < k; i++) {
          line.add((r + i) * n + (c - i));
        }
        lines.add(line);
      }
    }

    _winLinesCache[key] = lines;
    return lines;
  }

  static bool isValidMove(TicTacToeState state, TicTacToeMove move) {
    if (move.index < 0 || move.index >= state.totalCells) return false;
    if (state.board[move.index] != null) return false;
    if (move.player != state.currentTurn) return false;
    if (checkGameOver(state).isOver) return false;
    return true;
  }

  static TicTacToeState applyMove(TicTacToeState state, TicTacToeMove move) {
    if (!isValidMove(state, move)) {
      throw ArgumentError(
        'Invalid move: $move for state current turn: ${state.currentTurn}',
      );
    }

    final newBoard = List<String?>.from(state.board);
    newBoard[move.index] = move.player;

    return TicTacToeState(
      gridSize: state.gridSize,
      winLength: state.winLength,
      board: newBoard,
      currentTurn: state.currentTurn == 'X' ? 'O' : 'X',
      moveCount: state.moveCount + 1,
      lastMoveIndex: move.index,
    );
  }

  static GameOverResult checkGameOver(TicTacToeState state) {
    final winLines = getWinLines(state.gridSize, state.winLength);

    for (final line in winLines) {
      final firstSymbol = state.board[line[0]];
      if (firstSymbol == null) continue;

      bool match = true;
      for (int i = 1; i < line.length; i++) {
        if (state.board[line[i]] != firstSymbol) {
          match = false;
          break;
        }
      }

      if (match) {
        return GameOverResult.win(firstSymbol, winningIndices: line);
      }
    }

    // Check draw
    if (state.board.every((cell) => cell != null)) {
      return GameOverResult.draw;
    }

    return GameOverResult.notOver;
  }

  /// Returns indices of all empty cells available for moves.
  static List<int> getAvailableMoves(TicTacToeState state) {
    final moves = <int>[];
    for (int i = 0; i < state.totalCells; i++) {
      if (state.board[i] == null) {
        moves.add(i);
      }
    }
    return moves;
  }
}
