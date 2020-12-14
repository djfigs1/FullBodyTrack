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

#define MARKER_DICTIONARY_TYPE aruco::DICT_4X4_1000


using namespace cv;

static cv::Ptr<aruco::Dictionary> MARKER_DICTIONARY = aruco::getPredefinedDictionary(MARKER_DICTIONARY_TYPE);

@implementation CVImgOutput

@end

@implementation ChArUcoBoardResult

@end

@implementation TrackerLocation

@end

@implementation TrackerResult

@end

@implementation TrackerObj
- (cv::Ptr<cv::aruco::Board>) generateBoard {
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
            cv::Point3f point = Point3f([corner[0] floatValue], [corner[1] floatValue], [corner[2] floatValue]);
            marker_corners.push_back(point);
        }
        
        allMarkerCorners.push_back(marker_corners);
        
    }
    cv::Ptr<aruco::Board> board = aruco::Board::create(allMarkerCorners, MARKER_DICTIONARY, markerIds);
    return board;
}
@end

@implementation OpenCVWrapper
static cv::Ptr<aruco::CharucoBoard> board = aruco::CharucoBoard::create(5, 7, 0.035f, 0.0175f, MARKER_DICTIONARY);
static cv::Ptr<aruco::DetectorParameters> parameters = aruco::DetectorParameters::create();
static std::vector<std::vector<Point2f>> allCharucoCorners;
static std::vector<std::vector<int>> allCharucoIds;

static NSMutableArray<TrackerObj*>* _trackerObjects;
static std::map<char, cv::Ptr<aruco::Board>> trackerBoards;
static cv::Mat cameraMatrix, distCoeffs;

+ (void) initialize {
    parameters.get()->cornerRefinementMethod = aruco::CORNER_REFINE_SUBPIX;
    //parameters.get()->adaptiveThreshWinSizeMin = 23;
    //parameters.get()->adaptiveThreshWinSizeMax = 23;
}

+ (void) setWinSize: (int) winSize {
    parameters.get()->cornerRefinementWinSize = winSize;
}

+ (NSString *) openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s", CV_VERSION];
}

+ (NSMutableArray<TrackerObj*>*) trackerObjects {
    if (_trackerObjects == nil) {
        _trackerObjects = [[NSMutableArray alloc] init];
    }
    return _trackerObjects;
}

+ (void) addTracker: (TrackerObj *)tracker {
    auto trackers = [OpenCVWrapper trackerObjects];
    if (trackers.count < INT8_MAX) {
        tracker.tracker_id = trackers.count + 1;
        [trackers addObject: tracker];
        cv::Ptr<aruco::Board> board = [tracker generateBoard];
        trackerBoards[tracker.tracker_id] = board;
    } else {
        // can't add more trackers
        return;
    }
    
}

+ (NSArray<TrackerObj*>*) getAllTrackers {
    auto trackers = [OpenCVWrapper trackerObjects];
    return [trackers copy];
}

+ (void) setCameraPropeties: (CameraProperties) properties {
    //double camMat[9] = {properties.fx,0,properties.cx,0,properties.fy,properties.cy,0,0,1};
    cameraMatrix = (Mat1d(3,3) << properties.fx, 0, properties.cx, 0, properties.fy, properties.cy, 0, 0, 1);
    distCoeffs = (Mat1d(1,5) << properties.distCoeffs[0], properties.distCoeffs[1], properties.distCoeffs[2], properties.distCoeffs[3], properties.distCoeffs[4]);
}

+ (void) setCameraRefine: (bool) refine {
    parameters.get()->cornerRefinementMethod = refine ? aruco::CORNER_REFINE_SUBPIX : aruco::CORNER_REFINE_NONE;
}

+ (CVImgOutput*) getMarkersFromBuffer: (CVImageBufferRef) buffer  {
    Mat rgbMat = [OpenCVWrapper _rgbMatFrom:buffer];
    std::vector<int> ids;
    std::vector<std::vector<Point2f>> corners;
    aruco::detectMarkers(rgbMat, MARKER_DICTIONARY, corners, ids);
    aruco::drawDetectedMarkers(rgbMat, corners, ids);
    
    if (!(cameraMatrix.empty() || distCoeffs.empty())) {
        std::vector<cv::Vec3d> rvecs, tvecs;
        aruco::estimatePoseSingleMarkers(corners, 0.02f, cameraMatrix, distCoeffs, rvecs, tvecs);
        for (int i=0; i<rvecs.size();i++) {
            auto rvec = rvecs[i];
            auto tvec = tvecs[i];
            aruco::drawAxis(rgbMat, cameraMatrix, distCoeffs, rvec, tvec, 0.05);
        }
    }
    
    UIImage *outputImage = MatToUIImage(rgbMat);
    CVImgOutput* output = [[CVImgOutput alloc] init];
    output.outputImage = outputImage;
    return output;
}

+ (TrackerResult*) getTrackersFromBuffer: (CVImageBufferRef) buffer  {
    Mat rgbMat = [OpenCVWrapper _rgbMatFrom:buffer];
    Mat grayMat;
    cv::cvtColor(rgbMat, grayMat, cv::COLOR_BGRA2GRAY);
    Mat thresMat;
    cv::threshold(grayMat, thresMat, 40, 255, cv::THRESH_BINARY);
    
    std::vector<int> ids;
    std::vector<std::vector<Point2f>> corners;
    
    aruco::detectMarkers(thresMat, MARKER_DICTIONARY, corners, ids, parameters);
    TrackerResult* result = [[TrackerResult alloc] init];
    NSMutableArray<TrackerLocation*>* locations = [[NSMutableArray alloc] init];
    auto trackers = [OpenCVWrapper trackerObjects];
    
    if (!(cameraMatrix.empty() || distCoeffs.empty()) && ids.size() > 0) {
        aruco::drawDetectedMarkers(rgbMat, corners, ids);
        std::vector<cv::Vec3d> rvecs, tvecs;
        for (TrackerObj* trackerobj in trackers) {
            cv::Ptr<aruco::Board> board_pointer = trackerBoards[trackerobj.tracker_id];
            TrackerLocation* location = [[TrackerLocation alloc] init];
            location.tracker_id = trackerobj.tracker_id;
            location.visible = false;
            if (board_pointer != nullptr) {
                cv::Vec3d rvec, tvec;
                int valid = aruco::estimatePoseBoard(corners, ids, board_pointer, cameraMatrix, distCoeffs, rvec, tvec);
                if (valid > 0) {
                    location.visible = true;
                    location.rvec = {rvec[0], rvec[1], rvec[2]};
                    location.tvec = {tvec[0], tvec[1], tvec[2]};
                    aruco::drawAxis(rgbMat, cameraMatrix, distCoeffs, rvec, tvec, 0.05);
                }
                
            }
            [locations addObject:location];
        }
    } else {
        // set all locations to empty
        for (TrackerObj* trackerobj in trackers) {
            TrackerLocation* location = [[TrackerLocation alloc] init];
            location.tracker_id = trackerobj.tracker_id;
            location.visible = false;
            [locations addObject:location];
        }
    }
    
    UIImage *outputImage = MatToUIImage(rgbMat);
    result.outputImage = outputImage;
    result.trackers = [locations copy];
    return result;
}

+ (ChArUcoBoardResult*) findChArUcoBoard: (CVImageBufferRef)buffer saveResult: (bool) save {
    Mat rgbMat = [OpenCVWrapper _rgbMatFrom: buffer];
    std::vector<int> ids;
    std::vector<std::vector<Point2f>> corners;
    aruco::detectMarkers(rgbMat, MARKER_DICTIONARY, corners, ids);
    
    ChArUcoBoardResult* result = [[ChArUcoBoardResult alloc] init];
    result.boardFound = false;
    
    if (ids.size() > 0) {
        aruco::drawDetectedMarkers(rgbMat, corners);
        std::vector<Point2f> charucoCorners;
        std::vector<int> charucoIds;
        aruco::interpolateCornersCharuco(corners, ids, rgbMat, board, charucoCorners, charucoIds);
        if (charucoIds.size() > 0) {
            result.boardFound = true;
            if (save) {
                allCharucoCorners.push_back(charucoCorners);
                allCharucoIds.push_back(charucoIds);
            }
            aruco::drawDetectedCornersCharuco(rgbMat, charucoCorners, charucoIds, Scalar(255,0,0));
        }
    }
    
    UIImage* outputImage = MatToUIImage(rgbMat);
    result.outputImage = outputImage;
    return result;
}

+ (int) boardsCaptured {
    return (int) allCharucoIds.size();
}

+ (CameraProperties) calibrateStoredBoards {
    Mat cameraMatrix, distCoeffs;
    aruco::calibrateCameraCharuco(allCharucoCorners, allCharucoIds, board, cv::Size(1080, 1920), cameraMatrix, distCoeffs);
    CameraProperties properties;
    properties.fx = cameraMatrix.at<double>(0,0);
    properties.fy = cameraMatrix.at<double>(1,1);
    properties.cx = cameraMatrix.at<double>(0,2);
    properties.cy = cameraMatrix.at<double>(1,2);
    for (int i=0; i<5; i++) {
        properties.distCoeffs[i] = distCoeffs.at<double>(i);
    }
    
    return properties;
    
}

#pragma mark Private
+ (Mat) _rgbMatFrom: (CVImageBufferRef) buffer {
    CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    void *baseaddress = CVPixelBufferGetBaseAddress(buffer);
    int width = (int) CVPixelBufferGetWidth(buffer);
    int height = (int) CVPixelBufferGetHeight(buffer);
    int bytesPerRow = (int) CVPixelBufferGetBytesPerRow(buffer);
    
    Mat imgMat(height, width, CV_8UC4, baseaddress, bytesPerRow);
    Mat rgbMat;
    cvtColor(imgMat, rgbMat, COLOR_BGRA2RGB);
    //resize(rgbMat, rgbMat, cv::Size(), 0.25, 0.25, INTER_CUBIC);
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    return rgbMat;
}

@end
