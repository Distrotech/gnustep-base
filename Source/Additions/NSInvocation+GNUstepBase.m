/* Implementation of extension methods to base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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
#import "config.h"
#import "GNUstepBase/NSInvocation+GNUstepBase.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

@implementation NSInvocation(GSCompatibility)
- (retval_t) returnFrame:(arglist_t)args
{
#warning (stephane@sente.ch) Not implemented
  return (retval_t)[self notImplemented:_cmd];
}

- (id) initWithArgframe:(arglist_t)args selector:(SEL)selector
{
#warning (stephane@sente.ch) Not implemented
  return [self notImplemented:_cmd];
}

@end
