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
- **iOS**：需要 Apple Developer 账号。推荐 `apple-actions/import-codesign-certs` + `apple-actions/download-provisioning-profiles`（或 fastlane match）导入证书和描述文件，然后把 `--no-codesign` 换成 `flutter build ipa --export-options-plist=ios/ExportOptions.plist`，产物改为 `build/ios/ipa/*.ipa`。
- 未签名 ipa 的临时安装方式：Sideloadly / AltStore / Xcode「Devices and Simulators」拖入，用个人证书重签。

## 本地等价命令
```sh
flutter analyze && flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

## 版本号
`pubspec.yaml` 的 `version: x.y.z+build` 决定安装包版本；发版前先改版本再打 tag。
