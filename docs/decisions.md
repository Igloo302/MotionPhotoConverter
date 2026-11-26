# Architecture Decision Records (ADR)

本文件记录 Motion2Live 的关键架构与工程决策。新功能规划前需与 `docs/architecture.md` 一并查阅。

---

## ADR-000: 记录模板（示例）

- **日期**: 2026-11-25
- **状态**: Accepted
- **背景 (Context)**: 描述触发该决策的问题背景、约束条件与业务需求。
- **决策 (Decision)**: 明确选定的技术方案、边界范围与接口约定。
- **权衡与影响 (Consequences)**: 记录收益、潜在风险、受影响模块以及未来可逆性。

---

## ADR-001: 多品牌 Motion Photo 采用工厂模式与共享 Probe 上下文

- **日期**: 2026-11-25
- **状态**: Accepted
- **背景 (Context)**: 小米、Pixel、三星、华为、OPPO、vivo 等厂商动态照片在 XMP 标签、EXIF 厂商字段与二进制 MP4 偏移（如三星 SEF 尾部标记）上存在差异，若各处理器重复扫描大文件二进制流会导致性能退化与误判（例如 Pixel v1 字段被其他处理器抢占）。
- **决策 (Decision)**: 在 `Motion2Live/Models/MotionPhotoProcessor.swift` 中引入 `MotionPhotoProbeContext` 惰性缓存单次解析的 EXIF Make/Model、MP4 `ftyp` 偏移与 SEF 标记；`MotionPhotoProcessorFactory` 按「专用品牌处理器 -> `UniversalMotionPhotoProcessor` 兜底」顺序匹配，并强制校验 `ftyp` 签名。
- **权衡与影响 (Consequences)**: 新增品牌只需实现 `BaseMotionPhotoProcessor` 子类并在工厂列表注册即可，避免全文件重复扫描；需通过 `Motion2LiveTests` 回归多品牌样图防止优先级冲突。
