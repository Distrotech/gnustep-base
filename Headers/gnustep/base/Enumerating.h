/* Protocol for GNU Objective C invocations
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: February 1996
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */ 

#ifndef __Enumerating_h__GNUSTEP_BASE_INCLUDE
#define __Enumerating_h__GNUSTEP_BASE_INCLUDE

#include <base/preface.h>

@protocol Enumerating <NSObject>

- initWithCollection: aCollection;
- nextObject;

@end

#endif /* __Enumerating_h__GNUSTEP_BASE_INCLUDE */

