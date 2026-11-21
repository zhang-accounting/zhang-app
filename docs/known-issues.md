# 已知问题与下一步（2026-10-10 更新：迁移到 zhang v0.2 之后）

来源：2026-10-02 的 fresh-eyes 审查，加上 v0.2 迁移（只支持 zhang ≥ 0.2，见 docs/compat-v0.2.md、docs/zhang-api.md）。

## 必须先修（日常使用前）
1. **账本请放在 git 下**：v0.2 会拒绝写不回去的名字（400），记一笔 / 编辑前会先调 `POST /api/transactions/preview` / `POST /api/transactions/{id}/preview`，但服务器本身仍会写入不平衡 / 账户不存在或已关闭的交易（其他客户端不一定 preview）。

## P1
- 鉴权类型互斥：decisions.md §7 要求 Basic 可与自定义 Header 叠加（Cloudflare Access + zhang Basic），现在 `authHeaders()` 只按单一类型发（lib/data/profiles/server_profile.dart）。需要改表单与模型。
- 浏览器登录的 token 是无状态 30 天 HMAC：「退出登录」只在本地删除 token，`POST /api/auth/logout` 不吊销；server 没有按 token 吊销的接口。
- 只有 passkey 且 server 早于 PR #786（无 `app_login`）时仍用不了：连接测试提示开启密码登录；有 `app_login` 的 server 提示改用「浏览器登录」。
- 浏览器登录的 iOS `ASWebAuthenticationSession` / Android Custom Tabs 不认 `allowSelfSigned`：自签名证书的 server 在浏览器里会被拦（App 内的 API 请求仍按 profile 放行）。
- 明文 http 发送凭据没有提示（S01 要求显式 opt-in）。
- 收入模式不能选 Liabilities 作为入账账户。
- 账本时钟：`ledger.now` 与设备时钟的差值每个 profile 只取一次（取整到 15 分钟）。App 运行期间账本时区或设备时区切换夏令时，「今天 / 本月」会差一小时，直到重启或切换 profile。
- 从账户页打开交易：`trx_id` 是真实交易 id，但没有按 id 取交易的接口，App 用 `/api/journals?keyword=<payee>` 最多翻 5 页（每页 100）去找；同名 payee 极多的老交易可能显示「找不到」。可改用 `journals.page` + `journals.postings{ids}`。
- 编辑交易（S08）在以下情况被拦下并说明原因（仍可「复制为新交易」），需要 server 配合才能放开：
  - 交易文本里有注释行（分录之间、首行行尾、元数据之后；`edit_drops_text`）：任何 PUT 都会删掉它们。需要 server 在改写时保留这些文本。
  - 分录自带标记（`! Assets:Cash …`、`C Expenses:Food …`，zhang 读 `* ! & ? %` 和 `A`–`Z`）：`/api/journals` 的 posting 没有 `flag` 字段，PUT 请求的 posting 也不能带 flag；server 只在该分录账户不变（按账户匹配到原分录）时保留它，改了账户就静默丢掉。App 用编辑前的 `POST /api/transactions/{id}/preview` 文本检测。建议：`written` 增加 `flag`，请求 posting 接受 `flag`（省略 = 沿用）。
  - 插件生成的交易（posting 没有 `written`，PUT 会 400）、服务器不返回 posting `metas` / `edit_drops_text`（较旧的 zhang）、preview 本身报字段错误（无 `text`）。

## P2
- 幂等键只在记一笔页面打开期间有效：一次可能已写入的尝试（超时、断线）之后关掉页面或 App 被系统杀掉，重新记同一笔会用新 key，可能记两笔（见 decisions.md「幂等记账」）。需要把未完成的保存持久化（离线队列）才能解决。
- 切换币种后不重新校验已输入的小数位（可输入 12.34 JPY）。
- 键盘：`3−5=` 之后再输数字会变成 −20。
- 标签过滤仍在客户端做（服务器依旧忽略百分号编码的 `tags%5B0%5D`，Dart 会重新编码 `[]`），罕见标签会把整个账本翻一遍、`total_count` 是未过滤的数。可改用内置查询 `journals.page{tags}`。
- 报表净额线画到了未来日期；账户余额阶梯图的终点用设备时钟（`balance_history_chart.dart`）。
- 两个 `formatAmount` helper 重复；`journal_providers` 直接 import main.dart。
- 编辑后交易按 server 的导出格式重写，以下纯文本形式会变（值不变）：元数据行按 key 排序（`/api/journals` 按 key 排序返回）；只写日期的交易头（`2026-11-01 *`）变成 `2026-11-01 00:00:00 *`（请求的 `datetime` 必须带时间）；`{150 USD}` → `{ 150 USD }`；只有一个字符串的交易头 `* "x"` → `* "" "x"`；`-0.00` → `0`。
- 分录元数据里不带引号的值（`lot: 8`、日期、布尔）：`/api/journals` 只给字符串，server 只在按账户匹配到原分录时保留不带引号的写法，改了这条分录的账户就写成 `lot: "8"`。App 从编辑前的 preview 文本找出这些值，改账户时先弹窗确认（普通表单和高级编辑器都会）。建议：server 在 `metas` 里标出原始写法，或允许请求指明。
- id 是「文件 + 偏移」的哈希：同一文件里前面的交易变长后，旧 id 可能指向另一笔交易。zhang PR #818 给 journal 条目（账户流水行是 `trx_version`）和 POST / PUT 返回 `version`：有 `version` 时 App 只靠给更新预览和 PUT 发 `If-Match`（412 → 「已在服务器上变化」），从账户流水行打开的交易若 `version` 与行上的 `trx_version` 不同就提示已变化。没有 `version` 的服务器上，App 在编辑检查前和 PUT 之前按 id 重新读取并比对，不一致就拒绝；这个查找按 payee 最多翻 5 页（每页 100），同名 payee 很多的老交易可能被误报为「已变化」，且重新读取与 PUT 之间仍有极短的竞争窗口。
- 分录元数据在高级编辑器里只读（原样保留）；交易元数据可编辑。复制为新交易时不带元数据（交易和分录的 metas，例如 `document` 附件、单据号）和链接（links 把相关条目连在一起，复制出来的是一笔新交易）。
- 账户树的「未计入总额（无价格）」提示是启发式：账户的 `calculated` 恰好等于其本位币余额、且外币没有直接价格时才提示。
- 文档：列表没有缩略图，不能按账户 / 交易筛选；从「全部文档」不能直接打开所属交易（没有按 id 取交易的接口）；PDF 等非图片只能经系统分享面板用其他 App 打开，App 内不预览。
- 预算：首页还没有预算汇总条（design-research §2.9）；预算详情不能切换月份（从列表换月后再进）；月份选择和报表一样不能翻到未来月份。

## 已修（供参考）
- 删除交易（2026-11-21，需要 zhang ≥ 0.3，PR #818；原「zhang server 侧」的「DELETE 交易」）：交易详情的溢出菜单 →「删除」→ 确认后发 `DELETE` 并带 `If-Match: <version>`；只有带 `version` 的交易才提供（旧服务器没有入口），过期的 id 不会删掉另一笔交易。412 / 404 提示「已在服务器上变化」并可刷新列表；成功后关闭详情，列表随重载刷新。不做撤销和列表滑动删除（见 decisions.md「删除交易」）。
- 记账后打开新交易（2026-11-21，需要 zhang ≥ 0.3，PR #818；原「zhang server 侧」的「POST 不返回 id」）：保存后的 snackbar 带「查看」（6 秒），打开服务器返回 id 的那笔交易：从首页记账就在首页标签打开，其他情况（包括从账户、报表标签）在流水标签打开；切换 profile 时这条 snackbar 会被收起（id 属于原来的账本）；按 id 查找并比对 version，id 已移动时显示「已变化」而不是另一笔交易。旧服务器（回答 `"Ok"`）、「再记一笔」、编辑时没有「查看」，与以前相同。
- 幂等记账（2026-11-21，需要 zhang ≥ 0.3，PR #831；原「zhang server 侧」的「无幂等键」）：每次新建交易都带 `Idempotency-Key`（随机 UUID），一个 key 对应用户的一次保存：超时 / 断线后重试、预览警告后「仍然保存」、被拒后修改再保存都沿用它，服务器只写一次，重放的回答（`Idempotency-Replayed: true`）当作保存成功；新开记一笔页面或「再记一笔」才换 key。时间为「现在」的记录在重试时沿用第一次可能已写入的尝试的时间。之前的尝试发过不同内容时，提示「这笔交易已由之前的一次保存写入，之后的修改可能没有保存」。旧服务器忽略这个 header（实测），不依赖它。服务器把 key 写成交易的 `idempotency-key` 元数据：App 记的每笔交易在账本文件里多这一行（见 decisions.md「幂等记账」）。
- 切换 profile 的隔离（2026-11-20）：每个 active profile 一个账本会话（独立的 `ProviderContainer`，`LedgerSessionHost`，见 architecture.md「账本会话」）。切换 / 编辑 / 删除 active profile 时整个会话换新，任何 provider（含以后新增的）都不会在加载期间显示或保存上一个账本的数据（原「必须先修」第 1 条）；版本门禁下沉到 client（`gatedClient`）：切到 zhang < 0.2 的服务器只会收到 `/api/info`、`/api/auth/status`，其它请求不发出、直接 `ApiServerTooOld`（原 P1「版本门禁挡不住 provider」）。另：widget 测试不再依赖运行日期（假服务器的 `ledger.now` 用设备时钟，`--dart-define=ZHANG_TEST_NOW=…` 可整体换日期跑），SSE 测试改用 fake time。
- 浏览器登录加上 PKCE（RFC 7636，仅 `S256`）与 `state`（2026-11-20，zhang PR #819）：每次登录生成随机 `code_verifier` / `state`，登录 URL 带 `code_challenge` 与 `state`，回调的 `state` 必须一致（server 有 `app_login_pkce` 时缺失也算失败），`app/exchange` 带 `code_verifier`。同一设备上截获 `zhang-app://` 回调的 App 拿不到 verifier，无法兑换。旧 server（无 `app_login_pkce`）仍可登录，但没有这层保护。
- 预算、文档界面（2026-11-20，原「只有 repository，还没有界面」）：报表页顶部「收支 / 预算」分段，预算显示报表期间所在的月份（不改动报表的周 / 年 / 自定义期间，按月时两边一起翻）；按 `category` 分组的月度列表（已分配 / 已花 / 可用、进度条、超支带 ⚠ 和文字、余量不足 20 % 用警示色、本月剩余天数与日均可用、无预算时说明 `budget` 指令并给出 zhang / beancount 写法示例）；预算详情（关联账户可点开、本月分配与计入的 posting，点 posting 打开交易）。账户详情显示该账户（含子账户）的文档，交易详情显示交易附件（`journals.documents` 按交易 id），「账户 › ⋯ › 文档」列出全部文档；图片经 API 客户端下载（鉴权生效）在 App 内缩放预览，其他文件「打开或分享」走系统分享面板（新依赖 `share_plus`；临时文件写在 `<temp>/zhang-share/`，分享结束即删，启动时和删除服务器时连同 Android 上 share_plus 的 `<temp>/share_plus/` 一起清掉（`clearSharedDocuments()`）；单个文件超过 50 MB 不下载；iOS「存储图像」需要的相册权限说明已加中英文）。
- 编辑 / 复制 / 高级记账（2026-11-20，S06 + S08）：交易详情加「编辑」「复制为新交易」；编辑先调 `POST /api/transactions/{id}/preview` 再 `PUT /api/transactions/{id}`（原 P2「记一笔的 preview 只在新建时调用」），写回原样读取的 tags / links / flag / 交易与分录元数据 / 分录 cost、price、comment（`written`，显式发送）和金额的原始小数位，实测未改动的交易 PUT 后所有值不变（文本按 server 的导出格式重写，见 P2）；有 `version` 时给更新预览和 PUT 带 `If-Match`，没有时在编辑检查和 PUT 前按 id 重新读取并比对；分录与（含大写 key 的）元数据按缩进和 `Type:Name` 区分；留空金额要配平多种商品、无法推断的卖出金额等 preview 错误会阻止保存；两条反向分录、同一币种、无 cost / price、账户类型符合某个模式且已开立的交易用普通表单编辑（模式锁定，表单不显示的字段原样保留），其余用高级编辑器；编辑后详情页等账本重载再按 id 重新读取，读到与保存内容一致的版本才显示（15 s 内没有就说明「尚未显示这次修改」；被编辑的交易 id 不变，同一文件中其后交易的 id 会变），id 过期（404 / 412）时提示返回刷新。新增多分录高级编辑器（从「记一笔」的「高级」分段进入并带入已填内容）：N 条分录、拖动 / 菜单排序、一条留空自动配平、cost / price / 注释、按币种的实时余差。
- v0.2 迁移（2026-10-10）：版本门禁（`/api/info.format`）+ 「服务器版本过旧」提示；连接测试遇到 401 时查 `/api/auth/status` 解释 passkey-only；汇总 / 排行 / 余额历史 / 错误 / 表单建议 / 预算 / 文档改用内置查询；余额断言显示 `asserted` 并用 `passed` 标记失败；`balance … with pad` 的检查折叠进 pad 行；账户页显示子账户并可点开交易；请求时间按账本墙钟发送；「今天 / 本月」按 `ledger.now`；写入后由 SSE `Reload` 触发刷新（600 ms 定时器只在 SSE 未连接时兜底）；`ReloadFailed` / `reload_failure` 在首页显示横幅并可重试 `POST /api/reload`；保存前先 preview（字段被拒、不平衡、账户未开立 / 已关闭会阻止保存，其他账本错误 / 提示如未声明的商品只警告，可「仍然保存」）；SSE 换 profile 不再重连旧服务器、静默 45 s 视为断线重连、断线 / 离线启动后连上会刷新并重查版本门禁、一次写入的两个 Reload 只刷新一次（700 ms 防抖）。
- 更早：标签转义（未转义会把账本文件写坏，P0）、切换账本残留数据/筛选、删除 profile 不清偏好、U+2212 负号、商品 rounding、写入按币种精度、类目名换行、FAB 遮挡最后一行、funding 默认账户跨币种、测试 retry policy、重复 accounts provider。

## zhang server 侧（见 decisions.md 末尾与 zhang-api.md §5）
仍缺：无预算写接口；zhang ≥ 0.3 之前的服务器没有 DELETE 交易、POST 不返回 id、没有幂等键（PR #818 / #831 已补，App 都已使用）；`/api/journals` 的 `tags[]` 百分号编码被静默忽略；`--auth` 不带 `:` 会静默关闭鉴权；不平衡 / 未开户的交易仍会写入；源码构建的版本号仍是 `0.1.0`。
v0.2 已修（App 已去掉对应 workaround）：`size=0` 崩溃、最早价格而非最新、无直接价格的商品算 0、`1E-8` 指数写法、未知 `/api` 路径返回 200、账户流水 `trx_id` 是 posting id、含 `/` 的 base64 文档无法下载、未知商品崩溃、预算月份 13 崩溃、for-new-transaction 混入 Balance Check / Pad、交易数含余额项、graph 忽略 interval 且用 UTC 日期、PUT 丢 cost/price/comment、失败的余额检查重置余额、reload 失败无提示、Basic scheme 大小写敏感。
