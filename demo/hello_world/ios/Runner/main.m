// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>
#import <Flutter/Flutter.h>
#import "AppDelegate.h"
#import <Flutter/FlutterDartProject.h>



int main(int argc, char * argv[]) {
    #ifndef DEBUG
    #ifdef AOT_CUSTOM
       NSString *dartIsolateSnapshotDataPath = [[NSBundle mainBundle] pathForResource:@"_kDartIsolateSnapshotData" ofType:@"dat"];
       NSString *dartVmSnapshotDataPath = [[NSBundle mainBundle] pathForResource:@"_kDartVmSnapshotData" ofType:@"dat"];
       NSString *assetPath = [NSString stringWithFormat:@"%@%@%@",[[NSBundle mainBundle] resourcePath],@"/",@"flutter_assets"];
       NSLog(@"main dartIsolateSnapshotDataPath = %@ dartVmSnapshotDataPath = %@ assetPath = %@", dartIsolateSnapshotDataPath,dartVmSnapshotDataPath,assetPath);
       [FlutterDartProject setAotFlutterAssertsPath:assetPath];
       NSData *dartIsolateSnapshotData = [NSData dataWithContentsOfFile:dartIsolateSnapshotDataPath];
       [FlutterDartProject setAotFlutterIsolateSnapshotData:dartIsolateSnapshotData];
       NSData *dartVmSnapshotData = [NSData dataWithContentsOfFile:dartVmSnapshotDataPath];
       [FlutterDartProject setAotFlutterVmSnapshotData:dartVmSnapshotData];
    #endif
    #endif
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([AppDelegate class]));
    }
}

