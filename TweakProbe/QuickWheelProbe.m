#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>

/// QuickWheelProbe - a standalone LiveContainer dynamic library.
/// Injecting this library should show a small native HUD above QuickWheel.
/// No private APIs, substrate hooks, JIT, or network access are required.

@interface QWProbe : NSObject
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSTimer *attachmentTimer;
@property (nonatomic) NSUInteger frames;
@property (nonatomic) CFTimeInterval lastTimestamp;
@property (nonatomic) CGFloat measuredFPS;
@property (nonatomic) BOOL compact;
@property (nonatomic) BOOL wasDragged;
@end

@implementation QWProbe

- (UIWindow *)activeWindow {
    UIApplication *app = [UIApplication sharedApplication];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]] ||
                scene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.isKeyWindow && candidate.rootViewController != nil) {
                    return candidate;
                }
            }
            for (UIWindow *candidate in windowScene.windows) {
                if (candidate.rootViewController != nil && !candidate.hidden) {
                    return candidate;
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return app.keyWindow;
#pragma clang diagnostic pop
}

- (void)begin {
    NSLog(@"[QuickWheelProbe] Library loaded, installing HUD when the app window exists");
    self.measuredFPS = 0;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(16, 95, 226, 66)];
    panel.backgroundColor = [UIColor colorWithRed:0.055 green:0.075 blue:0.11 alpha:0.96];
    panel.layer.cornerRadius = 15;
    panel.layer.borderWidth = 1.5;
    panel.layer.borderColor = [UIColor colorWithRed:0.19 green:0.92 blue:0.56 alpha:1].CGColor;
    panel.layer.shadowColor = UIColor.blackColor.CGColor;
    panel.layer.shadowRadius = 8;
    panel.layer.shadowOpacity = 0.3;
    panel.layer.shadowOffset = CGSizeMake(0, 3);
    panel.clipsToBounds = NO;
    panel.accessibilityLabel = @"QuickWheel test tweak active";
    self.panel = panel;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12, 7, 205, 52)];
    label.numberOfLines = 2;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
    label.text = @"TWEAK ACTIVE  ✓\nQuickWheel  •  testing FPS";
    [panel addSubview:label];
    self.label = label;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    [panel addGestureRecognizer:pan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [tap requireGestureRecognizerToFail:pan];
    [panel addGestureRecognizer:tap];

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(frameArrived:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    self.attachmentTimer = [NSTimer timerWithTimeInterval:0.5
                                                   target:self
                                                 selector:@selector(attachAndRefresh:)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.attachmentTimer forMode:NSRunLoopCommonModes];
    [self attachAndRefresh:nil];
}

- (void)attachAndRefresh:(NSTimer *)timer {
    UIWindow *target = [self activeWindow];
    if (target == nil || self.panel == nil) {
        return;
    }
    if (self.panel.superview != target) {
        [self.panel removeFromSuperview];
        CGSize size = target.bounds.size;
        CGFloat left = MAX(10, size.width - 236);
        CGFloat top = MAX(74, target.safeAreaInsets.top + 14);
        self.panel.frame = CGRectMake(left, top, self.compact ? 157 : 226, 66);
        [target addSubview:self.panel];
        NSLog(@"[QuickWheelProbe] HUD attached to window %@", target);
    }
    [target bringSubviewToFront:self.panel];
    [self updateText];
}

- (void)frameArrived:(CADisplayLink *)link {
    if (self.lastTimestamp <= 0) {
        self.lastTimestamp = link.timestamp;
        return;
    }
    self.frames += 1;
    CFTimeInterval elapsed = link.timestamp - self.lastTimestamp;
    if (elapsed >= 0.7) {
        self.measuredFPS = self.frames / elapsed;
        self.frames = 0;
        self.lastTimestamp = link.timestamp;
        [self updateText];
    }
}

- (void)updateText {
    if (self.label == nil) return;
    float battery = [UIDevice currentDevice].batteryLevel;
    NSString *batteryText = battery < 0 ? @"--" : [NSString stringWithFormat:@"%d%%", (int)roundf(battery * 100)];
    if (self.compact) {
        self.label.text = [NSString stringWithFormat:@"ACTIVE ✓\n%.0f FPS", self.measuredFPS];
    } else {
        self.label.text = [NSString stringWithFormat:@"TWEAK ACTIVE  ✓\n%.0f FPS  •  Battery %@", self.measuredFPS, batteryText];
    }
}

- (void)tapped:(UITapGestureRecognizer *)gesture {
    self.compact = !self.compact;
    CGRect frame = self.panel.frame;
    frame.size.width = self.compact ? 157 : 226;
    [UIView animateWithDuration:0.18 animations:^{
        self.panel.frame = frame;
    }];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    [self updateText];
}

- (void)panned:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.panel.superview;
    if (!superview) return;
    CGPoint translation = [gesture translationInView:superview];
    CGRect frame = self.panel.frame;
    frame.origin.x = MAX(3, MIN(superview.bounds.size.width - frame.size.width - 3, frame.origin.x + translation.x));
    frame.origin.y = MAX(3, MIN(superview.bounds.size.height - frame.size.height - 3, frame.origin.y + translation.y));
    self.panel.frame = frame;
    [gesture setTranslation:CGPointMake(0, 0) inView:superview];
}

@end

static QWProbe *QWProbeInstance = nil;
__attribute__((constructor))
static void QWProbeEntry(void) {
    NSLog(@"[QuickWheelProbe] dylib constructor called");
    dispatch_async(dispatch_get_main_queue(), ^{
        QWProbeInstance = [[QWProbe alloc] init];
        [QWProbeInstance begin];
    });
}
