//
//  InFocusControllerAppDelegate.h
//  InFocusController
//
//  Created by Janis Dancis on 10/6/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ProjectorProtocol.h"
#import "SimpleHTTPServer.h"


@interface InFocusControllerAppDelegate : NSObject <NSApplicationDelegate, RequestHandler> {
    NSWindow *window;
	IBOutlet NSMenu *statusMenu;
	NSStatusItem *statusItem;
	IBOutlet NSMenuItem *powerItem;
	IBOutlet NSMenuItem *quitItem;
	IBOutlet NSMenuItem *sourceLock;
	IBOutlet NSMenu *sources;
	IBOutlet NSMenu *displayModes;
	ProjectorProtocol *protocol;
	NSLock *connectLock;
	NSTimer *timer;
	
	// remote access
	SimpleHTTPServer *httpServer;
}

@property (retain) ProjectorProtocol *protocol;
@property (retain) NSLock *connectLock;
@property (retain) NSMenuItem *powerItem;
@property (retain) NSMenuItem *quitItem;
@property (retain) NSMenuItem *sourceLock;
@property (retain) NSMenu *sources;
@property (retain) NSMenu *displayModes;
@property (retain) NSTimer *timer;
@property (retain) SimpleHTTPServer *httpServer;

-(void) connectToProjector;
-(void) updateStatus;

-(IBAction) quitApp:(id)sender;
-(IBAction) switchSource:(id)sender;
-(IBAction) powerOnOff:(id)sender;

-(IBAction) lockSource:(id)sender;
-(IBAction) showMenu:(id)sender;

-(IBAction) preferences:(id)sender;

-(IBAction) setPreset:(id)sender;

-(IBAction) setDisplayMode:(id)sender;

@property (assign) IBOutlet NSWindow *window;

@end
