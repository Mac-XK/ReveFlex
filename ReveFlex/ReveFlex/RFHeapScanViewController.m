#import "RFHeapScanViewController.h"
#import "RFDetailViewController.h"
#import <objc/runtime.h>
#import <malloc/malloc.h>
#import <mach/mach.h>

// 定义一个全局的回调函数，用于堆内存枚举
static void enumerateHeapObjects(task_t task, void *context, unsigned type, vm_range_t *ranges, unsigned count) {
    NSMutableArray *objects = (__bridge NSMutableArray *)context;
    NSSet *targetClasses = objc_getAssociatedObject(objects, "targetClasses");
    
    for (unsigned i = 0; i < count; i++) {
        vm_range_t range = ranges[i];
        for (vm_address_t ptr = range.address; ptr < range.address + range.size; ptr += sizeof(void*)) {
            @try {
                id obj = (__bridge id)(void *)ptr;
                for (Class aClass in targetClasses) {
                    if ([obj isKindOfClass:aClass]) {
                        [objects addObject:obj];
                        break;
                    }
                }
            } @catch (NSException *exception) {
                // 指针无效，忽略
            }
        }
    }
}

@interface RFHeapScanViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) Class targetClass;
@property (nonatomic, strong) NSArray<id> *instances;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation RFHeapScanViewController

- (instancetype)initWithClass:(Class)targetClass {
    self = [super init];
    if (self) {
        _targetClass = targetClass;
        _instances = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"%@ 的实例", NSStringFromClass(self.targetClass)];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupTableView];
    [self setupActivityIndicator];
    [self scanForInstances];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

- (void)setupActivityIndicator {
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.activityIndicator.center = self.view.center;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
}

- (void)scanForInstances {
    [self.activityIndicator startAnimating];
    self.tableView.hidden = YES;
    
    // 在后台线程执行耗时的扫描操作
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *foundInstances = [NSMutableArray array];
        
        Class targetCls = self.targetClass;
        
        // 获取所有已注册的类，并找到所有子类
        NSMutableSet *targetClasses = [NSMutableSet setWithObject:targetCls];
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        if (classes) {
            for (unsigned int i = 0; i < classCount; i++) {
                Class currentClass = classes[i];
                Class superClass = class_getSuperclass(currentClass);
                while (superClass) {
                    if (superClass == targetCls) {
                        [targetClasses addObject:currentClass];
                        break;
                    }
                    superClass = class_getSuperclass(superClass);
                }
            }
            free(classes);
        }

        // 使用 vm_map 遍历堆内存
        vm_address_t *zones = NULL;
        unsigned int zoneCount = 0;
        kern_return_t result = malloc_get_all_zones(mach_task_self(), NULL, &zones, &zoneCount);

        // 将目标类集合关联到 foundInstances，以便回调函数能够访问
        objc_setAssociatedObject(foundInstances, "targetClasses", targetClasses, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if (result == KERN_SUCCESS) {
            for (int i = 0; i < zoneCount; i++) {
                malloc_zone_t *zone = (malloc_zone_t *)zones[i];
                if (zone && zone->introspect && zone->introspect->enumerator) {
                    // 使用正确的类型定义回调函数
                    malloc_introspection_t *introspect = zone->introspect;
                    
                    // 调用带有正确签名回调的枚举器
                    introspect->enumerator(mach_task_self(), (__bridge void *)foundInstances, MALLOC_PTR_IN_USE_RANGE_TYPE, (vm_address_t)zone, 0, enumerateHeapObjects);
                }
            }
        }
        
        // 移除关联对象
        objc_setAssociatedObject(foundInstances, "targetClasses", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 不再需要释放zones，因为malloc_get_all_zones()分配的zones是通过mach_task_self获取的，不需要我们释放

        // 切换回主线程更新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            self.instances = [NSSet setWithArray:foundInstances].allObjects; // 去重
            [self.activityIndicator stopAnimating];
            self.tableView.hidden = NO;
            [self.tableView reloadData];
            self.title = [NSString stringWithFormat:@"%@ 的实例 (%lu)", NSStringFromClass(self.targetClass), (unsigned long)self.instances.count];
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.instances.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * const InstanceCellID = @"InstanceCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:InstanceCellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:InstanceCellID];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:14];
    }
    
    id instance = self.instances[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%p", instance];
    cell.detailTextLabel.text = [instance description];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id selectedInstance = self.instances[indexPath.row];
    
    RFDetailViewController *detailVC = [[RFDetailViewController alloc] initWithClass:self.targetClass object:selectedInstance];
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end 