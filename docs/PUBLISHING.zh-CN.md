# 将 Screen Measurement Toolkit 发布到 GitHub

## 许可与署名

已核对 [Distanser 的许可证](https://github.com/simpel/ruler/blob/main/LICENSE)：MIT，原版权为 `Copyright (c) 2026 Joel Sandén`。MIT 允许修改、发布、分发、再许可和销售软件副本；复制原代码或其重要部分时，需要保留原版权声明和完整许可声明。原许可还含免责条款。

本项目已准备：

- 根目录 **LICENSE**：原始 MIT 全文逐字保留。
- 根目录 **NOTICE**：上游链接、作者、基线版本与修改说明。
- **README**：明确说明独立衍生自 Distanser，不把原始代码署名改成自己的。
- 应用 `Contents/Resources/` 与 DMG：携带 LICENSE 和 NOTICE。
- 关于 / 帮助与控制面板：保留来源与原作者致谢。

你可以给自己确实拥有版权的新增代码加真实姓名及年份，保留原作者声明和 MIT 全文即可。没有义务把所有新增代码都写成原作者的作品。仓库整体继续使用 MIT 是最直接的发布方式。

版权许可针对代码；新名称用于区别独立衍生项目。不要将项目描述成原作者官方发布或得到原作者背书。

## 推荐：新建独立仓库

仓库名可用 **screen-measurement-toolkit**，软件名称保留 **Screen Measurement Toolkit**。

1. 解压交付的源码 ZIP。此包不含 `.git`、编译缓存、旧安装包和上游 App Store 签名配置。
2. 在 GitHub 点 **New repository**，选择你的账号与可见性。创建空仓库，不额外生成 README、LICENSE 或 .gitignore；源码包已有这些文件。[GitHub 官方新建仓库步骤](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)
3. 在解压后的 `ScreenMeasurementToolkit` 目录运行以下命令，将 `YOUR_GITHUB_USERNAME` 换成你的账号：

```sh
git init -b main
git add .
git commit -m "feat: release Screen Measurement Toolkit"
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/screen-measurement-toolkit.git
git push -u origin main
```

这套命令适用于交付 ZIP 的新目录，不用于重置已有 `.git` 的开发工作区。

## 发布安装包

可直接在仓库 **Releases → Draft a new release** 中选择 `v1.0.0`，填写说明并附上：

- `Screen-Measurement-Toolkit-1.0.0-macOS.dmg`
- `Screen-Measurement-Toolkit-1.0.0-macOS.zip`（可选）
- `Screen-Measurement-Toolkit-1.0.0-Source.zip`（可选，经过整理的完整源码）
- `SHA256SUMS.txt`

检查草稿后点击 **Publish release**。GitHub 会按标签提供源码下载；无需把 DMG 或编译缓存提交进代码仓库。[GitHub 官方 Release 步骤](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

### 自动构建方式

项目已有 `.github/workflows/ci.yml` 与 `release.yml`。CI 构建与打包；推送 `v*` 标签会自动构建通用应用并创建 **Release 草稿**，供你检查后发布。

```sh
git tag v1.0.0
git push origin v1.0.0
```

仓库需启用 GitHub Actions。发布任务使用本仓库 `GITHUB_TOKEN` 的 `contents: write` 权限，不访问上游仓库、上游 Homebrew tap 或 App Store Connect。

若先手动创建了同一版本的 Release，勿再用同一标签触发自动创建；选择手动或自动方式之一。

## macOS 签名与公证

当前交付包是 **ad-hoc 签名，尚未 Apple 公证**。互联网下载后 Gatekeeper 可能要求用户在系统设置中选择“仍要打开”。公开面向更多用户分发时，建议用自己的 Apple Developer ID 证书签名并公证。

```sh
CODESIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" ./package.sh
xcrun notarytool submit build/dist/Screen-Measurement-Toolkit-1.0.0-macOS.dmg \
  --keychain-profile YOUR_NOTARY_PROFILE --wait
xcrun stapler staple build/dist/Screen-Measurement-Toolkit-1.0.0-macOS.dmg
```

`YOUR_NOTARY_PROFILE` 需按 Apple 官方流程预先配置。公证和 stapling 完成后重新生成并发布 DMG 校验和。自动工作流默认只做 ad-hoc 签名；需要公证时，在你自己的构建环境或经配置的 CI 中处理证书与凭据。

提供 `CODESIGN_IDENTITY` 后，构建脚本会为应用和 DMG 使用该身份签名并添加安全时间戳。证书签名与公证分支需要你的证书和凭据，当前本地交付已验证的是 ad-hoc 分支。上述流程公证的是 DMG；若同时分发应用 ZIP，应确保其中的应用已公证，并为应用附加票据后重新打 ZIP。[Apple：打包 macOS 软件](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)

参考：[Apple：自定义签名与公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。

## 后续更新

修改 `Resources/Info.plist` 中的版本与构建号，运行检查、打包，再创建新标签和 Release。保留 LICENSE 与 NOTICE，继续记录上游来源及你自己的修改。
