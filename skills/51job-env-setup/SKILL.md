---
name: 51job-env-setup
description: >
  一键初始化 51job 招聘环境：检测 Node.js / git / 51job CLI，缺失时自动从
  GitHub 拉取 51job-cli 源码构建并全局安装（自动加 PATH），验证 51job --version
  可用，最后引导一次扫码登录。当接收人刚激活专家团、对话报错「找不到 51job」、
  需要「安装 51job CLI」「初始化环境」「自动装 CLI」时使用。
---

# 51job-env-setup —— 一键安装 51job CLI 环境

**本 skill 只干一件事：让接收人的机器在最短时间内跑起 51job CLI。**

它按顺序做四步，全部可幂等重跑：

1. **检测现状**：`node` / `npm` / `git` 是否就绪，`51job` 命令是否已可用。
2. **安装**：从 GitHub 拉取 51job-cli 源码 → `npm ci`（锁版本）→ `npm run build`（tsc 编译）→ `npm pack` → `npm install -g`。构建逻辑完全复用 recruiting-copilot 的 `install-dependencies.sh` 里已验证的 51job 分支，**不要另写一套**。
3. **修 PATH（macOS / Linux）**：如果 npm 全局 bin 不在 `PATH`，幂等地往 shell 配置文件追加一段 `export PATH="<npm-prefix>/bin:$PATH"`（zsh 写 `~/.zprofile`，bash 写 `~/.bash_profile`）。
4. **验证**：`51job --version` 能跑通才算成功；失败把**原始报错**回报用户，不瞎编原因。

## 自动安装脚本

脚本已内置在 `scripts/` 下，覆盖三类系统，**按系统选一个跑**：

| 系统 | 命令 |
|---|---|
| macOS / Linux | `sh scripts/install-51job.sh` |
| Windows（PowerShell） | `powershell -ExecutionPolicy Bypass -File scripts/install-51job.ps1` |
| 任意（仅检测不安装） | `sh scripts/install-51job.sh --check-only` |

> Windows 提示：较老的非管理员 PowerShell 可能对 `npm install -g` 有权限限制，
> 优先用管理员终端；GPT 提示 npm 全局目录权限不足时选用管理员终端重跑。
> Windows 下 `npm -g` 的 bin 目录（`%APPDATA%\npm`）默认已在 PATH。

## 使用步骤（AI 执行这份剧本）

1. **先检测**：运行 `51job --version`；成功 → 跳到步骤 4（登录引导）。
2. **缺了再装**：按用户系统执行上面的安装脚本，**捕获完整输出**。安装失败 →
   读取报错、看是缺 Node、缺 git、还是 npm 权限问题，**针对性反馈给用户**，不重复试装。
3. **验证**：`51job --version`。仍失败 → 把报错原文交回，让用户看。
4. **登录引导**：提示用户跑 `51job login` 扫码；`51job wait-login` 等待完成。
   提醒：51job 默认**有头**窗口（不能设 `51JOB_BROWSER_HEADLESS=true`），扫码窗口弹出是正常现象。
5. **验收**：全部通过 → 告知用户「环境就绪」，转入招聘流水线（recruit-daily-51job）。

## 环境要求（装不上时对照排查）

- **Node.js ≥ 20**（51job-cli 基于 tsc + puppeteer-core）
- **npm**（随 Node 自带）
- **git**（源码安装需要）
- 本机有 **Chrome 或 Edge**（51job 靠它驱动真实浏览器）

## 安全与红线

- 安装源固定为 `git+https://github.com/se7enfive/51job-cli.git#main`，**不绕开、不换源**。
- 命令里的 `npm install -g` 是唯一需要系统级权限的动作，执行前向用户说明。
- 不读取、不外传 `~/.51job-cli/.cache/` 里的 cookie / `.env` 凭证。
- 装好/装失败都要明确报告，不假装成功。