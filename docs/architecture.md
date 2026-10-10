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
  authType: none | basic | bearer | headers,
  basicUsername, basicPassword, // basic
  bearerToken,                  // bearer -> Authorization: Bearer <token>
  customHeaders: Map<String,String>, // headers -> 原样附加（如 CF-Access-Client-Id）
  allowSelfSigned: bool          // 可选，默认 false
}
```
- 支持多个 profile，可切换；敏感字段只进 secure storage。
- 「测试连接」= GET `/api/info`，成功显示 server 版本与 ledger 标题；没有 `format` 字段（zhang < 0.2）提示「服务器版本过旧」；401 时查 `/api/auth/status`，只开 passkey 的服务器单独提示，否则提示鉴权失败。
- 所有请求相对 `baseUrl` 拼接 `/api/...`；报表、错误、表单建议、预算、文档走内置查询 `POST /api/query/builtins`；SSE `/api/sse` 的 `Reload` 驱动刷新，`ReloadFailed` 在首页显示横幅。

## 目录结构
```
lib/
  main.dart
  app.dart                 // MaterialApp.router、主题、locale
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
