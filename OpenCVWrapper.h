//
//  OpenCVWrapper.h
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/5/20.
//

#import "OpenCVWrapper.h"
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraPropertiesObjC: NSObject
@property NSNumber* fx;
@property NSNumber* fy;
@property NSNumber* cx;
@property NSNumber* cy;
@property NSArray<NSNumber*>* distCoeffs;
@end

@interface CVImgOutput: NSObject
@property UIImage* outputImage;
@property CGImageRef outputCGImage;
@property double outputTime;
@end

@interface ChArUcoBoardResult: CVImgOutput
@property bool boardFound;
@end

@interface TrackerObj: NSObject
@property NSString* tracker_id;
@property NSDictionary<NSNumber*, NSArray<NSArray<NSNumber*>*>*>* markers;
@end

@interface TrackerLocation: NSObject

typedef struct Vector3d {
    double x, y, z;
} Vector3d;

@property NSString* tracker_id;
@property bool visible;
@property Vector3d rvec;
@property Vector3d tvec;

@end

@interface TrackerResult: CVImgOutput
@property NSArray<TrackerLocation*>* trackers;
@end

@interface OpenCVWrapper : NSObject

+ (void) initialize;
+ (Vector3d) rvecFromPitch: (double) pitch yaw: (double) yaw roll: (double) roll;
+ (void) setCameraPropeties: (CameraPropertiesObjC*) properties;
+ (void) setShowPreviewWindow: (bool) preview;
+ (void) setCameraRefine: (bool) refine;
+ (void) addTracker: (TrackerObj*) tracker;
+ (bool) removeTracker: (TrackerObj*) tracker;

+ (NSString *) openCVVersionString;
+ (int) boardsCaptured;
+ (void) setDictionaryFromString: (NSString *) dictionary;

+ (CVImgOutput*) getMarkersFromBuffer: (CVImageBufferRef) buffer;
+ (TrackerResult*) getTrackersFromBuffer: (CVImageBufferRef) buffer;
+ (ChArUcoBoardResult*) findChArUcoBoard: (CVImageBufferRef) buffer saveResult: (bool) save;
+ () calibrateStoredBoards;

@end

NS_ASSUME_NONNULL_END
