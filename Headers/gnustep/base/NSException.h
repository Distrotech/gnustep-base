/* Interface for NSException for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: 1995

   Adapted to work together with other C and Objective-C exceptions by
   Niels M�ller <nisse@lysator.liu.se>
   
   This file is part of the GNU Objective C Class Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSException_h_OBJECTS_INCLUDE
#define __NSException_h_OBJECTS_INCLUDE

#include <Foundation/NSString.h>
#include <objects/Catch.h>
#include <stdarg.h>

@class NSDictionary;

@interface NSException : NSObject <NSCoding, NSCopying>
{    
  NSString *e_name;
  NSString *e_reason;
  NSDictionary *e_info;
}

+ (NSException *)exceptionWithName:(NSString *)name
	reason:(NSString *)reason
	userInfo:(NSDictionary *)userInfo;
+ (volatile void)raise:(NSString *)name
	format:(NSString *)format,...;
+ (volatile void)raise:(NSString *)name
	format:(NSString *)format
	arguments:(va_list)argList;

- (id)initWithName:(NSString *)name 
	reason:(NSString *)reason 
	userInfo:(NSDictionary *)userInfo;
- (volatile void)raise;

// Querying Exceptions
- (NSString *)name;
- (NSString *)reason;
- (NSDictionary *)userInfo;

@end

/* Common exceptions */
extern NSString *NSInconsistentArchiveException;
extern NSString *NSGenericException;
extern NSString *NSInternalInconsistencyException;
extern NSString *NSInvalidArgumentException;
extern NSString *NSMallocException;
extern NSString *NSRangeException;


@interface NSHandler : Catch_common
{
  NSException * theException;
}
- (NSException *) exception;
- exception: (NSException *) anException;
@end /* NSHandler */


typedef volatile void NSUncaughtExceptionHandler(NSException *exception);

extern NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler;
#define NSGetUncaughtExceptionHandler() _NSUncaughtExceptionHandler
#define NSSetUncaughtExceptionHandler(proc) \
			(_NSUncaughtExceptionHandler = (proc))

/* NS_DURING, NS_HANDLER and NS_ENDHANDLER are always used like:

	NS_DURING
	    some code which might raise an error
	NS_HANDLER
	    code that will be jumped to if an error occurs
	NS_ENDHANDLER

   If any error is raised within the first block of code, the second block
   of code will be jumped to.  Typically, this code will clean up any
   resources allocated in the routine, possibly case on the error code
   and perform special processing, and default to RERAISE the error to
   the next handler.  Within the scope of the handler, a local variable
   called exception holds information about the exception raised.

   It is illegal to exit the first block of code by any other means than
   NS_VALRETURN, NS_VOIDRETURN, or just falling out the bottom.
 */

#define NS_DURING { NSHandler* _LocalHandler = [NSHandler new]; \
		    if (SETJMP(*[_LocalHandler catch]) == 0) { 

#define NS_HANDLER [_LocalHandler release]; \
		  } else { \
		     NSException *exception = [_LocalHandler exception]; \
		     [_LocalHandler release];

#define NS_ENDHANDLER }}

#define NS_VALRETURN(val) do { typeof(val) temp = (val);	\
			       [_LocalHandler release];	\
			       return(temp); } while (0)

#define NS_VOIDRETURN do { [_LocalHandler release];	\
			   return; } while (0)


/* ------------------------------------------------------------------------ */
/*   Assertion Handling */
/* ------------------------------------------------------------------------ */

@interface NSAssertionHandler : NSObject

+ (NSAssertionHandler *)currentHandler;

- (void)handleFailureInFunction:(NSString *)functionName 
	file:(NSString *)fileName 
	lineNumber:(int)line 
	description:(NSString *)format,...;

- (void)handleFailureInMethod:(SEL)aSelector 
	object:object 
	file:(NSString *)fileName 
	lineNumber:(int)line 
	description:(NSString *)format,...;

@end

#define _NSAssertArgs(condition, desc, args...)		\
    do {							\
	if (!(condition)) {					\
	    [[NSAssertionHandler currentHandler] 		\
	    	handleFailureInMethod:_cmd 			\
		object:self 					\
		file:[NSString stringWithCString:__FILE__] 	\
		lineNumber:__LINE__ 				\
		description:(desc) , ## args]; 			\
	}							\
    } while(0)

#define _NSCAssertArgs(condition, desc, args...)		\
    do {							\
	if (!(condition)) {					\
	    [[NSAssertionHandler currentHandler] 		\
	    handleFailureInFunction:[NSString stringWithCString:__PRETTY_FUNCTION__] 				\
	    file:[NSString stringWithCString:__FILE__] 		\
	    lineNumber:__LINE__ 				\
	    description:(desc) , ## args]; 			\
	}							\
    } while(0)


/* Asserts to use in Objective-C method bodies*/ 
#define NSAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5)	\
    _NSAssertArgs((condition), (desc), (arg1), (arg2), (arg3), (arg4), (arg5))

#define NSAssert4(condition, desc, arg1, arg2, arg3, arg4)	\
    _NSAssertArgs((condition), (desc), (arg1), (arg2), (arg3), (arg4))

#define NSAssert3(condition, desc, arg1, arg2, arg3)	\
    _NSAssertArgs((condition), (desc), (arg1), (arg2), (arg3))

#define NSAssert2(condition, desc, arg1, arg2)		\
    _NSAssertArgs((condition), (desc), (arg1), (arg2))

#define NSAssert1(condition, desc, arg1)		\
    _NSAssertArgs((condition), (desc), (arg1))

#define NSAssert(condition, desc)			\
    _NSAssertArgs((condition), (desc))

#define NSParameterAssert(condition)			\
    _NSAssertArgs((condition), @"Invalid parameter not satisfying: %s", #condition)

/* Asserts to use in C function bodies */
#define NSCAssert5(condition, desc, arg1, arg2, arg3, arg4, arg5)	\
    _NSCAssertArgs((condition), (desc), (arg1), (arg2), (arg3), (arg4), (arg5))

#define NSCAssert4(condition, desc, arg1, arg2, arg3, arg4)	\
    _NSCAssertArgs((condition), (desc), (arg1), (arg2), (arg3), (arg4))

#define NSCAssert3(condition, desc, arg1, arg2, arg3)	\
    _NSCAssertArgs((condition), (desc), (arg1), (arg2), (arg3))

#define NSCAssert2(condition, desc, arg1, arg2)		\
    _NSCAssertArgs((condition), (desc), (arg1), (arg2))

#define NSCAssert1(condition, desc, arg1)		\
    _NSCAssertArgs((condition), (desc), (arg1))

#define NSCAssert(condition, desc)			\
    _NSCAssertArgs((condition), (desc))

#define NSCParameterAssert(condition)			\
    _NSCAssertArgs((condition), @"Invalid parameter not satisfying: %s", #condition)

#endif /* __NSException_h_OBJECTS_INCLUDE */
