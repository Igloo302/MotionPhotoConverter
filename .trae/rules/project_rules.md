### **第零部分：文档管理**
1. 项目背景信息、技术架构等信息从根目录下的 readme 文件和 docs 文件夹查阅，用户发起指令后，有任何不理解的上下文情况，都需要去 docs 查阅。
2. 在完成一轮编程后，都需要根据修改情况，检查 readme 文件和 docs 文件夹并更新相关文档，尤其注意要对 todo 文件进行更新，以说明最新的进度。

-----

### **第一部分：通用编程规则 (General Programming Rules)**

1.  **代码风格与规范 (Code Style & Conventions):**

      * **严格遵循 Swift API 设计指南:** 优先使用 `Swift API Design Guidelines`。代码应清晰、简洁且易于理解。
      * **命名规范:**
          * 类、结构体、枚举、协议名使用大驼峰命名法 (UpperCamelCase)。
          * 变量、常量、函数名、参数名使用小驼峰命名法 (lowerCamelCase)。
          * 布尔类型的变量应以 `is`, `has`, `should` 等开头，例如 `isUserLoggedIn`。
      * **注释:** 对复杂的逻辑、算法或意图不明确的代码块添加必要的注释。使用 `// MARK: -` 来组织和分割代码块，提高可读性。
      * **代码简洁性:** 避免编写冗余代码。优先使用 Swift 的高级特性，如 `map`, `filter`, `reduce` 等高阶函数，但以不牺牲可读性为前提。

2.  **错误处理 (Error Handling):**

      * **优先使用 `try/catch`:** 始终优先使用 Swift 的 `do-try-catch` 机制来处理可恢复的错误。
      * **自定义错误类型:** 创建具体的、遵循 `Error` 协议的枚举（Enum）来定义不同类型的错误，而不是简单地返回 `nil` 或字符串。例如：
        ```swift
        enum NetworkError: Error {
            case invalidURL
            case requestFailed(statusCode: Int)
            case decodingFailed
        }
        ```
      * **避免强制解包:** 严禁使用感叹号 `!` 进行强制解包（Forced Unwrapping）。请使用 `if let`, `guard let` 或 `??` (Nil-Coalescing Operator) 来安全地处理可选类型。

3.  **并发处理 (Concurrency):**

      * **优先使用 `async/await`:** 对于所有异步操作（网络请求、数据库读写等），请优先使用 Swift 5.5+ 引入的 `async/await` 语法。
      * **主线程操作:** 所有更新 UI 的操作必须在主线程（Main Actor）上执行。请使用 `@MainActor` 或 `Task { @MainActor in ... }` 来确保线程安全。

-----

### **第二部分：iOS 特定开发规则 (iOS-Specific Development Rules)**

1.  **UI 开发 (UI Development):**

      * **[如果使用 SwiftUI]**
          * **视图拆分:** 保持 `View` 的结构体短小且功能单一。将复杂的视图拆分成更小的、可复用的子视图。
          * **状态管理:** 使用 `@State`, `@Binding`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` 等属性包装器来清晰地管理视图状态。将业务逻辑从视图中分离到 `ViewModel` 或 `ObservableObject` 中。
          * **预览功能:** 为所有自定义的 SwiftUI 视图提供有效的 `#Preview`，以便在 Xcode Previews 中进行快速预览和调试。
      * **[如果使用 UIKit]**
          * **代码布局:** 优先使用 Auto Layout 进行界面布局，建议通过代码（例如使用 `NSLayoutConstraint` 或 `SnapKit` 等库）而非 Storyboard/XIB 来创建约束，以便于代码审查和维护。
          * **视图控制器职责:** 保持 `UIViewController` 的职责单一。避免“Massive View Controller”问题，将数据请求、业务逻辑等分离到其他对象中。
          * **重用机制:** 正确使用 `UITableView` 和 `UICollectionView` 的 cell 重用机制。

2.  **架构与数据流 (Architecture & Data Flow):**

      * **遵循既定架构:** 严格遵守项目中定义的 `[例如：MVVM]` 架构。
          * **Model:** 只包含纯数据结构。
          * **View:** 只负责展示和用户交互，将所有事件传递给 ViewModel。
          * **ViewModel:** 包含视图的状态和业务逻辑，负责处理数据、响应用户操作并更新视图状态。**ViewModel 不应直接引用 View/UIViewController。**
      * **依赖注入 (Dependency Injection):**
          * 不要在类内部直接创建其依赖项（如网络服务、数据库服务等）。
          * 通过构造函数注入（Constructor Injection）或属性注入（Property Injection）的方式传入依赖，以提高模块的可测试性和可重用性。

3.  **网络请求 (Networking):**

      * **分层设计:** 创建一个独立的网络层（Networking Layer）。不要在 `ViewModel` 或 `ViewController` 中直接调用 `URLSession`。
      * **数据模型:** 使用遵循 `Codable` 协议的 Swift 结构体（Struct）来映射 JSON/API 响应。

4.  **项目文件结构 (Project File Structure):**

      * **按功能组织:** 项目文件和文件夹应按功能（Feature）进行组织，而不是按类型（例如，一个文件夹放所有 `ViewController`，另一个放所有 `View`）。
          * **示例结构:**
            ```
            /AppName
                /Features
                    /Login
                        /View
                        /ViewModel
                        /Model
                    /Profile
                        /View
                        /ViewModel
                        /Model
                /Core
                    /Networking
                    /Database
                    /Extensions
                /App
                    /AppDelegate.swift
                    /SceneDelegate.swift
            ```
