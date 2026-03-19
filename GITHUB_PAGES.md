# GitHub Pages 部署说明

文档站通过 **gh-pages 分支** 发布，由 GitHub Actions 从 **docs** 分支自动部署。**main 分支不追踪 `docs/`**，站点源仅在 **docs** 分支。

## 首次设置

1. 在仓库 **Settings → Pages** 中：
   - **Source** 选择 **Deploy from a branch**
   - **Branch** 选择 **gh-pages**，目录选 **/ (root)**
   - 保存后，需有一次推送到 **docs** 分支触发 workflow 才会生成站点

2. 自定义域名（如 `paste.gxlself.com`）：在 **Settings → Pages → Custom domain** 填写；`docs/CNAME` 在 **docs** 分支内，部署时会一并推到 gh-pages。

## 触发部署

- 向 **docs** 分支推送且修改了 `docs/` 或本 workflow 时，会自动运行 **Deploy docs to gh-pages**，将 `docs/` 内容推到 **gh-pages**。
- 也可在 **Actions** 页手动运行该 workflow。

## 日常维护

- **编辑站点**：在 **docs** 分支下修改 `docs/`，提交并 push 到 **docs** 即可触发部署。
- **main 不追踪 docs/**：main 的 `.gitignore` 已忽略 `docs/`，如需从 main 移除已追踪的 docs，执行：
  ```bash
  git checkout main
  git rm -r --cached docs/
  git commit -m "chore: stop tracking docs/ on main"
  ```
  执行前请确保已创建并推送 **docs** 分支（`git branch docs && git push origin docs`），以免丢失站点内容。

## 中文支持

- 导航栏 **中文** 进入 `zh/index.html` 中文首页；中文首页内 **English** 返回英文。
