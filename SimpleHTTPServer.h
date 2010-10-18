//
//  GazzJSONServer.h
//  CocoaHTTPServer
//
//  Created by Janis Dancis on 10/15/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "HTTPServer.h"

@protocol RequestHandler
-(NSString*) respondToURI:(NSString*)uri ofType:(NSString*)type;
@end

@interface SimpleHTTPServer : NSObject {
	UInt32 port;
	NSString *name;
	HTTPServer *server;
	
	id<RequestHandler> delegate;
}

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) HTTPServer *server;
@property (assign) id<RequestHandler> delegate;

+(id) serverWithPort:(UInt32)port andServiceName:(NSString*)name;
-(id) initWithPort:(UInt32)port andServiceName:(NSString*)name;

-(void) start;

- (void)HTTPConnection:(HTTPConnection *)conn didReceiveRequest:(HTTPServerRequest *)mess;

-(NSString*) respondToURI:(NSString*)uri ofType:(NSString*)type;

@end
