//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSALTestCase.h"
#import "MSALBaseRequest+TestExtensions.h"
#import "MSALTestSwizzle.h"
#import "MSALTestBundle.h"

@interface MSALFakeInteractiveRequest : NSObject

@property NSString *state;
@property MSALRequestParameters *parameters;

@end

@implementation MSALFakeInteractiveRequest

@end

@interface MSALPublicClientApplicationTests : MSALTestCase

@end

@implementation MSALPublicClientApplicationTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNilClientId
{
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:nil
                                                    error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorInvalidParameter);
    XCTAssertNotNil(error.userInfo);
    XCTAssertNotNil(error.userInfo[MSALErrorDescriptionKey]);
    XCTAssertTrue([error.userInfo[MSALErrorDescriptionKey] containsString:@"clientId"]);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testRedirectUriError
{
    // By default the initializer for MSALPublicClientApplication should fail due to the redirect URI
    // not being listed in the info plist
    
    NSError *error = nil;
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"b92e0ba5-f86e-4411-8e18-6b5f928d968a"
                                                    error:&error];
    
    XCTAssertNil(application);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSALErrorRedirectSchemeNotRegistered);
    XCTAssertEqualObjects(error.domain, MSALErrorDomain);
}

- (void)testInit
{
    NSError *error = nil;
    
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[@"x-msauth-com-microsoft-unittests"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"b92e0ba5-f86e-4411-8e18-6b5f928d968a"
                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    XCTAssertEqualObjects(application.clientId, @"b92e0ba5-f86e-4411-8e18-6b5f928d968a");
    XCTAssertEqualObjects(application.redirectUri.absoluteString, @"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal");
}

- (void)testIsMSALResponse
{
    __block MSALFakeInteractiveRequest *request = nil;
    [MSALTestSwizzle classMethod:@selector(currentActiveRequest)
                           class:[MSALInteractiveRequest class]
                           block:(id)^id(id obj)
     {
         (void)obj;
         return request;
     }];
    
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:nil]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host"]]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/resp"]]);
    
    request = [MSALFakeInteractiveRequest new];
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/msal"]]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/msal?"]]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/?code=iamacode"]]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/msal?error=iamaerror&error_description=evenmoreinfo"]]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/?code=iamacode&state=fake_state"]]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/msal?error=iamaerror&error_description=evenmoreinfo&state=fake_state"]]);
    
    request.state = @"some_other_state";
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/?code=iamacode&state=fake_state"]]);
    XCTAssertFalse([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/msal?error=iamaerror&error_description=evenmoreinfo&state=fake_state"]]);
    
    request.state = @"fake_state";
    XCTAssertTrue([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/?code=iamacode&state=fake_state"]]);
    XCTAssertTrue([MSALPublicClientApplication isMSALResponse:[NSURL URLWithString:@"https://host/msal?error=iamaerror&error_description=evenmoreinfo&state=fake_state"]]);
}

- (void)testAcquireTokenScopes
{
    NSError *error = nil;
    
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[@"x-msauth-com-microsoft-unittests"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"b92e0ba5-f86e-4411-8e18-6b5f928d968a"
                                                authority:@"https://login.microsoftonline.com/common"
                                                    error:&error];
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqualObjects(params.unvalidatedAuthority, [NSURL URLWithString:@"https://login.microsoftonline.com/common"]);
         XCTAssertEqualObjects(params.scopes, [NSOrderedSet orderedSetWithObject:@"fakescope"]);
         XCTAssertEqualObjects(params.clientId, @"b92e0ba5-f86e-4411-8e18-6b5f928d968a");
         XCTAssertEqualObjects(params.redirectUri, [NSURL URLWithString:@"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal"]);
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertNil(params.loginHint);
         XCTAssertNil(params.component);
         XCTAssertNotNil(params.correlationId);
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope"]
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}

- (void)testAcquireScopesLoginHint
{
    NSError *error = nil;
    
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[@"x-msauth-com-microsoft-unittests"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"b92e0ba5-f86e-4411-8e18-6b5f928d968a"
                                                authority:@"https://login.microsoftonline.com/common"
                                                    error:&error];
    application.component = @"unittests";
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         
         XCTAssertNil(obj.additionalScopes);
         XCTAssertEqual(obj.uiBehavior, MSALUIBehaviorDefault);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqualObjects(params.unvalidatedAuthority.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, @"b92e0ba5-f86e-4411-8e18-6b5f928d968a");
         XCTAssertEqualObjects(params.redirectUri.absoluteString, @"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal");
         XCTAssertNotNil(params.correlationId);
         XCTAssertNil(params.extraQueryParameters);
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}

- (void)testAcquireScopesLoginHintBehaviorEQPs
{
    NSError *error = nil;
    
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[@"x-msauth-com-microsoft-unittests"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"b92e0ba5-f86e-4411-8e18-6b5f928d968a"
                                                authority:@"https://login.microsoftonline.com/common"
                                                    error:&error];
    application.component = @"unittests";
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         
         XCTAssertNil(obj.additionalScopes);
         XCTAssertEqual(obj.uiBehavior, MSALForceLogin);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqualObjects(params.unvalidatedAuthority.absoluteString, @"https://login.microsoftonline.com/common");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, @"b92e0ba5-f86e-4411-8e18-6b5f928d968a");
         XCTAssertEqualObjects(params.redirectUri.absoluteString, @"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal");
         XCTAssertNotNil(params.correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                             loginHint:@"fakeuser@contoso.com"
                            uiBehavior:MSALForceLogin
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}

- (void)testAcquireScopesAddlScopesLoginHintuiBehaviorEQPAuthorityCorrelationId
{
    NSError *error = nil;
    
    [MSALTestBundle overrideBundleId:@"com.microsoft.unittests"];
    
    NSArray* override = @[ @{ @"CFBundleURLSchemes" : @[@"x-msauth-com-microsoft-unittests"] } ];
    [MSALTestBundle overrideObject:override forKey:@"CFBundleURLTypes"];
    
    MSALPublicClientApplication *application =
    [[MSALPublicClientApplication alloc] initWithClientId:@"b92e0ba5-f86e-4411-8e18-6b5f928d968a"
                                                authority:@"https://login.microsoftonline.com/common"
                                                    error:&error];
    application.component = @"unittests";
    
    XCTAssertNotNil(application);
    XCTAssertNil(error);
    
    __block NSUUID *correlationId = [NSUUID new];
    
    [MSALTestSwizzle instanceMethod:@selector(run:)
                              class:[MSALBaseRequest class]
                              block:(id)^(MSALInteractiveRequest *obj, MSALCompletionBlock completionBlock)
     {
         XCTAssertTrue([obj isKindOfClass:[MSALInteractiveRequest class]]);
         
         XCTAssertEqualObjects(obj.additionalScopes, [NSOrderedSet orderedSetWithArray:@[@"fakescope3"]]);
         XCTAssertEqual(obj.uiBehavior, MSALForceConsent);
         
         MSALRequestParameters *params = [obj parameters];
         XCTAssertNotNil(params);
         
         XCTAssertEqualObjects(params.unvalidatedAuthority.absoluteString, @"https://login.microsoftonline.com/contoso.com");
         XCTAssertEqualObjects(params.scopes, ([NSOrderedSet orderedSetWithObjects:@"fakescope1", @"fakescope2", nil]));
         XCTAssertEqualObjects(params.clientId, @"b92e0ba5-f86e-4411-8e18-6b5f928d968a");
         XCTAssertEqualObjects(params.redirectUri.absoluteString, @"x-msauth-com-microsoft-unittests://com.microsoft.unittests/msal");
         XCTAssertEqualObjects(params.correlationId, correlationId);
         XCTAssertEqualObjects(params.extraQueryParameters, (@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }));
         XCTAssertEqualObjects(params.loginHint, @"fakeuser@contoso.com");
         
         completionBlock(nil, nil);
     }];
    
    [application acquireTokenForScopes:@[@"fakescope1", @"fakescope2"]
                      additionalScopes:@[@"fakescope3"]
                             loginHint:@"fakeuser@contoso.com"
                            uiBehavior:MSALForceConsent
                  extraQueryParameters:@{ @"eqp1" : @"val1", @"eqp2" : @"val2" }
                             authority:@"https://login.microsoftonline.com/contoso.com"
                         correlationId:correlationId
                       completionBlock:^(MSALResult *result, NSError *error)
     {
         XCTAssertNil(result);
         XCTAssertNil(error);
     }];
}

@end