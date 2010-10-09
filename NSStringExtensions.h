//
//  NSStringExtensions.h
//  SerialPortTest
//
//  Created by Janis Dancis on 10/7/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (MyCategory)
- (BOOL) startsWith: (NSString*) prefix;
- (BOOL) endsWith: (NSString*) postfix;
@end

