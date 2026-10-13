# CI（GitHub Actions）

工作流：`.github/workflows/build.yml`

## 触发
- push 到 `main` 或 `feat/**`、所有 pull request、手动 `workflow_dispatch`：跑 `check`（analyze + test）→ `android` + `ios` 两个打包 job。
- push `v*` tag（如 `v0.1.0`）：额外跑 `release`，把两个安装包挂到 GitHub Release 上。

## 产物
| job | 产物 | 说明 |
|---|---|---|
| android | `zhang-app-android.apk` | `flutter build apk --release`，目前用 debug keystore 签名，可直接侧载安装 |
| ios | `zhang-app-ios-unsigned.ipa` | `flutter build ios --release --no-codesign` 后打包的未签名 ipa，需要自己签名后安装 |

在 Actions 页面对应 run 的 Artifacts 里下载；tag 构建的产物在 Releases 页面。

## 之后接入正式签名
- **Android**：把 keystore base64 后存到仓库 secret（如 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`），在 `android` job 里解码到 `android/app/upload-keystore.jks`，生成 `android/key.properties`，并在 `android/app/build.gradle.kts` 的 release `signingConfig` 读取它。
- **iOS**：已接入 TestFlight，见下文。
- 未签名 ipa 的临时安装方式：Sideloadly / AltStore / Xcode「Devices and Simulators」拖入，用个人证书重签。

## iOS 签名 + TestFlight（`testflight` job）

只在 push `v*` tag 或手动 `workflow_dispatch` 时运行：导入发布证书和描述文件，在 CI 里临时把 `ios/Flutter/Release.xcconfig` 改成手动签名，再执行 `flutter build ipa`（build number 用 `github.run_number`），然后上传到 TestFlight。签名后的 ipa 也会作为 `zhang-app-ios-signed` artifact 上传。

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
flutter build ios --release --no-codesign
```

## 版本号
`pubspec.yaml` 的 `version: x.y.z+build` 决定安装包版本；发版前先改版本再打 tag。
