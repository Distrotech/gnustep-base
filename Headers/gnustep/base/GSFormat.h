/* GSFormat - printf-style formatting
    
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Kai Henningsen <kai@cats.ms>
   Created: Jan 2001

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

#ifndef __GSFormat_H_
#define __GSFormat_H_

#include	<Foundation/NSZone.h>

@class	NSDictionary;

typedef struct {
  unichar	*buf;
  size_t	len;
  size_t	size;
  NSZone	*z;
} FormatBuf_t;

void 
GSFormat(FormatBuf_t *fb, const unichar *fmt, va_list ap, NSDictionary *loc);

#endif

