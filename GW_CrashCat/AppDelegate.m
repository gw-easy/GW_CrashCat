//
//  AppDelegate.m
//  GW_CrashCat
//
//  Created by zdwx on 2019/5/30.
//  Copyright © 2019 DoubleK. All rights reserved.
//

#import "AppDelegate.h"
#import "GW_MainWinViewController.h"
@interface AppDelegate ()
@property (strong ,nonatomic) GW_MainWinViewController *mainVC;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    _mainVC = [[GW_MainWinViewController alloc] initWithWindowNibName:@"GW_MainWinViewController"];
    [_mainVC showWindow:self];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
