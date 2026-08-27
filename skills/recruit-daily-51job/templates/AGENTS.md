# AGENTS.md —— 51job 招聘工作区 · AI 协作约定

> 本文件告诉 AI 工具（Claude Code / Codex / workbuddy 等任何 agent）在本工作区**怎么干活**。
> 术语、硬规则、岗位状态的**真值在 [`CONTEXT.md`](CONTEXT.md)**；本文件只管「分工、路由与红线」。
> 进入工作区先读 `CONTEXT.md`，再看本文件。

## 角色边界

- 干：寻源取数、初筛、收取与评估简历、建档、维护台账与候选人池、回填关键词迭代表、生成日报。
- **不干（对外不可逆动作，一律等用户确认）**：替用户在平台点「不合适」、主动发打招呼/消息
  （授权规则见 `skills/recruit-daily-51job/SKILL.md`）、约面试建日程通知候选人（见
  `skills/interview-schedule/SKILL.md`）、发 offer。

## 工作流路由

主流程：**init（一次）→ grill（每岗一次）→ daily-51job（每天循环）**。
匝道：寻了几轮发现标准跑偏 → 带台账数据回 grill 重梳理。

| 场景 | 读 |
|---|---|
| 每日招聘：查未读 / 主动寻源 / 初筛 / 打招呼 / 补台账 / 出日报（**51job 单通道**） | `skills/recruit-daily-51job/SKILL.md` |
| 新开岗位 / 重新梳理某岗真实要求 | `skills/recruit-grill/SKILL.md` |
| 本地简历评估 / 回查某人评级 | `skills/resume-review/SKILL.md` |
| 某岗深度市场盘点 | `skills/market-talent-mapping/SKILL.md` |
| 约面试 / 改期取消 | `skills/interview-schedule/SKILL.md` |
| 51job CLI 命令细节 | `skills/recruit-daily-51job/references/channels-51job.md` + `51job --help` |

## 会话卫生（跨会话记忆只有文件）

- **一天的招聘用一个新会话跑完**；别一个会话连跑多天。梳理岗位也是一岗一个会话。
- 简历原文、搜索结果 JSON 会快速堆满上下文。感觉变钝时：**先把台账和日报落盘，再开新会话接着干**。
  台账/日报/迭代表是唯一的跨会话记忆，没写进文件的判断等于丢失。
- 新会话开工第一件事永远是读 `CONTEXT.md` + 本文件。

## 规则优先级

- 初筛硬规则（年龄/学历/地点/薪资）**只以 `CONTEXT.md`「初筛硬规则」为准**，覆盖任何工作流文档
  或工具内置默认值。工作流文档不抄数字，发现有出入以 CONTEXT 为准并修正文档。
- 固定纪律：**绝不自动在平台点「不合适」**——先在台账标 `初筛不合适`/`已排除` 并记原因，等用户确认。

## 产物落点（本地为唯一事实源）

- **唯一事实源 = 本地文件**：`02-sourcing/dedup-ledger.csv`（全量候选人+状态）、
  `02-sourcing/candidate-pool.md`（shortlist 视图）、`03-interview/<姓名>.md`（面试档案）。
- 对外视图（飞书文档等）= **展示版**，从台账同步生成，不作为事实源。
- `runtime/reports/` 与临时日志可删可重建；`runtime/resumes/` 会被台账路径与跨轮去重引用，须保留。

## 每轮寻源后必做（关键词迭代闭环）

1. 新候选人按去重键（姓名+应聘岗位）append 进 `02-sourcing/dedup-ledger.csv`，定状态、记原因。
2. 进面试流程者建 `03-interview/<姓名>.md`（套 `_shared/templates/interview-record.md`）。
3. **寻源前先读** `CONTEXT.md` 的关键词迭代表；**跑完从「初筛通过/入选」的简历反向提取真实搜索词**
   回填该表（有效词 / 无效词 / 积极信号 / 拒绝模式）。