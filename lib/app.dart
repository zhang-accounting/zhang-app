import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/theme/app_theme.dart';
import 'l10n/l10n.dart';
import 'router.dart';

/// Root widget: Material 3 light/dark theme, zh/en localisation, go_router.
class ZhangApp extends ConsumerWidget {
  const ZhangApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: zhangLightTheme,
      darkTheme: zhangDarkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveAppLocale,
      routerConfig: router,
    );
  }
}

/// Chinese for any `zh*` device locale, otherwise English. Also sets
/// `Intl.defaultLocale` so `DateFormat`/`NumberFormat` follow the app locale.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  Locale result = const Locale('en');
  for (final locale in preferred ?? const <Locale>[]) {
    if (locale.languageCode == 'zh') {
      result = const Locale('zh');
      break;
    }
    if (locale.languageCode == 'en') break;
  }
  Intl.defaultLocale = result.languageCode;
  return result;
}
