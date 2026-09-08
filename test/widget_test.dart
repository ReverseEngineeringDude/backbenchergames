import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:backbenchgames/core/plugin/game_registry.dart';
import 'package:backbenchgames/games/tic_tac_toe/tic_tac_toe_plugin.dart';
import 'package:backbenchgames/main.dart';

void main() {
  setUp(() {
    GameRegistry().register(TicTacToePlugin());
  });

  testWidgets('App renders Home Lobby with game modes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BackbenchGamesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BACKBENCH GAMES'), findsOneWidget);
    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.text('Pass & Play'), findsOneWidget);
    expect(find.text('vs Computer'), findsOneWidget);
    expect(find.text('Online Multiplayer'), findsOneWidget);
  });
}
