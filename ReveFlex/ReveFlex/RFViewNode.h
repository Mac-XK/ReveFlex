#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFViewNode : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, copy) NSString *displayString;
@property (nonatomic, copy, nullable) NSString *searchMatchContext;
@end

NS_ASSUME_NONNULL_END 