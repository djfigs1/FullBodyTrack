//
//  OpenCVWrapper.h
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/5/20.
//

#import "OpenCVWrapper.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CVImgOutput: NSObject
@property UIImage* outputImage;
@end

@interface ChArUcoBoardResult: CVImgOutput
@property bool boardFound;
@end

@interface TrackerObj: NSObject
@property NSString* serial;
@property char tracker_id;
@property NSDictionary<NSNumber*, NSArray<NSArray<NSNumber*>*>*>* markers;

@end

@interface TrackerLocation: NSObject

typedef struct Vector3d {
    double x, y, z;
} Vector3d;

@property char tracker_id;
@property bool visible;
@property Vector3d rvec;
@property Vector3d tvec;

@end

@interface TrackerResult: CVImgOutput
@property NSArray<TrackerLocation*>* trackers;
@end

@interface OpenCVWrapper : NSObject

@property (class) NSMutableArray<TrackerObj*>* trackerObjects;

typedef struct CameraProperties {
    double fx;
    double fy;
    double cx;
    double cy;
    double distCoeffs[5];
} CameraProperties;

typedef struct DetectionParameters {
    double adaptiveThreshConstant;
    int adaptThresWinSizeMax;
    int adaptThresWinSizeMin;
    int adaptThresWinSizeStep;
    float aprilTagCriticalRad;
    int aprilTagDeglitch;
    float aprilTagMaxLineFitMse;
    int aprilTagMaxNmaxima;
    int aprilTagMinCLusterPixels;
    int aprilTagMinWhiteBlackDiff;
    float aprilTagQuadDecimate;
    float aprliTagQuadSigma;
    int cornerRefinementMaxIterations;
    int cornerRefinementMethod;
    double cornerRefinementMinAccuracy;
    int cornerRefinementWinSize;
    bool detectInvertedMarker;
    double errorCorrectionRate;
    int markerBorderBits;
    double maxErroneousBitsInBorderRate;
    double minMarkerPerimRate;
    double maxMarkerPerimRate;
    int minDistanceToBorder;
    double minMarkerDistanceRate;
    double minMarkerPerimeterRate;
    double minOtsuStdDev;
    double perspectiveRemoveIgnoredMarginPerCell;
    int perspectiveRemovePixelPerCell;
    double polygonalApproxAccuracyRate;
    bool cornerRefine;
    
} DetectionParameters;

+ (void) initalize;
+ (void) setWinSize: (int) winSize;
+ (NSMutableArray<TrackerObj*>*) trackerObjects;
+ (void) setCameraPropeties: (CameraProperties) properties;
+ (void) setCameraRefine: (bool) refine;
+ (void) addTracker: (TrackerObj*) tracker;
+ (NSArray<TrackerObj*>*) getAllTrackers;
+ (NSString *) openCVVersionString;
+ (int) boardsCaptured;

+ (CVImgOutput*) getMarkersFromBuffer: (CVImageBufferRef) buffer;
+ (TrackerResult*) getTrackersFromBuffer: (CVImageBufferRef) buffer;
+ (ChArUcoBoardResult*) findChArUcoBoard: (CVImageBufferRef) buffer saveResult: (bool) save;
+ (CameraProperties) calibrateStoredBoards;

@end

NS_ASSUME_NONNULL_END
