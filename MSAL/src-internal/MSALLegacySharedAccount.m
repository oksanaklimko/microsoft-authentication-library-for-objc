// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSALLegacySharedAccount.h"
#import "MSIDJsonObject.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSALAccountEnumerationParameters.h"
#import <MSAL/MSAL.h>

@interface MSALLegacySharedAccount()

@property (nonatomic, readwrite) NSDictionary *jsonDictionary;

@end

static NSDateFormatter *s_updateDateFormatter = nil;

@implementation MSALLegacySharedAccount

#pragma mark - Init

- (instancetype)initWithJSONDictionary:(NSDictionary *)jsonDictionary error:(NSError **)error
{
    self = [super init];
    
    if (self)
    {
        _jsonDictionary = jsonDictionary;
        _accountType = [jsonDictionary msidStringObjectForKey:@"type"];
        _accountIdentifier = [jsonDictionary msidStringObjectForKey:@"id"];
        
        if ([NSString msidIsStringNilOrBlank:_accountType]
            || [NSString msidIsStringNilOrBlank:_accountIdentifier])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Missing account type or identifier (account type = %@, account identifier = %@)", _accountType, _accountIdentifier);
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected shared account found without type or identifier", nil, nil, nil, nil, nil);
            }
            
            return nil;
        }
        
        _signinStatusDictionary = [jsonDictionary msidObjectForKey:@"signInStatus" ofClass:[NSDictionary class]];
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Created sign in status dictionary %@", MSID_PII_LOG_MASKABLE(_signinStatusDictionary));
    }
    
    return self;
}

- (instancetype)initWithMSALAccount:(id<MSALAccount>)account
                      accountClaims:(NSDictionary *)claims
                    applicationName:(NSString *)appName
                     accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                              error:(NSError **)error
{
    if (accountVersion == MSALLegacySharedAccountVersionV1)
    {
        return nil;
    }
    
    NSString *appBundleId = [[NSBundle mainBundle] bundleIdentifier];
    
    NSMutableDictionary *jsonDictionary = [NSMutableDictionary new];
    jsonDictionary[@"id"] = [[NSUUID UUID] UUIDString];
    jsonDictionary[@"environment"] = @"PROD";
    
    if (accountVersion == MSALLegacySharedAccountVersionV3)
    {
        jsonDictionary[@"originAppId"] = appBundleId;
    }
    
    jsonDictionary[@"signInStatus"] = @{appBundleId : @"SignedIn"};
    jsonDictionary[@"username"] = account.username;
    jsonDictionary[@"additionalProperties"] = @{@"createdBy": appName};
    [jsonDictionary addEntriesFromDictionary:[self claimsFromMSALAccount:account claims:claims]];
    return [self initWithJSONDictionary:jsonDictionary error:error];
}

#pragma mark - Match

- (BOOL)matchesParameters:(MSALAccountEnumerationParameters *)parameters
{
    if (parameters.needsAssociatedRefreshToken)
    {
        NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSString *signinStatus = _signinStatusDictionary[appIdentifier];
        
        if (![signinStatus isEqualToString:@"SignedIn"])
        {
            return NO;
        }
        
        return YES;
    }
    
    return YES;
}

#pragma mark - Update

- (BOOL)updateAccountWithMSALAccount:(id<MSALAccount>)account
                     applicationName:(NSString *)appName
                           operation:(MSALLegacySharedAccountWriteOperation)operation
                      accountVersion:(MSALLegacySharedAccountVersion)accountVersion
                               error:(NSError **)error
{
    if (accountVersion == MSALLegacySharedAccountVersionV1)
    {
        return YES;
    }
    
    NSMutableDictionary *oldDictionary = [self.jsonDictionary mutableCopy];
    NSString *appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    if (appIdentifier)
    {
        NSMutableDictionary *signinDictionary = [NSMutableDictionary new];
        [signinDictionary addEntriesFromDictionary:_signinStatusDictionary];
        
        NSString *signinState = nil;
        
        switch (operation) {
            case MSALLegacySharedAccountRemoveOperation:
                signinState = @"SignedOut";
                break;
            case MSALLegacySharedAccountUpdateOperation:
                signinState = @"SignedIn";
                break;
                
            default:
                return NO;
        }
        
        signinDictionary[appIdentifier] = signinState;
        oldDictionary[@"signInStatus"] = signinDictionary;
    }
    
    NSDictionary *additionalAccountInfo = [self.jsonDictionary msidObjectForKey:@"additionalProperties" ofClass:[NSDictionary class]];
    NSMutableDictionary *mutableAdditionalInfo = [additionalAccountInfo mutableCopy];
    
    mutableAdditionalInfo[@"updatedBy"] = appName;
    mutableAdditionalInfo[@"updatedAt"] = [[[self class] dateFormatter] stringFromDate:[NSDate date]];
    
    oldDictionary[@"additionalProperties"] = additionalAccountInfo;
    
    if (account)
    {
        [oldDictionary addEntriesFromDictionary:[self updatedFieldsWithAccount:account]];
    }
    
    _jsonDictionary = oldDictionary;
    return YES;
}

- (NSDictionary *)updatedFieldsWithAccount:(id<MSALAccount>)account
{
    NSAssert(NO, @"Abstract method, implement me in the subclass");
    return nil;
}

- (NSDictionary *)claimsFromMSALAccount:(id<MSALAccount>)account claims:(NSDictionary *)claims
{
    NSAssert(NO, @"Abstract method, implement me in the subclass");
    return nil;
}

#pragma mark - Helpers

+ (NSDateFormatter *)dateFormatter
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_updateDateFormatter = [NSDateFormatter new];
        [s_updateDateFormatter setDateFormat:@"%Y-%m-%dT%H:%M:%S.Z"];
    });
    
    return s_updateDateFormatter;
}

@end
