# 51job 通道命令与坑

命令细节的权威是 `51job --help` / `51job <cmd> --help`；本文件只放**编排流程实际用到的调用形态**和实测踩过的坑。
对齐 **51job-cli ≥ 0.1.1**。51job-cli 驱动本机真实 Chrome（**默认有头**，窗口弹出是正常现象，不是故障）。命令之间浏览器**跨命令常驻**，
登录态持久化在 `~/.51job-cli/.cache/`——**这是账号敏感数据，绝不读取/导出/转发**。

## 命令速查

| 目的 | 命令 | 说明 |
|---|---|---|
| 登录（一次性） | `51job login` → `51job wait-login` | 打开登录页立即返回；wait-login 轮询等扫码完成 |
| 环境自检 | `51job doctor` | Chrome / Node / 数据目录 / 有头模式；不验证登录 |
| 查未读 | `51job list --unread --json` | **工作台投递箱**全职位聚合流；序号与 `chat --index` 一致 |
| 看全部投递 | `51job list --json` | 不带 `--unread` 即全部投递卡 |
| 按职位拉候选人 | `51job positions --candidates <职位名> --json` | `--source auto\|delivery\|search`；`--scope my\|org`；search 默认首屏，`--all` 全量（易风控） |
| 岗位槽位 | `51job positions --json` | 职位目录（状态/待处理数）；按职位搜人用 `--position`，不是这里的名字当 `search --job` |
| 推荐池（**姓名不打码**） | `51job recommend <岗位> --json` | 人才望远镜；每人带 `forJob`；可 `--greet` / `--inspect` |
| 按职位搜索（推荐） | `51job search --position <职位名> --json` | 锁定该职位并注入城市/学历；**`search` 没有 `--job`** |
| 关键词搜索 | `51job search "<关键词>" --json` | 与 `--position` **互斥**；输出对象 `{keyword,count,hits,...}`，人在 **`.hits`** |
| 逐个打招呼（先看再 Hi） | `51job greet <姓名> --job <岗> --dry-run` → 确认 → 再 `--no-confirm` | `--job` 是 greet/inspect 的搜索兜底词，不是 search 的参数 |
| 搜索池详情 | `51job inspect <姓名> --job <岗> --json` | 搜索池来源；`--hi` = 立即Hi聊（**耗点数**） |
| 投递/聊天详情 | `51job talent-detail <姓名> --json` | 人才管理页来源；`--hi` = 免费「回复」 |
| 直链详情（推荐回访） | `51job inspect --resume-id <ID> --json` | 不经搜索、不受排序/虚拟列表影响；要 Hi 必须再带 `--job-id` |
| 打开会话 | `51job chat <姓名> [--index N] [--unread]` | 同名用序号；`--unread` 时序号与 `list --unread` 对齐 |
| 发消息 | `51job send --text "话术"` | 先 `chat`；失败**不要盲着重发**（可能已发出） |
| 会话操作 | `51job action resume\|unsuitable\|wechat\|phone\|interview\|note` | **unsuitable 默认二次确认**，`--no-confirm` 跳过 |
| 在线简历截图 | `51job preview <姓名>` | 耗每日查看额度；OCR 默认关，需 `51JOB_RESUME_OCR=1` 才上传云端 |
| 抓 JD 缓存 | `51job jd <岗位名> [--cat] [--json]` | 缓存到 `~/.51job-cli/jd/` |
| 清本地残留 | `51job clean [--dry-run]` | OCR 文本/截图/探针快照；先 `--dry-run` |
| 关浏览器 | `51job shutdown` | 登录态保留 |

## 语义别混（来源决定命令）

| 来源 | 列表 | 详情 | `--hi` |
|---|---|---|---|
| 投递箱 | `list` | `talent-detail` | 免费「回复」 |
| 按职位投递/扩充 | `positions --candidates` | 视 `source`：delivery → `talent-detail`；search → `inspect` | 同上 |
| 主动搜索 | `search` | `inspect` | 立即Hi聊，耗点数 |
| 望远镜 | `recommend` | `inspect` | 耗点数 |

已落台账的人**不要按姓名/序号再搜**，用 `--resume-id`。

## `search --json`（0.1.1 breaking）

stdout 是**对象**，不是数组：

```json
{ "keyword": "...", "count": 30, "hits": [ { "name", "job", "company", "resumeId", ... } ] }
```

`--position` 时另有 `position` / `positionScope` / `injected` / `fallback`。编排读 **`.hits`**，不要把整个对象当一个人。

默认只读首屏（约 30 人）。`--all` 会滚动全量，易触发风控，非必要不用。

## 搜索 13 维筛选参数（`search` / `greet` 共用）

| 选项 | 取值示例 | 说明 |
|---|---|---|
| `--exp` | `3-5年` | 工作年限 |
| `--age` | `25-30岁` | 年龄 |
| `--gender` | `男/女` | 性别 |
| `--city` | `广州,深圳` | 期望工作地（`--position` 常从职位卡注入；显式传入覆盖） |
| `--residence` | `广东省,广州市,天河区` | 居住地（省,市,区 级联） |
| `--edu` | `本科及以上` | 学历要求 |
| `--school` | `985,双一流` | 学校性质多选 |
| `--status` | `离职-周内到岗` | 求职状态 |
| `--industry` | `建筑/房地产` | 期望行业多选 |
| `--func` | `建筑/房地产` | 期望职能多选 |
| `--salary` | `8千,2万以上` | 期望月薪档位 |
| `--work-industry` | — | 从事行业多选 |
| `--work-func` | — | 从事职能多选 |

## 实测踩过的坑（51job 特有）

- **`search` 没有 `--job`**：`<关键词>` 与 `--position` 互斥，同传会 fail。按职位寻源用 `search --position <职位名>`。`greet`/`inspect` 的 `--job` 只是补搜关键词。
- **JSON 人在 `.hits`**：把 `search --json` 当数组解析会把对象当成一条候选人。
- **姓名打码**：`search` 结果是打码名（`张**`）。同岗多个同姓打码名不能当去重键。**推荐池不打码**。台账主键是 `resumeId`。
- **序号只在同次调用内有效**：列表虚拟滚动、排序会变。跨调用用 `resumeId` 直链，别靠上次序号，也别只靠打码名。
- **`greet` 依赖 `--job` 补搜**：没 `resumeId` 时才走这条；关键词不准会找不到。有 `resumeId` 用 `inspect --resume-id --job-id --hi`。
- **`greet --dry-run` 免费先看**：只出详情摘要、不 Hi。确认后再去掉 `--dry-run`。
- **直链 Hi 必须 `--job-id`**：只带 `--resume-id` 是纯查看；`--hi` 不带 `--job-id` 会报错/跳过。
- **已 Hi 过按钮变「继续聊」**：`--hi` 无效；先查台账 Hi 状态，改走 `chat` + `send`。
- **`inspect` 开新 tab**：详情 tab 常驻属正常。
- **零卡兜底自动切回工作台**：`list` 读到 0 卡会回首页重读，「自动切回」warn 正常。
- **跨进程互斥**：`~/.51job-cli/.cache/session.lock`。**绝不并发跑两个 51job 命令**。
- **有头是真窗口**：**别给 51job 开无头**。`51JOB_BROWSER_HEADLESS=true` 绝对不要设。
- **`preview` 耗每日查看额度**：别循环。详情优先 `inspect`/`talent-detail --json`。OCR 默认关闭。
- **exit 2 = 站点改版**：可用性门禁锁区。停招聘，不要自己写选择器硬闯；维护侧走 51job-cli 的 frontend-analysis。
- **登录窗口秒开秒关 / 反复停在登录页**（托管环境，2026-08-31 实测）：Claude Code Shell / WorkBuddy / Codex 等
  AI 工具环境常在**每条命令结束时回收该命令启动的所有子进程**（含 CLI 的 `detached: true` Chrome）。
  表现：`51job login` 窗口一闪即关；扫码成功后新窗口仍停在登录页（cookie 未落盘）。
  破解：**后台任务托住浏览器**——`51job login` 放进后台任务（run_in_background），命令末尾挂长循环
  （如 `while true; do sleep 60; done`）保持会话存活，扫码后等几秒让 cookie 写回
  `~/.51job-cli/.cache/`（约 300M+，登录态保存在这里）。之后 `51job shutdown` 或直接跑业务命令
  （如 `51job list --json`）都能**跨重启免扫码**复用登录态。注意：扫码成功 ≠ 持久化 —— 必须确认
  浏览器进程是**在后台任务保护下**完成了 cookie 落盘；普通前台命令结束即回收。
- **登录验证**：`51job wait-login --timeout 30` → 退出码 0 = 已登录；**只读试金石**用
  `51job list --json`，能读到投递候选人即登录态已固化。登录完成后日常跑 `recruit-daily-51job` 无需再登录。

## 安全红线（继承 51job-cli AGENTS.md，编排文档必须遵守）

1. **禁止无头**：`51JOB_BROWSER_HEADLESS=true` 会被风控识别，默认有头，勿改。
2. **对外不可逆动作默认需确认**：打招呼（greet 默认 Y/N）、`action unsuitable`（默认二次确认）。
   `--no-confirm` 仅在用户明确授权、目标被用户逐条确认过时用。
3. **风控熔断**：命中 403 / verify / security-check → 命令停止并输出熔断提示。**停手、报告用户、
   不自动重试、不刷新硬闯**。
4. **Hi 额度红线**：Hi 聊天/电话各扣点数；不足时返回 `hiResult: quota_exhausted` + 非零退出。
   读到 `quota_exhausted` 或 `hiResult` 非 success：**立即停手，绝不重试**。是否成功以命令结果为准，
   「点了按钮就算成功」是误报。
5. **写操作节流**：命令内置 800–2500ms 随机延迟；外层别再叠高频。批量间隔 ≥3–5s。
6. **`send` 失败不要盲着重发**：超时/`failed`/`unknown` 时消息可能已发出。记 unknown，查会话后再决定。
7. **登录态与敏感数据**：`~/.51job-cli/.cache/` 的 cookie、`.env` 凭证不外读不转发。
   百度密钥用 `51JOB_BAIDU_API_KEY` / `51JOB_BAIDU_SECRET_KEY`（不要用通用名 `API_KEY`）。
   OCR 默认关；`51JOB_RESUME_OCR=1` 才上传。项目目录 `./.env` 默认不加载（需 `51JOB_PROJECT_ENV=1`）。
8. **平台改版先停**：exit 2 或选择器失效 → 停手报告，先 `51job doctor` / 维护侧校准，别硬闯。

## 浏览器 / 稳定性补充

- 51job 的 CDP 调试端口以 `51job doctor` 输出为准。
- 常驻浏览器判断：`curl http://127.0.0.1:<port>/json/version`，UA 含 `HeadlessChrome` 就是无头——
  **看到无头就 `51job shutdown` 重启成有头**。
- 反检测保护挂在 CLI 进程自己的 CDP session 上，进程退出即失效。**不要从第二个连接发重量级 CDP 域**。
- 关浏览器 `51job shutdown`（登录态保留）。
- 批跑别用管道过滤落文件（等 EOF 误判空/卡），前台给足超时或全量落盘再筛。
