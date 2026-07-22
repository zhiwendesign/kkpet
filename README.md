# 卡卡（Kaka）Codex Pet

卡卡是一只蓝色头发、蓝色安全帽和黄色工装造型的 3D 玩具风 Codex 宠物。当前版本使用 Codex v2 宠物格式，包含完整标准动画和 16 个环视方向。

![卡卡在 Codex 中的演示](kkpet.gif)

## 选择下载版本

| 版本 | 适合谁 | 包含内容 |
| --- | --- | --- |
| [纯原生版](https://github.com/zhiwendesign/kkpet/releases/download/kaka-v2.0.0/kaka-codex-pet-v2.zip) | 只想安装 Codex 宠物的用户 | `pet.json`、v2 精灵图、原生动画与 16 个环视方向 |
| [原生宠物 + 用量版 1.5.0](https://github.com/zhiwendesign/kkpet/releases/download/kaka-v2.0.0/kaka-codex-pet-v2-usage-v1.5.0.zip) | 希望在卡卡头顶查看用量的 macOS 用户 | 纯原生卡卡、周剩余额度进度条、`Today:` 今日 Token、登录自动启动 |
| [完整 QA 资料版](https://github.com/zhiwendesign/kkpet/releases/download/kaka-v2.0.0/kaka-codex-pet-v2-with-qa.zip) | 需要检查图集制作质量的用户 | 纯原生卡卡及图集、方向、动画和验证资料 |

用量版 `1.5.0` 中，人物完全由 Codex 原生宠物系统显示。透明信息层只保留下面两行内容，不再绘制第二个人物或播放伴随层人物动画：

![用量信息层](usage-overlay/usage-only.png)

历史版本 `1.4.0` 仍保留在 [GitHub Release](https://github.com/zhiwendesign/kkpet/releases/tag/kaka-v2.0.0) 中，不会被新版覆盖。

## 安装纯原生版

1. 下载并解压 `kaka-codex-pet-v2.zip`。
2. 将整个 `kaka` 文件夹复制到：

   ```text
   ~/.codex/pets/kaka
   ```

3. 重启 Codex。
4. 打开 `Settings > Pets`，选择“卡卡”，然后点击 `Wake Pet`。

可以在 Finder 中按 `Command + Shift + G`，输入 `~/.codex/pets` 后前往安装目录。如果已经有同名宠物，请先备份原目录。

## 安装原生宠物 + 用量版

要求：macOS 13 或更高版本，并且已经安装、登录 Codex/ChatGPT。

1. 下载并解压 `kaka-codex-pet-v2-usage-v1.5.0.zip`。
2. 在终端进入解压后的目录。
3. 执行：

   ```bash
   ./scripts/install.sh
   ```

安装脚本会写入：

```text
~/.codex/pets/kaka/
~/Applications/KakaUsageOverlay.app
~/Library/LaunchAgents/com.local.kaka-usage-overlay.plist
```

安装后在 Codex 中选择“卡卡”并显示宠物。此后：

- 使用 Codex 原生“显示宠物 / 隐藏宠物”，卡卡和用量信息会一起显示或隐藏。
- 拖动原生卡卡时，用量信息会自动跟随到人物头顶。
- 用量每 60 秒更新一次。
- 信息层不显示 Dock 图标，也不会修改 Codex 应用程序。

卸载用量信息层但保留原生卡卡：

```bash
./scripts/uninstall.sh
```

完整源码和技术说明位于 [`usage-overlay/`](usage-overlay/README.md)。

## 为什么用量信息是透明信息层

官方 `pet.json` 只描述宠物名称、精灵图版本和精灵图路径，不能运行脚本或读取账户用量。因此动态的周额度与今日 Token 由一个无 Dock 图标的透明 macOS 信息层提供。

信息层只负责：

- 读取本机 Codex 的周额度和每日 Token。
- 监听原生宠物的显示状态和保存位置。
- 在原生卡卡头顶绘制进度条和 `Today:`。

它不替换原生卡卡，也不包含第二套人物资源。

## 原生宠物规格

- Pet ID：`kaka`
- Sprite 版本：`2`
- 图集尺寸：`1536 × 2288`
- 单帧尺寸：`192 × 208`
- 图集布局：`8` 列 × `11` 行
- 标准状态行：`idle`、`running-right`、`running-left`、`waving`、`jumping`、`failed`、`waiting`、`running`、`review`
- 方向行：16 个顺时针方向，从 `000` 到 `337.5`

`pet.json`：

```json
{
  "id": "kaka",
  "displayName": "卡卡",
  "description": "A cheerful blue-haired 3D toy construction kid in a blue hard hat and yellow overalls.",
  "spriteVersionNumber": 2,
  "spritesheetPath": "spritesheet.webp"
}
```

`spriteVersionNumber: 2` 是必需字段；缺少它时，Codex 会按旧的九行格式读取图集。

## 质量验证

- 图集结构验证：通过，无错误或警告。
- 最终视觉 QA：通过。
- 上、右、下、左四个方向基准：全部通过盲测硬门槛。
- 用量版界面 QA：只包含周进度条与 `Today:`，不包含宠物图片、人物容器或按钮。
- 用量版应用包：只嵌入 `index.html`，原生宠物图集仅安装到 `~/.codex/pets/kaka`。

完整图集：

![卡卡 v2 图集](kaka-v2-run/qa/contact-sheet-extended.png)

16 个环视方向：

![卡卡的 16 个环视方向](kaka-v2-run/qa/look-directions.png)

## 仓库结构

```text
kaka-v2-run/                    # v2 原生宠物成品与 QA
usage-overlay/                  # macOS 用量信息层源码与安装脚本
├── Sources/KakaUsageOverlay/   # 用量读取、原生显隐监听和定位
├── Resources/                  # 信息界面、宠物安装资源和 LaunchAgent
└── scripts/                    # 构建、安装、卸载与 QA
kkpet.gif                       # Codex 中的原生宠物演示
```

仓库不再包含 v1 图集、v1 清单或 v1 验证报告。
