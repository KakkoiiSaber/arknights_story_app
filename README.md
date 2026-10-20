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

PRTS StoryPlayer 上游以 Git submodule 引入；初始化、版本更新和 Flutter 嵌入方案见
[上游播放器依赖说明](third_party/README.md)。网页版正文使用上游引擎，首页和活动主题页保留 Flutter 实现。

联动主题信息以数据仓库的 `assets/stage_table_complement.json` 为维护入口；
生成后的远程元数据包含完整主题字段时优先采用，数据发布前使用随包配置兜底。
简体中文故事库中 8 个联动活动的随包补充配置集中在
[`story_themes.json`](lib/assets/data/story_themes.json)：源石尘行动、落叶逐火、
水晶箭行动、泰拉饭、无忧梦呓、好久不见、泡影苍霆、月行水上。
它支持独立 URL、带标题的原始入口图、左右拼接背景及 intro/loop 音乐；
普通活动及其他语言仍按现有远程元数据加载。原始素材出处和替代说明保存在各条目的
`sources` / `sourceNote` 中；没有独立拆出的 Logo 时显示原始带标题活动图。
联动封面选用原始活动入口图或官方宣传图。首页封面等高、宽度随原图比例变化，使用 contain 完整展示；联动仅在独立「联动」分类中显示。
故事主题页保留完整背景与向右、向下的黑色渐变，右侧依次显示 Logo、完整简介和带分割线的章节入口；横屏右侧独立滚动，窄屏改为上下排列。
首页与主题页不再显示音量按钮。原生端默认播放音乐；网页版共用 Web Audio 上下文，首次点击、触摸结束或键盘操作后恢复播放，无需额外的启动弹窗。浏览器明确禁止站点播放声音时仍遵守其设置；PRTS 阅读器沿用自身的音频解锁逻辑。
已找到的四张 `storyreview/hubs` 剧情回顾缩略图作为备选保留在数据仓库中。
《好久不见》未确认剧情回顾主题音乐，故事介绍页保持静音；不再使用首篇剧情音乐代替。

原生 Windows、macOS、iOS、Android 阅读页使用同一份 PRTS StoryPlayer（系统 WebView）；Web 版维持在线阅读，不提供下载。
故事介绍页的「下载整个故事」一次收集所有小节的 TXT、背景、立绘、表情、音频和可用视频，按故事建立一个任务并去重资源。首页设置可查看进度、实际本地占用，暂停、继续、重试或删除任务；已下载的故事可从设置选择小节直接阅读。下载仅在 App 运行时进行，重启后保留为暂停状态；未完成文件在继续时重新下载，共享文件在最后一个引用故事删除后才清理。
播放器代码、字体、内置 UI 和映射快照随 App 打包，不计入故事下载大小。阅读器通过仅监听 `127.0.0.1` 的本地服务读取已下载文件，缺失文件才请求网络。首页与主题页资料首次运行时下载并保存在应用支持目录，后续启动检查版本并增量更新；剧情演出资源仍独立管理。

原生构建前运行：

```sh
git submodule update --init --recursive
flutter pub get
npm ci
npm run build:player
dart run tool/package_player.dart
flutter build windows
```

Windows 构建需 NuGet CLI，运行需 Microsoft Edge WebView2 Runtime。增加插件后应执行 `flutter pub get` 并完整重编译，热重载无法注册新的原生插件。生成的 `lib/assets/prts_player.zip` 不提交 Git，发布工作流会自动生成。macOS 发行包需保留本地服务的 network.server entitlement；iOS/Android 只对回环本地 HTTP 放行。

### 首页与主题资源按需下载

安装包不携带资源清单、故事目录、封面、背景或主题音乐。原生端首次启动从 story data 的 `assets/review_manifest.json` 获取清单，下载并校验对应的目录/章节介绍快照，再下载首页封面和 Logo；背景、音乐在打开故事页时按需下载。Web 继续在线使用现有数据，不提供持久下载管理。

每次启动先加载本地快照，再后台检查清单的内容版本。SHA-256 相同的文件复用，新增或变更的文件才下载；新版目录先完整落盘，失败时保留上一版。文件存储在应用支持目录 `review-resources/`，不是系统可自动清理的临时缓存。首屏优先使用可见素材，批量预取不阻塞进入故事。首页显示更新状态；设置中的「首页与主题资源」提供版本、占用、进度、检查更新、下载首页、补齐全部、暂停/继续和清理。清理保留故事目录及独立的 AVG 故事下载。

清单由 **story data 仓库** 的 Update Data Action 运行 `node scripts/review_manifest.mjs --refresh` 生成并与数据一起提交，包含真实资源来源、分组、大小与校验值，以及内容寻址的 `assets/review_payload/files/*.json`。App 发布工作流不再抓取或打包主题素材，因此数据更新无需发布新版 App。默认中文目录；数据生成器的 `--locales` 可以扩展语言。塞壬唱片会过期的签名音源通过曲目 ID 获取新地址后，仍按预期 SHA-256 校验内容。

默认清单地址为数据仓库 main 分支。开发测试可使用：

```sh
flutter run -d windows --dart-define=STORY_REVIEW_MANIFEST_URL=https://raw.githubusercontent.com/KakkoiiSaber/arknights_story_data/dev/assets/review_manifest.json
```

首次使用需要先发布数据仓库的新清单和 JSON 快照；发布前 App 会报告清单更新失败并保留现有在线读取回退。所有主题素材补齐约 419.7 MiB，首页仅预取目录、封面与 Logo。暂停和关闭 App 后均复用完整文件，未完成文件重新下载，避免 CDN 不支持 Range 时拼接损坏。

原生端烟雾测试可用 `flutter run -d windows -t tool/native_player_smoke.dart`：实际下载序章资源，检查本地命中且播放期间没有远程补载，结果写入 `.dart_tool/native-smoke-result.json`。Linux 继续保留基础 Flutter 阅读器，暂不提供 PRTS 原生下载。

PRTS 播放页的「设置」与首页设置共用全局阅读偏好：博士名称（默认博士）、文字字号（80%–140%，同时缩放对白与人物名称）和逐字显示间隔（0–100 毫秒，0 为即时显示）。字号调整会重新排版当前对白与人物名称，长名称自动缩小以适配可用宽度；名称与速度从下一句生效，自动播放的上游速度档位保持原有行为。Web 保存到当前站点的 localStorage，原生端保存到应用支持目录的 reader-settings.json，各端本地独立保存。桥接层 preferences-adapter.mjs 在构建时检查上游接口，未修改上游子模块。

运行 `node scripts/verify_story_themes.mjs` 可以检查所有补充素材的 HTTP 状态和媒体类型。
检查使用局域网预览页的 Referer，避免把 Wiki 站内允许、外部站点被拒绝的地址误判为可用。
背景通过 Flutter 图片缓存加载，章节列表不等待大图或音乐下载完成。

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
