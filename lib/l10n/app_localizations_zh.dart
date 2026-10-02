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
  String get addModeExpense => '支出';

  @override
  String get addModeIncome => '收入';

  @override
  String get addModeTransfer => '转账';

  @override
  String get addClose => '关闭';

  @override
  String get addSubcategory => '子类目';

  @override
  String get addSubcategoryRequired => '必选';

  @override
  String addNoCategories(String root) {
    return '账本里没有开设的 $root 账户，请先添加 open 指令。';
  }

  @override
  String get addFundingExpense => '付款账户';

  @override
  String get addFundingIncome => '存入账户';

  @override
  String get addFrom => '转出';

  @override
  String get addTo => '转入';

  @override
  String get addSwap => '交换账户';

  @override
  String get addChooseAccount => '选择账户';

  @override
  String get addPayee => '商户 / 对方';

  @override
  String get addNarration => '备注';

  @override
  String get addTags => '标签';

  @override
  String get addTagHint => '新标签';

  @override
  String get addTagAdd => '添加';

  @override
  String get addDone => '完成';

  @override
  String get addToday => '今天';

  @override
  String get addDate => '日期';

  @override
  String get addSaveAndAnother => '再记';

  @override
  String get addSaveAndAnotherLabel => '保存并再记一笔';

  @override
  String get addEvaluate => '计算';

  @override
  String get addBackspace => '退格（长按清零）';

  @override
  String get addPlus => '加';

  @override
  String get addMinus => '减';

  @override
  String get addDecimalPoint => '小数点';

  @override
  String get addHintAmount => '请输入金额';

  @override
  String get addHintAmountPositive => '金额需大于 0';

  @override
  String get addHintCategory => '请选择类目';

  @override
  String get addHintSubcategory => '请选择子类目';

  @override
  String get addHintFunding => '请选择账户';

  @override
  String get addHintFrom => '请选择转出账户';

  @override
  String get addHintTo => '请选择转入账户';

  @override
  String get addHintSameAccount => '转出和转入不能是同一个账户';

  @override
  String get addHintCommodity => '正在读取账本币种…';

  @override
  String addSavedSnack(String amount, String title) {
    return '已记账 $amount · $title';
  }

  @override
  String addSavedCount(int count) {
    return '本次已记 $count 笔';
  }

  @override
  String get addSaveFailed => '未能保存';

  @override
  String get addDiscardTitle => '放弃这笔？';

  @override
  String get addDiscardMessage => '已填写的内容不会保存。';

  @override
  String get addDiscard => '放弃';

  @override
  String get addKeepEditing => '继续编辑';

  @override
  String addLastAmount(String amount) {
    return '上次 $amount';
  }

  @override
  String get addCommodity => '币种';

  @override
  String get addPickerSearch => '搜索名称 / 别名 / 任意一段';

  @override
  String get addPickerFavourites => '收藏';

  @override
  String get addPickerRecent => '最近';

  @override
  String get addPickerAll => '全部';

  @override
  String get addPickerEmpty => '没有匹配的账户';

  @override
  String get addPickerStarHint => '长按账户可加入收藏';

  @override
  String get addPickerStarred => '已收藏';

  @override
  String get addTypeAssets => '资产';

  @override
  String get addTypeLiabilities => '负债';

  @override
  String get addTypeEquity => '权益';

  @override
  String get addTypeIncome => '收入';

  @override
  String get addTypeExpenses => '支出';
}
