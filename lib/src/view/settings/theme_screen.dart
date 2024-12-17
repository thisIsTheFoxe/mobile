import 'dart:ui' show ImageFilter;
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/general_preferences.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/color_palette.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/settings/board_theme_screen.dart';
import 'package:lichess_mobile/src/view/settings/piece_set_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/adaptive_choice_picker.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/change_colors.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_alert_dialog.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';

const _kBoardSize = 200.0;

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(
      androidBuilder: (context) => const Scaffold(body: _Body()),
      iosBuilder:
          (context) => CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              automaticBackgroundVisibility: false,
              backgroundColor: Styles.cupertinoAppBarColor
                  .resolveFrom(context)
                  .withValues(alpha: 0.0),
              border: null,
            ),
            child: const _Body(),
          ),
    );
  }
}

String shapeColorL10n(BuildContext context, ShapeColor shapeColor) =>
// TODO add l10n
switch (shapeColor) {
  ShapeColor.green => 'Green',
  ShapeColor.red => 'Red',
  ShapeColor.blue => 'Blue',
  ShapeColor.yellow => 'Yellow',
};

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late double brightness;
  late double hue;

  double headerOpacity = 0;

  bool openAdjustColorSection = false;

  @override
  void initState() {
    super.initState();
    final boardPrefs = ref.read(boardPreferencesProvider);
    brightness = boardPrefs.brightness;
    hue = boardPrefs.hue;
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification && notification.depth == 0) {
      final ScrollMetrics metrics = notification.metrics;
      double scrollExtent = 0.0;
      switch (metrics.axisDirection) {
        case AxisDirection.up:
          scrollExtent = metrics.extentAfter;
        case AxisDirection.down:
          scrollExtent = metrics.extentBefore;
        case AxisDirection.right:
        case AxisDirection.left:
          break;
      }

      final opacity = scrollExtent > 0.0 ? 1.0 : 0.0;

      if (opacity != headerOpacity) {
        setState(() {
          headerOpacity = opacity;
        });
      }
    }
    return false;
  }

  void _showColorPicker() {
    final generalPrefs = ref.read(generalPreferencesProvider);
    showAdaptiveDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool useDefault = generalPrefs.customThemeSeed == null;
        Color color = generalPrefs.customThemeSeed ?? kDefaultSeedColor;
        return StatefulBuilder(
          builder: (context, setState) {
            return PlatformAlertDialog(
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColorPicker(
                      enableAlpha: false,
                      pickerColor: color,
                      onColorChanged: (c) {
                        setState(() {
                          useDefault = false;
                          color = c;
                        });
                      },
                    ),
                    SecondaryButton(
                      semanticsLabel: 'Default color',
                      onPressed:
                          !useDefault
                              ? () {
                                setState(() {
                                  useDefault = true;
                                  color = kDefaultSeedColor;
                                });
                              }
                              : null,
                      child: const Text('Default color'),
                    ),
                    SecondaryButton(
                      semanticsLabel: context.l10n.cancel,
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: Text(context.l10n.cancel),
                    ),
                    SecondaryButton(
                      semanticsLabel: context.l10n.ok,
                      onPressed: () {
                        if (useDefault) {
                          Navigator.of(context).pop(null);
                        } else {
                          Navigator.of(context).pop(color);
                        }
                      },
                      child: Text(context.l10n.ok),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((color) {
      if (color != false) {
        ref.read(generalPreferencesProvider.notifier).setCustomThemeSeed(color as Color?);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final generalPrefs = ref.watch(generalPreferencesProvider);
    final boardPrefs = ref.watch(boardPreferencesProvider);

    final bool hasAjustedColors = brightness != 0.0 || hue != 0.0;

    final backgroundColor = Styles.cupertinoAppBarColor.resolveFrom(context);

    return NotificationListener(
      onNotification: handleScrollNotification,
      child: CustomScrollView(
        slivers: [
          if (Theme.of(context).platform == TargetPlatform.iOS)
            PinnedHeaderSliver(
              child: ClipRect(
                child: BackdropFilter(
                  enabled: backgroundColor.alpha != 0xFF,
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: ShapeDecoration(
                      color: headerOpacity == 1.0 ? backgroundColor : backgroundColor.withAlpha(0),
                      shape: LinearBorder.bottom(
                        side: BorderSide(
                          color:
                              headerOpacity == 1.0 ? const Color(0x4D000000) : Colors.transparent,
                          width: 0.0,
                        ),
                      ),
                    ),
                    padding:
                        Styles.bodyPadding +
                        EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
                    child: _BoardPreview(boardPrefs: boardPrefs, brightness: brightness, hue: hue),
                  ),
                ),
              ),
            )
          else
            SliverAppBar(
              pinned: true,
              title: const Text('Theme'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(_kBoardSize + 16.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: _BoardPreview(boardPrefs: boardPrefs, brightness: brightness, hue: hue),
                ),
              ),
            ),
          SliverList.list(
            children: [
              ListSection(
                hasLeading: true,
                children: [
                  SettingsListTile(
                    icon: const Icon(LichessIcons.chess_board),
                    settingsLabel: Text(context.l10n.board),
                    settingsValue: boardPrefs.boardTheme.label,
                    onTap: () {
                      pushPlatformRoute(
                        context,
                        title: context.l10n.board,
                        builder: (context) => const BoardThemeScreen(),
                      );
                    },
                  ),
                  SettingsListTile(
                    icon: const Icon(LichessIcons.chess_pawn),
                    settingsLabel: Text(context.l10n.pieceSet),
                    settingsValue: boardPrefs.pieceSet.label,
                    onTap: () {
                      pushPlatformRoute(
                        context,
                        title: context.l10n.pieceSet,
                        builder: (context) => const PieceSetScreen(),
                      );
                    },
                  ),
                  SettingsListTile(
                    icon: const Icon(LichessIcons.arrow_full_upperright),
                    settingsLabel: const Text('Shape color'),
                    settingsValue: shapeColorL10n(context, boardPrefs.shapeColor),
                    onTap: () {
                      showChoicePicker(
                        context,
                        choices: ShapeColor.values,
                        selectedItem: boardPrefs.shapeColor,
                        labelBuilder:
                            (t) => Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: shapeColorL10n(context, t)),
                                  const TextSpan(text: '   '),
                                  WidgetSpan(
                                    child: Container(width: 15, height: 15, color: t.color),
                                  ),
                                ],
                              ),
                            ),
                        onSelectedItemChanged: (ShapeColor? value) {
                          ref
                              .read(boardPreferencesProvider.notifier)
                              .setShapeColor(value ?? ShapeColor.green);
                        },
                      );
                    },
                  ),
                  SwitchSettingTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(context.l10n.preferencesBoardCoordinates),
                    value: boardPrefs.coordinates,
                    onChanged: (value) {
                      ref.read(boardPreferencesProvider.notifier).toggleCoordinates();
                    },
                  ),
                  SwitchSettingTile(
                    // TODO translate
                    leading: const Icon(Icons.border_outer),
                    title: const Text('Show border'),
                    value: boardPrefs.showBorder,
                    onChanged: (value) {
                      ref.read(boardPreferencesProvider.notifier).toggleBorder();
                    },
                  ),
                ],
              ),
              ListSection(
                header: SettingsSectionTitle(context.l10n.advancedSettings),
                hasLeading: true,
                children: [
                  PlatformListTile(
                    leading: const Icon(Icons.brightness_6),
                    title: Slider.adaptive(
                      min: -0.5,
                      max: 0.5,
                      value: brightness,
                      onChanged: (value) {
                        setState(() {
                          brightness = value;
                        });
                      },
                      onChangeEnd: (value) {
                        ref
                            .read(boardPreferencesProvider.notifier)
                            .adjustColors(brightness: brightness);
                      },
                    ),
                  ),
                  PlatformListTile(
                    leading: const Icon(Icons.invert_colors),
                    title: Slider.adaptive(
                      min: -1.0,
                      max: 1.0,
                      value: hue,
                      onChanged: (value) {
                        setState(() {
                          hue = value;
                        });
                      },
                      onChangeEnd: (value) {
                        ref.read(boardPreferencesProvider.notifier).adjustColors(hue: hue);
                      },
                    ),
                  ),
                  PlatformListTile(
                    leading: Opacity(
                      opacity: hasAjustedColors ? 1.0 : 0.5,
                      child: const Icon(Icons.cancel),
                    ),
                    title: Opacity(
                      opacity: hasAjustedColors ? 1.0 : 0.5,
                      child: Text(context.l10n.boardReset),
                    ),
                    onTap:
                        hasAjustedColors
                            ? () {
                              setState(() {
                                brightness = 0.0;
                                hue = 0.0;
                              });
                              ref
                                  .read(boardPreferencesProvider.notifier)
                                  .adjustColors(brightness: 0.0, hue: 0.0);
                            }
                            : null,
                  ),
                  PlatformListTile(
                    leading: const Icon(Icons.colorize_outlined),
                    title: const Text('App theme'),
                    trailing: switch (generalPrefs.appThemeSeed) {
                      AppThemeSeed.board => Text(context.l10n.board),
                      AppThemeSeed.system => Text(context.l10n.mobileSystemColors),
                      AppThemeSeed.color =>
                        generalPrefs.customThemeSeed != null
                            ? Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: generalPrefs.customThemeSeed,
                                shape: BoxShape.circle,
                              ),
                            )
                            : Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: kDefaultSeedColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                    },
                    onTap: () {
                      showAdaptiveActionSheet<void>(
                        context: context,
                        actions:
                            AppThemeSeed.values
                                .where((t) => t != AppThemeSeed.system || getCorePalette() != null)
                                .map(
                                  (t) => BottomSheetAction(
                                    makeLabel:
                                        (context) => switch (t) {
                                          AppThemeSeed.board => Text(context.l10n.board),
                                          AppThemeSeed.system => Text(
                                            context.l10n.mobileSystemColors,
                                          ),
                                          AppThemeSeed.color => const Text('Custom color'),
                                        },
                                    onPressed: (context) {
                                      ref
                                          .read(generalPreferencesProvider.notifier)
                                          .setAppThemeSeed(t);

                                      if (t == AppThemeSeed.color) {
                                        _showColorPicker();
                                      }
                                    },
                                    dismissOnPress: true,
                                  ),
                                )
                                .toList(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(child: SizedBox(height: 16.0)),
          ),
        ],
      ),
    );
  }
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.boardPrefs, required this.brightness, required this.hue});

  final BoardPrefs boardPrefs;
  final double brightness;
  final double hue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ChangeColors(
        brightness: brightness,
        hue: hue,
        child: Chessboard.fixed(
          size: _kBoardSize,
          orientation: Side.white,
          lastMove: const NormalMove(from: Square.e2, to: Square.e4),
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          shapes:
              <Shape>{
                Circle(color: boardPrefs.shapeColor.color, orig: Square.fromName('b8')),
                Arrow(
                  color: boardPrefs.shapeColor.color,
                  orig: Square.fromName('b8'),
                  dest: Square.fromName('c6'),
                ),
              }.lock,
          settings: boardPrefs.toBoardSettings().copyWith(
            brightness: 0.0,
            hue: 0.0,
            borderRadius: const BorderRadius.all(Radius.circular(4.0)),
            boxShadow: boardShadows,
          ),
        ),
      ),
    );
  }
}
