# Passkey 登录设计：浏览器登录回跳（App Login Handoff）

状态：设计稿，2026-10-10。服务端部分尚未实现（需要在 zhang 仓库改 `zhang-server/src/auth` 与前端登录页）。

## 为什么不用原生 passkey

- iOS 的平台 passkey API 要求 Relying Party 域名在**编译期**写进 App 的 Associated Domains 权限，并在该域名下托管 `apple-app-site-association`。通用客户端无法预知每个用户的自托管域名。
- Android 的 Credential Manager 只要求域名下托管 `/.well-known/assetlinks.json`（可由 zhang server 代为提供），技术上可行，但只覆盖一端。
- 结论：让**系统浏览器**完成 passkey/密码验证（iOS `ASWebAuthenticationSession`，Android Custom Tabs），浏览器对任意域名都能用 passkey；验证完成后由 server 把一次性 code 回跳给 App，App 再换成会话 token。

## 时序

```
App                                   系统浏览器                         zhang server
 |-- 打开 <base>/login?return_to=zhang-app://auth/callback -->|
 |                                      |-- 密码或 passkey 登录 ----------->|  设 zhang_session cookie
 |                                      |-- POST /api/auth/app/code -------->|  校验 return_to scheme，签发一次性 code
 |                                      |<-- {"data":{"code","redirect"}} ---|
 |<-- 302/location: zhang-app://auth/callback?code=... --|
 |-- POST /api/auth/app/exchange {"code"} ------------------------------------>|  code 单次、60 s 有效
 |<-- {"data":{"token","expires_at","user"}} ----------------------------------|
 |-- 之后所有 /api/* 请求带 Authorization: Bearer <token> ---------------------->|
```

## 服务端需要新增（zhang 仓库）

1. **Bearer 会话 token**：凡接受 `zhang_session` cookie 的地方同样接受 `Authorization: Bearer <session-token>`（同一校验逻辑、同一 claims）。Basic 不变。
2. **`POST /api/auth/app/code`**（需已登录）：body `{"return_to": "<url>"}`。`return_to` 的 scheme 必须在允许列表内，默认 `["zhang-app"]`，可用环境变量 `ZHANG_APP_RETURN_SCHEMES`（逗号分隔）扩展；否则 400。签发一次性 code（32 字节随机、base64url、60 s TTL、单次使用、内存保存并绑定当前会话 token），返回 `{"data":{"code":"…","redirect":"<return_to 追加 code 参数后的 url>"}}`。
3. **`POST /api/auth/app/exchange`**（免登录，code 即凭据）：body `{"code":"…"}` → 消费 code → `{"data":{"token":"<session token>","expires_at":"<RFC3339>","user":"<name>"}}`。未知/过期/已用 → 401 `{"message":"invalid or expired code"}`。复用登录限流（5 次/15 分钟/IP → 429）。
4. **登录页**：支持 `?return_to=`，在密码、passkey 登录以及首次 passkey 注册流程中保留该参数；登录成功后若 `return_to` scheme 在允许列表内，调用 `app/code` 并跳转到返回的 `redirect`；若打开登录页时已登录则直接做 code 步骤；显示「正在返回 App…」。普通 Web 登录不受影响。
5. **`GET /api/auth/status`** 增加 `"app_login": true` 与 `"app_return_schemes": [...]`，供客户端特性探测。
6. 文档：在 authentication 文档加「移动端回跳」一节（时序、端点、环境变量、安全说明：单次 60 s code、scheme 白名单防开放重定向、Bearer token 与 cookie 同为 30 天无状态 HMAC、logout 不吊销）。

## App 端需要新增（zhang-app，待迁移到 v0.2 后做）

- `ServerProfile.authType` 增加 `session`（界面文案「浏览器登录（passkey / 密码）」）；secure storage 保存 `sessionToken` 与 `expiresAt`。
- 引导页：填 URL 后 `GET /api/auth/status`；`enabled && app_login` 时显示「用浏览器登录」按钮；`enabled && !methods.password && !app_login` 时提示「该 server 只允许 passkey 且未开启 App 回跳，请升级 server」。
- 用 `flutter_web_auth_2`（iOS `ASWebAuthenticationSession` / Android Custom Tabs）打开 `<base>/login?return_to=zhang-app://auth/callback`，回调 scheme `zhang-app`（iOS `CFBundleURLTypes`，Android intent-filter）。
- 拿到 `code` 后调用 `app/exchange`，保存 token；拦截器对该 profile 发送 `Authorization: Bearer <token>`。
- 任何 401 或 `expires_at` 临近 → 首页 banner「会话已过期，重新登录」，点击重走浏览器流程；设置页提供「退出登录」（本地清 token 并调用 `/api/auth/logout`）。
- 测试：exchange/拦截器单元测试；集成测试可用 `--dart-define` 注入一个假的 code 流程（server 侧实现后再跑真机）。

## 安全要点

- code 一次性、60 s、绑定签发时的会话；换取后立即失效。
- `return_to` 只允许白名单 scheme，杜绝开放重定向；App 校验回调里只取 `code`。
- token 与 cookie 同源同效力，存 Keychain/Keystore，不写日志。
- 浏览器会话里的 cookie 与 App 隔离，App 只持有 token。
