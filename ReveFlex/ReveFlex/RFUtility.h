#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFUtility : NSObject

/// 将 Objective-C 类型编码转换为人类可读的字符串
+ (NSString *)decodeType:(const char *)typeEncoding;

/// 将 Method 格式化为 class-dump 风格的字符串
+ (NSString *)formatMethod:(Method)method withPrefix:(const char *)prefix;

/// 将 objc_property_t 格式化为 class-dump 风格的字符串
+ (NSString *)formatProperty:(objc_property_t)property;

/// 将 Method 格式化为适用于 Logos 的字符串
+ (NSString *)formatMethodForLogos:(Method)method withPrefix:(const char *)prefix;

@end

NS_ASSUME_NONNULL_END 