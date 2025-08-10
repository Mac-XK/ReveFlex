#import "RFUtility.h"

@implementation RFUtility

+ (NSString *)decodeType:(const char *)typeEncoding {
    if (typeEncoding == NULL) return @"(unknown)";
    switch (typeEncoding[0]) {
        case '@': {
            if (strlen(typeEncoding) > 2) {
                char className[256];
                sscanf(typeEncoding, "@\"%[^\"]\"", className);
                return [NSString stringWithFormat:@"%s *", className];
            }
            return @"id";
        }
        case 'c': return @"char";
        case 'i': return @"int";
        case 's': return @"short";
        case 'l': return @"long";
        case 'q': return @"long long";
        case 'C': return @"unsigned char";
        case 'I': return @"unsigned int";
        case 'S': return @"unsigned short";
        case 'L': return @"unsigned long";
        case 'Q': return @"unsigned long long";
        case 'f': return @"float";
        case 'd': return @"double";
        case 'B': return @"BOOL";
        case 'v': return @"void";
        case '*': return @"char *";
        case '#': return @"Class";
        case ':': return @"SEL";
        case '{': {
            char structName[256];
            sscanf(typeEncoding, "{%[^=]", structName);
            return [NSString stringWithFormat:@"struct %s", structName];
        }
        default: return [NSString stringWithUTF8String:typeEncoding];
    }
}

+ (NSString *)formatMethod:(Method)method withPrefix:(const char *)prefix {
    SEL selector = method_getName(method);
    NSMutableString *formatted = [NSMutableString stringWithFormat:@"%s ", prefix];

    char returnType[256];
    method_getReturnType(method, returnType, sizeof(returnType));
    [formatted appendFormat:@"(%@)", [self decodeType:returnType]];
    
    NSString *selectorString = NSStringFromSelector(selector);
    NSArray *components = [selectorString componentsSeparatedByString:@":"];
    
    unsigned int argCount = method_getNumberOfArguments(method);
    if (argCount <= 2) {
        [formatted appendString:selectorString];
    } else {
        for (unsigned int i = 2; i < argCount; i++) {
            char argType[256];
            method_getArgumentType(method, i, argType, sizeof(argType));
            NSString *component = (i-2 < components.count) ? components[i-2] : @"";
            [formatted appendFormat:@"%@:(%@)arg%d ", component, [self decodeType:argType], i-2];
        }
    }
    
    return [formatted stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (NSString *)formatProperty:(objc_property_t)property {
    const char *name = property_getName(property);
    const char *attrs = property_getAttributes(property);
    
    NSString *attrString = [NSString stringWithUTF8String:attrs];
    NSArray *attrParts = [attrString componentsSeparatedByString:@","];
    
    NSMutableString *attributes = [NSMutableString string];
    NSString *typeName = @"";

    for (NSString *part in attrParts) {
        if ([part hasPrefix:@"T"]) {
            typeName = [self decodeType:[part cStringUsingEncoding:NSUTF8StringEncoding] + 1];
        } else if ([part isEqualToString:@"R"]) {
            [attributes appendString:@"readonly, "];
        } else if ([part isEqualToString:@"C"]) {
            [attributes appendString:@"copy, "];
        } else if ([part isEqualToString:@"&"]) {
            [attributes appendString:@"strong, "];
        } else if ([part isEqualToString:@"W"]) {
            [attributes appendString:@"weak, "];
        } else if ([part isEqualToString:@"N"]) {
            [attributes appendString:@"nonatomic, "];
        }
    }
    
    NSString *finalAttrs = @"";
    if (attributes.length > 0) {
        finalAttrs = [NSString stringWithFormat:@"(%@)", [attributes substringToIndex:attributes.length - 2]];
    }

    return [NSString stringWithFormat:@"@property %@ %@ %s;", finalAttrs, typeName, name];
}

+ (NSString *)formatMethodForLogos:(Method)method withPrefix:(const char *)prefix {
    SEL selector = method_getName(method);
    NSMutableString *formatted = [NSMutableString stringWithFormat:@"%s ", prefix];

    char returnType[256];
    method_getReturnType(method, returnType, sizeof(returnType));
    [formatted appendFormat:@"(%@)", [self decodeType:returnType]];
    
    NSString *selectorString = NSStringFromSelector(selector);
    NSArray *components = [selectorString componentsSeparatedByString:@":"];
    
    unsigned int argCount = method_getNumberOfArguments(method);
    if (argCount <= 2) {
        [formatted appendString:selectorString];
    } else {
        for (unsigned int i = 2; i < argCount; i++) {
            char argType[256];
            method_getArgumentType(method, i, argType, sizeof(argType));
            NSString *component = (i-2 < components.count) ? components[i-2] : @"";
            [formatted appendFormat:@"%@:(%@)arg%d ", component, [self decodeType:argType], i-1]; // arg name changed to arg1, arg2...
        }
    }
    
    return [formatted stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@end 