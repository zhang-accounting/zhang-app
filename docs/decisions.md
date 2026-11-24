# Lead 决策记录（对 docs/design-research.md §5 开放问题的裁定）

日期：2026-10-02

## 产品 / 视觉
1. **收支颜色**：做成设置项，三档：`expenseRed`（支出红 / 收入绿）、`incomeRed`（收入红 / 支出绿）、`mono`（单色，只用 +/− 号）。默认值按系统语言：zh → `incomeRed`，其他 → `expenseRed`。**不弹**首次选择卡片，在 Settings 里可改。
2. **导航**：Home / Journal / [中间凸起「记一笔」按钮] / Reports / Accounts。预算不单独成 tab，放在 Reports 里作为一个分段（P1）。Settings 从 Home app bar 的齿轮进入。
3. **类目宫格不默认选中**；未选类目时保存键禁用并给出提示。
4. **类目图标只存本地**：按账户名关键词（中英）映射到 Material icon，用户可在本地覆盖（P1）。不往 `open` 指令写 meta。
5. **记一笔三种模式**（支出 / 收入 / 转账）生成两条显式金额的 posting；「高级」多 posting 编辑器属于 P1。
6. **保存后不做乐观更新**：POST 成功后刷新 journals 第 1 页与 summary（服务器写入异步，id 不稳定）。zhang ≥ 0.3 的 POST 在重载之后才回答并给出新交易的 id 与 version：仍不做乐观更新、刷新照旧由 SSE `Reload` 驱动，id 只用于保存后 snackbar 的「查看」（2026-11-21）。

## 鉴权
7. zhang 原生只有 HTTP Basic。Bearer 与自定义 Header 是给反向代理 / 网关（如 Cloudflare Access、Caddy forward_auth）用的，可与 Basic 叠加（同时启用多种时全部附加）。
   - 实现（2026-11-21）：「登录方式」只决定 `Authorization`（无 / Basic / 浏览器登录的 Bearer / 反向代理 Bearer 四选一）；自定义 Header 与登录方式无关，每个请求都附加（浏览器登录的 `/api/auth/status` 与 code 兑换也带上，否则过不了网关）。
   - `Authorization` 归登录方式所有：选了登录方式时，编辑表单拒绝名为 `Authorization`（不分大小写）的自定义 Header（「测试连接」「浏览器登录」「保存」都不执行并在该行提示），模型层 `authHeaders()` 也从不让自定义 `Authorization` 覆盖登录方式的值（不分大小写，dio 的 header 也不分大小写）。只有登录方式为「无需登录」时才发送自定义 `Authorization`（给要求其他 scheme 的网关用）。浏览器登录的探测与兑换请求永远不带 `Authorization`。
   - 其他请求头：请求自己的头优先。自定义 Header 只补请求和客户端都没设的头，所以自定义的 `Accept` / `Content-Type` / `If-Match` / `Idempotency-Key` 不会盖掉 SSE 的 `Accept: text/event-stream`、编辑的 `If-Match` 或 JSON 请求体的 `Content-Type`（名称不分大小写）。
   - 不跟随重定向（`followRedirects: false`）：dart:io 跟随重定向时只去掉 `Authorization` / `Cookie`，自定义 Header（如 `CF-Access-Client-Secret`）会被带到任何目标，包括别的主机和明文 http。zhang 的 API 从不重定向，3xx 一律报错（`ApiRedirect`）：转到**别的主机**或已知网关登录路径（`/cdn-cgi/access/`、`/oauth2/`、`/outpost.goauthentik.io/`、`/.pomerium/`）按登录网关处理（Cloudflare Access 对未认证请求就是 302 到它的登录页），配置向导第 1 步给出「前面有登录网关」；同一主机内的重定向（http → https、路径变了）提示把最终地址填为服务器地址。
   - 旧数据迁移：存储格式加版本号 `v: 2`（只有整数 `v >= 2` 算新格式）。旧的 `authType: headers` 读成「无需登录 + 原有 Header」（原来的自定义 `Authorization` 照常发送）；其他旧类型若还存着 Header（旧版本从不发送）就丢弃，保证迁移前后发出的请求头完全一致；下次保存写成 v2。不认识的 `authType`（更新版本写的）按「无需登录」读，且去掉自定义 `Authorization`：什么 `Authorization` 都不发（fail closed）。
   - 配置向导：网关 Header 能通过网关、而 zhang 自己还要求登录时（第 1 步读不到 `/api/auth/status`，带 Header 能读到且已开启登录），第 2 步保留这些 Header，接着走 zhang 的浏览器登录或用户名密码。

## 范围
8. **MVP = design-research §4 的 P0 全部 12 项**，分三条并行线实现：
   - A「记账流」：S03 AddTransactionSheet + AmountKeypad + 类目宫格 / 子类目 chips，S04 AccountPickerSheet，S05 payee / narration 补全（frecency）与 payee 自动填表，类目→资金账户记忆。
   - B「浏览」：S02 HomeScreen，S07 JournalScreen（分页、月头 / 日头、`classify()`、类型 chips、keyword / tag 过滤），S08 TransactionDetailScreen。
   - C「账户与报表」：S12 AccountsScreen（树 + 净资产），S13 AccountDetailScreen（余额 + 流水 + running balance），S10 ReportsScreen（期间选择、KPI、趋势柱、分类排行 + 下钻）。
   - 全局状态（骨架屏、空态、卡片级错误、401 banner）由各线在自己屏幕内使用 foundation 提供的共享 widget。
9. P1 / P2 按 design-research §4 顺序排期，不在本轮实现。

## 上游 zhang API 缺口（需要在 zhang 仓库解决，记录给作者）
- ~~缺 `DELETE /api/transactions/:id`（无法做滑动删除 / 撤销）~~：zhang ≥ 0.3（PR #818）有 `DELETE`（必须带 `If-Match`），App 已在交易详情里使用，见下「删除交易」。
- ~~`POST /api/transactions` 不返回新交易 id（附件上传要绕路）~~：zhang ≥ 0.3（PR #818）返回 id 与 version，App 用于保存后的「查看」；记账时附带附件仍未做。
- ~~posting 不支持 cost / price~~：v0.2 已支持写 cost / price / comment / metas（高级编辑器与编辑交易已使用；分录 flag 仍读不到、写不了，见 known-issues）。
- ~~无幂等键（离线重试可能重复记账）~~：zhang ≥ 0.3（PR #831）有 `Idempotency-Key`，App 已使用，见下「幂等记账」。
- `/api/journals` 仍不支持按日期 / 账户 / 金额过滤；v0.2 可用 BQL（`POST /api/query`、`postings.between` 等内置查询）代替。
- 无预算写接口（budget-add / budget-transfer）。
- 表单建议（`journals.payees`）无使用频次信号；账户不暴露允许的币种。
- 2026-10-10 起 App 只支持 zhang ≥ 0.2（内置查询 API），见 docs/compat-v0.2.md；仍存在的服务器问题见 docs/zhang-api.md §5。这里的 0.2 指 zhang main 上的 v0.2 API，0.2.0 正式版（2026-10-02）还没有内置查询和 `format`。App 1.1.0 与 zhang 0.3.0 一起发布，所以从 2026-11-21 起 App 文案和文档都写「需要 zhang 0.3 或更新版本」，并注明 2026-10-10 之后从 main 构建的服务器也可用。

## 服务器配置向导（2026-10-14）
- 作者反馈「整个 APP 的 onboarding 页面似乎做得不太好」：原先是一张长表单（名称、URL、溢出屏幕的 5 段鉴权选择、自签名开关、颜色、测试、保存）。改为按 design-research S01 的分步向导：欢迎页（仅首次启动；「连接我的服务器」/「试用 Demo」）→ 1 服务器地址（探测 `/api/auth/status` + `/api/info`）→ 2 登录（只显示服务器支持的方式，浏览器登录优先；开放的服务器跳过）→ 3 账本概览、名称、颜色 →「开始使用」。
- 「试用 Demo」连 zhang README 里的公开只读 Demo `https://zhang-demo.onrender.com`（无需登录，v0.2 API；Render 免费实例闲置后首个请求约 30 s，超时自动重试两次）。
- 设置 →「添加服务器」复用向导（无欢迎页）；「编辑服务器」保留紧凑表单，分为「服务器 / 登录 / 外观」三节，登录方式改用 `DropdownMenu`。
- 仍只用 Material 3 原生组件，配色沿用种子色与 `ZhangColors`；成功 / 失败提示改用 M3 的 primaryContainer / errorContainer，不再借用收支色（收支色将来会随红涨绿跌设置互换）。

## 幂等记账（2026-11-21）
- 每次新建交易（`POST /api/transactions`）都带 `Idempotency-Key`（随机 UUID v4），不按服务器版本区分：旧服务器忽略这个 header（实测），不需要门禁。
- 一个 key 对应用户的「一次保存」（`CreateIntent`）：记一笔页面打开时生成（它打开的高级编辑器沿用同一个），失败后的每次重试都用它——超时、断线、5xx、预览警告后的「仍然保存」、被服务器拒绝（4xx）后修改再保存。保存成功后页面关闭；「再记一笔」和新开页面才换 key。离开页面即放弃这次保存。
- 修改后重试也不换 key：之前的尝试可能已写入，换 key 就会记两笔。服务器按 key 重放的是之前写入的那一笔（不管这次的内容），所以 App 记下可能已写入的请求（4xx 以外的结果），重放时若其中有与本次不同的内容，就提示「之前的一次保存已写入，之后的修改可能没有保存」，而不是静默当作保存了新内容。
- 时间为「现在」的记录在重试时沿用第一次可能已写入的尝试的时间，使重放与新写入的是同一笔交易。
- 服务器把 key 写成交易元数据 `idempotency-key`：App 记的每笔交易在账本文件里多一行。显示（2026-11-21 审查后的决定）：交易详情的元数据列表**不显示**它（这是保存的记账信息，不是给人读的）；高级编辑器编辑交易时它**不是可编辑的行**，保存时按原位置原样带回——删掉它会让原来那次保存的迟到重试再写一笔；「复制为文本」和编辑的 PUT 照旧带着它。「复制为新交易」不带元数据，副本不会继承 key。用户在高级编辑器里新建交易时自己写了 `idempotency-key` 元数据则不发 header（服务器会 400）。
- 已知限制：key 只活在记一笔页面里。某次尝试服务器可能已写入（超时、断线）之后，用户关掉页面、或系统杀掉 App，再重新记同一笔就是新 key，若那次尝试其实已写入就会记两笔。离线队列 / 持久化未完成的保存不在本次范围内。
- 服务器的回答只是附加信息：2xx 但没有可读的回答体（代理返回空 body 等）也算保存成功，只是没有 id（没有「查看」）。

## 删除交易（2026-11-21）
- 只在交易详情里删除：右上角溢出菜单（⋮）→「删除」→ 确认对话框（写明日期、payee、备注、金额）→ `DELETE /api/transactions/{id}` 带 `If-Match: <version>`。删除是破坏性且少用的操作，放在溢出菜单里，不再增加第四个顶栏图标。
- 流水列表**不做**滑动删除：`Dismissible` 要求划走的行立刻从列表里消失（乐观删除，违背 §6），而删除可能被 412 / 404 拒绝；同一文件里其后的交易 id 会变，列表无论如何都要整页重取；没有撤销时误划的代价太大。
- 只有带 `version` 的交易（zhang ≥ 0.3）才提供删除：id 是「文件 + 偏移」，删除后下一笔交易可能占用这个 id；只有 `If-Match` 能保证过期的 id 不会删掉另一笔交易（服务器还会在 24 小时内记住刚删除 / 替换的版本，重发的删除不会删掉内容相同的「双胞胎」）。旧服务器上没有删除入口。
- 412 / 404 →「已在服务器上变化」，没有删除任何内容，「刷新」回到列表并重新读取；其他错误（400 插件生成、409 文件已变化）显示服务器的原因。成功后关闭详情，列表随 SSE `Reload` 刷新，与编辑相同。
- 不做撤销。后续可以考虑：用删除前的快照重新 `POST` 一笔（保留元数据，包括 `idempotency-key`，此时不发 header）——但它会写到 `directive_output_path` 指定的文件末尾、按导出格式重写，而不是回到原来的位置；服务器的 tombstone 只用来拒绝过期的写入，对撤销没有帮助。

## 明文 http（2026-11-21，S01 的「允许 HTTP（不安全）」）
- profile 的地址是 `http://`、又带凭据（选了登录方式或有自定义 Header；浏览器登录即使未登录也算，登录后就会带 token）时，必须显式确认「仍然通过 http 发送我的凭据」：编辑表单里「测试连接」「浏览器登录」「保存」在确认前不可用，配置向导第 2 步的各种登录 / 连接在确认前不发任何请求。确认按 profile 保存（`plainHttpAcknowledged`，非敏感，存在 shared_preferences），只对确认时的地址有效：改地址要重新确认，换成 https 或去掉凭据后不再保存。
- **豁免**：只豁免本机回环 `localhost` 和回环 IP 字面量 `127.0.0.0/8`、`::1`——流量不离开设备（如 SSH 隧道）。不豁免 `*.localhost`（Android / iOS 的解析器不一定把它解析到回环）。**不豁免**局域网地址（`192.168.*`、`10.*`、`*.local` 等）：共享 Wi-Fi 上能被读到，正是 http 最常见、最需要用户知情的场景。
- **常驻提示**：账本名旁（各标签页 app bar 的 `ActiveLedgerTitle`）显示一个警示色的「未加密」小图标（点按有说明），设置的服务器列表在地址后注明「未加密（http）」；只要该 profile 通过非回环的 http 发送凭据就一直显示，确认过也显示。
- 升级前已存在、未确认的 http profile 不会被锁住：照常连接、显示同样的提示，下次在编辑表单保存时才要求确认；对这种浏览器登录 profile 点「重新登录」（首页 / 设置）会先弹窗确认，确认后一并保存。
- 配置向导里网关 Header 通过后（Header 已经随确认发出），确认勾选框锁定不能再取消；「再次检查」也带网关 Header，同样要先确认。
