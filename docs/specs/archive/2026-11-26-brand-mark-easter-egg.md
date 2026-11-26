# Spec: 左上角品牌图标连击彩蛋（实况快门充能 & 脉冲）

- **日期**: 2026-11-26
- **状态**: Done（已归档）
- **设计门禁**: L1（纯动效与微交互，跳过 Figma，开发阶段通过真机与单元测试验证）
- **关联文档**: [architecture.md](../../architecture.md)、[design-system.md](../../design-system.md)

---

## 1. 目标与背景
在首页左上角 [HomeView.swift](../../../Motion2Live/HomeView.swift) 的 `Motion2LiveBrandMark`（双层液态玻璃叠卡 + Live Photo 同心圆环）上增加隐藏连击彩蛋：连续轻点 5 次触发“实况快门充能 & 首页卡片共振”交互，搭配逐级触感反馈，强化 Motion2Live「离线摄影暗房」的品牌质感，同时完全不干扰主流程与视觉排版。

## 2. 交互逻辑与状态机
1. **第 1～4 次点击（充能阶段）**：
   - `tapCount` 递增，重置 `0.85s` 连击超时任务（超时未继续点击则以 `.spring` 平滑归零）。
   - 触感反馈：第 1～2 次 `AppHaptics.lightImpact()`；第 3～4 次 `AppHaptics.mediumImpact()`。
   - 视觉反馈：前后叠卡错位弹开、虚线圆环顺时针旋转 `+72°`、底层 `AppTheme.accent` 柔光光晕逐级增强。
2. **第 5 次点击（彩蛋爆发）**：
   - 取消超时任务，置 `isCoolingDown = true`（`1.6s` 冷却），`tapCount = 0`。
   - 触感反馈：`AppHaptics.success()` 并在 `0.09s` 后追加 `AppHaptics.mediumImpact()` 二段回震。
   - 视觉反馈：
     - `Motion2LiveBrandMark` 释放双层青色脉冲波纹（`BrandPulseWaveOverlay`），叠卡执行 `360°` 优雅翻转；
     - 首页 `HeroPhotoDeckStage` 同步共振：3 张展示卡片扇形张开后弹性回落，背景双色光晕同步膨胀，背后释放两道光学冲击波环（`HeroDeckShockwaveRing`）。
   - 无障碍降级：系统开启 `accessibilityReduceMotion` 时跳过大幅旋转/扇形扩散，保留柔和的高亮脉冲与触感。
3. **生命周期复位**：`HomeView.onDisappear` 与 `HeroPhotoDeckStage.onDisappear` 均取消异步任务并复位瞬时状态。

## 3. 变更清单
- `Motion2Live/HomeView.swift`：实现 `Motion2LiveBrandMark` 连击充能、`BrandPulseWaveOverlay`、`HeroPhotoDeckStage` 爆发共振与 `HeroDeckShockwaveRing`（未新增文字弹窗/toast，全语言通用）。

## 4. 验证结果
- `xcodebuild ... -only-testing:Motion2LiveTests test`：`Motion2LiveTests`（38 tests）+ `ShareAttachmentLoaderTests`（6 tests）全部通过（44 passed, 0 failures）。
- 真机验证：已编译并刷入 iPhone 17（`Igloo`）验证动效与触感反馈。
