#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WindowActivation : NSObject

/**
 * Activates the specified application.
 * @param pid The process identifier of the application to activate
 * @return OSStatus indicating success (0) or an error code
 */
+ (OSStatus)activateApp:(pid_t)pid;

@end

NS_ASSUME_NONNULL_END
