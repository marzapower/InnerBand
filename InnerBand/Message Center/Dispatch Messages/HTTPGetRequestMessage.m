//
//  HTTPGetRequestMessage.m
//  InnerBand
//
//  InnerBand - The iOS Booster!
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "HTTPGetRequestMessage.h"
#import <UIKit/UIKit.h>
#import "Macros.h"
#import "MessageCenter.h"
#import "Functions.h"
#import "ARCMacros.h"

@implementation HTTPGetRequestMessage

+ (id)messageWithName:(NSString *)name userInfo:(NSDictionary *)userInfo url:(NSString *)url {
	HTTPGetRequestMessage *message = [[HTTPGetRequestMessage alloc] initWithName:name userInfo:userInfo];
	
	// must be async
	message.asynchronous = YES;
	
    message->_url = [url copy];
	message->_headersDict = [[NSMutableDictionary alloc] init];
	
	// autorelease
    return SAFE_ARC_AUTORELEASE(message);
}

+ (id)messageWithName:(NSString *)name userInfo:(NSDictionary *)userInfo url:(NSString *)url processBlock:(ib_http_proc_t)processBlock {
	HTTPGetRequestMessage *message = [[HTTPGetRequestMessage alloc] initWithName:name userInfo:userInfo];
	
	// must be async
	message.asynchronous = YES;
	
    message->_url = [url copy];
	message->_headersDict = [[NSMutableDictionary alloc] init];
    message->_processBlock = SAFE_ARC_BLOCK_COPY(processBlock);
    
	// autorelease
    return SAFE_ARC_AUTORELEASE(message);    
}

- (void)dealloc {
    SAFE_ARC_RELEASE(_url);
    SAFE_ARC_RELEASE(_responseData);
    SAFE_ARC_RELEASE(_headersDict);
    SAFE_ARC_BLOCK_RELEASE(_processBlock);
    SAFE_ARC_SUPER_DEALLOC();
}

#pragma mark -

- (void)addHeaderValue:(NSString *)value forKey:(NSString *)key {
    [_headersDict setValue:value forKey:key];
}

- (void)inputData:(NSData *)input {
	NSString *subbedURL = _url;
	NSError *error = nil;
	NSHTTPURLResponse *response = nil;
	
	// perform substitutions on URL
	for (NSString *key in self.userInfo) {
		NSString *subToken = [NSString stringWithFormat:@"[%@]", key];
        
		if ([[self.userInfo objectForKey:key] isKindOfClass:NSString.class]) {
            subbedURL = [subbedURL stringByReplacingOccurrencesOfString:subToken withString:[(NSString *)[self.userInfo objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        }
	}
    
	// debug
    if ([MessageCenter isDebuggingEnabled]) {
        NSLog(@"OPEN URL: %@", subbedURL);
    }
	
	// generate request
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:subbedURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    [request setAllHTTPHeaderFields:_headersDict];
    
	NSData *content = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
	if (!error) {
		_responseData = [content mutableCopy];
        
		if (response) {
            NSMutableDictionary *updatedUserInfo = [self.userInfo mutableCopy];
            [self setUserInfoValue:BOX_INT(response.statusCode) forKey:HTTP_STATUS_CODE];
            
            if (_processBlock) {
                _processBlock(_responseData, response.statusCode);
            }
            
            SAFE_ARC_RELEASE(updatedUserInfo);
		} else if (_processBlock) {
            _processBlock(_responseData, 0);
        }
	} else {
		_responseData = nil;
        
        if (_processBlock) {
            _processBlock(_responseData, response ? response.statusCode : 0);
        }
    }
}

- (NSData *)outputData {
	return _responseData;
}

@end
