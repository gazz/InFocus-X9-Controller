//
//  GazzJSONServer.m
//  CocoaHTTPServer
//
//  Created by Janis Dancis on 10/15/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import "SimpleHTTPServer.h"
#import "NSStringExtensions.h"


@implementation SimpleHTTPServer

@synthesize server, name, delegate;

+(id) serverWithPort:(UInt32)port andServiceName:(NSString*)name {
	return [[[SimpleHTTPServer alloc] initWithPort:port andServiceName:name] autorelease];
}

-(id) initWithPort:(UInt32)_port andServiceName:(NSString*)_name {
	if ([super init]) {
		port = _port;
		self.name = _name;
		self.server = [[HTTPServer alloc] init];
		[server setPort:port];
		[server setType:@"_http._tcp."];
		[server setName:name];
		[server setDelegate:self];
	}
	return self;
}

-(void) start {
	NSError *startError = nil;
	if (![server start:&startError] ) {
		NSLog(@"Error starting server: %@", startError);
	} else {
		NSLog(@"Starting server on port %d", [server port]);
	}
}

-(void) dealloc {
	[name release];
	[server release];
	[super dealloc];
}


#pragma mark -
#pragma mark Request handler

- (void)HTTPConnection:(HTTPConnection *)conn didReceiveRequest:(HTTPServerRequest *)mess {
	NSLog(@"Handling request");
	CFHTTPMessageRef request = [mess request];

	NSDictionary *headers = [(id)CFHTTPMessageCopyAllHeaderFields(request) autorelease];
	NSLog(@"headers: %@", headers);
	
    NSString *vers = [(id)CFHTTPMessageCopyVersion(request) autorelease];
    if (!vers || ![vers isEqual:(id)kCFHTTPVersion1_1]) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 505, NULL, (CFStringRef)vers); // Version Not Supported
        [mess setResponse:response];
        CFRelease(response);
        return;
    }
	
    NSString *method = [(id)CFHTTPMessageCopyRequestMethod(request) autorelease];
    if (!method) {
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, kCFHTTPVersion1_1); // Bad Request
        [mess setResponse:response];
        CFRelease(response);
        return;
    }
	
	if ([method isEqual:@"GET"] || [method isEqual:@"HEAD"]) {
		NSURL *uri = [(NSURL *)CFHTTPMessageCopyRequestURL(request) autorelease];
		NSString *path= [uri path];
		NSString *type = @"HTML";
		if ([path endsWith:@".JSON"]) {
			path = [path substringToIndex:(path.length-5)];
			type = @"JSON";
		}
		NSData *data = [[self respondToURI:path ofType:type] dataUsingEncoding:NSUTF8StringEncoding];
		
        if (!data) {
            CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 404, NULL, kCFHTTPVersion1_1); // Not Found
			CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)[NSString stringWithFormat:@"%d", 0]);
            [mess setResponse:response];
            CFRelease(response);
            return;
        }
		
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1); // OK
        CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)[NSString stringWithFormat:@"%d", [data length]]);
        if ([method isEqual:@"GET"]) {
            CFHTTPMessageSetBody(response, (CFDataRef)data);
        }
        [mess setResponse:response];
        CFRelease(response);
        return;
    }
	
}

-(NSString*) respondToURI:(NSString*)uri ofType:(NSString*)type {
	if (delegate) {
		return [delegate respondToURI:uri ofType:(NSString*)type];
	}
	return @"džēāh";
}



@end
