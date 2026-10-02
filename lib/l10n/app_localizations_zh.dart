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

  @override
  String get accountsNetWorth => '净资产';

  @override
  String get accountsAssets => '资产';

  @override
  String get accountsLiabilities => '负债';

  @override
  String get accountsIncome => '收入';

  @override
  String get accountsExpenses => '支出';

  @override
  String get accountsEquity => '权益';

  @override
  String accountsNetWorthSource(String currency) {
    return '按账户余额汇总（$currency）';
  }

  @override
  String accountsNotInTotal(String commodities) {
    return '未计入合计（无汇率）：$commodities';
  }

  @override
  String get accountsSearch => '搜索账户';

  @override
  String get accountsSearchHint => '账户名或别名';

  @override
  String get accountsCloseSearch => '关闭搜索';

  @override
  String get accountsShowClosed => '显示已关闭账户';

  @override
  String accountsClosedHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已隐藏 $count 个已关闭账户',
    );
    return '$_temp0';
  }

  @override
  String get accountsClosedBadge => '已关闭';

  @override
  String get accountsOpenBadge => '使用中';

  @override
  String get accountsEmpty => '账本里还没有账户。在账本中写入 open 指令后会显示在这里。';

  @override
  String accountsNoMatches(String query) {
    return '没有匹配「$query」的账户';
  }

  @override
  String get accountsExpand => '展开';

  @override
  String get accountsCollapse => '收起';

  @override
  String get accountsShowCommodities => '展开各币种';

  @override
  String get accountsHideCommodities => '收起币种';

  @override
  String accountsOpened(String date) {
    return '开户于 $date';
  }

  @override
  String accountsConvertedTotal(String amount) {
    return '合计约 $amount';
  }

  @override
  String get accountsBalanceHistory => '余额走势';

  @override
  String get accountsNoBalanceHistory => '暂无余额记录';

  @override
  String get accountsTransactions => '流水';

  @override
  String get accountsRunningBalance => '余额';

  @override
  String get accountsNoTransactions => '这个账户还没有流水';

  @override
  String get accountsBalanceCheck => '余额断言';

  @override
  String get accountsBalancePad => '余额填充';

  @override
  String get accountsCopyName => '复制账户名';

  @override
  String get accountsNameCopied => '已复制账户名';

  @override
  String get reportsPeriodWeek => '周';

  @override
  String get reportsPeriodMonth => '月';

  @override
  String get reportsPeriodYear => '年';

  @override
  String get reportsPeriodCustom => '自定义';

  @override
  String get reportsPreviousPeriod => '上一期';

  @override
  String get reportsNextPeriod => '下一期';

  @override
  String get reportsPickRange => '选择日期范围';

  @override
  String get reportsIncome => '收入';

  @override
  String get reportsExpense => '支出';

  @override
  String get reportsNet => '结余';

  @override
  String get reportsCashflowTitle => '收支趋势';

  @override
  String get reportsNoData => '本期间没有数据';

  @override
  String get reportsBreakdownTitle => '分类占比';

  @override
  String get reportsExpenses => '支出';

  @override
  String get reportsIncomeSegment => '收入';

  @override
  String get reportsOther => '其他';

  @override
  String get reportsTotal => '合计';

  @override
  String get reportsNoExpenses => '本期间没有支出';

  @override
  String get reportsNoIncome => '本期间没有收入';

  @override
  String get reportsUpOneLevel => '返回上一级';

  @override
  String get reportsShowSubAccounts => '查看子账户';

  @override
  String get reportsOpenAccount => '查看账户';
}
