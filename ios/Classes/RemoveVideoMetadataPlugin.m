#import "RemoveVideoMetadataPlugin.h"
#if __has_include(<remove_video_metadata/remove_video_metadata-Swift.h>)
#import <remove_video_metadata/remove_video_metadata-Swift.h>
#else
#import "remove_video_metadata-Swift.h"
#endif

@implementation RemoveVideoMetadataPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRemoveVideoMetadataPlugin registerWithRegistrar:registrar];
}
@end
