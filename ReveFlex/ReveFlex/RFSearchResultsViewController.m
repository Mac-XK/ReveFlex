#import "RFSearchResultsViewController.h"
#import "RFDetailViewController.h"
#import <objc/runtime.h>

@interface RFSearchResultsViewController ()
@property (nonatomic, strong) NSArray<NSDictionary *> *originalResults;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray *> *groupedResults;
@property (nonatomic, strong) NSArray<NSString *> *groupKeys;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation RFSearchResultsViewController

- (instancetype)initWithResults:(NSArray<NSDictionary *> *)results title:(NSString *)title {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _originalResults = results;
        self.title = title;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupSearchController];
    [self setupNavigationBar];
    
    [self filterAndGroupResults:self.originalResults];
}

#pragma mark - Setup

- (void)setupSearchController {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"在结果中筛选";
    
    if (@available(iOS 13.0, *)) {
        self.searchController.searchBar.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.searchController.searchBar.barTintColor = [UIColor whiteColor];
    }
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    } else {
        self.tableView.tableHeaderView = self.searchController.searchBar;
    }
    self.definesPresentationContext = YES;
}

- (void)setupNavigationBar {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                             target:self
                                             action:@selector(dismissViewController)];
}

- (void)dismissViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Data Handling

- (void)filterAndGroupResults:(NSArray *)results {
    NSMutableDictionary<NSString *, NSMutableArray *> *grouped = [NSMutableDictionary dictionary];
    
    for (NSDictionary *result in results) {
        NSString *type = result[@"type"];
        NSString *groupKey = [self groupKeyForType:type];
        
        if (!grouped[groupKey]) {
            grouped[groupKey] = [NSMutableArray array];
        }
        [grouped[groupKey] addObject:result];
    }
    
    self.groupedResults = [NSDictionary dictionaryWithDictionary:grouped];
    
    NSArray *keyOrder = @[@"类", @"方法", @"属性"];
    self.groupKeys = [keyOrder filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return self.groupedResults[evaluatedObject] != nil;
    }]];
    
    [self.tableView reloadData];
}

- (NSString *)groupKeyForType:(NSString *)type {
    if ([type isEqualToString:@"class"]) return @"类";
    if ([type isEqualToString:@"method"]) return @"方法";
    if ([type isEqualToString:@"property"]) return @"属性";
    return @"其他";
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchText = searchController.searchBar.text;
    
    if (searchText.length == 0) {
        [self filterAndGroupResults:self.originalResults];
        return;
    }
    
    NSMutableArray *filteredResults = [NSMutableArray array];
    NSString *lowercaseSearchText = [searchText lowercaseString];
    
    for (NSDictionary *result in self.originalResults) {
        NSString *detail = result[@"detail"];
        if ([detail.lowercaseString containsString:lowercaseSearchText]) {
            [filteredResults addObject:result];
        }
    }
    
    [self filterAndGroupResults:filteredResults];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.groupKeys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *groupKey = self.groupKeys[section];
    return self.groupedResults[groupKey].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *groupKey = self.groupKeys[section];
    NSUInteger count = self.groupedResults[groupKey].count;
    return [NSString stringWithFormat:@"%@ (%lu)", groupKey, (unsigned long)count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SearchResultCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:14];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.textLabel.numberOfLines = 0;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *groupKey = self.groupKeys[indexPath.section];
    NSDictionary *result = self.groupedResults[groupKey][indexPath.row];
    
    NSString *type = result[@"type"];
    
    if ([type isEqualToString:@"class"]) {
        cell.textLabel.text = result[@"name"];
        cell.detailTextLabel.text = nil;
    } else {
        cell.textLabel.text = result[@"name"];
        cell.detailTextLabel.text = result[@"class"];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *groupKey = self.groupKeys[indexPath.section];
    NSDictionary *result = self.groupedResults[groupKey][indexPath.row];
    
    NSString *className = result[@"class"] ?: result[@"name"];
    Class selectedClass = NSClassFromString(className);
    
    if (selectedClass) {
        RFDetailViewController *detailVC = [[RFDetailViewController alloc] initWithClass:selectedClass object:nil];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

@end 