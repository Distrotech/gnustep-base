/* Implementation of abstract superclass port for use with NSConnection
   Copyright (C) 1997, 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: August 1997

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
   */

#include <config.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSPortCoder.h>
#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSAutoreleasePool.h>

@class	GSTcpPort;

@implementation NSPort

Class	NSPort_abstract_class;
Class	NSPort_concrete_class;

+ (id) allocWithZone: (NSZone*)aZone
{
  if (self == NSPort_abstract_class)
    {
      return NSAllocateObject(NSPort_concrete_class, 0, aZone);
    }
  else
    {
      return NSAllocateObject(self, 0, aZone);
    }
}

+ (void) initialize
{
  if (self == [NSPort class])
    {
      NSPort_abstract_class = self;
      NSPort_concrete_class = [GSTcpPort class];
    }
}

+ (NSPort*) port
{
  return AUTORELEASE([NSPort_concrete_class new]);
}

+ (NSPort*) portWithMachPort: (int)machPort
{
  return AUTORELEASE([[self alloc] initWithMachPort: machPort]);
}

- (id) copyWithZone: (NSZone*)aZone
{
  return RETAIN(self);
}

- (id) delegate
{
  return _delegate;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [(NSPortCoder*)aCoder encodePortObject: self];
}

- (id) init
{
  self = [super init];
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  id	obj = [(NSPortCoder*)aCoder decodePortObject];

  if (obj != self)
    {
      RELEASE(self);
      self = RETAIN(obj);
    }
  return self;
}

- (id) initWithMachPort: (int)machPort
{
  [self shouldNotImplement: _cmd];
  return nil;
}

/*
 *	subclasses should override this method and call [super invalidate]
 *	in their versions of the method.
 */
- (void) invalidate
{
  NSAutoreleasePool	*arp;

  [[NSPortNameServer systemDefaultPortNameServer] removePort: self];
  _is_valid = NO;
  /*
   * Use a local autorelease pool when invalidating so that we know that
   * anything refering to this port during the invalidation process is
   * released immediately.
   */
  arp = [NSAutoreleasePool new];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSPortDidBecomeInvalidNotification
		  object: self];
  [arp release];
}

- (BOOL) isValid
{
  return _is_valid;
}

- (int) machPort
{
  [self shouldNotImplement: _cmd];
  return 0;
}

- (id) retain
{
  return [super retain];
}

- (id) autorelease
{
  return [super autorelease];
}

- (void) release
{
  if (_is_valid && [self retainCount] == 1)
    {
      /*
       * If the port is about to have a final release deallocate it
       * we must invalidate it.
       * Bracket with retain/release pair to prevent recursion.
       */
      [super retain];
      [self invalidate];
      [super release];
    }
  [super release];
}

- (void) setDelegate: (id) anObject
{
  NSAssert([anObject respondsToSelector: @selector(handlePortMessage:)],
    NSInvalidArgumentException);
  _delegate = anObject;
}

- (void) addConnection: (NSConnection*)aConnection
             toRunLoop: (NSRunLoop*)aLoop
               forMode: (NSString*)aMode
{
  [aLoop addPort: self forMode: aMode];
}

- (void) removeConnection: (NSConnection*)aConnection
              fromRunLoop: (NSRunLoop*)aLoop
                  forMode: (NSString*)aMode
{
  [aLoop removePort: self forMode: aMode];
}

- (unsigned) reservedSpaceLength
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL) sendBeforeDate: (NSDate*)when
             components: (NSMutableArray*)components
                   from: (NSPort*)receivingPort
               reserved: (unsigned) length
{
  return [self sendBeforeDate: when
			msgid: 0
		   components: components
			 from: receivingPort
		     reserved: length];
}

- (BOOL) sendBeforeDate: (NSDate*)when
		  msgid: (int)msgid
             components: (NSMutableArray*)components
                   from: (NSPort*)receivingPort
               reserved: (unsigned)length
{
  [self subclassResponsibility: _cmd];
  return YES;
}

@end

