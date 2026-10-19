# PRTS StoryPlayer 上游依赖

`prts-widgets/` 是 [MooncellWiki/prts-widgets](https://github.com/MooncellWiki/prts-widgets)
的 Git submodule，跟踪 `main`，由父仓库的 gitlink 固定具体提交。
上游引擎是 PRTS Wiki 的 Web 实现，不是鹰角官方发布的播放器 SDK。

首次接入固定为 `97d35ebedcd70d56b14d9ef05238a88460d97cf4`。
当前仅完成源码依赖接入；Flutter 正文仍使用本项目的基础 Dart 播放器，
尚未切换到上游引擎，也没有修改上游源码。

## 克隆和更新

```sh
git clone --recurse-submodules https://github.com/KakkoiiSaber/arknights_story_app.git
# 已有 checkout 补齐依赖（使用父仓库固定的版本）
git submodule update --init --recursive

# 主动升级到上游 main，再验证并记录新的 gitlink
git submodule update --remote -- third_party/prts-widgets
git diff --submodule=log
git add third_party/prts-widgets
```

升级必须连同宿主桥接构建和样例剧情回归验证，再提交父仓库的新指针。
常规 clone/build 使用固定提交，不使用 `--remote`，避免不同机器得到不同引擎。
Git submodule 按仓库引入，不能只把上游的 StoryPlayer 子目录作为独立 submodule。

## 调用接口与宿主边界

关键源码都在 `src/widgets/StoryPlayer/`：

- `context.ts`：`loadContextByScript(txt)`，载入角色映射、音频变量及背景尺寸数据。
- `engine/preload.ts`：`preloadContextAssets(context, onProgress)`，预加载图片、音频和字体。
- `engine/createStoryPlayer.ts`：`createStoryPlayer(context)`，返回 `mount(host)`、
  `start()`、`advance()`、`destroy()` 等接口。
- `index.vue`：PRTS 的完整 Vue UI 外壳；可以单独复用引擎，而不依赖 Wiki 页面的模板。
- `AGENTS.md`：上游结构、行为约束和测试说明。

下一阶段在父仓库新增独立 Web 宿主与构建配置，直接 import 上述接口。
Flutter Web 用 iframe 承载，Android/iOS 用 WebView 承载；Flutter 保留首页、
活动主题页、导航和主题 BGM，正文演出由上游引擎负责。
退出时必须 destroy 播放器，释放画布、音频及事件监听，然后恢复主题页 BGM。

仍需完成并验证的桥接工作：

1. 将 Kengxxiao 的原版 TXT 传入宿主，提供加载、失败重试和用户点击开始入口。
2. 将 TypeScript/PixiJS 编译为 JS/CSS/图片产物，并纳入 Flutter 的构建和打包步骤。
3. 处理 Web 与移动 WebView 的跨域、字体、音频用户手势、生命周期和横屏。
4. 使用上游配套的 PRTS 资源映射。`asset.ts` 路由到 `torappu.prts.wiki`；
   `context.ts` 拉取 character.json 等数据，不能仅更换图片 URL 就混用 arkdata。
   `font.ts` 还注明了 static.prts.wiki 的 Referer/CORS 限制，需要在独立宿主上实测。
5. 用 `obt/guide/beg/0_welcome_to_guide.txt` 对照验证立绘、focus、黑白遮罩、
   镜头运动、BGM/音效和分支，再替换现有正文入口。

上游 `.node-version` 当前为 Node 24，`package.json` 声明 pnpm 12.4.2。
其根构建面向整个 Wiki 的多组件部署，宿主应有自己的精简构建入口，
不要调用上传、发布或 prune 脚本。submodule 复用的是引擎实现，仍需要构建 Web 产物。

上游源码许可证保留在 `prts-widgets/LICENSE`（MIT）；分发构建产物时保留对应许可。
游戏图片、音频、字体等资源与引擎代码分别管理来源和许可。
