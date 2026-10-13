import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// The public zhang demo (README "Online demo"): a fictional, read-only
/// ledger without sign-in. Hosted on a free Render plan, so the first
/// request after a while wakes it up (~30 s).
const kDemoServerUrl = 'https://zhang-demo.onrender.com';

const _docs = 'https://zhang-accounting.kilerd.me';

bool _zh(BuildContext context) => Localizations.localeOf(context).languageCode == 'zh';

/// zhang docs pages the setup links to (Chinese pages for a zh app locale).
abstract final class ZhangDocs {
  static String introduction(BuildContext context) =>
      _zh(context) ? '$_docs/zh-cn/getting-started/introduction/' : '$_docs/getting-started/introduction/';

  static String upgrading(BuildContext context) =>
      _zh(context) ? '$_docs/zh-cn/deployment/upgrading/' : '$_docs/deployment/upgrading/';

  static String appSignIn(BuildContext context) => _zh(context)
      ? '$_docs/zh-cn/deployment/authentication/'
      : '$_docs/deployment/authentication/#mobile-app-sign-in';
}

/// Opens [url] in the browser; failures are ignored (nothing to recover).
Future<void> openExternalUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // No browser available: nothing useful to show.
  }
}
