/* Interface for NSRunLoop for GNUStep
   Copyright (C) 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: March 1996

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

#ifndef __NSRunLoop_h_GNUSTEP_BASE_INCLUDE
#define __NSRunLoop_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSMapTable.h>

@class NSTimer, NSDate, NSPort;

/**
 * Run loop mode used to deal with input sources other than NSConnections or
 * dialog windows.  Most commonly used. Defined in
 * <code>Foundation/NSRunLoop.h</code>.
 */
GS_EXPORT NSString * const NSDefaultRunLoopMode;

@interface NSRunLoop : NSObject <GCFinalization>
{
  @private
  NSString		*_currentMode;
  NSMapTable		*_contextMap;
  NSMutableArray	*_contextStack;
  NSMutableArray	*_timedPerformers;
  void			*_extra;
}

+ (NSRunLoop*) currentRunLoop;

- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)limit_date;

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode;

- (NSString*) currentMode;

- (NSDate*) limitDateForMode: (NSString*)mode;

- (void) run;

- (BOOL) runMode: (NSString*)mode
      beforeDate: (NSDate*)date;

- (void) runUntilDate: (NSDate*)date;

@end

@interface NSRunLoop(OPENSTEP)

- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode;

- (void) cancelPerformSelectorsWithTarget: (id)target;

- (void) cancelPerformSelector: (SEL)aSelector
			target: (id)target
		      argument: (id)argument;

- (void) configureAsServer;

- (void) performSelector: (SEL)aSelector
		  target: (id)target
		argument: (id)argument
		   order: (unsigned int)order
		   modes: (NSArray*)modes;

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode;

@end

/*
 *	GNUstep extensions
 */

/**
 * Enumeration of event types that an [NSRunLoop] watcher
 * can watch for.  See [NSRunLoop-addEvent:type:watcher:forMode:].
 * This is a GNUstep extension.
 <example>
{
    ET_RDESC,	// Watch for descriptor becoming readable.
    ET_WDESC,	// Watch for descriptor becoming writeable.
    ET_RPORT,	// Watch for message arriving on port.
    ET_EDESC	// Watch for descriptor with out-of-band data.
}
 </example>
 */
typedef	enum {
#ifdef __MINGW__
    ET_HANDLE,
#else
    ET_RDESC,	/* Watch for descriptor becoming readable.	*/
    ET_WDESC,	/* Watch for descriptor becoming writeable.	*/
#endif
    ET_RPORT,	/* Watch for message arriving on port.		*/
/* For binary compatibility we have an extra ifdef... */
#ifndef __MINGW__
    ET_EDESC	/* Watch for descriptor with out-of-band data.	*/
#endif
} RunLoopEventType;

/**
 * This protocol documents the callback messages that an object
 * receives if it has registered to receive run loop events using
 * [NSRunLoop-addEvent:type:watcher:forMode:]
 */
@protocol RunLoopEvents
/**
 * Callback message sent to object waiting for an event in the
 * runloop when the limit-date for the operation is reached.
 * If an NSDate object is returned, the operation is restarted
 * with the new limit-date, otherwise it is removed from the
 * run loop.
 */
- (NSDate*) timedOutEvent: (void*)data
		     type: (RunLoopEventType)type
		  forMode: (NSString*)mode;
/**
 * Callback message sent to object when the event it it waiting
 * for occurs.  The 'data' and 'type' valueds are those passed in the
 * original -addEvent:type:watcher:forMode: method.
 * The 'extra' value may be additional data returned depending
 * on the type of event.
 */
- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode;
@end

/**
 * These are general purpose methods for letting objects ask
 * the runloop to watch for events for them.  Only one object
 * at a time may be watching for a particular event in a mode, but
 * that object may add itself as a watcher many times as long as
 * each addition is matched by a removal (the run loop keeps count).
 * Alternatively, the 'removeAll' parameter may be set to 'YES' for
 * [-removeEvent:type:forMode:all:] in order to remove the watcher
 * irrespective of the number of times it has been added.
 */
@interface NSRunLoop(GNUstepExtensions)

/**
 * Adds a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the -currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.<br />
 * NB. The watcher is <em>not</em> retained by the run loop and must
 * be removed from the loop before deallocation ... otherwise the loop
 * might try to send a message to the deallocated watcher object
 * resulting in a crash. You use -removeEvent:type:forMode:all: to do this.
 */
- (void) addEvent: (void*)data
	     type: (RunLoopEventType)type
	  watcher: (id<RunLoopEvents>)watcher
	  forMode: (NSString*)mode;

/**
 * Removes a runloop watcher matching the specified data and type in this
 * runloop.  If the mode is nil, either the -currentMode is used (if the
 * loop is running) or NSDefaultRunLoopMode is used.<br />
 * The additional removeAll flag may be used to remove all instances of
 * the watcher rather than just a single one.
 */
- (void) removeEvent: (void*)data
	        type: (RunLoopEventType)type
	     forMode: (NSString*)mode
		 all: (BOOL)removeAll;
@end

/**
 * Defines implementation-helper method -getFds:count:.
 * <strong>This interface will probably change.  Do not rely on it.</strong>
 */
// xxx This interface will probably change.
@interface NSObject (OptionalPortRunLoop)
/** If a InPort object responds to this, it is sent just before we are
   about to wait listening for input.
   This interface will probably change. */
- (void) getFds: (int*)fds count: (int*)count;
@end

#ifdef __MINGW32__
/**
 * Interface that add method to set target for win32 messages.<br />
 */
@interface NSRunLoop(mingw32)
/**
 * Adds a target to the loop in the specified mode for the 
 * win32 messages.<br />
 * Only a target+selector is added in one mode. Successive 
 * calls overwrite the previous.<br />
 */
- (void) addMsgTarget: (id)target
           withMethod: (SEL)selector
              forMode: (NSString*)mode;
/**
 * Delete the target of the loop in the specified mode for the 
 * win32 messages.<br />
 */
- (void) removeMsgForMode: (NSString*)mode;
@end
#endif
#endif /*__NSRunLoop_h_GNUSTEP_BASE_INCLUDE */
