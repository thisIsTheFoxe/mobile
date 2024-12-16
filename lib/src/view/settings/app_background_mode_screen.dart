import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/settings/general_preferences.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';

class AppBackgroundModeScreen extends StatelessWidget {
  const AppBackgroundModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(androidBuilder: _androidBuilder, iosBuilder: _iosBuilder);
  }

  Widget _androidBuilder(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(context.l10n.background)), body: _Body());
  }

  Widget _iosBuilder(BuildContext context) {
    return CupertinoPageScaffold(navigationBar: const CupertinoNavigationBar(), child: _Body());
  }

  static String themeTitle(BuildContext context, BackgroundThemeMode theme) {
    switch (theme) {
      case BackgroundThemeMode.system:
        return context.l10n.deviceTheme;
      case BackgroundThemeMode.dark:
        return context.l10n.dark;
      case BackgroundThemeMode.light:
        return context.l10n.light;
    }
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(generalPreferencesProvider.select((state) => state.themeMode));

    void onChanged(BackgroundThemeMode? value) => ref
        .read(generalPreferencesProvider.notifier)
        .setThemeMode(value ?? BackgroundThemeMode.system);

    return SafeArea(
      child: ListView(
        children: [
          ChoicePicker(
            choices: BackgroundThemeMode.values,
            selectedItem: themeMode,
            titleBuilder: (t) => Text(AppBackgroundModeScreen.themeTitle(context, t)),
            onSelectedItemChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
