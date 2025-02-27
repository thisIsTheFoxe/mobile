import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/auth/auth_session.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_service.dart';
import 'package:lichess_mobile/src/model/game/game_repository_providers.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_angle.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_difficulty.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_opening.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_preferences.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_providers.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_service.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_theme.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/navigation.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/utils/immersive_mode.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/share.dart';
import 'package:lichess_mobile/src/view/account/rating_pref_aware.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_screen.dart';
import 'package:lichess_mobile/src/view/game/archived_game_screen.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_feedback_widget.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_session_widget.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_settings_screen.dart';
import 'package:lichess_mobile/src/view/settings/toggle_sound_button.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_choice_picker.dart';
import 'package:lichess_mobile/src/widgets/board_table.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  /// Creates a new puzzle screen.
  ///
  /// If [puzzleId] is provided, the screen will load the puzzle with that id. Otherwise, it will load the next puzzle from the queue.
  const PuzzleScreen({required this.angle, this.puzzleId, super.key});

  final PuzzleAngle angle;
  final PuzzleId? puzzleId;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route is PageRoute) {
      rootNavPageRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    rootNavPageRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPop() {
    super.didPop();
    if (mounted) {
      ref.invalidate(nextPuzzleProvider(widget.angle));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WakelockWidget(
      child: PlatformScaffold(
        appBar: PlatformAppBar(
          actions: const [ToggleSoundButton(), _PuzzleSettingsButton()],
          title: _Title(angle: widget.angle),
        ),
        body:
            widget.puzzleId != null
                ? _LoadPuzzleFromId(angle: widget.angle, id: widget.puzzleId!)
                : _LoadNextPuzzle(angle: widget.angle),
      ),
    );
  }
}

class _Title extends ConsumerWidget {
  const _Title({required this.angle});

  final PuzzleAngle angle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (angle) {
      PuzzleTheme(themeKey: final key) =>
        key == PuzzleThemeKey.mix
            ? Text(context.l10n.puzzleDesc)
            : Text(key.l10n(context.l10n).name),
      PuzzleOpening(key: final key) => ref
          .watch(puzzleOpeningNameProvider(key))
          .when(
            data: (data) => Text(data),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Text(key.replaceAll('_', ' ')),
          ),
    };
  }
}

class _LoadNextPuzzle extends ConsumerWidget {
  const _LoadNextPuzzle({required this.angle});

  final PuzzleAngle angle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextPuzzle = ref.watch(nextPuzzleProvider(angle));

    return nextPuzzle.when(
      data: (data) {
        if (data == null) {
          return const Center(
            child: BoardTable(
              fen: kEmptyFen,
              orientation: Side.white,
              errorMessage: 'No more puzzles. Go online to get more.',
            ),
          );
        } else {
          return _Body(initialPuzzleContext: data);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, s) {
        debugPrint('SEVERE: [PuzzleScreen] could not load next puzzle; $e\n$s');
        return Center(
          child: BoardTable(fen: kEmptyFen, orientation: Side.white, errorMessage: e.toString()),
        );
      },
    );
  }
}

class _LoadPuzzleFromId extends ConsumerWidget {
  const _LoadPuzzleFromId({required this.angle, required this.id});

  final PuzzleAngle angle;
  final PuzzleId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzle = ref.watch(puzzleProvider(id));
    final session = ref.watch(authSessionProvider);

    return puzzle.when(
      data: (data) {
        return _Body(
          initialPuzzleContext: PuzzleContext(
            angle: const PuzzleTheme(PuzzleThemeKey.mix),
            puzzle: data,
            userId: session?.user.id,
          ),
        );
      },
      loading:
          () => const Column(
            children: [
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: BoardTable.empty(showEngineGaugePlaceholder: true),
                ),
              ),
              PlatformBottomBar.empty(),
            ],
          ),
      error: (e, s) {
        debugPrint('SEVERE: [PuzzleScreen] could not load next puzzle; $e\n$s');
        return Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: BoardTable(
                  fen: kEmptyFen,
                  orientation: Side.white,
                  errorMessage: e.toString(),
                ),
              ),
            ),
            const SizedBox(height: kBottomBarHeight),
          ],
        );
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.initialPuzzleContext});

  final PuzzleContext initialPuzzleContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrlProvider = puzzleControllerProvider(initialPuzzleContext);
    final puzzleState = ref.watch(ctrlProvider);

    final boardPreferences = ref.watch(boardPreferencesProvider);

    final currentEvalBest = ref.watch(engineEvaluationProvider.select((s) => s.eval?.bestMove));
    final evalBestMove = (currentEvalBest ?? puzzleState.node.eval?.bestMove) as NormalMove?;

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: BoardTable(
              orientation: puzzleState.pov,
              fen: puzzleState.fen,
              lastMove: puzzleState.lastMove as NormalMove?,
              gameData: GameData(
                playerSide:
                    puzzleState.mode == PuzzleMode.load || puzzleState.position.isGameOver
                        ? PlayerSide.none
                        : puzzleState.mode == PuzzleMode.view
                        ? PlayerSide.both
                        : puzzleState.pov == Side.white
                        ? PlayerSide.white
                        : PlayerSide.black,
                isCheck: boardPreferences.boardHighlights && puzzleState.position.isCheck,
                sideToMove: puzzleState.position.turn,
                validMoves: puzzleState.validMoves,
                promotionMove: puzzleState.promotionMove,
                onMove: (move, {isDrop}) {
                  ref.read(ctrlProvider.notifier).onUserPreMove(move);
                },
                onPromotionSelection: (role) {
                  ref.read(ctrlProvider.notifier).onPromotionSelection(role);
                },
              ),
              shapes:
                  puzzleState.isEngineEnabled && evalBestMove != null
                      ? ISet([
                        Arrow(
                          color: const Color(0x66003088),
                          orig: evalBestMove.from,
                          dest: evalBestMove.to,
                        ),
                      ])
                      : null,
              engineGauge:
                  puzzleState.isEngineEnabled
                      ? (
                        orientation: puzzleState.pov,
                        isLocalEngineAvailable: true,
                        position: puzzleState.position,
                        savedEval: puzzleState.node.eval,
                      )
                      : null,
              showEngineGaugePlaceholder: true,
              topTable: Center(
                child: PuzzleFeedbackWidget(
                  puzzle: puzzleState.puzzle,
                  state: puzzleState,
                  onStreak: false,
                ),
              ),
              bottomTable: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (puzzleState.glicko != null)
                    RatingPrefAware(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Row(
                          children: [
                            Text(context.l10n.rating),
                            const SizedBox(width: 5.0),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: puzzleState.glicko!.rating,
                                end:
                                    puzzleState.nextContext?.glicko?.rating ??
                                    puzzleState.glicko!.rating,
                              ),
                              duration: const Duration(milliseconds: 500),
                              builder: (context, double rating, _) {
                                return Text(
                                  rating.truncate().toString(),
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  PuzzleSessionWidget(
                    initialPuzzleContext: initialPuzzleContext,
                    ctrlProvider: ctrlProvider,
                  ),
                ],
              ),
            ),
          ),
        ),
        _BottomBar(initialPuzzleContext: initialPuzzleContext, ctrlProvider: ctrlProvider),
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.initialPuzzleContext, required this.ctrlProvider});

  final PuzzleContext initialPuzzleContext;
  final PuzzleControllerProvider ctrlProvider;

  static const _repeatTriggerDelays = [
    Duration(milliseconds: 500),
    Duration(milliseconds: 250),
    Duration(milliseconds: 100),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzleState = ref.watch(ctrlProvider);
    final isDailyPuzzle = puzzleState.puzzle.isDailyPuzzle == true;

    return PlatformBottomBar(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (initialPuzzleContext.userId != null &&
            !isDailyPuzzle &&
            puzzleState.mode != PuzzleMode.view)
          _DifficultySelector(
            initialPuzzleContext: initialPuzzleContext,
            ctrlProvider: ctrlProvider,
          ),
        if (puzzleState.mode != PuzzleMode.view)
          BottomBarButton(
            icon: Icons.help,
            label: puzzleState.premoves.toString(),
            showLabel: true,
            onTap:
                puzzleState.canViewSolution
                    ? () => ref.read(ctrlProvider.notifier).viewSolution()
                    : null,
          ),
        if (puzzleState.premoves.isNotEmpty)
          BottomBarButton(
            icon: Icons.check,
            label: 'Complete premoves',
            showLabel: true,
            onTap:
                puzzleState.canViewSolution
                    ? () => ref.read(ctrlProvider.notifier).completePremoves()
                    : null,
          ),
        if (puzzleState.mode == PuzzleMode.view)
          BottomBarButton(
            label: context.l10n.menu,
            onTap: () {
              _showPuzzleMenu(context, ref);
            },
            icon: Icons.menu,
          ),
        if (puzzleState.mode == PuzzleMode.view)
          BottomBarButton(
            onTap: () {
              ref.read(ctrlProvider.notifier).toggleLocalEvaluation();
            },
            label: context.l10n.toggleLocalEvaluation,
            icon: CupertinoIcons.gauge,
            highlighted: puzzleState.isLocalEvalEnabled,
          ),
        if (puzzleState.mode == PuzzleMode.view)
          RepeatButton(
            triggerDelays: _repeatTriggerDelays,
            onLongPress: puzzleState.canGoBack ? () => _moveBackward(ref) : null,
            child: BottomBarButton(
              onTap: puzzleState.canGoBack ? () => _moveBackward(ref) : null,
              label: 'Previous',
              icon: CupertinoIcons.chevron_back,
              showTooltip: false,
            ),
          ),
        if (puzzleState.mode == PuzzleMode.view)
          RepeatButton(
            triggerDelays: _repeatTriggerDelays,
            onLongPress: puzzleState.canGoNext ? () => _moveForward(ref) : null,
            child: BottomBarButton(
              onTap: puzzleState.canGoNext ? () => _moveForward(ref) : null,
              label: context.l10n.next,
              icon: CupertinoIcons.chevron_forward,
              showTooltip: false,
              blink: puzzleState.viewedSolutionRecently,
            ),
          ),
        if (puzzleState.mode == PuzzleMode.view)
          BottomBarButton(
            onTap:
                puzzleState.mode == PuzzleMode.view && puzzleState.nextContext != null
                    ? () => ref.read(ctrlProvider.notifier).onLoadPuzzle(puzzleState.nextContext!)
                    : null,
            highlighted: true,
            label: context.l10n.puzzleContinueTraining,
            icon: CupertinoIcons.play_arrow_solid,
          ),
      ],
    );
  }

  Future<void> _showPuzzleMenu(BuildContext context, WidgetRef ref) {
    final puzzleState = ref.watch(ctrlProvider);
    return showAdaptiveActionSheet(
      context: context,
      actions: [
        BottomSheetAction(
          makeLabel: (context) => Text(context.l10n.mobileSharePuzzle),
          onPressed: (context) {
            launchShareDialog(
              context,
              text: lichessUri('/training/${puzzleState.puzzle.puzzle.id}').toString(),
            );
          },
        ),
        BottomSheetAction(
          makeLabel: (context) => Text(context.l10n.analysis),
          onPressed: (context) {
            pushPlatformRoute(
              context,
              builder:
                  (context) => AnalysisScreen(
                    options: AnalysisOptions(
                      orientation: puzzleState.pov,
                      standalone: (
                        pgn: ref.read(ctrlProvider.notifier).makePgn(),
                        isComputerAnalysisAllowed: true,
                        variant: Variant.standard,
                      ),
                      initialMoveCursor: 0,
                    ),
                  ),
            );
          },
        ),
        BottomSheetAction(
          makeLabel:
              (context) => Text(context.l10n.puzzleFromGameLink(puzzleState.puzzle.game.id.value)),
          onPressed: (_) async {
            final game = await ref.read(
              archivedGameProvider(id: puzzleState.puzzle.game.id).future,
            );
            if (context.mounted) {
              pushPlatformRoute(
                context,
                builder:
                    (context) => ArchivedGameScreen(
                      gameData: game.data,
                      orientation: puzzleState.pov,
                      initialCursor: puzzleState.puzzle.puzzle.initialPly + 1,
                    ),
              );
            }
          },
        ),
      ],
    );
  }

  void _moveForward(WidgetRef ref) {
    ref.read(ctrlProvider.notifier).userNext();
  }

  void _moveBackward(WidgetRef ref) {
    ref.read(ctrlProvider.notifier).userPrevious();
  }
}

class _DifficultySelector extends ConsumerWidget {
  const _DifficultySelector({required this.initialPuzzleContext, required this.ctrlProvider});

  final PuzzleContext initialPuzzleContext;
  final PuzzleControllerProvider ctrlProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final difficulty = ref.watch(puzzlePreferencesProvider.select((state) => state.difficulty));
    final state = ref.watch(ctrlProvider);
    final connectivity = ref.watch(connectivityChangesProvider);
    return connectivity.when(
      data:
          (data) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              PuzzleDifficulty selectedDifficulty = difficulty;
              return BottomBarButton(
                icon: Icons.tune,
                label: puzzleDifficultyL10n(context, difficulty),
                tooltip: context.l10n.puzzleDifficultyLevel,
                showLabel: true,
                onTap:
                    !data.isOnline || state.isChangingDifficulty
                        ? null
                        : () {
                          showChoicePicker(
                            context,
                            choices: PuzzleDifficulty.values,
                            selectedItem: difficulty,
                            labelBuilder: (t) => Text(puzzleDifficultyL10n(context, t)),
                            onSelectedItemChanged: (PuzzleDifficulty? d) {
                              if (d != null) {
                                setState(() {
                                  selectedDifficulty = d;
                                });
                              }
                            },
                          ).then((_) async {
                            if (selectedDifficulty == difficulty) {
                              return;
                            }
                            final nextContext = await ref
                                .read(ctrlProvider.notifier)
                                .changeDifficulty(selectedDifficulty);
                            if (context.mounted && nextContext != null) {
                              ref.read(ctrlProvider.notifier).onLoadPuzzle(nextContext);
                            }
                          });
                        },
              );
            },
          ),
      loading: () => const ButtonLoadingIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PuzzleSettingsButton extends StatelessWidget {
  const _PuzzleSettingsButton();

  @override
  Widget build(BuildContext context) {
    return AppBarIconButton(
      onPressed:
          () => showAdaptiveBottomSheet<void>(
            context: context,
            isDismissible: true,
            isScrollControlled: true,
            showDragHandle: true,
            constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.5),
            builder: (_) => const PuzzleSettingsScreen(),
          ),
      semanticsLabel: context.l10n.settingsSettings,
      icon: const Icon(Icons.settings),
    );
  }
}
