#import "RemoveVideoLocationPlugin.h"
#if __has_include(<remove_video_location/remove_video_location-Swift.h>)
#import <remove_video_location/remove_video_location-Swift.h>
#else
#import "remove_video_location-Swift.h"
#endif

@implementation RemoveVideoLocationPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRemoveVideoLocationPlugin registerWithRegistrar:registrar];
}
@end
