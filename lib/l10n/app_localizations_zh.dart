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
  String get errorServerTooOld =>
      '该 zhang 服务器版本过旧：需要 zhang ≥ 0.2（带内置查询 API）。请升级服务器。';

  @override
  String get errorPasskeyOnly =>
      '该服务器只允许通行密钥（passkey）登录，App 无法使用。请在服务器上启用密码登录（ZHANG_AUTH 或 --auth user:pass）。';

  @override
  String errorApiMismatch(String message) {
    return '服务器没有这个 API（$message）。App 需要 zhang ≥ 0.2。';
  }

  @override
  String get serverTooOldTitle => '服务器版本过旧';

  @override
  String serverTooOldVersion(String version) {
    return '服务器报告的版本：$version。';
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
  String get addPreviewRejected => '未保存——账本会报告以下问题：';

  @override
  String addPreviewUnbalanced(String amounts) {
    return '分录不平衡（相差 $amounts）。';
  }

  @override
  String addPreviewAccountMissing(String account) {
    return '账户 $account 未开立。';
  }

  @override
  String addPreviewAccountClosed(String account) {
    return '账户 $account 已关闭。';
  }

  @override
  String get addPreviewWarning => '账本会报告以下问题（尚未保存）：';

  @override
  String get addSaveAnyway => '仍然保存';

  @override
  String addPreviewCommodityUndeclared(String commodity) {
    return '账本中没有声明商品 $commodity。';
  }

  @override
  String addPreviewCommodityNotAllowed(String account, String commodity) {
    return '账户 $account 的开户指令没有列出 $commodity。';
  }

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
  String homeErrorLocation(String file, int line) {
    return '$file 第 $line 行';
  }

  @override
  String get homeAuthBanner => '服务器拒绝了保存的凭据。';

  @override
  String get homeAuthUpdate => '去更新';

  @override
  String get homeReloadFailed => '账本重新加载失败。在修复文件之前，服务器仍显示上一个版本。';

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
  String journalPadTarget(String amount) {
    return '至 $amount';
  }

  @override
  String trxBalanceActual(String amount) {
    return '实际余额 $amount';
  }

  @override
  String trxBalanceDifference(String amount) {
    return '差额 $amount';
  }

  @override
  String accountsSubAccount(String account) {
    return '子账户 $account';
  }

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

  @override
  String get authSession => '浏览器登录';

  @override
  String get authSessionHelper => '在浏览器中用通行密钥（passkey）或密码登录';

  @override
  String get signInWithBrowser => '用浏览器登录';

  @override
  String get signingIn => '正在登录…';

  @override
  String get signInAgain => '重新登录';

  @override
  String get signOut => '退出登录';

  @override
  String signedOut(String name) {
    return '已退出「$name」';
  }

  @override
  String signedInAs(String user, String date) {
    return '已登录为 $user，有效期至 $date';
  }

  @override
  String signedInSnack(String user) {
    return '已登录为 $user';
  }

  @override
  String sessionSubtitle(String user, String date) {
    return '$user · 有效期至 $date';
  }

  @override
  String get notSignedIn => '未登录';

  @override
  String get signInFirst => '请先用浏览器登录。';

  @override
  String get signInNotNeeded => '该服务器无需登录，请选择「无需登录」。';

  @override
  String get signInNotSupported => '该服务器尚不支持 App 登录，请升级 zhang（PR #786）。';

  @override
  String get signInCancelled => '已取消登录。';

  @override
  String get signInBrowserFailed => '无法打开浏览器登录。';

  @override
  String get signInMalformedCallback => '服务器返回的登录结果无效。';

  @override
  String get signInCodeRejected => '登录凭证已过期或已被使用，请重新登录。';

  @override
  String signInRateLimited(int seconds) {
    return '登录尝试次数过多，请 $seconds 秒后再试。';
  }

  @override
  String get signInRateLimitedLater => '登录尝试次数过多，请稍后再试。';

  @override
  String get homeSessionBanner => '登录已失效，请在浏览器中重新登录。';

  @override
  String homeSessionExpiring(String date) {
    return '登录将于 $date 过期，请重新登录以保持连接。';
  }

  @override
  String get errorPasskeyOnlyBrowser => '该服务器只允许通行密钥（passkey）登录，请选择「浏览器登录」。';

  @override
  String get welcomeTagline => '纯文本账本，随身携带。';

  @override
  String get welcomeBody => '连接你自己部署的 zhang 服务器，随时查看余额、记一笔。';

  @override
  String get welcomeWhatIsZhang => '什么是 zhang 服务器？';

  @override
  String get welcomeAboutBody =>
      'zhang 是开源、自托管的记账工具，账本是你自己持有的纯文本文件。服务器由你自己运行（Docker 或单个可执行文件），App 连接到它使用。App 需要 zhang 0.2 或更新版本。';

  @override
  String get welcomeReadDocs => '查看文档';

  @override
  String get close => '关闭';

  @override
  String get welcomeConnect => '连接我的服务器';

  @override
  String get welcomeTryDemo => '试用 Demo';

  @override
  String get welcomeDemoCaption => 'Demo 是 zhang 项目托管的一套虚构的只读账本。';

  @override
  String get welcomeDemoWaking => '正在唤醒 Demo 服务器，最长可能需要一分钟。';

  @override
  String setupStep(int step, int total) {
    return '第 $step 步，共 $total 步';
  }

  @override
  String get setupServerTitle => '你的服务器在哪里？';

  @override
  String get setupServerBody => '填写你在浏览器里打开 zhang 时用的地址。';

  @override
  String get setupUrlLabel => '服务器地址';

  @override
  String get setupUrlHint => 'ledger.example.com 或 192.168.1.10:8000';

  @override
  String get setupPaste => '粘贴';

  @override
  String setupUrlNormalized(String url) {
    return '将连接 $url';
  }

  @override
  String get setupContinue => '继续';

  @override
  String get setupChecking => '正在检查…';

  @override
  String get setupTryAgain => '重试';

  @override
  String get setupHintReach => '检查地址和端口，并确认这台手机能访问到服务器（同一 Wi-Fi 或 VPN）。';

  @override
  String get setupHttpHint => '没有填写协议，所以使用了 https://。局域网里的服务器通常用 http://。';

  @override
  String setupTryHttp(String url) {
    return '改用 $url';
  }

  @override
  String get setupNotZhang => '服务器有响应，但不像是 zhang。请填写 zhang 网页的地址，不需要 /api。';

  @override
  String get setupBehindGateway => '前面有登录网关';

  @override
  String get setupTooOldTitle => '这台服务器需要升级';

  @override
  String setupTooOldBody(String version) {
    return '它运行的 zhang $version 缺少 App 需要的 API。请把服务器升级到 zhang 0.2 或更新版本，然后重试。';
  }

  @override
  String get setupHowToUpgrade => '如何升级';

  @override
  String setupSignInTitle(String ledger) {
    return '登录「$ledger」';
  }

  @override
  String get setupSignInTitleUntitled => '登录';

  @override
  String setupSignInBody(String host) {
    return '$host 需要登录。';
  }

  @override
  String get setupBrowserStep1 => '服务器的登录页会在安全的浏览器窗口中打开。';

  @override
  String get setupBrowserStep2 => '在那里用通行密钥或密码登录。App 只保存登录令牌，不保存密码。';

  @override
  String get setupWaitingBrowser => '正在等待浏览器…';

  @override
  String get setupUsePassword => '使用用户名和密码';

  @override
  String get setupUseBrowser => '改用浏览器登录';

  @override
  String get setupSignIn => '登录';

  @override
  String get setupPasskeyOnlyTitle => '这台服务器只接受通行密钥';

  @override
  String get setupPasskeyOnlyBody =>
      'App 通过服务器的登录页使用通行密钥，但这个版本的 zhang 还不能把登录结果交回 App。请升级服务器，或开启密码登录。';

  @override
  String get setupCheckAgain => '重新检查';

  @override
  String get setupCredentialsUnknown => '服务器要求提供凭据。';

  @override
  String get setupGatewayBody => 'zhang 前面的反向代理或网关要求提供凭据，请在「反向代理或网关」中填写。';

  @override
  String get setupAdvancedTitle => '反向代理或网关';

  @override
  String get setupAdvancedSubtitle => 'Bearer 令牌或自定义 Header';

  @override
  String get setupConnect => '连接';

  @override
  String setupSignedInAs(String user) {
    return '已登录为 $user';
  }

  @override
  String get setupConnected => '已连接';

  @override
  String get setupReadyTitle => '连接成功';

  @override
  String get setupReadyBody => '给账本起个名字、选个颜色，之后都可以在设置里修改。';

  @override
  String get setupFactCurrency => '记账货币';

  @override
  String get setupFactAccounts => '账户';

  @override
  String setupFactAccountsValue(int count) {
    return '$count 个';
  }

  @override
  String get setupFactServer => '服务器';

  @override
  String get setupFactSignedIn => '登录身份';

  @override
  String get setupFactSignIn => '登录';

  @override
  String get setupFactNoSignIn => '无需登录';

  @override
  String get setupFactUnavailable => '无法读取账本详情，仍可以开始使用。';

  @override
  String get setupNameLabel => '在本机显示的名称';

  @override
  String get setupDemoNote => '这是 zhang 的 Demo，一套只读账本：可以浏览，新记录不会被保存。';

  @override
  String get setupStart => '开始使用';

  @override
  String get profileSectionServer => '服务器';

  @override
  String get profileSectionSignIn => '登录';

  @override
  String get profileSectionAppearance => '外观';

  @override
  String get authMethodLabel => '登录方式';

  @override
  String get authNoneLong => '无需登录';

  @override
  String get authBasicLong => '用户名和密码';

  @override
  String get authSessionLong => '浏览器登录（通行密钥或密码）';

  @override
  String get authBearerLong => 'Bearer 令牌（反向代理）';

  @override
  String get authHeadersLong => '自定义 Header（反向代理）';

  @override
  String get setupProxyHeaders => '自定义 Header';

  @override
  String get setupUnreachable => '无法连接到服务器';
}
