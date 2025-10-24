//
//  AgentConnection.m
//  Sparkle
//
//  Created by Mayur Pawashe on 7/17/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#import "AgentConnection.h"
#import "SPUMessageTypes.h"
#import "SPUInstallerAgentProtocol.h"
#import "SUInstallerAgentInitiationProtocol.h"
#import "SUCodeSigningVerifier.h"
#import "SULog.h"
#import <os/log.h>


#include "AppKitPrevention.h"

@interface AgentConnection () <NSXPCListenerDelegate, SUInstallerAgentInitiationProtocol>

@end

@implementation AgentConnection
{
    NSXPCListener *_xpcListener;
    NSXPCConnection *_activeConnection;
    __weak id<AgentConnectionDelegate> _delegate;
}

@synthesize agent = _agent;
@synthesize connected = _connected;
@synthesize invalidationError = _invalidationError;

- (instancetype)initWithHostBundleIdentifier:(NSString *)bundleIdentifier delegate:(id<AgentConnectionDelegate>)delegate
{
    self = [super init];
    if (self != nil) {
        // Agents should always be the one that connect to daemons due to how mach bootstraps work
        // For this reason, we are the ones that are creating a listener, not the agent
        NSString *serviceName = SPUProgressAgentServiceNameForBundleIdentifier(bundleIdentifier);
        os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] AgentConnection init with service name: %{public}@", serviceName);

        _xpcListener = [[NSXPCListener alloc] initWithMachServiceName:serviceName];
        _xpcListener.delegate = self;
        _delegate = delegate;
    }
    return self;
}

- (void)startListener
{
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] AgentConnection startListener called");
    [_xpcListener resume];
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] AgentConnection XPC listener resumed, waiting for connection...");
}

- (void)invalidate
{
    _delegate = nil;
    
    [_activeConnection invalidate];
    // Don't need to set _activeConnection to nil, we don't expect new connections
    
    [_xpcListener invalidate];
    _xpcListener = nil;
}

- (BOOL)listener:(NSXPCListener *)__unused listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] AgentConnection received new connection attempt");

    if (_activeConnection != nil) {
        os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] REJECTING: Already have an active connection");
        SULog(SULogLevelError, @"Error: Rejecting new connection for agent due already having an active connection");

        [newConnection invalidate];
        return NO;
    }

    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Validating connection code signing...");

    // Hardening but not critical for security
    NSError *validationError = nil;
    SUValidateConnectionStatus validationStatus = [SUCodeSigningVerifier validateConnection:newConnection options:SUValidateConnectionOptionDefault error:&validationError];

    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Validation status: %{public}lu", validationStatus);

    switch (validationStatus) {
        case SUValidateConnectionStatusSetCodeSigningRequirementSuccess:
            os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Validation SUCCESS: Code signing requirement met");
            break;
        case SUValidateConnectionStatusSetNoRequirementSuccess:
            os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Validation SUCCESS: No requirement needed");
            break;
        case SUValidateConnectionStatusAPIFailure:
        case SUValidateConnectionStatusCodeSigningRequirementFailure:
        case SUValidateConectionNoSupportedValidationMethodFailure:
            os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] REJECTING: Validation failed with status %{public}lu, error: %{public}@", validationStatus, validationError.localizedDescription);
            SULog(SULogLevelError, @"Error: Rejecting new connection for agent due to failing validation of XPC connection with status %lu and error: %@", validationStatus, validationError.localizedDescription);

            [newConnection invalidate];
            return NO;
    }
    
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Setting up connection interfaces");

    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SUInstallerAgentInitiationProtocol)];
    newConnection.exportedObject = self;

    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SPUInstallerAgentProtocol)];

    _activeConnection = newConnection;

    __weak __typeof__(self) weakSelf = self;
    newConnection.interruptionHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Agent connection interrupted");
            __typeof__(self) strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf->_activeConnection invalidate];
            }
        });
    };

    newConnection.invalidationHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Agent connection invalidated");
            __typeof__(self) strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf->_delegate agentConnectionDidInvalidate];
            }
        });
    };

    _agent = newConnection.remoteObjectProxy;

    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Resuming agent connection, accepting connection");
    [newConnection resume];

    return YES;
}

- (void)connectionDidInitiateWithReply:(void (^)(void))acknowledgement
{
    os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] ========== CONNECTION DID INITIATE ==========");
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_connected = YES;

        [self->_delegate agentConnectionDidInitiate];
        os_log(OS_LOG_DEFAULT, "[SPARKLE DEBUG AUTOUPDATE] Agent marked as connected, delegate notified");
    });
    
    if (acknowledgement != NULL) {
        acknowledgement();
    }
}

- (void)connectionWillInvalidateWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_invalidationError = error;
    });
}

@end
