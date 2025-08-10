#import "RFHierarchyViewController.h"
#import "RFDetailViewController.h"
#import "RFViewNode.h"
#import "RFUIManager.h"
#import "RFPatchingManager.h"
#import <objc/runtime.h>

@interface RFHierarchyViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) NSArray<RFViewNode *> *filteredViewNodes; // 用于存放过滤后的结果
@end

@implementation RFHierarchyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 搜索框
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.placeholder = @"搜索视图文本、类名、标识符...";
    UITextField *searchTextField = [self.searchBar valueForKey:@"searchField"];
    if (searchTextField) {
        searchTextField.textColor = [UIColor whiteColor];
    }
    self.navigationItem.titleView = self.searchBar;
    
    // Setup navigation bar buttons
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(close)];
    UIBarButtonItem *patchCenterButton = [[UIBarButtonItem alloc] initWithTitle:@"补丁中心" style:UIBarButtonItemStylePlain target:self action:@selector(showPatchCenter)];
    UIBarButtonItem *loadButton = [[UIBarButtonItem alloc] initWithTitle:@"加载" style:UIBarButtonItemStylePlain target:self action:@selector(loadPatchSet)];
    
    self.navigationItem.rightBarButtonItems = @[closeButton, patchCenterButton];
    self.navigationItem.leftBarButtonItem = loadButton;

    self.view.backgroundColor = [UIColor clearColor];
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = self.view.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.blurView];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44.0;
    [self.blurView.contentView addSubview:self.tableView];
    
    // 初始状态下，显示所有节点
    self.filteredViewNodes = self.viewNodes;
}

- (void)close {
    // This now needs to call the UIManager to properly handle state
    [RFUIManager dismissExplorer];
}

- (void)showPatchCenter {
    RFPatchListViewController *patchVC = [[RFPatchListViewController alloc] init];
    [self.navigationController pushViewController:patchVC animated:YES];
}

#pragma mark - 补丁集加载

- (void)loadPatchSet {
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json", @"public.text"] inMode:UIDocumentPickerModeImport];
    documentPicker.delegate = self;
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    
    // 确保在完成选择后可以访问文件
    BOOL success = [url startAccessingSecurityScopedResource];
    
    NSError *readError = nil;
    NSString *jsonString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&readError];
    
    if (success) {
        [url stopAccessingSecurityScopedResource];
    }
    
    if (!jsonString) {
        // Show error alert
        return;
    }
    
    NSError *applyError = nil;
    NSInteger appliedCount = [[RFPatchingManager sharedManager] applyPatchesFromJSON:jsonString error:&applyError];
    
    NSString *message = applyError ? applyError.localizedDescription : [NSString stringWithFormat:@"成功应用了 %ld 个补丁。", (long)appliedCount];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"加载完成" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // User cancelled the picker.
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredViewNodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"ViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:13];
        cell.textLabel.numberOfLines = 0;
        
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:1.0];
        cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:12];
        cell.detailTextLabel.numberOfLines = 0;

        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    RFViewNode *node = self.filteredViewNodes[indexPath.row];
    
    cell.textLabel.text = node.displayString;
    cell.detailTextLabel.text = node.searchMatchContext;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RFViewNode *node = self.filteredViewNodes[indexPath.row];
    if (!node.view) return;

    NSString *title = [NSString stringWithFormat:@"<%@: %p>", [node.view class], node.view];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"详细信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        RFDetailViewController *detailVC = [[RFDetailViewController alloc] initWithClass:node.view.class object:node.view];
        [self.navigationController pushViewController:detailVC animated:YES];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"复制类名" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = NSStringFromClass([node.view class]);
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredViewNodes = self.viewNodes;
    } else {
        NSMutableArray<RFViewNode *> *filteredNodes = [NSMutableArray array];
        for (RFViewNode *originalNode in self.viewNodes) {
            
            NSString *matchReason = nil;
            UIView *targetView = originalNode.view;
            if (!targetView) continue;

            // 维度1: 搜索视图文本
            NSString *viewText = nil;
            if ([targetView respondsToSelector:@selector(text)]) {
                // 使用消除performSelector警告的安全方法
                IMP imp = [targetView methodForSelector:@selector(text)];
                NSString* (*func)(id, SEL) = (void *)imp;
                viewText = func(targetView, @selector(text));
            } else if ([targetView respondsToSelector:@selector(attributedText)]) {
                // 使用消除performSelector警告的安全方法
                IMP imp = [targetView methodForSelector:@selector(attributedText)];
                NSAttributedString* (*func)(id, SEL) = (void *)imp;
                NSAttributedString *attrText = func(targetView, @selector(attributedText));
                viewText = attrText.string;
            }
            if (viewText && [viewText rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                matchReason = [NSString stringWithFormat:@"匹配文本: \"%@\"", viewText];
            }
            
            // 维度2: 搜索类名
            if (!matchReason && [NSStringFromClass([targetView class]) rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                matchReason = [NSString stringWithFormat:@"匹配类名: %@", NSStringFromClass([targetView class])];
            }
            
            // 维度3: 搜索可访问性标识符
            if (!matchReason && targetView.accessibilityIdentifier && [targetView.accessibilityIdentifier rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                matchReason = [NSString stringWithFormat:@"匹配标识符: %@", targetView.accessibilityIdentifier];
            }

            if (matchReason) {
                // 开启"代码溯源"
                NSString *ownershipInfo = [self findOwnershipForView:targetView];
                
                RFViewNode *resultNode = [[RFViewNode alloc] init];
                resultNode.view = targetView;
                resultNode.displayString = originalNode.displayString;
                resultNode.searchMatchContext = [NSString stringWithFormat:@"%@%@", matchReason, ownershipInfo];
                [filteredNodes addObject:resultNode];
            }
        }
        self.filteredViewNodes = filteredNodes;
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder]; // 收起键盘
}

#pragma mark - Ownership Finder

- (NSString *)findOwnershipForView:(UIView *)targetView {
    // 1. 沿着响应者链找到VC
    UIResponder *responder = targetView;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    
    UIViewController *ownerVC = (UIViewController *)responder;
    if (!ownerVC) {
        return @""; // 未找到所属控制器
    }

    // 2. 构建从目标视图到其所在VC的视图的路径
    NSMutableArray<NSString *> *pathComponents = [NSMutableArray array];
    UIView *currentView = targetView;
    while (currentView && currentView != ownerVC.view) {
        [pathComponents insertObject:NSStringFromClass([currentView class]) atIndex:0];
        currentView = currentView.superview;
    }
    // 如果ownerVC.view本身就是目标，或者中途断了，至少把目标本身加上
    if (pathComponents.count == 0 && targetView) {
         [pathComponents addObject:NSStringFromClass([targetView class])];
    }

    NSString *viewPath = [pathComponents componentsJoinedByString:@" -> "];
    
    NSString *ownershipInfo = [NSString stringWithFormat:@"\n-> 由 %@ 管理\n-> 路径: %@", NSStringFromClass([ownerVC class]), viewPath];

    return ownershipInfo;
}

@end 