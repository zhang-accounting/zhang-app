import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/app.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/ledger_session.dart';

/// The app pumped as `bootstrap()` builds it: [ZhangApp] in a
/// [LedgerSessionHost] (one provider container per active profile).
class AppHost {
  AppHost(this._tester);

  final WidgetTester _tester;

  /// The container of the current ledger session; a new one after every
  /// switch / edit of the active profile (do not keep it across one).
  ProviderContainer get container => ProviderScope.containerOf(_tester.element(find.byType(ZhangApp)));
}

/// Pumps [ZhangApp] in a [LedgerSessionHost] with [initial] profiles and
/// [overrides] applied to every session, and settles.
Future<AppHost> pumpAppHost(
  WidgetTester tester, {
  ProfilesState initial = const ProfilesState(),
  List<Override> overrides = const [],
  Duration? Function(int retryCount, Object error)? retry,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    LedgerSessionHost(initialProfiles: initial, overrides: overrides, retry: retry, child: const ZhangApp()),
  );
  if (settle) await tester.pumpAndSettle();
  return AppHost(tester);
}
