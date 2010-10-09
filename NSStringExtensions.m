//
//  NSStringExtensions.m
//  SerialPortTest
//
//  Created by Janis Dancis on 10/7/10.
//  Copyright 2010 digihaze. All rights reserved.
//

#import "NSStringExtensions.h"



@implementation NSString (MyCategory)
- (BOOL) startsWith: (NSString*) prefix {
	NSRange range = [self rangeOfString:prefix];
	if (range.location==0 && range.length==[prefix length]) {
		return YES;
	}
	return NO;
}

- (BOOL) endsWith: (NSString*) postfix {
	NSRange range = [self rangeOfString:postfix];
	if(range.location == (self.length - postfix.length) && range.length==postfix.length) {
		return YES;
	}
	return NO;
}

@end