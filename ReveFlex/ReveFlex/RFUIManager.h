#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFUIManager : NSObject

/**
 Installs the ReveFlex entry point (a draggable button) into the application's key window.
 This method should be called once at application startup.
 */
+ (void)install;

/**
 Presents the main ReveFlex user interface.
 */
+ (void)showExplorer;

/**
 Dismisses the main ReveFlex user interface.
 */
+ (void)dismissExplorer;

/**
 Shows the global search UI, presented from a given view controller.
 @param viewController The view controller from which to present the search UI.
 */
+ (void)showGlobalSearchFromViewController:(UIViewController *)viewController;

+ (void)setupGestureRecognizer;

@end

NS_ASSUME_NONNULL_END 