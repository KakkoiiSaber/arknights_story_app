# 原版 TXT 解析基础

网页版正文现由 PRTS 上游引擎播放，见 [桥接与构建说明](../third_party/README.md)。
下述 Dart 解析器和基础播放器保留给非 Web 平台及独立测试，不参与网页正文演出。

参考 PRTS [StoryPlayer](https://prts.wiki/w/微件:StoryPlayer) 及其
[parser.ts](https://github.com/MooncellWiki/prts-widgets/blob/main/src/widgets/StoryPlayer/engine/parser.ts)。
本项目独立实现 Dart 扫描器，只参考语法与职责划分，不依赖 Web 播放器。

`StoryPage` 从当前语言的 `gamedata/story/` 获取 UTF-8 TXT，经
`StoryScriptParser` 生成 `StoryEvent`，再交给 `StoryPlayer` 维护场景与指令游标，
由 `StoryPlayerView` 显示。解析和执行模块不依赖 Flutter，可单独验证。
原先的 `storyPreviewEvent` 保留作文本预览适配器。

## 语法与保留信息

- `[Command(key=value)]`、`[Command]`、`[name="角色"] 对白` 和普通旁白。
- 指令名统一小写；参数键保留大小写，参数值支持字符串、数字和布尔值。
- 引号中的逗号、等号、方括号和括号不作为分隔符；支持单双引号、转义及嵌套括号。
- 处理 BOM、CRLF/LF/CR、空行、整行 `//` 注释和行末反斜杠续行。
- 每个事件保留原文、首个物理行号、全部参数、尾随文本及有无参数块。
- HEADER、Character/CharSlot、音频、Delay、Tween、Decision/Predicate 等均保留为事件。
  未知指令不丢弃；畸形标签生成带诊断的 `unparsed` 事件并继续解析后文。
- 不修改 `{@nickname}`、富文本、资源键或选项值；不人为追加原文中没有的 endtip。

## 当前播放器和后续边界

支持点击、空格、回车或右方向键逐段推进对白、旁白和字幕；背景和图片更新或清除；
旧版 Character 的单人居中/双人左右布局，以及 CharSlot 的左/中/右槽位和立绘清除。
focus 以静态明暗表示，显式 ato=0 直接按淡出终点清除。Decision 等待用户选择，
Predicate 过滤不匹配分支的文本和场景指令；缺省 references 恢复共通剧情。
到末尾显示完成页，可返回主题页或重新阅读。长文本和选项可滚动。

原来的首页和故事主题页保留；进入播放器暂停主题 BGM，返回后重新播放主题 BGM。
正文不播放音频，Delay、Tween、Blocker 等演出指令目前跳过，全部仍保留在原始事件中。
背景和图片使用 PNG 默认格式；立绘优先精确表情/姿势，回退到默认缩写命名及 PNG/WebP，
缺失资源显示占位图标，不阻塞对白。特殊资源别名、复杂位移/缩放、富文本、昵称替换、
动画、遮罩和音频映射尚待后续完善。本版本不保证所有章节的演出还原。

## 验证

```sh
dart scripts/tests/story_parser_test.dart
# 可选：附加本地原版 TXT，验证整篇无解析诊断
dart scripts/tests/story_parser_test.dart /path/to/sample.txt
flutter test
flutter build web
```

测试包含语法边界、未知/损坏指令、分支控制、场景更新/清除、重新阅读、
点击和键盘推进、横竖屏布局及资源 URL 回退。
