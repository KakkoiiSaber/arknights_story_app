# 原版 TXT 解析基础

参考 PRTS [StoryPlayer](https://prts.wiki/w/微件:StoryPlayer) 及其
[parser.ts](https://github.com/MooncellWiki/prts-widgets/blob/main/src/widgets/StoryPlayer/engine/parser.ts)。
本项目独立实现 Dart 扫描器，只参考语法与职责划分，不依赖 Web 播放器。

`StoryPage` 从当前语言的 `gamedata/story/` 获取 UTF-8 TXT，经
`StoryScriptParser` 生成 `StoryEvent`，再经 `storyPreviewEvent` 显示滚动阅读预览。
解析模块不依赖 Flutter，可单独验证。

## 语法与保留信息

- `[Command(key=value)]`、`[Command]`、`[name="角色"] 对白` 和普通旁白。
- 指令名统一小写；参数键保留大小写，参数值支持字符串、数字和布尔值。
- 引号中的逗号、等号、方括号和括号不作为分隔符；支持单双引号、转义及嵌套括号。
- 处理 BOM、CRLF/LF/CR、空行、整行 `//` 注释和行末反斜杠续行。
- 每个事件保留原文、首个物理行号、全部参数、尾随文本及有无参数块。
- HEADER、Character/CharSlot、音频、Delay、Tween、Decision/Predicate 等均保留为事件。
  未知指令不丢弃；畸形标签生成带诊断的 `unparsed` 事件并继续解析后文。
- 不修改 `{@nickname}`、富文本、资源键或选项值；不人为追加原文中没有的 endtip。

## 当前预览和后续边界

预览显示对白、旁白、字幕、背景、图片及选项文本，展示全部分支，并在界面明确标注。
原始事件流仍包含预览未处理的指令。预览不播放音频，不执行选项跳转、立绘演出、
遮罩、等待或动画，也不把 ListView 的构建顺序当成脚本执行顺序。

下一阶段需要独立 runtime：维护场景状态和指令游标，实现点击推进、Decision/Predicate
分支、阻塞与非阻塞时序，再接立绘和资源解析。音频 `$key` 需要映射，图片文件格式、
立绘缺失和不同命名变体需要资源回退。当前图片预览使用 PNG，尚不保证所有章节的资源覆盖。

## 验证

```sh
dart scripts/tests/story_parser_test.dart
# 可选：附加本地原版 TXT，验证整篇无解析诊断
dart scripts/tests/story_parser_test.dart /path/to/sample.txt
```

测试包含语法边界、未知/损坏指令、分支参数、资源键、路径迁移及预览不执行音频。
