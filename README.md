# ReveFlex - 强大的 iOS 运行时调试与修补工具

<div align="center">

![ReveFlex Logo](https://img.shields.io/badge/ReveFlex-v0.1--1-blue?style=for-the-badge)
![iOS Support](https://img.shields.io/badge/iOS-13.0%2B-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Jailbroken%20iOS-orange?style=for-the-badge)
![License](https://img.shields.io/badge/License-Educational%20Use-red?style=for-the-badge)

**一个专为 iOS 开发者和逆向工程师打造的强大调试工具**

[English](#english) | [中文](#中文) | [安装指南](#安装指南) | [使用教程](#使用教程) | [API 文档](#api-文档)

</div>

---

## 中文

### 🚀 项目简介

ReveFlex 是一个革命性的 iOS 越狱插件，专为开发者、逆向工程师和安全研究人员设计。它将强大的运行时调试能力与直观的用户界面相结合，提供了前所未有的 iOS 应用程序分析和修改体验。

**核心价值：**
- 🔬 **深度分析**：实时查看和分析任何 iOS 应用的内部结构
- ⚡ **即时修改**：无需重新编译即可修改应用行为
- 🎯 **精确定位**：快速找到目标 UI 元素和方法
- 🛡️ **安全研究**：为安全测试和漏洞研究提供强大工具

### 🌟 核心功能详解

#### 🔍 UI 层次结构浏览器
ReveFlex 提供了业界最先进的 UI 调试功能，让您能够深入了解任何 iOS 应用的界面结构。

**主要特性：**
- **实时视图层次结构**
  - 完整的 UIView 树状结构显示
  - 支持 UIViewController 层次结构
  - 实时更新，反映当前界面状态
  - 支持复杂的嵌套视图结构

- **智能搜索系统**
  - 按类名搜索：`UILabel`, `UIButton`, `UIImageView` 等
  - 按属性搜索：文本内容、颜色、尺寸等
  - 正则表达式支持
  - 模糊匹配和精确匹配

- **详细属性查看器**
  - 视图几何信息：frame, bounds, center
  - 样式属性：backgroundColor, alpha, hidden
  - 约束信息：Auto Layout 约束详情
  - 层级关系：父视图、子视图、兄弟视图

- **代码溯源功能**
  - 追踪视图的创建调用栈
  - 识别视图的所有者 ViewController
  - 显示相关的 IBOutlet 连接
  - 定位 Storyboard 或 XIB 来源

#### 🛠️ 运行时方法修补引擎
ReveFlex 的核心功能之一是其强大的运行时方法修补系统，允许您在不修改应用源码的情况下改变其行为。

**技术实现：**
- **Method Swizzling**：基于 Objective-C Runtime 的方法替换
- **IMP 替换**：直接替换方法实现指针
- **动态代理**：支持复杂的方法调用拦截
- **类型安全**：自动处理不同返回类型的方法

**支持的数据类型：**
- 基础类型：`BOOL`, `int`, `float`, `double`
- 对象类型：`NSString`, `NSNumber`, `NSArray`, `NSDictionary`
- 结构体：`CGRect`, `CGPoint`, `CGSize`, `NSRange`
- 自定义对象：任何 Objective-C 对象

**补丁管理系统：**
- **按应用分组**：每个应用的补丁独立管理
- **批量操作**：支持批量启用/禁用补丁
- **导入导出**：JSON 格式的补丁配置文件
- **版本控制**：补丁配置的版本管理
- **冲突检测**：自动检测和解决补丁冲突

#### 🎯 高级调试工具集

**全局搜索引擎：**
- 跨应用搜索 UI 元素
- 支持多种搜索条件组合
- 实时搜索结果更新
- 搜索历史记录

**内存分析器：**
- 实时内存使用监控
- 对象分配追踪
- 内存泄漏检测
- 堆栈分析

**性能监控：**
- CPU 使用率监控
- 方法调用频率统计
- 渲染性能分析
- 网络请求监控

### 🏗️ 技术架构

#### 核心组件

**RFUIManager**
- 负责用户界面管理
- 处理浮动按钮和手势识别
- 管理调试界面的显示和隐藏
- 协调各个功能模块

**RFPatchingManager**
- 核心的方法修补引擎
- 管理所有活跃的补丁
- 处理方法调用的拦截和转发
- 提供补丁的持久化存储

**RFHierarchyViewController**
- UI 层次结构的可视化展示
- 处理用户的交互操作
- 提供搜索和过滤功能
- 集成详细信息查看器

**RFDraggableView**
- 可拖拽的浮动入口按钮
- 自动吸附到屏幕边缘
- 支持手势识别
- 最小化界面干扰

#### 技术特性

- **零侵入性设计**
  - 通过 MobileSubstrate 动态注入
  - 不修改目标应用的二进制文件
  - 支持系统应用和第三方应用
  - 可随时启用或禁用

- **高性能优化**
  - 异步处理避免界面卡顿
  - 智能缓存减少重复计算
  - 内存使用优化
  - 最小化对目标应用的性能影响

- **强大的兼容性**
  - 支持 iOS 13.0 - iOS 17.x
  - 兼容 arm64 和 arm64e 架构
  - 支持 rootless 越狱环境
  - 适配各种屏幕尺寸和分辨率

- **开发者友好**
  - 直观的用户界面设计
  - 丰富的调试信息展示
  - 详细的错误提示和日志
  - 完整的 API 文档

### 📋 安装指南

#### 系统要求
- **设备要求**：已越狱的 iPhone/iPad
- **系统版本**：iOS 13.0 或更高版本
- **架构支持**：arm64, arm64e
- **越狱环境**：支持 rootless 和传统越狱

#### 依赖框架
- **MobileSubstrate**：核心注入框架
- **Objective-C Runtime**：方法修补基础
- **UIKit**：用户界面框架

#### 安装步骤

**方法一：通过 Cydia/Sileo 安装**
1. 添加源：`https://your-repo.com/`
2. 搜索 "ReveFlex"
3. 点击安装并重启设备

**方法二：手动安装 .deb 包**
```bash
# 通过 SSH 连接到设备
ssh root@your-device-ip

# 安装 deb 包
dpkg -i ReveFlex.deb

# 重启 SpringBoard
killall SpringBoard
```

**方法三：开发者编译安装**
```bash
# 克隆项目
git clone https://github.com/your-username/ReveFlex.git
cd ReveFlex

# 使用 Theos 编译
make package install
```

### 🎮 使用教程

#### 快速开始

**1. 激活 ReveFlex**
- 安装完成后，打开任意应用
- 您会看到一个标有 "RF" 的半透明浮动按钮
- 按钮会自动吸附到屏幕边缘

**2. 基础操作**
- **单击**：打开/关闭 ReveFlex 主界面
- **拖拽**：移动浮动按钮位置
- **长按**：快速访问设置菜单

#### 详细功能使用

**UI 层次结构浏览**

1. **查看视图树**
   ```
   点击 RF 按钮 → 主界面 → 层次结构标签
   ```
   - 树状结构显示所有视图
   - 缩进表示层级关系
   - 点击展开/折叠子视图

2. **搜索特定视图**
   ```
   主界面 → 搜索框 → 输入关键词
   ```
   - 支持类名搜索：`UILabel`
   - 支持内容搜索：`登录按钮`
   - 支持属性搜索：`hidden:YES`

3. **查看视图详情**
   ```
   选择视图 → 详情按钮 → 属性列表
   ```
   - 几何信息：位置、大小、变换
   - 样式属性：颜色、透明度、圆角
   - 层级关系：父视图、子视图列表

**方法修补操作**

1. **创建新补丁**
   ```
   选择视图 → 方法列表 → 选择方法 → 添加补丁
   ```
   - 选择要修补的方法
   - 设置新的返回值
   - 选择数据类型
   - 确认应用补丁

2. **管理现有补丁**
   ```
   主界面 → 补丁管理 → 应用列表
   ```
   - 按应用查看所有补丁
   - 启用/禁用特定补丁
   - 删除不需要的补丁
   - 导出补丁配置

3. **批量操作**
   ```
   补丁管理 → 选择多个补丁 → 批量操作
   ```
   - 批量启用/禁用
   - 批量删除
   - 批量导出

#### 高级功能

**全局搜索**
```
主界面 → 全局搜索 → 输入搜索条件
```
- 跨所有视图搜索
- 支持正则表达式
- 实时搜索结果
- 搜索历史记录

**内存分析**
```
主界面 → 工具 → 内存分析器
```
- 查看内存使用情况
- 检测内存泄漏
- 分析对象分配
- 监控内存变化

**性能监控**
```
主界面 → 工具 → 性能监控
```
- CPU 使用率
- 方法调用统计
- 渲染性能
- 网络请求监控

#### 实用技巧

**1. 快速定位 UI 元素**
- 使用搜索功能而不是手动浏览
- 利用类名前缀快速过滤
- 结合内容搜索精确定位

**2. 高效的补丁管理**
- 为不同功能创建不同的补丁组
- 使用描述性的补丁名称
- 定期导出补丁配置作为备份

**3. 调试最佳实践**
- 在修改前先备份原始行为
- 逐步测试补丁效果
- 使用日志记录调试信息

### 🔧 配置选项

#### 全局设置

**界面设置**
- 浮动按钮透明度：0.3 - 1.0
- 主界面主题：浅色/深色/自动
- 字体大小：小/中/大
- 动画效果：开启/关闭

**功能设置**
- 自动保存补丁：开启/关闭
- 启动时加载补丁：开启/关闭
- 调试日志级别：关闭/错误/警告/信息/调试
- 性能监控：开启/关闭

**安全设置**
- 系统应用保护：开启/关闭
- 补丁确认对话框：开启/关闭
- 危险操作警告：开启/关闭
- 自动备份：开启/关闭

#### 应用特定设置

每个应用都可以有独立的设置：
- 补丁总开关
- 界面显示偏好
- 调试级别
- 自定义快捷键

### 📚 API 文档

#### RFUIManager API

**基础方法**
```objc
// 安装 ReveFlex 到指定窗口
+ (void)install;

// 显示主界面
+ (void)showExplorer;

// 隐藏主界面
+ (void)dismissExplorer;

// 显示全局搜索界面
+ (void)showGlobalSearchFromViewController:(UIViewController *)viewController;

// 设置手势识别器
+ (void)setupGestureRecognizer;

// 检查是否启用
+ (BOOL)isReveFlexEnabled;
```

#### RFPatchingManager API

**补丁管理**
```objc
// 获取共享实例
+ (instancetype)sharedManager;

// 应用方法补丁
- (BOOL)patchMethod:(Method)method
            ofClass:(Class)cls
          withValue:(id)value
              error:(NSError **)error;

// 移除方法补丁
- (void)unpatchMethod:(Method)method ofClass:(Class)cls;

// 检查方法是否已被修补
- (BOOL)isMethodPatched:(Method)method ofClass:(Class)cls;

// 获取补丁信息
- (RFPatchInfo *)patchInfoForMethod:(Method)method ofClass:(Class)cls;
```

**批量操作**
```objc
// 获取所有已修补的应用
- (NSArray<NSString *> *)allPatchedBundleIdentifiers;

// 获取指定应用的所有补丁
- (NSArray<RFPatchInfo *> *)patchesForBundleIdentifier:(NSString *)bundleIdentifier;

// 移除指定应用的所有补丁
- (void)unpatchAllMethodsForBundleIdentifier:(NSString *)bundleIdentifier;

// 设置应用补丁开关
- (void)setApplicationPatchesEnabled:(BOOL)enabled
                   forBundleIdentifier:(NSString *)bundleIdentifier;
```

**导入导出**
```objc
// 导出补丁到 JSON
- (NSString *)exportPatchesToJSON:(NSError **)error;

// 从 JSON 导入补丁
- (NSInteger)applyPatchesFromJSON:(NSString *)jsonString error:(NSError **)error;
```

#### RFPatchInfo 数据结构

```objc
@interface RFPatchInfo : NSObject
@property (nonatomic, copy) NSString *methodName;      // 方法名
@property (nonatomic, strong) id patchedValue;         // 补丁值
@property (nonatomic, copy) NSString *valueType;       // 值类型
@property (nonatomic, assign) Method method;           // 方法对象
@property (nonatomic, assign) Class targetClass;       // 目标类
@property (nonatomic, copy) NSString *bundleIdentifier; // 应用 ID
@property (nonatomic, assign) BOOL isClassMethod;      // 是否为类方法
@end
```

### 🛡️ 安全考虑

#### 权限管理
- ReveFlex 需要注入到目标应用进程
- 具有修改应用行为的能力
- 可以访问应用的内存空间
- 能够拦截和修改方法调用

#### 安全措施
- **沙盒隔离**：每个应用的补丁相互独立
- **权限检查**：对系统关键应用进行保护
- **操作确认**：危险操作需要用户确认
- **日志记录**：详细记录所有操作

#### 最佳实践
- 仅在测试环境中使用
- 定期备份重要数据
- 避免修改系统核心应用
- 谨慎处理敏感信息

### ⚠️ 免责声明

**重要提醒：请仔细阅读以下免责声明**

#### 使用目的限制
1. **教育研究用途**：本工具专为学习、研究、开发和安全测试目的而设计
2. **禁止非法使用**：严禁用于任何违法犯罪活动，包括但不限于：
   - 破解商业软件
   - 绕过安全机制
   - 窃取用户数据
   - 恶意攻击系统

#### 风险警告
3. **使用风险**：使用本工具可能导致以下后果，用户需自行承担所有风险：
   - 应用程序崩溃或异常
   - 数据丢失或损坏
   - 设备系统不稳定
   - 安全漏洞暴露
   - 违反应用使用条款

4. **技术风险**：
   - 方法修补可能导致不可预期的副作用
   - 内存操作可能引起系统崩溃
   - 不当使用可能损坏应用数据
   - 可能与其他插件产生冲突

#### 法律责任
5. **合规义务**：用户有完全责任确保使用本工具符合：
   - 当地法律法规
   - 应用程序使用条款
   - 设备制造商政策
   - 相关行业标准

6. **免责条款**：
   - 本软件按"现状"提供，不提供任何明示或暗示的担保
   - 开发者不对使用本工具造成的任何直接、间接、偶然、特殊或后果性损害承担责任
   - 包括但不限于利润损失、数据丢失、业务中断等

#### 商业使用限制
7. **非商业性质**：
   - 未经明确书面授权，禁止将本工具用于任何商业目的
   - 禁止基于本工具开发商业产品
   - 禁止将本工具集成到商业解决方案中

8. **知识产权**：
   - 尊重第三方应用的知识产权
   - 不得使用本工具侵犯他人专利、商标或版权
   - 遵守开源许可证条款

#### 用户确认
**使用本工具即表示您已：**
- 完全阅读并理解上述所有条款
- 同意承担使用本工具的所有风险和责任
- 承诺仅将本工具用于合法的教育和研究目的
- 理解并接受开发者的免责声明

**如果您不同意上述任何条款，请立即停止使用本工具。**

### 👨‍💻 开发者信息

#### 项目信息
- **项目名称**：ReveFlex
- **当前版本**：0.1-1
- **开发者**：MacXK
- **开发语言**：Objective-C, C
- **构建工具**：Theos, Xcode
- **许可证**：Educational Use License

#### 版本历史
- **v0.1-1** (当前版本)
  - 初始发布版本
  - 基础 UI 调试功能
  - 方法修补引擎
  - 补丁管理系统

#### 技术支持
- **问题反馈**：通过 GitHub Issues
- **功能建议**：通过 GitHub Discussions
- **安全问题**：请私下联系开发者
- **文档更新**：欢迎提交 PR

#### 贡献指南
我们欢迎社区贡献，包括但不限于：
- **代码贡献**：修复 bug、添加新功能
- **文档改进**：完善文档、添加示例
- **测试反馈**：报告兼容性问题
- **翻译工作**：支持更多语言

**贡献流程：**
1. Fork 项目仓库
2. 创建功能分支
3. 提交代码更改
4. 创建 Pull Request
5. 等待代码审查

#### 致谢
感谢以下项目和个人的贡献：
- **Theos**：提供构建框架
- **MobileSubstrate**：提供注入机制
- **iOS 开发社区**：提供技术支持
- **测试用户**：提供宝贵反馈

### 🔗 相关链接

- **项目主页**：[GitHub Repository](https://github.com/your-username/ReveFlex)
- **问题反馈**：[GitHub Issues](https://github.com/your-username/ReveFlex/issues)
- **讨论社区**：[GitHub Discussions](https://github.com/your-username/ReveFlex/discussions)
- **更新日志**：[CHANGELOG.md](CHANGELOG.md)
- **开发文档**：[Wiki](https://github.com/your-username/ReveFlex/wiki)

### 🎯 使用场景

#### 开发调试
- **UI 布局调试**：快速定位布局问题
- **属性验证**：确认视图属性设置
- **层次结构分析**：理解复杂的视图结构
- **性能优化**：识别性能瓶颈

#### 逆向工程
- **应用分析**：了解第三方应用结构
- **功能研究**：分析特定功能实现
- **安全测试**：发现潜在安全问题
- **兼容性测试**：验证不同版本兼容性

#### 学习研究
- **iOS 开发学习**：理解系统应用实现
- **UI 设计研究**：学习优秀的界面设计
- **技术探索**：探索新的技术实现
- **最佳实践**：学习行业最佳实践

### 🚨 常见问题

#### 安装问题

**Q: 安装后没有看到浮动按钮？**
A: 请检查以下几点：
- 确认设备已正确越狱
- 重启 SpringBoard：`killall SpringBoard`
- 检查 MobileSubstrate 是否正常工作
- 查看系统日志是否有错误信息

**Q: 在某些应用中无法使用？**
A: 可能的原因：
- 应用有反调试保护
- 应用使用了特殊的安全机制
- 系统应用可能需要特殊权限
- 尝试在设置中启用"系统应用支持"

#### 使用问题

**Q: 补丁不生效？**
A: 请检查：
- 确认补丁已正确应用
- 检查方法签名是否正确
- 验证返回值类型是否匹配
- 查看是否有其他插件冲突

**Q: 应用崩溃怎么办？**
A: 建议操作：
- 立即禁用相关补丁
- 重启应用
- 检查崩溃日志
- 报告问题给开发者

#### 兼容性问题

**Q: 支持最新的 iOS 版本吗？**
A: ReveFlex 会持续更新以支持新的 iOS 版本，请关注项目更新。

**Q: 与其他插件冲突？**
A: 如果遇到冲突，请：
- 尝试禁用其他调试类插件
- 检查是否有相同功能的插件
- 联系开发者寻求解决方案

---

## English

### 🚀 Project Overview

ReveFlex is a revolutionary iOS jailbreak tweak designed for developers, reverse engineers, and security researchers. It combines powerful runtime debugging capabilities with an intuitive user interface, providing an unprecedented iOS application analysis and modification experience.

**Core Values:**
- 🔬 **Deep Analysis**: Real-time viewing and analysis of any iOS application's internal structure
- ⚡ **Instant Modification**: Modify application behavior without recompilation
- 🎯 **Precise Targeting**: Quickly locate target UI elements and methods
- 🛡️ **Security Research**: Powerful tools for security testing and vulnerability research

### 🌟 Detailed Core Features

#### 🔍 UI Hierarchy Browser
ReveFlex provides the industry's most advanced UI debugging capabilities, allowing you to deeply understand the interface structure of any iOS application.

**Key Features:**
- **Real-time View Hierarchy**
  - Complete UIView tree structure display
  - Support for UIViewController hierarchy
  - Real-time updates reflecting current interface state
  - Support for complex nested view structures

- **Smart Search System**
  - Search by class name: `UILabel`, `UIButton`, `UIImageView`, etc.
  - Search by properties: text content, colors, dimensions, etc.
  - Regular expression support
  - Fuzzy matching and exact matching

- **Detailed Property Viewer**
  - View geometry: frame, bounds, center
  - Style properties: backgroundColor, alpha, hidden
  - Constraint information: Auto Layout constraint details
  - Hierarchical relationships: parent views, child views, sibling views

- **Code Tracing Functionality**
  - Track view creation call stack
  - Identify view owner ViewController
  - Display related IBOutlet connections
  - Locate Storyboard or XIB sources

#### 🛠️ Runtime Method Patching Engine
One of ReveFlex's core features is its powerful runtime method patching system, allowing you to change application behavior without modifying source code.

**Technical Implementation:**
- **Method Swizzling**: Objective-C Runtime-based method replacement
- **IMP Replacement**: Direct replacement of method implementation pointers
- **Dynamic Proxy**: Support for complex method call interception
- **Type Safety**: Automatic handling of methods with different return types

**Supported Data Types:**
- Basic types: `BOOL`, `int`, `float`, `double`
- Object types: `NSString`, `NSNumber`, `NSArray`, `NSDictionary`
- Structures: `CGRect`, `CGPoint`, `CGSize`, `NSRange`
- Custom objects: Any Objective-C object

**Patch Management System:**
- **Application Grouping**: Independent patch management for each application
- **Batch Operations**: Support for batch enable/disable patches
- **Import/Export**: JSON format patch configuration files
- **Version Control**: Version management of patch configurations
- **Conflict Detection**: Automatic detection and resolution of patch conflicts

#### 🎯 Advanced Debugging Toolkit

**Global Search Engine:**
- Cross-application UI element search
- Support for multiple search criteria combinations
- Real-time search result updates
- Search history records

**Memory Analyzer:**
- Real-time memory usage monitoring
- Object allocation tracking
- Memory leak detection
- Stack analysis

**Performance Monitor:**
- CPU usage monitoring
- Method call frequency statistics
- Rendering performance analysis
- Network request monitoring

### 🏗️ Technical Architecture

#### Core Components

**RFUIManager**
- Responsible for user interface management
- Handles floating button and gesture recognition
- Manages debug interface display and hiding
- Coordinates various functional modules

**RFPatchingManager**
- Core method patching engine
- Manages all active patches
- Handles method call interception and forwarding
- Provides persistent storage for patches

**RFHierarchyViewController**
- Visual display of UI hierarchy
- Handles user interactions
- Provides search and filtering functionality
- Integrates detailed information viewer

**RFDraggableView**
- Draggable floating entry button
- Automatic edge snapping
- Gesture recognition support
- Minimal interface interference

#### Technical Features

- **Zero Intrusion Design**
  - Dynamic injection via MobileSubstrate
  - No modification of target application binaries
  - Support for system and third-party applications
  - Can be enabled or disabled at any time

- **High Performance Optimization**
  - Asynchronous processing to avoid UI lag
  - Smart caching to reduce redundant calculations
  - Memory usage optimization
  - Minimal performance impact on target applications

- **Strong Compatibility**
  - Support for iOS 13.0 - iOS 17.x
  - Compatible with arm64 and arm64e architectures
  - Support for rootless jailbreak environments
  - Adaptation to various screen sizes and resolutions

- **Developer Friendly**
  - Intuitive user interface design
  - Rich debugging information display
  - Detailed error messages and logging
  - Complete API documentation

### 📋 Installation Guide

#### System Requirements
- **Device Requirements**: Jailbroken iPhone/iPad
- **System Version**: iOS 13.0 or higher
- **Architecture Support**: arm64, arm64e
- **Jailbreak Environment**: Support for rootless and traditional jailbreak

#### Dependencies
- **MobileSubstrate**: Core injection framework
- **Objective-C Runtime**: Method patching foundation
- **UIKit**: User interface framework

#### Installation Steps

**Method 1: Install via Cydia/Sileo**
1. Add source: `https://your-repo.com/`
2. Search for "ReveFlex"
3. Tap install and restart device

**Method 2: Manual .deb Package Installation**
```bash
# Connect to device via SSH
ssh root@your-device-ip

# Install deb package
dpkg -i ReveFlex.deb

# Restart SpringBoard
killall SpringBoard
```

**Method 3: Developer Compilation**
```bash
# Clone project
git clone https://github.com/your-username/ReveFlex.git
cd ReveFlex

# Compile with Theos
make package install
```

### 🎮 Usage Tutorial

#### Quick Start

**1. Activate ReveFlex**
- After installation, open any application
- You'll see a semi-transparent floating button labeled "RF"
- The button automatically snaps to screen edges

**2. Basic Operations**
- **Single tap**: Open/close ReveFlex main interface
- **Drag**: Move floating button position
- **Long press**: Quick access to settings menu

#### Detailed Feature Usage

**UI Hierarchy Browsing**

1. **View Tree Structure**
   ```
   Tap RF button → Main interface → Hierarchy tab
   ```
   - Tree structure displays all views
   - Indentation indicates hierarchy levels
   - Tap to expand/collapse child views

2. **Search Specific Views**
   ```
   Main interface → Search box → Enter keywords
   ```
   - Support class name search: `UILabel`
   - Support content search: `Login Button`
   - Support property search: `hidden:YES`

3. **View Details**
   ```
   Select view → Details button → Property list
   ```
   - Geometry info: position, size, transform
   - Style properties: color, opacity, corner radius
   - Hierarchy: parent view, child view list

**Method Patching Operations**

1. **Create New Patch**
   ```
   Select view → Method list → Select method → Add patch
   ```
   - Choose method to patch
   - Set new return value
   - Select data type
   - Confirm patch application

2. **Manage Existing Patches**
   ```
   Main interface → Patch management → Application list
   ```
   - View all patches by application
   - Enable/disable specific patches
   - Delete unnecessary patches
   - Export patch configurations

3. **Batch Operations**
   ```
   Patch management → Select multiple patches → Batch operations
   ```
   - Batch enable/disable
   - Batch delete
   - Batch export

#### Advanced Features

**Global Search**
```
Main interface → Global search → Enter search criteria
```
- Search across all views
- Regular expression support
- Real-time search results
- Search history

**Memory Analysis**
```
Main interface → Tools → Memory analyzer
```
- View memory usage
- Detect memory leaks
- Analyze object allocation
- Monitor memory changes

**Performance Monitoring**
```
Main interface → Tools → Performance monitor
```
- CPU usage
- Method call statistics
- Rendering performance
- Network request monitoring

### 🔧 Configuration Options

#### Global Settings

**Interface Settings**
- Floating button opacity: 0.3 - 1.0
- Main interface theme: Light/Dark/Auto
- Font size: Small/Medium/Large
- Animation effects: On/Off

**Feature Settings**
- Auto-save patches: On/Off
- Load patches on startup: On/Off
- Debug log level: Off/Error/Warning/Info/Debug
- Performance monitoring: On/Off

**Security Settings**
- System app protection: On/Off
- Patch confirmation dialogs: On/Off
- Dangerous operation warnings: On/Off
- Auto backup: On/Off

#### Application-Specific Settings

Each application can have independent settings:
- Patch master switch
- Interface display preferences
- Debug level
- Custom shortcuts

### 🛡️ Security Considerations

#### Permission Management
- ReveFlex needs to inject into target application processes
- Has the ability to modify application behavior
- Can access application memory space
- Capable of intercepting and modifying method calls

#### Security Measures
- **Sandbox Isolation**: Patches for each application are independent
- **Permission Checks**: Protection for system critical applications
- **Operation Confirmation**: Dangerous operations require user confirmation
- **Logging**: Detailed logging of all operations

#### Best Practices
- Use only in testing environments
- Regularly backup important data
- Avoid modifying system core applications
- Handle sensitive information carefully

### ⚠️ Disclaimer

**Important Notice: Please read the following disclaimer carefully**

#### Usage Purpose Limitations
1. **Educational Research Use**: This tool is designed for learning, research, development, and security testing purposes
2. **Prohibited Illegal Use**: Strictly prohibited for any illegal criminal activities, including but not limited to:
   - Cracking commercial software
   - Bypassing security mechanisms
   - Stealing user data
   - Malicious system attacks

#### Risk Warnings
3. **Usage Risks**: Using this tool may result in the following consequences, users assume all risks:
   - Application crashes or exceptions
   - Data loss or corruption
   - Device system instability
   - Security vulnerability exposure
   - Violation of application terms of use

4. **Technical Risks**:
   - Method patching may cause unpredictable side effects
   - Memory operations may cause system crashes
   - Improper use may damage application data
   - May conflict with other plugins

#### Legal Responsibilities
5. **Compliance Obligations**: Users have full responsibility to ensure use of this tool complies with:
   - Local laws and regulations
   - Application terms of use
   - Device manufacturer policies
   - Relevant industry standards

6. **Disclaimer Clauses**:
   - This software is provided "as is" without any express or implied warranties
   - Developers are not liable for any direct, indirect, incidental, special, or consequential damages caused by using this tool
   - Including but not limited to profit loss, data loss, business interruption, etc.

#### Commercial Use Restrictions
7. **Non-commercial Nature**:
   - Without explicit written authorization, commercial use of this tool is prohibited
   - Prohibited from developing commercial products based on this tool
   - Prohibited from integrating this tool into commercial solutions

8. **Intellectual Property**:
   - Respect third-party application intellectual property
   - Do not use this tool to infringe others' patents, trademarks, or copyrights
   - Comply with open source license terms

#### User Confirmation
**By using this tool, you acknowledge that you have:**
- Fully read and understood all the above terms
- Agreed to assume all risks and responsibilities of using this tool
- Committed to using this tool only for legal educational and research purposes
- Understood and accepted the developer's disclaimer

**If you do not agree with any of the above terms, please stop using this tool immediately.**

### 👨‍💻 Developer Information

#### Project Information
- **Project Name**: ReveFlex
- **Current Version**: 0.1-1
- **Developer**: MacXK
- **Development Language**: Objective-C, C
- **Build Tools**: Theos, Xcode
- **License**: Educational Use License

#### Version History
- **v0.1-1** (Current Version)
  - Initial release version
  - Basic UI debugging functionality
  - Method patching engine
  - Patch management system

#### Technical Support
- **Issue Reporting**: Via GitHub Issues
- **Feature Suggestions**: Via GitHub Discussions
- **Security Issues**: Please contact developer privately
- **Documentation Updates**: PRs welcome

#### Contribution Guidelines
We welcome community contributions, including but not limited to:
- **Code Contributions**: Bug fixes, new features
- **Documentation Improvements**: Enhance documentation, add examples
- **Testing Feedback**: Report compatibility issues
- **Translation Work**: Support for more languages

**Contribution Process:**
1. Fork project repository
2. Create feature branch
3. Submit code changes
4. Create Pull Request
5. Wait for code review

#### Acknowledgments
Thanks to the following projects and individuals for their contributions:
- **Theos**: Providing build framework
- **MobileSubstrate**: Providing injection mechanism
- **iOS Development Community**: Providing technical support
- **Beta Testers**: Providing valuable feedback

### 🔗 Related Links

- **Project Homepage**: [GitHub Repository](https://github.com/your-username/ReveFlex)
- **Issue Reporting**: [GitHub Issues](https://github.com/your-username/ReveFlex/issues)
- **Discussion Community**: [GitHub Discussions](https://github.com/your-username/ReveFlex/discussions)
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)
- **Development Documentation**: [Wiki](https://github.com/your-username/ReveFlex/wiki)

### 📱 Screenshots

#### Main Interface
![Main Interface](screenshots/main-interface-en.png)
*ReveFlex main interface showing clear UI hierarchy*

#### Search Feature
![Search Feature](screenshots/search-feature-en.png)
*Powerful search functionality for quick element location*

#### Patch Management
![Patch Management](screenshots/patch-management-en.png)
*Intuitive patch management interface*

#### Detail View
![Detail View](screenshots/detail-view-en.png)
*Rich view property information*

### 🎯 Use Cases

#### Development Debugging
- **UI Layout Debugging**: Quickly locate layout issues
- **Property Verification**: Confirm view property settings
- **Hierarchy Analysis**: Understand complex view structures
- **Performance Optimization**: Identify performance bottlenecks

#### Reverse Engineering
- **Application Analysis**: Understand third-party application structure
- **Feature Research**: Analyze specific feature implementations
- **Security Testing**: Discover potential security issues
- **Compatibility Testing**: Verify compatibility across versions

#### Learning and Research
- **iOS Development Learning**: Understand system application implementations
- **UI Design Research**: Learn excellent interface designs
- **Technical Exploration**: Explore new technical implementations
- **Best Practices**: Learn industry best practices

### 🚨 FAQ

#### Installation Issues

**Q: Don't see the floating button after installation?**
A: Please check the following:
- Confirm device is properly jailbroken
- Restart SpringBoard: `killall SpringBoard`
- Check if MobileSubstrate is working properly
- Check system logs for error messages

**Q: Cannot use in certain applications?**
A: Possible reasons:
- Application has anti-debugging protection
- Application uses special security mechanisms
- System applications may require special permissions
- Try enabling "System App Support" in settings

#### Usage Issues

**Q: Patches not taking effect?**
A: Please check:
- Confirm patch is correctly applied
- Check if method signature is correct
- Verify return value type matches
- Check for conflicts with other plugins

**Q: What to do if application crashes?**
A: Recommended actions:
- Immediately disable related patches
- Restart application
- Check crash logs
- Report issue to developer

#### Compatibility Issues

**Q: Does it support the latest iOS version?**
A: ReveFlex will continuously update to support new iOS versions, please follow project updates.

**Q: Conflicts with other plugins?**
A: If conflicts occur, please:
- Try disabling other debugging plugins
- Check for plugins with similar functionality
- Contact developer for solutions

---

<div align="center">

**ReveFlex - Empowering iOS Development and Research**

Made with ❤️ by MacXK

[⬆ Back to Top](#reveflex---强大的-ios-运行时调试与修补工具)

</div>
