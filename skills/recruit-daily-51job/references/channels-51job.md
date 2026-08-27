# 51job 通道命令与坑

命令细节的权威是 `51job --help` / `51job <cmd> --help`；本文件只放**编排流程实际用到的调用形态**和实测踩过的坑。
51job-cli 驱动本机真实 Chrome（**默认有头**，窗口弹出是正常现象，不是故障）。命令之间浏览器**跨命令常驻**，
登录态持久化在 `~/.51job-cli/.cache/`——**这是账号敏感数据，绝不读取/导出/转发**。

## 命令速查

| 目的 | 命令 | 说明 |
|---|---|---|
| 登录（一次性） | `51job login` → `51job wait-login` | 打开登录页立即返回；wait-login 轮询等扫码完成 |
| 查未读 | `51job list --unread --json` | 投递列表，`--unread` 只留未读；JSON 出 `[{index,name,time,unread,snippet,age,years,edu,city}]` |
| 看全部投递 | `51job list --json` | 不带 `--unread` 即全部投递卡 |
| 岗位槽位 | `51job positions --json` | 拿「岗位名」做后续 `--job` 匹配；含状态/待处理数 |
| 推荐池（**姓名不打码**） | `51job recommend <岗位> --json` | 人才望远镜推荐；输出每人带 `forJob` 字段；`[岗位]` 可切左侧岗位菜单 |
| 推荐池内打招呼 | `51job recommend <岗位> --greet <姓名或序号N>` | 推荐页不打码，可精确点名打 |
| 人才搜索（**姓名打码**） | `51job search "<关键词>" [13 维筛选] --json` | 输出 `name/job/company/meta/salary/age/exp/edu` |
| 逐个打招呼（先看再 Hi） | `51job greet <姓名> --job <岗> --dry-run` → 确认 → 再 `--no-confirm` | 默认 Y/N 确认；`--dry-run` 只看详情不 Hi；`--by-index N` 按序号定位 |
| 详情提取 | `51job inspect <姓名> --job <岗> --json` | 结构化：求职意向/技能明细/工作经历/教育经历；`--hi` 提取后顺手打 |
| 打开会话（人才管理页） | `51job chat <姓名> [--index N] [--strict]` | 同名用序号；聊天面板在「人才管理」页候选人行的「回复」按钮 |
| 发消息 | `51job send --text "话术"` | 先 `chat` 打开会话；真实鼠标点击发送 + 失败自动重试 |
| 会话操作 | `51job action resume\|unsuitable\|wechat\|phone\|interview\|note` | **unsuitable（不合适）默认二次确认**（拒绝/接受同理），`--no-confirm` 跳过 |
| 在线简历（**耗每日额度**） | `51job preview <姓名>` | 弹窗截图 + 百度 OCR 落盘 `~/.51job-cli/ocr/`；**别循环调用** |
| 抓 JD 缓存 | `51job jd <岗位名> [--cat] [--json]` | 缓存到 `~/.51job-cli/jd/<名>.md`；`--cat` 直接出正文 |
| 页面改版时 | `51job probe` | 输出选择器校准建议（存 `~/.51job-cli/probe/`） |
| 关浏览器 | `51job shutdown` | 登录态保留，下条命令自动重启仍登录 |

## 搜索 13 维筛选参数（`search` / `greet` 共用）

| 选项 | 取值示例 | 说明 |
|---|---|---|
| `--exp` | `3-5年` | 工作年限 |
| `--age` | `25-30岁` | 年龄 |
| `--gender` | `男/女` | 性别 |
| `--city` | `广州,深圳` | 期望工作地（页面禁用时自动跳过并提示） |
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

- **姓名打码**：`search` 结果是打码名（`张**`）。同岗多个同姓打码名 → 台账里加后缀区分
  （`张**(测绘)`）避免去重键碰撞。**推荐池（recommend）不打码**，适合精确点名。
- **序号只在同次调用内有效**：搜索结果/推荐列表每次调用会重排。跨调用要用 `51job greet <姓名>`
  + `--job <岗>` 定向，别靠上次序号。
- **`greet` 依赖 `--job` 补搜**：`greet` 打招呼要先在搜索池里定位到这个人——搜索关键词给得不准
  找不到，会失败。**先 `search <岗关键词>` 确认池内有人，再 `greet <姓名> --job <岗>`**。
- **`greet --dry-run` 免费先看**：只打开详情展示摘要、不实际 Hi、不耗每日额度。批量场景想
  「先看再 Hi」用它；确认后再去 `--dry-run` 跑真打。
- **`inspect` 详情开新 tab**：`greet`/`inspect` 会新开详情 tab（resumeId 页面），命令结束 tab 常驻，
  属正常；下次命令自动定位正确页面，不依赖残留 tab。
- **零卡兜底自动切回工作台**：`list` 读到 0 卡会自动回工作台首页重读，「自动切回」warn 是正常的。
- **跨进程互斥**：命令之间用 `~/.51job-cli/.cache/session.lock` 加锁。**绝不并发跑两个 51job 命令**。
- **有头是真窗口**：屏幕上蹦出 Chrome 是正常的，**别给 51job 开无头**（UA 自报 HeadlessChrome 与
  Client Hints 矛盾 = 自动化指纹，有封号风险）。`51JOB_BROWSER_HEADLESS=true` 绝对不要设。
- **`preview` 耗每日查看额度**：别循环。要看详情信息优先用 `51job inspect --json`，额度留给真正要
  逐字看的简历；OCR 需要百度凭证，失败不影响截图落盘。

## 安全红线（继承 51job-cli AGENTS.md，编排文档必须遵守）

1. **禁止无头**：`51JOB_BROWSER_HEADLESS=true` 会被风控识别，默认有头，勿改。
2. **对外不可逆动作默认需确认**：打招呼（greet 默认 Y/N）、`action unsuitable`（默认二次确认）。
   `--no-confirm` 仅在用户明确授权、目标被用户逐条确认过时用。
3. **风控熔断**：命中 403 / verify / security-check → 命令停止并输出熔断提示。**停手、报告用户、
   不自动重试、不刷新硬闯**。
4. **Hi 额度红线（2026-08-26 实测新增）**：Hi 聊天/电话各扣点数；点数不足时点「立即Hi聊」会弹
   「剩余额度不足，请联系管理员分配」模态框（需手动点关闭，CLI 已自动关闭并返回
   `hiResult: quota_exhausted` + 非零退出）。编排读到 `quota_exhausted` 或 `hiResult` 非 success：
   **立即停手，向用户报「Hi 额度不足，请分配后再跑」，绝不重试**。且 **greet 是否成功必须以命令
   返回结果为准**（「点了按钮就算成功」是误报——额度 0 时点了也发不出去）。
5. **写操作节流**：命令内置 800–2500ms 随机延迟；外层脚本别再叠高频。批量打招呼/发消息间隔 ≥3–5s。
6. **登录态与敏感数据**：`~/.51job-cli/.cache/` 的 cookie、`.env` 的百度 OCR 凭证不外读不转发。
7. **平台改版先校准**：选择器失效先 `probe` 校准，别自己写浏览器脚本硬闯。

## 浏览器 / 稳定性补充

- 51job 的 CDP 调试端口默认 9222（以 `51job doctor` 输出为准）。
- 常驻浏览器判断：`curl http://127.0.0.1:9222/json/version`，UA 含 `HeadlessChrome` 就是无头——
  **看到无头就 `51job shutdown` 重启成有头**。
- 反检测保护挂在 CLI 进程自己的 CDP session 上，进程退出即失效。**面板只读，别手动操作；别从
  第二个连接发重量级 CDP 域**（`Network.enable`/`Runtime.enable` 会把浏览器杀/拧死）。
- 关浏览器 `51job shutdown`（登录态保留）。
- 批跑别用管道过滤落文件（等 EOF 误判空/卡），前台给足超时或全量落盘再筛。