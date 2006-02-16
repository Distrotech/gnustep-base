/** Interface for NSStream for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Derek Zhou <derekzhou@gmail.com>
   Date: 2006

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */

#ifndef __NSStream_h_GNUSTEP_BASE_INCLUDE
#define __NSStream_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#if OS_API_VERSION(100400,GS_API_LATEST) && GS_API_VERSION(010200,GS_API_LATEST)

typedef enum {   
  NSStreamStatusNotOpen = 0,   
  NSStreamStatusOpening = 1,
  NSStreamStatusOpen = 2,   
  NSStreamStatusReading = 3,   
  NSStreamStatusWriting = 4,   
  NSStreamStatusAtEnd = 5,   
  NSStreamStatusClosed = 6,   
  NSStreamStatusError = 7
} NSStreamStatus;

typedef enum {   
  NSStreamEventNone = 0,    
  NSStreamEventOpenCompleted = 1,    
  NSStreamEventHasBytesAvailable = 2,
  NSStreamEventHasSpaceAvailable = 4,    
  NSStreamEventErrorOccurred = 8,    
  NSStreamEventEndEncountered = 16
} NSStreamEvent;

@class NSError;
@class NSHost;
@class NSInputStream;
@class NSOutputStream;
@class NSString;
@class NSRunLoop;

/**
 * NSStream is an abstract class for objects representing streams. 
 */
@interface NSStream : NSObject

/**
 * Creates and returns by reference an NSInputStream object and NSOutputStream 
 * object for a socket connection with the specified port on host.
 */
+ (void) getStreamsToHost: (NSHost *)host 
                     port: (int)port 
              inputStream: (NSInputStream **)inputStream 
             outputStream: (NSOutputStream **)outputStream;

/**
 * Closes the receiver.
 */
- (void) close;

/**
 * Returns the receiver's delegate.
 */
- (id) delegate;

/**
 * Opens the receiving stream.
 */
- (void) open;

/**
 * Returns the receiver's property for the specified key.
 */
- (id) propertyForKey: (NSString *)key;

/**
 * Removes the receiver from the NSRunLoop specified by aRunLoop
 * running in the mode.
 */
- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode;

/**
 * Schedules the receiver on aRunLoop using the specified mode.
 */
- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode;

/**
 * Sets the receiver's delegate.
 */
- (void) setDelegate: (id)delegate;

/**
 * Sets the value of the property specified by key to property, returns YES 
 * if the key-value pair are accepted by the receiver.
 */
- (BOOL) setProperty: (id)property forKey: (NSString *)key;

/**
 * Returns an NSError object representing the stream error, or nil if no error 
 * has been encountered.
 */
- (NSError *) streamError;

/**
 * Returns the receiver's status.
 */
- (NSStreamStatus) streamStatus;

@end

@class NSData;

/**
 * NSInputStream is a subclass of NSStream that provides read-only
 * stream functionality.
 */
@interface NSInputStream : NSStream

/**
 * Creates and returns an initialized NSInputStream object
 * for reading from data.
 */
+ (id) inputStreamWithData: (NSData *)data;

/**
 * Creates and returns an initialized NSInputStream object that reads data from 
 * the file at the specified path.
 */
+ (id) inputStreamWithFileAtPath: (NSString *)path;
 
/**
 * Returns a pointer to the read buffer in buffer and, by reference, the number 
 * of bytes available in len.
 */
- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len;

/**
 * Returns YES if the receiver has bytes available to read.
 * The receiver may also return YES if a read must be attempted
 * in order to determine the availability of bytes.
 */
- (BOOL) hasBytesAvailable;

/**
 * Returns an initialized NSInputStream object for reading from data.
 */ 
- (id) initWithData: (NSData *)data;

/**
 * Returns an initialized NSInputStream object for reading from the file at the 
 * specified path.
 */
- (id) initWithFileAtPath: (NSString *)path;

/**
 * Reads up to len bytes into buffer, returning the actual number of bytes read.
 */
- (int) read: (uint8_t *)buffer maxLength: (unsigned int)len;

@end

/**
 * NSOutputStream is a subclass of NSStream that provides
 * write-only stream functionality.
 */
@interface NSOutputStream : NSStream

/**
 * Creates and returns an initialized NSOutputStream object
 * that can write to buffer, up to a maximum of capacity bytes.
 */
+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity;

/**
 * Creates and returns an initialized NSOutputStream object
 * for writing to the file specified by path.
 */
+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend;

/**
 * Creates and returns an initialized NSOutputStream object
 * that will write stream data to memory.
 */
+ (id) outputStreamToMemory;

/**
 * Returns YES if the receiver can be written to,
 * or if a write must be attempted 
 * in order to determine if space is available.
 */
- (BOOL) hasSpaceAvailable;

/**
 * Returns an initialized NSOutputStream object that can write to buffer, 
 * up to a maximum of capacity bytes.
 */
- (id) initToBuffer: (uint8_t *)buffer capacity: (unsigned int)capacity;

/**
 * Returns an initialized NSOutputStream object for writing to the file
 * specified by path.<br />
 * If shouldAppend is YES, newly written data will be appended to any 
 * existing file contents.
 */
- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend;

/**
 * Returns an initialized NSOutputStream object that will write to memory.
 */
- (id) initToMemory;

/**
 * Writes the contents of buffer, up to a maximum of len bytes,
 * to the receiver.
 */
- (int) write: (const uint8_t *)buffer maxLength: (unsigned int)len;

@end

/**
 * the additional interface defined for gnustep
 */
@interface NSStream (GNUstepExtensions)

/**
 * Creates and returns by reference an NSInputStream object and
 * NSOutputStream object for a local socket connection with the
 * specified path. To use them you need to open them and wait
 * on the NSStreamEventOpenCompleted event on one of them
 */
+ (void) getLocalStreamsToPath: (NSString *)path 
		   inputStream: (NSInputStream **)inputStream 
		  outputStream: (NSOutputStream **)outputStream;
/**
 * Creates and returns by reference an NSInputStream object and NSOutputStream 
 * object for a anonymous local socket. Although you still need to open them, 
 * the open will be instantanious, and no NSStreamEventOpenCompleted event 
 * will be delivered.
 */
+ (void) pipeWithInputStream: (NSInputStream **)inputStream 
                outputStream: (NSOutputStream **)outputStream;
@end

/**
 * GSServerStream is a subclass of NSStream that encapsulate a "server" stream;
 * that is a stream that binds to a socket and accepts incoming connections
 */
@interface GSServerStream : NSStream
/**
 * Createe a ip (ipv6) server stream
 */
+ (id) serverStreamToAddr: (NSString*)addr port: (int)port;
/**
 * Create a local (unix domain) server stream
 */
+ (id) serverStreamToAddr: (NSString*)addr;
/**
 * This is the method that accepts a connection and generates two streams
 * as the server side inputStream and OutputStream.
 * Although you still need to open them, the open will be
 * instantanious, and no NSStreamEventOpenCompleted event will be delivered.
 */
- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream;

/**
 * the designated initializer for a ip (ipv6) server stream
 */
- (id) initToAddr: (NSString*)addr port: (int)port;
/**
 * the designated initializer for a local (unix domain) server stream
 */
- (id) initToAddr: (NSString*)addr;

@end

@protocol GSStreamListener
/**
 * The delegate receives this message when streamEvent
 * has occurred on theStream.
 */
- (void) stream: (NSStream *)theStream handleEvent: (NSStreamEvent)streamEvent;
@end

GS_EXPORT NSString * const NSStreamDataWrittenToMemoryStreamKey;
GS_EXPORT NSString * const NSStreamFileCurrentOffsetKey;

GS_EXPORT NSString * const NSStreamSocketSecurityLevelKey;
GS_EXPORT NSString * const NSStreamSocketSecurityLevelNone;
GS_EXPORT NSString * const NSStreamSocketSecurityLevelSSLv2;
GS_EXPORT NSString * const NSStreamSocketSecurityLevelSSLv3;
GS_EXPORT NSString * const NSStreamSocketSecurityLevelTLSv1;
GS_EXPORT NSString * const NSStreamSocketSecurityLevelNegotiatedSSL;
GS_EXPORT NSString * const NSStreamSocketSSLErrorDomain;
GS_EXPORT NSString * const NSStreamSOCKSErrorDomain;
GS_EXPORT NSString * const NSStreamSOCKSProxyConfigurationKey;
GS_EXPORT NSString * const NSStreamSOCKSProxyHostKey;
GS_EXPORT NSString * const NSStreamSOCKSProxyPasswordKey;
GS_EXPORT NSString * const NSStreamSOCKSProxyPortKey;
GS_EXPORT NSString * const NSStreamSOCKSProxyUserKey;
GS_EXPORT NSString * const NSStreamSOCKSProxyVersion4;
GS_EXPORT NSString * const NSStreamSOCKSProxyVersion5;
GS_EXPORT NSString * const NSStreamSOCKSProxyVersionKey;


#endif

#endif /* __NSStream_h_GNUSTEP_BASE_INCLUDE */
