//
//  GW_XCArchiveInfo.h
//  DSYMTools
//
//  Created by gw on 7/27/16.
//  Copyright © 2016 gw. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * 文件类型
 */
typedef NS_ENUM(NSInteger, GW_XCArchiveFileType){
    // archive 文件
    GW_XCArchiveFileTypeXCARCHIVE = 1,
    //dsym 文件
    GW_XCArchiveFileTypeDSYM = 2
};

@class GW_UUIDInfo;

@interface GW_XCArchiveInfo : NSObject

/**
 *  dSYM 路径
 */
@property (copy) NSString *dSYMFilePath;

/**
 * dSYM 文件名
 */
@property (copy) NSString *dSYMFileName;

/**
 * archive 文件名
 */
@property (copy) NSString *archiveFileName;

/**
 * archive 文件路径
 */
@property (copy) NSString *archiveFilePath;

/**
 * uuids
 */
@property (copy) NSArray<GW_UUIDInfo *> *uuidInfos;

/**
 * 文件类型
 */
@property (assign) GW_XCArchiveFileType archiveFileType;

@end
