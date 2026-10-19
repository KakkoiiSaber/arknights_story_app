# PRTS StoryPlayer 上游依赖

`prts-widgets/` 是 [MooncellWiki/prts-widgets](https://github.com/MooncellWiki/prts-widgets)
的 Git submodule，跟踪 `main`，由父仓库的 gitlink 固定具体提交。
上游引擎是 PRTS Wiki 的 Web 实现，不是鹰角官方发布的播放器 SDK。

首次接入固定为 `97d35ebedcd70d56b14d9ef05238a88460d97cf4`。
网页版正文已通过 iframe 接入上游引擎，没有修改 submodule 源码。
Android/iOS 等非 Web 平台暂时保留本项目的基础 Dart 播放器。

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

父仓库的 `player_host/` 是精简 Web 宿主，直接 import 上述接口。
Flutter Web 的 `PrtsStoryView` 用 iframe 承载；Flutter 保留首页、活动主题页、
导航和主题 BGM，正文演出由上游引擎负责。
退出时清空 iframe，宿主 pagehide 调用 destroy 释放画布、音频及监听，再恢复主题页 BGM。

## 构建和局域网预览

```sh
git submodule update --init --recursive
npm ci
npm run test:player
npm run check:player
npm run build:player
flutter pub get
flutter build web
npm run stage:player
python -m http.server 8080 --bind 0.0.0.0 --directory build/web
```

`build:player` 生成 `web/prts-player/`；`stage:player` 将完整宿主拷入 Flutter
构建目录，避免增量构建缓存遗漏新增文件。两者均已加入 Web 发布 workflow。
源码、lockfile 和 submodule 指针入库，`node_modules`、生成的 JS 和缓存字体不入库。

主页入口不变：黑暗时代·上 → 序章·上 → 等待预加载 → 点击“开始阅读”。
也可直接打开 `/prts-player/index.html`，默认就是
`obt/guide/beg/0_welcome_to_guide.txt`，便于单独检查上游演出。
正文可点击/空格推进、全屏、重新阅读；图片、动画和音频由原始上游引擎执行。
加载失败会显示原因并提供重试。初始化失败、网络中断时不自动退回简化播放器。

资源来源默认是 GitHub Raw，可在播放器顶部切换为 PRTS CDN 对照。
直接链接使用 `?resources=github` 或 `?resources=prts`，切换会重新载入当前剧情。

## 资源与构建适配

1. Flutter 将当前语言的 Kengxxiao 原版 TXT URL 传入宿主，仅接受指定上游仓库的 TXT。
2. 独立 Vite 构建直接打包上游引擎，不依赖完整 Vue Wiki 外壳。
3. 字体、character.json、background.json、story_variables.json 在构建时缓存到本地宿主。
   Vite 适配器改写其交付 URL；若上游契约改变则构建失败，submodule 文件保持不变。
   对话渲染前等待字体和资源预加载。用户点击开始后解锁 WebAudio。
4. `resources.mjs` 将上游资源路由的结果映射到 `akgcc/arkdata` 的 GitHub Raw。
   背景对应 `assets/torappu/dynamicassets/avg/backgrounds/`，图片对应同层 `images/`，
   音频对应 `assets/torappu/dynamicassets/audio/sound_beta_2/`。
   立绘从 PRTS 的 0-based body/index 转为 `assets/avg/characters/base#表情$姿势.png`，
   使用预合成图片，同时保留上游位置、原生尺寸、别名和身体分组信息。
   PRTS 模式不转换立绘表示，使用原始 CDN 素材；两种模式共享本地元数据和字体。
   未适配媒体种类和缺少映射的角色在实际引用时明确报错，不静默切回 PRTS。
   序章的 17 个 PNG 和 12 个 MP3 地址已逐项验证；其他章节仍需检查完整覆盖。
5. 原生移动 WebView、离线媒体缓存和更多章节的演出回归仍待后续实现。

元数据缓存可用 `node player_host/prepare.mjs --refresh-metadata` 主动刷新，
再执行 `npm run build:player` 和 `npm run stage:player`。上游代码版本与在线媒体版本
分别管理；更新 submodule 后应刷新元数据并重新验证样例剧情。

上游 `.node-version` 当前为 Node 24，`package.json` 声明 pnpm 12.4.2。
其根构建面向整个 Wiki 的多组件部署，宿主应有自己的精简构建入口，
不要调用上传、发布或 prune 脚本。submodule 复用的是引擎实现，仍需要构建 Web 产物。

上游源码许可证保留在 `prts-widgets/LICENSE`（MIT）；分发构建产物时保留对应许可。
游戏图片、音频、字体等资源与引擎代码分别管理来源和许可。
