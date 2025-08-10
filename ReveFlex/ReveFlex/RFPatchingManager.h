#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

// 通知名称常量
extern NSString * const RFPatchingManagerDidUpdatePatchesNotification;

// 新增：定义补丁类型
typedef NS_ENUM(NSInteger, RFPatchType) {
    RFPatchTypeReturnValue,  // 修改返回值
    RFPatchTypeArguments     // 修改参数 (终极Hook)
};

@interface RFPatchInfo : NSObject

// 补丁类型
@property (nonatomic, assign) RFPatchType patchType;

// 方法的原始实现 (IMP)
@property (nonatomic, assign) IMP originalIMP;

// 新增：用于参数修改，存放原始的 Method 对象
@property (nonatomic, assign) Method originalMethod;

// 新增：用于参数修改，存放原始IMP的别名Selector
@property (nonatomic, copy) NSString *aliasSelectorName;

// --- 用于 RFPatchTypeReturnValue ---
// 方法被修改后需要返回的新值
@property (nonatomic, strong, nullable) id patchedValue;

// --- 用于 RFPatchTypeArguments ---
// 参数补丁，格式: @{ @(参数索引): 新值, ... }
// 参数索引从 0 开始 (对应方法的第一个参数)
@property (nonatomic, strong, nullable) NSDictionary<NSNumber *, id> *argumentPatches;


// 方法返回值的类型编码 (例如，BOOL 类型的 "B")
@property (nonatomic, strong) NSString *returnTypeEncoding;

// 被修补的方法
@property (nonatomic, assign) Method method;

// 被修补的类
@property (nonatomic, assign) Class targetClass;

// 新增：补丁所属的应用Bundle ID
@property (nonatomic, copy) NSString *bundleIdentifier;

// 新增：明确记录是否为类方法
@property (nonatomic, assign) BOOL isClassMethod;

@end


@interface RFPatchingManager : NSObject

+ (instancetype)sharedManager;

/**
 将方法调用转发到原始实现
 @param invocation 方法调用对象
 */
- (void)forwardInvocation:(NSInvocation *)invocation;

/**
 将方法调用转发到原始实现，并指定原始IMP
 @param invocation 方法调用对象
 @param originalIMP 原始的方法实现
 */
- (void)forwardInvocation:(NSInvocation *)invocation originalIMP:(IMP)originalIMP;

/**
 对一个方法应用返回值补丁
 @param method 要修补的方法
 @param cls 方法所属的类
 @param value 要返回的新值
 @return 如果补丁成功应用则返回 YES
 */
- (BOOL)patchMethodReturnValue:(Method)method ofClass:(Class)cls withValue:(id)value;

/**
 对带参数的方法应用通用补丁
 这个方法可以处理带有参数的方法
 @param selector 要修补的方法选择器
 @param cls 方法所属的类
 @param isClassMethod 是否是类方法
 @param value 要返回的新值
 @return 如果补丁成功应用则返回 YES
 */
- (BOOL)patchMethodWithSelector:(SEL)selector ofClass:(Class)cls isClassMethod:(BOOL)isClassMethod returnValue:(id)value;

/**
 对一个方法的参数应用补丁
 @param method 要修补的方法
 @param cls 方法所属的类
 @param argumentIndex 要修改的参数索引 (从0开始)
 @param value 新的参数值
 @return 如果补丁成功应用则返回 YES
 */
- (BOOL)patchMethodArgument:(Method)method ofClass:(Class)cls argumentIndex:(NSUInteger)argumentIndex withValue:(id)value;

/**
 移除一个方法的补丁，恢复其原始行为
 @param method 要移除补丁的方法
 @param cls 方法所属的类
 */
- (void)unpatchMethod:(Method)method ofClass:(Class)cls;

/**
 检查一个方法当前是否已被修补
 @param method 要检查的方法
 @param cls 方法所属的类
 @return 如果方法已被修补则返回 YES
 */
- (BOOL)isMethodPatched:(Method)method ofClass:(Class)cls;

/**
 获取指定方法的补丁信息
 @param method 要查询的方法
 @param cls 方法所属的类
 @return 如果已修补，则返回 RFPatchInfo 对象，否则返回 nil
 */
- (nullable RFPatchInfo *)patchInfoForMethod:(Method)method ofClass:(Class)cls;

/**
 此方法旨在从我们自定义的 IMP 中调用，以获取要返回的值
 它被设为公共的以便桩函数调用，但不应被应用的其他部分直接调用
 */
- (nullable id)patchedValueForObject:(id)object selector:(SEL)selector;

#pragma mark - 新的补丁管理API (按App分组)

/**
 获取所有已应用补丁的应用的Bundle ID列表
 @return 一个按字母顺序排序的Bundle ID字符串数组
 */
- (NSArray<NSString *> *)allPatchedBundleIdentifiers;

/**
 获取指定Bundle ID下所有补丁的方法key
 @param bundleIdentifier 目标应用的Bundle ID
 @return 一个方法key的数组
 */
- (NSArray<NSString *> *)allPatchedMethodKeysForBundleIdentifier:(NSString *)bundleIdentifier;

/**
 移除一个方法的补丁
 @param key 方法的唯一key
 @param bundleIdentifier 补丁所属应用的Bundle ID
 */
- (void)unpatchMethodWithKey:(NSString *)key forBundleIdentifier:(NSString *)bundleIdentifier;

/**
 获取补丁信息
 @param key 方法的唯一key
 @param bundleIdentifier 补丁所属应用的Bundle ID
 @return 对应的RFPatchInfo对象，如果不存在则为nil
 */
- (nullable RFPatchInfo *)patchInfoForKey:(NSString *)key forBundleIdentifier:(NSString *)bundleIdentifier;

/**
 * @brief 获取指定类的指定方法的补丁信息。
 * @param selector 要查询的方法的选择器。
 * @param cls 方法所属的类。
 * @return 如果已修补，则返回 RFPatchInfo 对象，否则返回 nil。
 */
- (nullable RFPatchInfo *)patchInfoForSelector:(SEL)selector ofClass:(Class)cls;

/**
 检查指定应用的补丁总开关是否开启
 @param bundleIdentifier 目标应用的Bundle ID
 @return 如果开启则为YES
 */
- (BOOL)isApplicationPatchesEnabled:(NSString *)bundleIdentifier;

/**
 设置指定应用的补丁总开关
 @param enabled 是否开启
 @param bundleIdentifier 目标应用的Bundle ID
 */
- (void)setApplicationPatchesEnabled:(BOOL)enabled forBundleIdentifier:(NSString *)bundleIdentifier;

/**
 移除所有已应用的方法补丁
 */
- (void)unpatchAllMethods;

/**
 获取应用的显示名称
 @param bundleIdentifier 目标应用的Bundle ID
 @return 应用的显示名称，如果获取失败则返回Bundle ID本身
 */
- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier;


#pragma mark - 序列化/反序列化 (内部使用)

/**
 导出所有当前应用的补丁到一个 JSON 字符串。
 @param error 如果导出过程中发生错误，会通过此参数返回。
 @return 一个包含所有补丁信息的 JSON 字符串，如果无补丁或发生错误则返回 nil。
 */
- (nullable NSString *)exportPatchesToJSON:(NSError **)error;

/**
 从一个 JSON 字符串加载并应用补丁集。
 @param jsonString 包含补丁信息的 JSON 字符串。
 @param error 如果加载或应用过程中发生错误，会通过此参数返回。
 @return 成功应用的补丁数量。
 */
- (NSInteger)applyPatchesFromJSON:(NSString *)jsonString error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END 