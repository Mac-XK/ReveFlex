#import "RFPatchListViewController.h"
#import "RFPatchingManager.h"
#import "RFDetailViewController.h" // For navigating back
#import "RFUtility.h"
// RFSettingsViewController 已移除，不需要这个设置功能
#import <mach-o/dyld.h>
#import <objc/runtime.h>

// 辅助函数，用于获取方法的静态地址
static vm_address_t get_static_address(IMP imp) {
    if (!imp) return 0;
    vm_address_t slide = 0;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i)->filetype == MH_EXECUTE) {
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    return (vm_address_t)imp - slide;
}

@interface RFPatchListViewController ()
@property (nonatomic, strong) NSArray<NSString *> *bundleIdentifiers;
@property (nonatomic, strong) RFPatchingManager *patchManager;
@end

@implementation RFPatchListViewController

- (instancetype)init {
    // 使用 InsetGrouped 样式以获得带圆角的分区效果
    if (@available(iOS 13.0, *)) {
        self = [super initWithStyle:UITableViewStyleInsetGrouped];
    } else {
        self = [super initWithStyle:UITableViewStyleGrouped];
    }
    return self;
}

// 添加patchManager的getter方法，确保属性被正确初始化
- (RFPatchingManager *)patchManager {
    if (!_patchManager) {
        _patchManager = [RFPatchingManager sharedManager];
    }
    return _patchManager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"已应用的补丁";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    [self setupTableView];
    [self setupNavigationBar];
    
    // 监听补丁更新通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePatchesChanged:)
                                                 name:RFPatchingManagerDidUpdatePatchesNotification
                                               object:nil];
    
    [self reloadPatches];
}

// 添加setupTableView方法的实现
- (void)setupTableView {
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60.0;
    // 移除这行，因为它会强制使用不支持副标题的默认样式
    // [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"PatchCell"];
}

- (void)setupNavigationBar {
    // 使用一个“操作”按钮来提供多个选项
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(showActions:)];
}

// 设置功能已移除

- (void)reloadPatches {
    self.bundleIdentifiers = [self.patchManager allPatchedBundleIdentifiers];
    [self.tableView reloadData];
}

#pragma mark - 导出与操作

- (void)showActions:(id)sender {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"选择操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"全部恢复" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self unpatchAll];
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"导出为 .xm Hook 文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self exportAsXmFile];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"分享补丁集 (.json)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self sharePatchesAsJSON];
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // 兼容 iPad
    if ([sender isKindOfClass:[UIBarButtonItem class]]) {
        actionSheet.popoverPresentationController.barButtonItem = sender;
    }
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)sharePatchesAsJSON {
    NSError *error = nil;
    NSString *jsonString = [self.patchManager exportPatchesToJSON:&error];

    if (!jsonString || error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出失败" message:error.localizedDescription ?: @"无法生成补丁集文件。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSString *fileName = @"ReveFlex_PatchSet.json";
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    
    NSError *writeError = nil;
    [jsonString writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    
    if (writeError) {
        // Handle error
        return;
    }
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        // Cleanup the temporary file
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    };

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)exportAsXmFile {
    NSMutableDictionary<NSString *, NSMutableArray<RFPatchInfo *> *> *groupedPatches = [NSMutableDictionary dictionary];

    // 遍历所有 enabled 的 app 的补丁
    for (NSString *bundleId in self.bundleIdentifiers) {
        if (![self.patchManager isApplicationPatchesEnabled:bundleId]) continue;
        
        NSArray *keys = [self.patchManager allPatchedMethodKeysForBundleIdentifier:bundleId];
        for (NSString *key in keys) {
            RFPatchInfo *info = [self.patchManager patchInfoForKey:key forBundleIdentifier:bundleId];
            // 目前只导出返回值类型的补丁
            if (info && info.targetClass && info.patchType == RFPatchTypeReturnValue) {
                NSString *className = NSStringFromClass(info.targetClass);
                NSMutableArray *patchesForClass = groupedPatches[className];
                if (!patchesForClass) {
                    patchesForClass = [NSMutableArray array];
                    groupedPatches[className] = patchesForClass;
                }
                [patchesForClass addObject:info];
            }
        }
    }

    if (groupedPatches.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无补丁可导出" message:@"当前没有已启用的返回值补丁。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSMutableString *logosFile = [NSMutableString stringWithString:@"// 由 ReveFlex 导出\n\n"];
    
    for (NSString *className in groupedPatches.allKeys) {
        [logosFile appendFormat:@"%%hook %@\n\n", className];
        
        for (RFPatchInfo *info in groupedPatches[className]) {
            // 获取静态地址并添加到注释，方便逆向分析
            IMP imp = method_getImplementation(info.method);
            vm_address_t staticAddress = get_static_address(imp);
            if (staticAddress > 0) {
                [logosFile appendFormat:@"// IDA / Hopper 静态地址: 0x%lx\n", staticAddress];
            }

            // 生成方法签名
            BOOL isClassMethod = class_isMetaClass(info.targetClass);
            NSString *methodSignature = [RFUtility formatMethod:info.method withPrefix:(isClassMethod ? "+" : "-")];
            [logosFile appendFormat:@"%@ {\n", methodSignature];
            
            // 生成返回语句
            id value = info.patchedValue;
            NSString *returnValueString;
            const char *typeEncoding = [info.returnTypeEncoding cStringUsingEncoding:NSUTF8StringEncoding];

            if ([value isKindOfClass:[NSString class]]) {
                // 对字符串中的特殊字符进行转义
                NSString *escapedString = [(NSString *)value stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
                escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
                returnValueString = [NSString stringWithFormat:@"@\"%@\"", escapedString];
            } else if ([value isKindOfClass:[NSNumber class]]) {
                if (strcmp(typeEncoding, @encode(BOOL)) == 0) {
                    returnValueString = [value boolValue] ? @"YES" : @"NO";
                } else {
                    returnValueString = [value stringValue];
                }
            } else if ([value isKindOfClass:[NSValue class]] && strcmp([value objCType], @encode(CGRect)) == 0) {
                CGRect rect = [value CGRectValue];
                returnValueString = [NSString stringWithFormat:@"CGRectMake(%g, %g, %g, %g)", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
            } else {
                returnValueString = [NSString stringWithFormat:@"(id)0x%lx; // Review required: complex type", (unsigned long)value];
            }
            
            [logosFile appendFormat:@"    return %@;\n", returnValueString];
            [logosFile appendString:@"}\n\n"];
        }
        
        [logosFile appendString:@"%end\n\n"];
    }
    
    // 分享生成的文件
    NSString *fileName = @"ReveFlex_Patches.xm";
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    [logosFile writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    activityVC.completionWithItemsHandler = ^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    };

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.bundleIdentifiers.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *bundleId = self.bundleIdentifiers[section];
    return [self.patchManager allPatchedMethodKeysForBundleIdentifier:bundleId].count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *bundleId = self.bundleIdentifiers[section];

    // 创建容器 View
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 44)];
    // 移除背景色，以适应 InsetGrouped 样式
    // headerView.backgroundColor = [UIColor systemGray5Color];

    // 创建 Label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = [self.patchManager displayNameForBundleIdentifier:bundleId];
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [headerView addSubview:titleLabel];

    // 创建 Switch
    UISwitch *toggleSwitch = [[UISwitch alloc] init];
    toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    toggleSwitch.on = [self.patchManager isApplicationPatchesEnabled:bundleId];
    toggleSwitch.tag = section; // 使用 tag 传递 section 索引
    [toggleSwitch addTarget:self action:@selector(toggleAppPatches:) forControlEvents:UIControlEventValueChanged];
    [headerView addSubview:toggleSwitch];

    // 设置布局约束
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:16],
        [titleLabel.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        
        [toggleSwitch.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-16],
        [toggleSwitch.centerYAnchor constraintEqualToAnchor:headerView.centerYAnchor],
        
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:toggleSwitch.leadingAnchor constant:-8]
    ]];

    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"PatchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        // 使用 Subtitle 风格以显示更详细的信息
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.textLabel.font = [UIFont systemFontOfSize:16.0];
        cell.detailTextLabel.numberOfLines = 0; // 允许多行显示
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    
    NSString *bundleId = self.bundleIdentifiers[indexPath.section];
    NSArray<NSString *> *keys = [self.patchManager allPatchedMethodKeysForBundleIdentifier:bundleId];
    NSString *key = keys[indexPath.row];
    
    RFPatchInfo *patchInfo = [self.patchManager patchInfoForKey:key forBundleIdentifier:bundleId];
    
    if (patchInfo) {
        // 从新的key格式 (+/-ClassName-MethodName) 中解析出类名和方法名
        NSString *prefix = [key hasPrefix:@"+"] || [key hasPrefix:@"-"] ? [key substringToIndex:1] : @"";
        NSString *keyBody = [prefix length] > 0 ? [key substringFromIndex:1] : key;

        NSRange separatorRange = [keyBody rangeOfString:@"-"];
        NSString *className;
        NSString *methodName;

        if (separatorRange.location != NSNotFound) {
            className = [keyBody substringToIndex:separatorRange.location];
            methodName = [keyBody substringFromIndex:separatorRange.location + 1];
        } else {
            // 为旧格式或无效格式提供回退
            className = @"未知类";
            methodName = keyBody;
        }
        
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", prefix, methodName];
        
        // 根据补丁类型显示不同的详细信息
        if (patchInfo.patchType == RFPatchTypeReturnValue) {
            id value = patchInfo.patchedValue;
            NSString *valueString;
            if ([value isKindOfClass:[NSValue class]] && strncmp([value objCType], @encode(CGRect), strlen(@encode(CGRect))) == 0) {
                valueString = NSStringFromCGRect([value CGRectValue]);
            } else {
                valueString = [value description] ?: @"nil";
            }
            cell.detailTextLabel.text = [NSString stringWithFormat:@"所属类: %@\n返回值 -> %@", className, valueString];
            
        } else if (patchInfo.patchType == RFPatchTypeArguments) {
            NSMutableString *argsString = [NSMutableString string];
            [patchInfo.argumentPatches enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull idx, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [argsString appendFormat:@"参数%@: %@; ", idx, [obj description] ?: @"nil"];
            }];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"所属类: %@\n参数 -> %@", className, argsString];
            
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"所属类: %@", className];
        }

    } else {
        cell.textLabel.text = @"无效的补丁";
        cell.detailTextLabel.text = key;
    }
    
    // 根据开关状态更新 Cell UI
    BOOL isEnabled = [self.patchManager isApplicationPatchesEnabled:bundleId];
    cell.userInteractionEnabled = isEnabled;
    cell.accessoryType = isEnabled ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    if (@available(iOS 13.0, *)) {
        cell.textLabel.textColor = isEnabled ? [UIColor labelColor] : [UIColor tertiaryLabelColor];
        cell.detailTextLabel.textColor = isEnabled ? [UIColor secondaryLabelColor] : [UIColor tertiaryLabelColor];
    } else {
        cell.textLabel.textColor = isEnabled ? [UIColor blackColor] : [UIColor grayColor];
        cell.detailTextLabel.textColor = isEnabled ? [UIColor darkGrayColor] : [UIColor grayColor];
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *bundleId = self.bundleIdentifiers[indexPath.section];
    return [self.patchManager isApplicationPatchesEnabled:bundleId];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    // canEditRowAtIndexPath 已经处理了禁用逻辑，但我们可以在这里再加一层保险
    NSString *bundleId = self.bundleIdentifiers[indexPath.section];
    if (![self.patchManager isApplicationPatchesEnabled:bundleId]) {
        return nil;
    }
    
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"恢复" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        
        NSString *bundleId = self.bundleIdentifiers[indexPath.section];
        NSArray<NSString *> *keys = [self.patchManager allPatchedMethodKeysForBundleIdentifier:bundleId];
        NSString *key = keys[indexPath.row];
        
        [self.patchManager unpatchMethodWithKey:key forBundleIdentifier:bundleId];
        
        [self reloadPatches]; // 重新加载以防整个 section 被删除
        
        completionHandler(YES);
    }];
    
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    return config;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // userInteractionEnabled 应该已经阻止了这里的调用，但作为安全措施，我们再次检查
    NSString *bundleId = self.bundleIdentifiers[indexPath.section];
    if (![self.patchManager isApplicationPatchesEnabled:bundleId]) {
        return;
    }
    
    NSArray<NSString *> *keys = [self.patchManager allPatchedMethodKeysForBundleIdentifier:bundleId];
    NSString *key = keys[indexPath.row];
    
    RFPatchInfo *patchInfo = [self.patchManager patchInfoForKey:key forBundleIdentifier:bundleId];

    if (!patchInfo || !patchInfo.method || !patchInfo.targetClass) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"无法修改此补丁，信息不完整。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [self showPatchValueInputForPatchInfo:patchInfo];
}

- (void)showPatchValueInputForPatchInfo:(RFPatchInfo *)patchInfo {
    char returnType[256];
    method_getReturnType(patchInfo.method, returnType, sizeof(returnType));
    
    NSString *title = @"修改返回值";
    NSString *message = [NSString stringWithFormat:@"请输入新的返回值 (类型: %s)", returnType];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    BOOL isCGRect = (strncmp(returnType, @encode(CGRect), strlen(@encode(CGRect))) == 0);

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        id value = patchInfo.patchedValue;
        if ([value isKindOfClass:[NSValue class]] && strncmp([value objCType], @encode(CGRect), strlen(@encode(CGRect))) == 0) {
            textField.text = NSStringFromCGRect([value CGRectValue]);
        } else {
            textField.text = [NSString stringWithFormat:@"%@", value];
        }
        
        if (isCGRect) {
            textField.placeholder = @"格式: {{x,y},{w,h}}";
        }
    }];

    char returnTypeChar = returnType[0];

    [alert addAction:[UIAlertAction actionWithTitle:@"应用" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *inputText = alert.textFields.firstObject.text;
        id valueToPatch = nil;

        if (isCGRect) {
            valueToPatch = [NSValue valueWithCGRect:CGRectFromString(inputText)];
        } else {
            switch (returnTypeChar) {
                case '@': valueToPatch = inputText; break;
                case 'B': valueToPatch = @([inputText boolValue]); break;
                case 'c': case 'i': case 's': case 'l': case 'q':
                case 'C': case 'I': case 'S': case 'L': case 'Q':
                    valueToPatch = @([inputText longLongValue]); break;
                case 'f': case 'd': valueToPatch = @([inputText doubleValue]); break;
                case '#': valueToPatch = inputText; break;
            }
        }

        if (valueToPatch) {
            BOOL success = [self.patchManager patchMethodReturnValue:patchInfo.method ofClass:patchInfo.targetClass withValue:valueToPatch];
            if (success) {
                [self reloadPatches]; // 刷新列表
            } else {
                // Handle error
            }
        }
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

// 添加unpatchAll方法实现
- (void)unpatchAll {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认恢复" 
                                                                   message:@"是否恢复所有已应用的补丁？此操作无法撤销。" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.patchManager unpatchAllMethods];
        [self reloadPatches];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// 添加toggleAppPatches:方法实现
- (void)toggleAppPatches:(UISwitch *)sender {
    NSInteger section = sender.tag;
    NSString *bundleId = self.bundleIdentifiers[section];
    [self.patchManager setApplicationPatchesEnabled:sender.isOn forBundleIdentifier:bundleId];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationAutomatic];
}

// 添加handlePatchesChanged:方法的实现
- (void)handlePatchesChanged:(NSNotification *)notification {
    // 确保在主线程上刷新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadPatches];
    });
}

@end 
