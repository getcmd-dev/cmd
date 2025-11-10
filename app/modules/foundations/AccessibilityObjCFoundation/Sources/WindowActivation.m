#import "WindowActivation.h"

@implementation WindowActivation

+ (OSStatus)activateApp:(pid_t)pid
{
    if(pid == -1) {
        return procNotFound; // Process identifier is invalid.
    }

    ProcessSerialNumber process;
    OSStatus error = GetProcessForPID(pid, &process); // Deprecated, but replacement (NSRunningApplication:activateWithOptions:] does not work properly on Big Sur.
    if(error) {
        return error; // Process could not be obtained. Evaluate error (e.g. using osstatus.com) to understand why.
    }

    return SetFrontProcess(&process); // Deprecated, but replacement (NSRunningApplication:activateWithOptions:] does not work properly on Big Sur.
}

@end
