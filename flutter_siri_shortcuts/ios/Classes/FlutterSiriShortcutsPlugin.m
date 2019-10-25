#import "FlutterSiriShortcutsPlugin.h"
#import <Intents/Intents.h>
#import <IntentsUI/IntentsUI.h>
#import <CoreSpotlight/CoreSpotlight.h>

static NSString * const CHANNEL_NAME_SET_SHOTCUT = @"github.com/hugochou/setShotcut";
static NSString * const CHANNEL_NAME_GET_SHOTCUTS = @"github.com/hugochou/getAllVoiceShortcuts";
static NSString * const CHANNEL_NAME_LISTEN_SHOTCUTS = @"github.com/hugochou/listenShotcut";
static NSString * const CHANNEL_NAME_METHOD = @"github.com/hugochou/methodChannel";


@interface FlutterSiriShortcutsPlugin()<INUIAddVoiceShortcutViewControllerDelegate, INUIEditVoiceShortcutViewControllerDelegate, FlutterStreamHandler>
@property (nonatomic, copy) FlutterEventSink setShotcutSink;
@property (nonatomic, copy) FlutterEventSink allShotcutsSink;
@property (nonatomic, copy) FlutterEventSink listenShotcutSink;
@property (nonatomic, strong) FlutterEventChannel *setShotcutChannel;
@property (nonatomic, strong) FlutterEventChannel *allShotcutsChannel;
@property (nonatomic, strong) FlutterEventChannel *listenShotcutChannel;
@property (nonatomic, copy) NSString *activityType;
@end

@implementation FlutterSiriShortcutsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterSiriShortcutsPlugin* instance = [[FlutterSiriShortcutsPlugin alloc] init];

    // 注册设置捷径channel
    instance.setShotcutChannel = [FlutterEventChannel eventChannelWithName:CHANNEL_NAME_SET_SHOTCUT
                                                           binaryMessenger:[registrar messenger]];
    [instance.setShotcutChannel setStreamHandler:instance];

    // 注册获取所有捷径channel
    instance.allShotcutsChannel = [FlutterEventChannel eventChannelWithName:CHANNEL_NAME_GET_SHOTCUTS
                                                            binaryMessenger:[registrar messenger]];
    [instance.allShotcutsChannel setStreamHandler:instance];

    // 注册监听 Siri 捷径命令channel
    instance.allShotcutsChannel = [FlutterEventChannel eventChannelWithName:CHANNEL_NAME_LISTEN_SHOTCUTS
                                                            binaryMessenger:[registrar messenger]];
    [instance.allShotcutsChannel setStreamHandler:instance];


    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:CHANNEL_NAME_METHOD
                                     binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:channel];

    [registrar addApplicationDelegate:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getLaunchShotcut" isEqualToString:call.method]) {
        result(self.activityType);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)getAllVoiceShortcuts {
    if (@available(iOS 12.0, *)) {
        __weak typeof(self) weakSelf = self;
        [[INVoiceShortcutCenter sharedCenter] getAllVoiceShortcutsWithCompletion:^(NSArray<INVoiceShortcut *> * _Nullable voiceShortcuts, NSError * _Nullable error) {
            NSMutableArray<NSString *> *types = [NSMutableArray array];
            for (INVoiceShortcut *voiceShortcut in voiceShortcuts) {
                [types addObject:voiceShortcut.shortcut.userActivity.activityType];
            }
            if (weakSelf.allShotcutsSink) {
                weakSelf.allShotcutsSink(types);
            }
        }];
    }
}

- (void)addShotcut:(NSDictionary *)arguments API_AVAILABLE(ios(12.0)){
    NSString *type = [NSString stringWithFormat:@"%@", [arguments objectForKey:@"type"]];
    NSString *title = [NSString stringWithFormat:@"%@", [arguments objectForKey:@"title"]];
    NSString *subTitle = [NSString stringWithFormat:@"%@", [arguments objectForKey:@"subTitle"]];
    NSString *suggestion = [NSString stringWithFormat:@"%@", [arguments objectForKey:@"suggestion"]];
    __weak typeof(self) weakSelf = self;
    [[INVoiceShortcutCenter sharedCenter] getAllVoiceShortcutsWithCompletion:^(NSArray<INVoiceShortcut *> * _Nullable voiceShortcuts, NSError * _Nullable error) {
        for (int i = 0; i < voiceShortcuts.count; i ++) {
            if ([voiceShortcuts[i].shortcut.userActivity.activityType isEqualToString:type]) {
                [weakSelf setupIntents:type title:title subTitle:subTitle suggestion:suggestion voiceShorcut:voiceShortcuts[i] isEdit:YES];
                return;
            }
        }
        [weakSelf setupIntents:type title:title subTitle:subTitle suggestion:suggestion voiceShorcut:nil isEdit:NO];
    }];
}

- (void)setupIntents:(NSString *)type
               title:(NSString *)title
            subTitle:(NSString *)subTitle
          suggestion:(NSString *)suggestion
        voiceShorcut:(INVoiceShortcut *)voiceShorcut
              isEdit:(BOOL)isEdit API_AVAILABLE(ios(12.0)){
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType: type];
    userActivity.title = title;
    [userActivity setEligibleForSearch:YES];
    [userActivity setEligibleForPrediction:YES];
    userActivity.suggestedInvocationPhrase = suggestion;
    userActivity.persistentIdentifier = type;

    CSSearchableItemAttributeSet *attributes = [[CSSearchableItemAttributeSet alloc] init];
    attributes.contentDescription = subTitle;

    userActivity.contentAttributeSet = attributes;

    dispatch_async(dispatch_get_main_queue(), ^{
        FlutterAppDelegate *delegate = (FlutterAppDelegate *)[UIApplication sharedApplication].delegate;
        UIViewController *root = delegate.window.rootViewController;
        if (isEdit) {
            INUIEditVoiceShortcutViewController *addvc = [[INUIEditVoiceShortcutViewController alloc] initWithVoiceShortcut:voiceShorcut];
            addvc.delegate = self;
            [root presentViewController:addvc animated:YES completion:nil];
        } else {
            INShortcut *shortCuts = [[INShortcut alloc] initWithUserActivity:userActivity];
            INUIAddVoiceShortcutViewController *addvc = [[INUIAddVoiceShortcutViewController alloc] initWithShortcut:shortCuts];
            addvc.delegate = self;
            [root presentViewController:addvc animated:YES completion:nil];
        }
    });
}

#pragma mark - INUIAddVoiceShortcutViewControllerDelegate
// 0 失败/取消，1 新增， 2 编辑，3 删除
- (void)addVoiceShortcutViewController:(nonnull INUIAddVoiceShortcutViewController *)controller didFinishWithVoiceShortcut:(nullable INVoiceShortcut *)voiceShortcut error:(nullable NSError *)error  API_AVAILABLE(ios(12.0)){
    if (!error) {
        [controller dismissViewControllerAnimated:YES completion:nil];
        if (self.setShotcutSink) {
            // 1:表示新增捷径
            self.setShotcutSink(@1);
        }
    }
}

- (void)addVoiceShortcutViewControllerDidCancel:(nonnull INUIAddVoiceShortcutViewController *)controller  API_AVAILABLE(ios(12.0)){
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (self.setShotcutSink) {
        // 0:表示取消新增捷径
        self.setShotcutSink(@0);
    }
}


#pragma mark - INUIEditVoiceShortcutViewControllerDelegate
- (void)editVoiceShortcutViewController:(nonnull INUIEditVoiceShortcutViewController *)controller didDeleteVoiceShortcutWithIdentifier:(nonnull NSUUID *)deletedVoiceShortcutIdentifier  API_AVAILABLE(ios(12.0)){
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (self.setShotcutSink) {
        // 3:表示删除捷径
        self.setShotcutSink(@3);
    }
}

- (void)editVoiceShortcutViewController:(nonnull INUIEditVoiceShortcutViewController *)controller didUpdateVoiceShortcut:(nullable INVoiceShortcut *)voiceShortcut error:(nullable NSError *)error  API_AVAILABLE(ios(12.0)){
    if (!error) {
        [controller dismissViewControllerAnimated:YES completion:nil];
        if (self.setShotcutSink) {
            // 2:表示编辑捷径
            self.setShotcutSink(@2);
        }
    }
}

- (void)editVoiceShortcutViewControllerDidCancel:(nonnull INUIEditVoiceShortcutViewController *)controller  API_AVAILABLE(ios(12.0)){
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (self.setShotcutSink) {
        // 0:表示取消编辑捷径
        self.setShotcutSink(@0);
    }
}

#pragma mark - FlutterStreamHandler
- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    if (events) {
        arguments = (NSDictionary *)arguments;
        NSString *type = [NSString stringWithFormat:@"%@", [arguments objectForKey:@"channelName"]];
        if ([type isEqualToString:@"getAllVoiceShortcuts"]) {
            self.allShotcutsSink = events;
            [self getAllVoiceShortcuts];
        } else if ([type isEqualToString:@"listenShotcut"]) {
            self.listenShotcutSink = events;
        } else if ([type isEqualToString:@"setShotcut"]) {
            if (@available(iOS 12.0, *)) {
                self.setShotcutSink = events;
                [self addShotcut:arguments];
            } else {
                events(@NO);
            }
        }
    }
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    return nil;
}

#pragma mark - UIApplicationDelegate
- (BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray * _Nullable))restorationHandler {
    self.activityType = userActivity.activityType;
    if (self.listenShotcutSink) {
        self.listenShotcutSink(userActivity.activityType);
    }
    return YES;
}
@end
