/* Interface for NSUUID for GNUStep
   Copyright (C) 2013 Free Software Foundation, Inc.

   Written by:  Graham Lee <graham@iamleeg.com>
   Created: 2013
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#ifndef __NSUUID_h_GNUSTEP_BASE_INCLUDE
#define __NSUUID_h_GNUSTEP_BASE_INCLUDE

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSString;

@interface NSUUID : NSObject <NSCopying, NSCoding>
{
  @private
  uint8_t uuid[16];
}

+ (id) UUID;
- (id) initWithUUIDString: (NSString *)string;
- (id) initWithUUIDBytes: (uint8_t*)bytes;
- (NSString *) UUIDString;
- (void) getUUIDBytes: (uint8_t*)bytes;

@end

#if     defined(__cplusplus)
}
#endif

#endif /* __NSUUID_h_GNUSTEP_BASE_INCLUDE */
