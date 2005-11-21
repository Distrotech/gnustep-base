/** Interface for abstract superclass NSPort for use with NSConnection
   Copyright (C) 1997,2002 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.

  AutogsdocSource: NSPort.m
  AutogsdocSource: NSSocketPort.m
  AutogsdocSource: NSMessagePort.m
*/

#ifndef __NSPort_h_GNUSTEP_BASE_INCLUDE
#define __NSPort_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>
#include	<Foundation/NSMapTable.h>

#if	defined(__MINGW32__)
#include	<winsock2.h>
#include	<wininet.h>
#else
#include	<sys/socket.h>
#define	SOCKET	int
#endif

@class	NSMutableArray;
@class	NSConnection;
@class	NSDate;
@class	NSRunLoop;
@class	NSString;
@class	NSPortMessage;
@class	NSHost;

@interface NSObject(NSPortDelegateMethods)
/**
 * Subclasses of NSPort send this message to their delegate on receipt
 * of a port message.
 */
- (void) handlePortMessage: (NSPortMessage*)aMessage;
@end

/**
 *  Exception raised by [NSPort], [NSConnection], and friends if sufficient
 *  time elapses while waiting for a response, or if the receiving port is
 *  invalidated before a request can be received.  See
 *  [NSConnection-setReplyTimeout:].
 */
GS_EXPORT NSString * const NSPortTimeoutException; /* OPENSTEP */

/**
 * <p><code>NSPort</code> is an abstract class defining interfaces underlying
 * communications in the distributed objects framework.  Each side of a
 * connection will have an <code>NSPort</code> object, responsible for sending
 * and receiving [NSPortMessage]s, which are then passed to delegates when
 * received.  The <code>NSPort</code> must be added to the [NSRunLoop] as an
 * input source.</p>
 *
 * <p>This class also implements the functionality of the
 * <code><em>NSMachPort</em></code> class on OS X.</p>
 */
@interface NSPort : NSObject <NSCoding, NSCopying>
{
  BOOL		_is_valid;
  id		_delegate;
}

/**
 * Basic constructor returns object capable of send and receive.<br />
 * By default, the port returned is an instance of [NSMessagePort]
 * capable only of host-local communication.  However, the
 * <code>NSPortIsMessagePort</code> user default may be set to NO to
 * change the behavior so that the returned value is an instance of
 * the [NSSocketPort] class.
 */
+ (NSPort*) port;

/**
 * NSMachPort compatibility method.
 */
+ (NSPort*) portWithMachPort: (int)machPort;

/**
 *  Returns the object that received messages will be passed off to.
 */
- (id) delegate;

/**
 *  Sets the object that received messages will be passed off to.
 */
- (void) setDelegate: (id)anObject;

/**
 * Basic initializer sets up object capable of send and receive.
 * See +port for more details.
 */
- (id) init;

/**
 * NSMachPort compatibility method.
 */
- (id) initWithMachPort: (int)machPort;

/**
 * NSMachPort compatibility.
 */
- (int) machPort;

/**
 * Mark port as invalid, deregister with listeners and cease further network
 * operations.  Subclasses should override and call super.
 */
- (void) invalidate;

/**
 * Returns whether port has been marked invalid.
 */
- (BOOL) isValid;

#ifndef	STRICT_OPENSTEP
/**
 * Adds to run loop as input source to be notified for input in given mode.
 * This method is for use by subclasses.
 */
- (void) addConnection: (NSConnection*)aConnection
	     toRunLoop: (NSRunLoop*)aLoop
	       forMode: (NSString*)aMode;

/**
 * Removes from run loop as input source to be notified for input in given mode.
 * This method is for use by subclasses.
 */
- (void) removeConnection: (NSConnection*)aConnection
	      fromRunLoop: (NSRunLoop*)aLoop
		  forMode: (NSString*)aMode;

/**
 * Returns amount of space used for header info at beginning of messages.
 * Subclasses should override (this implementation returns 0).
 */
- (unsigned) reservedSpaceLength;

/**
 * Internal method for sending message, for use by subclasses.
 */
- (BOOL) sendBeforeDate: (NSDate*)when
		  msgid: (int)msgid
	     components: (NSMutableArray*)components
		   from: (NSPort*)receivingPort
	       reserved: (unsigned)length;

/**
 * Internal method for sending message, for use by subclasses.
 */
- (BOOL) sendBeforeDate: (NSDate*)when
	     components: (NSMutableArray*)components
		   from: (NSPort*)receivingPort
	       reserved: (unsigned)length;
#endif
@end

/**
 *  Notification posted when an instance of [NSPort] or a subclass becomes
 *  invalid.
 */
GS_EXPORT NSString* const NSPortDidBecomeInvalidNotification;

#define	PortBecameInvalidNotification NSPortDidBecomeInvalidNotification

#ifndef	STRICT_OPENSTEP

/**
 * Native socket type.
 */
typedef SOCKET NSSocketNativeHandle;

/**
 *  <p>An [NSPort] implementation for network object communications based on
 *  BSD sockets.  Can be used for interthread/interprocess
 *  communications between same or different hosts (though on same host
 *  [NSMessagePort] will be more efficient).</p>
 *
 *  <p>Note that this class is incompatible with the latest OS X version.</p>
 */
@interface NSSocketPort : NSPort <GCFinalization>
{
  NSRecursiveLock	*myLock;
  NSHost		*host;		/* OpenStep host for this port.	*/
  NSString		*address;	/* Forced internet address.	*/
  gsu16			portNum;	/* TCP port in host byte order.	*/
  SOCKET		listener;
  NSMapTable		*handles;	/* Handles indexed by socket.	*/
#if	defined(__MINGW32__)
  WSAEVENT              eventListener;
  NSMapTable            *events;
#endif
}

/**
 * Look up and return an existing <code>NSSocketPort</code> given a host and
 * number, or return nil if one has not been created.
 */
+ (NSSocketPort*) existingPortWithNumber: (gsu16)number
				  onHost: (NSHost*)aHost;

/**
 * This is the preferred initialisation method for <code>NSSocketPort</code>.
 * <br/>
 * number should be a TCP/IP port number or may be zero for a port on
 * the local host.<br/>
 * aHost should be the host for the port or may be nil for the local
 * host.<br/>
 * addr is the IP address that MUST be used for this port - if it is nil
 * then, for the local host, the port uses ALL IP addresses, and for a
 * remote host, the port will use the first address that works.<br/>
 * shouldListen specifies whether to listen on the port initially.
 */
+ (NSSocketPort*) portWithNumber: (gsu16)number
			  onHost: (NSHost*)aHost
		    forceAddress: (NSString*)addr
			listener: (BOOL)shouldListen;

/**
 *  Returns IP address of underlying socket.
 */
- (NSString*) address;

/**
 * This is a callback method used by the NSRunLoop class to determine which
 * descriptors to watch for the port.
 */
- (void) getFds: (int*)fds count: (int*)count;

/**
 *  Delegates processing of a message.
 */
- (void) handlePortMessage: (NSPortMessage*)m;

/**
 * Returns host that the underlying socket is connected to.
 */
- (NSHost*) host;

/**
 *  Returns port number of underlying socket.
 */
- (gsu16) portNumber;

// This is the OS X interface
/*
{
  NSSocketNativeHandle _socket;
  int _protocolFamily;
  int _socketType;
  int _protocol;
  NSData *_remoteAddrData;
}
- (id) init;
- (id) initWithTCPPort: (unsigned short)portNumber;
- (id) initWithProtocolFamily: (int)family
                   socketType: (int)type
                     protocol: (int)protocol
                      address: (NSData *)addrData;
- (id) initWithProtocolFamily: (int)family
                   socketType: (int)type
                     protocol: (int)protocol
                       socket: (NSSocketNativeHandle)socket;
- (id) initRemoteWithTCPPort: (unsigned short)portNumber
                        host: (NSString *)hostname;
- (id) initRemoteWithProtocolFamily: (int)family
                         socketType: (int)type
                           protocol: (int)protocol
                            address: (NSData *)addrData;

- (NSData *) address;
- (int) protocol;
- (int) protocolFamily;
- (NSSocketNativeHandle) socket;
- (int) socketType;
*/

@end


/**
 *  An [NSPort] implementation for network object communications
 *  which can be used for interthread/interprocess communications
 *  on the same host, but not between different hosts.
 */
@interface NSMessagePort : NSPort <GCFinalization>
{
  void	*_internal;
}
@end


#endif


#endif /* __NSPort_h_GNUSTEP_BASE_INCLUDE */

