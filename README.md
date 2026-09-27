# arknights_story_app

使用 Flutter 开发的明日方舟剧情阅读与回顾应用。

## iOS：使用 SideStore 安装与更新

首次使用需要按 [SideStore 官方指南](https://docs.sidestore.io/docs/installation/prerequisites) 安装并配置 SideStore。
安装本应用时，由 SideStore 使用**用户自己的 Apple 账号**签名，无需作者提供付费开发者证书。

应用源地址（第一个包含此发布流程的正式版本发布成功后生效）：

[Arknights Story 应用源](https://github.com/KakkoiiSaber/arknights_story_app/releases/latest/download/apps.json)

```text
https://github.com/KakkoiiSaber/arknights_story_app/releases/latest/download/apps.json
```

1. 打开 SideStore，进入 **Sources**，点击 **+** 并粘贴上述地址。
2. 在源中找到 **Arknights Story**，点击安装。
3. 新版本发布后，刷新源或等待 SideStore 检查更新，再点击 **Update**。

已安装 SideStore 的设备也可使用以下链接唤起添加源；若浏览器不支持，请复制上面的 HTTPS 地址手动添加：

[在 SideStore 中添加源](sidestore://source?url=https%3A%2F%2Fgithub.com%2FKakkoiiSaber%2Farknights_story_app%2Freleases%2Flatest%2Fdownload%2Fapps.json)

此源使用 AltStore Classic 兼容格式，也可添加到支持该格式的其他客户端。
免费账号的签名通常在 7 天后过期；请保持 SideStore 所需的本地 VPN 和后台续签配置正常。
**Refresh 是续签已安装版本，Update 才是安装新版本**，应用源不会保证无人操作的静默升级。
详情参考 [SideStore FAQ](https://docs.sidestore.io/docs/faq) 和 [应用源说明](https://docs.sidestore.io/docs/advanced/app-sources)。

## 发布新版本

将代码提交并推送到 GitHub 后，创建一个递增的正式版本 tag，例如：

```sh
git tag v0.1.1
git push origin v0.1.1
```

`Flutter App Release` 工作流会自动：

1. 从 tag 得到版本号（`v0.1.1` 对应 `0.1.1`），以 Actions 的运行序号作为构建号，传给各原生平台的 Flutter 构建命令。
2. 在 macOS runner 上生成未签名 IPA，读取实际安装包的版本、Bundle ID、最低 iOS 版本、文件大小和隐私权限，并检查构建产物的签名权限。
3. 生成 `apps.json`，将 IPA、图标 `icon.png` 和应用源一起上传到 GitHub Release。
4. 保留从接入此流程之后发布的源版本记录，将新版本放在最前面，让较旧 iOS 设备仍可选择兼容版本。
5. 在附件上传完成后公开正式 Release，并将其设为 Latest，使固定订阅地址自动指向新源。

支持 `v主版本.次版本.修订号`，兼容原有的 `v0.1`（构建版本规范化为 `0.1.0`）。
当前流程只发布正式版，不接受带 `-beta`、`-rc` 或 `+构建号` 的 tag。
请每次使用一个新版本 tag；发布步骤会拒绝覆盖源中相同或更早的版本。
构建失败且尚未公开的 Release 可以重跑，已公开版本的修复应使用新 tag。

在分支上手动运行工作流时，版本取自 `pubspec.yaml`，仅生成构建附件，不发布 Release 或应用源。
在 tag 上手动运行会执行正式发布。
可以同步维护 `pubspec.yaml` 的版本用于本地构建；正式发布时以 tag 为准。

发布脚本只使用 Python 标准库，不需要额外服务器、Apple 签名密钥或个人访问令牌。
CI 固定使用 Flutter 3.47.5，Android 构建使用 Gradle 8.14.4、AGP 8.11.1 和 Kotlin 2.2.20；升级 Flutter 时需同时检查这些工具的兼容性。
Windows 构建固定使用 `windows-2022`（Visual Studio 2022），以兼容当前音频插件。
GitHub 仓库及 Release 附件需要公开可下载；工作流仅在发布 job 使用内置 `GITHUB_TOKEN` 的 `contents: write` 权限。
请保留应用现有 Bundle ID `com.example.arknightsStoryApp`，以便已有用户继续接收覆盖更新。

源作为 Release 附件保存，不放在会被网页构建覆盖的 `docs/` 中。
首次接入前已发布的旧 IPA 不会自动补入版本记录。维护 Release 时，请保留已发布的 IPA 和图标附件，且不要把缺少 `apps.json` 的 Release 标为 Latest。

本地验证发布脚本（Python 3.10+）：

```sh
python -m unittest discover -s scripts/tests -v
python scripts/altstore_source.py version --ref refs/tags/v0.1.1
```

格式依据：[AltStore 应用源规范](https://faq.altstore.io/developers/make-a-source) 与 [更新规则](https://faq.altstore.io/developers/updating-apps)。

## 数据与资源

review data and assets:
[story review meta/audio/info data](https://github.com/KakkoiiSaber/arknights_story_data/tree/main/assets)
[story review cover/title/bg/bgmusic assets](https://github.com/KakkoiiSaber/arkdata/tree/main/assets)

story data and assets:
[story data cn](https://github.com/Kengxxiao/ArknightsGameData/tree/master/zh_CN/gamedata/story)
[story data global](https://github.com/Kengxxiao/ArknightsGameData_YoStar/tree/main/en_US/gamedata/story)
[story audio/video/img/char assets](https://github.com/akgcc/arkdata/tree/main/assets)




utils
[poster](https://prts.wiki/w/%E5%AE%98%E6%96%B9%E5%AE%A3%E4%BC%A0%E5%9B%BE%E4%B8%80%E8%A7%88)
[assetsguide](https://github.com/isHarryh/Ark-Unpacker/blob/v4.x/docs/AssetsGuide.md)
