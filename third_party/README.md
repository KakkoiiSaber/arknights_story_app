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

主页入口不变：黑暗时代·上 → 序章·上 → 显示加载中 → 就绪后自动播放。
也可直接打开 `/prts-player/index.html`，默认就是
`obt/guide/beg/0_welcome_to_guide.txt`，便于单独检查上游演出。
正文可点击/空格推进、全屏、重新阅读；图片、动画和音频由原始上游引擎执行。
加载失败会显示原因并提供重试。初始化失败、网络中断时不自动退回简化播放器。

网页版正文的背景、立绘、音频使用 PRTS 的地址及原始资源解析规则；
原版 TXT 保留 Kengxxiao 的 GitHub Raw 来源，由 PRTS 引擎解析。
没有资源来源选择或“开始阅读”确认；旧 `resources` 查询参数也不再切换资源来源。
首页、活动主题页及其封面、背景和主题音乐继续使用原有 GitHub Raw 配置。

## 资源与构建适配

1. Flutter 将当前语言的 Kengxxiao 原版 TXT URL 传入宿主，仅接受指定上游仓库的 TXT。
   TXT 保留现有来源；演出素材使用 PRTS，不依赖 arkdata 的媒体目录映射。
2. 独立 Vite 构建直接打包上游引擎，不依赖完整 Vue Wiki 外壳。
3. 字体、character.json、background.json、story_variables.json 在构建时缓存到本地宿主。
   Vite 适配器改写其交付 URL；若上游契约改变则构建失败，submodule 文件保持不变。
   对话渲染前只等待开场窗口的字体和资源，就绪后直接调用 start。
   自动尝试恢复 WebAudio，但不等待 resume 完成以免阻塞画面；如果浏览器限制
   自动出声，在首次 pointerdown、click 或 keydown 时再次解锁音频。
   `loading-window.mjs` 使用上游解析器的物理行边界选择当前及后续共 8 段非空文本，
   最多扫描 160 条解析记录；保留反斜杠续行，不改变剧情执行与分支语义。
   阅读行变化时串行预热新窗口；快速推进只保留最新待处理位置。
   窗口之外的资源（包括分支跳转）由引擎按需加载，预热失败不打断当前阅读。
   不再等待整章下载；网络慢或快速跳转时，仍可能在首次使用资源处短暂等待。
4. 保留上游 `engine/asset.ts` 的 PRTS 资源路由和 character.json 角色表示。
   宿主不再转换 arkdata 的目录、表情与姿势文件名；没有 GitHub 媒体回退。
5. 原生移动 WebView、离线媒体缓存和更多章节的演出回归仍待后续实现。

元数据缓存可用 `node player_host/prepare.mjs --refresh-metadata` 主动刷新，
再执行 `npm run build:player` 和 `npm run stage:player`。上游代码版本与在线媒体版本
分别管理；更新 submodule 后应刷新元数据并重新验证样例剧情。

上游 `.node-version` 当前为 Node 24，`package.json` 声明 pnpm 12.4.2。
其根构建面向整个 Wiki 的多组件部署，宿主应有自己的精简构建入口，
不要调用上传、发布或 prune 脚本。submodule 复用的是引擎实现，仍需要构建 Web 产物。

上游源码许可证保留在 `prts-widgets/LICENSE`（MIT）；分发构建产物时保留对应许可。
游戏图片、音频、字体等资源与引擎代码分别管理来源和许可。
