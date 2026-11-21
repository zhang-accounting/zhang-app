# zhang-app 架构决策（lead 决定，执行者遵守）

目标：用 Flutter 构建 zhang accounting 的 Android/iOS 客户端，连接用户自建的 zhang server，
支持自定义 endpoint 与鉴权。

## 技术栈
- Flutter stable（brew cask 安装，3.47.x），Dart 3，Material 3。
- 状态管理：`flutter_riverpod`（不用 codegen，手写 Provider/Notifier）。
- 路由：`go_router`，底部导航用 `StatefulShellRoute`。
- HTTP：`dio`。统一 `ZhangApiClient`，baseUrl + 鉴权由 interceptor 注入。
- 本地存储：`shared_preferences`（非敏感：profile 列表、当前 profile id、UI 偏好）；
  `flutter_secure_storage`（密码 / token / 自定义 header 值）。
- 模型：手写 `fromJson`/`toJson`（避免 build_runner）；金额用 `Decimal`（package `decimal`）而非 double。
- 图表：`fl_chart`。
- i18n：`flutter_localizations` + ARB（`intl`），提供 zh-CN 与 en。
- 日志：`logger` 或 `dart:developer`，不打印凭据。

## 服务器 Profile 与鉴权模型
```
ServerProfile {
  id, name, baseUrl,            // baseUrl 形如 https://ledger.example.com（无尾部 /api）
  authType: none | basic | bearer | session, // 只决定 Authorization
  basicUsername, basicPassword, // basic
  bearerToken,                  // bearer -> Authorization: Bearer <token>
  sessionToken, sessionExpiresAt, sessionUser, // session（浏览器登录）-> Authorization: Bearer <token>
  customHeaders: Map<String,String>, // 与 authType 叠加，每个请求原样附加（如 CF-Access-Client-Id）
  allowSelfSigned: bool          // 可选，默认 false
}
```
- 支持多个 profile，可切换；敏感字段只进 secure storage。
- 自定义 Header 不能覆盖登录方式的 `Authorization`（decisions.md §7）；存储格式 `v: 2`，旧的 `authType: headers` 在读取时迁移。
- 「测试连接」= GET `/api/info`，成功显示 server 版本与 ledger 标题；没有 `format` 字段（zhang < 0.2）提示「服务器版本过旧」；401 时查 `/api/auth/status`，只开 passkey 的服务器单独提示，否则提示鉴权失败。
- 所有请求相对 `baseUrl` 拼接 `/api/...`；报表、错误、表单建议、预算、文档走内置查询 `POST /api/query/builtins`；SSE `/api/sse` 的 `Reload` 驱动刷新，`ReloadFailed` 在首页显示横幅。

## 账本会话（切换 profile 的隔离）
- `bootstrap()` 把 app 放进 `LedgerSessionHost`（`lib/ledger_session.dart`）：每个 active profile 一个独立的 `ProviderContainer`（账本会话）。切换、编辑、删除 active profile 或添加第一个 profile 时新建一个空会话，旧会话在这一帧结束后 dispose：所有 provider——现有的和以后新增的，不论 Future / Notifier / family / autoDispose——都从零开始，加载期间不可能显示或保存上一个账本的账户、payee、金额；旧会话的 API client 被关闭（进行中的请求取消），SSE 断开且不会重连旧服务器。
- 会话内 `activeProfileProvider` 固定（override 成该会话的 profile），切换只能通过换会话生效，旧会话的 provider 不会转去请求新服务器。
- 版本门禁在 client 层：`zhangApiClientProvider` 经 `gatedClient`（`lib/data/api/server_gate.dart`）包装，`serverGateProvider`（`/api/info`）证明是 zhang ≥ 0.2 之前只放行 `/api/info`、`/api/auth/status`，其它请求等门禁；旧服务器上一律不发出、直接抛 `ApiServerTooOld`；门禁失败（离线、401）时下一个请求会重新探测。`AppShell` 照旧据此显示「服务器版本过旧」。
- 门禁是 fail-closed（有意如此）：`/api/info` 一直失败（返回的不是 zhang 的 JSON、反向代理挡了这个路径、5xx、401…）时，除探测外的请求一个都不发，整个 App 读不到也写不了账本。表现：标签页照常显示，每个数据区显示探测的那个错误（`ErrorView`，如「Unexpected response. Is this the address of a zhang server?」、`Server error 502: …`、「Authentication failed (401)…」）并带重试，重试会重新探测；SSE 连不上；设置页（改地址、切换 profile、连接测试）照常可用。
- 跨会话保留：widget 树（GlobalKey 整体挂到新会话的 scope 下：路由栈、Settings 页面、snackbar 都在，不闪屏）、`GoRouter`、profile 列表（所有会话共用一个 `profilesStoreProvider`，会话结束后才完成的 profile 修改也不会丢）、`bootstrap()` 传入的 overrides（SharedPreferences、secret store…）。

**新 provider 的规则**（照现有写法即可，不需要为切换做任何事）：
- 数据 provider 照旧 `ref.watch(ledgerRevisionProvider)` + `ref.watch(<x>RepositoryProvider)`（或 `zhangApiClientProvider`）。它们都属于当前会话，切换后自然是新的，门禁也自动生效。
- 服务器数据只放在 provider 里：不要放 static / 全局变量 / 单例缓存；State 里不要长期保存 `ref.read` 拿到的 repository、client、notifier（只在一次操作内用）；在 build 里 `ref.watch` / `ref.listen`，不要用 `listenManual`（换会话时不会迁移）。
- 要跨 profile 保留的 app 级状态放 SharedPreferences（按 profile id 分 key，如 `RecordPrefs`），或作为 override 交给 `LedgerSessionHost`；provider 里的内存状态在切换时重置。
- 不要自己 new `ZhangApiClient` 去读账本（连接测试、浏览器登录这类探测除外）；确实需要时用 `gatedClient(ref, client)` 包装。
- 测试：`pumpAppHost`（`test/helpers/app_host.dart`）按 `bootstrap()` 的结构启动 app，`app.container` 是当前会话的 container，切换后会变。

## 目录结构
```
lib/
  main.dart
  app.dart                 // MaterialApp.router、主题、locale
  ledger_session.dart      // LedgerSessionHost：每个 active profile 一个 ProviderContainer
  core/   theme/ utils/ (money format, date)
  data/   api/ (client, endpoints, dto) models/ repositories/
  features/
    onboarding/  settings/  home/  journals/  transaction_new/
    accounts/    stats/     budgets/  commodities/  errors/
  l10n/
test/
```

## 质量门槛
- `flutter analyze` 零错误；`flutter test` 通过（至少覆盖 DTO 解析、金额格式化、auth header 注入）。
- `flutter build ios --simulator --no-codesign` 与 `flutter build apk --debug` 可编译。
- 提交信息遵循 Conventional Commits；不添加 AI 署名。
