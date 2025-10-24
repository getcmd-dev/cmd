//
//  SUInstaller.m
//  Sparkle
//
//  Created by Andy Matuschak on 4/10/08.
//  Copyright 2008 Andy Matuschak. All rights reserved.
//

#import "SUInstaller.h"
#import "SUPlainInstaller.h"
#import "SUGuidedPackageInstaller.h"
#import "SUHost.h"
#import "SUConstants.h"
#import "SULog.h"
#import "SUErrors.h"
#import "SPUInstallationType.h"
#import "SUNormalization.h"
#import <os/log.h>


#include "AppKitPrevention.h"

@implementation SUInstaller

+ (nullable NSString *)installSourcePathInUpdateFolder:(NSString *)inUpdateFolder forHost:(SUHost *)host
#if SPARKLE_BUILD_PACKAGE_SUPPORT
                                             isPackage:(BOOL *)isPackagePtr isGuided:(BOOL *)isGuidedPtr
#endif
{
    NSParameterAssert(inUpdateFolder);
    NSParameterAssert(host);

    // Write to a debug log file to avoid Console.app <private> redaction
    NSString *logPath = [@"/tmp/sparkle_debug.log" stringByExpandingTildeInPath];
    NSFileHandle *logFile = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!logFile) {
        [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
        logFile = [NSFileHandle fileHandleForWritingAtPath:logPath];
    }
    [logFile seekToEndOfFile];

    #define LOG_TO_FILE(fmt, ...) do { \
        NSString *msg = [NSString stringWithFormat:@"%@ " fmt @"\n", [NSDate date], ##__VA_ARGS__]; \
        [logFile writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]]; \
    } while(0)

    LOG_TO_FILE(@"========== installSourcePathInUpdateFolder starting ==========");
    LOG_TO_FILE(@"Update folder: %@", inUpdateFolder);
    LOG_TO_FILE(@"Host bundle path: %@", [host bundlePath]);
    LOG_TO_FILE(@"Host name: %@", [host name]);
    LOG_TO_FILE(@"Host bundle identifier: %@", host.bundle.bundleIdentifier);

    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] ========== installSourcePathInUpdateFolder starting ==========");
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Update folder: %{public}@", inUpdateFolder);
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Host bundle path: %{public}@", [host bundlePath]);
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Host name: %{public}@", [host name]);
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Host bundle identifier: %{public}@", host.bundle.bundleIdentifier);

    // Search subdirectories for the application
    NSString *currentFile,
        *newAppDownloadPath = nil,
        *bundleFileName = [[host bundlePath] lastPathComponent],
        *alternateBundleFileName = [[host name] stringByAppendingPathExtension:[[host bundlePath] pathExtension]];

    LOG_TO_FILE(@"Looking for bundle filename: %@", bundleFileName);
    LOG_TO_FILE(@"Alternate bundle filename: %@", alternateBundleFileName);

    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Looking for bundle filename: %{public}@", bundleFileName);
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Alternate bundle filename: %{public}@", alternateBundleFileName);

#if SPARKLE_BUILD_PACKAGE_SUPPORT
    NSString *fallbackPackagePath = nil;

    BOOL isPackage = NO;
    BOOL isGuided = YES;
#endif
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:inUpdateFolder];
    NSString *bundleFileNameNoExtension = [bundleFileName stringByDeletingPathExtension];

    LOG_TO_FILE(@"Bundle filename (no ext): %@", bundleFileNameNoExtension);

    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Bundle filename (no ext): %{public}@", bundleFileNameNoExtension);

    while ((currentFile = [dirEnum nextObject])) {
        NSString *currentPath = [inUpdateFolder stringByAppendingPathComponent:currentFile];

        LOG_TO_FILE(@"Checking file: %@", currentFile);
        os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Checking file: %{public}@", currentFile);

        // Ignore all symbolic links and aliases
        {
            NSURL *currentPathURL = [NSURL fileURLWithPath:currentPath];

            NSNumber *symbolicLinkFlag = nil;
            [currentPathURL getResourceValue:&symbolicLinkFlag forKey:NSURLIsSymbolicLinkKey error:NULL];
            if (symbolicLinkFlag.boolValue) {
                SULog(SULogLevelDefault, @"[DEBUG] Skipping symlink: %@", currentFile);
                // NSDirectoryEnumerator won't recurse into symlinked directories
                continue;
            }

            NSNumber *aliasFlag = nil;
            [currentPathURL getResourceValue:&aliasFlag forKey:NSURLIsAliasFileKey error:NULL];

            if (aliasFlag.boolValue) {
                SULog(SULogLevelDefault, @"[DEBUG] Skipping alias: %@", currentFile);
                NSNumber *directoryFlag = nil;
                [currentPathURL getResourceValue:&directoryFlag forKey:NSURLIsDirectoryKey error:NULL];

                // Some DMGs have symlinks into /Applications! That's no good!
                if (directoryFlag.boolValue) {
                    [dirEnum skipDescendents];
                }

                continue;
            }
        }

        NSString *currentFilename = [currentFile lastPathComponent];
#if SPARKLE_BUILD_PACKAGE_SUPPORT
        NSString *currentExtension = [currentFile pathExtension];
        NSString *currentFilenameNoExtension = [currentFilename stringByDeletingPathExtension];
#endif
        if ([currentFilename isEqualToString:bundleFileName] ||
            [currentFilename isEqualToString:alternateBundleFileName]) // We found one!
        {
            LOG_TO_FILE(@"FOUND MATCH by filename! %@", currentPath);
#if SPARKLE_BUILD_PACKAGE_SUPPORT
            isPackage = NO;
#endif
            newAppDownloadPath = currentPath;
            break;
#if SPARKLE_BUILD_PACKAGE_SUPPORT
        } else if ([currentExtension isEqualToString:@"pkg"] ||
                   [currentExtension isEqualToString:@"mpkg"]) {
            LOG_TO_FILE(@"Found package file: %@", currentFile);
            if ([currentFilenameNoExtension isEqualToString:bundleFileNameNoExtension]) {
                LOG_TO_FILE(@"FOUND MATCH by package name! %@", currentPath);
                isPackage = YES;
                newAppDownloadPath = currentPath;
                break;
            } else {
                LOG_TO_FILE(@"Package name doesn't match, saving as fallback: %@", currentFile);
                // Remember any other non-matching packages we have seen should we need to use one of them as a fallback.
                fallbackPackagePath = currentPath;
            }
#endif
        } else {
            // Try matching on bundle identifiers in case the user has changed the name of the host app
            NSBundle *incomingBundle = [NSBundle bundleWithPath:currentPath];
            NSString *hostBundleIdentifier = host.bundle.bundleIdentifier;
            LOG_TO_FILE(@"Trying bundle identifier match for: %@", currentFile);
            if (incomingBundle) {
                LOG_TO_FILE(@"Bundle loaded. Bundle ID: %@ (looking for: %@)", incomingBundle.bundleIdentifier, hostBundleIdentifier);
            } else {
                LOG_TO_FILE(@"Could not load as bundle: %@", currentPath);
            }
            if (incomingBundle && [incomingBundle.bundleIdentifier isEqualToString:hostBundleIdentifier]) {
                LOG_TO_FILE(@"FOUND MATCH by bundle identifier! %@", currentPath);
#if SPARKLE_BUILD_PACKAGE_SUPPORT
                isPackage = NO;
#endif
                newAppDownloadPath = currentPath;
                break;
            }
        }
    }

    SULog(SULogLevelDefault, @"[DEBUG] Finished scanning files");

#if SPARKLE_BUILD_PACKAGE_SUPPORT
    // We don't have a valid path. Try to use the fallback package.

    if (newAppDownloadPath == nil && fallbackPackagePath != nil) {
        SULog(SULogLevelDefault, @"[DEBUG] Using fallback package: %@", fallbackPackagePath);
        isPackage = YES;
        newAppDownloadPath = fallbackPackagePath;
    }

    if (isPackage) {
        // Guided (or now "normal") installs used to be opt-in (i.e, Sparkle would detect foo.sparkle_guided.pkg or foo.sparkle_guided.mpkg),
        // Interactive installs are no longer supported, so isGuided = NO will later turn into an error

        // foo.app -> foo.sparkle_interactive.pkg or foo.sparkle_interactive.mpkg
        if ([[[newAppDownloadPath stringByDeletingPathExtension] pathExtension] isEqualToString:@"sparkle_interactive"]) {
            isGuided = NO;
        }
    }

    if (isPackagePtr)
        *isPackagePtr = isPackage;
    if (isGuidedPtr)
        *isGuidedPtr = isGuided;

#endif

    if (!newAppDownloadPath) {
        LOG_TO_FILE(@"========== FAILED TO FIND INSTALL SOURCE! ==========");
        LOG_TO_FILE(@"Searched %@ for %@.(app%@)", inUpdateFolder, bundleFileNameNoExtension,
#if SPARKLE_BUILD_PACKAGE_SUPPORT
              @"|pkg"
#else
              @""
#endif
              );
        os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] ========== FAILED TO FIND INSTALL SOURCE! ==========");
        os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] Searched %{public}@ for %{public}@.(app|pkg)", inUpdateFolder, bundleFileNameNoExtension);
    } else {
        LOG_TO_FILE(@"========== SUCCESS! Found install source at: %@ ==========", newAppDownloadPath);
        os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG] ========== SUCCESS! Found install source at: %{public}@ ==========", newAppDownloadPath);
    }

    [logFile closeFile];
    #undef LOG_TO_FILE

    return newAppDownloadPath;
}

+ (nullable id<SUInstallerProtocol>)installerForHost:(SUHost *)host expectedInstallationType:(NSString *)expectedInstallationType updateDirectory:(NSString *)updateDirectory connectionCodeSigningValidationSkipped:(BOOL)connectionCodeSigningValidationSkipped homeDirectory:(NSString *)homeDirectory userName:(NSString *)userName error:(NSError * __autoreleasing *)error
{
#if SPARKLE_BUILD_PACKAGE_SUPPORT
    BOOL isPackage = NO;
    BOOL isGuided = NO;
#endif
    
    NSString *newDownloadPath = [self installSourcePathInUpdateFolder:updateDirectory forHost:host
#if SPARKLE_BUILD_PACKAGE_SUPPORT
                                                            isPackage:&isPackage isGuided:&isGuided
#endif
    ];
    
    if (newDownloadPath == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: @"Couldn't find an appropriate update in the downloaded package." }];
        }
        return nil;
    }
    
#if SPARKLE_BUILD_PACKAGE_SUPPORT
    if (isPackage && connectionCodeSigningValidationSkipped) {
        // Package updates cannot update arbitrary bundles if code signing validation on the connection was skipped
        // (This means our helper is not code signed with an Apple issued certificate).
        // In this case, the main executable must be owned by root and the host must contain our installer tool
        
        NSString *installerExecutablePath = NSBundle.mainBundle.executableURL.URLByResolvingSymlinksInPath.path;
        if (installerExecutablePath == nil) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: @"The "@SPARKLE_RELAUNCH_TOOL_NAME" executable path failed to be retrieved, which is an internal error that shouldn't happen. Please try to update using a production build of your app." }];
            }
            
            return nil;
        }
        
        NSString *hostBundlePath = host.bundle.bundleURL.URLByResolvingSymlinksInPath.path;
        if (hostBundlePath == nil) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: @"The host bundle path to update to be retrieved, which is an internal error that shouldn't happen. Please try to update using a production build of your app." }];
            }
            
            return nil;
        }
        
        NSError *attributesError = nil;
        NSDictionary<NSFileAttributeKey, id> *fileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:installerExecutablePath error:&attributesError];
        
        if (fileAttributes == nil) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: @"File attributes failed to be retrieved from the "@SPARKLE_RELAUNCH_TOOL_NAME" executable, which is an internal error that shouldn't happen. Please try to update using a production build of your app." }];
            }
            
            return nil;
        }
        
        NSNumber *installerOwnerID = fileAttributes[NSFileOwnerAccountID];
        if (installerOwnerID == nil) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: @"File owner ID failed to be retrieved from the "@SPARKLE_RELAUNCH_TOOL_NAME" executable, which is an internal error that shouldn't happen. Please try to update using a production build of your app." }];
            }
            
            return nil;
        }
        
        // Check our helper is owned by root
        if (![installerOwnerID isEqual:@(0)]) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Due to security, updating apps with package installers is disabled when '%@' is not signed with the same Team ID as your app, and "@SPARKLE_RELAUNCH_TOOL_NAME" is not owned by root (this specific case) or not residing in '%@'. Please either test an exported & production build of your app, or for development, code sign your app and Sparkle's embedded helpers with the same team: https://sparkle-project.org/documentation/sandboxing#code-signing", installerExecutablePath, hostBundlePath] }];
            }
            
            return nil;
        }
        
        NSArray<NSString *> *installerExecutablePathComponents = installerExecutablePath.pathComponents;
        NSArray<NSString *> *hostBundlePathComponents = hostBundlePath.pathComponents;
        
        if (installerExecutablePathComponents.count <= hostBundlePathComponents.count) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Due to security, updating apps with package installers is disabled when '%@' is not signed with the same Team ID as your app, and "@SPARKLE_RELAUNCH_TOOL_NAME" is not owned by root or not residing in '%@' (this specific case). Please either test an exported & production build of your app, or for development, code sign your app and Sparkle's embedded helpers with the same team: https://sparkle-project.org/documentation/sandboxing#code-signing", installerExecutablePath, hostBundlePath] }];
            }
            
            return nil;
        }
        
        // Check out helper resides inside the host app to be updated
        if (![[installerExecutablePathComponents subarrayWithRange:NSMakeRange(0, hostBundlePathComponents.count)] isEqualToArray:hostBundlePathComponents]) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUMissingUpdateError userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Due to security, updating apps with package installers is disabled when '%@' is not signed with the same Team ID as your app, and "@SPARKLE_RELAUNCH_TOOL_NAME" is not owned by root or not residing in '%@' (this specific case). Please either test an exported & production build of your app, or for development, code sign your app and Sparkle's embedded helpers with the same team: https://sparkle-project.org/documentation/sandboxing#code-signing", installerExecutablePath, hostBundlePath] }];
            }
            
            return nil;
        }
    }
#else
    (void)connectionCodeSigningValidationSkipped;
#endif
    
    // Make sure we find the type of installer that we were expecting to find
    // We shouldn't implicitly trust the installation type fed into here from the appcast because the installation type helps us determine
    // ahead of time whether or not this installer tool should be ran as root or not
    id <SUInstallerProtocol> installer = nil;
#if SPARKLE_BUILD_PACKAGE_SUPPORT
    if (isPackage && isGuided) {
        if (![expectedInstallationType isEqualToString:SPUInstallationTypeGuidedPackage]) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUInstallationError userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Found guided package installer but '%@=%@' was probably missing in the appcast item enclosure", SUAppcastAttributeInstallationType, SPUInstallationTypeGuidedPackage] }];
            }
        } else {
            installer = [[SUGuidedPackageInstaller alloc] initWithPackagePath:newDownloadPath homeDirectory:homeDirectory userName:userName];
        }
    } else if (isPackage) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUInstallationError userInfo:@{ NSLocalizedDescriptionKey: @"Found interactive package installer (with 'sparkle_interactive' in the filename) but these are no longer supported. Please remove 'sparkle_interactive' from the filename." }];
        }
    } else
#endif
    {
        if (![expectedInstallationType isEqualToString:SPUInstallationTypeApplication]) {
            if (error != NULL) {
                *error = [NSError errorWithDomain:SUSparkleErrorDomain code:SUInstallationError userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Found regular application update but expected '%@=%@' from the appcast item enclosure instead", SUAppcastAttributeInstallationType, expectedInstallationType] }];
            }
        } else {
            NSString *normalizedInstallationPath = nil;
            if (SPARKLE_NORMALIZE_INSTALLED_APPLICATION_NAME) {
                normalizedInstallationPath = SUNormalizedInstallationPath(host);
            }
            
            // If we have a normalized path, we'll install to "#{CFBundleName}.app", but only if that path doesn't already exist. If we're "Foo 4.2.app," and there's a "Foo.app" in this directory, we don't want to overwrite it! But if there's no "Foo.app," we'll take that name.
            // Otherwise if there's no normalized path (the more likely case), we'll just use the host bundle's path
            // Check progress agent app which computes normalized path too according to these rules
            NSString *installationPath;
            if (normalizedInstallationPath != nil && ![[NSFileManager defaultManager] fileExistsAtPath:normalizedInstallationPath]) {
                installationPath = normalizedInstallationPath;
            } else {
                installationPath = host.bundlePath;
            }
            
            installer = [[SUPlainInstaller alloc] initWithHost:host bundlePath:newDownloadPath installationPath:installationPath];
        }
    }
    
    return installer;
}

@end
