//
//  InFocusControllerAppDelegate.h
//  InFocusController
//
//  Created by Janis Dancis on 10/6/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ProjectorProtocol.h"

@interface InFocusControllerAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
	IBOutlet NSMenu *statusMenu;
	NSStatusItem *statusItem;
	IBOutlet NSMenuItem *powerItem;
	IBOutlet NSMenuItem *quitItem;
	IBOutlet NSMenuItem *sourceLock;
	IBOutlet NSMenu *sources;
	ProjectorProtocol *protocol;
	NSLock *connectLock;
	NSTimer *timer;
}

@property (retain) ProjectorProtocol *protocol;
@property (retain) NSLock *connectLock;
@property (retain) NSMenuItem *powerItem;
@property (retain) NSMenuItem *quitItem;
@property (retain) NSMenuItem *sourceLock;
@property (retain) NSMenu *sources;
@property (retain) NSTimer *timer;

-(void) connectToProjector;
-(void) toggleStatus;

-(IBAction) quitApp:(id)sender;
-(IBAction) switchSource:(id)sender;
-(IBAction) powerOnOff:(id)sender;

-(IBAction) lockSource:(id)sender;
-(IBAction) showMenu:(id)sender;

-(IBAction) preferences:(id)sender;


@property (assign) IBOutlet NSWindow *window;

@end
