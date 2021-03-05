//
//  OpenCVWrapper.m
//  FullBodyTrack
//
//  Created by DJ Figueroa on 8/5/20.
//

#import <opencv2/opencv.hpp>
#import <opencv2/aruco.hpp>
#import <opencv2/aruco/charuco.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <AVFoundation/AVFoundation.h>
#import "OpenCVWrapper.h"
#import "aruco/aruco.h"

@implementation CameraPropertiesObjC

@end

@implementation CVImgOutput

@end

@implementation ChArUcoBoardResult

@end

@implementation TrackerLocation

@end

@implementation TrackerResult

@end

#define MARKER_DICTIONARY_TYPE cv::aruco::DICT_4X4_1000

static cv::Ptr<cv::aruco::Dictionary> MARKER_DICTIONARY = cv::aruco::getPredefinedDictionary(MARKER_DICTIONARY_TYPE);

@implementation TrackerObj
- (std::string) tracker_id_std_string {
    std::string tracker_id_str = std::string([[self tracker_id] UTF8String]);
    return tracker_id_str;
}

- (aruco::MarkerMap) generateMarkerMap {
    std::vector<int> markerIds;
    std::vector<std::vector<cv::Point3f>> allMarkerCorners;
    markerIds.reserve(_markers.allKeys.count);
    allMarkerCorners.reserve(_markers.allKeys.count);
    for (NSNumber* key in _markers) {
        NSArray<NSArray<NSNumber*>*>* corners = [_markers objectForKey:key];
        int marker_id = [key intValue];
        markerIds.push_back(marker_id);
        
        std::vector<cv::Point3f> marker_corners;
        marker_corners.reserve(4);
        
        for (NSArray<NSNumber*>* corner in corners) {
            cv::Point3f point = cv::Point3f([corner[0] floatValue], [corner[1] floatValue], [corner[2] floatValue]);
            marker_corners.push_back(point);
        }
        
        allMarkerCorners.push_back(marker_corners);
        
    }
    aruco::MarkerMap marker_map;
    marker_map.mInfoType = aruco::MarkerMap::METERS;
    marker_map.resize(allMarkerCorners.size());
    for (int i = 0; i < allMarkerCorners.size(); i++) {
        marker_map[i].id = markerIds[i];
        for (auto corner : allMarkerCorners[i]) {
            marker_map[i].push_back(corner);
        }
    }
    return marker_map;
}
@end

@implementation OpenCVWrapper

static cv::Ptr<cv::aruco::CharucoBoard> board = cv::aruco::CharucoBoard::create(5, 7, 0.035f, 0.0175f, MARKER_DICTIONARY);
static std::vector<std::vector<cv::Point2f>> allCharucoCorners;
static std::vector<std::vector<int>> allCharucoIds;
static aruco::MarkerDetector detector;
static aruco::CameraParameters* arucoCamParams = nullptr;

static std::vector<TrackerObj*> trackers;
static std::map<std::string, aruco::MarkerMap> trackerMaps;
static cv::Mat outputMat, cameraMatrix, distCoeffs;
static bool showPreview = true;

+ (void) initialize {
    NSLog(@"Initializing ArUco Parameters...");
    aruco::MarkerDetector::Params &params = detector.getParameters();
    params.maxThreads = 1;
    params.setDetectionMode(aruco::DetectionMode::DM_FAST, 0.02);
    params.setCornerRefinementMethod(aruco::CornerRefinementMethod::CORNER_SUBPIX);
    NSLog(@"Complete");
}

+ (void) setDictionaryFromString: (NSString *) dictionary {
    std::string dictionary_str = std::string([dictionary UTF8String]);
    aruco::Dictionary dict = aruco::Dictionary::loadDirectlyFromString(dictionary_str);
    NSLog(@"dict name: %s", dict.getName().c_str());
    NSLog(@"dict size: %llu", dict.size());
    
    detector.setDictionary(dict);
}

+ (NSString *) openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s", CV_VERSION];
}

+ (void) addTracker: (TrackerObj *)tracker {
    if (trackers.size() < INT8_MAX) {
        trackers.push_back(tracker);
        aruco::MarkerMap marker_map = [tracker generateMarkerMap];
        std::string key = std::string([tracker.tracker_id UTF8String]);
        trackerMaps[key] = marker_map;
    } else {
        // can't add more trackers
        return;
    }
    
}

+ (bool) removeTracker: (TrackerObj *) tracker_to_remove {
    std::string key_to_remove = [tracker_to_remove tracker_id_std_string];
    for (int i=0; i<trackers.size(); i++) {
        TrackerObj* tracker = trackers[i];
        std::string key = [tracker tracker_id_std_string];
        if (key_to_remove.compare(key) == 0) {
            trackers.erase(trackers.begin() + i);
            trackerMaps.erase(key_to_remove);
            return true;
        }
    }
    return false;
}

+ (void) setCameraPropeties: (CameraPropertiesObjC*) properties {
    double cx = [properties.cx doubleValue];
    double cy = [properties.cy doubleValue];
    double fx = [properties.fx doubleValue];
    double fy = [properties.fy doubleValue];
    double coeffs[5];
    
    for (int i = 0; i<5; i++) {
        double val = [properties.distCoeffs[i] doubleValue];
        coeffs[i] = val;
    }
    
    cameraMatrix = (cv::Mat1d(3,3) << fx, 0, cx, 0, fy, cy, 0, 0, 1);
    distCoeffs = (cv::Mat1d(1,5) << coeffs[0], coeffs[1], coeffs[2], coeffs[3], coeffs[4]);
    arucoCamParams = new aruco::CameraParameters(cameraMatrix, distCoeffs, cv::Size(1080,1920));
}

+ (void) setCameraRefine: (bool) refine {
    aruco::MarkerDetector::Params &params = detector.getParameters();
    params.setCornerRefinementMethod(refine ? aruco::CORNER_SUBPIX : aruco::CORNER_NONE);
}

+ (void) setShowPreviewWindow: (bool) preview {
    showPreview = preview;
}

+ (Vector3d) rvecFromPitch: (double) pitch yaw: (double) yaw roll: (double) roll {
    cv::Mat rotationMatrix = euler2rot(pitch, yaw, roll);
    cv::Mat rvec_mat;
    cv::Rodrigues(rotationMatrix, rvec_mat);
    Vector3d rvec;
    rvec.x = rvec_mat.at<double>(0);
    rvec.y = rvec_mat.at<double>(1);
    rvec.z = rvec_mat.at<double>(2);
    return rvec;
}

+ (CVImgOutput*) getMarkersFromBuffer: (CVImageBufferRef) buffer  {
    cv::Mat rgbMat = grayMatFrom(buffer, nil);
    cv::threshold(rgbMat, rgbMat, 40, 255, cv::THRESH_BINARY);
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    std::vector<aruco::Marker> markers = detector.detect(rgbMat, *arucoCamParams, 0.05);
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    double detectionTime = end - start;
    double ms = detectionTime * 1000;
    for (int i=0; i<markers.size(); i++) {
        aruco::Marker marker = markers[i];
        marker.draw(rgbMat);
        
        aruco::CvDrawingUtils::draw3dAxis(rgbMat,marker,*arucoCamParams);
    }

    //drawDebugInfo(rgbMat, ms);

    UIImage *outputImage = MatToUIImage(rgbMat);
    CVImgOutput* output = [[CVImgOutput alloc] init];
    output.outputImage = outputImage;
    
    output.outputTime = ms;

    return output;
    
    
    
}

+ (TrackerResult*) getTrackersFromBuffer: (CVImageBufferRef) buffer  {
    if (arucoCamParams == nullptr) return nil;
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    double conversionTime;
    cv::Mat img;
    if (showPreview) {
        img = rgbMatFrom(buffer, &conversionTime);
    } else {
        img = grayMatFrom(buffer, &conversionTime);
    }
    
    std::vector<aruco::Marker> markers;
    CFAbsoluteTime detection_start = CFAbsoluteTimeGetCurrent();
    detector.detect(img, markers, *arucoCamParams);
    double detectionTime = CFAbsoluteTimeGetCurrent() - detection_start;
    double ms = detectionTime * 1000;
    
    TrackerResult* result = [[TrackerResult alloc] init];
    NSMutableArray<TrackerLocation*>* locations = [[NSMutableArray alloc] init];

    if (markers.size() > 0) {
        if (showPreview) {
            for (auto marker : markers) {
                marker.draw(img);
            }
        }
        
        
        for (TrackerObj* trackerobj : trackers) {
            std::string tracker_id = [trackerobj tracker_id_std_string];
            aruco::MarkerMap marker_map = trackerMaps[tracker_id];
            TrackerLocation* location = [[TrackerLocation alloc] init];
            location.tracker_id = trackerobj.tracker_id;
            location.visible = false;
            
            aruco::MarkerMapPoseTracker MSPoseTracker;
            MSPoseTracker.setParams(*arucoCamParams, marker_map);
            if (MSPoseTracker.estimatePose(markers)) {
                cv::Mat rvec, tvec;
                rvec = MSPoseTracker.getRvec();
                tvec = MSPoseTracker.getTvec();
                location.visible = true;
                location.rvec = {rvec.at<float>(0,0), rvec.at<float>(0,1), rvec.at<float>(0,2)};
                location.tvec = {tvec.at<float>(0,0), tvec.at<float>(0,1), tvec.at<float>(0,2)};
                if (showPreview) {
                    aruco::CvDrawingUtils::draw3dAxis(img, *arucoCamParams, rvec, tvec, 0.05);
                }
            }
            [locations addObject:location];
        }
    } else {
        // set all locations to empty
        for (TrackerObj* trackerobj : trackers) {
            TrackerLocation* location = [[TrackerLocation alloc] init];
            location.tracker_id = trackerobj.tracker_id;
            location.visible = false;
            [locations addObject:location];
        }
    }
    
    double totalTimeMs = (CFAbsoluteTimeGetCurrent() - start) * 1000;
    
    result.outputImage = nullptr;
    if (showPreview) {
        drawDebugInfo(img, conversionTime * 1000, ms, totalTimeMs);
        
        NSData *data = [NSData dataWithBytes:img.data length: img.step.p[0]*img.rows];
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef) data);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNone ;
        
        CGImageRef cg_img = CGImageCreate(
            img.cols,
            img.rows,
            8,
            8 * img.elemSize(),
            img.step[0],
            colorSpace,
            bitmapInfo,
            provider,
            nil,
            false,
            kCGRenderingIntentDefault
        );
        
        UIImage *outputImage = [UIImage imageWithCGImage:cg_img];
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        CGImageRelease(cg_img);
        result.outputImage = outputImage;
    }
    
    result.outputTime = (CFAbsoluteTimeGetCurrent() - start) * 1000;
    result.trackers = [locations copy];
    return result;
}

+ (ChArUcoBoardResult*) findChArUcoBoard: (CVImageBufferRef)buffer saveResult: (bool) save {
    cv::Mat rgbMat = rgbMatFrom(buffer, nil);
    std::vector<int> ids;
    std::vector<std::vector<cv::Point2f>> corners;
    cv::aruco::detectMarkers(rgbMat, MARKER_DICTIONARY, corners, ids);
    
    ChArUcoBoardResult* result = [[ChArUcoBoardResult alloc] init];
    result.boardFound = false;
    
    if (ids.size() > 0) {
        cv::aruco::drawDetectedMarkers(rgbMat, corners);
        std::vector<cv::Point2f> charucoCorners;
        std::vector<int> charucoIds;
        cv::aruco::interpolateCornersCharuco(corners, ids, rgbMat, board, charucoCorners, charucoIds);
        if (charucoIds.size() > 0) {
            result.boardFound = true;
            if (save) {
                allCharucoCorners.push_back(charucoCorners);
                allCharucoIds.push_back(charucoIds);
            }
            cv::aruco::drawDetectedCornersCharuco(rgbMat, charucoCorners, charucoIds, cv::Scalar(255,0,0));
        }
    }
    
    UIImage* outputImage = MatToUIImage(rgbMat);
    result.outputImage = outputImage;
    return result;
}

+ (int) boardsCaptured {
    return (int) allCharucoIds.size();
}

+ (CameraPropertiesObjC*) calibrateStoredBoards {
    cv::Mat cameraMatrix, distCoeffs;
    cv::aruco::calibrateCameraCharuco(allCharucoCorners, allCharucoIds, board, cv::Size(1080, 1920), cameraMatrix, distCoeffs);
    CameraPropertiesObjC* properties = [[CameraPropertiesObjC alloc] init];

    double fx = cameraMatrix.at<double>(0,0);
    double fy = cameraMatrix.at<double>(1,1);
    double cx = cameraMatrix.at<double>(0,2);
    double cy = cameraMatrix.at<double>(1,2);
    properties.fx = [NSNumber numberWithDouble: fx];
    properties.fy = [NSNumber numberWithDouble: fy];
    properties.cx = [NSNumber numberWithDouble: cx];
    properties.cy = [NSNumber numberWithDouble: cy];
    NSMutableArray<NSNumber*>* coeffs = [NSMutableArray arrayWithCapacity: 5];
    
    for (int i=0; i<5; i++) {
        double val = distCoeffs.at<double>(i);
        [coeffs addObject: [NSNumber numberWithDouble: val]];
    }
    properties.distCoeffs = [coeffs copy];
    
    return properties;
    
}

#pragma mark Private
static cv::Mat rgbMatFrom(CVImageBufferRef buffer, double* conversionTime) {
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    void *baseaddress = CVPixelBufferGetBaseAddress(buffer);
    int width = (int) CVPixelBufferGetWidth(buffer);
    int height = (int) CVPixelBufferGetHeight(buffer);
    int bytesPerRow = (int) CVPixelBufferGetBytesPerRow(buffer);
    
    cv::Mat imgMat(height, width, CV_8UC4, baseaddress, bytesPerRow);
    cv::Mat rgbMat;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    cvtColor(imgMat, rgbMat, cv::COLOR_BGRA2RGB);
    CFAbsoluteTime diff = CFAbsoluteTimeGetCurrent() - start;
    if (conversionTime != nullptr) {
        *conversionTime = diff;
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return rgbMat;
}

static cv::Mat grayMatFrom(CVImageBufferRef buffer, double* conversionTime) {
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    void *baseaddress = CVPixelBufferGetBaseAddress(buffer);
    int width = (int) CVPixelBufferGetWidth(buffer);
    int height = (int) CVPixelBufferGetHeight(buffer);
    int bytesPerRow = (int) CVPixelBufferGetBytesPerRow(buffer);
    
    cv::Mat imgMat(height, width, CV_8UC4, baseaddress, bytesPerRow);
    cv::Mat rgbMat;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    cvtColor(imgMat, rgbMat, cv::COLOR_BGRA2GRAY);
    CFAbsoluteTime diff = CFAbsoluteTimeGetCurrent() - start;
    if (conversionTime != nullptr) {
        *conversionTime = diff;
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return rgbMat;
}

static void drawDebugInfo(cv::Mat &img, double conversionTimeMs, double detectionTimeMs, double totalTimeMs) {
    double fontScale = img.cols/720.0;
    double lineHeight = 50 * img.rows / 1280;
    char msString[32];
    char fpsString[32];
    char totalString[32];
    char conversionString[32];
    double fps = 1000.0/totalTimeMs;
    snprintf(conversionString, sizeof(conversionString), "CVT: %g ms", conversionTimeMs);
    snprintf(msString, sizeof(msString), "DET: %g ms", detectionTimeMs);
    snprintf(totalString, sizeof(msString), "TOT: %g ms", totalTimeMs);
    snprintf(fpsString, sizeof(fpsString), "%g fps", fps);
    cv::putText(img, conversionString, cv::Point(25,lineHeight), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,255,0));
    cv::putText(img, msString, cv::Point(25,lineHeight*2), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,255,0));
    if (totalTimeMs <= 1000.0/60.0) {
        cv::putText(img, totalString, cv::Point(25,lineHeight*3), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,255,0));
        cv::putText(img, fpsString, cv::Point(25,lineHeight*4), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,255,0));
    } else if (totalTimeMs > 1000.0/60.0 && totalTimeMs < 1000.0/30.0) {
        cv::putText(img, totalString, cv::Point(25,lineHeight*3), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,255,255));
        cv::putText(img, fpsString, cv::Point(25,lineHeight*4), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,255,255));
    } else {
        cv::putText(img, totalString, cv::Point(25,lineHeight*3), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,0,255));
        cv::putText(img, fpsString, cv::Point(25,lineHeight*4), cv::FONT_HERSHEY_DUPLEX, fontScale, CV_RGB(0,0,255));
    }
}

static cv::Mat euler2rot(double pitch, double yaw, double roll) {
    cv::Mat rotationMatrix(3,3,CV_64F);

    double m00, m01, m02, m10, m11, m12, m20, m21, m22;

    // yaw      a
    // pitch    b
    // roll     y

    m00 = cos(yaw) * cos(pitch);
    m01 = cos(yaw) * sin(pitch) * sin(roll) - sin(yaw) * cos(roll);
    m02 = cos(yaw) * sin(pitch) * cos(roll) + sin(yaw) * sin(roll);
    m10 = sin(yaw) * cos(pitch);
    m11 = sin(yaw) * sin(pitch) * sin(roll) + cos(yaw) * cos(roll);
    m12 = sin(yaw) * sin(pitch) * cos(roll) - cos(yaw) * sin(roll);
    m20 = -sin(pitch);
    m21 = cos(pitch) * sin(roll);
    m22 = cos(pitch) * cos(roll);

    rotationMatrix.at<double>(0,0) = m00;
    rotationMatrix.at<double>(0,1) = m01;
    rotationMatrix.at<double>(0,2) = m02;
    rotationMatrix.at<double>(1,0) = m10;
    rotationMatrix.at<double>(1,1) = m11;
    rotationMatrix.at<double>(1,2) = m12;
    rotationMatrix.at<double>(2,0) = m20;
    rotationMatrix.at<double>(2,1) = m21;
    rotationMatrix.at<double>(2,2) = m22;
    
    return rotationMatrix;

}

@end
