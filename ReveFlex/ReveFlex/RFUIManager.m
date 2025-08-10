#import "RFUIManager.h"
#import "RFHierarchyViewController.h"
#import "RFViewNode.h"
#import "RFDetailViewController.h"
#import "RFSearchResultsViewController.h"
#import "RFDraggableView.h"
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

// 定义用户默认值的键名
static NSString * const kReveFlexEnabledKey = @"ReveFlexEnabled";

// 移除原子操作相关头文件，使用dispatch_queue_t来确保线程安全

#pragma mark - Helper Functions

// Function to get the ASLR slide of the main executable
static vm_address_t get_aslr_slide() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i)->filetype == MH_EXECUTE) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

// 递归查找最顶层的视图控制器
static UIViewController* findTopmostViewController(UIViewController *controller) {
    if (controller.presentedViewController) {
        return findTopmostViewController(controller.presentedViewController);
    }
    if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)controller;
        if (tabController.selectedViewController) {
            return findTopmostViewController(tabController.selectedViewController);
        }
    }
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController *)controller;
        if (navController.visibleViewController) {
            return findTopmostViewController(navController.visibleViewController);
        }
    }
    return controller;
}

// 构建视图层级的递归函数
static void buildHierarchy(UIView *view, NSString *prefix, NSMutableArray<RFViewNode *> *nodes) {
    [view.subviews enumerateObjectsUsingBlock:^(UIView * _Nonnull subview, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL isLast = (idx == view.subviews.count - 1);
        
        RFViewNode *node = [[RFViewNode alloc] init];
        node.view = subview;
        
        NSString *nodePrefix = [NSString stringWithFormat:@"%@%@", prefix, isLast ? @"└── " : @"├── "];
        node.displayString = [NSString stringWithFormat:@"%@<%@: %p>", nodePrefix, [subview class], subview];
        [nodes addObject:node];
        
        NSString *childPrefix = [NSString stringWithFormat:@"%@%@", prefix, isLast ? @"    " : @"│   "];
        buildHierarchy(subview, childPrefix, nodes);
    }];
}

#pragma mark - RFUIManager Implementation

@interface RFUIManager ()
@property (nonatomic, strong) RFDraggableView *entryBubble;
@property (nonatomic, strong, nullable) UIWindow *hostWindow;
@property (nonatomic, assign, getter=isShowing) BOOL showing;
@end

@implementation RFUIManager

+ (instancetype)sharedManager {
    static RFUIManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)install {
    // Ensure this runs on the main thread after the app has launched.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in (UIApplication.sharedApplication.connectedScenes)) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    keyWindow = scene.windows.firstObject;
                    break;
                }
            }
        } else {
            keyWindow = UIApplication.sharedApplication.keyWindow;
        }

        if (keyWindow) {
            [[self sharedManager] setupWithWindow:keyWindow];
        }
    });
}

- (void)setupWithWindow:(UIWindow *)window {
    if (self.entryBubble) {
        return; // Already installed
    }
    self.hostWindow = window;
    self.entryBubble = [[RFDraggableView alloc] initWithWindow:window];
    
    __weak typeof(self) weakSelf = self;
    self.entryBubble.tapHandler = ^{
        if (weakSelf.isShowing) {
            [RFUIManager dismissExplorer];
        } else {
            [RFUIManager showExplorer];
        }
    };
}

+ (void)showExplorer {
    RFUIManager *manager = [self sharedManager];
    if (manager.isShowing || !manager.hostWindow) {
        return;
    }
    manager.showing = YES;
    
    // Build the hierarchy at the moment it's shown
    UIViewController *topViewController = findTopmostViewController(manager.hostWindow.rootViewController);
    UIView *rootView = topViewController.view;
    NSMutableArray<RFViewNode *> *nodes = [NSMutableArray array];
    RFViewNode *rootNode = [[RFViewNode alloc] init];
    rootNode.view = rootView;
    rootNode.displayString = [NSString stringWithFormat:@"<%@: %p> (当前视图)", [rootView class], rootView];
    [nodes addObject:rootNode];
    buildHierarchy(rootView, @"", nodes);
    
    RFHierarchyViewController *hierarchyVC = [[RFHierarchyViewController alloc] init];
    hierarchyVC.viewNodes = nodes;
    
    UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:hierarchyVC];
    navVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    
    [topViewController presentViewController:navVC animated:YES completion:nil];
}

+ (void)dismissExplorer {
    RFUIManager *manager = [self sharedManager];
    if (!manager.isShowing || !manager.hostWindow) {
        return;
    }
    
    UIViewController *topViewController = findTopmostViewController(manager.hostWindow.rootViewController);
    [topViewController dismissViewControllerAnimated:YES completion:^{
        manager.showing = NO;
    }];
}

+ (void)showGlobalSearchFromViewController:(UIViewController *)viewController {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"全局搜索" 
                                                                   message:@"请输入要搜索的类名或方法名" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"输入类名或方法名";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"搜索" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *searchText = alert.textFields.firstObject.text;
        if (searchText.length > 0) {
            [self performGlobalSearch:searchText fromViewController:viewController];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [viewController presentViewController:alert animated:YES completion:nil];
}

+ (void)performGlobalSearch:(NSString *)searchText fromViewController:(UIViewController *)viewController {
    // 创建进度提示
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在搜索..." 
                                                                          message:@"正在搜索所有已加载的类和方法，请稍候..." 
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [viewController presentViewController:progressAlert animated:YES completion:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSDictionary *> *results = [NSMutableArray array];
        NSString *lowercaseSearchText = [searchText lowercaseString];
        
        // 获取所有已加载的类
        unsigned int classCount;
        Class *classList = objc_copyClassList(&classCount);
        
        // 用于跟踪搜索进度
        __block int processedClasses = 0;
        __block int totalClasses = (int)classCount;
        
        // 创建串行队列用于更新进度
        dispatch_queue_t progressQueue = dispatch_queue_create("com.macxk.reveflex.progress", DISPATCH_QUEUE_SERIAL);
#if !OS_OBJECT_USE_OBJC
dispatch_retain(progressQueue);
#endif
        
        // 更新进度的函数
        void (^updateProgress)(void) = ^{
            float progress = (float)processedClasses / totalClasses;
            dispatch_async(dispatch_get_main_queue(), ^{
                progressAlert.message = [NSString stringWithFormat:@"已搜索 %d/%d 个类 (%.1f%%)", 
                                processedClasses, totalClasses, progress * 100];
            });
        };
        
        // 创建分块处理的队列和组
        dispatch_queue_t searchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_group_t searchGroup = dispatch_group_create();
        
        // 分块大小
        int chunkSize = 100;
        int numChunks = (classCount + chunkSize - 1) / chunkSize;
        
        // 用于线程安全地添加结果
        NSLock *resultsLock = [[NSLock alloc] init];
        
        // 处理每个分块
        for (int chunk = 0; chunk < numChunks; chunk++) {
            int startIdx = chunk * chunkSize;
            int endIdx = MIN(startIdx + chunkSize, classCount);
            
            dispatch_group_async(searchGroup, searchQueue, ^{
                NSMutableArray *chunkResults = [NSMutableArray array];
                
                for (int i = startIdx; i < endIdx; i++) {
                    @autoreleasepool {
                        Class cls = classList[i];
                        NSString *className = NSStringFromClass(cls);
                        
                        // 检查类名是否匹配
                        if ([className.lowercaseString containsString:lowercaseSearchText]) {
                            [chunkResults addObject:@{
                                @"type": @"class",
                                @"name": className,
                                @"detail": @"类"
                            }];
                        }
                        
                        // 检查类方法
                        unsigned int classMethodCount;
                        Method *classMethodList = class_copyMethodList(object_getClass(cls), &classMethodCount);
                        
                        for (unsigned int j = 0; j < classMethodCount; j++) {
                            Method method = classMethodList[j];
                            SEL selector = method_getName(method);
                            NSString *methodName = NSStringFromSelector(selector);
                            
                            // 常规搜索
                            if ([methodName.lowercaseString containsString:lowercaseSearchText]) {
                                [chunkResults addObject:@{
                                    @"type": @"method",
                                    @"name": methodName,
                                    @"class": className,
                                    @"detail": [NSString stringWithFormat:@"%@ +%@", className, methodName]
                                }];
                            }
                        }
                        free(classMethodList);
                        
                        // 检查实例方法
                        unsigned int instanceMethodCount;
                        Method *instanceMethodList = class_copyMethodList(cls, &instanceMethodCount);
                        
                        for (unsigned int j = 0; j < instanceMethodCount; j++) {
                            Method method = instanceMethodList[j];
                            SEL selector = method_getName(method);
                            NSString *methodName = NSStringFromSelector(selector);
                            
                            // 常规搜索
                            if ([methodName.lowercaseString containsString:lowercaseSearchText]) {
                                [chunkResults addObject:@{
                                    @"type": @"method",
                                    @"name": methodName,
                                    @"class": className,
                                    @"detail": [NSString stringWithFormat:@"%@ -%@", className, methodName]
                                }];
                            }
                        }
                        free(instanceMethodList);
                        
                        // 检查属性
                        unsigned int propertyCount;
                        objc_property_t *propertyList = class_copyPropertyList(cls, &propertyCount);
                        
                        for (unsigned int j = 0; j < propertyCount; j++) {
                            objc_property_t property = propertyList[j];
                            const char *propertyName = property_getName(property);
                            NSString *propName = [NSString stringWithUTF8String:propertyName];
                            
                            // 常规搜索
                            if ([propName.lowercaseString containsString:lowercaseSearchText]) {
                                [chunkResults addObject:@{
                                    @"type": @"property",
                                    @"name": propName,
                                    @"class": className,
                                    @"detail": [NSString stringWithFormat:@"%@ (属性 %@)", className, propName]
                                }];
                            }
                        }
                        free(propertyList);
                    }
                    
                    // 更新进度
                    dispatch_async(progressQueue, ^{
                        processedClasses++;
                        if (processedClasses % 50 == 0) {
                            updateProgress();
                        }
                    });
                }
                
                // 将结果添加到主结果数组
                [resultsLock lock];
                [results addObjectsFromArray:chunkResults];
                [resultsLock unlock];
            });
        }
        
        // 等待所有搜索完成
        dispatch_group_wait(searchGroup, DISPATCH_TIME_FOREVER);
        free(classList);
        
        // 对结果进行排序和限制
        NSArray *sortedResults = [self sortAndLimitResults:results forSearchText:searchText isVipSearch:NO];
        
        // 在主线程显示结果
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                if (sortedResults.count > 0) {
                    NSString *title = [NSString stringWithFormat:@"搜索结果 (%lu)", (unsigned long)sortedResults.count];
                    
                    // 使用新的、独立的视图控制器来显示结果
                    RFSearchResultsViewController *resultsVC = [[RFSearchResultsViewController alloc] initWithResults:sortedResults title:title];
                    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:resultsVC];
                    navController.modalPresentationStyle = UIModalPresentationFormSheet;
                    [viewController presentViewController:navController animated:YES completion:nil];
                    
                } else {
                    UIAlertController *noResultsAlert = [UIAlertController alertControllerWithTitle:@"没有找到结果" 
                                                                                          message:[NSString stringWithFormat:@"没有找到包含 '%@' 的类、方法或属性", searchText] 
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                    [noResultsAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
                    [viewController presentViewController:noResultsAlert animated:YES completion:nil];
                }
            }];
        });
#if !OS_OBJECT_USE_OBJC
dispatch_release(progressQueue);
#endif
    });
}

// 对结果进行排序和限制
+ (NSArray *)sortAndLimitResults:(NSArray *)results forSearchText:(NSString *)searchText isVipSearch:(BOOL)isVipSearch {
    // searchText 参数在此方法中实际没有被使用
    
    // 对结果进行排序
    NSArray *sortedResults = [results sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        // 优先级1：精确匹配的结果排在前面
        BOOL isExactMatch1 = [obj1[@"detail"] containsString:@"精确匹配"];
        BOOL isExactMatch2 = [obj2[@"detail"] containsString:@"精确匹配"];
        
        if (isExactMatch1 && !isExactMatch2) {
            return NSOrderedAscending;
        } else if (!isExactMatch1 && isExactMatch2) {
            return NSOrderedDescending;
        }
        
        // 优先级2：类型排序（类 > 方法 > 属性 > 协议）
        NSArray *typeOrder = @[@"class", @"method", @"property", @"protocol"];
        NSInteger typeIndex1 = [typeOrder indexOfObject:obj1[@"type"]];
        NSInteger typeIndex2 = [typeOrder indexOfObject:obj2[@"type"]];
        
        if (typeIndex1 != typeIndex2) {
            return typeIndex1 < typeIndex2 ? NSOrderedAscending : NSOrderedDescending;
        }
        
        // 优先级3：按名称排序
        NSString *name1 = [obj1[@"name"] lowercaseString];
        NSString *name2 = [obj2[@"name"] lowercaseString];
        
        // 对于VIP搜索，包含"vip"的名称排在前面
        if (isVipSearch) {
            BOOL containsVip1 = [name1 containsString:@"vip"];
            BOOL containsVip2 = [name2 containsString:@"vip"];
            
            if (containsVip1 && !containsVip2) {
                return NSOrderedAscending;
            } else if (!containsVip1 && containsVip2) {
                return NSOrderedDescending;
            }
            
            // 对于同样包含"vip"的名称，"isVip"方法排在前面
            BOOL isIsVip1 = [name1 isEqualToString:@"isvip"];
            BOOL isIsVip2 = [name2 isEqualToString:@"isvip"];
            
            if (isIsVip1 && !isIsVip2) {
                return NSOrderedAscending;
            } else if (!isIsVip1 && isIsVip2) {
                return NSOrderedDescending;
            }
        }
        
        // 默认按字母顺序排序
        return [name1 compare:name2];
    }];
    
    // 限制结果数量（避免显示太多结果导致性能问题）
    NSInteger maxResults = isVipSearch ? 1000 : 500; // VIP搜索允许更多结果
    
    if (sortedResults.count > maxResults) {
        sortedResults = [sortedResults subarrayWithRange:NSMakeRange(0, maxResults)];
    }
    
    return sortedResults;
}

+ (void)toggleVisibility {
    if ([self sharedManager].isShowing) {
        [self dismissExplorer];
    } else {
        [self showExplorer];
    }
}

+ (void)setupGestureRecognizer {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in (UIApplication.sharedApplication.connectedScenes)) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    keyWindow = scene.windows.firstObject;
                    break;
                }
            }
        } else {
            keyWindow = UIApplication.sharedApplication.keyWindow;
        }

        if (keyWindow) {
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleVisibility)];
            tapGesture.numberOfTouchesRequired = 3;
            tapGesture.numberOfTapsRequired = 1;
            [keyWindow addGestureRecognizer:tapGesture];
        }
    });
}

+ (BOOL)isReveFlexEnabled {
    // 默认为启用
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kReveFlexEnabledKey] == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kReveFlexEnabledKey];
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:kReveFlexEnabledKey];
}

+ (void)handleSettingsChange:(NSNotification *)notification {
    if (![self isReveFlexEnabled]) {
        [self dismissExplorer];
    } else {
        // If the user re-enables it, they may need to manually re-show the window
        // or we could automatically show it. For now, we'll just log it.
        NSLog(@"[ReveFlex] has been re-enabled. You may need to re-trigger the show mechanism.");
    }
}

@end 
