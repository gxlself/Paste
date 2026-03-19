# GitHub Pages 部署说明

文档站通过 **gh-pages 分支** 发布，由 GitHub Actions 从 **docs** 分支自动部署。**docs 分支只追踪 `docs/` 下的内容**（分支根目录即站点根目录），main 上保留 `docs/` 用于编辑，通过 subtree 推送到 docs 分支。

## 首次设置

1. 在仓库 **Settings → Pages** 中：
   - **Source** 选择 **Deploy from a branch**
   - **Branch** 选择 **gh-pages**，目录选 **/ (root)**
   - 保存后，需有一次推送到 **docs** 分支触发 workflow 才会生成站点

2. 自定义域名（如 `paste.gxlself.com`）：在 **Settings → Pages → Custom domain** 填写；`docs/CNAME` 在 **docs** 分支内，部署时会一并推到 gh-pages。

## 让 docs 分支只包含 docs/ 内容（subtree）

**docs** 分支使用 `git subtree split`，分支内只有站点文件（如 `index.html`、`zh/`、`site.css` 在根目录），没有 Paste 工程其他文件。

**首次创建或重建 docs 分支（在 main 上执行，且确保 `docs/` 已提交）：**

```bash
git checkout main
git subtree split --prefix=docs -b docs
git push -f origin docs
```

若远程已有 **docs** 分支，上述 `git push -f` 会覆盖，请先确认无未合并内容。

## 触发部署

- 向 **docs** 分支推送后，会自动运行 **Deploy docs to gh-pages**，将 **docs 分支根目录**（即站点）推到 **gh-pages**。
- 也可在 **Actions** 页手动运行该 workflow。

## 日常维护

- **编辑站点**：在 **main** 分支下修改 `docs/`，提交后执行：
  ```bash
  git subtree push origin docs
  ```
  即可把 `docs/` 的变更单独推到 **docs** 分支并触发部署。
- 若希望在 **docs** 分支上直接改（例如只改文案）：`git checkout docs` 后编辑根目录下的文件，提交并 push。注意此时 docs 分支没有项目其他文件，无法从 main 直接 merge，后续再更新站点内容时可从 main 重新 `git subtree push`（会按 subtree 历史合并）。

## 中文支持

- 导航栏 **中文** 进入 `zh/index.html` 中文首页；中文首页内 **English** 返回英文。
