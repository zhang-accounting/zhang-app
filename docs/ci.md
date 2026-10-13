# CI（GitHub Actions）

工作流：`.github/workflows/build.yml`

## 触发
- push 到 `main` 或 `feat/**`、所有 pull request、手动 `workflow_dispatch`：跑 `check`（analyze + test）→ `android` + `ios` 两个打包 job。
- push `v*` tag（如 `v0.1.0`）：iOS 包上传 TestFlight，并额外跑 `release`，把 Android apk / aab 挂到 GitHub Release 上。
- 手动 `workflow_dispatch`：同样会上传 TestFlight（不发 Release）。

## 产物
| job | 产物 | 说明 |
|---|---|---|
| android | `zhang-app-android.apk` + `zhang-app-android.aab`（artifact `zhang-app-android`） | `flutter build apk/appbundle --release`，用上传密钥签名（build number 用 `github.run_number`）；apk 可直接侧载，aab 用于 Google Play。fork PR 读不到 secrets 时退回 debug 签名 |
| ios | `zhang-app-ios.ipa`（artifact `zhang-app-ios-signed`） | App Store 签名的 ipa，只能通过 TestFlight / App Store 安装；PR 上只做 `--no-codesign` 编译检查，不产出 ipa |

在 Actions 页面对应 run 的 Artifacts 里下载；tag 构建的产物在 Releases 页面。

## Android 签名（`android` job）

- 包名 `com.zhangaccounting.app`，与 iOS bundle id 一致（`android/app/build.gradle.kts` 的 `namespace` / `applicationId`）。
- CI 从 secrets 解码上传密钥到 `$RUNNER_TEMP/upload-keystore.jks`，写出 `android/key.properties`，Gradle 发现该文件就用它签 release；没有（本地默认、fork PR）则退回 debug keystore。`key.properties`、`*.jks` 已在 `android/.gitignore` 里。
- 构建后用 `apksigner verify --print-certs` 打印签名者，可在日志里核对指纹。

| Secret | 内容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名（`upload`） |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |

密钥来源：2026-10-13 在作者 Mac 上用 `keytool -genkeypair -keyalg RSA -keysize 4096 -validity 10000` 生成，原件和密码在 `~/.zhang-app/upload-keystore.{jks,env}`（权限 600）。**这是 Play 的上传密钥，丢了就无法再更新已发布的 App，请另外备份到密码管理器。** 上传密钥证书 SHA-256 指纹：`2D:A5:07:B3:B3:5F:BE:86:07:C3:1E:52:F7:E5:CF:2F:D7:A8:50:43:8E:B4:E8:15:16:12:88:BF:55:B2:F6:90`（配置 `assetlinks.json` 时要用）。

本地出签名包：
```sh
cat > android/key.properties <<EOT
storeFile=$HOME/.zhang-app/upload-keystore.jks
storePassword=<ANDROID_KEYSTORE_PASSWORD>
keyAlias=upload
keyPassword=<ANDROID_KEY_PASSWORD>
EOT
flutter build apk --release
```


## iOS 签名 + TestFlight（`ios` job）

- pull request：只跑 `flutter build ios --release --no-codesign`，确认能编译（fork PR 读不到 secrets）。
- 其它触发：导入发布证书和描述文件，在 CI 里临时把 `ios/Flutter/Release.xcconfig` 改成手动签名，再执行 `flutter build ipa`（build number 用 `github.run_number`），签名后的 ipa 作为 `zhang-app-ios-signed` artifact 上传。
- 只有 `v*` tag 和手动 `workflow_dispatch` 会把 ipa 上传到 TestFlight；普通 push 不上传，避免产生大量无用 build。

一次性准备：
1. App Store Connect 里用 Bundle ID `com.zhangaccounting.app` 创建 App。
2. 导出 **Apple Distribution** 证书为 `.p12`（钥匙串 → 导出，设置密码）。
3. 在 Developer 后台创建这个 Bundle ID 的 **App Store** 描述文件并下载。
4. App Store Connect → 用户和访问 → 集成 → 创建 API Key（App Manager 权限），下载 `.p8`。

仓库 Secrets：
| Secret | 内容 |
|---|---|
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `IOS_DIST_CERT_P12_BASE64` | `base64 -i dist.p12 \| pbcopy` |
| `IOS_DIST_CERT_PASSWORD` | p12 密码 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 -i app.mobileprovision \| pbcopy` |
| `APP_STORE_CONNECT_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | `.p8` 文件的完整内容 |

## 本地等价命令
```sh
flutter analyze && flutter test
flutter build apk --release
flutter build ios --release --no-codesign   # 编译检查；签名包请走 CI
```

## 版本号
`pubspec.yaml` 的 `version: x.y.z+build` 决定安装包版本；发版前先改版本再打 tag。
