/** Implementation for NSNull for GNUStep
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2000
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSNull class reference</title>
   $Date$ $Revision$
   */ 

/*
 * An object to use as a placeholder - in collections for instance.
 */
#include <Foundation/NSNull.h>

@implementation	NSNull

static NSNull	*null = 0;

+ (id) allocWithZone: (NSZone*)z
{
  return null;
}

+ (id) alloc
{
  return null;
}

+ (void) initialize
{
  if (null == 0)
    {
      null = (NSNull*)NSAllocateObject(self, 0, NSDefaultMallocZone());
    }
}

+ (NSNull*) null
{
  return null;
}

- (id) autorelease
{
  return self;
}

- (id) copyWithZone: (NSZone*)z
{
  return self;
}

- (id) copy
{
  return self;
}

- (void) dealloc
{
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  return self;
}

- (BOOL) isEqual: (id)other
{
  if (other == self)
    return YES;
  else
    return NO;
}

- (void) release
{
}

- (id) retain
{
  return self;
}
@end


