/* Interface for NSObject for GNUStep
   Copyright (C) 1995, 1996, 1998 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: 1995
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSObject_h_GNUSTEP_BASE_INCLUDE
#define __NSObject_h_GNUSTEP_BASE_INCLUDE

/*
 *	Check consistency of definitions for system compatibility.
 */
#if	defined(STRICT_OPENSTEP)
#define	NO_GNUSTEP	1
#elif	defined(STRICT_MACOS_X)
#define	NO_GNUSTEP	1
#else
#undef	NO_GNUSTEP
#endif

#include <GSConfig.h>
#include <objc/objc.h>
#include <objc/Protocol.h>
#include <Foundation/NSZone.h>
#include <base/fake-main.h>

@class NSArchiver;
@class NSArray;
@class NSCoder;
@class NSDictionary;
@class NSPortCoder;
@class NSMethodSignature;
@class NSMutableString;
@class NSRecursiveLock;
@class NSString;
@class NSInvocation;
@class Protocol;

@protocol NSObject
- (Class) class;
- (Class) superclass;
- (BOOL) isEqual: anObject;
- (BOOL) isKindOfClass: (Class)aClass;
- (BOOL) isMemberOfClass: (Class)aClass;
- (BOOL) isProxy;
- (unsigned) hash;
- self;
- performSelector: (SEL)aSelector;
- performSelector: (SEL)aSelector withObject: anObject;
- performSelector: (SEL)aSelector withObject: object1 withObject: object2;
- (BOOL) respondsToSelector: (SEL)aSelector;
- (BOOL) conformsToProtocol: (Protocol *)aProtocol;
- retain;
- autorelease;
- (oneway void) release;
- (unsigned) retainCount;
- (NSZone *) zone;
- (NSString *) description;
@end

@protocol NSCopying
- (id) copyWithZone: (NSZone *)zone;
@end

@protocol NSMutableCopying
- (id) mutableCopyWithZone: (NSZone *)zone;
@end

@protocol NSCoding
- (void) encodeWithCoder: (NSCoder*)aCoder;
- (id) initWithCoder: (NSCoder*)aDecoder;
@end


@interface NSObject <NSObject>
{
  Class isa;
}

+ (void) initialize;
+ (id) allocWithZone: (NSZone*)z;
+ (id) alloc;
+ (id) new;
- (id) copy;
- (void) dealloc;
- (id) init;
- (id) mutableCopy;

+ (Class) class;
+ (Class) superclass;

+ (BOOL) instancesRespondToSelector: (SEL)aSelector;

+ (IMP) instanceMethodForSelector: (SEL)aSelector;
- (IMP) methodForSelector: (SEL)aSelector;
+ (NSMethodSignature*) instanceMethodSignatureForSelector: (SEL)aSelector;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;

- (NSString*) description;
+ (NSString*) description;

+ (void) poseAsClass: (Class)aClass;

- (void) doesNotRecognizeSelector: (SEL)aSelector;

- (void) forwardInvocation: (NSInvocation*)anInvocation;

- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder;
- (Class) classForArchiver;
- (Class) classForCoder;
- (Class) classForPortCoder;
- (id) replacementObjectForArchiver: (NSArchiver*)anEncoder;
- (id) replacementObjectForCoder: (NSCoder*)anEncoder;
- (id) replacementObjectForPortCoder: (NSPortCoder*)anEncoder;


+ setVersion: (int)aVersion;
+ (int) version;

@end

NSObject *NSAllocateObject(Class aClass, unsigned extraBytes, NSZone *zone);
void NSDeallocateObject(NSObject *anObject);
NSObject *NSCopyObject(NSObject *anObject, unsigned extraBytes, NSZone *zone);

BOOL NSShouldRetainWithZone(NSObject *anObject, NSZone *requestedZone);
unsigned NSExtraRefCount(id anObject);
void NSIncrementExtraRefCount(id anObject);
BOOL NSDecrementExtraRefCountWasZero(id anObject);

typedef enum _NSComparisonResult 
{
  NSOrderedAscending = -1, NSOrderedSame, NSOrderedDescending
} 
NSComparisonResult;

enum {NSNotFound = 0x7fffffff};

@interface NSObject (NEXTSTEP)
- error:(const char *)aString, ...;
- notImplemented:(SEL)aSel;
/* - (const char *) name;
   Removed because OpenStep has -(NSString*)name; */
@end

#ifndef	NO_GNUSTEP
/* Global lock to be used by classes when operating on any global
   data that invoke other methods which also access global; thus,
   creating the potential for deadlock. */
extern NSRecursiveLock *gnustep_global_lock;

/*
 * The GNUDescriptionDestination protocol declares a single method used
 * to append a property-list description string to some output destination
 * so that property-lists can be converted to strings in a stream avoiding
 * the use of ridiculous amounts of memory for deeply nested data structures.
 */
@protocol       GNUDescriptionDestination
- (void) appendString: (NSString*)str;
@end

@interface NSObject (GNU)
- (int) compare: anObject;
- (void) descriptionTo: (id<GNUDescriptionDestination>)output;
- (void) descriptionWithLocale: (NSDictionary*)aLocale
			    to: (id<GNUDescriptionDestination>)output;
- (void) descriptionWithLocale: (NSDictionary*)aLocale
			indent: (unsigned)level
			    to: (id<GNUDescriptionDestination>)output;
- (Class)transmuteClassTo:(Class)aClassObject;
- subclassResponsibility:(SEL)aSel;
- shouldNotImplement:(SEL)aSel;
+ (Class) autoreleaseClass;
+ (void) setAutoreleaseClass: (Class)aClass;
+ (void) enableDoubleReleaseCheck: (BOOL)enable;
- read: (TypedStream*)aStream;
- write: (TypedStream*)aStream;
@end

/*
 *	Protocol for garbage collection finalization - same as libFoundation
 *	for compatibility.
 */
@protocol       GCFinalization
- (void) gcFinalize;
@end

#endif

#include <Foundation/NSDate.h>
@interface NSObject (TimedPerformers)
+ (void) cancelPreviousPerformRequestsWithTarget: (id)obj
					selector: (SEL)s
					  object: (id)arg;
- (void) performSelector: (SEL)s
	      withObject: (id)arg
	      afterDelay: (NSTimeInterval)seconds;
- (void) performSelector: (SEL)s
	      withObject: (id)arg
	      afterDelay: (NSTimeInterval)seconds
		 inModes: (NSArray*)modes;
@end

/*
 *	RETAIN(), RELEASE(), and AUTORELEASE() are placeholders for the
 *	future day when we have garbage collecting.
 */
#ifndef	GS_WITH_GC
#define	GS_WITH_GC	0
#endif
#if	GS_WITH_GC

#ifndef	RETAIN
#define	RETAIN(object)		((id)object)
#endif
#ifndef	RELEASE
#define	RELEASE(object)		
#endif
#ifndef	AUTORELEASE
#define	AUTORELEASE(object)	((id)object)
#endif

#ifndef	TEST_RETAIN
#define	TEST_RETAIN(object)	((id)object)
#endif
#ifndef	TEST_RELEASE
#define	TEST_RELEASE(object)
#endif
#ifndef	TEST_AUTORELEASE
#define	TEST_AUTORELEASE(object)	((id)object)
#endif

#ifndef	ASSIGN
#define	ASSIGN(object,value)	(object = value)
#endif
#ifndef	ASSIGNCOPY
#define	ASSIGNCOPY(object,value)	(object = [value copy])
#endif
#ifndef	DESTROY
#define	DESTROY(object) 	(object = nil)
#endif

#ifndef	CREATE_AUTORELEASE_POOL
#define	CREATE_AUTORELEASE_POOL(X)	
#endif

#else

/*
 *	Basic retain, release, and autorelease operations.
 */
#ifndef	RETAIN
#define	RETAIN(object)		[object retain]
#endif
#ifndef	RELEASE
#define	RELEASE(object)		[object release]
#endif
#ifndef	AUTORELEASE
#define	AUTORELEASE(object)	[object autorelease]
#endif

/*
 *	Tested retain, release, and autorelease operations - only invoke the
 *	objective-c method if the receiver is not nil.
 */
#ifndef	TEST_RETAIN
#define	TEST_RETAIN(object)	(object != nil ? [object retain] : nil)
#endif
#ifndef	TEST_RELEASE
#define	TEST_RELEASE(object)	({ if (object) [object release]; })
#endif
#ifndef	TEST_AUTORELEASE
#define	TEST_AUTORELEASE(object)	({ if (object) [object autorelease]; })
#endif

/*
 *	ASSIGN(object,value) assignes the value to the object with
 *	appropriate retain and release operations.
 */
#ifndef	ASSIGN
#define	ASSIGN(object,value)	({\
typeof (value) __value = (value); \
if (__value != object) \
  { \
    if (__value) \
      { \
	[__value retain]; \
      } \
    if (object) \
      { \
	[object release]; \
      } \
    object = __value; \
  } \
})
#endif

/*
 *	ASSIGNCOPY(object,value) assignes a copy of the value to the object with
 *	and release operations.
 */
#ifndef	ASSIGNCOPY
#define	ASSIGNCOPY(object,value)	({\
typeof (value) __value = (value); \
if (__value != object) \
  { \
    if (__value) \
      { \
	__value = [__value copy]; \
      } \
    if (object) \
      { \
	[object release]; \
      } \
    object = __value; \
  } \
})
#endif

/*
 *	DESTROY() is a release operation which also sets the object to be
 *	a nil pointer for tidyness - we can't accidentally use a DESTROYED
 *	object later.
 */
#ifndef	DESTROY
#define	DESTROY(object) 	({ \
  if (object) \
    { \
      [object release]; \
      object = nil; \
    } \
})
#endif

#ifndef	CREATE_AUTORELEASE_POOL
#define	CREATE_AUTORELEASE_POOL(X)	\
  NSAutoreleasePool *(X) = [NSAutoreleasePool new]
#endif

#endif

#endif /* __NSObject_h_GNUSTEP_BASE_INCLUDE */
