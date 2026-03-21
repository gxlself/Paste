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

## 中文支持

- 导航栏提供 **中文** 链接，进入 `zh/index.html` 中文首页。
- 中文首页为 `docs/zh/index.html`，`lang="zh-CN"`，已做基础翻译；其他子页暂链回英文版，后续可逐步补充中文版。
