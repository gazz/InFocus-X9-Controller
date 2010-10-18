//
//  InFocusControllerAppDelegate.m
//  InFocusController
//
//  Created by Janis Dancis on 10/6/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import "InFocusControllerAppDelegate.h"
#import "AMSerialPortList.h"
#import "SimpleHTTPServer.h"

#import "CJSONSerializer.h"
#import "NSStringExtensions.h"


@interface InFocusControllerAppDelegate (PrivateMethods)
-(NSString*) buildHTMLResponse;
@end



@implementation InFocusControllerAppDelegate

@synthesize window, protocol, connectLock, powerItem, quitItem, timer, sourceLock, sources, displayModes, httpServer;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.connectLock = [[NSLock alloc] init];
	[self updateStatus];
	powerItem.title = @"Connecting...";
	// open connection in background thread 
	[self performSelectorInBackground:@selector(connectToProjector) withObject:nil];
	
	self.timer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(updateStatus) userInfo:nil repeats:YES];
	
	// start up webserver
	self.httpServer = [SimpleHTTPServer serverWithPort:64299 andServiceName:@"InFocusX9 Projector remote"];
	[httpServer setDelegate:self];
	[httpServer start];
}

-(void) awakeFromNib {
	statusItem = [[[NSStatusBar systemStatusBar] 
					statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	[statusItem setHighlightMode:YES];
	[statusMenu setAutoenablesItems:NO];
	
//	NSImage *img = [NSImage imageNamed:@"projektors.icns"];
	NSImage *img = [NSImage imageNamed:@"32_proj_gray.png"];
	[img setSize:NSMakeSize(18, 18)];
	
	[statusItem setImage:img];
}

-(void) dealloc {
	[httpServer release];
	[timer release];
	[powerItem release];
	[quitItem release];
	[sourceLock release];
	[sources release];
	[displayModes release];
	[protocol release];
	[connectLock release];
	[super dealloc];
}

-(void) connectToProjector {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	[connectLock lock];
	NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
	AMSerialPort *aPort;
	while (aPort = [enumerator nextObject]) {
		NSLog(@"Trying device: %@", [aPort bsdPath]);
		self.protocol = [ProjectorProtocol protocolWithDevPath:[aPort bsdPath]];
		if ([protocol isOpen] && [protocol isProjectorConnected]) {
			NSLog(@"Successfully connected to projector: %@", [aPort bsdPath]);
			[self performSelectorOnMainThread:@selector(updateStatus) withObject:nil waitUntilDone:NO];
			break;
		} else {
			self.protocol = nil;
		}
	}
	if (protocol==nil) {
		NSLog(@"Cannot find projector");
	}
	[connectLock unlock];
	[pool release];
}


-(void) updateStatus {
	if (![connectLock tryLock]) {
		return;
	}
	BOOL enabled = NO, poweredOn = [protocol isProjectorOn];
	if (protocol==nil ) {
		// disable menus & show connecting icon
		enabled = NO;
		poweredOn = NO;
		NSImage *img = [NSImage imageNamed:@"32_proj_gray.png"];
		[img setSize:NSMakeSize(18, 18)];
		[statusItem setImage:img];
	} else {
		if ([protocol isSourceLocked]) {
			[sourceLock setState:NSOnState];
		} else {
			[sourceLock setState:NSOffState];
		}

		// enable menus & show connected icon
		enabled = YES;
		NSImage *img = [NSImage imageNamed:@"32_proj.png"];
		[img setSize:NSMakeSize(18, 18)];
		[statusItem setImage:img];
		poweredOn = [protocol isProjectorOn];
		
	}
	for (int i=0; i< [statusMenu numberOfItems]; ++i) {
		NSMenuItem *item = [statusMenu itemAtIndex:i];
		if (item==quitItem || [[item title] isEqualToString:@"Preferences..."])
			continue;
		if (item==powerItem) {
			if (poweredOn) {
				[item setTitle:@"Power Off"];
			} else {
				[item setTitle:@"Power On"];
			}
			[item setEnabled:enabled];
			continue;
		}
		[item setEnabled:(enabled&&poweredOn)];
	}

	UInt32 activeSource = [protocol source];
	for (int i=0; i< [sources numberOfItems]; ++i) {
		NSMenuItem *item = [sources itemAtIndex:i];
		if ([item isEqualTo:sourceLock])
			continue;
		if ([item tag]==activeSource)
			[item setState:NSOnState];
		else
			[item setState:NSOffState];
	}	
	
	// current display mode
	UInt32 activeDisplayMode = [protocol displayMode];
	for (int i=0; i< [displayModes numberOfItems]; ++i) {
		NSMenuItem *item = [displayModes itemAtIndex:i];
		if ([item tag]==activeDisplayMode)
			[item setState:NSOnState];
		else
			[item setState:NSOffState];
	}	
	
	
	[connectLock unlock];
}


-(IBAction) quitApp:(id)sender {
	NSLog(@"Quitting X9 Controller");
	self.protocol = nil;
	[[NSApplication sharedApplication] terminate:nil];
}

-(IBAction) switchSource:(id)sender {
	NSLog(@"Switching source to %@", [sender title]);
	[protocol setSource:[sender tag]];
}

-(IBAction) powerOnOff:(id)sender {
	if ([protocol isProjectorOn]) {
		NSLog(@"Powering Off projector");
		[protocol powerOff];
	} else {
		NSLog(@"Powering On projector");
		[protocol powerOn];
	}
}
	
-(IBAction) lockSource:(id)sender {
	NSLog(@"Locking source");
	if ([protocol isSourceLocked]) {
		[protocol unlockSource];
	} else {
		[protocol lockSource];
	}
	[self updateStatus];
}

-(IBAction) showMenu:(id)sender {
	NSLog(@"Showing menu");
	[protocol showMenu];
	[self updateStatus];
}

-(IBAction) preferences:(id)sender {
	NSLog(@"Preferences");
}

-(IBAction) setDisplayMode:(id)sender {
	[protocol setDisplayMode:[sender tag]];
}


-(IBAction) setPreset:(id)sender {
	switch ([sender tag]) {
		case 1: {
			NSLog(@"Setting Game preset");
			// GAME
			[protocol setDisplayMode:kDisplayMode_Game];
			[protocol setBrightness:30];
			[protocol setContrast:-10];
			break;
		}
		case 2: {
			NSLog(@"Setting PC preset");
			// PC
			[protocol setDisplayMode:kDisplayMode_PC];
			[protocol setBrightness:0];
			[protocol setContrast:-3];
			break;
		}
		default:
			break;
	}
}

#pragma mark -
#pragma mark HTTP Server request handler

//-(NSString*) respondToURI:(NSString*)uri {
-(NSString*) respondToURI:(NSString*)uri ofType:(NSString*)type {
	// URL example: http://hostname:64299/PWR/1, http://hostname:64299/DSP!
	// pattern: http://<host>:<port>/<action>/<value>
	
	BOOL uriRecognized = NO;
	
	// split url
	NSMutableArray *reqMsgArr = [NSMutableArray array];
	// check if starts with / and remove it
	if ([uri startsWith:@"/"]) {
		uri = [uri substringFromIndex:1];
	}
	NSRange rng = [uri rangeOfString:@"/"];
	if (rng.location!=NSNotFound) {
		[reqMsgArr addObject:[uri substringWithRange:NSMakeRange(0, rng.location)]];
		if (uri.length > rng.location+1) {
			[reqMsgArr addObject:[uri substringFromIndex:(rng.location+1)]];
		}
	} else {
		[reqMsgArr addObject:uri];
	}
	
	NSArray *knownMessages = [NSArray arrayWithObjects:@"PWR",@"SRC",@"DSP",@"SRL",@"BRI",@"CON",@"KEY",nil];
	
	if (reqMsgArr.count > 0) {
		NSString *msg = [reqMsgArr objectAtIndex:0];
		if (msg.length>=3) {
			msg = [msg substringToIndex:3];
		}
		for (UInt32 i=0; i< knownMessages.count; ++i) {
			if ([[knownMessages objectAtIndex:i] isEqualToString:msg]) {
				uriRecognized = YES;
				break;
			}
		}
	}
	
	NSDictionary *resultDict = nil;
	if (uriRecognized) {
		NSString *msg = [reqMsgArr objectAtIndex:0];
		if (reqMsgArr.count > 1) {
			// send data message
			UInt32 value = [[reqMsgArr objectAtIndex:1] intValue];
			BOOL result = [protocol sendInputMessage:msg withValue:value];
			resultDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:result] forKey:@"result"];
		} else {
			msg = [msg stringByReplacingOccurrencesOfString:@"Q" withString:@"?"];
			// request data message
			UInt32 result = [protocol sendReadValueMessage:msg];
			resultDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:result] forKey:@"result"];
		}
	} else {
		NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
		// query full status
		[tmpDict setObject:[NSNumber numberWithBool:[protocol isProjectorOn]] forKey:@"PWR"];
		[tmpDict setObject:[NSNumber numberWithInt:[protocol source]] forKey:@"SRC"];
		[tmpDict setObject:[NSNumber numberWithInt:[protocol displayMode]] forKey:@"DSP"];
		[tmpDict setObject:[NSNumber numberWithBool:[protocol isSourceLocked]] forKey:@"SRL"];
		[tmpDict setObject:[NSNumber numberWithInt:[protocol sendReadValueMessage:@"BRI?"]] forKey:@"BRI"];
		[tmpDict setObject:[NSNumber numberWithInt:[protocol sendReadValueMessage:@"CON?"]] forKey:@"CON"];
		resultDict = tmpDict;
	}
	
	// return the same simple html page for every request
	if ([type isEqualToString:@"HTML"]) {
		return [self buildHTMLResponse];
	} else if ([type isEqualToString:@"JSON"]) {
		CJSONSerializer *serializer = [CJSONSerializer serializer];
		return [serializer serializeDictionary:resultDict];
	} else if ([type isEqualToString:@"XML"]) {
		// TODO: respond with XML
	}
	return @"";
}

-(NSString*) comboBoxWithItems:(NSArray*)items andIntValue:(UInt32)selectedValue message:(NSString*)message {
	NSString *selectHTML = [NSString stringWithFormat:@"<select id='%@' onchange='submitComboMessage(\"%@\")'>", [NSString stringWithFormat:@"%@_combo", message],  message];
	for (UInt32 i=0; i< items.count; ++i) {
		NSString *item = [items objectAtIndex:i];
		NSString *itemOption = [NSString stringWithFormat:@"<option value='%d' %@ >%@</option>", i, (i==selectedValue?@"selected":@""), item];
		selectHTML = [selectHTML stringByAppendingString:itemOption];
	}
	selectHTML = [selectHTML stringByAppendingString:@"</select>"];
	return selectHTML;
}

-(NSString*) buildHTMLResponse {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"web" withExtension:@"html"];
	NSString *response = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];

	
// read localized strings (great way to learn stuff on your hobby project, this case - localization on OSX & iOS)
	NSArray *sourceNames = [NSArray arrayWithObjects:NSLocalizedStringFromTable(@"SourceComputer",@"InfoPlist",@""), 
							NSLocalizedStringFromTable(@"SourceComponent",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"SourceS-Video",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"SourceComposite",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"SourceDVI",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"SourceSCART",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"SourceHDMI",@"InfoPlist",nil), 
							nil]; 
	
//	NSLog(@"Sources: '%@'", sourceNames);
	
	NSArray *displayModesArr = [NSArray arrayWithObjects:NSLocalizedStringFromTable(@"DisplayPC",@"InfoPlist",@""), 
							NSLocalizedStringFromTable(@"DisplayMovie",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"DisplaySRGB",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"DisplayGame",@"InfoPlist",nil), 
							NSLocalizedStringFromTable(@"DisplayUser",@"InfoPlist",nil), 
							nil]; 
	
//	NSLog(@"Display Modes: '%@'", displayModesArr);
	
// query projector for status
	BOOL projectorOn = [protocol isProjectorOn];
	UInt32 sourceIndex = [protocol source];
	UInt32 displayModeIndex = [protocol displayMode];
	BOOL sourceLocked = [protocol isSourceLocked];
	
	
	
// replace html template placeholders with real values
	NSMutableDictionary *replacables = [NSMutableDictionary dictionary];
	[replacables setObject:(projectorOn?@"On":@"Off") forKey:@"${POWER_STATE_NAME}"];
	[replacables setObject:(sourceIndex==-1?@"N/A":[sourceNames objectAtIndex:sourceIndex]) forKey:@"${SOURCE}"];
	[replacables setObject:(sourceLocked?@"Yes":@"No") forKey:@"${SOURCE_LOCKED}"];
	[replacables setObject:(displayModeIndex==-1?@"N/A":[displayModesArr objectAtIndex:displayModeIndex]) forKey:@"${DISPLAY_MODE}"];
	
	// Power On/Off
	[replacables setObject:(!projectorOn?@"On":@"Off") forKey:@"${POWER_STATE_TOGGLE_NAME}"];		// name
	[replacables setObject:(!projectorOn?@"1":@"0") forKey:@"${POWER_STATE}"];					// value
		
	// SELECT_SOURCE_COMBO
	[replacables setObject:[self comboBoxWithItems:sourceNames andIntValue:sourceIndex message:@"SRC"] forKey:@"${SELECT_SOURCE_COMBO}"];
	
	// SELECT_DISPLAY_MODE_COMBO
	[replacables setObject:[self comboBoxWithItems:displayModesArr andIntValue:displayModeIndex message:@"DSP"] forKey:@"${SELECT_DISPLAY_MODE_COMBO}"];
	
	// replace every occurence in web template with current value
	NSArray *keyArray =  [replacables allKeys];
	for (int i=0; i < [keyArray count]; ++i) {
		NSString *key = [keyArray objectAtIndex:i];
		NSString *value = [replacables objectForKey:key];
		response = [response stringByReplacingOccurrencesOfString:key withString:value];
	}
	
	return response;
}

@end
