#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RFSearchResultsViewController : UITableViewController <UISearchResultsUpdating>

- (instancetype)initWithResults:(NSArray<NSDictionary *> *)results title:(NSString *)title;

@end

NS_ASSUME_NONNULL_END 