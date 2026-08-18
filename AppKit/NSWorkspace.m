/* Copyright (c) 2006-2007 Christopher J. W. Lloyd <cjwl@objc.net>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/NSRaise.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSEvent.h>
#import <Foundation/Foundation.h>

NSString *const NSWorkspaceApplicationKey = @"NSWorkspaceApplicationKey";

NSString *const NSWorkspaceWillPowerOffNotification =
        @"NSWorkspaceWillPowerOffNotification";

NSString *const NSWorkspaceRecycleOperation = @"NSWorkspaceRecycleOperation";

NSString *const NSWorkspaceLaunchConfigurationAppleEvent =
        @"NSWorkspaceLaunchConfigurationAppleEvent";
NSString *const NSWorkspaceLaunchConfigurationArguments =
        @"NSWorkspaceLaunchConfigurationArguments";
NSString *const NSWorkspaceLaunchConfigurationEnvironment =
        @"NSWorkspaceLaunchConfigurationEnvironment";
NSString *const NSWorkspaceLaunchConfigurationArchitecture =
        @"NSWorkspaceLaunchConfigurationArchitecture";

NSString *const NSWorkspaceActiveSpaceDidChangeNotification =
        @"NSWorkspaceActiveSpaceDidChangeNotification";
const NSNotificationName NSWorkspaceDidDeactivateApplicationNotification =
        @"NSWorkspaceDidDeactivateApplicationNotification";
const NSNotificationName NSWorkspaceDidWakeNotification = 
        @"NSWorkspaceDidWakeNotification";
NSString *const NSWorkspaceDidLaunchApplicationNotification =
        @"NSWorkspaceDidLaunchApplicationNotification";
NSString *const NSWorkspaceDidTerminateApplicationNotification =
        @"NSWorkspaceDidTerminateApplicationNotification";
const NSNotificationName NSWorkspaceScreensDidSleepNotification =
        @"NSWorkspaceScreensDidSleepNotification";
const NSNotificationName NSWorkspaceScreensDidWakeNotification =
        @"NSWorkspaceScreensDidWakeNotification";
const NSNotificationName NSWorkspaceWillSleepNotification =
        @"NSWorkspaceWillSleepNotification";
const NSNotificationName NSWorkspaceSessionDidBecomeActiveNotification =
        @"NSWorkspaceSessionDidBecomeActiveNotification";
const NSNotificationName NSWorkspaceSessionDidResignActiveNotification =
        @"NSWorkspaceSessionDidResignActiveNotification";
NSNotificationName const NSWorkspaceDidActivateApplicationNotification = @"NSWorkspaceDidActivateApplicationNotification";

const NSNotificationName
        NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification =
                @"NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification";

NSNotificationName NSWorkspaceDidMountNotification = @"NSWorkspaceDidMountNotification";
NSNotificationName NSWorkspaceDidUnmountNotification = @"NSWorkspaceDidUnmountNotification";
NSNotificationName NSWorkspaceWillUnmountNotification = @"NSWorkspaceWillUnmountNotification";

@implementation NSWorkspace

+ (NSWorkspace *) sharedWorkspace {
    return NSThreadSharedInstance(@"NSWorkspace");
}

- init {
    _notificationCenter = [[NSNotificationCenter alloc] init];
    return self;
}

- (NSNotificationCenter *) notificationCenter {
    return _notificationCenter;
}

- (NSImage *) iconForFile: (NSString *) path {
    return [NSImage imageNamed: @"NSApplicationIcon"];
}

- (NSImage *) iconForFiles: (NSArray *) array {
    return [NSImage imageNamed: @"NSApplicationIcon"];
}

- (NSImage *) iconForFileType: (NSString *) type {
    return [NSImage imageNamed: @"NSApplicationIcon"];
}

- (NSString *) localizedDescriptionForType: (NSString *) type {
    return type;
}

- (BOOL) filenameExtension: (NSString *) extension
            isValidForType: (NSString *) type
{
    return NO;
}

- (NSString *) preferredFilenameExtensionForType: (NSString *) type {
    return nil;
}

- (BOOL) type: (NSString *) type conformsToType: (NSString *) conformsToType {
    return NO;
}

- (NSString *) typeOfFile: (NSString *) path error: (NSError **) error {
    return nil;
}

- (BOOL) openFile: (NSString *) path {
    return NO;
}

- (BOOL) openFile: (NSString *) path withApplication: (NSString *) application {
    return NO;
}

- (BOOL) openTempFile: (NSString *) path {
    return NO;
}

- (BOOL) openFile: (NSString *) path
        fromImage: (NSImage *) image
               at: (NSPoint) point
           inView: (NSView *) view
{
    return NO;
}

- (BOOL) openFile: (NSString *) path
        withApplication: (NSString *) application
          andDeactivate: (BOOL) deactivate
{
    return NO;
}

- (BOOL) openURL: (NSURL *) url {
    return NO;
}

- (BOOL) selectFile: (NSString *) path
        inFileViewerRootedAtPath: (NSString *) rootedAtPath
{
    return NO;
}

- (void) slideImage: (NSImage *) image from: (NSPoint) from to: (NSPoint) to {
}

- (BOOL) performFileOperation: (NSString *) operation
                       source: (NSString *) source
                  destination: (NSString *) destination
                        files: (NSArray *) files
                          tag: (NSInteger *) tag
{
    return NO;
}

- (BOOL) getFileSystemInfoForPath: (NSString *) path
                      isRemovable: (BOOL *) isRemovable
                       isWritable: (BOOL *) isWritable
                    isUnmountable: (BOOL *) isUnmountable
                      description: (NSString **) description
                             type: (NSString **) type
{
    return NO;
}

- (BOOL) getInfoForFile: (NSString *) path
            application: (NSString **) application
                   type: (NSString **) type
{
    *application = @"";
    *type = @"";
    return YES;
}

- (void) checkForRemovableMedia {
}

- (NSArray *) mountNewRemovableMedia {
    return @[];
}

- (NSArray *) mountedRemovableMedia {
    return @[];
}

- (NSArray *) mountedLocalVolumePaths {
    return @[];
}

- (BOOL) unmountAndEjectDeviceAtPath: (NSString *) path {
    return NO;
}

- (BOOL) fileSystemChanged {
    return NO;
}

- (BOOL) userDefaultsChanged {
    return NO;
}

- (void) noteFileSystemChanged {
}

- (void) noteFileSystemChanged: (NSString *) path {
}

- (void) noteUserDefaultsChanged {
}

- (BOOL) isFilePackageAtPath: (NSString *) path {
    NSString *ext = [path pathExtension];
    return [ext isEqualToString: @"app"] || [ext isEqualToString: @"bundle"] || [ext isEqualToString: @"framework"];
}

- (NSString *) absolutePathForAppBundleWithIdentifier: (NSString *) identifier {
    return nil;
}

- (NSString *) pathForApplication: (NSString *) application {
    return nil;
}

- (NSArray *) launchedApplications {
    return @[];
}

- (NSArray *) runningApplications {
    return @[];
}

- (BOOL) launchApplication: (NSString *) application {
    return NO;
}

- (BOOL) launchApplication: (NSString *) application
                  showIcon: (BOOL) showIcon
                autolaunch: (BOOL) autolaunch
{
    return NO;
}

- (void) findApplications {
}

- (NSDictionary *) activeApplication {
    return nil;
}

- (void) hideOtherApplications {
}

- (NSInteger) extendPowerOffBy: (NSInteger) milliseconds {
    return 0;
}

- (NSString *) fullPathForApplication: (NSString *) appName {
    return nil;
}

- (void) openURL: (NSURL *) url configuration: (id) config completionHandler: (void (^)(id, NSError *)) handler {
    if (handler) handler(nil, nil);
}

- (BOOL) openFile: (NSString *) fullPath application: (NSString *) appName {
    return NO;
}

- (BOOL) launchAppWithBundleIdentifier: (NSString *) bundleId options: (NSUInteger) options additionalEventParamDescriptor: (NSAppleEventDescriptor *) descriptor launchIdentifier: (NSNumber **) identifier {
    return NO;
}

- (BOOL) selectFile: (NSString *) inFileOrNullViewerType: (NSString *) inFileType {
    return NO;
}

- (BOOL) selectFile: (NSString *) inFile toShowAtPath: (NSString *) inShowPath {
    return NO;
}

- (void) activateFileViewerSelectingURLs: (NSArray *) urls {
}

- (id) frontmostApplication {
    return nil;
}

- (NSRect) iconRectForBadgeContentRect: (NSRect) contentRect {
    return NSZeroRect;
}

- (BOOL) setIconImage: (NSImage *) image forFile: (NSString *) fileOptions: (NSDictionary *) options {
    return NO;
}

- (BOOL) shouldDelayWindowsOrderingForEvent: (NSEvent *) event {
    return NO;
}

- (void) findApplicationsWithOptions: (NSDictionary *) options {
}

- (void) setRecentDocumentPList: (NSString *) path {
}

- (id) requestAuthorizationOfType: (NSUInteger) type error: (NSError **) error {
    return nil;
}

@end

@implementation NSWorkspace (CocotronAdditions)

- (BOOL) isFileHiddenAtPath: (NSString *) path {
    return NO;
}

@end

static dispatch_once_t _initOnceNsWorkspaceOpenConfig;
static id _singletonNsWorkspaceOpenConfig;

@implementation NSWorkspaceOpenConfiguration
+ (instancetype)configuration {
    dispatch_once(&_initOnceNsWorkspaceOpenConfig, ^{
        _singletonNsWorkspaceOpenConfig = [[NSWorkspaceOpenConfiguration alloc] init];
    });
    return _singletonNsWorkspaceOpenConfig;
}

@end
