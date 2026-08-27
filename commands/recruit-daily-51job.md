---
description: 处理今天的 51job 招聘：查未读、寻源、初筛、打招呼、补台账、出日报
---

读取并严格执行 `${CLAUDE_PLUGIN_ROOT}/skills/recruit-daily-51job/SKILL.md` 的流程，对 $ARGUMENTS 指定的岗位（未指定则按 CONTEXT 中的优先级）处理 51job 单通道招聘。先读工作区 CONTEXT.md 和 AGENTS.md；对外不可逆动作（打招呼、点不合适）遵守该文档的安全规则。BOSS/猎聘请使用 `/recruit-daily`。
