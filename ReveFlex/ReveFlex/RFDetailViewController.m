#import "RFDetailViewController.h"
#import "RFUIManager.h"
#import "RFPatchingManager.h"
#import "RFUtility.h"
#import "RFPatchDetailViewController.h"
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <WebKit/WebKit.h>
#import "RFHeapScanViewController.h"

#pragma mark - RFDetailViewController Implementation

@interface RFDetailViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, assign) Class targetClass;
@property (nonatomic, weak, nullable) id targetObject;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSValue *> *properties;
@property (nonatomic, strong) NSArray<NSValue *> *classMethods;
@property (nonatomic, strong) NSArray<NSValue *> *instanceMethods;
@property (nonatomic, strong) NSMutableSet<NSIndexPath *> *selectedMethodPaths;

// For local filtering state
@property (nonatomic, strong) NSString *filterText;
@property (nonatomic, assign) BOOL isFiltering;
@property (nonatomic, strong) NSArray<NSValue *> *filteredProperties;
@property (nonatomic, strong) NSArray<NSValue *> *filteredClassMethods;
@property (nonatomic, strong) NSArray<NSValue *> *filteredInstanceMethods;

// C-style arrays for holding method lists, to be freed in dealloc
@property (nonatomic, assign) Method *classMethodList;
@property (nonatomic, assign) Method *instanceMethodList;
@end

@interface RFDetailViewController ()
- (void)showInvokeMethodAlertForMethod:(Method)method;
- (void)invokeMethod:(Method)method withParameters:(NSArray *)parameters;
- (void)copyBreakpointCommandForMethod:(Method)method;
- (void)showHookCodeGeneratorForMethod:(Method)method isClassMethod:(BOOL)isClassMethod;
- (void)generateLogosHookForMethod:(Method)method isClassMethod:(BOOL)isClassMethod;
- (void)generateFridaHookForMethod:(Method)method isClassMethod:(BOOL)isClassMethod;
- (void)showSwizzleInterfaceForMethod:(Method)method isClassMethod:(BOOL)isClassMethod;
- (void)performMethodSwizzlingWithOriginalMethod:(Method)originalMethod 
                                   isClassMethod:(BOOL)isClassMethod 
                                 targetClassName:(NSString *)targetClassName 
                                targetMethodName:(NSString *)targetMethodName;
- (void)generateBinarySignatureForMethod:(Method)method;
- (void)showCodePreview:(NSString *)code withTitle:(NSString *)title;
@end

@implementation RFDetailViewController

- (void)dealloc {
    // Free the method lists we manually copied
    free(self.classMethodList);
    free(self.instanceMethodList);
}

- (instancetype)initWithClass:(Class)targetClass object:(nullable id)targetObject {
    self = [super init];
    if (self) {
        _targetClass = targetClass;
        _targetObject = targetObject;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSStringFromClass(self.targetClass);
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.selectedMethodPaths = [NSMutableSet set];
    self.isFiltering = NO;

    [self setupNormalNavItems];
    [self loadClassDetails];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44.0;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.view addSubview:self.tableView];
    
    // 添加长按手势
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 1.0;
    [self.tableView addGestureRecognizer:longPress];
    
    // 不再支持高亮显示特定项
}

- (void)setupNormalNavItems {
    self.navigationItem.hidesBackButton = NO;
    UIBarButtonItem *hookButton;
    if (@available(iOS 13.0, *)) {
        hookButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"hammer"] style:UIBarButtonItemStylePlain target:self action:@selector(toggleHookMode)];
    } else {
        hookButton = [[UIBarButtonItem alloc] initWithTitle:@"Hook" style:UIBarButtonItemStylePlain target:self action:@selector(toggleHookMode)];
    }
    
    UIBarButtonItem *exportButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(exportHeader)];
    
    UIBarButtonItem *searchButton;
    if (@available(iOS 13.0, *)) {
        searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"] style:UIBarButtonItemStylePlain target:self action:@selector(showSearchOptions)];
    } else {
        searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(showSearchOptions)];
    }
    
    self.navigationItem.rightBarButtonItems = @[exportButton, hookButton, searchButton];
}

- (void)setupHookingNavItems {
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleDone target:self action:@selector(toggleHookMode)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"生成Hook" style:UIBarButtonItemStyleDone target:self action:@selector(generateHookFile)];
}

- (void)loadClassDetails {
    // Properties
    unsigned int propCount;
    objc_property_t *propList = class_copyPropertyList(self.targetClass, &propCount);
    NSMutableArray *properties = [NSMutableArray array];
    for (unsigned int i = 0; i < propCount; i++) {
        [properties addObject:[NSValue valueWithPointer:propList[i]]];
    }
    free(propList);
    self.properties = [properties sortedArrayUsingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
        const char *name1 = property_getName([obj1 pointerValue]);
        const char *name2 = property_getName([obj2 pointerValue]);
        return [[NSString stringWithUTF8String:name1] compare:[NSString stringWithUTF8String:name2]];
    }];

    // Instance Methods
    unsigned int instMethodCount;
    self.instanceMethodList = class_copyMethodList(self.targetClass, &instMethodCount);
    NSMutableArray *instanceMethods = [NSMutableArray array];
    for (unsigned int i = 0; i < instMethodCount; i++) {
        [instanceMethods addObject:[NSValue valueWithPointer:self.instanceMethodList[i]]];
    }
    // Do NOT free the list here, it's freed in dealloc
    self.instanceMethods = [instanceMethods sortedArrayUsingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
        Method m1 = [obj1 pointerValue];
        Method m2 = [obj2 pointerValue];
        return [NSStringFromSelector(method_getName(m1)) compare:NSStringFromSelector(method_getName(m2))];
    }];
    
    // Class Methods
    unsigned int classMethodCount;
    Class metaClass = object_getClass(self.targetClass);
    self.classMethodList = class_copyMethodList(metaClass, &classMethodCount);
    NSMutableArray *classMethods = [NSMutableArray array];
    for (unsigned int i = 0; i < classMethodCount; i++) {
        [classMethods addObject:[NSValue valueWithPointer:self.classMethodList[i]]];
    }
    // Do NOT free the list here, it's freed in dealloc
    self.classMethods = [classMethods sortedArrayUsingComparator:^NSComparisonResult(NSValue *obj1, NSValue *obj2) {
        Method m1 = [obj1 pointerValue];
        Method m2 = [obj2 pointerValue];
        return [NSStringFromSelector(method_getName(m1)) compare:NSStringFromSelector(method_getName(m2))];
    }];
}

#pragma mark - Actions

- (void)toggleHookMode {
    BOOL isEditing = !self.tableView.isEditing;
    [self.tableView setEditing:isEditing animated:YES];
    
    if (isEditing) {
        [self setupHookingNavItems];
    } else {
        [self setupNormalNavItems];
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.hidesBackButton = NO;
        [self.selectedMethodPaths removeAllObjects];
    }
}

- (void)generateHookFile {
    if (self.selectedMethodPaths.count == 0) {
        // Optionally show an alert here
        [self toggleHookMode];
        return;
    }
    
    NSMutableString *logosString = [NSMutableString string];
    [logosString appendFormat:@"// 由 ReveFlex 为您生成\n// 作者: MacXK\n\n"];
    [logosString appendFormat:@"%%hook %@\n\n", NSStringFromClass(self.targetClass)];

    // Sort index paths to generate code in order
    NSArray *sortedPaths = [[self.selectedMethodPaths allObjects] sortedArrayUsingSelector:@selector(compare:)];

    for (NSIndexPath *path in sortedPaths) {
        Method method;
        const char *prefix;
        if (path.section == 1) { // Class Method
            method = [self.classMethods[path.row] pointerValue];
            prefix = "+";
        } else { // Instance Method
            method = [self.instanceMethods[path.row] pointerValue];
            prefix = "-";
        }
        
        [logosString appendFormat:@"%@ {\n", [RFUtility formatMethodForLogos:method withPrefix:prefix]];
        [logosString appendString:@"    %logf(\"[MacXK]\");\n"];
        [logosString appendString:@"    %orig;\n"];
        [logosString appendString:@"}\n\n"];
    }

    [logosString appendString:@"%end\n"];
    
    // Share the file
    NSString *fileName = [NSString stringWithFormat:@"%@.xm", NSStringFromClass(self.targetClass)];
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    
    [logosString writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    };
    [self presentViewController:activityVC animated:YES completion:nil];

    [self toggleHookMode];
}

#pragma mark - Export

- (void)exportHeader {
    NSMutableString *headerString = [NSMutableString string];
    
    // Header
    Class superclass = class_getSuperclass(self.targetClass);
    [headerString appendFormat:@"// 由 ReveFlex 生成\n\n"];
    if (superclass) {
        [headerString appendFormat:@"@interface %@ : %@\n\n", NSStringFromClass(self.targetClass), NSStringFromClass(superclass)];
    } else {
        [headerString appendFormat:@"@interface %@\n\n", NSStringFromClass(self.targetClass)];
    }
    
    // Properties
    if (self.properties.count > 0) {
        [headerString appendString:@"// 属性\n"];
        for (NSValue *propValue in self.properties) {
            [headerString appendFormat:@"%@\n", [RFUtility formatProperty:[propValue pointerValue]]];
        }
        [headerString appendString:@"\n"];
    }
    
    // Class Methods
    if (self.classMethods.count > 0) {
        [headerString appendString:@"// 类方法\n"];
        for (NSValue *methodValue in self.classMethods) {
            [headerString appendFormat:@"%@;\n", [RFUtility formatMethod:[methodValue pointerValue] withPrefix:"+"]];
        }
        [headerString appendString:@"\n"];
    }
    
    // Instance Methods
    if (self.instanceMethods.count > 0) {
        [headerString appendString:@"// 实例方法\n"];
        for (NSValue *methodValue in self.instanceMethods) {
            [headerString appendFormat:@"%@;\n", [RFUtility formatMethod:[methodValue pointerValue] withPrefix:"-"]];
        }
        [headerString appendString:@"\n"];
    }
    
    [headerString appendString:@"@end\n\n"];
    [headerString appendString:@"// 作者 MacXK\n"];
    
    // 1. 创建临时文件路径
    NSString *fileName = [NSString stringWithFormat:@"%@.h", NSStringFromClass(self.targetClass)];
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    
    // 2. 将内容写入文件
    NSError *error = nil;
    [headerString writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"[ReveFlex] Error writing header to temp file: %@", error);
        return; // 如果写入失败，则不继续
    }
    
    // 3. 分享文件URL
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    
    // 4. 设置完成回调，用于删除临时文件
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    };
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isFiltering) {
        if (section == 0) return self.filteredProperties.count;
        if (section == 1) return self.filteredClassMethods.count;
        return self.filteredInstanceMethods.count;
    }
    if (section == 0) return self.properties.count;
    if (section == 1) return self.classMethods.count;
    return self.instanceMethods.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSUInteger propCount = self.isFiltering ? self.filteredProperties.count : self.properties.count;
    NSUInteger classMethodCount = self.isFiltering ? self.filteredClassMethods.count : self.classMethods.count;
    NSUInteger instMethodCount = self.isFiltering ? self.filteredInstanceMethods.count : self.instanceMethods.count;

    if (section == 0 && propCount > 0) {
        return [NSString stringWithFormat:@"属性 (%lu)", (unsigned long)propCount];
    }
    if (section == 1 && classMethodCount > 0) {
        return [NSString stringWithFormat:@"类方法 (+, %lu)", (unsigned long)classMethodCount];
    }
    if (section == 2 && instMethodCount > 0) {
        return [NSString stringWithFormat:@"实例方法 (-, %lu)", (unsigned long)instMethodCount];
    }
    
    // Show count of 0 only when not filtering
    if (!self.isFiltering) {
        if (section == 0) return @"属性 (0)";
        if (section == 1) return @"类方法 (0)";
        if (section == 2) return @"实例方法 (0)";
    }

    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"DetailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:12];
        cell.textLabel.numberOfLines = 0;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (indexPath.section == 0) {
        NSArray *props = self.isFiltering ? self.filteredProperties : self.properties;
        objc_property_t prop = [props[indexPath.row] pointerValue];
        cell.textLabel.text = [RFUtility formatProperty:prop];
    } else if (indexPath.section == 1) {
        NSArray *methods = self.isFiltering ? self.filteredClassMethods : self.classMethods;
        NSValue *methodValue = methods[indexPath.row];
        cell.textLabel.text = [RFUtility formatMethod:[methodValue pointerValue] withPrefix:"+"];
    } else {
        NSArray *methods = self.isFiltering ? self.filteredInstanceMethods : self.instanceMethods;
        NSValue *methodValue = methods[indexPath.row];
        cell.textLabel.text = [RFUtility formatMethod:[methodValue pointerValue] withPrefix:"-"];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.isEditing) {
        if (indexPath.section > 0) { // Only methods can be hooked
            [self.selectedMethodPaths addObject:indexPath];
        }
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];

        if (indexPath.section == 0) {
            NSArray *props = self.isFiltering ? self.filteredProperties : self.properties;
            objc_property_t prop = [props[indexPath.row] pointerValue];
            [self handlePropertyTap:prop];
        } else {
            NSValue *methodValue;
            if (indexPath.section == 1) {
                NSArray *methods = self.isFiltering ? self.filteredClassMethods : self.classMethods;
                methodValue = methods[indexPath.row];
            } else {
                NSArray *methods = self.isFiltering ? self.filteredInstanceMethods : self.instanceMethods;
                methodValue = methods[indexPath.row];
            }
            [self handleMethodTap:methodValue isClassMethod:(indexPath.section == 1)];
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.isEditing) {
        [self.selectedMethodPaths removeObject:indexPath];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return UITableViewCellEditingStyleNone; // Properties cannot be selected
    }
    return UITableViewCellEditingStyleDelete | UITableViewCellEditingStyleInsert;
}

#pragma mark - Interaction Handlers

- (void)handlePropertyTap:(objc_property_t)prop {
    const char *propName = property_getName(prop);
    NSString *propNameString = [NSString stringWithUTF8String:propName];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:propNameString message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"获取当前值" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (!self.targetObject) {
            [self showResultAlert:@"无法获取值" message:@"目标对象已被销毁。"];
            return;
        }
        @try {
            id value = [self.targetObject valueForKey:propNameString];
            [self showResultAlert:@"属性值" message:[value description] ?: @"nil"];
        } @catch (NSException *exception) {
            [self showResultAlert:@"获取失败" message:exception.reason];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleMethodTap:(NSValue *)methodValue isClassMethod:(BOOL)isClassMethod {
    Method method = [methodValue pointerValue];
    NSString *methodName = [RFUtility formatMethod:method withPrefix:isClassMethod ? "+" : "-"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:methodName message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    // --- Add options for patching ---
    RFPatchingManager *manager = [RFPatchingManager sharedManager];
    Class targetCls = isClassMethod ? object_getClass(self.targetClass) : self.targetClass;
    
    // 选项：修改方法
    [alert addAction:[UIAlertAction actionWithTitle:@"修改方法 (参数/返回值)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        Class clsForPatching = isClassMethod ? object_getClass(self.targetClass) : self.targetClass;
        RFPatchDetailViewController *patchVC = [[RFPatchDetailViewController alloc] initWithMethod:method ofClass:clsForPatching isClassMethod:isClassMethod];
        [self.navigationController pushViewController:patchVC animated:YES];
    }]];
    
    // 选项：恢复
    if ([manager isMethodPatched:method ofClass:targetCls]) {
        [alert addAction:[UIAlertAction actionWithTitle:@"恢复原始实现" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [manager unpatchMethod:method ofClass:targetCls];
            [self showResultAlert:@"已恢复" message:@"方法已恢复原始实现。"];
        }]];
    }
    // --- End patching options ---

    [alert addAction:[UIAlertAction actionWithTitle:@"复制静态地址 (IDA)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self copyStaticAddressForMethod:method];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制断点命令" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self copyBreakpointCommandForMethod:method];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"生成Hook代码" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showHookCodeGeneratorForMethod:method isClassMethod:isClassMethod];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"方法交换 (Swizzle)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showSwizzleInterfaceForMethod:method isClassMethod:isClassMethod];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"生成特征码" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self generateBinarySignatureForMethod:method];
    }]];
    
    if (!isClassMethod) {
        [alert addAction:[UIAlertAction actionWithTitle:@"调用方法" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (!self.targetObject) {
                [self showResultAlert:@"调用失败" message:@"目标对象已被销毁。"];
                return;
            }
            [self showInvokeMethodAlertForMethod:method];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showResultAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 处理长按手势
- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"高级选项" 
                                                                       message:nil 
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"查找引用此类的其他类" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self findReferencesToCurrentClass];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"在堆中查找此类的实例 (choose)"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self findInstancesInHeap];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"分析类层次结构" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self analyzeClassHierarchy];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"查找关联协议" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self findAssociatedProtocols];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"生成调用链跟踪代码" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self generateCallChainTraceCode];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"生成类依赖图" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:^(UIAlertAction * _Nonnull action) {
            [self generateClassDependencyGraph];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// 分析类层次结构
- (void)analyzeClassHierarchy {
    NSMutableString *hierarchyText = [NSMutableString string];
    
    // 分析父类层次
    [hierarchyText appendString:@"继承层次:\n\n"];
    
    Class currentClass = self.targetClass;
    NSMutableArray *superclasses = [NSMutableArray array];
    
    while (currentClass) {
        [superclasses insertObject:NSStringFromClass(currentClass) atIndex:0];
        currentClass = class_getSuperclass(currentClass);
    }
    
    // 显示继承链
    for (NSUInteger i = 0; i < superclasses.count; i++) {
        NSString *indentation = [@"" stringByPaddingToLength:i*2 withString:@" " startingAtIndex:0];
        [hierarchyText appendFormat:@"%@%@\n", indentation, superclasses[i]];
    }
    
    // 查找子类
    [hierarchyText appendString:@"\n直接子类:\n\n"];
    
    unsigned int classCount;
    Class *classList = objc_copyClassList(&classCount);
    NSMutableArray *subclasses = [NSMutableArray array];
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classList[i];
        if (cls != self.targetClass && class_getSuperclass(cls) == self.targetClass) {
            [subclasses addObject:NSStringFromClass(cls)];
        }
    }
    
    if (subclasses.count > 0) {
        for (NSString *subclass in [subclasses sortedArrayUsingSelector:@selector(compare:)]) {
            [hierarchyText appendFormat:@"- %@\n", subclass];
        }
    } else {
        [hierarchyText appendString:@"(无直接子类)\n"];
    }
    
    // 查找同级类（具有相同父类的类）
    Class parentClass = class_getSuperclass(self.targetClass);
    if (parentClass) {
        [hierarchyText appendFormat:@"\n同级类 (继承自 %@):\n\n", NSStringFromClass(parentClass)];
        
        NSMutableArray *siblingClasses = [NSMutableArray array];
        for (unsigned int i = 0; i < classCount; i++) {
            Class cls = classList[i];
            if (cls != self.targetClass && class_getSuperclass(cls) == parentClass) {
                [siblingClasses addObject:NSStringFromClass(cls)];
            }
        }
        
        if (siblingClasses.count > 0) {
            for (NSString *siblingClass in [siblingClasses sortedArrayUsingSelector:@selector(compare:)]) {
                [hierarchyText appendFormat:@"- %@\n", siblingClass];
            }
        } else {
            [hierarchyText appendString:@"(无同级类)\n"];
        }
    }
    
    free(classList);
    
    // 显示结果
    [self showCodePreview:hierarchyText withTitle:@"类层次结构分析"];
}

// 查找关联协议
- (void)findAssociatedProtocols {
    NSMutableString *protocolText = [NSMutableString string];
    
    // 获取类实现的协议
    unsigned int protocolCount;
    Protocol * __unsafe_unretained *protocolList = class_copyProtocolList(self.targetClass, &protocolCount);
    
    [protocolText appendFormat:@"%@ 实现的协议:\n\n", NSStringFromClass(self.targetClass)];
    
    if (protocolCount > 0) {
        for (unsigned int i = 0; i < protocolCount; i++) {
            Protocol *proto = protocolList[i];
            const char *protocolName = protocol_getName(proto);
            [protocolText appendFormat:@"- %s\n", protocolName];
            
            // 获取协议遵循的其他协议
            unsigned int inheritedProtocolCount;
            Protocol * __unsafe_unretained *inheritedProtocols = protocol_copyProtocolList(proto, &inheritedProtocolCount);
            
            if (inheritedProtocolCount > 0) {
                [protocolText appendString:@"  继承自:\n"];
                for (unsigned int j = 0; j < inheritedProtocolCount; j++) {
                    [protocolText appendFormat:@"    - %s\n", protocol_getName(inheritedProtocols[j])];
                }
            }
            
            free(inheritedProtocols);
        }
    } else {
        [protocolText appendString:@"(未实现任何协议)\n"];
    }
    
    free(protocolList);
    
    // 查找采用此类作为委托/数据源的其他类
    [protocolText appendString:@"\n可能使用此类作为委托/数据源的类:\n\n"];
    
    unsigned int classCount;
    Class *classList = objc_copyClassList(&classCount);
    NSMutableSet *potentialUsers = [NSMutableSet set];
    
    NSString *className = NSStringFromClass(self.targetClass);
    NSString *delegatePattern = [NSString stringWithFormat:@"%@Delegate", className];
    NSString *dataSourcePattern = [NSString stringWithFormat:@"%@DataSource", className];
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classList[i];
        unsigned int propCount;
        objc_property_t *props = class_copyPropertyList(cls, &propCount);
        
        for (unsigned int j = 0; j < propCount; j++) {
            objc_property_t prop = props[j];
            const char *propName = property_getName(prop);
            NSString *propNameStr = [NSString stringWithUTF8String:propName];
            
            if ([propNameStr isEqualToString:@"delegate"] || 
                [propNameStr isEqualToString:@"dataSource"] || 
                [propNameStr containsString:delegatePattern] || 
                [propNameStr containsString:dataSourcePattern]) {
                
                const char *attrs = property_getAttributes(prop);
                NSString *attrStr = [NSString stringWithUTF8String:attrs];
                
                if ([attrStr containsString:className]) {
                    [potentialUsers addObject:NSStringFromClass(cls)];
                    break;
                }
            }
        }
        
        free(props);
    }
    
    if (potentialUsers.count > 0) {
        for (NSString *user in [[potentialUsers allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
            [protocolText appendFormat:@"- %@\n", user];
        }
    } else {
        [protocolText appendString:@"(未找到)\n"];
    }
    
    free(classList);
    
    // 显示结果
    [self showCodePreview:protocolText withTitle:@"协议分析"];
}

// 生成调用链跟踪代码
- (void)generateCallChainTraceCode {
    NSMutableString *traceCode = [NSMutableString string];
    NSString *className = NSStringFromClass(self.targetClass);
    
    [traceCode appendFormat:@"// 由 ReveFlex 生成的调用链跟踪代码\n"];
    [traceCode appendFormat:@"// 目标类: %@\n\n", className];
    
    // Logos 版本
    [traceCode appendString:@"// ===== Logos 版本 =====\n\n"];
    [traceCode appendFormat:@"%%hook %@\n\n", className];
    
    // 为所有实例方法添加跟踪
    [traceCode appendString:@"// 跟踪所有实例方法\n"];
    [traceCode appendString:@"-(void)forwardInvocation:(NSInvocation *)invocation {\n"];
    [traceCode appendString:@"    NSString *selector = NSStringFromSelector(invocation.selector);\n"];
    [traceCode appendString:@"    %logf(@\"[调用链] %@ 调用方法: %@\", self.class, selector);\n"];
    [traceCode appendString:@"    \n"];
    [traceCode appendString:@"    // 获取调用堆栈\n"];
    [traceCode appendString:@"    NSArray *callStack = [NSThread callStackSymbols];\n"];
    [traceCode appendString:@"    if (callStack.count > 2) {\n"];
    [traceCode appendString:@"        for (int i = 2; i < MIN(8, callStack.count); i++) {\n"];
    [traceCode appendString:@"            %logf(@\"[调用栈] %@\", callStack[i]);\n"];
    [traceCode appendString:@"        }\n"];
    [traceCode appendString:@"    }\n"];
    [traceCode appendString:@"    \n"];
    [traceCode appendString:@"    %orig;\n"];
    [traceCode appendString:@"}\n\n"];
    
    // 添加类方法跟踪
    [traceCode appendString:@"// 跟踪类方法\n"];
    [traceCode appendString:@"+(void)forwardInvocation:(NSInvocation *)invocation {\n"];
    [traceCode appendString:@"    NSString *selector = NSStringFromSelector(invocation.selector);\n"];
    [traceCode appendString:@"    %logf(@\"[调用链] %@ 调用类方法: %@\", self, selector);\n"];
    [traceCode appendString:@"    \n"];
    [traceCode appendString:@"    // 获取调用堆栈\n"];
    [traceCode appendString:@"    NSArray *callStack = [NSThread callStackSymbols];\n"];
    [traceCode appendString:@"    if (callStack.count > 2) {\n"];
    [traceCode appendString:@"        for (int i = 2; i < MIN(8, callStack.count); i++) {\n"];
    [traceCode appendString:@"            %logf(@\"[调用栈] %@\", callStack[i]);\n"];
    [traceCode appendString:@"        }\n"];
    [traceCode appendString:@"    }\n"];
    [traceCode appendString:@"    \n"];
    [traceCode appendString:@"    %orig;\n"];
    [traceCode appendString:@"}\n\n"];
    
    [traceCode appendString:@"%end\n\n"];
    
    // Frida 版本
    [traceCode appendString:@"// ===== Frida 版本 =====\n\n"];
    [traceCode appendString:@"if (ObjC.available) {\n"];
    [traceCode appendString:@"    try {\n"];
    [traceCode appendFormat:@"        var className = \"%@\";\n", className];
    [traceCode appendString:@"        var methods = ObjC.classes[className].$ownMethods;\n"];
    [traceCode appendString:@"        \n"];
    [traceCode appendString:@"        console.log(\"[*] 开始跟踪 \" + className + \" 的所有方法\");\n"];
    [traceCode appendString:@"        \n"];
    [traceCode appendString:@"        for (var i = 0; i < methods.length; i++) {\n"];
    [traceCode appendString:@"            var method = methods[i];\n"];
    [traceCode appendString:@"            var implementation = ObjC.classes[className][method].implementation;\n"];
    [traceCode appendString:@"            \n"];
    [traceCode appendString:@"            Interceptor.attach(implementation, {\n"];
    [traceCode appendString:@"                onEnter: function(args) {\n"];
    [traceCode appendString:@"                    console.log(\"[+] 调用方法: \" + method);\n"];
    [traceCode appendString:@"                    console.log(\"[+] 调用栈:\\n\" + Thread.backtrace(this.context, Backtracer.ACCURATE).map(DebugSymbol.fromAddress).join(\"\\n\"));\n"];
    [traceCode appendString:@"                },\n"];
    [traceCode appendString:@"                onLeave: function(retval) {\n"];
    [traceCode appendString:@"                    console.log(\"[-] 方法返回: \" + method);\n"];
    [traceCode appendString:@"                }\n"];
    [traceCode appendString:@"            });\n"];
    [traceCode appendString:@"        }\n"];
    [traceCode appendString:@"        \n"];
    [traceCode appendString:@"        // 跟踪实例方法\n"];
    [traceCode appendString:@"        var instanceMethods = ObjC.classes[className].prototype.$ownMethods;\n"];
    [traceCode appendString:@"        for (var i = 0; i < instanceMethods.length; i++) {\n"];
    [traceCode appendString:@"            var method = instanceMethods[i];\n"];
    [traceCode appendString:@"            var implementation = ObjC.classes[className].prototype[method].implementation;\n"];
    [traceCode appendString:@"            \n"];
    [traceCode appendString:@"            Interceptor.attach(implementation, {\n"];
    [traceCode appendString:@"                onEnter: function(args) {\n"];
    [traceCode appendString:@"                    var obj = new ObjC.Object(args[0]);\n"];
    [traceCode appendString:@"                    console.log(\"[+] 实例 \" + obj + \" 调用方法: \" + method);\n"];
    [traceCode appendString:@"                    console.log(\"[+] 调用栈:\\n\" + Thread.backtrace(this.context, Backtracer.ACCURATE).map(DebugSymbol.fromAddress).join(\"\\n\"));\n"];
    [traceCode appendString:@"                },\n"];
    [traceCode appendString:@"                onLeave: function(retval) {\n"];
    [traceCode appendString:@"                    console.log(\"[-] 方法返回: \" + method);\n"];
    [traceCode appendString:@"                }\n"];
    [traceCode appendString:@"            });\n"];
    [traceCode appendString:@"        }\n"];
    [traceCode appendString:@"        \n"];
    [traceCode appendString:@"        console.log(\"[*] 跟踪设置完成\");\n"];
    [traceCode appendString:@"    } catch (err) {\n"];
    [traceCode appendString:@"        console.log(\"[!] 跟踪设置失败: \" + err.message);\n"];
    [traceCode appendString:@"    }\n"];
    [traceCode appendString:@"} else {\n"];
    [traceCode appendString:@"    console.log(\"[!] Objective-C Runtime 不可用\");\n"];
    [traceCode appendString:@"}\n"];
    
    // 显示生成的代码
    [self showCodePreview:traceCode withTitle:@"调用链跟踪代码"];
}

// 生成类依赖关系图
- (void)generateClassDependencyGraph {
    NSString *className = NSStringFromClass(self.targetClass);
    
    // 创建进度提示
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在分析..." 
                                                                          message:@"正在分析类依赖关系，请稍候..." 
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 分析类依赖关系
        NSMutableSet<NSString *> *relatedClasses = [NSMutableSet set];
        NSMutableArray<NSArray<NSString *> *> *relationships = [NSMutableArray array];
        
        // 添加当前类
        [relatedClasses addObject:className];
        
        // 添加父类关系
        NSMutableArray<NSString *> *superclasses = [NSMutableArray array];
        Class currentClass = self.targetClass;
        Class superClass = class_getSuperclass(currentClass);
        
        while (superClass) {
            NSString *superClassName = NSStringFromClass(superClass);
            [superclasses addObject:superClassName];
            [relatedClasses addObject:superClassName];
            [relationships addObject:@[superClassName, className, @"继承"]];
            
            currentClass = superClass;
            superClass = class_getSuperclass(currentClass);
        }
        
        // 分析实例变量和属性依赖
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(self.targetClass, &ivarCount);
        
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *ivarType = ivar_getTypeEncoding(ivar);
            NSString *typeStr = [NSString stringWithUTF8String:ivarType];
            
            // 尝试提取类名
            if ([typeStr hasPrefix:@"@\""]) {
                NSString *ivarClassName = [typeStr substringWithRange:NSMakeRange(2, typeStr.length - 3)];
                if (NSClassFromString(ivarClassName)) {
                    [relatedClasses addObject:ivarClassName];
                    [relationships addObject:@[className, ivarClassName, @"包含"]];
                }
            }
        }
        free(ivars);
        
        // 分析属性依赖
        unsigned int propCount;
        objc_property_t *props = class_copyPropertyList(self.targetClass, &propCount);
        
        for (unsigned int i = 0; i < propCount; i++) {
            objc_property_t prop = props[i];
            const char *attrs = property_getAttributes(prop);
            NSString *attrStr = [NSString stringWithUTF8String:attrs];
            
            // 查找类型定义
            NSArray *components = [attrStr componentsSeparatedByString:@","];
            for (NSString *component in components) {
                if ([component hasPrefix:@"T@\""]) {
                    NSString *propClassName = [component substringWithRange:NSMakeRange(3, component.length - 4)];
                    if (NSClassFromString(propClassName)) {
                        [relatedClasses addObject:propClassName];
                        [relationships addObject:@[className, propClassName, @"引用"]];
                    }
                    break;
                }
            }
        }
        free(props);
        
        // 分析协议依赖
        unsigned int protocolCount;
        Protocol * __unsafe_unretained *protocolList = class_copyProtocolList(self.targetClass, &protocolCount);
        
        for (unsigned int i = 0; i < protocolCount; i++) {
            Protocol *proto = protocolList[i];
            const char *protocolName = protocol_getName(proto);
            NSString *protocolNameStr = [NSString stringWithFormat:@"%s", protocolName];
            
            [relatedClasses addObject:protocolNameStr];
            [relationships addObject:@[className, protocolNameStr, @"实现"]];
        }
        free(protocolList);
        
        // 查找子类
        unsigned int classCount;
        Class *classList = objc_copyClassList(&classCount);
        
        for (unsigned int i = 0; i < classCount; i++) {
            Class cls = classList[i];
            if (cls != self.targetClass && class_getSuperclass(cls) == self.targetClass) {
                NSString *subclassName = NSStringFromClass(cls);
                [relatedClasses addObject:subclassName];
                [relationships addObject:@[subclassName, className, @"继承"]];
            }
        }
        free(classList);
        
        // 生成DOT格式的图形描述
        NSMutableString *dotGraph = [NSMutableString string];
        [dotGraph appendString:@"digraph ClassDependencies {\n"];
        [dotGraph appendString:@"    rankdir=LR;\n"];
        [dotGraph appendString:@"    node [shape=box, style=filled, fillcolor=lightblue];\n"];
        [dotGraph appendFormat:@"    \"%@\" [fillcolor=gold];\n", className];
        
        // 添加节点
        for (NSString *cls in relatedClasses) {
            if (![cls isEqualToString:className]) {
                [dotGraph appendFormat:@"    \"%@\";\n", cls];
            }
        }
        
        // 添加关系
        for (NSArray *relation in relationships) {
            NSString *from = relation[0];
            NSString *to = relation[1];
            NSString *type = relation[2];
            
            NSString *edgeColor = @"black";
            NSString *edgeStyle = @"solid";
            
            if ([type isEqualToString:@"继承"]) {
                edgeColor = @"blue";
                edgeStyle = @"bold";
            } else if ([type isEqualToString:@"包含"]) {
                edgeColor = @"red";
            } else if ([type isEqualToString:@"引用"]) {
                edgeColor = @"green";
            } else if ([type isEqualToString:@"实现"]) {
                edgeColor = @"purple";
                edgeStyle = @"dashed";
            }
            
            [dotGraph appendFormat:@"    \"%@\" -> \"%@\" [label=\"%@\", color=%@, style=%@];\n", 
                                   from, to, type, edgeColor, edgeStyle];
        }
        
        [dotGraph appendString:@"}\n"];
        
        // 生成PlantUML格式的图形描述
        NSMutableString *plantUML = [NSMutableString string];
        [plantUML appendString:@"@startuml\n"];
        [plantUML appendString:@"skinparam classAttributeIconSize 0\n"];
        [plantUML appendString:@"skinparam monochrome false\n"];
        [plantUML appendString:@"skinparam shadowing false\n"];
        [plantUML appendString:@"skinparam linetype ortho\n"];
        [plantUML appendString:@"skinparam handwritten false\n"];
        
        // 添加类定义
        for (NSString *cls in relatedClasses) {
            if ([cls hasPrefix:@"NS"] || [cls hasPrefix:@"UI"]) {
                [plantUML appendFormat:@"class \"%@\" <<Framework>> {\n}\n", cls];
            } else if ([cls hasPrefix:@"I"] && cls.length > 1 && isupper([cls characterAtIndex:1])) {
                [plantUML appendFormat:@"interface \"%@\" {\n}\n", cls];
            } else {
                [plantUML appendFormat:@"class \"%@\" {\n}\n", cls];
            }
        }
        
        // 添加关系
        for (NSArray *relation in relationships) {
            NSString *from = relation[0];
            NSString *to = relation[1];
            NSString *type = relation[2];
            
            if ([type isEqualToString:@"继承"]) {
                [plantUML appendFormat:@"\"%@\" --|> \"%@\"\n", from, to];
            } else if ([type isEqualToString:@"包含"]) {
                [plantUML appendFormat:@"\"%@\" *-- \"%@\"\n", from, to];
            } else if ([type isEqualToString:@"引用"]) {
                [plantUML appendFormat:@"\"%@\" --> \"%@\"\n", from, to];
            } else if ([type isEqualToString:@"实现"]) {
                [plantUML appendFormat:@"\"%@\" ..|> \"%@\"\n", from, to];
            }
        }
        
        [plantUML appendString:@"@enduml\n"];
        
        // 创建结果字符串
        NSMutableString *resultString = [NSMutableString string];
        [resultString appendFormat:@"// %@ 类依赖关系图\n\n", className];
        [resultString appendString:@"// DOT格式 (可用于Graphviz)\n"];
        [resultString appendString:@"// -----------------------------\n"];
        [resultString appendString:dotGraph];
        [resultString appendString:@"\n\n"];
        [resultString appendString:@"// PlantUML格式\n"];
        [resultString appendString:@"// -----------------------------\n"];
        [resultString appendString:plantUML];
        
        // 在主线程显示结果
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                [self showCodePreview:resultString withTitle:[NSString stringWithFormat:@"%@ 类依赖图", className]];
            }];
        });
    });
}

#pragma mark - Method Swizzling

// 显示方法交换界面
- (void)showSwizzleInterfaceForMethod:(Method)method isClassMethod:(BOOL)isClassMethod {
    SEL originalSelector = method_getName(method);
    NSString *originalSelectorName = NSStringFromSelector(originalSelector);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"方法交换 (Method Swizzling)" 
                                                                   message:[NSString stringWithFormat:@"选择交换目标方法\n当前方法: %@", originalSelectorName]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"目标类名 (如: UIView)";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"目标方法名 (如: setFrame:)";
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"交换" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *targetClassName = alert.textFields[0].text;
        NSString *targetMethodName = alert.textFields[1].text;
        
        if (targetClassName.length == 0 || targetMethodName.length == 0) {
            [self showResultAlert:@"交换失败" message:@"类名和方法名不能为空"];
            return;
        }
        
        [self performMethodSwizzlingWithOriginalMethod:method 
                                        isClassMethod:isClassMethod 
                                     targetClassName:targetClassName 
                                    targetMethodName:targetMethodName];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 执行方法交换
- (void)performMethodSwizzlingWithOriginalMethod:(Method)originalMethod 
                                   isClassMethod:(BOOL)isClassMethod 
                                targetClassName:(NSString *)targetClassName 
                               targetMethodName:(NSString *)targetMethodName {
    
    // 获取目标类
    Class targetClass = NSClassFromString(targetClassName);
    if (!targetClass) {
        [self showResultAlert:@"交换失败" message:[NSString stringWithFormat:@"找不到类: %@", targetClassName]];
        return;
    }
    
    // 如果是类方法，获取元类
    if (isClassMethod) {
        targetClass = object_getClass(targetClass);
    }
    
    // 获取目标方法
    SEL targetSelector = NSSelectorFromString(targetMethodName);
    if (!targetSelector) {
        [self showResultAlert:@"交换失败" message:@"无效的方法名"];
        return;
    }
    
    Method targetMethod = class_getInstanceMethod(targetClass, targetSelector);
    if (!targetMethod) {
        [self showResultAlert:@"交换失败" message:[NSString stringWithFormat:@"在类 %@ 中找不到方法: %@", targetClassName, targetMethodName]];
        return;
    }
    
    // 执行方法交换
    method_exchangeImplementations(originalMethod, targetMethod);
    
    // 显示成功消息
    [self showResultAlert:@"方法交换成功" 
                  message:[NSString stringWithFormat:@"已交换:\n%@ [%@]\n与\n%@ [%@]", 
                           NSStringFromClass(self.targetClass), 
                           NSStringFromSelector(method_getName(originalMethod)),
                           targetClassName, 
                           targetMethodName]];
    
    // 重新加载表格
    [self.tableView reloadData];
}

#pragma mark - Advanced Hook Code Generator

// 显示Hook代码生成器界面
- (void)showHookCodeGeneratorForMethod:(Method)method isClassMethod:(BOOL)isClassMethod {
    SEL selector = method_getName(method);
    NSString *selectorName = NSStringFromSelector(selector);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择Hook框架" 
                                                                   message:[NSString stringWithFormat:@"为 %@ 生成Hook代码", selectorName]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Logos (Theos)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self generateLogosHookForMethod:method isClassMethod:isClassMethod];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Frida" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self generateFridaHookForMethod:method isClassMethod:isClassMethod];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 生成Logos Hook代码
- (void)generateLogosHookForMethod:(Method)method isClassMethod:(BOOL)isClassMethod {
    SEL selector = method_getName(method);
    NSString *selectorName = NSStringFromSelector(selector);
    const char *prefix = isClassMethod ? "+" : "-";
    
    NSMutableString *hookCode = [NSMutableString string];
    [hookCode appendFormat:@"// 由 ReveFlex 生成的 Logos Hook 代码\n"];
    [hookCode appendFormat:@"// 目标类: %@\n", NSStringFromClass(self.targetClass)];
    [hookCode appendFormat:@"// 方法: %@\n\n", [RFUtility formatMethod:method withPrefix:prefix]];
    
    [hookCode appendFormat:@"%%hook %@\n\n", NSStringFromClass(self.targetClass)];
    
    // 构建方法签名和参数日志
    NSMutableString *methodSignature = [NSMutableString string];
    NSMutableString *logStatement = [NSMutableString string];
    
    // 获取返回类型
    char returnType[256];
    method_getReturnType(method, returnType, sizeof(returnType));
    NSString *returnTypeStr = [RFUtility decodeType:returnType];
    
    // 分析方法名和参数
    NSArray *components = [selectorName componentsSeparatedByString:@":"];
    unsigned int argCount = method_getNumberOfArguments(method);
    
    // 开始构建方法签名
    [methodSignature appendFormat:@"%s ", prefix];
    [methodSignature appendFormat:@"(%@)", returnTypeStr];
    
    // 构建日志语句开头
    [logStatement appendString:@"    NSLog(@\"[MacXK] %@"];
    
    if (argCount <= 2) {
        // 无参数方法
        [methodSignature appendString:selectorName];
        [logStatement appendFormat:@" called\");\n"];
    } else {
        // 有参数方法
        for (unsigned int i = 2; i < argCount; i++) {
            char argType[256];
            method_getArgumentType(method, i, argType, sizeof(argType));
            NSString *argTypeStr = [RFUtility decodeType:argType];
            NSString *component = (i-2 < components.count) ? components[i-2] : @"";
            
            if (i == 2) {
                [methodSignature appendFormat:@"%@:(%@)arg%d ", component, argTypeStr, i-2];
            } else {
                [methodSignature appendFormat:@"%@:(%@)arg%d ", component, argTypeStr, i-2];
            }
            
            // 添加参数到日志
            if (i == 2) {
                [logStatement appendFormat:@" %@:", component];
            } else {
                [logStatement appendFormat:@" %@:", component];
            }
            
            // 根据参数类型添加合适的格式说明符
            if ([argTypeStr isEqualToString:@"int"] || 
                [argTypeStr isEqualToString:@"unsigned int"] || 
                [argTypeStr isEqualToString:@"short"] || 
                [argTypeStr isEqualToString:@"unsigned short"]) {
                [logStatement appendString:@" %d"];
            } else if ([argTypeStr isEqualToString:@"long"] || 
                       [argTypeStr isEqualToString:@"unsigned long"] || 
                       [argTypeStr isEqualToString:@"long long"] || 
                       [argTypeStr isEqualToString:@"unsigned long long"]) {
                [logStatement appendString:@" %lld"];
            } else if ([argTypeStr isEqualToString:@"float"] || 
                       [argTypeStr isEqualToString:@"double"]) {
                [logStatement appendString:@" %f"];
            } else if ([argTypeStr isEqualToString:@"BOOL"]) {
                [logStatement appendString:@" %@"];
            } else if ([argTypeStr isEqualToString:@"char *"] || 
                       [argTypeStr isEqualToString:@"const char *"]) {
                [logStatement appendString:@" %s"];
            } else if ([argTypeStr hasPrefix:@"struct"]) {
                [logStatement appendString:@" (struct)"];
            } else {
                [logStatement appendString:@" %@"];
            }
        }
        
        // 完成日志语句
        [logStatement appendString:@"\""];
        
        // 添加参数变量
        for (unsigned int i = 2; i < argCount; i++) {
            char argType[256];
            method_getArgumentType(method, i, argType, sizeof(argType));
            NSString *argTypeStr = [RFUtility decodeType:argType];
            
            if ([argTypeStr isEqualToString:@"BOOL"]) {
                [logStatement appendFormat:@", arg%d ? @\"YES\" : @\"NO\"", i-2];
            } else if ([argTypeStr hasPrefix:@"struct"]) {
                // 结构体不输出具体值
            } else if ([argTypeStr isEqualToString:@"id"] || 
                       [argTypeStr hasSuffix:@" *"] || 
                       [argTypeStr isEqualToString:@"SEL"] || 
                       [argTypeStr isEqualToString:@"Class"]) {
                [logStatement appendFormat:@", arg%d", i-2];
            } else {
                [logStatement appendFormat:@", arg%d", i-2];
            }
        }
        
        [logStatement appendString:@");\n"];
    }
    
    // 完成方法签名
    NSString *finalMethodSignature = [methodSignature stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // 组装完整的跟踪代码
    [hookCode appendFormat:@"%@ {\n", finalMethodSignature];
    [hookCode appendString:logStatement];
    
    // 添加返回语句
    if (![returnTypeStr isEqualToString:@"void"]) {
        [hookCode appendString:@"    \n    // 调用原始方法并获取返回值\n"];
        [hookCode appendString:@"    id result = %orig;\n"];
        [hookCode appendString:@"    NSLog(@\"[MacXK] 返回值: %@\", result);\n"];
        [hookCode appendString:@"    return result;\n"];
    } else {
        [hookCode appendString:@"    \n    // 调用原始方法\n"];
        [hookCode appendString:@"    %orig;\n"];
    }
    
    [hookCode appendString:@"}\n\n"];
    [hookCode appendString:@"%end\n"];
    
    // 复制到剪贴板
    [UIPasteboard generalPasteboard].string = hookCode;
    
    // 显示生成的代码
    [self showCodePreview:hookCode withTitle:@"Logos Hook代码"];
}

// 生成Frida Hook代码
- (void)generateFridaHookForMethod:(Method)method isClassMethod:(BOOL)isClassMethod {
    SEL selector = method_getName(method);
    NSString *selectorName = NSStringFromSelector(selector);
    
    NSMutableString *hookCode = [NSMutableString string];
    [hookCode appendFormat:@"// 由 ReveFlex 生成的 Frida Hook 代码\n"];
    [hookCode appendFormat:@"// 目标类: %@\n", NSStringFromClass(self.targetClass)];
    [hookCode appendFormat:@"// 方法: %@\n\n", selectorName];
    
    [hookCode appendString:@"if (ObjC.available) {\n"];
    [hookCode appendString:@"    try {\n"];
    
    if (isClassMethod) {
        [hookCode appendFormat:@"        var classHandle = ObjC.classes[\"%@\"];\n", NSStringFromClass(self.targetClass)];
        [hookCode appendFormat:@"        var method = classHandle[\"%@\"];\n\n", selectorName];
    } else {
        [hookCode appendFormat:@"        var classHandle = ObjC.classes[\"%@\"];\n", NSStringFromClass(self.targetClass)];
        [hookCode appendFormat:@"        var method = classHandle.prototype[\"%@\"];\n\n", selectorName];
    }
    
    [hookCode appendString:@"        Interceptor.attach(method.implementation, {\n"];
    [hookCode appendString:@"            onEnter: function(args) {\n"];
    [hookCode appendFormat:@"                console.log(\"[MacXK] 方法被调用: %@\");\n", selectorName];
    
    // 添加参数日志
    unsigned int argCount = method_getNumberOfArguments(method);
    if (argCount > 2) {
        [hookCode appendString:@"                \n                // 打印参数\n"];
        for (unsigned int i = 2; i < argCount; i++) {
            [hookCode appendFormat:@"                console.log(\"[MacXK] 参数%d: \" + args[%d]);\n", i-2, i];
        }
    }
    
    [hookCode appendString:@"            },\n"];
    [hookCode appendString:@"            onLeave: function(retval) {\n"];
    [hookCode appendString:@"                console.log(\"[MacXK] 返回值: \" + retval);\n"];
    [hookCode appendString:@"                // 如果需要修改返回值，取消下面注释\n"];
    [hookCode appendString:@"                // retval.replace(ObjC.classes.NSNumber.numberWithBool_(true));\n"];
    [hookCode appendString:@"                return retval;\n"];
    [hookCode appendString:@"            }\n"];
    [hookCode appendString:@"        });\n"];
    [hookCode appendString:@"        console.log(\"[MacXK] Hook 成功安装\");\n"];
    [hookCode appendString:@"    } catch (err) {\n"];
    [hookCode appendString:@"        console.log(\"[MacXK] Hook 失败: \" + err.message);\n"];
    [hookCode appendString:@"    }\n"];
    [hookCode appendString:@"} else {\n"];
    [hookCode appendString:@"    console.log(\"[MacXK] Objective-C Runtime 不可用\");\n"];
    [hookCode appendString:@"}\n"];
    
    // 显示生成的代码
    [self showCodePreview:hookCode withTitle:@"Frida Hook代码"];
}

#pragma mark - Binary Signature Generator

// 生成二进制特征码
- (void)generateBinarySignatureForMethod:(Method)method {
    IMP imp = method_getImplementation(method);
    SEL selector = method_getName(method);
    
    // 获取ASLR偏移
    vm_address_t slide = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i)->filetype == MH_EXECUTE) {
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    
    // 计算静态地址
    vm_address_t staticAddress = (vm_address_t)imp - slide;
    
    // 读取方法实现的前32字节（如果可能）
    NSMutableString *byteString = [NSMutableString string];
    NSMutableString *signatureString = [NSMutableString string];
    NSMutableString *idaSignature = [NSMutableString string];
    
    @try {
        uint8_t *bytes = (uint8_t *)imp;
        for (int i = 0; i < 32; i++) {
            [byteString appendFormat:@"%02X ", bytes[i]];
            
            // 为IDA创建特征码模式
            if (i % 4 == 0 && i > 0) {
                [idaSignature appendString:@" "];
            }
            [idaSignature appendFormat:@"%02X", bytes[i]];
            
            // 创建通用特征码（带通配符）
            if (i % 4 == 0 && i > 0) {
                [signatureString appendString:@" "];
            }
            
            // 某些字节可能是地址或偏移，用通配符替代
            if (i >= 8 && i < 12) {
                [signatureString appendString:@"??"];
            } else {
                [signatureString appendFormat:@"%02X", bytes[i]];
            }
        }
    } @catch (NSException *exception) {
        [byteString appendString:@"无法读取方法实现的字节码"];
    }
    
    // 创建特征码信息
    NSMutableString *signatureInfo = [NSMutableString string];
    [signatureInfo appendFormat:@"方法: %@\n\n", NSStringFromSelector(selector)];
    [signatureInfo appendFormat:@"静态地址: 0x%llx\n\n", (unsigned long long)staticAddress];
    
    [signatureInfo appendString:@"原始字节码:\n"];
    [signatureInfo appendString:byteString];
    [signatureInfo appendString:@"\n\n"];
    
    [signatureInfo appendString:@"IDA 特征码:\n"];
    [signatureInfo appendString:idaSignature];
    [signatureInfo appendString:@"\n\n"];
    
    [signatureInfo appendString:@"通用特征码 (带通配符):\n"];
    [signatureInfo appendString:signatureString];
    [signatureInfo appendString:@"\n\n"];
    
    [signatureInfo appendString:@"IDA 二进制搜索命令:\n"];
    [signatureInfo appendString:@"在IDA中按Alt+B，然后输入上述特征码\n\n"];
    
    [signatureInfo appendString:@"Hopper 二进制搜索:\n"];
    [signatureInfo appendString:@"在Hopper中使用搜索功能，选择\"Hex String\"选项\n"];
    
    // 显示特征码信息
    [self showCodePreview:signatureInfo withTitle:@"二进制特征码"];
}

// 查找引用当前类的其他类
- (void)findReferencesToCurrentClass {
    NSString *className = NSStringFromClass(self.targetClass);
    NSMutableArray<NSString *> *referencingClasses = [NSMutableArray array];
    
    // 获取所有已加载的类
    unsigned int classCount;
    Class *classList = objc_copyClassList(&classCount);
    
    // 创建进度提示
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"正在搜索..." 
                                                                          message:@"正在分析所有已加载的类，请稍候..." 
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 遍历所有类
        for (unsigned int i = 0; i < classCount; i++) {
            Class cls = classList[i];
            
            // 检查是否是当前类的子类
            if (cls != self.targetClass && class_getSuperclass(cls) == self.targetClass) {
                [referencingClasses addObject:[NSString stringWithFormat:@"%@ (子类)", NSStringFromClass(cls)]];
                continue;
            }
            
            // 检查实例变量
            unsigned int ivarCount;
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);
            for (unsigned int j = 0; j < ivarCount; j++) {
                Ivar ivar = ivars[j];
                const char *ivarType = ivar_getTypeEncoding(ivar);
                NSString *typeStr = [NSString stringWithUTF8String:ivarType];
                
                if ([typeStr containsString:className]) {
                    [referencingClasses addObject:[NSString stringWithFormat:@"%@ (实例变量)", NSStringFromClass(cls)]];
                    break;
                }
            }
            free(ivars);
            
            // 检查属性
            unsigned int propCount;
            objc_property_t *props = class_copyPropertyList(cls, &propCount);
            for (unsigned int j = 0; j < propCount; j++) {
                objc_property_t prop = props[j];
                const char *attrs = property_getAttributes(prop);
                NSString *attrStr = [NSString stringWithUTF8String:attrs];
                
                if ([attrStr containsString:className]) {
                    [referencingClasses addObject:[NSString stringWithFormat:@"%@ (属性)", NSStringFromClass(cls)]];
                    break;
                }
            }
            free(props);
            
            // 检查方法签名
            unsigned int methodCount;
            Method *methods = class_copyMethodList(cls, &methodCount);
            for (unsigned int j = 0; j < methodCount; j++) {
                Method method = methods[j];
                const char *types = method_getTypeEncoding(method);
                NSString *typeStr = [NSString stringWithUTF8String:types];
                
                if ([typeStr containsString:className]) {
                    [referencingClasses addObject:[NSString stringWithFormat:@"%@ (方法签名)", NSStringFromClass(cls)]];
                    break;
                }
            }
            free(methods);
        }
        
        free(classList);
        
        // 在主线程显示结果
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressAlert dismissViewControllerAnimated:YES completion:^{
                NSString *resultMessage;
                if (referencingClasses.count > 0) {
                    resultMessage = [referencingClasses componentsJoinedByString:@"\n"];
                } else {
                    resultMessage = @"未找到引用此类的其他类";
                }
                
                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"引用查找结果" 
                                                                                   message:resultMessage 
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"复制结果" 
                                                               style:UIAlertActionStyleDefault 
                                                             handler:^(UIAlertAction * _Nonnull action) {
                    [UIPasteboard generalPasteboard].string = resultMessage;
                }]];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:resultAlert animated:YES completion:nil];
            }];
        });
    });
}

#pragma mark - Heap Scanning

- (void)findInstancesInHeap {
    RFHeapScanViewController *heapVC = [[RFHeapScanViewController alloc] initWithClass:self.targetClass];
    [self.navigationController pushViewController:heapVC animated:YES];
}

#pragma mark - Code Preview

// 安全的代码预览方法
- (void)showCodePreview:(NSString *)code withTitle:(NSString *)title {
    // 创建一个新的视图控制器来显示代码
    UIViewController *previewVC = [[UIViewController alloc] init];
    previewVC.title = title;
    previewVC.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 创建文本视图
    UITextView *textView = [[UITextView alloc] initWithFrame:previewVC.view.bounds];
    textView.font = [UIFont fontWithName:@"Menlo" size:12];
    textView.text = code;
    textView.editable = NO;
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [previewVC.view addSubview:textView];
    
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] 
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                   target:self 
                                   action:@selector(dismissPreviewVC:)];
    previewVC.navigationItem.rightBarButtonItem = closeButton;
    
    // 添加复制按钮
    UIBarButtonItem *copyButton = [[UIBarButtonItem alloc] 
                                  initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                  target:self 
                                  action:@selector(copyPreviewCode:)];
    previewVC.navigationItem.leftBarButtonItem = copyButton;
    
    // 使用导航控制器包装预览控制器
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:previewVC];
    navController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    // 保存代码到临时属性，以便复制按钮使用
    objc_setAssociatedObject(previewVC, "previewCode", code, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self presentViewController:navController animated:YES completion:nil];
}

// 关闭预览的方法
- (void)dismissPreviewVC:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 复制预览代码的方法
- (void)copyPreviewCode:(id)sender {
    // 移除未使用的button变量
    UIViewController *previewVC = ((UINavigationController *)self.presentedViewController).topViewController;
    NSString *code = objc_getAssociatedObject(previewVC, "previewCode");
    
    if (code) {
        [UIPasteboard generalPasteboard].string = code;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制" 
                                                                       message:@"代码已复制到剪贴板" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [previewVC presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Global Search

// 显示全局搜索界面
- (void)showGlobalSearch {
    // 调用RFUIManager的全局搜索方法
    [RFUIManager showGlobalSearchFromViewController:self];
}

#pragma mark - Search

- (void)showSearchOptions {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    if (self.isFiltering) {
        [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"清除筛选 (%@)", self.filterText] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self clearLocalFilter];
        }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:@"在当前类中搜索" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self showLocalSearchAlert];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"全局搜索" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [RFUIManager showGlobalSearchFromViewController:self];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // For iPad compatibility
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.lastObject;
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLocalSearchAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"在当前类中搜索" 
                                                                   message:@"请输入要搜索的内容" 
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"属性或方法名";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"搜索" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *searchText = alert.textFields.firstObject.text;
        if (searchText.length > 0) {
            [self performLocalSearchWithText:searchText];
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performLocalSearchWithText:(NSString *)searchText {
    self.isFiltering = YES;
    self.filterText = searchText;
    NSString *lowerSearchText = [searchText lowercaseString];

    NSPredicate *propPredicate = [NSPredicate predicateWithBlock:^BOOL(NSValue *evaluatedObject, NSDictionary *bindings) {
        objc_property_t prop = [evaluatedObject pointerValue];
        return [[[RFUtility formatProperty:prop] lowercaseString] containsString:lowerSearchText];
    }];
    self.filteredProperties = [self.properties filteredArrayUsingPredicate:propPredicate];

    NSPredicate *classMethodPredicate = [NSPredicate predicateWithBlock:^BOOL(NSValue *evaluatedObject, NSDictionary *bindings) {
        Method method = [evaluatedObject pointerValue];
        return [[[RFUtility formatMethod:method withPrefix:"+"] lowercaseString] containsString:lowerSearchText];
    }];
    self.filteredClassMethods = [self.classMethods filteredArrayUsingPredicate:classMethodPredicate];

    NSPredicate *instMethodPredicate = [NSPredicate predicateWithBlock:^BOOL(NSValue *evaluatedObject, NSDictionary *bindings) {
        Method method = [evaluatedObject pointerValue];
        return [[[RFUtility formatMethod:method withPrefix:"-"] lowercaseString] containsString:lowerSearchText];
    }];
    self.filteredInstanceMethods = [self.instanceMethods filteredArrayUsingPredicate:instMethodPredicate];

    [self.tableView reloadData];
}

- (void)clearLocalFilter {
    self.isFiltering = NO;
    self.filterText = nil;
    self.filteredProperties = nil;
    self.filteredClassMethods = nil;
    self.filteredInstanceMethods = nil;
    [self.tableView reloadData];
}

// Add before @end
- (void)copyBreakpointCommandForMethod:(Method)method {
    SEL selector = method_getName(method);
    NSString *selectorName = NSStringFromSelector(selector);
    
    // 生成LLDB断点命令
    NSString *breakpointCommand = [NSString stringWithFormat:@"breakpoint set --name \"%@\"", selectorName];
    
    // 复制到剪贴板
    [UIPasteboard generalPasteboard].string = breakpointCommand;
    
    // 显示确认提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"断点命令已复制" 
                                                                   message:[NSString stringWithFormat:@"LLDB命令已复制到剪贴板：\n%@", breakpointCommand] 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Add before @end
- (void)copyStaticAddressForMethod:(Method)method {
    IMP imp = method_getImplementation(method);
    
    vm_address_t slide = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i)->filetype == MH_EXECUTE) {
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    
    vm_address_t staticAddress = (vm_address_t)imp - slide;
    NSString *addressString = [NSString stringWithFormat:@"0x%llx", (unsigned long long)staticAddress];
    
    [UIPasteboard generalPasteboard].string = addressString;
    
    // Show a confirmation alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"地址已复制" message:[NSString stringWithFormat:@"静态地址 %@ 已复制到剪贴板。", addressString] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Add before @end
- (void)showInvokeMethodAlertForMethod:(Method)method {
    SEL selector = method_getName(method);
    NSString *selectorName = NSStringFromSelector(selector);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"调用方法" 
                                                                   message:[NSString stringWithFormat:@"您确定要调用方法 %@ 吗？", selectorName]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"调用" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 尝试调用无参数方法
        @try {
            NSMethodSignature *signature = [self.targetObject methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:selector];
            [invocation setTarget:self.targetObject];
            [invocation invoke];
            
            // 对于返回值的处理
            NSString *returnValue = @"(无返回值)";
            const char *returnType = [signature methodReturnType];
            if (strcmp(returnType, @encode(void)) != 0) {
                if (strcmp(returnType, @encode(id)) == 0 || strcmp(returnType, @encode(Class)) == 0) {
                    __unsafe_unretained id result = nil;
                    [invocation getReturnValue:&result];
                    returnValue = [NSString stringWithFormat:@"%@", result ?: @"nil"];
                } else if (strcmp(returnType, @encode(BOOL)) == 0) {
                    BOOL result;
                    [invocation getReturnValue:&result];
                    returnValue = result ? @"YES" : @"NO";
                } else if (strcmp(returnType, @encode(int)) == 0) {
                    int result;
                    [invocation getReturnValue:&result];
                    returnValue = [NSString stringWithFormat:@"%d", result];
                } else {
                    returnValue = @"(返回值类型不支持显示)";
                }
            }
            
            [self showResultAlert:@"调用成功" message:[NSString stringWithFormat:@"方法返回值: %@", returnValue]];
        } @catch (NSException *exception) {
            [self showResultAlert:@"调用失败" message:exception.reason ?: @"未知错误"];
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 实现invokeMethod:withParameters: 方法
- (void)invokeMethod:(Method)method withParameters:(NSArray *)parameters {
    SEL selector = method_getName(method);
    NSMethodSignature *signature = [self.targetObject methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    [invocation setTarget:self.targetObject];
    
    // 设置参数
    for (NSUInteger i = 0; i < parameters.count && i < signature.numberOfArguments - 2; i++) {
        id param = parameters[i];
        [invocation setArgument:&param atIndex:i + 2]; // 0和1是self和_cmd
    }
    
    [invocation invoke];
    
    // 处理返回值（如果需要）
    const char *returnType = [signature methodReturnType];
    if (strcmp(returnType, @encode(void)) != 0) {
        if (strcmp(returnType, @encode(id)) == 0 || strcmp(returnType, @encode(Class)) == 0) {
            __unsafe_unretained id result = nil;
            [invocation getReturnValue:&result];
            NSLog(@"返回值: %@", result ?: @"nil");
        }
    }
}

@end
