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
  String get homeExpense => '支出';

  @override
  String get homeIncome => '收入';

  @override
  String get homeNet => '结余';

  @override
  String get homePreviousMonth => '上个月';

  @override
  String get homeNextMonth => '下个月';

  @override
  String get homeRecentTitle => '最近交易';

  @override
  String get homeSeeAll => '全部';

  @override
  String get homeEmptyLedger => '还没有交易，点 ＋ 记第一笔。';

  @override
  String homeErrorCount(int count) {
    return '$count 个错误';
  }

  @override
  String get homeErrorsTitle => '账本错误';

  @override
  String homeErrorsMore(int shown, int total) {
    return '显示 $shown / $total 条';
  }

  @override
  String homeErrorLocation(String file, int offset) {
    return '$file · 第 $offset 字节';
  }

  @override
  String get homeAuthBanner => '服务器拒绝了保存的凭据。';

  @override
  String get homeAuthUpdate => '去更新';

  @override
  String get homeLoadFailed => '加载失败';

  @override
  String get journalFilterAll => '全部';

  @override
  String get journalKindExpense => '支出';

  @override
  String get journalKindIncome => '收入';

  @override
  String get journalKindTransfer => '转账';

  @override
  String get journalKindCompound => '复合';

  @override
  String get journalKindAdjustment => '调整';

  @override
  String get journalKindRefund => '退款';

  @override
  String get journalBalanceCheck => '余额断言';

  @override
  String get journalBalancePad => '余额填充';

  @override
  String get journalBalanceFailed => '余额断言失败';

  @override
  String get journalSearch => '搜索';

  @override
  String get journalSearchHint => '收款方、备注、账户、标签…';

  @override
  String get journalCloseSearch => '关闭搜索';

  @override
  String get journalTags => '标签';

  @override
  String get journalTagsTitle => '按标签筛选';

  @override
  String get journalNoTags => '已加载的交易中没有标签。';

  @override
  String journalRemoveTag(String tag) {
    return '移除标签筛选 $tag';
  }

  @override
  String journalMonthExpense(String amount) {
    return '支出 $amount';
  }

  @override
  String journalMonthIncome(String amount) {
    return '收入 $amount';
  }

  @override
  String get journalToday => '今天';

  @override
  String get journalYesterday => '昨天';

  @override
  String get journalEmpty => '还没有交易';

  @override
  String get journalEmptyHint => '点 ＋ 记第一笔。';

  @override
  String get journalNoMatch => '没有匹配的交易';

  @override
  String get journalClearFilters => '清除过滤';

  @override
  String get journalLoadMoreFailed => '加载更多失败';

  @override
  String get journalUnbalanced => '不平衡';

  @override
  String get journalPending => '待确认';

  @override
  String get journalAttachment => '有附件';

  @override
  String get trxTitle => '交易详情';

  @override
  String get trxPostings => '分录';

  @override
  String get trxDetails => '详情';

  @override
  String get trxDate => '日期';

  @override
  String get trxFlag => '标记';

  @override
  String get trxTags => '标签';

  @override
  String get trxLinks => '链接';

  @override
  String get trxMetas => '元数据';

  @override
  String get trxAuto => '自动';

  @override
  String trxWritten(String amount) {
    return '记账金额 $amount';
  }

  @override
  String get trxCopyText => '复制为文本';

  @override
  String get trxCopied => '已复制到剪贴板';

  @override
  String get trxNotFound => '找不到这笔交易。账本重载后 id 会变化，请从列表重新打开。';

  @override
  String get trxUnbalanced => '这笔交易不平衡。';

  @override
  String trxFilterByTag(String tag) {
    return '查看带 #$tag 标签的交易';
  }
}
