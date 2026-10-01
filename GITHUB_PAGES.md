# GitHub Pages 部署说明

文档站通过 **gh-pages 分支** 发布到 GitHub Pages，由 GitHub Actions 自动部署。

## 首次设置

1. 在仓库 **Settings → Pages** 中：
   - **Source** 选择 **Deploy from a branch**
   - **Branch** 选择 **gh-pages**，目录选 **/ (root)**
   - 保存后，首次需等一次 workflow 跑完才会生成站点

2. 若使用自定义域名（如 `paste.gxlself.com`），在 **Settings → Pages → Custom domain** 填写域名；`docs/CNAME` 已包含该域名，部署时会一并推到 gh-pages。

## 触发部署

- 向 **main** 分支推送且变更包含 `docs/**` 或 `.github/workflows/deploy-docs.yml` 时，会自动运行 **Deploy docs to gh-pages**，将仓库中 **`docs/` 目录**推送到 **gh-pages** 分支根目录（与线上站点一致）。
- 也可在 **Actions** 页手动 **Run workflow** 触发部署。

## 本机手动推送到 gh-pages

当需要**不经过 main 推送**、直接把当前工作区里的 `docs/` 同步到线上时，在**仓库根目录**执行（**不要**加 `sudo`）：

```bash
# 任选其一（推荐第一种，不依赖可执行位）
bash scripts/deploy-docs-gh-pages.sh

chmod +x scripts/deploy-docs-gh-pages.sh
./scripts/deploy-docs-gh-pages.sh
```

若出现 `zsh: permission denied: ./scripts/...`，说明未 `chmod +x`，请用上面的 `bash scripts/...`，或先 `chmod +x` 再 `./scripts/...`。**不要用 `sudo ./scripts/...`**（工作目录与 PATH 会变，常见 `command not found`，且不应以 root 推你自己的仓库）。

脚本会读取 **`origin`** 的 URL，将 `docs/` 打成单次 orphan 提交并 **`git push -f origin gh-pages`**（与 Actions 的 `force_orphan` 一致）。需本机 **SSH 能连 GitHub** 或 **HTTPS + 有效凭据**。若走代理导致 `Connection closed by 127.0.0.1:7890` 之类错误，请检查系统/终端的代理或 `GIT_SSH_COMMAND`、`~/.ssh/config`，使 `git` 访问 `github.com` 正常。

将脚本纳入版本库时若希望克隆后可直接 `./scripts/...`，在仓库根执行一次：`git update-index --chmod=+x scripts/deploy-docs-gh-pages.sh` 并提交（Git 会记录可执行位）。

## SEO（搜索与分享）

- 规范域名与 **canonical / Open Graph** 使用 **`https://paste.gxlself.com`**（与 `docs/CNAME` 一致）；若更换自定义域名，需同步更新各 HTML 的 `head` 与 **`docs/sitemap.xml`**。
- **`docs/robots.txt`** 指向站点地图；新增或下线可索引页面时，更新 **`docs/sitemap.xml`** 中的 URL 列表。
- 上线后可在 [Google Search Console](https://search.google.com/search-console) 提交 `https://paste.gxlself.com/sitemap.xml`。

## 链接约定（macOS 安装包）

- 导航主按钮 **Get Paste** / **获取 macOS 版**、首屏与功能页底部的 **Get Paste for macOS** / **获取 macOS 版 Paste**、**Updates** 页主按钮 → 均指向 **[GitHub Releases](https://github.com/gxlself/Paste/releases)**，便于一键进入发布页下载 `Paste-*-macos.zip`。
- **paste.gxlself.com** 可在文案中作为产品介绍 / 截图说明出现（纯文字或单独链到官网）；**不要**把 macOS zip 的唯一入口改成仅官网而无 Releases 链。
- iOS（App Store / TestFlight）链接与 macOS 下载分开维护，勿混用。

## 中文支持

- 导航栏提供 **中文** 链接，进入 `zh/index.html` 中文首页。
- 中文首页为 `docs/zh/index.html`，`lang="zh-CN"`，已做基础翻译；其他子页暂链回英文版，后续可逐步补充中文版。
