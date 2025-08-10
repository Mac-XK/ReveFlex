#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFDraggableView : UIView

/**
 The main view controller for the ReveFlex UI, which will be presented upon tapping the button.
 */
@property (nonatomic, strong) UIViewController *mainViewController;

/**
 A block that will be executed when the button is tapped.
 Use this to present the mainViewController.
 */
@property (nonatomic, copy) void (^tapHandler)(void);

/**
 Initializes the draggable view and adds it to the specified window.
 @param window The key window of the application.
 @return An instance of RFDraggableView.
 */
- (instancetype)initWithWindow:(UIWindow *)window;

@end

NS_ASSUME_NONNULL_END 