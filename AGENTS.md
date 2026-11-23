# Multi-Agent 协作维护规范 (Collaboration Guidelines)

本项目（Motion2Live）采用多个 Agent 应用与开发者共同协作维护模式。为保证多人/多 Agent 在异步及并发环境下的代码质量与工程一致性，所有参与维护的 Agent **必须严格遵守以下规则**：

---

### 1. 核心守则：操作前必校最新状态（Read Before Write）
- **绝不盲信历史记忆或上一轮上下文**：
  在分析、重构或修改任何文件前，**必须先读取该文件的磁盘最新内容**。因为在当前会话之外，其他 Agent 或用户可能已经对该文件提交了修改。
- **环境安全检查惯例**：
  由于工作区可能位于 OneDrive 等云盘同步目录，运行 Git 相关命令时请始终附加参数避免索引死锁：
  ```bash
  git -c core.preloadindex=false status -s
  ```

---

### 2. 增量修改原则（Targeted Edits over Full Overwrite）
- **禁止无条件全量覆盖**：
  进行代码或文档更新时，优先使用基于精确目标匹配的局部替换工具（Edit / Diff）。
- **冲突自愈流程**：
  若编辑时发现 `Target` 片段无法精确匹配，说明内容已被他人调整：
  1. 立即重新读取该文件最新切片；
  2. 比对他人引入的最新改动与自身意图；
  3. 执行类似 Git Rebase 的智能合入，严禁直接全量覆写覆盖他人劳动成果。

---

### 3. 云同步冲突感知与清理（OneDrive Artifacts）
- **识别冲突副本**：
  随时留意工作区中是否出现了带有机器名后缀的文件（例如 `*-MBFVFG71WHQ6LW.md`）。
- **处理方式**：
  发现此类冲突文件时，应比对冲突文件与主文件的差异，将有价值的修改合并至主文件，随后安全清理冲突副本，防止工程产生认知分叉。

---

### 4. 统一工程标准（Single Source of Truth）
- **主工程收敛**：
  当前工程核心已正式收敛至 **`Motion2Live`**（对应 Target `Motion2Live` 与 `Motion2Live.xcodeproj`）。
- **配置文件防损**：
  修改 `Motion2Live.xcodeproj/project.pbxproj` 时，务必保持 `PBXBuildFile`、`PBXFileReference`、`PBXGroup` 及 `PBXSourcesBuildPhase` 四个段落的映射严格一致，防止 Xcode 工程损坏。

---

### 5. 核心功能性能与健壮性准则
- **内存防爆（OOM Prevention）**：
  处理高分辨率图片和批量转换（Batch Conversion）时，严禁将全量原图同时解码进内存。缩略图必须使用 `CGImageSourceCreateThumbnailAtIndex` 低内存读取，批量导出任务需严格采用可控的串行处理流程。
- **临时文件生命周期管理**：
  所有解压、临时 MOV、MP4 及 GIF 文件必须在写入 `PHPhotoLibrary` 后立即清理，不可长期滞留在 `NSTemporaryDirectory`。
