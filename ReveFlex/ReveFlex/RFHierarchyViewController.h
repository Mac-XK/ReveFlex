#import <UIKit/UIKit.h>
#import "RFPatchListViewController.h"

@class RFViewNode;

NS_ASSUME_NONNULL_BEGIN

@interface RFHierarchyViewController : UIViewController <UISearchBarDelegate, UIDocumentPickerDelegate>
@property (nonatomic, strong) NSArray<RFViewNode *> *viewNodes;
@end

NS_ASSUME_NONNULL_END 