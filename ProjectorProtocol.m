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
#ifdef AMSerialDebug
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
#ifdef AMSerialDebug
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
#ifdef AMSerialDebug
//		NSLog(@"Received data: %@, Response: '%@' [%d]", text, response, response.length);
#endif
		
		// search for one of the 
		if ([self extractMessages:response]) {
#ifdef AMSerialDebug
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


#pragma mark -
#pragma mark X9 Projector interface

-(BOOL)isProjectorConnected {
	NSArray *messages = [self sendRequest:@"[00PWR?]"];
	if ([[messages lastObject] isEqualToString:REQUEST_FAILED])
		return YES;
	return NO;
}

-(BOOL)isProjectorOn {
	NSArray *messages = [self sendRequest:@"[00SRC?]"];
	if ([[messages lastObject] isEqualToString:REQUEST_PASSED])
		return YES;
	if ([self isSourceLocked])
		return YES;
	return NO;
}

-(UInt32) parseIntResponse:(NSString*)message {
	// remove square brackets
	NSString *str = [message stringByReplacingOccurrencesOfString:@"[" withString:@""];
	str = [str stringByReplacingOccurrencesOfString:@"]" withString:@""];
	str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
	return [str intValue];
}

-(BOOL)isSourceLocked {
	NSArray *messages = [self sendRequest:@"[00SRL?]"];
	if ([[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		UInt32 result = [self parseIntResponse:[messages objectAtIndex:0]];
		return result == 1;
	}
	return NO;
}

-(BOOL) powerOn {
	NSArray *messages = [self sendRequest:@"[00PWR1]"];
	if (![[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		NSLog(@"Cannot power on projector");
		return NO;
	}
	return YES;
}

-(BOOL) powerOff {
	NSArray *messages = [self sendRequest:@"[00PWR0]"];
	if (![[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		NSLog(@"Cannot power off projector");
		return NO;
	}
	return YES;
}

-(BOOL) lockSource {
	NSArray *messages = [self sendRequest:@"[00SRL1]"];
	if (![[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		NSLog(@"Cannot lock source");
		return NO;
	}
	return YES;
}

-(BOOL) unlockSource {
	NSArray *messages = [self sendRequest:@"[00SRL0]"];
	if (![[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		NSLog(@"Cannot unlock source");
		return NO;
	}
	return YES;
}

-(BOOL) showMenu {
	NSArray *messages = [self sendRequest:@"[00KEY1]"];
	if (![[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		NSLog(@"Cannot power off projector");
		return NO;
	}
	return YES;
}

-(BOOL) setSource:(UInt32)source {
	NSArray *messages = [self sendRequest:[NSString stringWithFormat:@"[00SRC%d]", source]];
	if (![[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		NSLog(@"Cannot set source: %d", source);
		return NO;
	}
	return YES;
}

-(UInt32) source {
	NSArray *messages = [self sendRequest:@"[00SRC?]"];
	if ([[messages lastObject] isEqualToString:REQUEST_PASSED]) {
		UInt32 result = [self parseIntResponse:[messages objectAtIndex:0]];
		return result;
	}
	return -1;
}


@end
