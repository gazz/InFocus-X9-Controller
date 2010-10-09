//
//  InFocusControllerAppDelegate.m
//  InFocusController
//
//  Created by Janis Dancis on 10/6/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import "InFocusControllerAppDelegate.h"
#import "AMSerialPortList.h"

@implementation InFocusControllerAppDelegate

@synthesize window, protocol, connectLock, powerItem, quitItem, timer, sourceLock, sources;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.connectLock = [[NSLock alloc] init];
	[self toggleStatus];
	// open connection in background thread 
	[self performSelectorInBackground:@selector(connectToProjector) withObject:nil];
	
	self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(toggleStatus) userInfo:nil repeats:YES];
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
	[timer release];
	[powerItem release];
	[quitItem release];
	[sourceLock release];
	[sources release];
	[protocol release];
	[connectLock release];
	[super dealloc];
}

-(void) connectToProjector {
	[connectLock lock];
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
	AMSerialPort *aPort;
	while (aPort = [enumerator nextObject]) {
		NSLog(@"Trying device: %@", [aPort bsdPath]);
		self.protocol = [ProjectorProtocol protocolWithDevPath:[aPort bsdPath]];
		if ([protocol isOpen] && [protocol isProjectorConnected]) {
			NSLog(@"Successfully connected to projector: %@", [aPort bsdPath]);
			[self performSelectorOnMainThread:@selector(toggleStatus) withObject:nil waitUntilDone:NO];
			break;
		} else {
			self.protocol = nil;
		}
	}
	if (protocol==nil) {
		NSLog(@"Cannot find projector");
	}
	[pool release];
	[connectLock unlock];
}


-(void) toggleStatus {
	[connectLock lock];
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
		if ([item tag]==activeSource)
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
	[self toggleStatus];
}

-(IBAction) showMenu:(id)sender {
	NSLog(@"Showing menu");
	[protocol showMenu];
	[self toggleStatus];
}

-(IBAction) preferences:(id)sender {
	NSLog(@"Preferences");
}


@end
