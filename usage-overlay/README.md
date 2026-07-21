# 卡卡（Kaka）Codex Pet + 用量悬浮层

卡卡是一个蓝色头发、蓝色安全帽和黄色工装造型的 3D 玩具风 Codex 宠物。当前宠物格式为 v2，支持完整标准动画、16 个环视方向，以及账户周用量与每日 Token 显示。用量挂件当前为 `1.4.0`，已与 Codex 原生的“显示宠物 / 隐藏宠物”联动。

## 用量悬浮层

用量挂件会直接读取本机 Codex 后台的账户数据，每 60 秒自动刷新。它不再使用独立的显示开关，而是跟随 Codex 原生宠物状态：

- 在 Codex 的 `Settings > Pets` 点击 `Wake Pet`，或在账户菜单中选择“显示宠物”：卡卡和用量区一起出现。
- 点击 `Tuck Away Pet`，或选择“隐藏宠物”：卡卡和用量区一起隐藏。
- 挂件以只读方式监听 Codex 保存的宠物开关和坐标，响应时间约 `0.35 秒`；拖动原生宠物后会自动对齐新位置。
- 用户级 LaunchAgent 会在登录 macOS 后自动启动，并在挂件异常退出时恢复，所以重启 Codex 或 Mac 后不会再丢失。
- 挂件不修改 `/Applications/ChatGPT.app` 或 `/Applications/Codex.app`，Codex 更新不会覆盖它。

界面与动画：

- 人物上方采用紧凑两行布局：第一行显示周剩余额度进度条，第二行用黄色 `Today:` 标签显示今日用量。
- 周剩余百分比放在无黑色边框的蓝色胶囊进度条内部；每日 Token 使用 `K`、`M`、`B` 紧凑格式。
- 人物显示宽度与 Codex 原生默认宠物一致，为 `112 px`。
- 用量区没有厚重卡片背景，靠近卡卡时仅轻微提高文字亮度。
- 四档人物状态与四套交互动作都使用现有 v2 图集帧，不叠加 CSS 缩放或摇晃。
- 默认只播放低频待机；macOS 原生跟踪鼠标进入人物区域，hover 时先挥手一轮，再按当前额度播放快速双跳、普通单跳、弱跳或勉强起身，随后自动恢复对应状态。点击则直接播放当前档位动作。
- 挂件窗口不拦截鼠标，原生宠物仍可拖动；挂件会在拖动结束后跟随新坐标。

人物状态按「周剩余额度」切换：

| 周剩余 | 人物状态 | 动画表现 |
| --- | --- | --- |
| `80%–100%` | 活蹦乱跳 | 低频活泼待机；hover 播放快速连跳 |
| `20%–79%` | 平平淡淡 | 原生慢速待机；hover 播放一次完整普通跳 |
| `5%–19%` | 疲惫 | 持续低头缓动；hover 只做幅度很小的弱跳 |
| `<5%` | 躺下休息 | 保持躺下；hover 勉强起身、小跳后回到疲惫动作 |

Codex 的 `pet.json` 只支持宠物名称、图集版本和图集路径，不能直接声明用量 UI。因此原生 v2 宠物安装在 `~/.codex/pets/kaka`，用量与四档状态由透明 macOS 伴侣挂件完成；原生开关作为两者的统一控制入口。

### 安装与启动

安装 Codex v2 宠物、用量挂件和自动启动服务：

```bash
./scripts/install.sh
```

安装脚本会写入：

```text
~/.codex/pets/kaka/
~/Applications/KakaUsageOverlay.app
~/Library/LaunchAgents/com.local.kaka-usage-overlay.plist
```

安装后打开 Codex 的 `Settings > Pets`，选择“卡卡”，再点击 `Wake Pet`。以后只需使用 Codex 自带的“显示宠物 / 隐藏宠物”。

只构建项目内版本：

```bash
./scripts/build.sh
```

构建产物位于：

```text
dist/KakaUsageOverlay.app
```

卸载用量挂件（不删除 Codex 宠物本体）：

```bash
./scripts/uninstall.sh
```

## 分享给其他人

根据对方需要，可以分享完整悬浮层，也可以只分享 Codex 宠物：

| 分享方式 | 包含内容 | 不包含内容 |
| --- | --- | --- |
| 完整版安装包（推荐） | Codex v2 宠物、四档状态与交互动作、周剩余额度进度条、`Today:` 今日 Token、原生显示/隐藏联动、自动启动 | — |
| 仅 `kaka` 宠物目录 | Codex v2 宠物、标准动画、16 个环视方向 | 用量进度条、今日 Token 和独立悬浮层交互 |

### 分享完整版（推荐）

请分享 release 中的完整版 ZIP，不要只发送 `.app`。完整包同时包含预编译应用、v2 宠物图集、安装/卸载脚本和 LaunchAgent 模板，接收方不需要 Xcode。

接收方解压后在终端进入该目录，执行：

```bash
./scripts/install.sh
```

要求：macOS 13 或更新版本，并已安装、登录 Codex/ChatGPT。安装完成后，需要在 `Settings > Pets` 中选择“卡卡”并显示宠物。

> 当前构建使用本地临时签名，尚未经过 Apple 公证，因此首次打开时 macOS 可能显示安全提示。若要公开发布给大量用户，需要改用 Apple Developer ID 签名并完成 Apple notarization（公证）。

### 仅分享 Codex 宠物

如果对方只想在 Codex 中使用卡卡，可以压缩已经安装的宠物目录：

```bash
ditto -c -k --sequesterRsrc --keepParent \
  "$HOME/.codex/pets/kaka" \
  "$HOME/Desktop/kaka-pet-v2.zip"
```

接收方解压后，将整个 `kaka` 文件夹放到：

```text
~/.codex/pets/kaka
```

可以在 Finder 中按 `Command + Shift + G`，输入 `~/.codex/pets` 后前往该目录。复制完成后重启 Codex 即可。

这种方式只安装 v2 宠物，不会显示周用量进度条、`Today:` 今日 Token 或独立悬浮层。

## 当前状态

- Pet ID：`kaka`
- Sprite 版本：`2`
- 图集尺寸：`1536 × 2288`
- 单帧尺寸：`192 × 208`
- 图集布局：`8` 列 × `11` 行
- 安装目录：`~/.codex/pets/kaka`
- 图集验证：通过，无错误或警告
- 独立视觉 QA：通过
- 四个方向基准：上、右、下、左全部通过盲测硬门槛
- 用量数据：Codex 本地 `account/rateLimits/read` 与 `account/usage/read`
- 用量刷新：每 60 秒
- 用量悬浮层：macOS 透明置顶窗口，不显示 Dock 图标
- 原生联动：监听 `electron-avatar-overlay-open` 和原生宠物坐标，不写入 Codex 状态
- 自动恢复：`com.local.kaka-usage-overlay` 用户级 LaunchAgent

项目中只保留当前 v2 成品与 QA 资料。

## 文件位置

已安装的宠物：

```text
~/.codex/pets/kaka/
├── pet.json
└── spritesheet.webp
```

项目内的 v2 成品和验证资料：

```text
Sources/KakaUsageOverlay/
└── main.swift
Resources/
├── Info.plist
├── com.local.kaka-usage-overlay.plist
├── index.html
├── kaka-lying.png
├── kaka-spritesheet.webp
└── pet.json
scripts/
├── build.sh
├── install.sh
├── qa_overlay.swift
└── uninstall.sh
qa/usage-overlay/
├── lively-90.png
├── lively-hover.png
├── normal-40.png
├── normal-hover.png
├── tired-15.png
├── tired-hover.png
├── lying-3.png
└── lying-hover.png
kaka-v2-run/
├── pet_request.json
├── final/
│   ├── spritesheet-extended.webp
│   ├── validation-extended.json
│   └── validation-packaged.json
└── qa/
    ├── contact-sheet-extended.png
    ├── look-directions.png
    ├── direction-semantics.json
    ├── direction-blind-validation.json
    ├── look-continuity.json
    ├── final-visual-qa.json
    ├── previews/
    └── run-summary.json
```

## 图集布局

| 行 | 状态 | 帧数 |
| --- | --- | ---: |
| 0 | idle | 6，另含 neutral 帧 |
| 1 | running-right | 8 |
| 2 | running-left | 8 |
| 3 | waving | 4 |
| 4 | jumping | 5 |
| 5 | failed | 8 |
| 6 | waiting | 6 |
| 7 | running | 6 |
| 8 | review | 6 |
| 9 | `000`–`157.5` | 8 |
| 10 | `180`–`337.5` | 8 |

16 个方向按顺时针排列：

```text
000, 022.5, 045, 067.5, 090, 112.5, 135, 157.5,
180, 202.5, 225, 247.5, 270, 292.5, 315, 337.5
```

其中 `000` 表示向上，`090` 表示屏幕右侧，`180` 表示向下，`270` 表示屏幕左侧。neutral 位于第 0 行第 6 列。

## 安装清单

`~/.codex/pets/kaka/pet.json`：

```json
{
  "id": "kaka",
  "displayName": "卡卡",
  "description": "A cheerful blue-haired 3D toy construction kid in a blue hard hat and yellow overalls.",
  "spriteVersionNumber": 2,
  "spritesheetPath": "spritesheet.webp"
}
```

`spriteVersionNumber: 2` 是必需字段；缺少它时，Codex 无法按当前十一行格式读取图集。

## QA 预览

完整图集：

![卡卡 v2 图集](kaka-v2-run/qa/contact-sheet-extended.png)

16 个环视方向：

![卡卡的 16 个环视方向](kaka-v2-run/qa/look-directions.png)

方向连续性检测记录了少量中间角度和行边界的审阅提示，但标签化动画复核确认不存在方向反转、尺寸跳变、注册偏移或身份漂移，因此最终视觉 QA 通过。

用量悬浮层的四档状态也已逐档截图验证：

| 活蹦乱跳 | 正常 | 疲惫 | 躺下 |
| --- | --- | --- | --- |
| ![活泼状态](qa/usage-overlay/lively-90.png) | ![正常状态](qa/usage-overlay/normal-40.png) | ![疲惫状态](qa/usage-overlay/tired-15.png) | ![躺下状态](qa/usage-overlay/lying-3.png) |

四档状态分别拥有专属 hover / 点击动作，每次只播放一轮：

| 快速连跳 | 普通跳 | 弱跳 | 勉强起身 |
| --- | --- | --- | --- |
| ![活泼 hover](qa/usage-overlay/lively-hover.png) | ![正常 hover](qa/usage-overlay/normal-hover.png) | ![疲惫 hover](qa/usage-overlay/tired-hover.png) | ![躺下 hover](qa/usage-overlay/lying-hover.png) |
