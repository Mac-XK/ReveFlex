#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFPatchDetailViewController : UIViewController

- (instancetype)initWithMethod:(Method)method
                       ofClass:(Class)targetClass
                 isClassMethod:(BOOL)isClassMethod;

@end

NS_ASSUME_NONNULL_END 