# zhang-app 移动端设计调研与设计规范

> 日期：2026-10-02 · 适用：zhang-app（Flutter / Material 3 / Android + iOS，phone-first）
> 目标：参考（"抄"）主流记账 App 已验证的交互，给 zhang（Beancount 风格纯文本复式记账）的移动客户端定一份可直接开工的设计规范。
>
> **证据等级标记**
> - 〔源码〕= 我们直接读过该项目的开源代码（给出文件路径）；〔官方〕= 官方文档 / 应用商店描述；〔评测〕= 第三方评测、产品分析文章；
> - **reportedly** = 只在二手资料或搜索摘要中看到，未能在官方文档或源码中核实。
> - 未找到的东西会直接说明（例如 SumiMakito 的 beancount-mobile，见 1.11）。

---

## 0. TL;DR：最重要的 10 条设计决策

1. **导航**：底部 5 格 = `Home 首页` / `Journal 流水` / **中间凸起的 `记一笔` 按钮** / `Reports 报表` / `Accounts 账户`。中间这个是"动作"，不是页面（鲨鱼、随手记、Ivy 都这么放）。`Settings` 和服务器切换放在 Home 的 app bar 里。
2. **记一笔默认走"类目宫格 + 计算器键盘"的单屏流程**（钱迹 / 鲨鱼 / Money Manager 的模式），顶部有 `支出 | 收入 | 转账 | 高级` 四个模式。前三种由 App 自动生成 2 条 posting，"高级"才是完整的多 posting 编辑器（Beancount Mobile 的模式）。
3. **"类目" = `Expenses:*` / `Income:*` 账户树的第 2 层**，第 3 层及更深显示成子类目 chips（对应钱迹的二级类目、Cashew 的 subcategory chips）。显示名优先用 `open` 指令的 `alias`，没有就用最后一段。
4. **付款账户自动记忆**：每个类目记住上次用的资金账户（MOZE 的做法），选了 payee 就用该 payee 上一笔交易自动填表（Fava 的 `payee_transaction`）；账户和 payee 按指数衰减的 frecency 排序（Fava 的 `ExponentialDecayRanker`）。
5. **键盘**：4×4 计算器键盘，支持 `+ − × ÷`，算式行实时预览；有算式没算完时"保存"键变成 `=`；左下角放 `再记`（钱迹）；按币种 precision 控制小数位；内部全部用 Decimal 计算。
6. **流水**：吸顶的月份头显示当月支出 / 收入，按天分组，每个日期头带当天净额；每笔交易按 posting 的账户类型自动判成 支出 / 收入 / 转账 / 复合；balance 断言作为一种特殊行显示。
7. **账户页**：顶部是净资产卡片（数值 + 走势），下面是可折叠的账户树（缩进引导线，父节点显示汇总余额，多币种可展开）。账户选择器用"收藏 / 最近 / 树形 + 搜索"，**不要**像 Beancount Mobile 那样把全路径平铺成一长串。
8. **报表**：周 / 月 / 年 / 自定义四种周期，可左右切换；收入和支出用分组柱状图，叠一条净额折线；分类占比用 donut（最多 6 段 + "其他"）配横向排行条，点一下可以下钻。**不做**随手记那种转饼图对指针的交互（被评测吐槽）。
9. **服务器接入**：首次启动走 `Server Setup` 向导，填 URL → 选鉴权方式（无 / Basic / Bearer / 自定义 Header）→ 点 **Test Connection** 跑分步检查 → 存成 profile，可以存多个。凭据放 Keychain / Keystore。每个 profile 有自己的颜色标记，避免记错账本。
10. **视觉**：M3 seed 配色，财务语义色（收入、支出、转账、预算状态）放在 `ThemeExtension` 里，并和 seed 做 harmonize。**收支红绿的约定可以切换**（钱迹、MOZE 都提供这个开关）。金额统一用等宽数字（tabular figures）、U+2212 负号，按币种 precision 显示小数，支持"隐藏金额"。

---

## 1. 竞品拆解（Per-app teardown）

### 1.0 覆盖范围与证据

| # | App | 平台 / 技术 | 开源 | 本文主要证据 |
|---|-----|-------------|------|--------------|
| 1 | 钱迹 Qianji | Android / iOS / 鸿蒙 / PC | 否 | 〔官方〕[钱迹用户指南](https://docs.qianjiapp.com/)，〔评测〕[少数派](https://sspai.com/post/61668)、[withcb](https://withcb.net/post/app-qian-ji/) |
| 2 | MOZE 3.0/4.0 | iOS / iPadOS / macOS / watchOS | 否 | 〔官方〕[doc.moze.app](https://doc.moze.app/)，〔评测〕[LarryNote](https://www.larrynote.com/moze-3-0-review/)、[vocus](https://vocus.cc/article/67d3cdd2fd89780001386b85) |
| 3 | 随手记 | Android / iOS | 否 | 〔评测〕[人人都是产品经理 #1](https://www.woshipm.com/evaluating/2388019.html)、[#2](https://www.woshipm.com/evaluating/939335.html) |
| 4 | 鲨鱼记账 | Android / iOS | 否 | 〔评测〕[站酷](https://www.zcool.com.cn/article/ZOTYzMjM2.html)、[简书](https://www.jianshu.com/p/3ce110fb2fd8)、[UICN](https://m.ui.cn/details/525983) |
| 5 | Cashew | Flutter（iOS / Android / Web） | 是 GPL-3.0 | 〔源码〕[jameskokoska/Cashew](https://github.com/jameskokoska/Cashew)（本地 clone 阅读） |
| 6 | Ivy Wallet | Kotlin / Compose（Android） | 是 GPL-3.0，已停更 | 〔源码〕[Ivy-Apps/ivy-wallet](https://github.com/Ivy-Apps/ivy-wallet)（本地 clone 阅读） |
| 7 | Money Manager（Realbyte） | Android / iOS | 否 | 〔官方〕[App Store](https://apps.apple.com/us/app/money-manager-expense-budget/id560481810)、[Google Play](https://play.google.com/store/apps/details?id=com.realbyteapps.moneymanagerfree&hl=en_US) |
| 8 | YNAB | iOS / Android / Web | 否 | 〔官方〕[support.ynab.com](https://support.ynab.com/en_us/how-to-add-transactions-in-ynab-HyDwA_byi)、[App Store](https://apps.apple.com/us/app/ynab/id1010865877) |
| 9 | Actual Budget | Web（含移动端布局） | 是 MIT | 〔源码〕[actualbudget/actual](https://github.com/actualbudget/actual) `packages/desktop-client/src/components/mobile/` |
| 10 | Spendee | iOS / Android / Web | 否 | 〔官方〕[App Store](https://apps.apple.com/us/app/expense-budget-app-spendee/id635861140) |
| 11 | Beancount 系：Beancount Mobile（beancount.io）、xuhcc/beancount-mobile、Fava、Costflow | RN / NativeScript / Web | 是 | 〔源码 / 官方〕见 1.11 |

前 9 个是重点拆解，Spendee 只做简述，Beancount 系单独成节。

---

### 1.1 钱迹 Qianji

**定位**：主打"无广告、无开屏、无理财"的"三无"记账工具，功能都围绕记账本身展开（[官方简介](https://docs.qianjiapp.com/)）。

**导航与首页**
- 首页按**月**加载账单，支持"自定义起始日"（比如每月 10 号起算），统计、预算、报表也跟着这个起始日走（[自定义起始日](https://docs.qianjiapp.com/home/custom_month_start.html)）。
- 主界面上半部分是当月汇总和报销情况，下面是消费清单；报销管理放在侧栏导航里（[少数派](https://sspai.com/post/61668)）。

**记一笔（核心界面）**：[添加收支](https://docs.qianjiapp.com/ji-zhang-jie-mian/tian-jia-shou-zhi.html)
- 自上而下：**分类列表**（必选，默认选中第一个，可以上下滚动；右上角 ➕ 直接进分类管理）→ **选择账户**（开了资产管理才出现）→ **备注**（可选）→ **时间**（默认"今天"；**在时间按钮上上下滑动可以 ±1 天**）→ **报销**勾选 → **计算器面板**。
- 计算器面板：最多两位小数；文档写的是只支持加法；按键有 `清零`、`再记`（"再记一笔"，提交后马上开始下一笔）、`保存`（保存后关闭页面，并触发一次同步）。
- 分类分两级：一级类目平铺成宫格，二级类目可选，"不选二级类目、不选账户也能完成一笔"（[withcb](https://withcb.net/post/app-qian-ji/)，[少数派](https://sspai.com/post/61668)）。
- 转账：转出账户 → 转入账户 → 金额 → 备注 / 时间（可选）→ 保存（[转账](https://docs.qianjiapp.com/ji-zhang-jie-mian/zhuan-zhang-cao-zuo.html)）。
- 手续费 / 优惠：转账可以带手续费（单独统计为支出），支出可以带优惠（不计入收支，单独汇总）（[手续费 & 优惠](https://docs.qianjiapp.com/ji-zhang-jie-mian/fee_or_coupon.html)）。
- 多币种：默认关闭，要到"设置 — 实验室"打开；打开后金额右边会多一个币种按钮；默认币种跟所选资产一致（[多币种](https://docs.qianjiapp.com/multiple_currency.html)）。

**资产 / 账户**：[资产管理](https://docs.qianjiapp.com/assets/intro.html)
- 四大类：资金（现金、银行卡、支付宝、微信……）、信用卡（含花呗、白条）、充值（公交卡、饭卡……）、投资理财。
- **信用卡欠款显示为负数**，正数表示溢缴款。账户可以长按隐藏，隐藏后记账时不能再选。
- 自定义资产分组（会员功能）（[资产分组](https://docs.qianjiapp.com/assets/group.html)）。资产负债表、单个资产的"资产趋势"（按月末余额推算），以及"手动调整某月月末余额"（[资产负债表](https://docs.qianjiapp.com/assetrecord/balance_sheet.html)、[资产趋势](https://docs.qianjiapp.com/assetrecord/asset_line.html)）。

**预算**：[预算说明](https://docs.qianjiapp.com/vip/vip_budget.html)
- 三种模式：总预算 + 一级分类预算 / 只设总预算 / 只设一级分类预算。
- **新的月份自动复制上月的预算配置**。

**快捷入口**：桌面小部件、应用快捷方式、快速设置开关，还有"**秒开模式**"（启动 App 直接进记账界面）（[少数派](https://sspai.com/post/61668)）；URL Scheme 可以直接跳到记账、预算、统计页面（[URL Scheme](https://docs.qianjiapp.com/plugin/url_scheme_others.html)）。

**个性化**：收支颜色可以切换：Android 在"设置 — 实验室"里，iOS 是"支持切换收入支出颜色"（[Android 更新记录](https://docs.qianjiapp.com/change-log/change_log_android.html)、[iOS 更新记录](https://docs.qianjiapp.com/change-log/change_log_ios.html)）；报销金额颜色固定为蓝色，不跟主题变，避免和主题色混淆（同上）。

**为什么快**：秒开模式 + 小部件；默认类目足够本地化，开箱即用；二级类目和账户都可以跳过；`再记` 适合连续补账；用滑动手势改日期。
**好评**：简洁、快、无广告、基础功能免费（[withcb](https://withcb.net/post/app-qian-ji/)）。**吐槽 / 局限**：iOS 版功能一度落后 Android（[少数派](https://sspai.com/post/61668)）；资产分组、资产负债表等进阶功能需要会员。

**可以借鉴到 zhang**：`再记`；日期按钮上下滑动 ±1 天；"不选账户也能存"→ 对应 zhang 的默认资金账户；信用卡负数显示；预算按月自动沿用；秒开模式（P2：启动直接进记一笔）。

---

### 1.2 MOZE 3.0 / 4.0

**定位**：台湾团队做的"最美记帐"，功能深度很高：信用卡账期、对账、拆账、专案、范本、捷径（[App Store](https://apps.apple.com/tw/app/moze/id1460011387)）。

**记一笔字段**：[記帳欄位介紹](https://doc.moze.app/record/introduction)
- 必要信息：记录类型（支出 / 收入 / 转账 / 应收 / 应付 / 系统类：手续费、折扣、红利）、类别、金额、账户、交易日期；进阶信息：名称、商家、专案、标签、备注、图片；进阶设置：单次 / 周期 / 分期，以及立即 / 提醒 / 延后入账。
- **金额不分正负号，系统根据记录类型自动判断**。这对复式记账的移动端很关键：用户只输入正数，符号由模式决定。
- **建议类别**：记到一定笔数后，会根据"这个时间点最可能用的类别"排序。比如早上 9–10 点，"早餐"会排在第一。
- **记住每个类别上次搭配的账户和专案**，下次选这个类别时自动带入。
- 币种：默认是账户主币种；点金额左边的币种按钮切换，按当天线上汇率换算，之后可以改成实际扣款金额。
- 手续费 / 折扣：点金额旁边的"＋"填写，可以自定义名称（比如"运费"）。

**范本 / 模式 / 快捷**
- 范本：在"名称"字段输入时会出现带 ★ 的范本，点一下自动带入其余字段；可以加入 Siri 和 Spotlight（[範本](https://doc.moze.app/record/template)）。
- 记账模式（4.0）：比如"日常 / 旅游 / 工作"，每个模式有自己的默认币种、账户、专案、类别，以及可选清单；**长按首页下方的 ＋ 可以快速切换模式**（[記帳模式](https://doc.moze.app/record/entry-mode)）。
- 完成记账的快捷方式：**下拉一段距离就完成**；**长按 ✓ 连续记账**（[記帳小技巧](https://doc.moze.app/record/tips)）。

**拆账**：一笔记录里可以有多个类别 / 账户 / 专案（比如大卖场一次买了几类东西，或者信用卡 + 点数一起付）（[拆帳](https://doc.moze.app/record/split-categories)）。这在概念上就是 **multi-posting**。

**报表**：[統計報表](https://doc.moze.app/analysis/statistics-report)
- 顶部是日期区间，可以左右切换，也可以点开直接选；下面依次是总览、明细（折线图，点一下列表会滚到对应日期）、类别（可以下钻到子类别）、排行、账户、专案、账户分组、名称、商家、标签、对象。
- 自定义报表的区间类型：单一区间 / 重复循环 / 截至今天；筛选条件可以"包含 / 排除"；内置周报、月报、年报。

**搜索**：关键字可以搜名称、备注、类别、账户、专案、商店、标签、对象，再加日期区间、金额上下限、类型等条件，可以按日期或金额排序（[搜尋](https://doc.moze.app/feature/search)）。

**对账**：对账模式下可以滑动逐笔确认（[vocus](https://vocus.cc/article/67d3cdd2fd89780001386b85)）；还有"餘額調整"：按某个时间点的实际余额设定，之后在这个时间点之前增删记录，也不会改变这个时间点的余额（[餘額調整](https://doc.moze.app/reconciliation/balance-adjustment)）。这和 Beancount 的 `balance` / `pad` 语义高度一致。

**偏好设置**：支出收入颜色、字体大小、日期格式、**数字键盘顺序（电话式 / 计算器式）**、复制记录时带入原时间还是当前时间、总额缩写、数字换算单位（[偏好設定](https://doc.moze.app/feature/preference)）。

**为什么快**：时段类别建议 + 类别→账户记忆，常见情况下只需要 "类别 → 金额 → ✓"；范本、Siri、Spotlight；下拉保存。
**好评**：功能强、界面方便，信用卡管理和分类完整度受称赞（[App Store](https://apps.apple.com/tw/app/moze/id1460011387)）；"多类别（拆账）是记账魔人必备"（[LarryNote](https://www.larrynote.com/moze-3-0-review/)）。**吐槽 / 局限**：3.0 从买断改成订阅（同上）；用户希望能自动更新股价、自动计息（App Store 评论摘要，reportedly）。

**可以借鉴到 zhang**：只输正数、符号由模式决定；时段建议；类别→账户记忆；★ 范本；长按 ＋ 切模式；下拉 / 长按保存；"对账模式"对应 balance check / pad；键盘顺序可选；收支颜色可选。

---

### 1.3 随手记

**定位**：老牌"记账 + 理财"产品，功能最全，但商业化（理财、贷款）和广告比较重（[woshipm #2](https://www.woshipm.com/evaluating/939335.html)）。

- **导航**：底部标签有 6 个，最左边是一个抽屉（切换账本、进个人中心）；导航栏可以自定义，有 13 个功能模块可选。评测认为 6 个标签对点击精度要求高，抽屉也不符合直觉，建议把核心功能放在底部导航，次要功能放进二级导航（[woshipm #2](https://www.woshipm.com/evaluating/939335.html)）。
- **记一笔按钮挪到首页正下方**，方便大屏手机单手记账；首页中间区域留空，专门用来看账和看统计（[woshipm #1](https://www.woshipm.com/evaluating/2388019.html)）。
- 记账页有 7 个标签：分类、账户、成员、商家、项目、备注、照片；流水类型分为支出 / 收入 / 转账 / 余额等；记完可以选"保存"、"保存为模板"或"再记一笔"（同上）。
- **模板记账**：只需要输入金额，其余信息由模板带出（[woshipm #2](https://www.woshipm.com/evaluating/939335.html)）。
- **流水 / 超级流水**：首页的上下看板显示各时间段的收支合计；"超级流水"的筛选条件更细，而且**可以保存筛选规则**，面向专家用户（同上）。
- **图表**：用饼图和条形图；但饼图要**旋转饼图、让某一段对准指针**才能看这一段的数据，评测认为认知成本高，建议改成点击，或者和条形图搭配（同上）。
- 预算有一级和二级；支持多人记账、场景账本（同上）。
- **吐槽**：广告和推送多；未登录时的数据在登录后"丢失"（其实是被放进了离线账本）；记账分类太繁多（[woshipm #2](https://www.woshipm.com/evaluating/939335.html)、[简书](https://www.jianshu.com/p/3ce110fb2fd8)）。

**可以借鉴到 zhang**：底部居中记一笔、单手可达；模板；保存过滤器（P2）。**反面教材**：标签太多、转饼图、广告。

---

### 1.4 鲨鱼记账

**定位**：主打"3 秒记账"的轻量工具，主色是明黄（[站酷](https://www.zcool.com.cn/article/ZOTYzMjM2.html)、[简书](https://www.jianshu.com/p/3ce110fb2fd8)）。

- **导航**：5 个标签：明细（首页）/ 记账（居中，舵式导航）/ 图表 / 发现 / 我的（[站酷](https://www.zcool.com.cn/article/ZOTYzMjM2.html)）。
- **明细页**：顶部是本月总收入和总支出，可以切换月份；下面按**天**分栏列出账单，点进去可以查看和修改（同上）。支持关键字搜索和日期筛选（[简书](https://www.jianshu.com/p/3ce110fb2fd8)）。
- **记账页**：选支出或收入（默认支出）→ 在分类宫格里点类别 → 用数字键盘输金额 → 备注（可选；系统会记录历史备注供快速选用）→ 时间 → 完成（[站酷](https://www.zcool.com.cn/article/ZOTYzMjM2.html)）。
  - 数字键盘带 `+`、`−` 和 `日历` 键（日历键用于补记历史账）；点备注后，**同一页面的数字键盘直接换成文字键盘**，不跳页；备注上方有"推荐备注"（reportedly，见 [UICN](https://m.ui.cn/details/525983)、[知乎竞品分析](https://zhuanlan.zhihu.com/p/116488189)）。
  - 一级分类有四十多个、没有二级分类，平铺下来超过一屏（reportedly，同上）。
- **图表页**：周 / 月 / 年切换；折线图 + 列表 + 按金额排序的条形图；**高于平均的类别会用红色标记提醒**（[站酷](https://www.zcool.com.cn/article/ZOTYzMjM2.html)、[简书](https://www.jianshu.com/p/3ce110fb2fd8)）。
- **好评**：上手快、记账快；**吐槽**：功能单一，很多功能要付费（[站酷](https://www.zcool.com.cn/article/ZOTYzMjM2.html)）。

**可以借鉴到 zhang**：居中记账按钮；按天分栏 + 月头汇总；`+ −` 键盘；推荐备注（= zhang 的 narration 历史建议）；"高于平均"提示。

---

### 1.5 Cashew（Flutter，开源，参考价值最高）

数据：4.9 星 / 15.7k+ 评价，100k+ 下载（[Code With Andrea 代码评审](https://codewithandrea.com/videos/code-review-cashew-app/)）。下面的结论来自 clone 下来的源码（[jameskokoska/Cashew](https://github.com/jameskokoska/Cashew)）。

- **导航**：底部栏有 3 个**用户可自定义**的快捷位（默认是 Home / Transactions / Budgets）加一个固定的 `More`；可以放进快捷位的还有 Goals、Subscriptions、Scheduled、Loans、Notifications、All Spending（summary）、Settings（`budget/lib/widgets/bottomNavBar.dart`、`budget/lib/struct/navBarIconsData.dart`）。宽屏时换成侧边栏（`navigationFramework.dart` 里的 `widthSideNavigationBar`）。
- **首页是可编辑的模块列表**，默认顺序：wallets（钱包切换）→ walletsList → budgets → objectives → allSpendingSummary → netWorth → overdueUpcoming → creditDebts → objectiveLoans → spendingGraph → pieChart → heatMap → transactionsList（`budget/lib/struct/defaultPreferences.dart`、`pages/homePage/*`、`pages/editHomePage.dart`）。
- **记一笔**（`budget/lib/pages/addTransactionPage.dart`）：
  - 组件依次是：交易类型（收入 / 支出 + upcoming / subscription / repeating / debt / credit）、`SelectAmount` 计算器键盘、`SelectCategory`（带收入 / 支出切换）和 **`SelectSubcategoryChips` 子类目 chips**、`SelectedWalletButton`、`DateButton`、`TitleInput`、`TransactionNotesTextInput`（自动识别链接）、预算 / 目标归属、附件图片。
  - **"Associated titles"**：同一个标题会自动归到同一个类目（设置项 `autoAddAssociatedTitles`）；可以选择"添加时先问标题"（`askForTransactionTitle`）。README 的说法是 "Automatically assign transactions with the same name to specific categories"。
  - 键盘（`budget/lib/widgets/selectAmount.dart`）：0–9、`.`、`<`（退格）、`÷ × − +`；**算式会在结果上方实时显示**（`calculationString`）；支持实体键盘输入；完成按钮的文案可以配置（`nextLabel`）。
- **流水**（`pages/transactionsListPage.dart`）：顶部是横向的 `MonthSelector`；按日期分组（`widgets/dateDivider.dart`）；`TransactionFiltersSelection` 可以按日期、类目、金额、标签过滤；**长按进入多选，并且支持拖动连续选择**（`widgets/transactionEntry/swipeToSelectTransactions.dart`）。
- **其他**：多币种（实时汇率）、Material You 动态色和自定义强调色、深色模式、生物识别锁、CSV / Google Sheets 导入、通过链接预填交易（README）。
- **好评**：界面美、可定制、无广告。**工程上的教训**：`addTransactionPage.dart` 有 5000 多行，全局 navigation key 到处强制 rebuild，没有用状态管理框架（[Code With Andrea](https://codewithandrea.com/videos/code-review-cashew-app/)）。**我们要抄的是交互，不是这套架构。**

**可以借鉴到 zhang**：子类目 chips；标题→类目关联（= zhang 的 payee→account 记忆）；算式实时显示；横向月份选择器；首页模块可以排序和隐藏（P2）；拖选多条。

---

### 1.6 Ivy Wallet（Kotlin / Compose，开源，已停更）

2024-11 起停止维护，仓库在 2026-04 归档（[README](https://github.com/Ivy-Apps/ivy-wallet)）。下面同样来自源码阅读。

- **导航**：底栏只有 `Home` 和 `Accounts` 两个页面，中间是一个大的 ＋（`feature/main/src/main/java/com/ivy/main/MainBottomBar.kt`）。
  - 点 ＋ 会展开 `Add Income` / `Add Expense` / `Add Transfer` / `Add planned payment` 几个按钮。
  - **在 ＋ 上做手势**：上滑 = 支出，左上滑 = 收入，右上滑 = 转账（同一文件里 `dragOffset` 的阈值判断）。
- **Home**：顶部是 "Hi {name}" 和总余额，下面是 cashflow 以及 Income / Expenses 两张卡（`feature/home/.../HomeHeader.kt`）；接着是 upcoming / overdue 的计划付款，然后是按日分组的历史。
  - 下拉出来的 More 菜单里有：搜索、储蓄目标、Settings、Categories、主题切换（Light / Dark / **AMOLED** / Auto）、Planned payments、Reports、Budgets、Loans（`HomeMoreMenu.kt`）。
- **记一笔是"引导式聚焦链"**（`feature/edit-transaction/src/main/java/com/ivy/transaction/EditTransactionScreen.kt`）：标题输入带 `titleSuggestions` → 金额 `AmountModal` → 如果还没选类目就**自动弹出** `ChooseCategoryModal` → 选完类目，如果金额为空又自动回到金额 → 然后是标签、到期日、`DescriptionModal`；汇率也可以单独改。
- **日分组头**：显示日期和当天的净 cashflow；**净额为正显示绿色，为负显示灰色而不是红色**（`temp/legacy-code/.../HistoryDateDivider.kt`），可以减少负面情绪。
- **好评**：UI / UX 是卖点，被 YouTube 评测列为 2021/2022 年度最佳 Android App 之一（[README](https://github.com/Ivy-Apps/ivy-wallet)）；有桌面小部件可以一键加收入、支出、转账（[Google Play](https://play.google.com/store/apps/details?id=com.ivy.wallet)）。

**可以借鉴到 zhang**：＋ 按钮手势（可选的高级用法）；字段的自动聚焦链；负数日净额用中性色；AMOLED 主题。

---

### 1.7 Money Manager（Realbyte）

- **导航**：底部 `Trans.` / `Stats` / `Accounts` / `Settings(More)` 四个标签（reportedly，[搜索结果汇总](https://help.realbyteapps.com/hc/en-us/articles/360046150874-Home-tab)，官方帮助中心被 Cloudflare 拦截，未能直接阅读）。
- **Trans 页**的顶部子标签是 `Daily / Calendar / Weekly / Monthly / Total(Summary)`，每个标签都显示 Income / Expenses / Total 三列；Calendar 显示当月每天的收入和支出总额（reportedly，同上）。
- **自称采用复式记账**：输入收入就直接存进账户，输入支出就直接从账户扣（[Google Play 描述](https://play.google.com/store/apps/details?id=com.realbyteapps.moneymanagerfree&hl=en_US)）。也就是说，每一笔都必须有资金账户。
- **Bookmark（书签）**：把常用支出存成书签，可以一次批量录入；有计算器（金额右上角按钮）、子类目开关、自定义月起始日、信用卡结算日、自动转账和周期记账（同上）。
- **好评**：功能全、类目可以分两级、账户类型灵活。**吐槽**：视觉老旧、多设备同步要手动上传和下载文件（[App Store](https://apps.apple.com/us/app/money-manager-expense-budget/id560481810)）；"手动记账的负担"让很多人坚持不到 6 周（[moonproduct 评测](https://www.moonproduct.tech/insights/money-manager-app-vs-finley/)）。

**可以借鉴到 zhang**：**日历视图**（P2）；收入 / 支出 / 合计三列的期间头；书签（= 模板）。它证明了复式记账的心智模型可以用"账户 + 类目"包装给普通用户。

---

### 1.8 YNAB

- **导航**：新版移动端加了一个 Home 标签作为第一个 tab（dashboard：待分配金额、优先类别、本月进度）（[Rachele DiTullio](https://racheleditullio.com/blog/2025/09/ynab-adds-a-home-screen-to-its-ios-mobile-app-but-is-it-accessible/)）；Reports 改名为 **Reflect**；Plan 页底部有 Add Transaction 按钮，**长按类目也可以加交易**（reportedly，[YNAB What's New](https://www.ynab.com/whats-new)）。
- **记一笔**：Home、Plan、Spending 页和每个账户 register 的底部都有 Add Transaction 按钮；先用数字键盘输金额，点 Done，然后选 Payee、Category，**App 会记住你在哪个地点用过哪个商家，把它排在前面**（[How to Add Transactions](https://support.ynab.com/en_us/how-to-add-transactions-in-ynab-HyDwA_byi)）。
  - 展开后有 cleared、flag、memo、repeat；可以加照片；计算器支持乘除；支持 split，split 里可以有 transfer 腿（[App Store](https://apps.apple.com/us/app/ynab/id1010865877)）。
- **payee→默认类目的更新规则**：只改一次类目不会改变这个 payee 的默认类目，要最近 3 笔里有 2 笔都是新类目才会切换（YNAB What's New，reportedly）。
- **Card Mode**：审核导入交易时，右滑 = 通过，左滑 = 跳过（[App Store](https://apps.apple.com/us/app/ynab/id1010865877)）。
- **吐槽**：UI 改动太频繁，打乱肌肉记忆；新 Home 拥挤；悬浮的添加按钮显得乱；信用卡预算逻辑不直观（同上，评论摘要）。
- 无障碍问题：... 菜单在 VoiceOver 下的焦点有问题，"Transaction" 按钮直到后来才补上 "Add Transaction" 的无障碍名称（[Rachele DiTullio](https://racheleditullio.com/blog/2025/09/ynab-adds-a-home-screen-to-its-ios-mobile-app-but-is-it-accessible/)）。

**和 zhang 的关系**：zhang 的预算系统就是照 YNAB 设计的（零基预算：`budget`、`budget-add`、`budget-transfer`，assigned / activity / available，见 zhang 仓库 `docs/src/content/docs/directives/4-budget.md`）。所以预算页面应该直接借 YNAB 的表达：**每个预算一行，显示 Available 的颜色状态**。还要借的：payee 默认类目的"多数票"更新规则；导航结构保持稳定，别频繁改；图标按钮要有无障碍名称。

---

### 1.9 Actual Budget（开源，移动端布局）

源码：`packages/desktop-client/src/components/mobile/`（[actualbudget/actual](https://github.com/actualbudget/actual)）。

- **导航是一个可以上拉的底部抽屉**（`MobileNavTabs.tsx`）：平时只露出第一行（Budget / Transaction / Accounts），上拉后出现 Reports、Schedules、Payees、Rules、Bank Sync、Settings（3 列网格，每行高 70）。用这种方式解决"入口太多"的问题，同时保持底栏简洁。
- **记一笔**（`mobile/transactions/TransactionEdit.tsx`）：字段顺序是 Amount（顶部大号）→ Payee → Category → Account → Date → Cleared / Reconciled → Notes；支持 split（`SplitAmountInput.tsx`）；有自己的 `CalculatorKeyboard.tsx`（底部固定，高度大约 50dvh，带 toggle sign、equals、clear、apply）。
- 账户 register 页带余额（`TransactionListWithBalances.tsx`）；支持下拉刷新（`PullToRefresh.tsx`）。
- 发布说明里有大量移动端表单的细节修正，比如"空金额时也保持输入框高度"、"字段加图标、占位符和下拉箭头"（[Release Notes](https://actualbudget.org/docs/releases/)）。

**可以借鉴到 zhang**：上拉的"更多"抽屉可以作为 Reports / Settings 等次要入口的备选方案；计算器键盘的 `toggle sign` 适合高级模式；表单字段统一用"图标 + 占位符 + 下拉箭头"。

---

### 1.10 Spendee（简述）

- 交易录入是**单屏流程**；有 AI 小票扫描（自动填价格、类目、描述和照片）；Wallets 用来组织现金、银行和"场合"（比如旅行）；有共享钱包、多币种、Labels、深色模式、Web 版（[App Store](https://apps.apple.com/us/app/expense-budget-app-spendee/id635861140)）。
- **吐槽**：最近崩溃多、性能差（"加一笔要 30 秒以上"）；默认币种会被重置；大额支出（机票、家电）没法分摊到多个周期（同上，评论摘要）。

**启示**：录入速度就是生命线，必须把性能当成功能来做；"分摊"在复式记账里可以用多 posting 加未来日期实现（P2）。

---

### 1.11 Beancount / 纯文本记账系移动端

> 说明：任务里提到的 "beancount-mobile by SumiMakito" 我**没有找到公开仓库或资料**（GitHub 和 Web 搜索都只找到 xuhcc 与 beancount.io 两个项目），所以这里用下面几个项目代替。

#### (a) Beancount Mobile（beancount.io，React Native / Expo，MIT）
来源：[mobile/README](https://github.com/bex-co/beancount-io/blob/main/mobile/README.md) 以及仓库里的 25 张官方截图（`mobile/docs/marketing-showcase/webp/`，本文直接查看了这些截图）。
- **导航**：`Home / Accounts / Transactions / Reports / Files` 五个标签；左上角是汉堡菜单，打开账本抽屉（切换账本、看当前服务器）；右上角有 ＋ 和通知铃。
- **Home**：Net Worth / Assets / Liabilities 三个切换；大号金额，下面是相对上期的涨跌、成本和未实现盈亏；面积折线图配 `1M 3M 6M YTD 1Y ALL` 区间 chips；再往下是 Recent Transactions（分类图标 + payee + narration + 金额，收入用绿色 "+"）。
- **Accounts**：Assets / Liabilities / Equity / Income / Expenses 五个可折叠分组；子账户带缩进引导线；右侧是余额，负数用红色；有"N not in total"的提示（有些商品没有价格，没法汇总）。
- **Transactions**：顶部搜索框和过滤按钮；按日期分组，组头是灰底条。
- **Reports**：同样的区间 chips；Income / Expenses 分组柱状图叠 Net Profit 折线；下面是支出分类排行（金额、百分比、横向进度条，带 ›，可以下钻）。
- **Add Transaction（新版）**：DATE / PAYEE / NARRATION 卡片；Postings 卡片每行是"账户 + ± 符号按钮 + 金额"，可以留一行金额为 `auto`；`+ Add posting`；底部有 **Remainder ✓ $0.00** 的平衡指示。
- **Add Transaction（legacy 版）**：大号金额 + **PAYEE / FROM / TO 三个字段** + 数字键盘 + Next。这就是"简单模式"的原型。
- **Account Picker**：顶部是 `All / Assets / Liabilities / Income / Expenses` 标签，下面是**全路径平铺列表**。账户多了以后很难扫读，这是我们要改进的地方。
- **Transaction Detail**：大号金额 + narration；Postings（账户等宽字体并上色，金额带 ±）；Details（Date / Payee / Narration）；`Location: main.bean:3053`；**Entry Context**（这笔交易前后各相关账户的余额）。
- **自托管服务器**：欢迎页右上角有服务器图标，可以填 base URL，并且有 **Test connection** 做"兼容性检查"；release 构建强制 HTTPS；切换服务器会清掉示例缓存，"App 不会静默切换服务器"（README）。鉴权走 OAuth（RFC 9728 / 8414 发现机制 + PKCE）。
- 其他：带语法高亮的源文件编辑器（有快速插入键：日期、flag、引号、账户、币种），保存时校验 checksum；收据拍照；13 种语言；**图标按钮必须有 VoiceOver / TalkBack 标签**，单测会检查（README）。

#### (b) xuhcc/beancount-mobile（NativeScript，Android）
- 功能：加交易、开账户、声明币种、以纯文本查看 beancount 文件、切换文件；没有同步，用 Syncthing（[README](https://github.com/xuhcc/beancount-mobile)）。
- 账本内的配置：`custom "bcm_option" "account_order" "to_from"`，控制交易表单里先显示 "to" 账户还是 "from" 账户；还有允许的 flags、缩进宽度（同上）。**说明"from/to 的顺序"是真实存在的用户偏好。**

#### (c) Fava（Beancount 官方 Web UI）
- 有人提议把 Fava 做成 PWA，理由是让"出门在外加交易"变得可行（[fava#965](https://github.com/beancount/fava/issues/965)）；窄屏下侧栏收起的行为也出现过回归问题（[fava#972](https://github.com/beancount/fava/issues/972)）。**说明 Web UI 的移动端体验确实不足，这正是 zhang-app 的价值所在。**
- 交易表单（`frontend/src/entry-forms/Transaction.svelte`，[beancount/fava](https://github.com/beancount/fava)）：
  - Payee 和 Narration 都有自动补全。**在表单还空着的时候选中某个 payee，会请求 `payee_transaction`，用这个 payee 最近的一笔交易填满整张表**；narration 同理。
  - narration 输入框里可以直接写 `#tag ^link`。
  - postings 的账户建议**按这个 payee 用过的账户排序**（`payee_accounts`）。
  - 最后一行 posting 填了内容，会自动追加一个空 posting；posting 可以拖动排序。
- 排序算法：`src/fava/core/attributes.py` 用 `ExponentialDecayRanker` 给 accounts、currencies、payees、narrations 做指数衰减排名（越近越常用越靠前）。**zhang-app 应该在客户端复刻这个算法。**

#### (d) Costflow
- 把一行文字转换成 Beancount 交易，比如 `@McDonalds 🍔 24 wechat > food`：`@` 是 payee，然后是 narration、金额，最后是账户别名，`>` 表示资金流向；`bofa` 这样的别名会被替换成 `Assets:US:BofA:Checking`；日期可以写 `yesterday` 或 `Jul 25`（[Costflow Syntax](https://www.costflow.io/docs/syntax/)，示例转述自搜索结果，reportedly）。它有 Telegram bot 和桌面 App（[costflow.io](https://www.costflow.io/)）。
- **启示**：给高级用户提供"一行文本记账"的输入方式（P2），并且支持账户别名。

---

### 1.12 横向对比矩阵

| 维度 | 钱迹 | MOZE | 随手记 | 鲨鱼 | Cashew | Ivy | Money Mgr | YNAB | Actual | Beancount Mobile |
|---|---|---|---|---|---|---|---|---|---|---|
| 底部导航 | 首页 + 侧栏 | 首页 + 长按＋切模式 | 6 标签 + 抽屉 | 5 标签，居中记账 | 3 个可自定义 + More | Home / ＋ / Accounts | Trans / Stats / Accounts / More | Home / Plan / Spending… | 可上拉的抽屉式底栏 | 5 标签 + 抽屉 |
| 记账入口 | 首页、小部件、秒开、URL Scheme | ＋、Widget、Watch、Siri、Spotlight | 首页居中、模板 | 居中 | FAB、链接预填 | ＋（带手势）、小部件 | ＋、书签 | 各页底部按钮、长按类目 | Transaction tab | 右上 ＋ |
| 录入顺序 | 类目 → 金额（同屏） | 类目（有建议）→ 金额 → ✓ | 类型 → 金额 → 类目等 | 类目 → 金额 → 备注 | 类型 / 金额 / 类目同屏 | 标题 → 金额 → 类目（自动聚焦） | 类型 → 字段 | 金额 → Payee → 类目 | 金额 → Payee → 类目 → 账户 | 金额 → Payee / From / To（legacy）；postings（新版） |
| 连续记账 | `再记` | 长按 ✓ | 再记一笔 | — | — | — | Continue（reportedly） | — | — | — |
| 智能建议 | 历史 | 时段类目、类目 → 账户 | 模板 | 推荐备注 | 标题 → 类目 | 标题建议 | 书签 | 地点 → payee、payee → 类目 | payee | 账户建议 |
| 拆分 / 多分录 | 手续费 / 优惠 | 拆账 | — | — | — | — | — | split | split | 完整 postings |
| 流水分组 | 月 / 日 | 日 | 日 / 期间看板 | 月头 + 日 | 月选择器 + 日 | 日（日净额） | 日 / 日历 / 周 / 月 | register | register | 日 |
| 报表 | 多维 | 多维、自定义、包含/排除 | 饼图（转指针）+ 条形 | 折线 + 排行 + 高于均值提示 | 饼图 / 折线 / 热力图 | 饼图 / 报表 | 饼图 / 趋势 | Reflect | 自定义报表 | 柱 + 线 + 排行 |
| 收支色可切换 | ✓ | ✓ | ? | ? | 强调色可选 | — | — | — | — | — |

### 1.13 "可直接抄"的模式库（编号供第 2 节引用）

| ID | 模式 | 出处 | 在 zhang-app 的落地 |
|----|------|------|----------------------|
| P-01 | 底部居中的记账按钮，单手可达 | 鲨鱼、随手记、Ivy | NavBar 的中间位 |
| P-02 | 长按 ＋ 切换记账模式 / 模板 | MOZE | 长按中间按钮弹出模式菜单 |
| P-03 | 在 ＋ 上用方向手势直达支出 / 收入 / 转账 | Ivy | 可选，设置里开启 |
| P-04 | 类目宫格 + 键盘同屏 | 钱迹、鲨鱼 | `AddTransactionSheet` |
| P-05 | 二级类目以 chips 形式出现 | 钱迹、Cashew | 第 3 层账户显示为 chips |
| P-06 | 只输正数，符号由模式决定 | MOZE | 支出 / 收入 / 转账模式 |
| P-07 | 类目 → 上次账户记忆 | MOZE | 每个 profile 存一份 `lastFundingByCategory` |
| P-08 | 时段建议类目 | MOZE | "建议" 行（P1） |
| P-09 | payee → 用上一笔交易填表 | Fava、Cashew | 选中 payee 后自动填 |
| P-10 | 指数衰减 frecency 排序 | Fava | 账户、payee、narration 排序 |
| P-11 | `再记` / 长按保存 = 保存并继续 | 钱迹、MOZE | 键盘上的 `再记` 键 |
| P-12 | 日期按钮上下滑动 ±1 天 | 钱迹 | 日期 chip 支持垂直滑动 |
| P-13 | 算式实时显示 + `=` 键 | Cashew、鲨鱼 | `AmountKeypad` |
| P-14 | 键盘布局可选（电话 / 计算器） | MOZE | 设置项 |
| P-15 | 文字输入时不跳页，键盘就地切换 | 鲨鱼 | payee / narration 就地编辑 |
| P-16 | 月头汇总 + 日分组 + 日净额 | 鲨鱼、Ivy、Money Manager | `JournalScreen` |
| P-17 | 日净额为负用中性色 | Ivy | 日头配色 |
| P-18 | Entry Context（交易前后余额） | Beancount Mobile | 交易详情；zhang API 直接返回 `account_before` / `account_after` |
| P-19 | 简单模式 Payee / From / To | Beancount Mobile legacy | 转账模式 |
| P-20 | 完整 postings + Remainder 指示 | Beancount Mobile | 高级模式 |
| P-21 | 区间 chips + 左右切换期间 | MOZE、Beancount Mobile | 报表页 |
| P-22 | 柱状图（收入 / 支出）叠净额折线 + 排行条 | Beancount Mobile、鲨鱼 | 报表页 |
| P-23 | 余额断言式的对账 | MOZE 餘額調整、钱迹手动调余额 | `ReconcileSheet` → `balance` / `pad` |
| P-24 | 信用卡（负债）显示为负数 | 钱迹 | 负债余额的默认显示 |
| P-25 | 收支颜色可切换 | 钱迹、MOZE | 设置项 |
| P-26 | 模板 / 范本 / 书签 | MOZE、随手记、Money Manager | 模板（P1） |
| P-27 | 可保存的高级过滤 | 随手记超级流水、MOZE 报表条件 | P2 |
| P-28 | 首页模块可排序和隐藏 | Cashew | P2 |
| P-29 | 服务器 URL + Test connection，绝不静默切换服务器 | Beancount Mobile | `ServerSetup` |
| P-30 | 隐藏金额 | YNAB Hide Amounts | 眼睛开关 |
| P-31 | 一行文本记账 + 账户别名 | Costflow | P2 |
| P-32 | 拖动连续多选 | Cashew | P2 批量操作 |

---

## 2. zhang-app 推荐设计

### 2.1 设计原则

1. **3 次点击记一笔**：常见情况是"类目 → 金额 → 保存"（P-04、P-07）。payee、narration、日期、标签都可以不填。
2. **复式在底层，单式在表层**：普通模式下，用户看到的是"类目"和"账户"，App 负责生成 postings。高级模式向懂 Beancount 的用户暴露全部能力。两种模式之间可以无损切换：普通模式的结果可以"展开为高级"；能被识别成两条 posting 的高级交易，也可以用普通模式编辑。
3. **服务器是事实来源**：App 不维护自己的账本。所有余额、统计都以 zhang API 为准；本地只做缓存、建议用的排序数据和离线草稿。
4. **账户名就是类目**：不另造"分类"概念。`Expenses:Food:Dining` 就是"餐饮 › 堂食"。显示名优先级是 `alias` > 最后一段。
5. **稳定胜过新颖**：导航和宫格位置保持稳定，不要根据 frecency 重排主宫格，只在"建议"行里动态排序（YNAB 因频繁改 UI 被吐槽；肌肉记忆是记账速度的核心）。
6. **可达性**：所有图标按钮都要有 Semantics 标签（Beancount Mobile 用单测强制这一点，YNAB 在这上面被吐槽过），触控目标 ≥ 48dp，支持系统字体缩放到 200%。

### 2.2 信息架构与导航

```
┌─────────────────────────────────────────────┐
│ App bar（各 tab 自己的）                       │
│                                             │
│                 Tab 内容                      │
│                                             │
├─────────┬─────────┬─────────┬───────┬───────┤
│  首页    │  流水    │  (＋)   │ 报表   │ 账户   │  ← NavigationBar，中间是凸起的 FAB
│  Home   │ Journal │ 记一笔   │Reports│Accounts│
└─────────┴─────────┴─────────┴───────┴───────┘
```

| Tab | 图标（Material Symbols） | 根页面 | 二级入口 |
|-----|--------------------------|--------|----------|
| 首页 Home | `home` | `HomeScreen` | app bar：ProfileSwitcher、Search、Settings、Errors badge |
| 流水 Journal | `receipt_long` | `JournalScreen` | Search & Filter、TransactionDetail |
| 记一笔 | `add`（FAB，居中） | 弹出 `AddTransactionSheet`（不是 tab） | 长按弹出模式菜单：支出、收入、转账、高级、对账、模板（P-02） |
| 报表 Reports | `bar_chart` | `ReportsScreen`（顶部分段：收支 / 预算） | BudgetDetail、分类下钻 |
| 账户 Accounts | `account_balance_wallet` | `AccountsScreen` | AccountDetail、Reconcile、Commodities |

- 用 Flutter 的 `NavigationBar`，4 个 destination，中间留一个空位，上面叠一个 `FloatingActionButton.large`（自定义 `FloatingActionButtonLocation`，居中，下沉一半）。M3 规定导航栏放 3–5 个 destination（[M3 Navigation bar](https://m3.material.io/components/navigation-bar/overview)），我们是 4 个 destination 加一个动作按钮，没有违反。
- **Settings 不占 tab**：入口在 Home app bar 右上角的齿轮。服务器 / 账本切换放在 Home app bar 的标题上（点标题弹出 `ProfileSwitcherSheet`），这和 Beancount Mobile 的账本抽屉作用相同，但更轻。
- 平板 / 横屏（P2）：宽度 ≥ 600dp 时换成 `NavigationRail`，Journal 和 Detail 做双栏（Cashew 也有宽屏侧栏）。
- 路由建议（go_router）：`/home`、`/journal`、`/journal/:txnId`、`/reports?seg=cashflow|budget&period=…`、`/budgets/:name`、`/accounts`、`/accounts/:accountName`、`/settings`、`/settings/servers/:profileId`、`/errors`、`/documents`、`/commodities/:name`、`/onboarding/*`。记一笔是 modal route `/add?mode=expense&account=…`，方便以后接 App Shortcuts 和深链（P2，借鉴钱迹 URL Scheme、MOZE 捷径）。

### 2.3 记账模式 → postings 映射（核心）

zhang 的建交易接口是 `POST /api/transactions`，请求体是 `CreateTransactionRequest { datetime, payee, flag?, narration?, postings[{account, unit?}], metas[], tags[], links[] }`，`unit` 可以为空，由账本推断（见 zhang `zhang-server/src/request.rs`）。各模式的映射如下（金额 `A > 0`，币种 `C`）：

| 模式 | UI 选择 | 生成的 postings | 列表显示 |
|------|---------|-----------------|----------|
| **支出 Expense** | 类目 = `Expenses:X`（宫格），资金账户 = `Assets:Y` 或 `Liabilities:Y` | `Expenses:X  +A C`<br>`Assets:Y  −A C` | `−A`，支出色 |
| **收入 Income** | 类目 = `Income:X`，入账账户 = `Assets:Y`（或 `Liabilities:Y`，比如退款进信用卡） | `Assets:Y  +A C`<br>`Income:X  −A C` | `+A`，收入色 |
| **转账 Transfer** | From = `Assets/Liabilities:F`，To = `Assets/Liabilities:T` | `T  +A C`<br>`F  −A C` | `A`，中性色，副标题 `F → T` |
| **还信用卡** | 转账的特例：To 是 `Liabilities:*` | 同转账 | 同转账，图标用 credit_card |
| **退款**（P1） | 支出交易详情里的"退款"动作（MOZE 一键退款） | `Assets/Liab:Y  +R C`<br>`Expenses:X  −R C` | `+R`，收入色，"退款"标签 |
| **手续费**（P2，钱迹 / MOZE） | 转账时多填一个 fee | `T +A`、`F −(A+fee)`、`Expenses:Fees +fee` | 转账 + "含手续费"标签 |
| **高级 Advanced** | 自由编辑 N 条 posting | 原样提交；允许最多一条 `unit = null`（auto） | 按下面的分类规则判断 |
| **对账 Reconcile** | 账户 + 实际余额 | 不是交易：调用 `POST /api/accounts/:name/balances`（`Check` 或 `Pad`） | 流水里显示为余额断言行 |

**两条 posting 都显式写金额**（不用 auto），这样服务器端的推断不会出意外，日后在文本文件里也一目了然。只有高级模式才允许 auto。

**交易显示分类算法**（Journal、Home、详情共用一个纯函数 `classify(txn)`）：
1. 按账户第一段统计 postings 的类型集合 `S`。
2. `S ⊆ {Assets, Liabilities}` → **转账**。金额取正向 posting 之和；颜色中性。
3. `Expenses ∈ S` 且 `Income ∉ S` → **支出**。金额 = Σ Expenses posting（>0）；如果 Σ < 0，说明是退款，归为"收入 / 退款"。
4. `Income ∈ S` 且 `Expenses ∉ S` → **收入**。金额 = −Σ Income posting。
5. `Income` 和 `Expenses` 同时存在（比如工资扣税）→ **复合**。金额 = Assets + Liabilities 的净变化，带"多分录"徽标。
6. 含 `Equity` → **调整 / 期初**，中性色，图标 `balance`。
7. 多币种：每个币种分别求和；行尾显示主币种金额，加一个"+1 币种"徽标；详情页里全部列出。

**类目宫格 / 图标的推导**
- 支出模式下，宫格 = `Expenses` 的第 2 层账户（`Expenses:Food`、`Expenses:Transport`…）。选中后，如果它有子账户，就在宫格下方出现子类目 chips（`Dining`、`Groceries`…），**可以不选**（不选就记到父账户）。前提是父账户在 zhang 里是 open 的；如果父账户没有 open，就强制选子类目，在 chip 行加"必选"提示。
- 宫格顺序：默认按 `/api/for-new-transaction` 返回的顺序；用户可以在设置里拖动排序（钱迹的分类管理同样是"长按拖动排序"，见[分类管理](https://docs.qianjiapp.com/fen-lei-guan-li.html)）。**顺序固定，不随 frecency 变动。**
- 图标：如果账户 `open` 的 meta 里有 `icon: "restaurant"`，就用它（**需要和 zhang 约定这个 meta 键**，见第 5 节开放问题）；没有的话，按关键字字典匹配（`Food|餐|饮 → restaurant`、`Transport|交通 → directions_bus`、`Rent|房租 → home`、`Salary|工资 → payments` …）；再没有，就用名称首字作为文字头像（钱迹"没有图标时取名称第一个字"，见[分类管理](https://docs.qianjiapp.com/fen-lei-guan-li.html)）。
- 顶部"建议"行（P1）：4 个 chip，按当前时段 + frecency 计算（P-08、P-10）。

**多币种的约束**：`CreateTransactionPostingRequest` 目前只有 `account` + `unit`，**没有 cost / price**。所以跨币种交易（比如用 USD 卡付 CNY 账单、`@ price`）在现有 API 下表达不了。MVP 只支持同一币种的 postings；高级模式里如果出现两种币种，要提示"需要服务端支持 price"（见第 5 节）。

---

### 2.4 逐屏规格（Screen specs）

> 每个屏都写了：目的 / 布局 / 组件 / 字段与数据来源 / 交互 / 状态。API 路径来自 zhang-server（`zhang-server/src/lib.rs`），字段的细节以 API 文档为准。

#### S01 `ServerSetupFlow`（首次启动 / 添加服务器）— P0

**目的**：配置自定义 endpoint 和鉴权，验证通过后保存成一个 profile。

**步骤与布局**
```
[1/3 服务器地址]                     [2/3 鉴权]                         [3/3 测试连接]
 Profile 名称 [ 家庭账本      ]        鉴权方式 (SegmentedButton)          ✓ 地址可达 (DNS/TCP/TLS)  120ms
 服务器地址   [ https://zhang.e… ]      [无][Basic][Bearer][自定义]         ✓ zhang 服务响应 /api/info
   ⓘ 例：https://ledger.example.com   Basic: 用户名 [   ] 密码 [  👁]      ✓ 鉴权通过
 □ 允许 HTTP（不安全）⚠              Bearer: Token [ ••••••  👁]         ✓ 读取账本：「家庭账本」 v0.x
 颜色标记 ● ● ● ● ●                   自定义 Header: [+ 添加]              ⚠ 账本有 3 个错误（可稍后查看）
 [下一步]                              Key [CF-Access-Client-Id] Val[••]  
                                      高级：超时 [15s]                    [返回修改]   [保存并进入]
```

**组件**：`TextField`（URL 用 `keyboardType: url`，失焦时做校验）、`SegmentedButton<AuthType>`、`PasswordField`（带显隐切换）、`HeaderListEditor`（key/value 行，每行有"敏感"开关，敏感的值打码）、`ColorTagPicker`、`ConnectionCheckList`（逐项显示 ⏳ / ✓ / ✗ / ⚠，附耗时和错误详情）、`FilledButton`。

**字段**：`profileName`、`baseUrl`（自动去掉末尾 `/`；没写 scheme 时默认补 `https://`）、`allowInsecureHttp`、`authType ∈ {none, basic, bearer, headers}`、`username`、`password`、`token`、`headers[{key, value, secret}]`、`timeoutSec`、`colorTag`。可以同时有 Basic 和自定义 Header（比如前面有 Cloudflare Access，后面是 zhang 的 Basic），所以 UI 上"自定义 Header"做成一个**和鉴权方式无关的附加区块**。

**Test Connection 的检查项**（按顺序执行；任何一步失败就停下，把原因和建议显示在对应行下方）：
1. **地址解析和可达性**：URL 合法吗？是不是 HTTP 但没勾"允许 HTTP"？DNS、TCP、TLS 是否成功（证书错误单独提示）。
2. **zhang 服务识别**：`GET /api/info`，期望 200，JSON 里有 `version`（`BasicInfoEntity { title, version, build_date }`）。如果返回的是 HTML（比如登录页或反代页面），提示"看起来不是 zhang 服务，可能被代理拦截"。
3. **鉴权**：zhang 的 Basic Auth 作用在整个 router 上（`ValidateRequestHeaderLayer::basic`，见 `zhang-server/src/lib.rs`），所以第 2 步收到 401 就说明凭据不对；收到 403 或 302 到登录页，多半是 Cloudflare Access 之类的网关（这时提示用 Service Token 头 `CF-Access-Client-Id` / `CF-Access-Client-Secret`，见 [Cloudflare 文档](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/)）。
4. **账本读取**：`GET /api/for-new-transaction`（拿到账户数和 payee 数）、`GET /api/errors`（数量 > 0 只给 ⚠，不阻断）。
5. **写权限**：API 没有无副作用的写探测，**MVP 不测**，界面上写明"首次记账时验证写权限"。

**错误文案对照**

| 现象 | 文案 | 建议操作 |
|------|------|----------|
| DNS 失败 | 找不到服务器 | 检查地址拼写或网络 |
| 超时 | 连接超时（15s） | 检查端口、防火墙或 VPN |
| TLS 错误 | 证书无效或不受信任 | 用有效证书，或者（P2）信任自签证书指纹 |
| 401 | 用户名或密码错误 | 回到第 2 步 |
| 403 / 网关 HTML | 被网关拦截 | 添加网关要求的 Header |
| 404 `/api/info` | 地址不是 zhang 服务根路径 | 检查是否漏了子路径 |
| JSON 解析失败 | 服务版本不兼容 | 显示服务器版本，提示升级 |

**交互**：每一步都可以返回；"保存并进入"后进入 Home，并在后台预取账户列表。凭据存进 `flutter_secure_storage`（iOS Keychain / Android Keystore，[pub.dev](https://pub.dev/packages/flutter_secure_storage)），profile 的其他元数据存本地数据库。**绝不静默切换服务器**（P-29）：只有用户在 ProfileSwitcher 里明确选择才会切换。

#### S02 `HomeScreen` — P0

**布局**
```
┌ AppBar ─────────────────────────────────────┐
│ ● 家庭账本 ▾          🔍  ⚠3  ⚙              │  ← 颜色点 = profile 标记；⚠ = 账本错误数
├─────────────────────────────────────────────┤
│ ◀  2026年10月  ▶                     👁      │  MonthSwitcher + 隐藏金额开关
│ ┌ SummaryCard ────────────────────────────┐ │
│ │ 本月支出                                  │ │
│ │ ¥ 3,210.50                     (display) │ │
│ │ 收入 ¥12,000.00   结余 ¥8,789.50          │ │
│ │ ▁▂▅▂▃▁▇ 每日支出 sparkline                 │ │
│ └─────────────────────────────────────────┘ │
│ ┌ BudgetCard ─────────────────────────────┐ │
│ │ 本月预算  已用 64%  ███████░░░            │ │
│ │ 餐饮 超支 ¥120 · 交通 剩 ¥80              │ │  只显示最需要关注的 2–3 个
│ └─────────────────────────────────────────┘ │
│ 模板  [☕ 咖啡 ¥28] [🚇 地铁] [+]              │  QuickTemplatesRow（P1）
│ 最近交易                              全部 › │
│  今天 10月2日                     −¥128.50   │
│  🍜 海底捞  · 招行信用卡            −¥98.50   │
│  ☕ 星巴克  · 微信                  −¥30.00   │
│  昨天 …                                      │
└─────────────────────────────────────────────┘
```
**组件**：`ProfileTitleButton`、`ErrorsBadgeIconButton`、`MonthSwitcher`、`SummaryCard`（大号金额用 `displaySmall` + tabular figures）、`Sparkline`（fl_chart LineChart，不画坐标轴）、`BudgetSummaryCard`、`QuickTemplatesRow`（P1）、`TransactionTile`、`DayHeader`。

**数据**：
- `GET /api/statistic/summary?from=月初&to=月末` → `income`、`expense`（`CalculatedAmount`，显示 `calculated`），结余 = 收入 − 支出（注意 Income 在账本里是负数，按服务端口径做符号转换）。
- `GET /api/statistic/graph?from&to&interval=Day` → `changes[date][Expenses]` 画每日支出的 sparkline。
- `GET /api/budgets?year&month` → 汇总 `assigned_amount` / `activity_amount`，按 available 从低到高取前 3 个。
- `GET /api/journals?page=1&size=20`。

**交互**：下拉刷新；点 SummaryCard 进入 Reports（同一期间）；点 BudgetCard 进入 Reports › 预算；点交易进入详情；左右滑动 SummaryCard 或点 ◀ ▶ 切换月份（**最近交易**一直显示最新的，不跟着月份变）；👁 切换隐藏金额（P-30）。
**状态**：首次加载时卡片显示骨架屏；账本为空（0 笔交易）时显示 `EmptyLedgerCard`（"还没有交易，点 ＋ 记第一笔"）；单个卡片请求失败只在卡片内显示"加载失败 · 重试"，不影响整页。

#### S03 `AddTransactionSheet`（记一笔）— P0

**容器**：全屏 modal bottom sheet（`showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`），从中间按钮弹出；也可以从账户详情、模板、交易"复制"进入，带预填参数。

**布局（支出 / 收入模式）**
```
┌──────────────────────────────────────────────┐
│ ✕   [ 支出 | 收入 | 转账 | 高级 ]          模板 ☆ │  ModeSegmentedButton
├──────────────────────────────────────────────┤
│ 建议: [早餐] [咖啡] [地铁] [午餐]               │  SuggestionChipsRow（P1）
│ ┌────┐┌────┐┌────┐┌────┐┌────┐               │
│ │ 🍜 ││ 🚇 ││ 🛒 ││ 🏠 ││ 🎮 │  CategoryGrid │  第 2 层 Expenses 账户（5 列）
│ │餐饮││交通││购物││居住││娱乐│                │
│ └────┘└────┘└────┘└────┘└────┘ … 可上下滚动    │
│ 子类目: (堂食) (外卖) (咖啡) (夜宵)              │  SubcategoryChips（可不选）
├──────────────────────────────────────────────┤
│ [📅 今天 ⇅] [💳 招行信用卡 ▾] [# 标签] [📎]      │  MetaChipsRow
│ 商户 Payee   [ 海底捞            ] 建议: 海底捞 ·  │  PayeeField（有补全）
│ 备注 Narration [ 和同事聚餐       ]               │
├──────────────────────────────────────────────┤
│                         98 + 30.5            │  ExpressionLine
│ CNY ▾                    ¥ 128.50            │  AmountDisplay（headlineLarge）
│ ┌─────┬─────┬─────┬─────┐                    │
│ │  1  │  2  │  3  │  ⌫  │                    │
│ │  4  │  5  │  6  │  +  │   AmountKeypad     │
│ │  7  │  8  │  9  │  −  │                    │
│ │  .  │  0  │ 再记 │ 保存 │  （有未算完的算式时，"保存"变成 "="）│
│ └─────┴─────┴─────┴─────┘                    │
└──────────────────────────────────────────────┘
```
- 收入模式：宫格换成 `Income` 的第 2 层；资金 chip 的文案改成"存入"。
- 转账模式：宫格区换成两张 `AccountCard`（From / To）+ 中间一个 ⇅ 交换按钮（P-19）；From / To 的显示顺序可以在设置里改（xuhcc 的 `account_order` 证明有人需要）。
- 高级模式：见 S06。

**组件**：`ModeSegmentedButton`、`SuggestionChipsRow`、`CategoryGrid`（`SliverGrid`，每个 tile 72×72dp，图标 + 2 行以内的标签；选中时用 `secondaryContainer` 背景 + 勾）、`SubcategoryChips`（`ChoiceChip` 横向滚动）、`DateChip`、`FundingAccountChip`（打开 S04）、`TagsChip`、`AttachChip`（P1）、`PayeeField`、`NarrationField`、`ExpressionLine`、`AmountDisplay`、`CommodityButton`、`AmountKeypad`（见 2.5）。

**字段 → 请求**

| UI | 请求字段 | 默认值 |
|----|----------|--------|
| 日期 chip | `datetime` | 当前时间（ISO8601，带时区）；如果选的是"非今天的日期"，时间取本地 12:00，避免跨时区错日 |
| 类目 / 子类目 | `postings[0].account` | 无（必选） |
| 资金账户 | `postings[1].account` | 该类目上次用的账户（P-07）→ 设置里的默认账户 → 第一个 Assets 账户 |
| 金额 + 币种 | `postings[*].unit = {number, currency}` | 币种默认用资金账户的币种，没有就用 operating currency（`GET /api/options`） |
| Payee | `payee` | `""`（接口要求必填字符串；为空时，**列表里用类目名作标题**） |
| Narration | `narration` | null |
| 标签 | `tags[]` | [] |
| 待确认开关（P1） | `flag = Warning(!)` | `Okay(*)` |
| 来源 meta（P1） | `metas[{key:"zhang-app-id", value: uuid}]` | 用于离线重试去重（见 2.10） |

**交互细节**
- 打开时焦点直接在键盘上（不弹系统键盘）；宫格默认**不预选**。保存时如果没选类目，类目区抖动并提示"请选择类目"。钱迹默认选第一个类目（[添加收支](https://docs.qianjiapp.com/ji-zhang-jie-mian/tian-jia-shou-zhi.html)），但对复式记账来说记错类目的代价更高，所以我们不默认选。
- 点 Payee 或 Narration：同屏切换成系统键盘，键盘区域被系统键盘替换，**不跳页**（P-15）；收起系统键盘后恢复数字键盘。
- **选中 payee 补全项**：如果表单里除了金额都还空着，就用这个 payee 最近一笔交易填类目、资金账户和 narration（P-09，参考 Fava 只在空表单时填充的逻辑）；金额只作为 hint 显示（"上次 ¥98.50"），点 hint 才填入。
- `DateChip`：点开是 `showDatePicker`；**在 chip 上垂直滑动 ±1 天**（P-12）；只要不是今天，chip 就高亮显示日期。
- `保存`：校验通过后提交 → 成功就关闭 sheet，SnackBar 显示"已记账 −¥128.50 · 餐饮　查看"，同时让 Journal、Home、Accounts 的缓存失效。
- `再记`（P-11）：提交成功后**不关闭**，保留 模式 / 日期 / 资金账户，清空 金额 / 类目 / payee / narration；顶部显示一个计数小标签"本次已记 3 笔"。
- 下拉 sheet 关闭时，如果有未保存的输入，询问"放弃这笔？"（防误触）。MOZE 的"下拉保存"（[記帳小技巧](https://doc.moze.app/record/tips)）和 bottom sheet 的下拉关闭手势冲突，**不采用**。
- 长按中间按钮（P-02）：弹出 `ModeMenu`（支出 / 收入 / 转账 / 高级 / 对账 / 模板列表），直接以对应模式打开。
- Ivy 式手势（P-03）：设置里开启后，在中间按钮上**上滑 = 支出、左上 = 收入、右上 = 转账**。默认关闭。

**状态**：提交中，保存按钮显示 spinner，其余输入锁定；网络失败时 SnackBar 显示"未能保存（网络）· 存为草稿 / 重试"（P1 起自动进 Outbox）；服务端 4xx（比如账户未 open、不平衡）时，在 sheet 内显示错误条，原文附在可展开区域里。

#### S04 `AccountPickerSheet` — P0

```
┌──────────────────────────────────────────┐
│ 选择资金账户                          ✕   │
│ 🔍 [ 搜索：名称 / 别名 / 任意一段 ]          │
│ ⭐ 收藏    招行信用卡 −2,703.29 · 微信 312.00│  横向 chips
│ 🕘 最近    支付宝 · 现金 · 工资卡             │
│ [资产 | 负债]  (按模式过滤后剩下的类型 tabs)   │
│ ▾ Assets                       120,352.78 │
│   ▾ Bank                                  │
│     ├ 招商银行储蓄  CMB:Savings   2,754.06 │
│     └ 工商银行      ICBC          1,000.00 │
│   ▸ Alipay                       312.00   │
│ ▾ Liabilities                             │
│   └ 招行信用卡  CMB:Credit      −2,703.29  │
└──────────────────────────────────────────┘
```
- **按模式过滤**：支出 / 收入的资金账户只列 Assets + Liabilities；类目选择（在宫格里找不到时用"更多…"）只列 Expenses 或 Income；高级模式列全部类型，tab 是 `全部 / 资产 / 负债 / 收入 / 支出 / 权益`。
- 每行显示：图标、显示名（alias 或最后一段）、muted 的全路径、余额（只对 Assets / Liabilities 显示，数据来自 `GET /api/accounts` 的 `amount.calculated`）。已关闭账户（`status` 为 `Close`，见 zhang `zhang-core/src/domains/schemas.rs`）不显示。
- **搜索**：大小写不敏感，匹配任意一段、alias 或拼音首字母（P2，用 `lpinyin`）；结果平铺显示，命中部分高亮。
- 长按一行可以收藏 / 取消收藏（收藏存在本地，按 profile 分开）。
- 选中即返回，同时更新"最近"列表（frecency，P-10）。

#### S05 Payee / Narration / Tag 输入 — P0（补全）/ P1（时段建议）
- 数据源：`GET /api/for-new-transaction` → `payee[]`、`account_name[]`；narration 和标签的历史来自本地缓存的最近 N 笔交易（启动后后台拉 `GET /api/journals?page=1..k&size=200`，最多 1000 笔）。
- 排序：`score = Σ exp(−Δdays / 30)`（半衰期常数可调），对应 Fava 的 `ExponentialDecayRanker`（P-10）。
- 显示：输入框下方的 `SuggestionChipsRow` 最多 6 个，横向滚动；输入时按前缀 + 包含匹配过滤。
- 标签 chip：点开是多选 `FilterChip` 列表，可以新建；narration 里写 `#tag` 会自动识别成标签（Fava 支持在 narration 里写 `#tag ^link`）。
- payee → 默认类目的更新规则（P1）：借 YNAB 的"最近 3 笔里有 2 笔"才切换默认值，避免偶然的一次改动污染记忆。

#### S06 `AdvancedEntryScreen`（多 posting 编辑器）— P1
```
┌ 新交易（高级） ───────────────────── 保存 ┐
│ 日期 2026-10-02     Flag (*) (!)          │
│ Payee     [ 山姆会员店        ]            │
│ Narration [ 周末采购 #家庭     ]            │
│ Links     [ ^trip-2026 ]                  │
│ ── Postings ───────────────────────────── │
│ ≡ Expenses:Food:Groceries   [+] 320.00 CNY│
│ ≡ Expenses:Home:Supplies    [+]  80.00 CNY│
│ ≡ Liabilities:CMB:Credit    [−]   auto    │  ← 留空 = 自动配平
│ ＋ 添加分录                                 │
│ ─────────────────────────────────────────│
│ 余差 Remainder        ✓ 0.00 CNY          │  不平时是 ✗ 并显示差额（error 色）
│ ▸ Meta（键/值）                            │
└───────────────────────────────────────────┘
```
- 组件：`PostingRow`（拖动柄 ≡、账户按钮 → S04、± 切换、金额输入 → 弹出 `AmountKeypad`、币种）、`RemainderBar`（按币种逐个显示）、`MetaEditor`。
- 规则：最多一条金额为 `auto`（`unit: null`）；不平且没有 auto 行时，禁用保存；最后一行填写后自动追加一个空行（Fava 的行为）；左滑删除一行。
- 从普通模式点"展开为高级"时，把已经生成的两条 posting 带进来（无损切换）。
- 跨币种：出现第二种币种时，RemainderBar 分币种显示，同时提示"跨币种需要 price（当前 API 不支持）"（见第 5 节）。

#### S07 `JournalScreen`（流水）— P0
```
┌ 流水 ──────────────────────── 🔍  ⚙︎过滤 ┐
│ [全部] [支出] [收入] [转账] [#旅行 ✕]       │  FilterChipsBar（服务端过滤：keyword/tags/links）
├─────────────────────────────────────────┤
│ 2026年10月   支出 ¥3,210.50  收入 ¥12,000 │  StickyMonthHeader（吸顶）
│ 10月2日 周五                    −¥128.50 │  DayHeader（日净额；负数用中性色，P-17）
│ 🍜 海底捞                        −98.50  │
│    和同事聚餐 · 招行信用卡 · 📎            │
│ ⇄ 还信用卡                     2,703.29  │  转账：中性色，副标题 "工资卡 → 招行信用卡"
│ ✓ 余额断言 · 招商银行储蓄       2,754.06  │  BalanceCheck 行：图标 + 断言金额
│ 10月1日 周四                  +¥11,871.50│
│ 💰 公司（工资）               +12,000.00  │
│ …（无限滚动）                              │
└─────────────────────────────────────────┘
```
- 数据：`GET /api/journals?page&size=50&keyword&tags&links` → `Pageable<JournalItemEntity>`（`Transaction | BalanceCheck | BalancePad`）。月头的汇总按月请求 `GET /api/statistic/summary`（滚到某个月才懒加载并缓存）。**日净额由客户端根据已加载的条目计算**；如果分页边界正好切在某一天中间，这一天的净额先不显示（或显示 "…"），等这一天加载完整再显示。
- `TransactionTile` 字段：
  - 图标：类目图标；转账用 ⇄；断言用 ✓ / ✗；调整用 ⚖。
  - 标题：payee → narration → 类目显示名。
  - 副标题：narration（如果标题用的是 payee）· 资金账户显示名 · 标签。
  - 尾部：金额（按 2.3 的分类上色和加符号）。
  - 徽标：`!` flag 显示 tertiary 色的点；有附件显示 📎；不平衡（`is_balanced = false`）时用 error 色描边并显示 ⚠。
- 交互：
  - 点击进入详情；
  - **右滑 → "复制为新交易"**（打开 S03 并预填，日期改为今天；MOZE 有"複製記錄帶入時間"的偏好可以借鉴）；
  - **左滑 → "编辑"**（API 没有删除接口，所以不提供删除滑动，见第 5 节）；
  - 长按进入多选（P2，P-32）；
  - 顶部 chip 快速过滤；
  - 下拉刷新。
- 状态：空账本显示插画 + "记第一笔"；过滤后无结果显示"没有匹配的交易 · 清除过滤"；分页加载失败时，列表底部显示"加载更多失败 · 重试"。

#### S08 `TransactionDetailScreen` — P0（只读）/ P1（编辑、附件）
```
┌ ←                              ✎  ⧉  ⋯ ┐
│            −¥128.50                    │  hero 金额 + 类型 chip（支出）
│         海底捞 · 和同事聚餐               │
│ ── 分录 Postings ────────────────────── │
│ Expenses:Food:Dining      +128.50 CNY › │  点击 → AccountDetail
│ Liabilities:CMB:Credit    −128.50 CNY › │
│ ── 详情 ─────────────────────────────── │
│ 日期 2026-10-02 19:32   Flag *           │
│ 标签 #聚餐   链接 ^…                      │
│ Meta  key: value …                       │
│ ── 余额变化 Entry Context ────────────── │  P-18
│ Expenses:Food:Dining   1,000.00 → 1,128.50│
│ Liabilities:CMB:Credit −2,575 → −2,703.29│
│ ── 附件 ─────────────────────────────── │
│ [🧾 thumb] [＋ 添加]                      │
└─────────────────────────────────────────┘
```
- 数据：列表项本身已经带全了（`JournalTransactionItemEntity`：`postings[].account / unit / cost / inferred_unit / account_before / account_after`、`tags`、`links`、`flag`、`metas`、`is_balanced`）。所以详情页**不需要再发请求**，直接复用列表数据（用 id 作为路由参数；深链进入时再从缓存或分页里找）。附件：`GET /api/documents` 按 `trx_id` 过滤（或者从 metas 里找 document）。
- 动作：
  - `✎ 编辑` → 能用两条 posting 表达的交易进 S03，否则进 S06；提交走 `PUT /api/transactions/:id`。
  - `⧉ 复制`。
  - `⋯` → 复制为 zhang 文本（按 Beancount 语法渲染这一笔，方便贴到文件或聊天里）/ 分享 / 退款（P1）。
- 附件：`＋ 添加` → 拍照或相册 → `POST /api/transactions/:id/documents`（multipart）；缩略图点开全屏查看（`GET /api/documents/:path`）。

#### S09 `SearchScreen` & `FilterSheet` — P1
- 搜索框：服务端 `keyword`（实际匹配哪些字段以 API 文档为准，**reportedly** 是 payee / narration）；最近搜索历史存在本地。
- `FilterSheet`：
  - 服务端能做的：标签（多选）、链接。
  - 客户端或 SQL 才能做的（P2）：日期区间、账户（单个账户可以直接用 `GET /api/accounts/:name/journals`）、金额区间、类型（支出 / 收入 / 转账）。
  - P2 可以用 `POST /api/sql` 组合查询（需要确认 SQL schema 的稳定性）。
- 保存过滤器（P2，P-27）：命名之后出现在 Journal 顶部的 chip 栏。

#### S10 `ReportsScreen`（报表）— P0（收支）/ P1（预算段）
```
┌ 报表 ─────────────────────────────────────┐
│ [ 收支 | 预算 ]                              │  顶部 SegmentedButton
│ [周][月][年][自定义]    ◀ 2026年10月 ▶       │  PeriodSelector（P-21）
│ 支出 ¥3,210  收入 ¥12,000  结余 ¥8,790  42笔 │  KpiRow
│ ┌ 收支趋势 ──────────────────────────────┐ │
│ │ ▇▅  ▇▃  ▇▆ … 收入/支出分组柱 + 净额折线    │ │  月视图按日或周，年视图按月
│ └────────────────────────────────────────┘ │
│ [支出 | 收入]   分类占比                      │
│ ┌ Donut（≤6 段+其他）┐  餐饮  ¥1,200  37% ▇▇▇ │  CategoryRankList（P-22）
│ └─────────────────┘  居住  ¥900   28% ▇▇    │  点击 → 下一层账户 → 再点 → 账户流水
│ 最大的几笔  Top transactions                  │
└───────────────────────────────────────────┘
```
- 数据：
  - KPI 来自 `GET /api/statistic/summary?from&to`。
  - 趋势来自 `GET /api/statistic/graph?from&to&interval=Day|Week|Month`（`changes[date][AccountType]`）。
  - 分类排行和 Top transactions 来自 `GET /api/statistic/Expenses?from&to`（或 `/Income`）→ `detail[{account, amount}]`、`top_transactions[]`。
  - **下钻层级由客户端按账户前缀聚合**：第一层聚合到第 2 段（`Expenses:Food`），点进去再展开第 3 段。
- 交互：左右滑动图表区切换期间；点柱子显示 tooltip（日期、收入、支出、净额），再点一次跳到 Journal（预设日期过滤，P2）；排行行可以点；**不做旋转饼图**（随手记的反面教材）。
- "高于平均"标记（借鉴鲨鱼）：同一分类本期比过去 3 个期间的平均值高 20% 以上，就在行尾加 ↑ 和 tertiary 色（P1）。
- 净资产走势放在 Accounts 页的头部，不在这里（避免重复）。

#### S11 `BudgetsScreen`（报表 › 预算段）+ `BudgetDetailScreen` — P1
```
┌ ◀ 2026年10月 ▶ ─────────────────────────────┐
│ 已分配 ¥5,000   已花 ¥3,210   可用 ¥1,790      │  BudgetSummaryHeader
│ ── 日常开销（category）─────────────────────── │
│ 餐饮 Monthly Food   可用 −¥120   ██████████▌ ⚠ │  超支：error 容器色
│      已花 1,320 / 分配 1,200 · 剩 29 天          │
│ 交通                可用 ¥80    ███████░░░     │
│      已花 220 / 分配 300 · 日均可用 ¥2.7        │
│ ── 未分类 ──────────────────────────────────── │
└─────────────────────────────────────────────┘
```
- 数据：`GET /api/budgets?year&month` → `BudgetListItemEntity { name, alias, category, closed, assigned_amount, activity_amount, available_amount }`，按 `category` 分组（zhang 预算的 `category` meta 本来就是为前端分组设计的，见 zhang 文档 `directives/4-budget.md`）。
- `BudgetTile`：显示名用 alias → name；进度 = activity / assigned；状态色：available ≥ 20% 为正常（primary），0–20% 为 warning（tertiary），< 0 为超支（error，带 ⚠ 图标，**不只靠颜色**）。"日均可用 = available / 本月剩余天数"。
- `BudgetDetailScreen`：头部显示三个数；`related_accounts` chips（点击进 AccountDetail）；`GET /api/budgets/:name/interval/:year/:month` 返回的事件时间线（`BudgetEvent`：分配 / 转移；`Posting`：消费），按日分组；历史柱状图（近 6 个月的 assigned 和 activity，P2，需要按月循环请求）。
- **写操作**：zhang 的 `budget-add` / `budget-transfer` 目前**没有对应的写 API**，所以 MVP 的预算是只读的。将来要么扩展 API，要么通过 `PUT /api/files/:path` 追加指令（风险高，见第 5 节）。
- 空状态："账本里还没有 budget 指令"，附一个示例代码块和文档链接。

#### S12 `AccountsScreen`（账户）— P0
```
┌ 账户 ─────────────────────────── 🔍  ⋯ ┐
│ 净资产                                   │
│ ¥ 117,649.49                    ▲ 2.1%  │  NetWorthCard（P1 加走势图）
│ 资产 ¥120,352.78   负债 −¥2,703.29        │
│ [1M][3M][6M][YTD][1Y][ALL]  ╱‾‾╲_╱‾      │  （P1）
│ [资产 负债 | 收入 支出 权益]                 │  ScopeSegmentedButton，默认资产负债
│ ▾ 资产 Assets                120,352.78 │
│ │ ▾ Bank                       3,754.06 │  父节点：子账户汇总
│ │ │  招商银行储蓄 CMB:Savings     2,754.06 │
│ │ │  工商银行  ICBC              1,000.00 │
│ │ ▸ Investment                 89,651.30│
│ │   USD 账户          1,200.00 USD  ⌄   │  多币种：主值 + 展开
│ ▾ 负债 Liabilities            −2,703.29 │
│ │   招行信用卡                 −2,703.29 │
└──────────────────────────────────────────┘
```
- 数据：`GET /api/accounts` → `AccountEntity { name, status, alias, amount: CalculatedAmount { calculated, detail{commodity: number} } }`。**树由客户端按 `:` 切分构建**；父节点（可能并没有 open）的余额 = 子账户按币种求和，"换算后合计"用各子账户 `calculated` 的和。净资产 = Assets + Liabilities 的 `calculated`（负债本身是负数，直接相加），也可以用 summary 接口的 `balance` 与 `liability` 交叉校验。走势来自 `GET /api/statistic/graph` 的 `balances`（P1）。
- 组件：`NetWorthCard`、`RangeChips`、`AccountTreeView`（自绘缩进引导线，每级 16dp；层级超过 4 级时，第 5 级起不再缩进，改为在行内显示面包屑）、`AccountRow`、`MultiCommodityExpander`。
- 交互：点父节点折叠或展开（折叠状态本地记住）；点叶子进入 AccountDetail；长按弹出菜单（记一笔 / 对账 / 上传文档 / 复制账户名 / 收藏）；⋯ 菜单里有：显示已关闭账户、隐藏零余额账户、树形或平铺、负债显示为正数（P1，见 3.3）。
- 状态：没有任何 open 账户时显示 "账本里还没有 `open` 指令"，附示例；余额里有无法换算的商品时，在合计旁边显示 "1 项未计入合计 ⓘ"（Beancount Mobile 的 "N not in total"）。

#### S13 `AccountDetailScreen` — P0（流水）/ P1（走势、对账、文档）
```
┌ ← 招行信用卡                         ⋯ ┐
│ Liabilities:CMB:Credit                  │  muted 全路径（可复制）
│ −¥2,703.29                              │
│ ╱‾‾╲_╱‾  余额走势（1M/3M/…）              │  P1
│ [记一笔] [对账] [文档]                     │  ActionChips
│ 子账户（如有）…                            │
│ ── 流水 ─────────────────── 余额 ─────── │
│ 10/02 海底捞            −128.50 −2,703.29│  每行带变动后的 running balance
│ 10/01 ✓ 余额断言        −2,574.79 ✓      │
└──────────────────────────────────────────┘
```
- 数据：`GET /api/accounts/:name`（`AccountInfoEntity`）、`GET /api/accounts/:name/journals`（每行带 `account_after`，可以作为 running balance）、`GET /api/accounts/:name/balances`（历史余额 → 走势）、`GET /api/accounts/:name/documents`。
- 交互："记一笔"打开 S03，并把这个账户预设为资金账户；如果是 Expenses 账户，就预设为类目。"对账"打开 S14。

#### S14 `ReconcileSheet`（对账）+ `BatchReconcileScreen` — P1
- 单个账户的对账：显示"账本余额 2,754.06 CNY"；用键盘输入"实际余额"；实时显示差额。
  - 差额为 0 → 主按钮"记录断言"（`POST /api/accounts/:name/balances {type: "Check", amount}`）。
  - 差额不为 0 → 两个选项：
    - "仅断言（会产生账本错误，提醒你去查漏记）"；
    - "**自动补平**"（`{type: "Pad", amount, pad: <账户>}`）。补平来源账户默认是 `Equity:Opening-Balances`（如果存在），否则让用户选。这对应 MOZE 的"餘額調整"和钱迹的"手动调整余额"（P-23）。
- 批量对账（借鉴 MOZE 的对账模式，月底逐个核对）：列出所有 Assets / Liabilities 叶子账户，每行有输入框；只提交填了的行（`POST /api/accounts/batch-balances`）；提交后显示每一行是否通过。
- 对账之后，Journal 里会出现断言行；如果断言失败，`/api/errors` 会有记录，Home 的 ⚠ 角标会增加。

#### S15 `DocumentsScreen` / 收据拍照 — P1
- 在记一笔里点 📎：选拍照或相册 → 预览（可以裁剪，P2）→ 保存交易成功后上传。**问题**：`POST /api/transactions` 的返回是 `Created`，**不带新交易的 id**，没法直接上传附件（见第 5 节）。临时方案：保存后拉第 1 页 journals，用 `zhang-app-id` meta 匹配出 id 再上传。
- 文档页：按月分组的缩略图网格（`GET /api/documents`），可以按账户或交易过滤；点开全屏查看（支持缩放）；PDF 等非图片显示文件图标，用系统打开。

#### S16 `CommoditiesScreen` — P2
- 列表：`GET /api/commodities` → 名称、`total_amount`、最新价格和日期（`latest_price_*`），超过 7 天没更新的价格标 ⚠。
- 详情：`GET /api/commodities/:name` → `lots[]`（账户、数量、成本、取得日期）、`prices[]`（价格折线图）。

#### S17 `LedgerErrorsScreen` — P1
- `GET /api/errors` → `ErrorEntity { error_type, span{filename, start, end, content}, metas }`；按 `error_type` 分组；每条显示等宽字体的代码片段（`span.content`）、文件名和位置；点"查看文件"进入 S19（P2）。
- Home app bar 的 ⚠ 角标显示错误数；数量为 0 时不显示角标。

#### S18 `SettingsScreen` & `ServerProfilesScreen` — P0（基础）/ P1（其余）
- **服务器**：profile 列表（颜色点、名称、URL、最后连接时间、"当前"标记）→ 编辑（复用 S01 的表单）/ 重新测试 / 删除（二次确认，并清掉这个 profile 的缓存）/ 新增。`ProfileSwitcherSheet` 显示同样的列表，点一下就切换：清空内存状态、加载这个 profile 的缓存、在后台刷新。**切换后 app bar 的颜色点和标题马上变化**，防止记错账本。
- **显示**：主题（跟随系统 / 浅 / 深 / 纯黑 AMOLED）、动态取色（Android 12+）、**收支颜色约定**（3.1）、隐藏金额默认值、数字缩写（万 / k）、负债显示为正数、日期格式。
- **记账**：默认资金账户（每种模式各一个）、默认币种、键盘布局（计算器 789 在上 / 电话 123 在上，P-14）、是否启用中间按钮手势、类目宫格设置（显示哪一层、排序、隐藏某些类目、给类目指定图标；这些都只存本地，不写回账本）、"保存后留在页面"（默认关）。
- **安全**（P1）：生物识别锁（`local_auth`，[pub.dev](https://pub.dev/packages/local_auth)），以及进入后台多久后锁定。
- **数据**：清除缓存、`POST /api/reload`（让服务端重新加载账本）、导出诊断日志（会脱敏凭据）。
- **关于**：App 版本、服务器版本（`/api/info`）、开源许可。

#### S19 高级工具 — P2
- `FileEditorScreen`：`GET /api/files` → 文件列表；`GET/PUT /api/files/:path` 编辑。要有等宽字体、行号、快速插入键（日期、`*`、引号、账户补全，借鉴 Beancount Mobile 的 source editor），保存前显示 diff 确认。
- `SqlConsoleScreen`：`POST /api/sql`；结果显示成横向可滚动的表格；可以保存常用查询。只在设置里打开"开发者选项"后才显示。
- `QuickTextEntry`（P-31）：一行文本，比如 `@星巴克 咖啡 32 微信 > 饮料`，实时预览解析出的 postings；账户别名在设置里维护。

---

### 2.5 `AmountKeypad` 行为规格

| 项 | 规格 | 依据 |
|----|------|------|
| 布局 | 4×4。默认"电话式"（123 在上）；设置里可以换成"计算器式"（789 在上） | MOZE 的键盘顺序设置（P-14） |
| 键 | `0-9` `.` `⌫` `+` `−` `×`（P1）`÷`（P1）`再记` `保存/=` | 钱迹（再记、清零）、鲨鱼（+ −）、Cashew（÷ ×） |
| `×` `÷` 的位置 | 长按 `+` 出 `×`，长按 `−` 出 `÷`，不占额外的键位 | 保持 4×4，同时保留乘除能力 |
| 清零 | 长按 `⌫` = 清零（伴随触感反馈） | 钱迹有独立的 `清零` 键，我们合并成长按 |
| 算式 | 输入里有运算符时，上方 `ExpressionLine` 显示算式，`AmountDisplay` 实时显示结果；`保存` 键变成 `=`，按一次求值，再按一次才保存 | Cashew 的 `calculationString`（P-13） |
| 运算 | 用 `decimal` 包（[pub.dev](https://pub.dev/packages/decimal)）做精确计算，按常规优先级求值；**不用 double** | 金额精度 |
| 小数位 | 上限 = 币种 precision（`GET /api/commodities` 的 `precision`），默认 2；超出的输入被忽略，并轻微抖动 | 钱迹"最多两位小数" |
| 前导 | 第一个键是 `.` 时自动变成 `0.`；`0` 后面再输数字时替换掉这个 0 | — |
| 上限 | 整数部分最多 12 位 | 防误触 |
| 符号 | 支出 / 收入 / 转账模式下只能输正数，结果 ≤ 0 时禁止保存；高级模式在行上有 ± 切换 | MOZE"不分正负号"（P-06）；Actual 的 toggle sign |
| 币种 | `AmountDisplay` 左边的 `CommodityButton` 打开币种列表（常用的置顶） | MOZE、钱迹的币种按钮 |
| 反馈 | 每次按键都有 `HapticFeedback.selectionClick`；键的高度 ≥ 56dp；键盘区约占屏高的 38–42% | — |
| 实体键盘 | 支持数字、运算符、Backspace、Enter（= 或保存） | Cashew 支持实体键盘 |
| 可达性 | 每个键都有 Semantics 标签（"加""退格""再记一笔"）；`AmountDisplay` 作为 live region 朗读结果 | Beancount Mobile 的可达性要求 |

### 2.6 智能建议：最近 / 收藏账户、payee、模板

**本地数据（按 profile 隔离）**：
`suggestionCache = { txns: 最近 ≤1000 笔的精简信息(date, payee, narration, tags, postings.account, amounts), builtAt }`。来源是首次进入后后台分页拉取 `/api/journals`；以后每次新增或刷新时增量更新。

| 建议 | 算法 | 出处 |
|------|------|------|
| 账户 frecency | `score(a) = Σ_{posting∈a} exp(−Δdays/30)` | Fava `ExponentialDecayRanker`（P-10） |
| 类目 → 资金账户 | 取这个类目最近一笔交易里的 Assets / Liabilities 账户 | MOZE（P-07） |
| payee → 整笔 | 这个 payee 最近一笔交易的类目、资金账户、narration；金额只作为 hint | Fava `payee_transaction`（P-09） |
| payee → 账户排序 | 在账户选择器里，把这个 payee 用过的账户排在最前 | Fava `payee_accounts` |
| 时段类目（P1） | 把 24 小时分成 6 个桶；`score = frecency × (同桶次数+1)/(总次数+6)`，取前 4 | MOZE 建议类别（P-08） |
| 默认值更新（P1） | payee 的默认类目要最近 3 笔里有 2 笔一致才切换 | YNAB |
| 收藏 | 用户手动加星，存在本地；在账户选择器里置顶 | Beancount Mobile 的 Starred（概念） |
| 模板（P1） | 保存一部分字段（模式、类目、资金账户、payee、narration、标签，金额可选）；入口在 Home 的模板行、S03 右上角的 ☆、长按中间按钮 | MOZE 範本、随手记模板、Money Manager 书签（P-26） |

模板只存在本地（P1）。是否要同步到账本（比如写成 `custom "zhang-app-template"` 指令），列为开放问题。

### 2.7 账户层级的呈现规则

- **显示名**：`alias`（来自 `open` 的 meta）> 最后一段；全路径作为副标题（muted、`bodySmall`）。在详情和高级模式里，全路径用等宽字体（Beancount Mobile 就是这样）。
- **颜色 / 图标按顶级类型**：Assets 用 `account_balance`，Liabilities 用 `credit_card`，Income 用 `trending_up`，Expenses 用类目图标，Equity 用 `balance`。顶级类型的颜色只用在图标容器（`*Container` 角色）上，不给文字上色。
- **默认深度**：资金账户选择器展开到叶子；Accounts 页默认展开到第 2 层；Reports 的排行默认聚合到第 2 层。
- **超长路径**：中间段用省略号（`Assets:…:Checking`），点一下展开；搜索结果里高亮命中的那一段。
- **余额的符号**：按 Beancount 原生符号显示（负债为负、收入为负），**但是**：Reports 里收入取反显示为正；Accounts 页可以选"负债显示为正数（欠款）"（P1；钱迹默认把信用卡欠款显示为负数，P-24，所以默认保持负数）。
- **已关闭账户**：默认隐藏；在"显示已关闭"的状态下，置灰并加"已关闭"标签，不能在记账时选择（钱迹隐藏资产也是"不能再选择"）。

### 2.8 图表选型

图表库：`fl_chart`（[pub.dev](https://pub.dev/packages/fl_chart)）。

| 场景 | 图表 | 说明 |
|------|------|------|
| Home 每日支出 | Sparkline（折线，无坐标轴） | 只表达趋势 |
| 收支趋势 | 分组柱（收入 / 支出）+ 净额折线 | Beancount Mobile Reports（P-22）；月视图按日（≤31 根柱），年视图按月 |
| 分类占比 | Donut（≤6 段 + 其他）+ **排行条形列表** | 主读数靠列表，donut 只做概览；不做旋转交互 |
| 净资产 | 面积折线 + 区间 chips | Beancount Mobile Home |
| 账户余额走势 | 阶梯折线（step line） | 余额只在交易时变化，用阶梯更诚实 |
| 预算 | 横向进度条 + 超出部分 | 不用环形图，便于多行对比 |
| 价格 | 折线 | Commodity 详情 |
| 日历热力图（P2） | 月历格子，用颜色深浅表示支出 | Cashew 的 heatMap、Money Manager 的 Calendar |

**统一规则**：坐标轴的金额用缩写（1.2万 / 12k）；tooltip 用完整金额；分类颜色在所有图表里保持一致（按账户名稳定哈希到一套 8 色的分类色板，在深浅两种主题下都要校验对比度）；空期间不画空坐标系，而是显示"本期间没有数据"。

### 2.9 预算呈现（总结）

- zhang 的预算是 YNAB 式的零基预算（assigned / activity / available）。**主读数是 available**：用它的正负和比例上色，进度条显示 activity / assigned。
- 分组用 budget 的 `category` meta；排序是：超支在前 → 余量少的 → 其余按名称。
- Home 只显示汇总条，加上"最需要关注的 2–3 个"预算。
- 月份切换和报表共用同一个 `PeriodSelector`（预算只支持"月"）。
- MVP 只读（没有写 API），详见 S11。

### 2.10 空 / 加载 / 错误 / 离线状态

| 状态 | 规则 | 组件 |
|------|------|------|
| 首次加载 | 骨架屏（卡片和列表各自独立） | `SkeletonCard`、`SkeletonTile` |
| 刷新 | **先显示缓存**（stale-while-revalidate），顶部显示 2dp 的 `LinearProgressIndicator`；不用整页 spinner | — |
| 空 | 插画 + 一句解释 + 一个主操作（"记第一笔"、"去写 open 指令（文档）"、"清除过滤"） | `EmptyState` |
| 卡片级错误 | 卡片内显示"加载失败 · 重试"，并带错误码 | `InlineError` |
| 鉴权失效（401） | 全局 `MaterialBanner`："服务器拒绝了凭据 · 去更新"，点击进入 S18 编辑当前 profile；暂停后台请求 | `AuthBanner` |
| 网络离线 | 顶部 banner："离线 · 显示 10:32 的缓存"；只读页面照常浏览缓存；需要服务端计算的期间切换显示"离线不可用" | `OfflineBanner`（用 `connectivity_plus` 检测网络状态，再加一次实际请求来确认） |
| 记账离线（P1） | 进 **Outbox**：交易带上 `metas: zhang-app-id=<uuid>` 存在本地，界面显示"待同步 (2)"chip；联网后按顺序重试（指数退避）；重试前先用这个 id 查是否已经存在，防止重复提交（**依赖服务端支持按 meta 查询或幂等键，见第 5 节**） | `OutboxChip`、`OutboxScreen` |
| 账本数据错误 | 和网络错误分开：Home 上显示 ⚠ 角标，点进 S17；不平衡的交易在列表里描边 | `ErrorsBadge` |
| 服务端重载 | （P2）订阅 `GET /api/sse`；收到账本变更事件时让缓存失效并静默刷新，同时显示一个小 toast："账本已更新" | — |

缓存：每个 profile 一个本地数据库（drift / sqlite），缓存 accounts、最近的 journals 分页、各期间的 summary。键 = `profileId + 请求 + 参数`。

### 2.11 服务器 profile 与鉴权（数据模型和安全）

```
ServerProfile {
  id: uuid
  name: String              // "家庭账本"
  baseUrl: Uri              // https://zhang.example.com
  colorTag: int             // 5–8 种预设色之一
  auth: None | Basic{username, passwordRef} | Bearer{tokenRef}
  extraHeaders: [{key, valueRef | value, secret: bool}]
  allowInsecureHttp: bool   // 默认 false；勾选后显示红色警示
  timeout: Duration         // 默认 15s
  lastConnectedAt, serverVersion, ledgerTitle   // 来自 /api/info
  // P2: pinnedCertSha256
}
```
- `*Ref` 指向 `flutter_secure_storage` 里的键；**明文凭据不进普通数据库，也不进日志**。诊断日志里把 `Authorization` 和标记为 secret 的 header 替换成 `***`。
- 请求层用一个 `ZhangClient`（dio 拦截器）统一注入 `Authorization: Basic base64(user:pass)` 或 `Bearer <token>`，再加上 extraHeaders；把 401、403、超时、TLS 错误统一映射成 2.10 里的状态。
- 切换 profile 时：取消所有进行中的请求，换掉 client 和缓存；Outbox 按 profile 隔离，**草稿永远只提交到创建它时所在的 profile**。
- 只有一个 profile 时，app bar 的标题仍然可以点（进入"管理服务器"），保证入口一致。

---

## 3. Material 3 视觉方向

### 3.1 色彩角色

- **Seed**：建议用一个偏青绿的品牌色（比如 `#1F7A68`，"账本绿"，最终由 lead 决定）。用 `ColorScheme.fromSeed` 生成 light 和 dark 两套。Android 12+ 可以选"动态取色"（`dynamic_color` 包，[pub.dev](https://pub.dev/packages/dynamic_color)），**默认关闭**：金融数据的语义色需要稳定，壁纸取色可能让收支色难以分辨。
- **语义色**放在 `ThemeExtension<FinanceColors>`（[Flutter ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html)）里，每一种都有 `color / onColor / container / onContainer` 四个角色，并且对 seed 做 harmonize（M3 的"自定义颜色要和 source color 协调"，见 [M3 Define new colors](https://m3.material.io/styles/color/advanced/define-new-colors)；系统角色见 [M3 Color roles](https://m3.material.io/styles/color/roles)）：

| Token | 用途 | 默认（Western 约定） | CN 约定（红涨绿跌） |
|-------|------|----------------------|----------------------|
| `income` | 收入金额、正向变化 | 绿 `#2E7D32` 系 | 红 `#D84315` 系（偏橙红，要和 `error` 区分开） |
| `expense` | 支出金额 | 红 `#C62828` 系 | 绿 `#2E7D32` 系 |
| `transfer` | 转账 | `onSurfaceVariant`（中性） | 同左 |
| `neutralNegative` | 日净额为负、负余额 | `onSurfaceVariant` | 同左（Ivy：负数用灰色，P-17） |
| `budgetOk / Warn / Over` | 预算状态 | primary / tertiary / error | 同左 |
| `reimburse`（P2） | 报销 / 待收款 | 蓝，固定 | 同左（钱迹把报销色固定为蓝色） |

- **收支颜色约定做成设置项**（P-25；钱迹 Android"金额颜色支持切换（设置—实验室）"、iOS"支持切换收入支出颜色"，见各自的更新记录；MOZE 的"支出收入顏色"偏好）。有三个选项：
  1. **红涨绿跌**（收入红 / 支出绿，中国大陆、台湾、日本股市的惯例，参见[中国日报对"红涨绿跌"由来的解释](http://caijing.chinadaily.com.cn/2015-07/27/content_21415547.htm)）；
  2. **绿涨红跌**（收入绿 / 支出红，西方惯例）；
  3. **单色**：支出用 `onSurface`，只有收入用 `primary`。这样最克制，满屏不会全是红绿。
- **默认值**：系统语言是 zh / ja 时默认选 1，其他语言默认选 2（**需要 lead 确认，见第 5 节**）。
- **颜色永远不是唯一信号**：金额始终带 `+` 或 `−`；预算超支带 ⚠ 图标；对色弱用户友好。
- 选 CN 约定时，`income` 是红色，可能和 M3 的 `error` 混淆，所以：`income` 用偏橙的红（hue 约 15–20°），`error` 保持 M3 默认（hue 约 25°，饱和度更低）。另外，错误状态一定带图标和文字。

### 3.2 字体与排版

- 字体：系统默认（Android 是 Roboto + Noto Sans CJK，iOS 是 SF Pro + PingFang），不内嵌中文字体，控制包体积。
- **金额一律用等宽数字**：`TextStyle(fontFeatures: [FontFeature.tabularFigures()])`（[Flutter API](https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html)），保证上下行的小数点对齐。
- 字号（M3 type scale，[tokens](https://m3.material.io/styles/typography/type-scale-tokens)）：

| 用途 | 角色 |
|------|------|
| Home 主金额、交易详情 hero 金额 | `displaySmall`（36sp）|
| 记一笔的 AmountDisplay | `headlineLarge`（32sp），超过 10 位自动缩到 `headlineMedium` |
| 卡片次要金额、月头 | `titleMedium` |
| 列表标题（payee） | `bodyLarge` |
| 列表金额 | `titleSmall` 加 tabular figures，右对齐 |
| 副标题、全路径 | `bodySmall`，颜色用 `onSurfaceVariant` |
| 账户全路径（详情、高级模式） | 等宽 `bodySmall`（`RobotoMono` / `Menlo` 回退） |

- 币种符号和代码比数字小一档，并且颜色更淡，比如 "¥" 用 `titleSmall`，数字用 `headlineLarge`。

### 3.3 数字格式

| 规则 | 规格 |
|------|------|
| 千分位 | 按 locale（`intl` 的 `NumberFormat.decimalPatternDigits`）；zh / en 都是 `1,234,567.89` |
| 小数位 | = 币种 precision（`/api/commodities` 的 `precision`），没有就默认 2；不截断服务端给的更多位数，只在显示时四舍五入（rounding 用币种的 `rounding` 字段） |
| 负号 | U+2212 `−`（视觉上和 `+` 等宽），不用括号；交易列表里支出显示 `−128.50`，收入显示 `+12,000.00`，转账不带符号 |
| 币种显示 | 有 `prefix` / `suffix`（commodity 实体字段）就用（`¥128.50`）；没有就显示代码 `128.50 USD`；operating currency 用符号，其他币种用代码，避免 `$` 歧义 |
| 多币种合计 | 主显示 `≈ ¥12,345.67`（`CalculatedAmount.calculated`），点一下展开 `detail` 里各币种的原值；有无法换算的显示 "1 项未计入 ⓘ" |
| 缩写 | 图表坐标轴、紧凑卡片里，zh 用 `1.2万`、`3.4亿`，en 用 `12.3K`、`1.2M`（`NumberFormat.compact`）；可以在设置里关掉（MOZE 的"總額顯示縮寫"） |
| 隐藏金额 | 把数字替换成 `••••`，但保留符号和币种，比如 `−¥••••`；图表的 Y 轴隐藏刻度（P-30） |
| 日期 | 列表日头写 "10月2日 周五"；跨年时加上年份；详情页写 `2026-10-02 19:32`（ISO，跟账本文本一致） |
| 零 | 显示 `0.00`，不显示 `−0.00` |

### 3.4 深色模式

- 用 `ColorScheme.fromSeed(brightness: dark)`。语义色在 dark 主题下取 tone 80（文字）/ tone 30（container），保证和 `surface` 的对比度 ≥ 4.5:1。
- 提供 **纯黑（AMOLED）** 选项：`surface` = `#000000`，卡片用 `surfaceContainerLow`（Ivy 有 AMOLED 主题，`Theme.AMOLED_DARK`）。
- 图表的分类色板在浅色和深色下各有一套，并且都要校验对比度。donut 的分隔线用 `surface` 色描边。
- 截图和附件预览在深色模式下不反色。

### 3.5 动效与触感

- 记一笔：sheet 弹出用 M3 的 emphasized easing（约 300ms）；选中宫格 tile 时用 `scale 0.95 → 1` 加 selectionClick 触感；保存成功时用 `HapticFeedback.mediumImpact`，Journal 里新的一行做一次高亮闪烁（约 1s）。
- 数字变化（Home 汇总、余额）用 200ms 的数字滚动动画；"减少动态效果"开启时直接显示。
- `MonthSwitcher` 切换时，内容做横向 shared-axis 过渡。

---

## 4. MVP 屏幕优先级

### P0（第一个可用版本：连上服务器 → 看账 → 记账）

| # | 屏 / 能力 | 关键点 |
|---|-----------|--------|
| 1 | S01 `ServerSetupFlow`（URL + 无 / Basic / Bearer / 自定义 Header + Test Connection） | 凭据进 secure storage；分步诊断 |
| 2 | S18 基础：`ServerProfilesScreen` + `ProfileSwitcherSheet`；主题和收支颜色约定 | 多 profile，颜色标记 |
| 3 | S02 `HomeScreen`（SummaryCard、最近交易、⚠ 角标） | summary + journals |
| 4 | S03 `AddTransactionSheet`：支出 / 收入 / 转账 + `AmountKeypad`（+ −、再记）+ 类目宫格 + 子类目 chips | 显式双 posting；类目→账户记忆 |
| 5 | S04 `AccountPickerSheet`（最近 / 树 / 搜索） | 按模式过滤 |
| 6 | S05 payee / narration 补全（frecency）+ payee 自动填表 | `/api/for-new-transaction` + 本地缓存 |
| 7 | S07 `JournalScreen`（分页、月头、日头、类型 chips、keyword / tag 过滤） | `classify()` |
| 8 | S08 `TransactionDetailScreen`（只读：postings、Entry Context、标签） | 复用列表数据 |
| 9 | S12 `AccountsScreen`（树、净资产数字、多币种展开） | 客户端建树 |
| 10 | S13 `AccountDetailScreen`（余额 + 流水 + running balance） | account journals |
| 11 | S10 `ReportsScreen` 收支段（期间选择、KPI、趋势柱、分类排行 + 下钻） | statistic summary / graph / rank |
| 12 | 全局状态：骨架屏、空状态、卡片级错误、401 banner、离线只读 banner | 2.10 |

### P1（好用起来）

S06 高级多 posting 编辑器；S08 编辑（`PUT`）、复制、退款；S11 预算列表和详情（只读）；S14 对账（单个和批量，balance check / pad）；S15 收据附件和文档页；S17 账本错误页；S09 搜索和过滤面板；模板；时段建议；payee 默认类目的"多数票"规则；离线 Outbox；净资产和账户余额走势图；隐藏金额；生物识别锁；`× ÷` 键；高于平均提示；负债正数显示选项。

### P2（锦上添花 / 进阶）

S16 商品和价格；S19 文件编辑器、SQL 控制台、一行文本记账；保存的过滤器；日历视图和热力图；首页模块排序（Cashew）；App Shortcuts、桌面小部件、深链（钱迹 URL Scheme / 秒开模式）；SSE 实时刷新；多选批量操作（拖选）；平板双栏和 NavigationRail；自签证书指纹信任；手续费 posting；分摊；拼音搜索；Ivy 式的中间按钮手势（可以提前做，成本低）。

---

## 5. 开放问题 / 需要 lead 决策的取舍

**产品与视觉**
1. **收支颜色的默认值**：zh 系统语言默认"红涨绿跌"（收入红、支出绿），还是默认"单色"（最克制）？本文建议按语言默认选红涨绿跌，并在首次进入时弹一个一次性选择卡片。
2. **导航**：中间凸起的记一笔按钮（CN 习惯、单手可达，本文推荐）vs 标准 M3（4 个 destination + 右下角 FAB，更"原生"）。如果预算使用率高，是否要把预算升级为独立 tab（替换报表，把报表挪进首页）？
3. **类目宫格不默认选中**（本文推荐，避免记错）vs 钱迹式默认选中第一个（少点一次）。
4. **类目图标存在哪里**：只存本地（零侵入）vs 在 `open` 的 meta 里约定 `icon:` 键（可以跨设备同步，但要写账本）。

**zhang API 缺口（会影响 P1）**
5. **没有删除交易的接口**：流水的删除滑动和 SnackBar 的"撤销"都做不了。需要 `DELETE /api/transactions/:id`。
6. **建交易不返回 id**（`Created`）：附件上传、"查看刚记的那笔"都得绕路。建议让 `POST /api/transactions` 返回新交易的 id。
7. **posting 不支持 cost / price**：做不了跨币种交易（`@`、`@@`、`{}`）。
8. **没有幂等键**：离线重试可能重复提交。建议服务端识别 `metas` 里的某个键（比如 `zhang-app-id`）做去重，或者支持 `Idempotency-Key` 请求头。
9. **`/api/journals` 只支持 keyword / tags / links**：没有日期区间、账户、金额、类型的过滤，复杂过滤只能靠客户端或 `/api/sql`（SQL schema 稳定吗？能当作公开接口吗？）。
10. **预算没有写接口**（`budget-add` / `budget-transfer`）：MVP 预算只读。要不要扩展 API？
11. **`/api/for-new-transaction` 不带排序信号**：frecency 只能在客户端算（要拉最近 1000 笔）。如果能返回 `last_used` 时间或次数，就能省掉首屏的预拉取。
12. **鉴权**：zhang 原生只有 HTTP Basic（`--auth user:pass` 或 `ZHANG_AUTH` 环境变量，见 zhang 文档 `installation/3-basic_auth.md`）。Bearer 和自定义 Header 只对前置网关（Cloudflare Access、Nginx）有意义。需要确认这个定位，以及将来是否会有 token 鉴权或 OAuth（Beancount Mobile 走的是 OAuth + PKCE）。
13. **账户元数据**：`AccountEntity` 有 `alias`，但没有币种列表（`open` 指令的约束币种）。"资金账户的默认币种"只能靠猜（取余额里的主币种）。

**工程**
14. 本地缓存选 drift（sqlite）还是 isar / hive？客户端要复刻 `classify()`、frecency、建树这些纯函数，**建议写成纯 Dart 包并配单元测试**，不要重蹈 Cashew"5000 行页面文件"的覆辙。

---

## 附录 A：主要来源

- 钱迹用户指南：[首页](https://docs.qianjiapp.com/) · [添加收支](https://docs.qianjiapp.com/ji-zhang-jie-mian/tian-jia-shou-zhi.html) · [转账](https://docs.qianjiapp.com/ji-zhang-jie-mian/zhuan-zhang-cao-zuo.html) · [手续费&优惠](https://docs.qianjiapp.com/ji-zhang-jie-mian/fee_or_coupon.html) · [资产](https://docs.qianjiapp.com/assets/intro.html) · [资产分组](https://docs.qianjiapp.com/assets/group.html) · [资产负债表](https://docs.qianjiapp.com/assetrecord/balance_sheet.html) · [资产趋势](https://docs.qianjiapp.com/assetrecord/asset_line.html) · [多币种](https://docs.qianjiapp.com/multiple_currency.html) · [预算](https://docs.qianjiapp.com/vip/vip_budget.html) · [自定义起始日](https://docs.qianjiapp.com/home/custom_month_start.html) · [分类管理](https://docs.qianjiapp.com/fen-lei-guan-li.html) · [URL Scheme](https://docs.qianjiapp.com/plugin/url_scheme_others.html) · [Android 更新记录](https://docs.qianjiapp.com/change-log/change_log_android.html) · [iOS 更新记录](https://docs.qianjiapp.com/change-log/change_log_ios.html)；评测：[少数派](https://sspai.com/post/61668) · [withcb](https://withcb.net/post/app-qian-ji/)
- MOZE：[記帳欄位](https://doc.moze.app/record/introduction) · [記帳模式](https://doc.moze.app/record/entry-mode) · [範本](https://doc.moze.app/record/template) · [記帳小技巧](https://doc.moze.app/record/tips) · [拆帳](https://doc.moze.app/record/split-categories) · [統計報表](https://doc.moze.app/analysis/statistics-report) · [搜尋](https://doc.moze.app/feature/search) · [餘額調整](https://doc.moze.app/reconciliation/balance-adjustment) · [偏好設定](https://doc.moze.app/feature/preference) · [App Store](https://apps.apple.com/tw/app/moze/id1460011387) · [LarryNote](https://www.larrynote.com/moze-3-0-review/) · [vocus](https://vocus.cc/article/67d3cdd2fd89780001386b85)
- 随手记：[woshipm 2388019](https://www.woshipm.com/evaluating/2388019.html) · [woshipm 939335](https://www.woshipm.com/evaluating/939335.html)
- 鲨鱼记账：[站酷](https://www.zcool.com.cn/article/ZOTYzMjM2.html) · [简书](https://www.jianshu.com/p/3ce110fb2fd8) · [UICN](https://m.ui.cn/details/525983) · [知乎竞品分析](https://zhuanlan.zhihu.com/p/116488189)
- Cashew：[GitHub](https://github.com/jameskokoska/Cashew) · [Code With Andrea 评审](https://codewithandrea.com/videos/code-review-cashew-app/) · [Google Play](https://play.google.com/store/apps/details?id=com.budget.tracker_app)
- Ivy Wallet：[GitHub](https://github.com/Ivy-Apps/ivy-wallet) · [Google Play](https://play.google.com/store/apps/details?id=com.ivy.wallet)
- Money Manager：[App Store](https://apps.apple.com/us/app/money-manager-expense-budget/id560481810) · [Google Play](https://play.google.com/store/apps/details?id=com.realbyteapps.moneymanagerfree&hl=en_US) · [Help: Home tab](https://help.realbyteapps.com/hc/en-us/articles/360046150874-Home-tab)（被拦截，内容来自搜索摘要）· [moonproduct](https://www.moonproduct.tech/insights/money-manager-app-vs-finley/)
- YNAB：[Add Transactions](https://support.ynab.com/en_us/how-to-add-transactions-in-ynab-HyDwA_byi) · [What's New](https://www.ynab.com/whats-new) · [App Store](https://apps.apple.com/us/app/ynab/id1010865877) · [Rachele DiTullio 的可达性评测](https://racheleditullio.com/blog/2025/09/ynab-adds-a-home-screen-to-its-ios-mobile-app-but-is-it-accessible/)
- Actual Budget：[GitHub](https://github.com/actualbudget/actual) · [Release Notes](https://actualbudget.org/docs/releases/)
- Spendee：[App Store](https://apps.apple.com/us/app/expense-budget-app-spendee/id635861140)
- Beancount 系：[Beancount Mobile README](https://github.com/bex-co/beancount-io/blob/main/mobile/README.md) · [xuhcc/beancount-mobile](https://github.com/xuhcc/beancount-mobile) · [Fava](https://github.com/beancount/fava) · [fava#965](https://github.com/beancount/fava/issues/965) · [fava#972](https://github.com/beancount/fava/issues/972) · [Costflow Syntax](https://www.costflow.io/docs/syntax/)
- 规范与库：[M3 Navigation bar](https://m3.material.io/components/navigation-bar/overview) · [M3 Color roles](https://m3.material.io/styles/color/roles) · [M3 Define new colors](https://m3.material.io/styles/color/advanced/define-new-colors) · [M3 Type scale tokens](https://m3.material.io/styles/typography/type-scale-tokens) · [M3 Segmented buttons](https://m3.material.io/components/segmented-buttons/overview) · [M3 Bottom sheets](https://m3.material.io/components/bottom-sheets/overview) · [ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html) · [tabularFigures](https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html) · [dynamic_color](https://pub.dev/packages/dynamic_color) · [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) · [fl_chart](https://pub.dev/packages/fl_chart) · [decimal](https://pub.dev/packages/decimal) · [local_auth](https://pub.dev/packages/local_auth) · [Cloudflare Access Service Tokens](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/) · [红涨绿跌的由来（中国日报）](http://caijing.chinadaily.com.cn/2015-07/27/content_21415547.htm)
- zhang 本体（本地仓库 `/Users/kilerd/Projects/zhang`）：`zhang-server/src/lib.rs`（路由、Basic Auth）、`zhang-server/src/request.rs`、`zhang-server/src/response.rs`、`docs/src/content/docs/directives/4-budget.md`
