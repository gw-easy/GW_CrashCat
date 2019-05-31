//
//  GW_MainWinViewController.m
//  CustomModalWindow
//
//  Created by answer on 7/26/16.
//  Copyright © 2016 answer. All rights reserved.
//

#import "GW_MainWinViewController.h"
#import "GW_XCArchiveInfo.h"
#import "GW_UUIDInfo.h"
#import "GW_XCArchiveFilesScrollView.h"


@interface GW_MainWinViewController ()<NSTableViewDelegate, NSTableViewDataSource, NSDraggingDestination,NSSearchFieldDelegate>

/**
 *  显示 archive 文件的 tableView
 */
@property (weak) IBOutlet NSTableView *archiveFilesTableView;

/**
 搜索框
 */
@property (weak) IBOutlet NSSearchField *searchBox;

/**
 搜索按钮
 */
@property (weak) IBOutlet NSButton *searchBtn;

/**
 *  存放 radio 的 box
 */
@property (weak) IBOutlet NSBox *radioBox;

/**
 *  archive 文件信息数组
 */
@property (copy) NSMutableArray<GW_XCArchiveInfo *> *archiveFilesInfo;

/**
 *  选中的 archive 文件信息
 */
//@property (strong) GW_XCArchiveInfo *selectedArchiveInfo;
@property (strong) GW_XCArchiveInfo *selectedArchiveInfo;
/**
 搜索产生的结果
 */
@property (strong) NSArray<GW_XCArchiveInfo *> *searchFiles;

/**
 * 选中的 UUID 信息
 */
@property (strong) GW_UUIDInfo *selectedUUIDInfo;

/**
 *  显示选中的 CPU 类型对应可执行文件的 UUID
 */
@property (weak) IBOutlet NSTextField *selectedUUIDLabel;

/**
 *  显示默认的 Slide Address
 */
@property (weak) IBOutlet NSTextField *defaultSlideAddressLabel;

/**
 *  显示错误内存地址
 */
@property (weak) IBOutlet NSTextField *errorMemoryAddressLabel;

/**
 *  错误信息
 */
@property (unsafe_unretained) IBOutlet NSTextView *errorMessageView;



@property (weak) IBOutlet GW_XCArchiveFilesScrollView *GW_XCArchiveFilesScrollView;

@end

@implementation GW_MainWinViewController
#pragma mark - 重置数据
- (IBAction)resetAllDataAction:(id)sender {
    [self reloadAllData];
}

#pragma mark - 开始搜索
- (IBAction)searchBtnAction:(id)sender {
    @synchronized (self) {
        NSMutableArray *searchA = [NSMutableArray array];
        for (int i = 0; i<_archiveFilesInfo.count; i++) {
            GW_XCArchiveInfo *infoM = _archiveFilesInfo[i];
            if ([infoM.archiveFileName containsString:_searchBox.stringValue]) {
                [searchA addObject:infoM];
            }
        }
        _searchFiles = searchA;
        [self.archiveFilesTableView reloadData];
    }
}

- (void)searchFieldDidStartSearching:(NSSearchField *)sender{
    NSLog(@"searchFieldDidStartSearching");
}

- (void)searchFieldDidEndSearching:(NSSearchField *)sender{
    _searchFiles = _archiveFilesInfo;
    [self.archiveFilesTableView reloadData];
}

- (void)reloadAllData{
    NSArray *archiveFilePaths = [self allDSYMFilePath];
    [self handleArchiveFileWithPath:archiveFilePaths];
}

- (void)windowDidLoad{
    [super windowDidLoad];
    
    [self.window registerForDraggedTypes:@[NSColorPboardType, NSFilenamesPboardType]];

    _searchBox.delegate = self;
    [self reloadAllData];
}



/**
 *  处理给定archive文件路径，获取 GW_XCArchiveInfo 对象
 *
 *  @param filePaths archvie 文件路径
 */
- (void)handleArchiveFileWithPath:(NSArray *)filePaths {
    _archiveFilesInfo = [NSMutableArray arrayWithCapacity:1];
    
    for(NSString *filePath in filePaths){
        GW_XCArchiveInfo *archiveInfo = [[GW_XCArchiveInfo alloc] init];

        NSString *fileName = filePath.lastPathComponent;
        //支持 xcarchive 文件和 dSYM 文件。
        if ([fileName hasSuffix:@".xcarchive"]){
            archiveInfo.archiveFilePath = filePath;
            archiveInfo.archiveFileName = fileName;
            archiveInfo.archiveFileType = GW_XCArchiveFileTypeXCARCHIVE;
            [self formatArchiveInfo:archiveInfo];
        }else if([fileName hasSuffix:@".app.dSYM"]){
            archiveInfo.dSYMFilePath = filePath;
            archiveInfo.dSYMFileName = fileName;
            archiveInfo.archiveFileType = GW_XCArchiveFileTypeDSYM;
            [self formatDSYM:archiveInfo];
        }else{
            continue;
        }

        [_archiveFilesInfo addObject:archiveInfo];
    }

    _searchFiles = _archiveFilesInfo;
    NSLog(@"%@----",NSStringFromRect(self.archiveFilesTableView.frame));
    [self.archiveFilesTableView reloadData];
}

/**
 *  从 archive 文件中获取 dsym 文件信息
 *
 *  @param archiveInfo archive info 对象
 */
- (void)formatArchiveInfo:(GW_XCArchiveInfo *)archiveInfo{
    NSString *dSYMsDirectoryPath = [NSString stringWithFormat:@"%@/dSYMs", archiveInfo.archiveFilePath];
    NSArray *keys = @[@"NSURLPathKey",@"NSURLFileResourceTypeKey",@"NSURLIsDirectoryKey",@"NSURLIsPackageKey"];
    NSArray *dSYMSubFiles= [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:dSYMsDirectoryPath] includingPropertiesForKeys:keys options:(NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants) error:nil];
    for(NSURL *fileURLs in dSYMSubFiles){
        if ([[fileURLs.relativePath lastPathComponent] hasSuffix:@"app.dSYM"]){
            archiveInfo.dSYMFilePath = fileURLs.relativePath;
            archiveInfo.dSYMFileName = fileURLs.relativePath.lastPathComponent;
        }
    }
    [self formatDSYM:archiveInfo];

}

/**
 * 根据 dSYM 文件获取 UUIDS。

 @param archiveInfo archiveInfo
 */
- (void)formatDSYM:(GW_XCArchiveInfo *)archiveInfo{
    //匹配 () 里面内容
    NSString *pattern = @"(?<=\\()[^}]*(?=\\))";
    NSRegularExpression *reg = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSString *commandString = [NSString stringWithFormat:@"dwarfdump --uuid \"%@\"",archiveInfo.dSYMFilePath];
    NSString *uuidsString = [self runCommand:commandString];
    NSArray *uuids = [uuidsString componentsSeparatedByString:@"\n"];

    NSMutableArray *uuidInfos = [NSMutableArray arrayWithCapacity:1];
    for(NSString *uuidString in uuids){
        NSArray* match = [reg matchesInString:uuidString options:NSMatchingReportCompletion range:NSMakeRange(0, [uuidString length])];
        if (match.count == 0) {
            continue;
        }
        for (NSTextCheckingResult *result in match) {
            NSRange range = [result range];
            GW_UUIDInfo *uuidInfo = [[GW_UUIDInfo alloc] init];
            uuidInfo.arch = [uuidString substringWithRange:range];
            uuidInfo.uuid = [uuidString substringWithRange:NSMakeRange(6, range.location-6-2)];
            uuidInfo.executableFilePath = [uuidString substringWithRange:NSMakeRange(range.location+range.length+2, [uuidString length]-(range.location+range.length+2))];
            [uuidInfos addObject:uuidInfo];
        }
        archiveInfo.uuidInfos = uuidInfos;
    }
}

/**
 * 获取所有 dSYM 文件目录.
 */
- (NSMutableArray *)allDSYMFilePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSRange userRange = [NSHomeDirectory() rangeOfString:NSUserName()];
    NSString *basePath = [NSHomeDirectory() substringToIndex:userRange.location+userRange.length];
    NSString *archivesPath = [basePath stringByAppendingPathComponent:@"Library/Developer/Xcode/Archives/"];
    NSURL *bundleURL = [NSURL fileURLWithPath:archivesPath];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:bundleURL
                                          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        errorHandler:^BOOL(NSURL *url, NSError *error)
    {
        if (error) {
            NSLog(@"[Error] %@ (%@)", error, url);
            return NO;
        }

        return YES;
    }];

    NSMutableArray *mutableFileURLs = [NSMutableArray array];
    for (NSURL *fileURL in enumerator) {
        NSString *filename;
        [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];

        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if ([filename hasPrefix:@"_"] && [isDirectory boolValue]) {
            [enumerator skipDescendants];
            continue;
        }

        //TODO:过滤部分没必要遍历的目录

        if ([filename hasSuffix:@".xcarchive"] && [isDirectory boolValue]){
            [mutableFileURLs addObject:fileURL.relativePath];
            [enumerator skipDescendants];
        }
    }
    return mutableFileURLs;
}

- (NSString *)runCommand:(NSString *)commandToRun
{
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    
    NSArray *arguments = @[@"-c",
            [NSString stringWithFormat:@"%@", commandToRun]];
//    NSLog(@"run command:%@", commandToRun);
    [task setArguments:arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}


/**
 * 导出 ipa 文件
   xcodebuild -exportArchive -exportFormat ipa -archivePath "/path/to/archiveFile" -exportPath "/path/to/ipaFile"
 */
- (IBAction)exportIPA:(id)sender {
    if(!_selectedArchiveInfo){
        NSLog(@"还未选中 archive 文件");
        return;
    }

    if(_selectedArchiveInfo.archiveFileType == GW_XCArchiveFileTypeDSYM){
        NSLog(@"archive 文件才可导出 ipa 文件");
        return;
    }


    NSString *ipaFileName = [_selectedArchiveInfo.archiveFileName stringByReplacingOccurrencesOfString:@"xcarchive" withString:@"ipa"];
    
    NSSavePanel *saveDlg = [[NSSavePanel alloc]init];
    saveDlg.title = ipaFileName;
    saveDlg.message = @"Save My File";
    saveDlg.allowedFileTypes = @[@"ipa"];
    saveDlg.nameFieldStringValue = ipaFileName;
    __weak __typeof(&*self)weakSelf = self;
    [saveDlg beginWithCompletionHandler: ^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton){
            NSURL  *url =[saveDlg URL];
            NSLog(@"filePath url%@",url);
            NSString *exportCmd = [NSString stringWithFormat:@"/usr/bin/xcodebuild -exportArchive -exportFormat ipa -archivePath \"%@\" -exportPath \"%@\"", weakSelf.selectedArchiveInfo.archiveFilePath, url.relativePath];
            [weakSelf runCommand:exportCmd];
        }
    }];
}

#pragma mark - NSTableViewDataSources
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{
    NSLog(@"%lu------",(unsigned long)self.searchFiles.count);
    return [self.searchFiles count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    GW_XCArchiveInfo *archiveInfo= _searchFiles[row];
    if(archiveInfo.archiveFileType == GW_XCArchiveFileTypeXCARCHIVE){
        return archiveInfo.archiveFileName;
    }else if(archiveInfo.archiveFileType == GW_XCArchiveFileTypeDSYM){
        return archiveInfo.dSYMFileName;
    }
    return archiveInfo.archiveFileName;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{

    GW_XCArchiveInfo *archiveInfo= _searchFiles[row];
    NSString *identifier = tableColumn.identifier;
    NSView *view = [tableView makeViewWithIdentifier:identifier owner:self];
    NSArray *subviews = view.subviews;
    if (subviews.count > 0) {
        if ([identifier isEqualToString:@"name"]) {
            NSTextField *textField = subviews[0];
            if(archiveInfo.archiveFileType == GW_XCArchiveFileTypeXCARCHIVE){
                textField.stringValue = archiveInfo.archiveFileName;
            }else if(archiveInfo.archiveFileType == GW_XCArchiveFileTypeDSYM){
                textField.stringValue = archiveInfo.dSYMFileName;
            }
        }
    }
    return view;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification{
    NSInteger row = [notification.object selectedRow];
    _selectedArchiveInfo= _searchFiles[row];
    [self resetPreInformation];

    CGFloat radioButtonWidth = CGRectGetWidth(self.radioBox.contentView.frame);
    CGFloat radioButtonHeight = 18;
    __weak __typeof(&*self)weakSelf = self;
    [_selectedArchiveInfo.uuidInfos enumerateObjectsUsingBlock:^(GW_UUIDInfo *uuidInfo, NSUInteger idx, BOOL *stop) {
        CGFloat space = (CGRectGetHeight(weakSelf.radioBox.contentView.frame) - weakSelf.selectedArchiveInfo.uuidInfos.count * radioButtonHeight) / (weakSelf.selectedArchiveInfo.uuidInfos.count + 1);
        CGFloat y = space * (idx + 1) + idx * radioButtonHeight;
        NSButton *radioButton = [[NSButton alloc] initWithFrame:NSMakeRect(10,y,radioButtonWidth,radioButtonHeight)];
        [radioButton setButtonType:NSRadioButton];
        [radioButton setTitle:uuidInfo.arch];
        radioButton.tag = idx + 1;
        [radioButton setAction:@selector(radioButtonAction:)];
        [weakSelf.radioBox.contentView addSubview:radioButton];
    }];
}

/**
 * 重置之前显示的信息
 */
- (void)resetPreInformation {
    [self.radioBox.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    _selectedUUIDInfo = nil;
    self.selectedUUIDLabel.stringValue = @"";
    self.defaultSlideAddressLabel.stringValue = @"";
    self.errorMemoryAddressLabel.stringValue = @"";
    [self.errorMessageView setString:@""];
}

- (void)radioButtonAction:(id)sender{
    NSButton *radioButton = sender;
    NSInteger tag = radioButton.tag;
    _selectedUUIDInfo = _selectedArchiveInfo.uuidInfos[tag - 1];
    _selectedUUIDLabel.stringValue = _selectedUUIDInfo.uuid;
    _defaultSlideAddressLabel.stringValue = _selectedUUIDInfo.defaultSlideAddress;
}

- (void)doubleActionMethod{
    NSLog(@"double action");
}

- (IBAction)analyse:(id)sender {
    if(self.selectedArchiveInfo == nil){
        return;
    }

    if(self.selectedUUIDInfo == nil){
        return;
    }

    if([self.defaultSlideAddressLabel.stringValue isEqualToString:@""]){
        return;
    }

    if([self.errorMemoryAddressLabel.stringValue isEqualToString:@""]){
        return;
    }

    NSString *commandString = [NSString stringWithFormat:@"xcrun atos -arch %@ -o \"%@\" -l %@ %@", self.selectedUUIDInfo.arch, self.selectedUUIDInfo.executableFilePath, self.defaultSlideAddressLabel.stringValue, self.errorMemoryAddressLabel.stringValue];
    NSString *result = [self runCommand:commandString];
    [self.errorMessageView setString:result];
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender{

    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSColorPboardType] ) {
        if (sourceDragMask & NSDragOperationGeneric) {
            return NSDragOperationGeneric;
        }
    }
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & NSDragOperationLink) {
            return NSDragOperationLink;
        } else if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender{

}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];

    if ([[pboard types] containsObject:NSURLPboardType] ) {
        NSURL *fileURL = [NSURL URLFromPasteboard:pboard];
        NSLog(@"%@",fileURL);
    }

    if([[pboard types] containsObject:NSFilenamesPboardType]){
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        NSMutableArray *archiveFilePaths = [NSMutableArray arrayWithCapacity:1];
        for(NSString *filePath in files){
            if([filePath.pathExtension isEqualToString:@"xcarchive"]){
                NSLog(@"%@", filePath);
                [archiveFilePaths addObject:filePath];
            }

            if([filePath.pathExtension isEqualToString:@"dSYM"]){
                [archiveFilePaths addObject:filePath];
            }
        }
        
        if(archiveFilePaths.count == 0){
            NSLog(@"没有包含任何 xcarchive 文件");
            return NO;
        }
        
        [self resetPreInformation];

        [self handleArchiveFileWithPath:archiveFilePaths];

        
    }

    return YES;
}


@end
