//
//  RNAccountKit.m
//

#import "RNAccountKit.h"
#import "RCTBridge.h"
#import "RNAccountKitViewController.h"
#import <AccountKit/AccountKit.h>
#import "RCTRootView.h"
#import "RCTLog.h"

@implementation RNAccountKit
{
    AKFAccountKit *_accountKit;
}

RCT_EXPORT_MODULE();


RCT_EXPORT_METHOD(login:(NSString *)type
                  resolver: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)
{
    @try {
        RNAccountKitViewController* a = [[RNAccountKitViewController alloc] initWithAccountKit: [self getAccountKit]];
        
        if ([type isEqual: @"phone"]) {
            [a loginWithPhone: resolve rejecter: reject];
        } else {
            [a loginWithEmail: resolve rejecter: reject];
        }
    }
    @catch (NSException * e) {
        reject(@"login_failed", @"Could not login", [self errorFromException:e]);
    }
    
}

RCT_EXPORT_METHOD(logout: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)
{
    @try {
        [_accountKit logOut];
    }
    @catch (NSException * e) {
        reject(@"logout_error", @"Could not logout", [self errorFromException:e]);
    }
}


RCT_EXPORT_METHOD(configure:(NSDictionary *)options
                  resolver: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)
{
    self.options = options;
}


RCT_EXPORT_METHOD(getCurrentAccessToken: (RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        id<AKFAccessToken> accessToken = [[self getAccountKit] currentAccessToken];
        
        if (![accessToken accountID]) {
            return resolve(nil);
        }
        
        NSMutableDictionary *accessTokenData =[[NSMutableDictionary alloc] init];
        accessTokenData[@"accountId"] = [accessToken accountID];
        accessTokenData[@"appId"] = [accessToken applicationID];
        accessTokenData[@"token"] = [accessToken tokenString];
        accessTokenData[@"lastRefresh"] = [NSNumber numberWithDouble: ([[accessToken lastRefresh] timeIntervalSince1970] * 1000)];
        accessTokenData[@"refreshIntervalSeconds"] = [NSNumber numberWithDouble: [accessToken tokenRefreshInterval]];
        
        resolve(accessTokenData);
    }
    @catch (NSException * e) {
        reject(@"access_token_error", @"Could not get access token", [self errorFromException:e]);
    }
}

RCT_EXPORT_METHOD(getCurrentAccount: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)
{
    [_accountKit requestAccount:^(id<AKFAccount> account, NSError *error) {
        // account ID
        if (error) {
            reject(@"request_account", @"Could not get account data", error);
        } else {
            resolve([self formatAccountData:account]);
        }
    }];
}

- (AKFAccountKit*) getAccountKit
{
    if (_accountKit == nil) {
        // may also specify AKFResponseTypeAccessToken
        BOOL useAccessToken = [[self.options valueForKey:@"responseType"] isEqualToString:@"token"];
        AKFResponseType responseType = useAccessToken ? AKFResponseTypeAccessToken : AKFResponseTypeAuthorizationCode;
        _accountKit = [[AKFAccountKit alloc] initWithResponseType:responseType];
    }
    
    return _accountKit;
}

- (NSMutableDictionary*) formatAccountData: (id<AKFAccount>) account
{
    NSMutableDictionary *result =[[NSMutableDictionary alloc] init];
    result[@"id"] = account.accountID;
    result[@"email"] = account.emailAddress;
    
    if (account.phoneNumber && account.phoneNumber.phoneNumber) {
        result[@"phoneNumber"] = @{
            @"number": account.phoneNumber.phoneNumber,
            @"countryCode": account.phoneNumber.countryCode
        };
    }
    
    return result;
}

- (NSError *) errorFromException: (NSException *) exception
{
    NSDictionary *exceptionInfo = @{
        @"name": exception.name,
        @"reason": exception.reason,
        @"callStackReturnAddresses": exception.callStackReturnAddresses,
        @"callStackSymbols": exception.callStackSymbols,
        @"userInfo": exception.userInfo
    };
    
    return [[NSError alloc] initWithDomain: @"RNAccountKit"
                                      code: 0
                                  userInfo: exceptionInfo];
}

@end