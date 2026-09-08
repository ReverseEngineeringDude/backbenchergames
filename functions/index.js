const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Computes all winning lines of length winLength on a gridSize x gridSize board.
 */
function getWinLines(gridSize, winLength) {
  const lines = [];
  const n = gridSize;
  const k = winLength;

  // Horizontal rows
  for (let r = 0; r < n; r++) {
    for (let c = 0; c <= n - k; c++) {
      const line = [];
      for (let i = 0; i < k; i++) line.push(r * n + c + i);
      lines.push(line);
    }
  }

  // Vertical columns
  for (let c = 0; c < n; c++) {
    for (let r = 0; r <= n - k; r++) {
      const line = [];
      for (let i = 0; i < k; i++) line.push((r + i) * n + c);
      lines.push(line);
    }
  }

  // Diagonal down-right (\)
  for (let r = 0; r <= n - k; r++) {
    for (let c = 0; c <= n - k; c++) {
      const line = [];
      for (let i = 0; i < k; i++) line.push((r + i) * n + (c + i));
      lines.push(line);
    }
  }

  // Diagonal down-left (/)
  for (let r = 0; r <= n - k; r++) {
    for (let c = k - 1; c < n; c++) {
      const line = [];
      for (let i = 0; i < k; i++) line.push((r + i) * n + (c - i));
      lines.push(line);
    }
  }

  return lines;
}

/**
 * Server-side authoritative validation of Tic-Tac-Toe game result
 * for 3x3 (3 dots), 6x6 (4 dots), and 9x9 (5 dots).
 */
function validateTicTacToeResult(moves, gridSize = 3, winLength = 3) {
  const totalCells = gridSize * gridSize;
  const board = Array(totalCells).fill(null);
  let currentTurn = "X";
  const winLines = getWinLines(gridSize, winLength);

  for (let i = 0; i < moves.length; i++) {
    const move = moves[i].moveData;
    const index = move.index;
    const player = move.player;

    // Check bounds & turn
    if (index < 0 || index >= totalCells) return { valid: false };
    if (board[index] !== null) return { valid: false };
    if (player !== currentTurn) return { valid: false };

    board[index] = player;
    currentTurn = currentTurn === "X" ? "O" : "X";

    // Check for win
    for (const line of winLines) {
      const first = board[line[0]];
      if (first && line.every((idx) => board[idx] === first)) {
        return {
          valid: true,
          isOver: true,
          winner: first,
          isDraw: false,
        };
      }
    }
  }

  // Draw if board is full
  if (moves.length === totalCells) {
    return { valid: true, isOver: true, winner: null, isDraw: true };
  }

  return { valid: true, isOver: false, winner: null, isDraw: false };
}

/**
 * Firestore trigger on room updates:
 * Server-authoritative game completion validation and leaderboard score updates.
 */
exports.onRoomFinished = functions.firestore
  .document("rooms/{roomId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Trigger only when room status transitions to 'finished'
    if (before.status === "finished" || after.status !== "finished") {
      return null;
    }

    const gameId = after.gameId || "tic_tac_toe";
    const moves = after.moves || [];
    const players = after.players || [];

    if (players.length < 2) return null;

    const host = players.find((p) => p.isHost) || players[0];
    const guest = players.find((p) => !p.isHost) || players[1];

    let validatedWinnerSymbol = null;
    let validatedIsDraw = false;

    if (gameId === "tic_tac_toe") {
      const gridSize = (after.stateData && after.stateData.gridSize) || 3;
      const winLength =
        (after.stateData && after.stateData.winLength) ||
        (gridSize === 6 ? 4 : gridSize === 9 ? 5 : 3);

      const result = validateTicTacToeResult(moves, gridSize, winLength);
      if (!result.valid || !result.isOver) {
        console.warn(`Tampered or incomplete game detected in room ${context.params.roomId}`);
        return null;
      }
      validatedWinnerSymbol = result.winner;
      validatedIsDraw = result.isDraw;
    }

    let winnerUid = null;
    let loserUid = null;

    if (!validatedIsDraw && validatedWinnerSymbol) {
      winnerUid = validatedWinnerSymbol === host.symbol ? host.uid : guest.uid;
      loserUid = winnerUid === host.uid ? guest.uid : host.uid;
    }

    // Run batch update to update users and leaderboard entries atomically
    const batch = db.batch();

    const hostRef = db.collection("users").doc(host.uid);
    const guestRef = db.collection("users").doc(guest.uid);
    const hostLbRef = db.collection("leaderboard").doc(gameId).collection("entries").doc(host.uid);
    const guestLbRef = db.collection("leaderboard").doc(gameId).collection("entries").doc(guest.uid);

    const hostDoc = await hostRef.get();
    const guestDoc = await guestRef.get();

    const hostData = hostDoc.exists ? hostDoc.data() : {};
    const guestData = guestDoc.exists ? guestDoc.data() : {};

    const hostStats = (hostData.stats && hostData.stats[gameId]) || {
      wins: 0, losses: 0, draws: 0, currentStreak: 0, bestStreak: 0, rankScore: 1000,
    };
    const guestStats = (guestData.stats && guestData.stats[gameId]) || {
      wins: 0, losses: 0, draws: 0, currentStreak: 0, bestStreak: 0, rankScore: 1000,
    };

    if (validatedIsDraw) {
      hostStats.draws += 1;
      hostStats.currentStreak = 0;
      hostStats.rankScore += 5;

      guestStats.draws += 1;
      guestStats.currentStreak = 0;
      guestStats.rankScore += 5;
    } else if (winnerUid === host.uid) {
      hostStats.wins += 1;
      hostStats.currentStreak += 1;
      hostStats.bestStreak = Math.max(hostStats.bestStreak, hostStats.currentStreak);
      hostStats.rankScore += 25 + (hostStats.currentStreak > 2 ? 10 : 0);

      guestStats.losses += 1;
      guestStats.currentStreak = 0;
      guestStats.rankScore = Math.max(0, guestStats.rankScore - 15);
    } else {
      guestStats.wins += 1;
      guestStats.currentStreak += 1;
      guestStats.bestStreak = Math.max(guestStats.bestStreak, guestStats.currentStreak);
      guestStats.rankScore += 25 + (guestStats.currentStreak > 2 ? 10 : 0);

      hostStats.losses += 1;
      hostStats.currentStreak = 0;
      hostStats.rankScore = Math.max(0, hostStats.rankScore - 15);
    }

    // Write updated stats to users/{uid}
    batch.set(hostRef, { stats: { [gameId]: hostStats } }, { merge: true });
    batch.set(guestRef, { stats: { [gameId]: guestStats } }, { merge: true });

    // Write server-authoritative leaderboard entry
    batch.set(hostLbRef, {
      uid: host.uid,
      displayName: host.displayName || "Player",
      avatarUrl: host.avatarUrl || "",
      gameId: gameId,
      wins: hostStats.wins,
      losses: hostStats.losses,
      draws: hostStats.draws,
      rankScore: hostStats.rankScore,
      currentStreak: hostStats.currentStreak,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    batch.set(guestLbRef, {
      uid: guest.uid,
      displayName: guest.displayName || "Player",
      avatarUrl: guest.avatarUrl || "",
      gameId: gameId,
      wins: guestStats.wins,
      losses: guestStats.losses,
      draws: guestStats.draws,
      rankScore: guestStats.rankScore,
      currentStreak: guestStats.currentStreak,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    console.log(`Successfully updated scores and leaderboard for room ${context.params.roomId}`);
    return null;
  });
