<p align="center">
  <img src="Paste/Assets.xcassets/AppIcon.appiconset/icon_256.png" alt="Paste 应用图标" width="192" height="192">
</p>

[English](README.md) | **中文**

# Paste — macOS 与 iOS 剪贴板管理器

轻量、隐私优先的剪贴板管理器。本仓库在一个 Xcode 工程中提供 **三套交付物**：

| 平台 | 说明 |
|------|------|
| **macOS — `Paste`** | 菜单栏应用：记录剪贴板历史、全局快捷键、悬浮面板、Paste Stack、Pinboards，可选 **iCloud** 同步。 |
| **iOS — `Paste-iOS`** | iPhone/iPad 应用：浏览同一套历史与 Pinboards，支持文本/图片/文件筛选、自定义分类、多选、文档扫描与快速新建文本。 |
| **iOS — `Paste-Keyboard`** | **自定义键盘扩展**：在键盘中选取已保存片段并插入到任意应用（邮件、备忘录等），无需切出当前应用。 |

**iOS 应用**与 **Paste 键盘**共用同一 **App Group** 数据库，键盘可读取应用维护的片段。macOS 使用本地存储；在 macOS 与 iOS 同时开启 **iCloud 同步**（同一 Apple ID）时，历史可在设备间同步。

**iOS / 键盘构建**需一次性配置签名与 App Group，详见 **[SETUP.md](SETUP.md)**。macOS 目标无需额外配置即可运行。

**为 GitHub Releases 打包 macOS zip/pkg：** 安装完整 Xcode 后执行 `./scripts/build-macos-github-release.sh`，详见 **[docs/RELEASE_MACOS.md](docs/RELEASE_MACOS.md)**。

**iOS 分发给他人：** Apple 不允许像 macOS 那样从 GitHub 安装；分发通过 **TestFlight** 或 **App Store**，详见 **[docs/RELEASE_IOS.md](docs/RELEASE_IOS.md)**。

**iOS 已上架 App Store：** [**Paste G** 在 App Store](https://apps.apple.com/us/app/paste-g/id6758338373) — 适用于 iPhone 与 iPad（¥18 等区定价）。

**iOS TestFlight：** 在 iPhone/iPad 上安装 [TestFlight](https://apps.apple.com/app/testflight/id899247664)，然后打开 **[此公开链接](https://testflight.apple.com/join/2UKC5P27)** 加入测试。若链接显示已满或暂不接收测试者，可邮件 **[gxlself@gmail.com](mailto:gxlself@gmail.com)**。

**问题或 Bug：** 请在 GitHub 上 [**提交 issue**](https://github.com/gxlself/paste/issues)。

若 Paste 对你有帮助，欢迎在 GitHub 上 [**给仓库点个 Star**](https://github.com/gxlself/paste)，方便更多人发现本项目。

---

## 效果图

### macOS — Paste

主面板：搜索、类型筛选（全部 / 文本 / 图片 / 文件 / 链接 / 收藏）、横向卡片浏览。

<p align="center">
  <img src="docs/screenshots/mac-main.png" alt="macOS 主面板：搜索与筛选" width="800">
</p>

主面板预览区与分类栏（深色外观）。

<p align="center">
  <img src="docs/screenshots/mac-preview.png" alt="macOS 主面板预览与分类" width="800">
</p>

### iOS — Paste G

应用概览与历史流（全部 / 文本 / 图片 / 文件 筛选）。

<p align="center">
  <img src="docs/screenshots/ios-hero.png" alt="iOS Paste G 概览" width="480">
</p>

自定义键盘：在任意应用中调出 Paste 键盘，搜索并插入已保存片段。

<p align="center">
  <img src="docs/screenshots/ios-keyboard.png" alt="iOS 自定义键盘" width="360">
</p>

功能总览：历史与分类、上下文菜单（复制 / 预览 / 编辑 / 置顶 / 分享等）、键盘与 iCloud 同步设置。

<p align="center">
  <img src="docs/screenshots/ios-features.png" alt="iOS 功能总览" width="600">
</p>

---

## 功能说明

### 剪贴板与历史（macOS）

| 功能 | 说明 |
|------|------|
| 剪贴板监控 | 约 300 ms 轮询；捕获纯文本、富文本（RTF）、图片与文件路径 |
| 智能去重 | SHA-256 内容哈希；重复项仅刷新时间戳 |
| 自写过滤 | Paste 写入的内容不会立即再次记录（避免循环） |
| 记录规则 | 跳过空/仅空白文本；可选关闭 **记录图片** 以跳过图片捕获 |
| 排除应用 | 排除列表中的 Bundle ID 不记录（如密码管理器） |
| 保留策略 | 时间预设（一天 → 不限）及非不限时的最大条数；清空全部历史；显示数据库大小 |
| 时间线分组 | 今天 / 昨天 / 本周 / 更早 |
| 来源应用 | 每条记录显示复制时所在应用的图标与名称 |
| 置顶 | 将项目固定到列表顶部 |

### 主面板

| 功能 | 说明 |
|------|------|
| 悬浮层 | 半透明 NSPanel；键盘优先；位置可设 **底部 / 顶部 / 左侧 / 右侧** |
| 外观 | 跟随系统、浅色或深色 |
| 卡片网格 | 自适应卡片布局；滑入动画 |
| 辅助粘贴 | 配合辅助功能，可粘贴到前台应用并关闭面板；关闭时仅复制到剪贴板，需自行 ⌘V |
| 菜单栏 | 左键切换面板；右键打开菜单（偏好设置、关于、打开剪贴板、暂停/恢复、退出） |

### 搜索与筛选

| 功能 | 说明 |
|------|------|
| 实时搜索 | 防抖全文搜索；面板聚焦时输入即搜 |
| 类型标签 | **全部**、**文本**、**图片**、**文件** |
| 正则标签 | 内置正则预设作为快速筛选 |
| 自定义类型 | 为项目添加用户定义分类（标签）；按分类筛选 |
| Tab 键 | 向前切换筛选标签；**⇧Tab** 向后 |

### Pinboards 与 Paste Stack

| 功能 | 说明 |
|------|------|
| Pinboards | 多槽位（默认 5 个，最多 10 个）；每槽位可标记项目；全局快捷键切换槽位 |
| Paste Stack | 将项目排队并按顺序粘贴；专用全局快捷键打开堆栈模式 |
| 纯文本粘贴 | 偏好设置：默认纯文本，或粘贴时按住 **⇧**（或所设修饰键） |

### 编辑与选择

| 功能 | 说明 |
|------|------|
| 新建条目 / Pinboard | 创建文本片段；创建新 Pinboard |
| 编辑 / 重命名 | 文本条目：完整编辑与重命名 |
| 多选 | **⇧←** / **⇧→** 扩展选择；**⌘A** 全选当前可见 |
| 撤销删除 | **⌘Z** 恢复最近删除的条目 |
| 删除 | **⌘⌫** 或 Forward Delete |
| 打开 | **⌘O** 打开 URL 或文件路径 |
| 预览 | 搜索为空时按 **Space** 快速预览 |
| 输入法 | **⌃Space** 在面板打开时切换键盘输入源 |
| 链接预览 | 卡片内可选富链接预览（偏好设置） |
| 声音 | 从面板复制时可选提示音 |

### 偏好设置（macOS）

| 标签 | 内容 |
|------|------|
| **通用** | 辅助功能状态、辅助粘贴、VoiceOver 播报、外观、面板位置、登录时启动、默认纯文本、链接预览、声音、菜单栏图标、保留与最大条数、记录图片、数据库大小、清空历史 |
| **快捷键** | 全局快捷键；快速粘贴修饰键（**⌘** / ⌥ / ⌃ / ⇧）+ **1–9**；纯文本修饰键；面板快捷键参考 |
| **规则** | 排除应用列表 |
| **同步** | 可选 iCloud（CloudKit）；立即同步 |

### iOS 应用（`Paste-iOS`）

| 功能 | 说明 |
|------|------|
| 历史 | 与共享 App Group 存储中的片段一致；滑动页面切换 **全部 / 文本 / 图片 / 文件** |
| Pinboards | 多 Pinboard 标签与 macOS 概念一致；在应用中管理 |
| 自定义类型 | 分类/标签；按类型重命名或清空 |
| 操作 | 复制到剪贴板、分享、多选批量操作、**文档扫描**与**新建文本**表单 |
| 设置 | 规则（如 iOS 上忽略敏感/自动生成内容的开关）、同步相关选项 |

### 自定义键盘（`Paste-Keyboard`）

| 项 | 说明 |
|----|------|
| 用途 | 在 **设置 → 通用 → 键盘 → 键盘** 中添加 **Paste**；输入时切换到 Paste 键盘可 **搜索并点击片段** 插入。 |
| 完全访问 | 扩展需读取共享 App Group 数据库，必须开启。添加键盘后在其设置中启用。见 [SETUP.md](SETUP.md)。 |
| 未开启完全访问 | 界面可能显示但 **无法从共享存储加载历史**。 |

### 跨设备同步

| | |
|--|--|
| **iOS 应用 ↔ 键盘** | 始终通过 **App Group** 本机存储。 |
| **macOS ↔ iOS** | 在偏好设置（macOS）与设置（iOS）中开启且使用同一 Apple ID 登录时，可选 **iCloud** 同步。 |

---

## 文档站点（`docs/`）

本项目的静态页面。**main 分支不追踪 `docs/`**；站点源在 **docs** 分支，部署到 **gh-pages**。详见 [GITHUB_PAGES.md](GITHUB_PAGES.md)。

**GitHub Pages：** 在 **Settings → Pages** 中选择 **Deploy from a branch**，分支 **gh-pages**，根目录 **/**。向 **docs** 分支推送并修改 `docs/` 时会自动部署。

**中文：** 站点导航中 **中文** 进入 `zh/index.html`。

| 页面 | 作用 |
|------|------|
| index.html | 首页、平台、亮点、赞助 |
| features.html | 功能导览（KEEP / SEARCH / ORGANIZE / 同步 / 隐私） |
| everyone.html | 普通用户 |
| developers.html | 开发者 |
| designers.html | 设计师 |
| sales-support.html | 销售与支持 |
| use-cases.html | 使用场景汇总 |
| help.html | 帮助与 FAQ |
| updates.html | 更新日志 → Releases |
| contact.html | 联系 |

---

## 系统要求

- **macOS 应用（`Paste`）**：macOS 13.0 Ventura 或更高
- **iOS 应用（`Paste-iOS`）** 与 **键盘扩展（`Paste-Keyboard`）**：iOS 16.0 或更高
- **Xcode**：15.0+，Swift 5.9+
- **构建 iOS 目标**：Apple Developer 团队 + App Group（见 [SETUP.md](SETUP.md)）

---

## 快速开始

```bash
git clone https://github.com/gxlself/paste.git
cd paste
open Paste.xcodeproj
```

**macOS**

1. 选择 **Paste** scheme 与 **My Mac**。
2. 按 **⌘R** 构建并运行。
3. 应用出现在菜单栏；**⌘⇧V**（默认）打开面板。

> **辅助功能**用于全局快捷键与**辅助粘贴**。若系统提示，请在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权。

**iOS 应用 + 自定义键盘**

1. 完成 **[SETUP.md](SETUP.md)**（签名、App Group `group.gxlself.paste-tool`，将 **Paste-Keyboard** 嵌入 **Paste-iOS**）。
2. 在模拟器或真机上运行 **Paste-iOS**（**⌘R**）。
3. 在设备上：**设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → Paste**，然后为 Paste 键盘开启 **允许完全访问**，以便读取共享历史。

---

## 项目结构

```
paste/
├── Paste.xcodeproj          # Xcode 工程（主入口）
├── docs/sponsor/            # 打赏二维码与微信公众号（README）
├── SETUP.md                 # iOS 签名、App Group、键盘完全访问
├── Paste/                   # macOS 应用 target
│   ├── App/                 # 应用入口与生命周期
│   ├── Features/            # UI 功能模块
│   │   ├── MainPanel/       # 悬浮剪贴板面板
│   │   ├── Preferences/     # 设置（通用 / 快捷键 / 规则 / 同步）
│   │   ├── About/           # 关于、隐私政策、条款
│   │   └── MenuBar/         # 菜单栏视图
│   ├── Services/            # 业务逻辑与系统服务
│   ├── Persistence/         # CoreData 栈与可选 CloudKit
│   ├── Models/              # 视图层数据模型
│   └── Support/             # 常量、AppSettings、工具
├── Paste-iOS/               # iOS 应用：浏览历史、Pinboards、设置
├── Paste-Keyboard/         # 自定义键盘：从 App Group 存储插入片段
├── Paste-Shared/            # iOS 目标共享代码
├── PasteTests/              # macOS 单元测试
├── PasteUITests/            # macOS UI 测试
└── LICENSE
```

### 架构（MVVM + Service）

**macOS：** SwiftUI + `NSPanel` / 窗口控制器 → 视图模型 → 服务（`ClipboardMonitor`、`HotKeyManager` 等）→ CoreData（+ 可选 CloudKit）。

**iOS + 键盘：** **Paste-iOS** 与 **Paste-Keyboard** 中的 SwiftUI → **Paste-Shared** 中的共享模型/仓库 → App Group 容器中的 CoreData（键盘与 iOS 应用共用同一存储）。

---

## 键盘快捷键

所有全局快捷键可在 **偏好设置 → 快捷键** 中修改（含恢复默认）。**偏好设置 → 快捷键** 还可设置 **1–9** 的**快速粘贴**修饰键（**⌘** / ⌥ / ⌃ / ⇧）与**纯文本粘贴**修饰键。

### 全局快捷键（默认）

| 操作 | 默认 | 说明 |
|------|------|------|
| 切换主面板 | ⌘⇧V | 打开/关闭剪贴板面板 |
| 切换 Paste Stack 面板 | ⌘⇧C | 打开/关闭 Paste Stack 模式 |
| 下一个 Pinboard | ⌘] | 切换到下一个 Pinboard 槽位 |
| 上一个 Pinboard | ⌘[ | 切换到上一个 Pinboard 槽位 |

### 面板内 — 导航与选择

| 快捷键 | 操作 |
|--------|------|
| ↑ / ↓ | 上一条 / 下一条 |
| ⌘↑ / ⌘↓ | 第一条 / 最后一条 |
| ← / → | 上一条 / 下一条 |
| ⇧← / ⇧→ | 扩展多选 |
| ⌘← / ⌘→ | 上一个 / 下一个 Pinboard |
| Tab / ⇧Tab | 下一个 / 上一个筛选标签（全部 → 文本 → 图片 → 文件 → 正则 → …） |
| 可打印字符 | 输入到搜索（聚焦搜索框） |
| ⌘F | 聚焦搜索 |
| Space | 快速预览（搜索为空或不占用 Space 时） |
| ⌃Space | 下一个输入源（输入法） |

### 面板内 — 操作

| 快捷键 | 操作 |
|--------|------|
| Enter / 小键盘 Enter | 粘贴选中项（默认纯文本时，或按住 **⇧** / 纯文本修饰键） |
| *修饰键* + 1 … 9 | 快速粘贴第 1–9 个**可见**项（修饰键默认 **⌘**） |
| ⌘C | 将选中项复制到系统剪贴板 |
| ⌘⌫ 或 Forward Delete | 删除选中项 |
| ⌘O | 打开 URL 或文件路径 |
| ⌘N | 新建文本条目 |
| ⇧⌘N | 新建 Pinboard |
| ⌘E | 编辑（文本条目） |
| ⌘R | 重命名（文本条目） |
| ⌘Z | 撤销最近一次删除 |
| ⌘T | 暂停 / 恢复剪贴板监控 |
| ⌘A | 全选可见项 |
| Esc | 关闭预览 → 清空搜索并失焦 → 退出多选 → 退出 Paste Stack → 退出 Pinboard 筛选 → 关闭面板 |

### 菜单栏（右键菜单）

| 项 | 说明 |
|----|------|
| 偏好设置 | 菜单打开时 **⌘,** |
| 退出 | 菜单打开时 **⌘Q** |

---

## 参与贡献

欢迎贡献。较大改动请先开 issue 讨论。

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feat/my-feature`
3. 按项目提交规范提交（见 `.cursorrules` 中的中文提交信息约定）
4. 发起 Pull Request

---

## 隐私

- 数据**仅存储在本地**；**iCloud 同步为可选**，使用你的 Apple ID / CloudKit 容器。
- **无统计、无崩溃上报**，所述配置下无第三方 SDK。
- **会记录的内容**：正常剪贴板内容，但不包括 (1) 空或仅空白文本，(2) **已排除**应用（按 Bundle ID）的复制，(3) 关闭**记录图片**时的图片，(4) Paste 自身刚写入的内容（防循环）。
- **排除应用**在 **偏好设置 → 规则** 中配置。

---

## 赞助与关注

若 Paste 为你节省了时间，欢迎打赏（微信 / 支付宝）。扫码关注微信公众号获取更新。

**小小打赏，少写 Bug — 维护者衷心感谢！**

| 微信打赏 | 支付宝 |
|----------|--------|
| <img src="docs/sponsor/wechat-pay-tip.png" width="200" alt="微信打赏二维码"> | <img src="docs/sponsor/alipay-tip.png" width="200" alt="支付宝打赏二维码"> |

**微信公众号**

<img src="docs/sponsor/wechat-official-account.png" width="200" alt="微信公众号二维码">

---

## 许可证

MIT License — 详见 [LICENSE](LICENSE)。
