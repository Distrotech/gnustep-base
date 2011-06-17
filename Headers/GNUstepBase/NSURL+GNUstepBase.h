/** Declaration of extension methods for base additions

   Copyright (C) 2003-2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   and:         Adam Fedor <fedor@gnu.org>

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

#ifndef	INCLUDED_NSURL_GNUstepBase_h
#define	INCLUDED_NSURL_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSURL.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@interface NSURL (GNUstepBaseAdditions)

/** Builds a URL from components as returned by the methods of the same names.
 */
- (id) initWithScheme: (NSString*)scheme
		 user: (NSString*)user
	     password: (NSString*)password
		 host: (NSString*)host
		 port: (NSNumber*)port
	     fullPath: (NSString*)fullPath
      parameterString: (NSString*)parameterString
		query: (NSString*)query
	     fragment: (NSString*)fragment;

@end

@interface NSURL (GNUstepBase)
/** Returns the full path for this URL including any trailing slash.
 */
- (NSString*) fullPath;
@end

#endif	/* OS_API_VERSION */

#if	defined(__cplusplus)
}
#endif

#endif	/* INCLUDED_NSURL_GNUstepBase_h */

