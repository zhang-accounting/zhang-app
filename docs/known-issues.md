# 已知问题与下一步（2026-10-10 更新：迁移到 zhang v0.2 之后）

来源：2026-10-02 的 fresh-eyes 审查，加上 v0.2 迁移（只支持 zhang ≥ 0.2，见 docs/compat-v0.2.md、docs/zhang-api.md）。

## 必须先修（日常使用前）
1. **账本请放在 git 下**：v0.2 会拒绝写不回去的名字（400），记一笔前会先调 `POST /api/transactions/preview`，但服务器本身仍会写入不平衡 / 账户不存在或已关闭的交易（其他客户端、PUT 编辑没有 preview）。

## P1
- 鉴权类型互斥：decisions.md §7 要求 Basic 可与自定义 Header 叠加（Cloudflare Access + zhang Basic），现在 `authHeaders()` 只按单一类型发（lib/data/profiles/server_profile.dart）。需要改表单与模型。
- 浏览器登录的 token 是无状态 30 天 HMAC：「退出登录」只在本地删除 token，`POST /api/auth/logout` 不吊销；server 没有按 token 吊销的接口。
- 只有 passkey 且 server 早于 PR #786（无 `app_login`）时仍用不了：连接测试提示开启密码登录；有 `app_login` 的 server 提示改用「浏览器登录」。
- 浏览器登录的 iOS `ASWebAuthenticationSession` / Android Custom Tabs 不认 `allowSelfSigned`：自签名证书的 server 在浏览器里会被拦（App 内的 API 请求仍按 profile 放行）。
- 明文 http 发送凭据没有提示（S01 要求显式 opt-in）。
- 收入模式不能选 Liabilities 作为入账账户。
- 账本时钟：`ledger.now` 与设备时钟的差值每个 profile 只取一次（取整到 15 分钟）。App 运行期间账本时区或设备时区切换夏令时，「今天 / 本月」会差一小时，直到重启或切换 profile。
- 从账户页打开交易：`trx_id` 是真实交易 id，但没有按 id 取交易的接口，App 用 `/api/journals?keyword=<payee>` 最多翻 5 页（每页 100）去找；同名 payee 极多的老交易可能显示「找不到」。可改用 `journals.page` + `journals.postings{ids}`。

## P2
- 切换币种后不重新校验已输入的小数位（可输入 12.34 JPY）。
- 键盘：`3−5=` 之后再输数字会变成 −20。
- 标签过滤仍在客户端做（服务器依旧忽略百分号编码的 `tags%5B0%5D`，Dart 会重新编码 `[]`），罕见标签会把整个账本翻一遍、`total_count` 是未过滤的数。可改用内置查询 `journals.page{tags}`。
- 报表净额线画到了未来日期；账户余额阶梯图的终点用设备时钟（`balance_history_chart.dart`）。
- 两个 `formatAmount` helper 重复；`journal_providers` 直接 import main.dart。
- 记一笔的 preview 只在新建时调用；编辑（PUT）还没有界面，以后应调 `POST /api/transactions/{id}/preview`。
- 账户树的「未计入总额（无价格）」提示是启发式：账户的 `calculated` 恰好等于其本位币余额、且外币没有直接价格时才提示。
- 文档：列表没有缩略图，不能按账户 / 交易筛选；从「全部文档」不能直接打开所属交易（没有按 id 取交易的接口）；PDF 等非图片只能经系统分享面板用其他 App 打开，App 内不预览。
- 预算：首页还没有预算汇总条（design-research §2.9）；预算详情不能切换月份（从列表换月后再进）；月份选择和报表一样不能翻到未来月份。

## 已修（供参考）
- 切换 profile 的隔离（2026-11-20）：每个 active profile 一个账本会话（独立的 `ProviderContainer`，`LedgerSessionHost`，见 architecture.md「账本会话」）。切换 / 编辑 / 删除 active profile 时整个会话换新，任何 provider（含以后新增的）都不会在加载期间显示或保存上一个账本的数据（原「必须先修」第 1 条）；版本门禁下沉到 client（`gatedClient`）：切到 zhang < 0.2 的服务器只会收到 `/api/info`、`/api/auth/status`，其它请求不发出、直接 `ApiServerTooOld`（原 P1「版本门禁挡不住 provider」）。另：widget 测试不再依赖运行日期（假服务器的 `ledger.now` 用设备时钟，`--dart-define=ZHANG_TEST_NOW=…` 可整体换日期跑），SSE 测试改用 fake time。
- 浏览器登录加上 PKCE（RFC 7636，仅 `S256`）与 `state`（2026-11-20，zhang PR #819）：每次登录生成随机 `code_verifier` / `state`，登录 URL 带 `code_challenge` 与 `state`，回调的 `state` 必须一致（server 有 `app_login_pkce` 时缺失也算失败），`app/exchange` 带 `code_verifier`。同一设备上截获 `zhang-app://` 回调的 App 拿不到 verifier，无法兑换。旧 server（无 `app_login_pkce`）仍可登录，但没有这层保护。
- 预算、文档界面（2026-11-20，原「只有 repository，还没有界面」）：报表页顶部「收支 / 预算」分段，预算与收支共用月份；按 `category` 分组的月度列表（已分配 / 已花 / 可用、进度条、超支带 ⚠ 和文字、余量不足 20 % 用警示色、本月剩余天数与日均可用、无预算时说明 `budget` 指令并给出 zhang / beancount 写法示例）；预算详情（关联账户可点开、本月分配与计入的 posting，点 posting 打开交易）。账户详情显示该账户（含子账户）的文档，交易详情显示交易附件（`journals.documents` 按交易 id），「账户 › ⋯ › 文档」列出全部文档；图片经 API 客户端下载（鉴权生效）在 App 内缩放预览，其他文件「打开或分享」走系统分享面板（新依赖 `share_plus`）。
- v0.2 迁移（2026-10-10）：版本门禁（`/api/info.format`）+ 「服务器版本过旧」提示；连接测试遇到 401 时查 `/api/auth/status` 解释 passkey-only；汇总 / 排行 / 余额历史 / 错误 / 表单建议 / 预算 / 文档改用内置查询；余额断言显示 `asserted` 并用 `passed` 标记失败；`balance … with pad` 的检查折叠进 pad 行；账户页显示子账户并可点开交易；请求时间按账本墙钟发送；「今天 / 本月」按 `ledger.now`；写入后由 SSE `Reload` 触发刷新（600 ms 定时器只在 SSE 未连接时兜底）；`ReloadFailed` / `reload_failure` 在首页显示横幅并可重试 `POST /api/reload`；保存前先 preview（字段被拒、不平衡、账户未开立 / 已关闭会阻止保存，其他账本错误 / 提示如未声明的商品只警告，可「仍然保存」）；SSE 换 profile 不再重连旧服务器、静默 45 s 视为断线重连、断线 / 离线启动后连上会刷新并重查版本门禁、一次写入的两个 Reload 只刷新一次（700 ms 防抖）。
- 更早：标签转义（未转义会把账本文件写坏，P0）、切换账本残留数据/筛选、删除 profile 不清偏好、U+2212 负号、商品 rounding、写入按币种精度、类目名换行、FAB 遮挡最后一行、funding 默认账户跨币种、测试 retry policy、重复 accounts provider。

## zhang server 侧（见 decisions.md 末尾与 zhang-api.md §5）
仍缺：DELETE 交易、POST 不返回 id、无幂等键、无预算写接口；`/api/journals` 的 `tags[]` 百分号编码被静默忽略；`--auth` 不带 `:` 会静默关闭鉴权；不平衡 / 未开户的交易仍会写入；源码构建的版本号仍是 `0.1.0`。
v0.2 已修（App 已去掉对应 workaround）：`size=0` 崩溃、最早价格而非最新、无直接价格的商品算 0、`1E-8` 指数写法、未知 `/api` 路径返回 200、账户流水 `trx_id` 是 posting id、含 `/` 的 base64 文档无法下载、未知商品崩溃、预算月份 13 崩溃、for-new-transaction 混入 Balance Check / Pad、交易数含余额项、graph 忽略 interval 且用 UTC 日期、PUT 丢 cost/price/comment、失败的余额检查重置余额、reload 失败无提示、Basic scheme 大小写敏感。
