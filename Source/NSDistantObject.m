/* Implementation for GNU Objective-C version of NSDistantObject
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Based on code by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
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
#include <Foundation/DistributedObjects.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSException.h>

static int	debug_proxy = 0;
static Class	placeHolder = 0;
static Class	distantObjectClass = 0;



/*
 *	The GSDistantObjectPlaceHolder class is simply used as a placeholder
 *	for an NSDistantObject so we can manage efficient allocation and
 *	initialisation - in most cases when we ask for an NSDistantObject
 *	instance, we will get a pre-existing one, so we don't want to go
 *	allocating the memory for a new instance unless absolutely necessary.
 */
@interface	GSDistantObjectPlaceHolder
+ (id) initWithLocal: (id)anObject connection: (NSConnection*)aConnection;
+ (id) initWithTarget: (unsigned)target connection: (NSConnection*)aConnection;
+ (void) autorelease;
+ (void) release;
+ (id) retain;
@end

@implementation	GSDistantObjectPlaceHolder

+ (void) autorelease
{
}

+ (void) release
{
}

+ (id) retain
{
  return self;
}

+ (void) initialize
{
  if (self == [GSDistantObjectPlaceHolder class])
    {
      distantObjectClass = [NSDistantObject class];
    }
}

+ (id) initWithLocal: (id)anObject connection: (NSConnection*)aConnection
{
  NSDistantObject	*proxy;

  NSAssert([aConnection isValid], NSInternalInconsistencyException);

  /*
   *	If there already is a local proxy for this target/connection
   *	combination, don't create a new one, just return the old one.
   */
  if ((proxy = [aConnection localForObject: anObject]))
    {
      return [proxy retain];
    }

  proxy = (NSDistantObject*)NSAllocateObject(distantObjectClass,
	0, NSDefaultMallocZone());
  return [proxy initWithLocal: anObject connection: aConnection];
}

+ (id) initWithTarget: (unsigned)target connection: (NSConnection*)aConnection
{
  NSDistantObject	*proxy;

  NSAssert([aConnection isValid], NSInternalInconsistencyException);

  /*
   *	If there already is a local proxy for this target/connection
   *	combination, don't create a new one, just return the old one.
   */
  if ((proxy = [aConnection proxyForTarget: target]))
    {
      return [proxy retain];
    }

  proxy = (NSDistantObject*)NSAllocateObject(distantObjectClass,
	0, NSDefaultMallocZone());
  return [proxy initWithTarget: target connection: aConnection];
}
@end

@interface NSDistantObject (Debug)
+ (void) setDebug: (int)val;
@end

@implementation NSDistantObject (Debug)
+ (void) setDebug: (int)val
{
  debug_proxy = val;
}
@end

@implementation NSDistantObject

/* This is the proxy tag; it indicates where the local object is,
   and determines whether the reply port to the Connection-where-the-
   proxy-is-local needs to encoded/decoded or not. */
enum
{
  PROXY_LOCAL_FOR_RECEIVER = 0,
  PROXY_LOCAL_FOR_SENDER,
  PROXY_REMOTE_FOR_BOTH
};

+ (void) initialize
{
  if (self == [NSDistantObject class])
    {
      placeHolder = [GSDistantObjectPlaceHolder class];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  return placeHolder;
}

+ (NSDistantObject*) proxyWithLocal: (id)anObject
			 connection: (NSConnection*)aConnection
{
  return [[placeHolder initWithLocal: anObject
			  connection: aConnection] autorelease];
}

+ (NSDistantObject*) proxyWithTarget: (unsigned)anObject
			  connection: (NSConnection*)aConnection
{
  return [[placeHolder initWithTarget: anObject
			   connection: aConnection] autorelease];
}

- (NSConnection*) connectionForProxy
{
  return _connection;
}

- (void) dealloc
{
  [self gcFinalize];
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aRmc
{
  unsigned	proxy_target;
  gsu8		proxy_tag;
  NSConnection	*encoder_connection;

  if ([aRmc class] != [PortEncoder class])
    [NSException raise: NSGenericException
		format: @"NSDistantObject objects only "
			@"encode with PortEncoder class"];

  encoder_connection = [(NSPortCoder*)aRmc connection];
  NSAssert(encoder_connection, NSInternalInconsistencyException);
  if (![encoder_connection isValid])
    [NSException
	    raise: NSGenericException
	   format: @"Trying to encode to an invalid Connection.\n"
      @"You should request NSConnectionDidDieNotification's and\n"
      @"release all references to the proxy's of invalid Connections."];

  proxy_target = _handle;

  if (encoder_connection == _connection)
    {
      if (_object)
	{
	  /*
	   *	This proxy is a local to us, remote to other side.
	   */
	  proxy_tag = PROXY_LOCAL_FOR_SENDER;

	  if (debug_proxy)
	    NSLog(@"Sending a proxy, will be remote 0x%x connection 0x%x\n",
			proxy_target, (gsaddr)_connection);

	  [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
				at: &proxy_tag
			  withName: @"Proxy is local for sender"];

	  [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
				at: &proxy_target
			  withName: @"Proxy target"];
	}
      else
	{
	  /*
	   *	This proxy is a local object on the other side.
	   */
	  proxy_tag = PROXY_LOCAL_FOR_RECEIVER;

	  if (debug_proxy)
	    NSLog(@"Sending a proxy, will be local 0x%x connection 0x%x\n",
			proxy_target, (gsaddr)_connection);

	  [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
				at: &proxy_tag
			  withName: @"Proxy is local for receiver"];

	  [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
				at: &proxy_target
			  withName: @"Proxy target"];
	}
    }
  else
    {
      /*
       *	This proxy will still be remote on the other side
       */
      NSPort		*proxy_connection_out_port = [_connection sendPort];
      NSDistantObject	*localProxy;

      NSAssert(proxy_connection_out_port,
	NSInternalInconsistencyException);
      NSAssert([proxy_connection_out_port isValid],
	NSInternalInconsistencyException);
      NSAssert(proxy_connection_out_port != [encoder_connection sendPort],
	NSInternalInconsistencyException);

      proxy_tag = PROXY_REMOTE_FOR_BOTH;

      /*
       *	Get a proxy to refer to self - we send this to the other
       *	side so we will be retained until the other side has
       *	obtained a proxy to the original object via a connection
       *	to the original vendor.
       */
      localProxy = [NSDistantObject proxyWithLocal: self
					connection: encoder_connection];

      if (debug_proxy)
	NSLog(@"Sending triangle-connection proxy 0x%x "
	      @"proxy-conn 0x%x to-proxy 0x%x to-conn 0x%x\n",
		localProxy->_handle, (gsaddr)localProxy->_connection,
		proxy_target, (gsaddr)_connection);

      /*
       *	It's remote here, so we need to tell other side where to form
       *	triangle connection to
       */
      [aRmc encodeValueOfCType: @encode(typeof(proxy_tag))
			    at: &proxy_tag
		      withName: @"Proxy remote for both sender and receiver"];

      [aRmc encodeValueOfCType: @encode(typeof(localProxy->_handle))
			    at: &localProxy->_handle
		      withName: @"Intermediary target"];

      [aRmc encodeValueOfCType: @encode(typeof(proxy_target))
			    at: &proxy_target
		      withName: @"Original target"];

      [aRmc encodeBycopyObject: proxy_connection_out_port
		      withName: @"Original port"];
    }
}

/*
 *	This method needs to be implemented to actually do anything.
 */
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  [NSException raise: NSInvalidArgumentException
	      format: @"Not yet implemented '%s'", sel_get_name(_cmd)];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  gsu8		proxy_tag;
  unsigned	target;
  id		decoder_connection;

  if ([aCoder class] != [PortDecoder class])
    {
      [self release];
      [NSException raise: NSGenericException
		  format: @"NSDistantObject objects only decode with "
			  @"PortDecoder class"];
    }

  decoder_connection = [(NSPortCoder*)aCoder connection];
  NSAssert(decoder_connection, NSInternalInconsistencyException);

  /* First get the tag, so we know what values need to be decoded. */
  [aCoder decodeValueOfCType: @encode(typeof(proxy_tag))
			  at: &proxy_tag
		    withName: NULL];

  switch (proxy_tag)
    {
      case PROXY_LOCAL_FOR_RECEIVER:
	/*
	 *	This was a proxy on the other side of the connection, but
	 *	here it's local.
	 *	Lookup the target handle to ensure that it exists here.
	 *	Return a retained copy of the local target object.
	 */
	[aCoder decodeValueOfCType: @encode(typeof(target))
				at: &target
			  withName: NULL];

        if (debug_proxy)
	  NSLog(@"Receiving a proxy for local object 0x%x "
		@"connection 0x%x\n", target, (gsaddr)decoder_connection);

        if (![[decoder_connection class] includesLocalTarget: target])
	  {
	    [self release];
	    [NSException raise: @"ProxyDecodedBadTarget"
			format: @"No local object with given target (0x%x)",
				target];
	  }
	else
	  {
	    NSDistantObject	*o;

	    o = [decoder_connection includesLocalTarget: target];
	    if (debug_proxy)
	      {
		NSLog(@"Local object is 0x%x (0x%x)\n",
		  (gsaddr)o, (gsaddr)o ? o->_object : 0);
	      }
	    [self release];
	    return o ? [o->_object retain] : nil;
	  }

      case PROXY_LOCAL_FOR_SENDER:
        /*
	 *	This was a local object on the other side of the connection,
	 *	but here it's a proxy object.  Get the target address, and
	 *	send [NSDistantObject +proxyWithTarget:connection:]; this will
	 *	return the proxy object we already created for this target, or
	 *	create a new proxy object if necessary.
	 */
	[aCoder decodeValueOfCType: @encode(typeof(target))
				at: &target
			  withName: NULL];
	if (debug_proxy)
	  NSLog(@"Receiving a proxy, was local 0x%x connection 0x%x\n",
		  target, (gsaddr)decoder_connection);
        [self release];
	return [[NSDistantObject proxyWithTarget: target
				      connection: decoder_connection] retain];

      case PROXY_REMOTE_FOR_BOTH:
        /*
	 *	This was a proxy on the other side of the connection, and it
	 *	will be a proxy on this side too; that is, the local version
	 *	of this object is not on this host, not on the host the
	 *	NSPortCoder is connected to, but on a *third* host.
	 *	This is why I call this a "triangle connection".  In addition
	 *	to decoding the target, we decode the OutPort object that we
	 *	will use to talk directly to this third host.  We send
	 *	[NSConnection +newForInPort:outPort:ancestorConnection:]; this
	 *	will either return the connection already created for this
	 *	inPort/outPort pair, or create a new connection if necessary.
	 */
	{
	  NSDistantObject	*result;
	  NSConnection		*proxy_connection;
	  NSPort		*proxy_connection_out_port = nil;
	  unsigned		intermediary;

	  /*
	   *	There is an object on the intermediary host that is keeping
	   *	that hosts proxy for the original object retained, thus
	   *	ensuring that the original is not released.  We create a
	   *	proxy for that intermediate proxy.  When we release this
	   *	proxy, the intermediary will be free to release it's proxy
	   *	and the original can then be released.  Of course, by that
	   *	time we will have obtained our own proxy for the original
	   *	object ...
	   */
	  [aCoder decodeValueOfCType: @encode(typeof(intermediary))
				  at: &intermediary
			    withName: NULL];
	  [NSDistantObject proxyWithTarget: intermediary
				connection: decoder_connection];

	  /*
	   *	Now we get the target number and port for the orignal object
	   *	and (if necessary) get the originating process to retain the
	   *	object for us.
	   */
	  [aCoder decodeValueOfCType: @encode(typeof(target))
				  at: &target
			    withName: NULL];

	  [aCoder decodeObjectAt: &proxy_connection_out_port
		        withName: NULL];

	  NSAssert(proxy_connection_out_port, NSInternalInconsistencyException);
	  /*
	   #	If there already exists a connection for talking to the
	   *	out port, we use that one rather than creating a new one from
	   *	our listening port. 
	   *
	   *	First we try for a connection from our receive port,
	   *	Then we try any connection to the send port
	   *	Finally we resort to creating a new connection - we don't
	   *	release the newly created connection - it will get released
	   *	automatically when no proxies are left on it.
	   */
	  proxy_connection = [[decoder_connection class]
				connectionByInPort:
					[decoder_connection receivePort]
				outPort:
					proxy_connection_out_port];
	  if (proxy_connection == nil)
	    {
	      proxy_connection = [[decoder_connection class]
			      connectionByOutPort: proxy_connection_out_port];
	    }
	  if (proxy_connection == nil)
	    {
	      proxy_connection = [[decoder_connection class]
			     newForInPort: [decoder_connection receivePort]
				  outPort: proxy_connection_out_port
		       ancestorConnection: decoder_connection];
	      [proxy_connection setNotOwned];
	      [proxy_connection autorelease];
	    }

	  if (debug_proxy)
	    NSLog(@"Receiving a triangle-connection proxy 0x%x "
		  @"connection 0x%x\n", target, (gsaddr)proxy_connection);

	  NSAssert(proxy_connection != decoder_connection,
	    NSInternalInconsistencyException);
	  NSAssert([proxy_connection isValid],
	    NSInternalInconsistencyException);

	  /*
	   *	If we don't already have a proxy for the object on the
	   *	remote system, we must tell the other end to retain its
	   *	local object for our use.
	   */
	  if ([proxy_connection includesProxyForTarget: target] == NO)
	    [proxy_connection retainTarget: target];

	  result = [[NSDistantObject proxyWithTarget: target
				          connection: proxy_connection] retain];
	  [self release];

	  /*
	   *	Finally - we have a proxy via a direct connection to the
	   *	originating server.  We have also created a proxy to an
	   *	intermediate object - but this proxy has not been retained
	   *	and will therefore go away when the current autorelease
	   *	pool is destroyed.
	   */
	  return result;
        }

    default:
      /* xxx This should be something different than NSGenericException. */
      [self release];
      [NSException raise: NSGenericException
		  format: @"Bad proxy tag"];
    }
  /* Not reached. */
  return nil;
}

- (id) initWithLocal: (id)anObject connection: (NSConnection*)aConnection
{
  NSDistantObject	*new_proxy;

  NSAssert([aConnection isValid], NSInternalInconsistencyException);

  /*
   *	If there already is a local proxy for this target/connection
   *	combination, don't create a new one, just return the old one.
   */
  if ((new_proxy = [aConnection localForObject: anObject]))
    {
      [self release];
      return [new_proxy retain];
    }

  /*
   *	We don't need to retain the oibject here - the connection
   *	will retain the proxies local object if necessary (and release it
   *	when all proxies referring to it have been released).
   */
  _object = anObject;

  /*
   *	We register this proxy with the connection using it.
   */
  _connection = [aConnection retain];
  [_connection addLocalObject: self];

  if (debug_proxy)
    NSLog(@"Created new local=0x%x object 0x%x target 0x%x connection 0x%x\n",
	   (gsaddr)self, (gsaddr)_object, _handle, (gsaddr)_connection);

  return self;
}

- (id) initWithTarget: (unsigned)target connection: (NSConnection*)aConnection
{
  NSDistantObject	*new_proxy;

  NSAssert([aConnection isValid], NSInternalInconsistencyException);

  /*
   *	If there already is a proxy for this target/connection combination,
   *	don't create a new one, just return the old one.
   */
  if ((new_proxy = [aConnection proxyForTarget: target]))
    {
      [self release];
      return [new_proxy retain];
    }

  _object = nil;
  _handle = target;

  /*
   *	We retain our connection so it can't disappear while the app
   *	may want to use it.
   */
  _connection = [aConnection retain];

  /*
   *	We register this object with the connection using it.
   */
  [_connection addProxy: self];

  if (debug_proxy)
      NSLog(@"Created new proxy=0x%x target 0x%x connection 0x%x\n",
	 (gsaddr)self, _handle, (gsaddr)_connection);

  return self;
}

- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector
{
  if (_object)
    {
      return [_object methodSignatureForSelector: aSelector];
    }
  else
    {
      if (_protocol)
	{
	  const char	*types = 0;

	  struct objc_method_description* mth;

	  mth = [_protocol descriptionForInstanceMethod: aSelector];
	  if (mth == 0)
	    {
	      mth = [_protocol descriptionForClassMethod: aSelector];
	    }
	  if (mth != 0)
	    {
	      types = mth->types;
	    }
	  if (types == 0)
	    {
	      return nil;
	    }
	  return [NSMethodSignature signatureWithObjCTypes: types];
	}
      else
	{
	  arglist_t	args;

	  /*
	   *	No protocol - so try forwarding the message.
	   */
	  args = __builtin_apply_args();
	  __builtin_return([self forward: _cmd : args]);
	}
    }
}

- (void) setProtocolForProxy: (Protocol*)aProtocol
{
  _protocol = aProtocol;
}

@end

@implementation NSDistantObject(GNUstepExtensions)

- (void) gcFinalize
{
  if (_connection)
    {
      if (debug_proxy > 3)
	NSLog(@"retain count for connection (0x%x) is now %u\n",
		(gsaddr)_connection, [_connection retainCount]);
      /*
       * A proxy for local object does not retain it's target - the
       * NSConnection class does that for us - so we need not release it.
       * For a local object the connection also retains this proxy, so we
       * can't be deallocated unless we are already removed from the
       * connection.
       *
       * A proxy retains it's connection so that the connection will
       * continue to exist as long as there is a something to use it.
       * So we release our reference to the connection here just as soon
       * as we have removed ourself from the connection.
       */
      if (_object == nil)
	[_connection removeProxy: self];
      [_connection release];
    }
}

- (id) awakeAfterUsingCoder: (NSCoder*)aDecoder
{
  return self;
}

static inline BOOL class_is_kind_of (Class self, Class aClassObject)
{
  Class class;

  for (class = self; class!=Nil; class = class_get_super_class(class))
    if (class==aClassObject)
      return YES;
  return NO;
}



- (const char *) selectorTypeForProxy: (SEL)selector
{
#if NeXT_runtime
  {
    elt e;
    const char *t;
    e = coll_hash_value_for_key(_method_types, selector);
    t = e.char_ptr_u;
    if (!t)
      {
	/* This isn't what we want, unless the remote machine has
	   the same architecture as us. */
	t = [connection _typeForSelector:selector remoteTarget:target];
	coll_hash_add(&_method_types, (void*)selector, t);
      }
    return t;
  }
#else /* NeXT_runtime */
  return sel_get_type (selector);
#endif
}

- (id) forward: (SEL)aSel :(arglist_t)frame
{
  if (debug_proxy)
    NSLog(@"NSDistantObject forwarding %s\n", sel_get_name(aSel));

  if (![_connection isValid])
    [NSException
	   raise: NSGenericException
	  format: @"Trying to send message to an invalid Proxy.\n"
      @"You should request NSConnectionDidDieNotification's and\n"
      @"release all references to the proxy's of invalid Connections."];

  return [_connection forwardForProxy: self
			     selector: aSel
			     argFrame: frame];
}

- (Class) classForCoder
{
  return object_get_class (self);
}

- (Class) classForPortCoder
{
  return object_get_class (self);
}

- (id) replacementObjectForCoder: (NSCoder*)aCoder
{
  return self;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}
@end


@implementation NSObject (NSDistantObject)
- (const char *) selectorTypeForProxy: (SEL)selector
{
#if NeXT_runtime
  {
    Method m = class_get_instance_method(isa, selector);
    if (m)
      return m->method_types;
    else
      return NULL;
  }
#else
  return sel_get_type (selector);
#endif
}

@end

@implementation Protocol (DistributedObjectsCoding)

- (Class) classForPortCoder
{
  return [self class];
}

- replacementObjectForPortCoder: (NSPortCoder*)aRmc;
{
  if ([aRmc isBycopy])
    return self;
  else
    return [NSDistantObject proxyWithLocal: self
				connection: [aRmc connection]];
}

@end

