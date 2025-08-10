#import "RFPatchDetailViewController.h"
#import "RFPatchingManager.h"
#import "RFUtility.h"
#import <objc/runtime.h>

// 添加 NSString 分类，以提供缺少的转换方法
@interface NSString (TypeConversion)
- (char)charValue;
- (short)shortValue;
- (long)longValue;
- (unsigned char)unsignedCharValue;
- (unsigned int)unsignedIntValue;
- (unsigned short)unsignedShortValue;
- (unsigned long)unsignedLongValue;
- (unsigned long long)unsignedLongLongValue;
@end

@implementation NSString (TypeConversion)
- (char)charValue {
    return (char)[self intValue];
}

- (short)shortValue {
    return (short)[self intValue];
}

- (long)longValue {
    return (long)[self longLongValue];
}

- (unsigned char)unsignedCharValue {
    return (unsigned char)[self intValue];
}

- (unsigned short)unsignedShortValue {
    return (unsigned short)[self intValue];
}

- (unsigned int)unsignedIntValue {
    return (unsigned int)[self intValue];
}

- (unsigned long)unsignedLongValue {
    return (unsigned long)[self longLongValue];
}

- (unsigned long long)unsignedLongLongValue {
    return strtoull([self UTF8String], NULL, 0);
}
@end

@interface RFPatchDetailViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) Method method;
@property (nonatomic, assign) Class targetClass;
@property (nonatomic, assign) BOOL isClassMethod;
@property (nonatomic, strong) NSMutableArray<NSString *> *argumentValues;
@property (nonatomic, strong) NSString *returnValue;

@end

@implementation RFPatchDetailViewController

- (instancetype)initWithMethod:(Method)method ofClass:(Class)targetClass isClassMethod:(BOOL)isClassMethod {
    self = [super init];
    if (self) {
        _method = method;
        _targetClass = targetClass;
        _isClassMethod = isClassMethod;
        _argumentValues = [NSMutableArray array];
        
        // 确保方法存在并获取参数数量
        if (method) {
            unsigned int argCount = method_getNumberOfArguments(method);
            for (unsigned int i = 2; i < argCount; i++) {
                [_argumentValues addObject:@""]; // 初始化为空字符串
            }

            char returnType[256];
            method_getReturnType(method, returnType, sizeof(returnType));
            if (returnType[0] != 'v') {
                _returnValue = @""; // 初始化为空字符串
            }
        } else {
            NSLog(@"[ReveFlex Warning] Method is nil in RFPatchDetailViewController init");
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"修改方法";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    [self setupTableView];
    [self setupNavigationBar];
    [self loadExistingPatches];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (void)setupNavigationBar {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"应用" style:UIBarButtonItemStyleDone target:self action:@selector(applyPatches)];
}

- (void)loadExistingPatches {
    // 根据是类方法还是实例方法，获取正确的类对象
    Class cls = self.isClassMethod ? object_getClass(self.targetClass) : self.targetClass;
    
    RFPatchInfo *patchInfo = [[RFPatchingManager sharedManager] patchInfoForMethod:self.method ofClass:cls];
    if (patchInfo) {
        // 加载返回值
        if (patchInfo.patchedValue) {
            if ([patchInfo.patchedValue isKindOfClass:[NSValue class]] && strncmp([patchInfo.patchedValue objCType], @encode(CGRect), strlen(@encode(CGRect))) == 0) {
                self.returnValue = NSStringFromCGRect([patchInfo.patchedValue CGRectValue]);
            } else {
                self.returnValue = [patchInfo.patchedValue description];
            }
        }
        
        // 加载参数值
        if (patchInfo.argumentPatches) {
            [patchInfo.argumentPatches enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                NSUInteger index = [key unsignedIntegerValue];
                if (index < self.argumentValues.count) {
                    self.argumentValues[index] = [obj description];
                }
            }];
        }
    }
}

- (void)applyPatches {
    // 强制结束编辑，确保所有输入框的值都已保存到属性中
    [self.view endEditing:YES];

    RFPatchingManager *manager = [RFPatchingManager sharedManager];
    
    // 根据是类方法还是实例方法，获取正确的类对象
    Class cls = self.isClassMethod ? object_getClass(self.targetClass) : self.targetClass;
    
    // 应用返回值补丁
    if (self.returnValue != nil) {
        char returnType[256];
        method_getReturnType(self.method, returnType, sizeof(returnType));
        id value = [self valueFromString:self.returnValue forType:returnType];
        
        BOOL isObjectType = (returnType[0] == '@' || returnType[0] == '#');

        if (value || (isObjectType && !value)) {
            // 使用更简单的API直接应用补丁，避免复杂的方法交换
            if (self.isClassMethod) {
                [manager patchMethodWithSelector:method_getName(self.method) 
                                         ofClass:self.targetClass 
                                   isClassMethod:YES 
                                     returnValue:value];
            } else {
                [manager patchMethodReturnValue:self.method
                                        ofClass:cls
                                      withValue:value];
            }
        } else {
            NSLog(@"[ReveFlex Debug] Failed to create value from string '%@' for type encoding '%s'.", self.returnValue, returnType);
        }
    }
    
    // 应用参数补丁
    for (int i = 0; i < self.argumentValues.count; i++) {
        NSString *stringValue = self.argumentValues[i];
        if (stringValue && stringValue.length > 0) {
            unsigned int argIndex = i + 2;
            char argType[256];
            method_getArgumentType(self.method, argIndex, argType, sizeof(argType));
            id value = [self valueFromString:stringValue forType:argType];
            if (value) {
                [manager patchMethodArgument:self.method
                                     ofClass:cls
                               argumentIndex:i
                                   withValue:value];
            } else {
                 NSLog(@"[ReveFlex Debug] Failed to create argument value from string '%@' for type encoding '%s'.", stringValue, argType);
            }
        }
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

// 辅助方法：将字符串转换为特定类型的值
- (nullable id)valueFromString:(NSString *)string forType:(const char *)typeEncoding {
    if (!string || string.length == 0) {
        // For most primitive types, an empty string can be interpreted as 0.
        switch (typeEncoding[0]) {
            case '@': // Treat empty string as nil for objects
            case '#': // Treat empty string as nil for classes
                return nil;
            case ':': // Selectors should not be nil from empty string
                return nil;
            case '{': // Structs - CGRectFromString handles empty string fine
                break;
            default: // Other primitives
                string = @"0";
                break;
        }
    }
    
    switch (typeEncoding[0]) {
        case '@':
            // If user explicitly types "nil", treat it as nil
            if ([string caseInsensitiveCompare:@"nil"] == NSOrderedSame) {
                return nil;
            }
            return string;
        case '#': return NSClassFromString(string);
        case ':': return (id)NSStringFromSelector(NSSelectorFromString(string));
        case 'c': return @([string charValue]);
        case 'i': return @([string intValue]);
        case 's': return @([string shortValue]);
        case 'l': return @([string longValue]);
        case 'q': return @([string longLongValue]);
        case 'C': return @([string unsignedCharValue]);
        case 'I': return @([string unsignedIntValue]);
        case 'S': return @([string unsignedShortValue]);
        case 'L': return @([string unsignedLongValue]);
        case 'Q': return @([string unsignedLongLongValue]);
        case 'f': return @([string floatValue]);
        case 'd': return @([string doubleValue]);
        case 'B': return @([string boolValue]);
        case '{': // 结构体 (目前仅支持CGRect)
            if (strncmp(typeEncoding, @encode(CGRect), strlen(@encode(CGRect))) == 0) {
                return [NSValue valueWithCGRect:CGRectFromString(string)];
            }
            return nil;
        default:
            return nil;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    char returnType[256];
    method_getReturnType(self.method, returnType, sizeof(returnType));
    BOOL hasReturnValue = (returnType[0] != 'v');
    
    // 1. 方法签名, 2. 参数, 3. 返回值 (可选)
    return 2 + (hasReturnValue ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { // 方法签名
        return 1;
    } else if (section == 1) { // 参数
        return method_getNumberOfArguments(self.method) - 2;
    } else { // 返回值
        return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"方法签名";
    } else if (section == 1) {
        return @"参数";
    } else {
        return @"返回值";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * const SignatureCellID = @"SignatureCell";
    static NSString * const InputCellID = @"InputCell";

    if (indexPath.section == 0) { // 方法签名
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SignatureCellID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SignatureCellID];
            cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:12];
            cell.textLabel.numberOfLines = 0;
            cell.userInteractionEnabled = NO;
        }
        const char *prefix = self.isClassMethod ? "+" : "-";
        cell.textLabel.text = [RFUtility formatMethod:self.method withPrefix:prefix];
        return cell;
    } else { // 参数和返回值
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:InputCellID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:InputCellID];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectInset(cell.contentView.bounds, 15, 0)];
            textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            textField.textAlignment = NSTextAlignmentRight;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            [cell.contentView addSubview:textField];
        }

        UITextField *textField = (UITextField *)[cell.contentView.subviews lastObject];
        
        if (indexPath.section == 1) { // 参数
            unsigned int argIndex = indexPath.row + 2;
            char argType[256];
            method_getArgumentType(self.method, argIndex, argType, sizeof(argType));
            NSString *typeName = [RFUtility decodeType:argType];
            
            cell.textLabel.text = [NSString stringWithFormat:@"参数 %lu (%@)", (unsigned long)indexPath.row, typeName];
            textField.text = self.argumentValues[indexPath.row];
            textField.tag = indexPath.row; // Tag for argument index
        } else { // 返回值
            char returnType[256];
            method_getReturnType(self.method, returnType, sizeof(returnType));
            NSString *typeName = [RFUtility decodeType:returnType];

            cell.textLabel.text = [NSString stringWithFormat:@"返回值 (%@)", typeName];
            textField.text = self.returnValue;
            textField.tag = -1; // Special tag for return value
        }
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Do nothing, cells are not selectable
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.tag == -1) { // 返回值
        self.returnValue = textField.text;
    } else if (textField.tag >= 0 && textField.tag < self.argumentValues.count) { // 参数
        self.argumentValues[textField.tag] = textField.text;
    }
}

@end 