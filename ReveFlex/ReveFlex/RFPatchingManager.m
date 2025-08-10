#import "RFPatchingManager.h"
#import <UIKit/UIGeometry.h>
#import <objc/runtime.h>
#import <objc/message.h>

// 定义通知名称常量
NSString * const RFPatchingManagerDidUpdatePatchesNotification = @"RFPatchingManagerDidUpdatePatchesNotification";

#define kAutoSavedPatchesKey @"ReveFlex_AutoSavedPatches_v3"

#pragma mark - 桩函数 (Stub IMPs)

// 这些 C 函数将作为被修补方法的新实现 (IMP)
// 每个函数都针对特定的返回类型

static CGRect RFPatchedCGRectIMP(id self, SEL _cmd) {
    id value = [[RFPatchingManager sharedManager] patchedValueForObject:self selector:_cmd];
    if ([value isKindOfClass:[NSValue class]]) {
        return [value CGRectValue];
    }
    return CGRectZero;
}

static id RFPatchedObjectIMP(id self, SEL _cmd) {
    return [[RFPatchingManager sharedManager] patchedValueForObject:self selector:_cmd];
}

static BOOL RFPatchedBOOLIMP(id self, SEL _cmd) {
    id value = [[RFPatchingManager sharedManager] patchedValueForObject:self selector:_cmd];
    return [value boolValue];
}

static NSInteger RFPatchedIntegerIMP(id self, SEL _cmd) {
    id value = [[RFPatchingManager sharedManager] patchedValueForObject:self selector:_cmd];
    return [value integerValue];
}

static double RFPatchedDoubleIMP(id self, SEL _cmd) {
    id value = [[RFPatchingManager sharedManager] patchedValueForObject:self selector:_cmd];
    return [value doubleValue];
}

static Class RFPatchedClassIMP(id self, SEL _cmd) {
    id value = [[RFPatchingManager sharedManager] patchedValueForObject:self selector:_cmd];
    if ([value isKindOfClass:[NSString class]]) {
        return NSClassFromString(value);
    }
    return [value class];
}

#pragma mark - RFPatchInfo 实现

@implementation RFPatchInfo
@end

#pragma mark - RFPatchingManager 实现

@interface RFPatchingManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *applications;
@property (nonatomic, assign) BOOL isInitializing;
@end

@implementation RFPatchingManager

+ (instancetype)sharedManager {
    static RFPatchingManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _applications = [NSMutableDictionary dictionary];
        _isInitializing = YES;
        [self _loadPatchesFromUserDefaults];
        _isInitializing = NO;
    }
    return self;
}

- (NSString *)_getCurrentBundleIdentifier {
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown.bundle.id";
}

#pragma mark - Public API

- (BOOL)patchMethodReturnValue:(Method)method ofClass:(Class)cls withValue:(id)value {
    BOOL isClassMethod = class_isMetaClass(cls);
    Class baseClass = isClassMethod ? NSClassFromString(NSStringFromClass(cls)) : cls;
    SEL selector = method_getName(method);
    NSString *key = [NSString stringWithFormat:@"%@%@-%@", isClassMethod ? @"+" : @"-", NSStringFromClass(baseClass), NSStringFromSelector(selector)];

    NSString *bundleIdentifier = [[NSBundle bundleForClass:baseClass] bundleIdentifier] ?: [self _getCurrentBundleIdentifier];
    
    IMP stubIMP = NULL;
    char returnType[256];
    method_getReturnType(method, returnType, sizeof(returnType));
    
    if (strncmp(returnType, @encode(CGRect), strlen(@encode(CGRect))) == 0) {
        stubIMP = (IMP)RFPatchedCGRectIMP;
    } else {
        switch (returnType[0]) {
            case '@': stubIMP = (IMP)RFPatchedObjectIMP; break;
            case 'B': stubIMP = (IMP)RFPatchedBOOLIMP; break;
            case 'c': case 'i': case 's': case 'l': case 'q':
            case 'C': case 'I': case 'S': case 'L': case 'Q':
                stubIMP = (IMP)RFPatchedIntegerIMP; break;
            case 'f': case 'd': stubIMP = (IMP)RFPatchedDoubleIMP; break;
            case '#': stubIMP = (IMP)RFPatchedClassIMP; break;
            default: return NO;
        }
    }

    if (!stubIMP) return NO;
    
    NSMutableDictionary *appPatches = [self _getOrCreateAppPatchesForBundleId:bundleIdentifier];
    NSMutableDictionary *patches = appPatches[@"patches"];
    RFPatchInfo *info = patches[key];

    if (!info) {
        info = [[RFPatchInfo alloc] init];
        info.originalIMP = method_getImplementation(method);
    }
    
    info.isClassMethod = isClassMethod;
    info.patchType = RFPatchTypeReturnValue;
    info.patchedValue = value;
    info.argumentPatches = nil;
    info.returnTypeEncoding = [NSString stringWithUTF8String:returnType];
    info.method = method;
    info.targetClass = cls;
    info.bundleIdentifier = bundleIdentifier;
    
    patches[key] = info;
    method_setImplementation(method, stubIMP);
    [self _savePatchesToUserDefaults];
    return YES;
}

- (BOOL)patchMethodArgument:(Method)method ofClass:(Class)cls argumentIndex:(NSUInteger)argumentIndex withValue:(id)value {
    BOOL isClassMethod = class_isMetaClass(cls);
    Class baseClass = isClassMethod ? NSClassFromString(NSStringFromClass(cls)) : cls;
    SEL selector = method_getName(method);
    NSString *key = [NSString stringWithFormat:@"%@%@-%@", isClassMethod ? @"+" : @"-", NSStringFromClass(baseClass), NSStringFromSelector(selector)];
    
    NSString *bundleIdentifier = [[NSBundle bundleForClass:baseClass] bundleIdentifier] ?: [self _getCurrentBundleIdentifier];
    
    NSMutableDictionary *appPatches = [self _getOrCreateAppPatchesForBundleId:bundleIdentifier];
    NSMutableDictionary *patches = appPatches[@"patches"];
    RFPatchInfo *info = patches[key];

    if (!info) {
        info = [[RFPatchInfo alloc] init];
        info.originalIMP = method_getImplementation(method);
    }
    
    NSMutableDictionary *newArgs = info.argumentPatches ? [info.argumentPatches mutableCopy] : [NSMutableDictionary dictionary];
    newArgs[@(argumentIndex)] = value;
    info.argumentPatches = newArgs;
    
    info.isClassMethod = isClassMethod;
    info.patchType = RFPatchTypeArguments;
    info.method = method;
    info.targetClass = cls;
    info.bundleIdentifier = bundleIdentifier;
    
    patches[key] = info;
    [self _savePatchesToUserDefaults];
    
    return YES;
}

- (void)unpatchMethod:(Method)method ofClass:(Class)cls {
    BOOL isClassMethod = class_isMetaClass(cls);
    Class baseClass = isClassMethod ? NSClassFromString(NSStringFromClass(cls)) : cls;
    SEL selector = method_getName(method);
    NSString *key = [NSString stringWithFormat:@"%@%@-%@", isClassMethod ? @"+" : @"-", NSStringFromClass(baseClass), NSStringFromSelector(selector)];

    NSString *bundleIdentifier = [[NSBundle bundleForClass:baseClass] bundleIdentifier] ?: [self _getCurrentBundleIdentifier];

    NSMutableDictionary *appPatches = self.applications[bundleIdentifier];
    NSMutableDictionary *patches = appPatches[@"patches"];
    RFPatchInfo *info = patches[key];
    
    if (info && info.originalIMP) {
        method_setImplementation(method, info.originalIMP);
        [patches removeObjectForKey:key];
        
        if (patches.count == 0) {
            [self.applications removeObjectForKey:bundleIdentifier];
        }
        [self _savePatchesToUserDefaults];
    }
}

- (BOOL)isMethodPatched:(Method)method ofClass:(Class)cls {
    BOOL isClassMethod = class_isMetaClass(cls);
    Class baseClass = isClassMethod ? NSClassFromString(NSStringFromClass(cls)) : cls;
    SEL selector = method_getName(method);
    NSString *key = [NSString stringWithFormat:@"%@%@-%@", isClassMethod ? @"+" : @"-", NSStringFromClass(baseClass), NSStringFromSelector(selector)];
    
    NSString *bundleIdentifier = [[NSBundle bundleForClass:baseClass] bundleIdentifier] ?: [self _getCurrentBundleIdentifier];
    
    if (![self isApplicationPatchesEnabled:bundleIdentifier]) {
        return NO;
    }
    
    return self.applications[bundleIdentifier][@"patches"][key] != nil;
}

- (nullable RFPatchInfo *)patchInfoForMethod:(Method)method ofClass:(Class)cls {
    BOOL isClassMethod = class_isMetaClass(cls);
    Class baseClass = isClassMethod ? NSClassFromString(NSStringFromClass(cls)) : cls;
    SEL selector = method_getName(method);
    NSString *key = [NSString stringWithFormat:@"%@%@-%@", isClassMethod ? @"+" : @"-", NSStringFromClass(baseClass), NSStringFromSelector(selector)];

    NSString *bundleIdentifier = [[NSBundle bundleForClass:baseClass] bundleIdentifier] ?: [self _getCurrentBundleIdentifier];
    
    return self.applications[bundleIdentifier][@"patches"][key];
}

- (nullable id)patchedValueForObject:(id)object selector:(SEL)selector {
    BOOL isClassMethod = object_isClass(object);
    Class objectClass = isClassMethod ? object : [object class];
    
    Class bundleClass = isClassMethod ? NSClassFromString(NSStringFromClass(objectClass)) : objectClass;
    NSString *bundleIdentifier = [[NSBundle bundleForClass:bundleClass] bundleIdentifier];
    if (!bundleIdentifier) {
        bundleIdentifier = [self _getCurrentBundleIdentifier];
    }

    if (![self isApplicationPatchesEnabled:bundleIdentifier]) {
        return nil;
    }

    Class currentClass = objectClass;
    while (currentClass) {
        NSString *className = NSStringFromClass(currentClass);

        NSString *key = [NSString stringWithFormat:@"%@%@-%@",
                         isClassMethod ? @"+" : @"-",
                         className,
                         NSStringFromSelector(selector)];

        RFPatchInfo *info = self.applications[bundleIdentifier][@"patches"][key];
        if (info) {
            return info.patchedValue;
        }
        
        currentClass = class_getSuperclass(currentClass);
    }
    
    return nil;
}

- (BOOL)patchMethodWithSelector:(SEL)selector ofClass:(Class)cls isClassMethod:(BOOL)isClassMethod returnValue:(id)value {
    Class targetClass = isClassMethod ? object_getClass(cls) : cls;
    
    Method method = class_getInstanceMethod(targetClass, selector);
    if (!method) {
        if (isClassMethod) {
            method = class_getClassMethod(cls, selector);
        }
        if (!method) {
            return NO;
        }
    }
    
    return [self patchMethodReturnValue:method ofClass:targetClass withValue:value];
}

#pragma mark - 新的补丁管理API (按App分组)

- (NSArray<NSString *> *)allPatchedBundleIdentifiers {
    return [self.applications.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray<NSString *> *)allPatchedMethodKeysForBundleIdentifier:(NSString *)bundleIdentifier {
    NSDictionary *patches = self.applications[bundleIdentifier][@"patches"];
    return [patches.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (void)unpatchMethodWithKey:(NSString *)key forBundleIdentifier:(NSString *)bundleIdentifier {
    NSMutableDictionary *appPatches = self.applications[bundleIdentifier];
    NSMutableDictionary *patches = appPatches[@"patches"];
    RFPatchInfo *info = patches[key];

    if (!info) return;

    if (info.method && info.originalIMP) {
        method_setImplementation(info.method, info.originalIMP);
        [patches removeObjectForKey:key];
        if (patches.count == 0) {
            [self.applications removeObjectForKey:bundleIdentifier];
        }
        [self _savePatchesToUserDefaults];
    }
}

- (nullable RFPatchInfo *)patchInfoForKey:(NSString *)key forBundleIdentifier:(NSString *)bundleIdentifier {
    return self.applications[bundleIdentifier][@"patches"][key];
}

- (BOOL)isApplicationPatchesEnabled:(NSString *)bundleIdentifier {
    return [self.applications[bundleIdentifier][@"enabled"] boolValue];
}

- (void)setApplicationPatchesEnabled:(BOOL)enabled forBundleIdentifier:(NSString *)bundleIdentifier {
    NSMutableDictionary *appInfo = self.applications[bundleIdentifier];
    if (!appInfo) return;
    
    appInfo[@"enabled"] = @(enabled);
    
    NSDictionary *patches = appInfo[@"patches"];
    for (NSString *key in patches) {
        RFPatchInfo *info = patches[key];
        if (enabled) {
            [self patchMethodReturnValue:info.method ofClass:info.targetClass withValue:info.patchedValue];
        } else {
            if (info.originalIMP) {
                method_setImplementation(info.method, info.originalIMP);
            }
        }
    }
    [self _savePatchesToUserDefaults];
}

- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier {
    NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleIdentifier];
    NSString *displayName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!displayName) {
        displayName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
    }
    return displayName ?: bundleIdentifier;
}

- (void)unpatchAllMethods {
    for (NSString *bundleId in [self.applications allKeys]) {
        NSMutableDictionary *appInfo = self.applications[bundleId];
        NSMutableDictionary *patches = appInfo[@"patches"];
        
        for (NSString *key in [patches allKeys]) {
            RFPatchInfo *info = patches[key];
            if (info.originalIMP && info.method) {
                method_setImplementation(info.method, info.originalIMP);
            }
        }
    }
    [self.applications removeAllObjects];
    [self _savePatchesToUserDefaults];
}

#pragma mark - 序列化/反序列化

- (nullable NSString *)exportPatchesToJSON:(NSError **)error {
    if (self.applications.count == 0) {
        if (error) *error = [NSError errorWithDomain:@"ReveFlex" code:100 userInfo:@{NSLocalizedDescriptionKey: @"没有可导出的补丁"}];
        return nil;
    }

    NSMutableDictionary *appsToExport = [NSMutableDictionary dictionary];
    for (NSString *bundleId in self.applications) {
        NSDictionary *appInfo = self.applications[bundleId];
        NSDictionary *patches = appInfo[@"patches"];
        
        NSMutableArray *patchesArray = [NSMutableArray array];
        for (NSString *key in patches) {
            RFPatchInfo *info = patches[key];
            id valueForJSON;
            const char *type = [info.returnTypeEncoding cStringUsingEncoding:NSUTF8StringEncoding];

            if (strncmp(type, @encode(CGRect), strlen(@encode(CGRect))) == 0) {
                valueForJSON = NSStringFromCGRect([info.patchedValue CGRectValue]);
            } else {
                valueForJSON = info.patchedValue;
            }
            
            Class baseClass = info.isClassMethod ? NSClassFromString(NSStringFromClass(info.targetClass)) : info.targetClass;

            NSDictionary *patchDict = @{
                @"patchType": @(info.patchType),
                @"className": NSStringFromClass(baseClass),
                @"methodName": NSStringFromSelector(method_getName(info.method)),
                @"isClassMethod": @(info.isClassMethod),
                @"returnType": info.returnTypeEncoding,
                @"patchedValue": valueForJSON ?: [NSNull null],
                @"argumentPatches": info.argumentPatches ?: [NSNull null]
            };
            [patchesArray addObject:patchDict];
        }
        
        appsToExport[bundleId] = @{
            @"enabled": appInfo[@"enabled"],
            @"patches": patchesArray
        };
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:appsToExport options:NSJSONWritingPrettyPrinted error:error];
    if (!jsonData) return nil;
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSInteger)applyPatchesFromJSON:(NSString *)jsonString error:(NSError **)error {
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *appsToImport = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];

    if (!appsToImport || ![appsToImport isKindOfClass:[NSDictionary class]]) {
        return 0;
    }

    NSInteger totalAppliedCount = 0;
    for (NSString *bundleId in appsToImport) {
        NSDictionary *appInfo = appsToImport[bundleId];
        BOOL isEnabled = [appInfo[@"enabled"] boolValue];
        NSArray *patchesArray = appInfo[@"patches"];

        if (![patchesArray isKindOfClass:[NSArray class]]) continue;
        
        NSMutableDictionary *loadedPatches = [NSMutableDictionary dictionary];

        for (NSDictionary *patchDict in patchesArray) {
            NSString *className = patchDict[@"className"];
            NSString *methodName = patchDict[@"methodName"];
            NSString *returnTypeStr = patchDict[@"returnType"];
            id patchedValueFromJSON = patchDict[@"patchedValue"];
            
            BOOL isClassMethod = NO;
            if (patchDict[@"isClassMethod"]) {
                isClassMethod = [patchDict[@"isClassMethod"] boolValue];
            }

            if (!className || !methodName || !returnTypeStr || !patchedValueFromJSON) continue;
            
            Class baseClass = NSClassFromString(className);
            if (!baseClass) continue;

            SEL selector = NSSelectorFromString(methodName);
            Method method;
            
            if (isClassMethod) {
                method = class_getClassMethod(baseClass, selector);
            } else {
                method = class_getInstanceMethod(baseClass, selector);
            }

            if (!method) continue;

            id valueToPatch;
            const char *type = [returnTypeStr cStringUsingEncoding:NSUTF8StringEncoding];

            if (strncmp(type, @encode(CGRect), strlen(@encode(CGRect))) == 0) {
                valueToPatch = [NSValue valueWithCGRect:CGRectFromString(patchedValueFromJSON)];
            } else if (type[0] == '@' || type[0] == '#') {
                valueToPatch = patchedValueFromJSON;
            } else if (type[0] == 'B') {
                valueToPatch = @([patchedValueFromJSON boolValue]);
            } else if (strchr("cislqCISLQ", type[0])) {
                valueToPatch = @([patchedValueFromJSON longLongValue]);
            } else if (strchr("fd", type[0])) {
                valueToPatch = @([patchedValueFromJSON doubleValue]);
            } else {
                continue;
            }
            
            Class targetClass = isClassMethod ? object_getClass(baseClass) : baseClass;

            if (valueToPatch) {
                RFPatchInfo *info = [[RFPatchInfo alloc] init];
                info.originalIMP = method_getImplementation(method);
                info.patchedValue = valueToPatch;
                info.returnTypeEncoding = returnTypeStr;
                info.method = method;
                info.targetClass = targetClass;
                info.bundleIdentifier = bundleId;
                info.isClassMethod = isClassMethod;
                
                NSString *key = [NSString stringWithFormat:@"%@%@-%@", isClassMethod ? @"+" : @"-", className, methodName];
                loadedPatches[key] = info;

                if (isEnabled) {
                    [self patchMethodReturnValue:method ofClass:targetClass withValue:valueToPatch];
                    totalAppliedCount++;
                }
            }
        }
        
        if (loadedPatches.count > 0) {
            self.applications[bundleId] = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                           @(isEnabled), @"enabled",
                                           loadedPatches, @"patches",
                                           nil];
        }
    }
    
    if (appsToImport.count == 0 && jsonString.length > 0) {
        [self.applications removeAllObjects];
    }
    [self _savePatchesToUserDefaults];

    return totalAppliedCount;
}

#pragma mark - 持久化

- (void)_savePatchesToUserDefaults {
    if (self.isInitializing) return;

    NSError *error = nil;
    NSString *jsonString = [self exportPatchesToJSON:&error];
    if (jsonString && !error) {
        [[NSUserDefaults standardUserDefaults] setObject:jsonString forKey:kAutoSavedPatchesKey];
    } else {
        if (self.applications.count == 0) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAutoSavedPatchesKey];
        }
    }
    
    if (!self.isInitializing) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RFPatchingManagerDidUpdatePatchesNotification object:nil];
    }
}

- (void)_loadPatchesFromUserDefaults {
    NSString *jsonString = [[NSUserDefaults standardUserDefaults] stringForKey:kAutoSavedPatchesKey];
    if (jsonString.length > 0) {
        [self applyPatchesFromJSON:jsonString error:nil];
    }
}

- (NSMutableDictionary *)_getOrCreateAppPatchesForBundleId:(NSString *)bundleId {
    NSMutableDictionary *appPatches = self.applications[bundleId];
    if (!appPatches) {
        appPatches = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                      @(YES), @"enabled",
                      [NSMutableDictionary dictionary], @"patches",
                      nil];
        self.applications[bundleId] = appPatches;
    }
    return appPatches;
}

@end 