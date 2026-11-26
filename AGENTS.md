# AGENTS.md — Motion2Live 工程宪章

## 1. 优先级与流程路由
- **优先级**：人类当前指令 > 安全与数据红线（一票否决） > 子目录 `AGENTS.md` > 根目录 `AGENTS.md`。
- **Fast-Track 直通车**：满足「单文件修改 + 预计改动 < 30 行 + 不涉及公共接口/数据结构变更」时，跳过 Superpowers 规划与 Worktree，原地修改并跑通验证。
- **Superpowers 标准流程**：其余中大型功能默认遵循 `Brainstorm -> Plan -> Worktree -> Subagent Build & Review -> Finish`；大规模检索与静态分析优先派发只读 Subagent 保护主上下文。

## 2. 项目安全红线（一票否决）
- **媒体与隐私数据安全**：解析多品牌 Motion Photo / EXIF / XMP / ISOBMFF 流及 `samples/local/` 时强制只读解析并校验 `ftyp` 签名与字节边界，严禁回写源资源；清理仅限 `NSTemporaryDirectory`（经 `MediaExportService.removeIfInTemporaryDirectory` 守卫）；`RecentConversionStore` 仅缓存 `Caches/RecentConversions/` 缩略图；纯离线零网络请求，变更 `UserDefaults`、文件时间戳或相册权限时须同步核对 `Motion2Live/PrivacyInfo.xcprivacy` 与 `Info.plist`。
- **隔离与防撞车**：严禁在 `main` 分支直接开发大功能；并行多任务必须使用独立 Git Worktree，测试必须使用独立 `temporaryDirectory`、`RecentConversionStore(directory:)` 与 Simulator 沙盒。
- **凭证与路径脱敏**：严禁硬编码本地绝对路径（含用户名 `/Users/...`）、API Key、Token、`.asc/` 签名信息或隐私数据。

## 3. 文档与记忆约定（覆盖 Skill 默认路径）
- 规划前必读 `docs/architecture.md`、`docs/decisions.md` 与 `docs/design-system.md`。
- 所有任务计划统一落盘至 `docs/specs/<YYYY-MM-DD>-<task-slug>.md`。
- 合并 `main` 后必须将 Spec 移入 `docs/specs/archive/`；除人类明确要求考古外，严禁检索或读取 `archive/`。
- 开发分支（Worktree）内严禁顺手修改 `docs/architecture.md` 与 `docs/design-system.md`，仅在合并收尾时询问是否更新。

## 4. 审查纪律与异常熔断
- **Reviewer Subagent 防包庇**：调用只读 Reviewer Subagent 时，仅允许传入当前 Spec 与 `git diff`（严禁传入主会话对话历史）；Builder 最终汇报时必须原样贴出 Reviewer 的 P0/P1 缺陷清单，P0 未清零严禁宣告完工。
- **禁止静默偏离**：发现 Spec 局部细节偏差时，先暂停并给出建议，待人类确认后先更新 Spec 再改代码。
- **硬熔断阈值**：若底层架构/数据流走不通，或同一报错连续尝试修复 3 次无解，立即停手，将现场（已完成进度、已排除的错误路径、阻塞文件与报错）写入当前 Spec 的 `## Handoff Notes`，并输出下一会话的启动提示词。
- **完工底线**：遵循奥卡姆原则，严禁删改原有测试强行通过；最终回复首行直接给出明确状态结论（适配移动端单行预览）。

## 5. 流程防呆与下一步引导 (Next-Step Auto-Guide)
每次阶段交付末尾附带 `### 下一步操作`：
- **Plan 完成**：给出新 Builder 会话启动词，提供双轨选项——**「建 Worktree」**（Agent 自动执行 `make wt name=<slug>` 并输出路径与启动词，用户开新会话粘贴开干）或 **「自动开干」**。
- **「自动开干」协议**：主会话转为纯调度器（禁改业务代码），自动 `make wt` -> 派发 Builder（仅传 Spec 与 Worktree 路径）编码与测试 -> 派发只读 Reviewer（仅传 Spec 与 `git diff`）盲审；有 P0 则修复复审（最多 2 轮，超限熔断），清零后提示冒烟测试。
- **Build & Review 完成**：提示在当前 Worktree 启动应用冒烟测试；涉及底层架构、Schema 或安全红线时，建议换模型开新会话交叉盲审。
- **Finish 完成**：给出 `make clean-wt name=<slug>`，提醒归档 Spec、通知其他 Worktree `rebase main`，并询问是否更新 `docs/architecture.md`。

## 6. 设计门禁路由 (Design Gate)
- 在 `Plan` 阶段评估 UI/交互复杂度，按需触发设计环节：
  - **L0 / L1（免设计或纯动效/微交互）**：跳过 Figma，直接在 Spec 中描述交互逻辑，开发阶段通过 Preview/热更新验证。
  - **L2（新页面/复杂布局/多形态适配）**：先输出线框与交互状态清单，待人类在独立 Figma 会话中确认视觉稿后，**必须将最终 Figma Frame 链接/Node ID 及四态（Loading/Empty/Error/边界）回填至 `docs/specs/<task>.md`**，再触发“手动挡”或“自动开干”。
- 涉及 UI 设计或编码时，优先对齐 `docs/design-system.md` 中的 Token 与现有组件，严禁随意硬编码新样式。

## 7. 目录与快捷入口导航
- 架构真相源：[docs/architecture.md](docs/architecture.md)
- 设计系统规范：[docs/design-system.md](docs/design-system.md)
- 架构决策记录：[docs/decisions.md](docs/decisions.md)
- 活跃设计规格：[docs/specs/](docs/specs/)（归档：`docs/specs/archive/`）
- 流程命令入口：`/plan`（启动规划与 Spec 落盘）、`/handoff`（状态落盘与跨会话交接）
