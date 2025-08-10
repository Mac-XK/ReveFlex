#line 1 "/Users/macxk/Desktop/UI调试/小工具/已开发/ReveFlex/ReveFlex/ReveFlex.xm"


#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import "RFUIManager.h"

static __attribute__((constructor)) void _logosLocalCtor_344ae32b(int __unused argc, char __unused **argv, char __unused **envp) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [RFUIManager install];
        [RFUIManager setupGestureRecognizer];
    });
}
