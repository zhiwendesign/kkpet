# 卡卡（Kaka）Codex Pet

卡卡由两部分组成：Codex 原生 v2 宠物，以及显示在原生宠物头顶的轻量用量信息层。

- 人物完全由 Codex 原生宠物系统显示和控制。
- 用量信息层只显示周剩余额度进度条和 `Today:` 今日 Token，不包含第二个人物、宠物图片或人物动画。
- 在 Codex 中选择“显示宠物 / 隐藏宠物”时，原生卡卡和用量信息会一起显示或隐藏。
- 拖动原生卡卡后，用量信息会自动跟随到人物头顶。

![只包含周额度与 Today 的用量信息层](usage-only.png)

## 原生卡卡

原生宠物安装在：

```text
~/.codex/pets/kaka/
├── pet.json
└── spritesheet.webp
```

宠物格式：

- Sprite 版本：`2`
- 图集尺寸：`1536 × 2288`
- 单帧尺寸：`192 × 208`
- 图集布局：`8` 列 × `11` 行
- 支持 Codex 标准状态动画与 16 个环视方向
- 人物 hover、点击和状态动画均由 Codex 原生宠物系统负责

## 用量信息层

用量信息层版本为 `1.5.0`，界面只有两行：

1. 无黑色边框的蓝色周剩余额度进度条。
2. 黄色 `Today:` 标签和今日 Token，数值使用 `K`、`M`、`B` 紧凑格式。

信息层每 60 秒从本机 Codex 后台读取一次账户数据。它不会修改 `/Applications/ChatGPT.app` 或 `/Applications/Codex.app`，也不在 Dock 中显示图标。

信息层只监听以下原生宠物状态：

- `electron-avatar-overlay-open`：控制显示和隐藏。
- `electron-avatar-overlay-bounds`：让信息层跟随原生宠物位置。

## 安装

在项目目录执行：

```bash
./scripts/install.sh
```

安装脚本会写入：

```text
~/.codex/pets/kaka/
~/Applications/KakaUsageOverlay.app
~/Library/LaunchAgents/com.local.kaka-usage-overlay.plist
```

安装完成后，在 Codex 的 `Settings > Pets` 中选择“卡卡”，然后点击 `Wake Pet`。以后直接使用 Codex 自带的“显示宠物 / 隐藏宠物”即可。

只构建信息层：

```bash
./scripts/build.sh
```

卸载信息层但保留原生卡卡：

```bash
./scripts/uninstall.sh
```

## 分享

可以提供两种版本：

| 版本 | 包含内容 |
| --- | --- |
| 纯原生宠物 | `pet.json` 和 `spritesheet.webp`；不显示用量 |
| 原生宠物 + 用量 | 原生卡卡、周额度、Today 用量、原生显隐联动和登录自动启动 |

纯原生宠物可以直接分享 `~/.codex/pets/kaka` 目录。完整版应分享包含安装脚本、LaunchAgent 模板和预编译信息层的 ZIP。

要求：macOS 13 或更高版本，并且已经安装和登录 Codex/ChatGPT。当前应用使用本地临时签名；公开发布时建议使用 Apple Developer ID 签名并完成 notarization。

## 项目结构

```text
Sources/KakaUsageOverlay/main.swift   # 用量读取、原生显隐监听和定位
Resources/index.html                  # 仅包含周额度与 Today 的透明界面
Resources/pet.json                    # 原生宠物清单
Resources/kaka-spritesheet.webp       # 原生 v2 宠物图集
Resources/com.local.kaka-usage-overlay.plist
scripts/build.sh
scripts/install.sh
scripts/uninstall.sh
scripts/qa_overlay.swift
kaka-v2-run/                          # 原生宠物视觉 QA 资料
```

用量信息无法写进官方 `pet.json`，因此它仍由一个无 Dock 图标的透明信息层提供；该信息层不再绘制或替代原生卡卡。
