// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Zhang 记账';

  @override
  String get tabHome => '首页';

  @override
  String get tabJournal => '明细';

  @override
  String get tabReports => '报表';

  @override
  String get tabAccounts => '账户';

  @override
  String get newTransaction => '记一笔';

  @override
  String get newTransactionTitle => '记一笔';

  @override
  String get settingsTitle => '设置';

  @override
  String get comingSoon => '即将推出';

  @override
  String activeLedger(String name) {
    return '当前账本：$name';
  }

  @override
  String get onboardingTitle => '连接你的 zhang 服务器';

  @override
  String get onboardingSubtitle => '填写自建 zhang 服务器的地址。凭据会安全地保存在本机。';

  @override
  String get profileNameLabel => '名称';

  @override
  String get profileNameHint => '例如：家庭账本';

  @override
  String get serverUrlLabel => '服务器地址';

  @override
  String get serverUrlHint => 'https://ledger.example.com';

  @override
  String get serverUrlHelper => '不需要带 /api。本地服务器可使用 http://。';

  @override
  String get serverUrlRequired => '请输入服务器地址';

  @override
  String get serverUrlInvalid => '请输入有效的 http(s) 地址';

  @override
  String get authTypeLabel => '鉴权方式';

  @override
  String get authNone => '无';

  @override
  String get authBasic => 'Basic';

  @override
  String get authBearer => 'Bearer';

  @override
  String get authHeaders => '自定义头';

  @override
  String get usernameLabel => '用户名';

  @override
  String get passwordLabel => '密码';

  @override
  String get tokenLabel => 'Bearer 令牌';

  @override
  String get headerNameLabel => 'Header 名称';

  @override
  String get headerValueLabel => '值';

  @override
  String get addHeader => '添加 Header';

  @override
  String get removeHeader => '移除 Header';

  @override
  String get showSecret => '显示';

  @override
  String get hideSecret => '隐藏';

  @override
  String get allowSelfSignedLabel => '允许自签名证书';

  @override
  String get allowSelfSignedHelp => '仅对你信任的服务器开启。';

  @override
  String get colorLabel => '颜色';

  @override
  String get colorDefault => '默认';

  @override
  String get testConnection => '测试连接';

  @override
  String get testingConnection => '正在测试…';

  @override
  String connectionOk(String title) {
    return '已连接到「$title」';
  }

  @override
  String connectionOkDetail(String version, String buildDate) {
    return 'zhang $version · 构建于 $buildDate';
  }

  @override
  String get untitledLedger => '未命名账本';

  @override
  String get save => '保存';

  @override
  String get saveAndContinue => '保存并继续';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get retry => '重试';

  @override
  String get errorUnauthorized => '鉴权失败（401），请检查凭据。';

  @override
  String get errorNotFound => '未找到（404）。';

  @override
  String errorServer(int status, String message) {
    return '服务器错误 $status：$message';
  }

  @override
  String get errorNetwork => '无法连接服务器，请检查地址和网络。';

  @override
  String get errorTimeout => '服务器响应超时。';

  @override
  String get errorCertificate => '服务器的 TLS 证书被拒绝。如果你信任该服务器，请开启「允许自签名证书」。';

  @override
  String get errorParse => '响应格式不符合预期。这是 zhang 服务器的地址吗？';

  @override
  String errorUnknown(String message) {
    return '出错了：$message';
  }

  @override
  String get serversSection => '服务器';

  @override
  String get addServer => '添加服务器';

  @override
  String get editServer => '编辑服务器';

  @override
  String get activeBadge => '当前';

  @override
  String switchedTo(String name) {
    return '已切换到 $name';
  }

  @override
  String get deleteServerTitle => '删除服务器？';

  @override
  String deleteServerMessage(String name) {
    return '将从本机移除「$name」及其保存的凭据。';
  }

  @override
  String get aboutSection => '关于';

  @override
  String get appVersion => '应用版本';

  @override
  String get serverVersion => '服务器版本';

  @override
  String get ledgerTitle => '账本';

  @override
  String get saved => '已保存';
}
