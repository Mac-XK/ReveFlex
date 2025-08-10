#import "RFDraggableView.h"

@implementation RFDraggableView

- (instancetype)initWithWindow:(UIWindow *)window {
    // Start with a small frame, it will be positioned later.
    self = [super initWithFrame:CGRectMake(0, 100, 40, 40)];
    if (self) {
        self.layer.cornerRadius = 20;
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:self.bounds];
        titleLabel.text = @"RF";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [self addSubview:titleLabel];
        
        [window addSubview:self];
        
        // Add gesture recognizers
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)]];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]];
    }
    return self;
}

- (void)handleTap {
    if (self.tapHandler) {
        self.tapHandler();
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)panner {
        // 修复类型不匹配警告，使用适当的类型转换
    UIView *superView = self.superview;
    CGPoint panPoint = [panner locationInView:superView];
    
    // Update view's position
    self.center = panPoint;
    
    if (panner.state == UIGestureRecognizerStateEnded) {
        [self stickToEdge];
    }
}

- (void)stickToEdge {
    // 修复类型不匹配警告，使用适当的类型转换
    UIView *superView = self.superview;
    CGRect frame = self.frame;
    
    CGFloat finalX;
    
    // Snap to the left or right edge
    if (frame.origin.x + frame.size.width / 2 < superView.bounds.size.width / 2) {
        finalX = 10; // Left padding
    } else {
        finalX = superView.bounds.size.width - frame.size.width - 10; // Right padding
    }
    
    // Ensure it doesn't go off screen vertically
    CGFloat finalY = MIN(MAX(frame.origin.y, 50), superView.bounds.size.height - frame.size.height - 50);
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.frame = CGRectMake(finalX, finalY, frame.size.width, frame.size.height);
    } completion:nil];
}

@end 