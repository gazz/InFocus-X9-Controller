//
//  ProjectorProtocol.h
//  SerialPortTest
//
//  Created by Janis Dancis on 10/7/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AMSerialPortAdditions.h"

#define REQUEST_PASSED @"[PAS]"
#define REQUEST_FAILED @"[FAL]"
#define REQUEST_NA @"[NA]"

@interface ProjectorProtocol : NSObject {
	NSString *devPath;
	NSString *response;
	NSLock *lock;
	AMSerialPort *port;
	BOOL responseReceived;
	NSMutableArray *responseMessages;
}

@property (nonatomic,retain) NSString *response;
@property (nonatomic,retain) NSMutableArray *responseMessages;
@property (nonatomic,retain) NSString *devPath;
@property (nonatomic,retain) AMSerialPort *port;

+(id) protocolWithDevPath:(NSString*)path;
-(id) initWithDevPath:(NSString*)path;

-(void)performSend:(NSString*)data;
-(NSMutableArray*)sendRequest:(NSString*)data;

-(BOOL)isOpen;

-(BOOL)isProjectorConnected;
-(BOOL)isProjectorOn;
-(BOOL)isSourceLocked;

-(BOOL) powerOn;
-(BOOL) powerOff;

-(BOOL) lockSource;
-(BOOL) unlockSource;
-(BOOL) showMenu;
-(BOOL) setSource:(UInt32)source;
-(UInt32) source;



@end
