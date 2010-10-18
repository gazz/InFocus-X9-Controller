//
//  ProjectorProtocol.m
//  SerialPortTest
//
//  Created by Janis Dancis on 10/7/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import <IOKit/serial/IOSerialKeys.h>

#import "ProjectorProtocol.h"
#import "NSStringExtensions.h"

@interface ProjectorProtocol (PrivateMethods)
-(void) serialPortReadData:(NSDictionary *)dataDictionary;
-(UInt32) parseIntResponse:(NSString*)message;
@end

@implementation ProjectorProtocol

@synthesize devPath, port, response, responseMessages;

+(id) protocolWithDevPath:(NSString*)path {
	return [[[ProjectorProtocol alloc] initWithDevPath:path] autorelease];
}

-(id) initWithDevPath:(NSString*)path {
	if ([super init]) {
		self.responseMessages = [NSMutableArray array];
		self.devPath = path;
		self.port = [[AMSerialPort alloc] init:path 
								 withName:path 
									 type:(NSString*)CFSTR(kIOSerialBSDModemType)];
		[port setDelegate:self];
		if ([port open]) {
#ifdef X9_PROTOCOL_DEBUG
			NSLog(@"Port open");
#endif
			[port readDataInBackground];
		} else {
			NSLog(@"Cannot open port: %@", path);
		}
	}
	return self;
}

-(void) dealloc {
	if ([port isOpen]) {
		[port close];
	}
	[devPath release];
	[port release];
	[lock release];
	[response release];
	[super dealloc];
}

#pragma mark -
#pragma mark Serial port IO

-(void)performSend:(NSString*)data {
	if([port isOpen]) { // in case an error occured while opening the port
		[port writeString:data usingEncoding:NSUTF8StringEncoding error:NULL];
	}
}

-(NSMutableArray*)sendRequest:(NSString*)data {
	self.response = nil;
	[lock lock];
	responseReceived = NO;
	[lock unlock];
	
	NSString *sendString = [data stringByAppendingString:@"\r"];
#ifdef X9_PROTOCOL_DEBUG
	NSLog(@"Request: %@", sendString);
#endif
	[self performSelector:@selector(performSend:) withObject:sendString];
	
	SInt64 timeout = 10000000;
	SInt64 step = 100000;
	[lock lock];
	while (!responseReceived && timeout>0) {
		[lock unlock];
		usleep(step);
		[lock lock];
		timeout -= step;
	}
	[lock unlock];
	return responseMessages;
}

-(BOOL) extractMessages:(NSString*)input {
	// parse response
	[responseMessages removeAllObjects];
	
	BOOL doneProcessing = NO;
	UInt32 currentOffset = 0;
	while(!doneProcessing) {
		// parse response
		UInt32 msgStart = -1, msgEnd = -1;
		NSRange rng = NSMakeRange(currentOffset, input.length - currentOffset);
		rng = [input rangeOfString:@"[" options:NSCaseInsensitiveSearch range:rng];
		msgStart = rng.location;
		if (rng.location!=NSNotFound) {
			rng = [input rangeOfString:@"]" options:NSCaseInsensitiveSearch range:NSMakeRange(rng.location, input.length-rng.location)];
			msgEnd = rng.location;
			if (rng.location!=NSNotFound) {
				[responseMessages addObject:[input substringWithRange:NSMakeRange(msgStart, msgEnd - msgStart+1)]];
				currentOffset = msgEnd;
			} else {
				doneProcessing = YES;
			}
		} else {
			doneProcessing = YES;
		}
	}
	
	NSString *lastMessage = [responseMessages lastObject];
	if ([lastMessage isEqualToString:REQUEST_PASSED] ||
		[lastMessage isEqualToString:REQUEST_FAILED] ||
		[lastMessage isEqualToString:REQUEST_NA]) {
		return YES;
	}
	
	return NO;
}

-(void) serialPortReadData:(NSDictionary *)dataDictionary {
	// this method is called if data arrives 
	// @"data" is the actual data, @"serialPort" is the sending port
	AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
	NSData *data = [dataDictionary objectForKey:@"data"];
	if ([data length] > 0) {
		NSString *text = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];;
		if ([text endsWith:@"\n\r"]) {
			text = [text substringToIndex:(text.length-1)];
		}
		
		if (response==nil)
			self.response = [NSString stringWithString:text];
		else {
			self.response = [response stringByAppendingString:text];
		}
#ifdef X9_PROTOCOL_DEBUG
//		NSLog(@"Received data: %@, Response: '%@' [%d]", text, response, response.length);
#endif
		
		// search for one of the 
		if ([self extractMessages:response]) {
#ifdef X9_PROTOCOL_DEBUG
			NSLog(@"Response: %@", response);
#endif
			[lock lock];
			responseReceived = YES;
			[lock unlock];
		}
		
		// continue listening
		[sendPort readDataInBackground];
	} else { // port closed
		NSLog(@"port closed\r");
	}
}

-(BOOL)isOpen {
	return [port isOpen];
}

-(UInt32) parseIntResponse:(NSString*)message {
	// remove square brackets
	NSString *str = [message stringByReplacingOccurrencesOfString:@"[" withString:@""];
	str = [str stringByReplacingOccurrencesOfString:@"]" withString:@""];
	str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
	return [str intValue];
}

-(UInt32) sendReadValueMessage:(NSString*)message {
	NSString *encodedMessage = [NSString stringWithFormat:@"[00%@]", message];
	NSArray *messages = [self sendRequest:encodedMessage];
	if ([[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		UInt32 result = [self parseIntResponse:[messages objectAtIndex:0]];
		return result;
	} else {
#ifdef X9_PROTOCOL_DEBUG
		NSLog(@"Read value message %@ failed", encodedMessage);
#endif
	}
	return -1;
}

-(BOOL) sendInputMessage:(NSString*)message withValue:(UInt32)value {
	NSString *encodedMessage = [NSString stringWithFormat:@"[00%@%d]", message, value];
	NSArray *messages = [self sendRequest:encodedMessage];
	if (![[messages lastObject] isEqualToString:REQUEST_PASSED]) {
#ifdef X9_PROTOCOL_DEBUG
		NSLog(@"Send input message %@ failed", encodedMessage);
#endif
		return NO;
	}
	return YES;
}

#pragma mark -
#pragma mark X9 Projector interface

-(BOOL)isProjectorConnected {
	NSArray *messages = [self sendRequest:@"PWR?"];
	NSString *msg = [messages lastObject];
	if ([msg isEqualToString:REQUEST_PASSED] || [msg isEqualToString:REQUEST_FAILED])
		return YES;
	return NO;
}

-(BOOL)isProjectorOn {
	if ([self sendReadValueMessage:@"SRC?"]!=-1)
		return YES;
	if ([self isSourceLocked])
		return YES;
	return NO;
}


-(BOOL)isSourceLocked {
	return (1==[self sendReadValueMessage:@"SRL?"]);
}

-(BOOL) powerOn {
	return [self sendInputMessage:@"PWR" withValue:1];
}

-(BOOL) powerOff {
	return [self sendInputMessage:@"PWR" withValue:0];
}

-(BOOL) lockSource {
	return [self sendInputMessage:@"SRL" withValue:1];
}

-(BOOL) unlockSource {
	return [self sendInputMessage:@"SRL" withValue:0];
}

-(BOOL) showMenu {
	return [self sendInputMessage:@"KEY" withValue:1];
}

-(BOOL) setSource:(UInt32)source {
	return [self sendInputMessage:@"SRC" withValue:source];
}

-(UInt32) source {
	return [self sendReadValueMessage:@"SRC?"];
}

-(DisplayMode) displayMode {
	return [self sendReadValueMessage:@"DSP?"];
}

-(BOOL) setDisplayMode:(DisplayMode)value {
	return [self sendInputMessage:@"DSP" withValue:value];
}

-(BOOL) setBrightness:(UInt32)value {
	return [self sendInputMessage:@"BRI" withValue:value];
}

-(BOOL) setContrast:(UInt32)value {
	return [self sendInputMessage:@"CON" withValue:value];
}



@end
