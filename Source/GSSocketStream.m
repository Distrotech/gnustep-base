/** Implementation for GSSocketStream for GNUStep
   Copyright (C) 2006-2008 Free Software Foundation, Inc.

   Written by:  Derek Zhou <derekzhou@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2006

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

#include "config.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSHost.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSValue.h>

#import "GSPrivate.h"
#import "GSStream.h"
#import "GSSocketStream.h"

#ifndef SHUT_RD
# ifdef  SD_RECEIVE
#   define SHUT_RD      SD_RECEIVE
#   define SHUT_WR      SD_SEND
#   define SHUT_RDWR    SD_BOTH
# else
#   define SHUT_RD      0
#   define SHUT_WR      1
#   define SHUT_RDWR    2
# endif
#endif

#ifdef _WIN32
extern const char *inet_ntop(int, const void *, char *, size_t);
extern int inet_pton(int , const char *, void *);
#endif

unsigned
GSPrivateSockaddrLength(struct sockaddr *addr)
{
  switch (addr->sa_family) {
    case AF_INET:       return sizeof(struct sockaddr_in);
#ifdef	AF_INET6
    case AF_INET6:      return sizeof(struct sockaddr_in6);
#endif
#ifndef	__MINGW32__
    case AF_LOCAL:       return sizeof(struct sockaddr_un);
#endif
    default:            return 0;
  }
}


/** The GSStreamHandler abstract class defines the methods used to
 * implement a handler object for a pair of streams.
 * The idea is that the handler is installed once the connection is
 * open, and a handshake is initiated.  During the handshake process
 * all stream events are sent to the handler rather than to the
 * stream delegate (the streams know to do this because the -handshake
 * method returns YES to tell them so).
 * While a handler is installed, the -read:maxLength: and -write:maxLength:
 * methods of the handle rare called instead of those of the streams (and
 * the handler may perform I/O using the streams by calling the private
 * -_read:maxLength: and _write:maxLength: methods instead of the public
 * methods).
 */
@interface      GSStreamHandler : NSObject
{
  GSSocketInputStream   *istream;	// Not retained
  GSSocketOutputStream  *ostream;       // Not retained
  BOOL                  initialised;
  BOOL                  handshake;
  BOOL                  active;
}
+ (void) tryInput: (GSSocketInputStream*)i output: (GSSocketOutputStream*)o;
- (id) initWithInput: (GSSocketInputStream*)i
              output: (GSSocketOutputStream*)o;
- (GSSocketInputStream*) istream;
- (GSSocketOutputStream*) ostream;

- (void) bye;           /* Close down the handled session.   */
- (BOOL) handshake;     /* A handshake/hello is in progress. */
- (void) hello;         /* Start up the session handshake.   */
- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len;
- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event;
- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len;
@end


@implementation GSStreamHandler

+ (void) tryInput: (GSSocketInputStream*)i output: (GSSocketOutputStream*)o
{
  [self subclassResponsibility: _cmd];
}

- (void) bye
{
  [self subclassResponsibility: _cmd];
}

- (BOOL) handshake
{
  return handshake;
}

- (void) hello
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithInput: (GSSocketInputStream*)i
              output: (GSSocketOutputStream*)o
{
  istream = i;
  ostream = o;
  handshake = YES;
  return self;
}

- (GSSocketInputStream*) istream
{
  return istream;
}

- (GSSocketOutputStream*) ostream
{
  return ostream;
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event
{
  [self subclassResponsibility: _cmd];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end

#if     defined(HAVE_GNUTLS)
/* Temporarily redefine 'id' in case the headers use the objc reserved word.
 */
#define	id	GNUTLSID
#include <gnutls/gnutls.h>
#include <gcrypt.h>
#undef	id

/* Set up locking callbacks for gcrypt so that it will be thread-safe.
 */
static int gcry_mutex_init (void **priv)
{
  NSLock        *lock = [NSLock new];
  *priv = (void*)lock;
  return 0;
}
static int gcry_mutex_destroy (void **lock)
{
  [((NSLock*)*lock) release];
  return 0;
}
static int gcry_mutex_lock (void **lock)
{
  [((NSLock*)*lock) lock];
  return 0;
}
static int gcry_mutex_unlock (void **lock)
{
  [((NSLock*)*lock) unlock];
  return 0;
}
static struct gcry_thread_cbs gcry_threads_other = {
  GCRY_THREAD_OPTION_DEFAULT,
  NULL,
  gcry_mutex_init,
  gcry_mutex_destroy,
  gcry_mutex_lock,
  gcry_mutex_unlock
};


@interface      GSTLS : GSStreamHandler
{
@public
  gnutls_session_t      session;
  gnutls_certificate_credentials_t      certcred;
}
@end

/* Callback to allow the TLS code to pull data from the remote system.
 * If the operation fails, this sets the error number.
 */
static ssize_t
GSTLSPull(gnutls_transport_ptr_t handle, void *buffer, size_t len)
{
  ssize_t       result;
  GSTLS         *tls = (GSTLS*)handle;
  
  result = [[tls istream] _read: buffer maxLength: len];
  if (result < 0)
    {
      int       e;

      if ([[tls istream] streamStatus] == NSStreamStatusError)
        {
          e = [[[(GSTLS*)handle istream] streamError] code];
        }
      else
        {
          e = EAGAIN;	// Tell GNUTLS this would block.
        }
#if	HAVE_GNUTLS_TRANSPORT_SET_ERRNO
      gnutls_transport_set_errno (tls->session, e);
#else
      errno = e;	// Not thread-safe
#endif
    }
  return result;
}

/* Callback to allow the TLS code to push data to the remote system.
 * If the operation fails, this sets the error number.
 */
static ssize_t
GSTLSPush(gnutls_transport_ptr_t handle, const void *buffer, size_t len)
{
  ssize_t       result;
  GSTLS         *tls = (GSTLS*)handle;
  
  result = [[tls ostream] _write: buffer maxLength: len];
  if (result < 0)
    {
      int       e;

      if ([[tls ostream] streamStatus] == NSStreamStatusError)
        {
          e = [[[tls ostream] streamError] code];
        }
      else
        {
          e = EAGAIN;	// Tell GNUTLS this would block.
        }
#if	HAVE_GNUTLS_TRANSPORT_SET_ERRNO
      gnutls_transport_set_errno (tls->session, e);
#else
      errno = e;	// Not thread-safe
#endif

    }
  return result;
}

static void
GSTLSLog(int level, const char *msg)
{
  NSLog(@"%s", msg);
}


@implementation GSTLS

static gnutls_anon_client_credentials_t anoncred;

+ (void) initialize
{
  static BOOL   beenHere = NO;

  if (beenHere == NO)
    {
      beenHere = YES;

      /* Make gcrypt thread-safe
       */
      gcry_control (GCRYCTL_SET_THREAD_CBS, &gcry_threads_other);
      /* Initialise gnutls
       */
      gnutls_global_init ();
      /* Allocate global credential information for anonymous tls
       */
      gnutls_anon_allocate_client_credentials (&anoncred);
      /* Enable gnutls logging via NSLog
       */
      gnutls_global_set_log_function (GSTLSLog);

    }
}

+ (void) tryInput: (GSSocketInputStream*)i output: (GSSocketOutputStream*)o
{
  NSString      *tls;

  tls = [i propertyForKey: NSStreamSocketSecurityLevelKey];
  if (tls == nil)
    {
      tls = [o propertyForKey: NSStreamSocketSecurityLevelKey];
      if (tls != nil)
        {
          [i setProperty: tls forKey: NSStreamSocketSecurityLevelKey];
        }
    }
  else
    {
      [o setProperty: tls forKey: NSStreamSocketSecurityLevelKey];
    }

  if (tls != nil)
    {
      GSTLS     *h;

      h = [[GSTLS alloc] initWithInput: i output: o];
      [i _setHandler: h];
      [o _setHandler: h];
      RELEASE(h);
    }
}

- (void) bye
{
  if (active == YES || handshake == YES)
    {
      active = NO;
      handshake = NO;
      gnutls_bye (session, GNUTLS_SHUT_RDWR);
    }
}

- (void) dealloc
{
  [self bye];
  gnutls_db_remove_session (session);
  gnutls_deinit (session);
  gnutls_certificate_free_credentials (certcred);
  [super dealloc];
}

- (BOOL) handshake
{
  return handshake;
}

- (void) hello
{
  if (active == NO)
    {
      int   ret;

      if (handshake == NO)
        {
          /* Set flag to say we are now doing a handshake.
           */
          handshake = YES;
        }
      ret = gnutls_handshake (session);
      if (ret < 0)
        {
          NSDebugMLLog(@"NSStream",
            @"Handshake status %d", ret);
	  if (GSDebugSet(@"NSStream") == YES)
	    {
              gnutls_perror(ret);
	    }
        }
      else
        {
          handshake = NO;       // Handshake is now complete.
          active = YES;         // The TLS session is now active.
        }
    }
}

- (id) initWithInput: (GSSocketInputStream*)i
              output: (GSSocketOutputStream*)o
{
  NSString      *proto = [i propertyForKey: NSStreamSocketSecurityLevelKey];

  if (GSDebugSet(@"NSStream") == YES)
    {
      gnutls_global_set_log_level (11); // Full debug output
    }
  else
    {
      gnutls_global_set_log_level (0);  // No debug
    }

  if ([[o propertyForKey: NSStreamSocketSecurityLevelKey] isEqual: proto] == NO)
    {
      DESTROY(self);
      return nil;
    }
  if ([proto isEqualToString: NSStreamSocketSecurityLevelNone] == YES)
    {
      proto = NSStreamSocketSecurityLevelNone;
      DESTROY(self);
      return nil;
    }
  else if ([proto isEqualToString: NSStreamSocketSecurityLevelSSLv2] == YES)
    {
      proto = NSStreamSocketSecurityLevelSSLv2;
      GSOnceMLog(@"NSStreamSocketSecurityLevelTLSv1 is insecure ..."
        @" not implemented");
      DESTROY(self);
      return nil;
    }
  else if ([proto isEqualToString: NSStreamSocketSecurityLevelSSLv3] == YES)
    {
      proto = NSStreamSocketSecurityLevelSSLv3;
    }
  else if ([proto isEqualToString: NSStreamSocketSecurityLevelTLSv1] == YES)
    {
      proto = NSStreamSocketSecurityLevelTLSv1;
    }
  else
    {
      proto = NSStreamSocketSecurityLevelNegotiatedSSL;
    }

  if ((self = [super initWithInput: i output: o]) == nil)
    {
      return nil;
    }

  initialised = YES;
  /* Configure this session to support certificate based
   * operation.
   */
  gnutls_certificate_allocate_credentials (&certcred);

  /* FIXME ... should get the trusted authority certificates
   * from somewhere sensible to validate the remote end!
   */
  gnutls_certificate_set_x509_trust_file
    (certcred, "ca.pem", GNUTLS_X509_FMT_PEM);

  /* Initialise session and set default priorities foir key exchange.
   */
  gnutls_init (&session, GNUTLS_CLIENT);
  gnutls_set_default_priority (session);

  if ([proto isEqualToString: NSStreamSocketSecurityLevelTLSv1] == YES)
    {
      const int proto_prio[4] = {
#if	defined(GNUTLS_TLS1_2)
        GNUTLS_TLS1_2,
#endif
        GNUTLS_TLS1_1,
        GNUTLS_TLS1_0,
        0 };
      gnutls_protocol_set_priority (session, proto_prio);
    }
  if ([proto isEqualToString: NSStreamSocketSecurityLevelSSLv3] == YES)
    {
      const int proto_prio[2] = {
        GNUTLS_SSL3,
        0 };
      gnutls_protocol_set_priority (session, proto_prio);
    }

/*
 {
    const int kx_prio[] = {
      GNUTLS_KX_RSA,
      GNUTLS_KX_RSA_EXPORT,
      GNUTLS_KX_DHE_RSA,
      GNUTLS_KX_DHE_DSS,
      GNUTLS_KX_ANON_DH,
      0 };
    gnutls_kx_set_priority (session, kx_prio);
    gnutls_credentials_set (session, GNUTLS_CRD_ANON, anoncred);
  }
 */ 

  /* Set certificate credentials for this session.
   */
  gnutls_credentials_set (session, GNUTLS_CRD_CERTIFICATE, certcred);
  
  /* Set transport layer to use our low level stream code.
   */
  gnutls_transport_set_lowat (session, 0);
  gnutls_transport_set_pull_function (session, GSTLSPull);
  gnutls_transport_set_push_function (session, GSTLSPush);
  gnutls_transport_set_ptr (session, (gnutls_transport_ptr_t)self);

  return self;
}

- (GSSocketInputStream*) istream
{
  return istream;
}

- (GSSocketOutputStream*) ostream
{
  return ostream;
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  return gnutls_record_recv (session, buffer, len);
}

- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event
{
  NSDebugMLLog(@"NSStream",
    @"GSTLS got %d on %p", event, stream);

  if (handshake == YES)
    {
      switch (event)
        {
          case NSStreamEventHasSpaceAvailable:
          case NSStreamEventHasBytesAvailable:
          case NSStreamEventOpenCompleted:
            [self hello]; /* try to complete the handshake */
            if (handshake == NO)
              {
                NSDebugMLLog(@"NSStream",
                  @"GSTLS completed on %p", stream);
                if ([istream streamStatus] == NSStreamStatusOpen)
                  {
		    [istream _resetEvents: NSStreamEventOpenCompleted];
                    [istream _sendEvent: NSStreamEventOpenCompleted];
                  }
                else
                  {
		    [istream _resetEvents: NSStreamEventErrorOccurred];
                    [istream _sendEvent: NSStreamEventErrorOccurred];
                  }
                if ([ostream streamStatus]  == NSStreamStatusOpen)
                  {
		    [ostream _resetEvents: NSStreamEventOpenCompleted
		      | NSStreamEventHasSpaceAvailable];
                    [ostream _sendEvent: NSStreamEventOpenCompleted];
                    [ostream _sendEvent: NSStreamEventHasSpaceAvailable];
                  }
                else
                  {
		    [ostream _resetEvents: NSStreamEventErrorOccurred];
                    [ostream _sendEvent: NSStreamEventErrorOccurred];
                  }
              }
            break;
          default:
            break;
        }
    }
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  return gnutls_record_send (session, buffer, len);
}

@end

#else   /* HAVE_GNUTLS */

/* GNUTLS not available ...
 */
@interface      GSTLS : GSStreamHandler
@end
@implementation GSTLS
+ (void) tryInput: (GSSocketInputStream*)i output: (GSSocketOutputStream*)o
{
  NSString	*tls;

  tls = [i propertyForKey: NSStreamSocketSecurityLevelKey];
  if (tls == nil)
    {
      tls = [o propertyForKey: NSStreamSocketSecurityLevelKey];
    }
  if (tls != nil
    && [tls isEqualToString: NSStreamSocketSecurityLevelNone] == NO)
    {
      NSLog(@"Attempt to use SSL/TLS without support.");
      NSLog(@"Please reconfigure gnustep-base with GNU TLS.");
    }
  return;
}
- (id) initWithInput: (GSSocketInputStream*)i
              output: (GSSocketOutputStream*)o
{
  DESTROY(self);
  return nil;
}
@end

#endif   /* HAVE_GNUTLS */



/*
 * States for socks connection negotiation
 */
static NSString * const GSSOCKSOfferAuth = @"GSSOCKSOfferAuth";
static NSString * const GSSOCKSRecvAuth = @"GSSOCKSRecvAuth";
static NSString * const GSSOCKSSendAuth = @"GSSOCKSSendAuth";
static NSString * const GSSOCKSAckAuth = @"GSSOCKSAckAuth";
static NSString * const GSSOCKSSendConn = @"GSSOCKSSendConn";
static NSString * const GSSOCKSAckConn = @"GSSOCKSAckConn";

@interface	GSSOCKS : GSStreamHandler
{
  NSString		*state;		/* Not retained */
  NSString		*address;
  NSString		*port;
  int			roffset;
  int			woffset;
  int			rwant;
  unsigned char		rbuffer[128];
}
- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event;
@end

@implementation	GSSOCKS
+ (void) tryInput: (GSSocketInputStream*)i output: (GSSocketOutputStream*)o
{
  NSDictionary          *conf;

  conf = [i propertyForKey: NSStreamSOCKSProxyConfigurationKey];
  if (conf == nil)
    {
      conf = [o propertyForKey: NSStreamSOCKSProxyConfigurationKey];
      if (conf != nil)
        {
          [i setProperty: conf forKey: NSStreamSOCKSProxyConfigurationKey];
        }
    }
  else
    {
      [o setProperty: conf forKey: NSStreamSOCKSProxyConfigurationKey];
    }

  if (conf != nil)
    {
      GSSOCKS           *h;
      struct sockaddr   *sa = [i _address];
      NSString          *v;
      BOOL              i6 = NO;

      v = [conf objectForKey: NSStreamSOCKSProxyVersionKey];
      if ([v isEqualToString: NSStreamSOCKSProxyVersion4] == YES)
        {
          v = NSStreamSOCKSProxyVersion4;
        }
      else
        {
          v = NSStreamSOCKSProxyVersion5;
        }

#if     defined(AF_INET6)
      if (sa->sa_family == AF_INET6)
        {
          i6 = YES;
        }
      else
#endif
      if (sa->sa_family != AF_INET)
        {
          GSOnceMLog(@"SOCKS not supported for socket type %d", sa->sa_family);
          return;
        }

      if (v == NSStreamSOCKSProxyVersion5)
        {
          GSOnceMLog(@"SOCKS 5 not supported yet");
          return;
        }
      else if (i6 == YES)
        {
          GSOnceMLog(@"INET6 not supported with SOCKS 4");
          return;
        }

      h = [[GSSOCKS alloc] initWithInput: i output: o];
      [i _setHandler: h];
      [o _setHandler: h];
      RELEASE(h);
    }
}

- (void) bye
{
  if (handshake == YES)
    {
      GSSocketInputStream	*is = RETAIN(istream);
      GSSocketOutputStream	*os = RETAIN(ostream);

      handshake = NO;

      [is _setHandler: nil];
      [os _setHandler: nil];
      [GSTLS tryInput: is output: os];
      if ([is streamStatus] == NSStreamStatusOpen)
        {
	  [is _resetEvents: NSStreamEventOpenCompleted];
          [is _sendEvent: NSStreamEventOpenCompleted];
        }
      else
        {
	  [is _resetEvents: NSStreamEventErrorOccurred];
          [is _sendEvent: NSStreamEventErrorOccurred];
        }
      if ([os streamStatus]  == NSStreamStatusOpen)
        {
	  [os _resetEvents: NSStreamEventOpenCompleted
	    | NSStreamEventHasSpaceAvailable];
          [os _sendEvent: NSStreamEventOpenCompleted];
          [os _sendEvent: NSStreamEventHasSpaceAvailable];
        }
      else
        {
	  [os _resetEvents: NSStreamEventErrorOccurred];
          [os _sendEvent: NSStreamEventErrorOccurred];
        }
      RELEASE(is);
      RELEASE(os);
    }
}

- (void) dealloc
{
  RELEASE(address);
  RELEASE(port);
  [super dealloc];
}

- (void) hello
{
  if (handshake == NO)
    {
      handshake = YES;
      /* Now send self an event to say we can write, to kick off the
       * handshake with the SOCKS server.
       */
      [self stream: ostream handleEvent: NSStreamEventHasSpaceAvailable];
    }
}

- (id) initWithInput: (GSSocketInputStream*)i
              output: (GSSocketOutputStream*)o
{
  if ((self = [super initWithInput: i output: o]) != nil)
    {
      if ([istream isKindOfClass: [GSInetInputStream class]] == NO)
	{
	  NSLog(@"Attempt to use SOCKS with non-INET stream ignored");
	  DESTROY(self);
	}
#if	defined(AF_INET6)
      else if ([istream isKindOfClass: [GSInet6InputStream class]] == YES)
	{
          GSOnceMLog(@"INET6 not supported with SOCKS yet...");
	  DESTROY(self);
	}
#endif	/* AF_INET6 */
      else
	{
	  struct sockaddr_in	*addr = (struct sockaddr_in*)[istream _address];
          NSDictionary          *conf;
          NSString              *host;
          int                   pnum;

          /* Record the host and port that the streams are supposed to be
           * connecting to.
           */ 
	  address = [[NSString alloc] initWithUTF8String:
	    (char*)inet_ntoa(addr->sin_addr)];
	  port = [[NSString alloc] initWithFormat: @"%d",
	    (NSInteger)GSSwapBigI16ToHost(addr->sin_port)];

          /* Now reconfigure the streams so they will actually connect
           * to the socks proxy server.
           */
          conf = [istream propertyForKey: NSStreamSOCKSProxyConfigurationKey];
          host = [conf objectForKey: NSStreamSOCKSProxyHostKey];
          pnum = [[conf objectForKey: NSStreamSOCKSProxyPortKey] intValue];
          [istream _setSocketAddress: address port: pnum family: AF_INET];
          [ostream _setSocketAddress: address port: pnum family: AF_INET];
	}
    }
  return self;
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  return [istream _read: buffer maxLength: len];
}

- (void) stream: (NSStream*)stream handleEvent: (NSStreamEvent)event
{
  NSString		*error = nil;
  NSDictionary		*conf;
  NSString		*user;
  NSString		*pass;

  if (event == NSStreamEventErrorOccurred
    || [stream streamStatus] == NSStreamStatusError
    || [stream streamStatus] == NSStreamStatusClosed)
    {
      [self bye];
      return;
    }

  conf = [stream propertyForKey: NSStreamSOCKSProxyConfigurationKey];
  user = [conf objectForKey: NSStreamSOCKSProxyUserKey];
  pass = [conf objectForKey: NSStreamSOCKSProxyPasswordKey];
  if ([[conf objectForKey: NSStreamSOCKSProxyVersionKey]
    isEqual: NSStreamSOCKSProxyVersion4] == YES)
    {
    }
  else
    {
      again:

      if (state == GSSOCKSOfferAuth)
	{
	  int		result;
	  int		want;
	  unsigned char	buf[4];

	  /*
	   * Authorisation record is at least three bytes -
	   *   socks version (5)
	   *   authorisation method bytes to follow (1)
	   *   say we do no authorisation (0)
	   *   say we do user/pass authorisation (2)
	   */
	  buf[0] = 5;
	  if (user && pass)
	    {
	      buf[1] = 2;
	      buf[2] = 2;
	      buf[3] = 0;
	      want = 4;
	    }
	  else
	    {
	      buf[1] = 1;
	      buf[2] = 0;
	      want = 3;
	    }

	  result = [ostream _write: buf + woffset maxLength: 4 - woffset];
	  if (result > 0)
	    {
	      woffset += result;
	      if (woffset == want)
		{
		  woffset = 0;
		  state = GSSOCKSRecvAuth;
		  goto again;
		}
	    }
	}
      else if (state == GSSOCKSRecvAuth)
	{
	  int	result;

	  result = [istream _read: rbuffer + roffset maxLength: 2 - roffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      roffset += result;
	      if (roffset == 2)
		{
		  roffset = 0;
		  if (rbuffer[0] != 5)
		    {
		      error = @"SOCKS authorisation response had wrong version";
		    }
		  else if (rbuffer[1] == 0)
		    {
		      state = GSSOCKSSendConn;
		      goto again;
		    }
		  else if (rbuffer[1] == 2)
		    {
		      state = GSSOCKSSendAuth;
		      goto again;
		    }
		  else
		    {
		      error = @"SOCKS authorisation response had wrong method";
		    }
		}
	    }
	}
      else if (state == GSSOCKSSendAuth)
	{
	  NSData	*u = [user dataUsingEncoding: NSUTF8StringEncoding];
	  unsigned	ul = [u length];
	  NSData	*p = [pass dataUsingEncoding: NSUTF8StringEncoding];
	  unsigned	pl = [p length];

	  if (ul < 1 || ul > 255)
	    {
	      error = @"NSStreamSOCKSProxyUserKey value too long";
	    }
	  else if (ul < 1 || ul > 255)
	    {
	      error = @"NSStreamSOCKSProxyPasswordKey value too long";
	    }
	  else
	    {
	      int		want = ul + pl + 3;
	      unsigned char	buf[want];
	      int		result;

	      buf[0] = 5;
	      buf[1] = ul;
	      memcpy(buf + 2, [u bytes], ul);
	      buf[ul + 2] = pl;
	      memcpy(buf + ul + 3, [p bytes], pl);
	      result = [ostream _write: buf + woffset
			     maxLength: want - woffset];
	      if (result == 0)
		{
		  error = @"SOCKS end-of-file during negotiation";
		}
	      else if (result > 0)
		{
		  woffset += result;
		  if (woffset == want)
		    {
		      state = GSSOCKSAckAuth;
		      goto again;
		    }
		}
	    }
	}
      else if (state == GSSOCKSAckAuth)
	{
	  int	result;

	  result = [istream _read: rbuffer + roffset maxLength: 2 - roffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      roffset += result;
	      if (roffset == 2)
		{
		  roffset = 0;
		  if (rbuffer[0] != 5)
		    {
		      error = @"SOCKS authorisation response had wrong version";
		    }
		  else if (rbuffer[1] == 0)
		    {
		      state = GSSOCKSSendConn;
		      goto again;
		    }
		  else if (rbuffer[1] == 2)
		    {
		      error = @"SOCKS authorisation failed";
		    }
		}
	    }
	}
      else if (state == GSSOCKSSendConn)
	{
	  unsigned char	buf[10];
	  int		want = 10;
	  int		result;
	  const char	*ptr;

	  /*
	   * Connect command is ten bytes -
	   *   socks version
	   *   connect command
	   *   reserved byte
	   *   address type
	   *   address 4 bytes (big endian)
	   *   port 2 bytes (big endian)
	   */
	  buf[0] = 5;	// Socks version number
	  buf[1] = 1;	// Connect command
	  buf[2] = 0;	// Reserved
	  buf[3] = 1;	// Address type (IPV4)
	  ptr = [address UTF8String];
	  buf[4] = atoi(ptr);
	  while (isdigit(*ptr))
	    ptr++;
	  ptr++;
	  buf[5] = atoi(ptr);
	  while (isdigit(*ptr))
	    ptr++;
	  ptr++;
	  buf[6] = atoi(ptr);
	  while (isdigit(*ptr))
	    ptr++;
	  ptr++;
	  buf[7] = atoi(ptr);
	  result = [port intValue];
	  buf[8] = ((result & 0xff00) >> 8);
	  buf[9] = (result & 0xff);

	  result = [ostream _write: buf + woffset maxLength: want - woffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      woffset += result;
	      if (woffset == want)
		{
		  rwant = 5;
		  state = GSSOCKSAckConn;
		  goto again;
		}
	    }
	}
      else if (state == GSSOCKSAckConn)
	{
	  int	result;

	  result = [istream _read: rbuffer + roffset
                        maxLength: rwant - roffset];
	  if (result == 0)
	    {
	      error = @"SOCKS end-of-file during negotiation";
	    }
	  else if (result > 0)
	    {
	      roffset += result;
	      if (roffset == rwant)
		{
		  if (rbuffer[0] != 5)
		    {
		      error = @"connect response from SOCKS had wrong version";
		    }
		  else if (rbuffer[1] != 0)
		    {
		      switch (rbuffer[1])
			{
			  case 1:
			    error = @"SOCKS server general failure";
			    break;
			  case 2:
			    error = @"SOCKS server says permission denied";
			    break;
			  case 3:
			    error = @"SOCKS server says network unreachable";
			    break;
			  case 4:
			    error = @"SOCKS server says host unreachable";
			    break;
			  case 5:
			    error = @"SOCKS server says connection refused";
			    break;
			  case 6:
			    error = @"SOCKS server says connection timed out";
			    break;
			  case 7:
			    error = @"SOCKS server says command not supported";
			    break;
			  case 8:
			    error = @"SOCKS server says address not supported";
			    break;
			  default:
			    error = @"connect response from SOCKS was failure";
			    break;
			}
		    }
		  else if (rbuffer[3] == 1)
		    {
		      rwant = 10;		// Fixed size (IPV4) address
		    }
		  else if (rbuffer[3] == 3)
		    {
		      rwant = 7 + rbuffer[4];	// Domain name leading length
		    }
		  else if (rbuffer[3] == 4)
		    {
		      rwant = 22;		// Fixed size (IPV6) address
		    }
		  else
		    {
		      error = @"SOCKS server returned unknown address type";
		    }
		  if (error == nil)
		    {
		      if (roffset < rwant)
			{
			  goto again;	// Need address/port bytes
			}
		      else
			{
			  NSString	*a;

			  error = @"";	// success
			  if (rbuffer[3] == 1)
			    {
			      a = [NSString stringWithFormat: @"%d.%d.%d.%d",
			        rbuffer[4], rbuffer[5], rbuffer[6], rbuffer[7]];
			    }
			  else if (rbuffer[3] == 3)
			    {
			      rbuffer[rwant] = '\0';
			      a = [NSString stringWithUTF8String:
			        (const char*)rbuffer];
			    }
			  else
			    {
			      unsigned char	buf[40];
			      int		i = 4;
			      int		j = 0;

			      while (i < rwant)
			        {
				  int	val;

				  val = rbuffer[i++];
				  val = val * 256 + rbuffer[i++];
				  if (i > 4)
				    {
				      buf[j++] = ':';
				    }
				  sprintf((char*)&buf[j], "%04x", val);
				  j += 4;
				}
			      a = [NSString stringWithUTF8String:
			        (const char*)buf];
			    }

			  [istream setProperty: a
					forKey: GSStreamRemoteAddressKey];
			  [ostream setProperty: a
					forKey: GSStreamRemoteAddressKey];
			  a = [NSString stringWithFormat: @"%d",
			    rbuffer[rwant-1] * 256 * rbuffer[rwant-2]];
			  [istream setProperty: a
					forKey: GSStreamRemotePortKey];
			  [ostream setProperty: a
					forKey: GSStreamRemotePortKey];
			  /* Return immediately after calling -bye as it
			   * will cause this instance to be deallocated.
			   */
			  [self bye];
			  return;
			}
		    }
		}
	    }
	}
    }

  if ([error length] > 0)
    {
      NSError *theError;

      theError = [NSError errorWithDomain: NSCocoaErrorDomain
	code: 0
	userInfo: [NSDictionary dictionaryWithObject: error
	  forKey: NSLocalizedDescriptionKey]];
      if ([istream streamStatus] != NSStreamStatusError)
	{
	  [istream _recordError: theError];
	}
      if ([ostream streamStatus] != NSStreamStatusError)
	{
	  [ostream _recordError: theError];
	}
      [self bye];
    }
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  return [ostream _write: buffer maxLength: len];
}

@end


static inline BOOL
socketError(int result)
{
#if	defined(__MINGW32__)
  return (result == SOCKET_ERROR) ? YES : NO;
#else
  return (result < 0) ? YES : NO;
#endif
}

static inline BOOL
socketWouldBlock()
{
#if	defined(__MINGW32__)
  int   e = WSAGetLastError();
  return (e == WSAEWOULDBLOCK || e == WSAEINPROGRESS) ? YES : NO;
#else
  return (errno == EWOULDBLOCK || errno == EINPROGRESS) ? YES : NO;
#endif
}


static void
setNonBlocking(SOCKET fd)
{
#if	defined(__MINGW32__)
  unsigned long dummy = 1;

  if (ioctlsocket(fd, FIONBIO, &dummy) == SOCKET_ERROR)
    {
      NSLog(@"unable to set non-blocking mode - %@", [NSError _last]);
    }
#else
  int flags = fcntl(fd, F_GETFL, 0);

  if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0)
    {
      NSLog(@"unable to set non-blocking mode - %@",
        [NSError _last]);
    }
#endif
}

@implementation GSSocketStream

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [_sibling _setSibling: nil];
  _sibling = nil;
  DESTROY(_handler);
  if (_address != 0)
    {
      NSZoneFree(NSDefaultMallocZone(), _address);
    }
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      // so that unopened access will fail
      _sibling = nil;
      _closing = NO;
      _passive = NO;
#if	defined(__MINGW32__)
      _loopID = WSA_INVALID_EVENT;
#else
      _loopID = (void*)(intptr_t)-1;
#endif
      _sock = INVALID_SOCKET;
      _handler = nil;
    }
  return self;
}

- (struct sockaddr*) _address
{
  return (struct sockaddr*)_address;
}

- (id) propertyForKey: (NSString *)key
{
  id	result = [super propertyForKey: key];

  if (result == nil && _address != 0)
    {
      SOCKET    s = [self _sock];

      switch (_address->sa_family)
        {
          case AF_INET:
            {
              struct sockaddr_in sin;
              socklen_t	        size = sizeof(sin);

              if ([key isEqualToString: GSStreamLocalAddressKey])
                {
                  if (getsockname(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      result = [NSString stringWithUTF8String:
                        (char*)inet_ntoa(sin.sin_addr)];
                    }
                }
              else if ([key isEqualToString: GSStreamLocalPortKey])
                {
                  if (getsockname(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      result = [NSString stringWithFormat: @"%d",
                        (int)GSSwapBigI16ToHost(sin.sin_port)];
                    }
                }
              else if ([key isEqualToString: GSStreamRemoteAddressKey])
                {
                  if (getpeername(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      result = [NSString stringWithUTF8String:
                        (char*)inet_ntoa(sin.sin_addr)];
                    }
                }
              else if ([key isEqualToString: GSStreamRemotePortKey])
                {
                  if (getpeername(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      result = [NSString stringWithFormat: @"%d",
                        (int)GSSwapBigI16ToHost(sin.sin_port)];
                    }
                }
            }
            break;
#if	defined(AF_INET6)
          case AF_INET6:
            {
              struct sockaddr_in6 sin;
              socklen_t	        size = sizeof(sin);

              if ([key isEqualToString: GSStreamLocalAddressKey])
                {
                  if (getsockname(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      char	buf[INET6_ADDRSTRLEN+1];

                      if (inet_ntop(AF_INET6, &(sin.sin6_addr), buf,
                        INET6_ADDRSTRLEN) == 0)
                        {
                          buf[INET6_ADDRSTRLEN] = '\0';
                          result = [NSString stringWithUTF8String: buf];
                        }
                    }
                }
              else if ([key isEqualToString: GSStreamLocalPortKey])
                {
                  if (getsockname(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      result = [NSString stringWithFormat: @"%d",
                        (int)GSSwapBigI16ToHost(sin.sin6_port)];
                    }
                }
              else if ([key isEqualToString: GSStreamRemoteAddressKey])
                {
                  if (getpeername(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      char	buf[INET6_ADDRSTRLEN+1];

                      if (inet_ntop(AF_INET6, &(sin.sin6_addr), buf,
                        INET6_ADDRSTRLEN) == 0)
                        {
                          buf[INET6_ADDRSTRLEN] = '\0';
                          result = [NSString stringWithUTF8String: buf];
                        }
                    }
                }
              else if ([key isEqualToString: GSStreamRemotePortKey])
                {
                  if (getpeername(s, (struct sockaddr*)&sin, &size) != -1)
                    {
                      result = [NSString stringWithFormat: @"%d",
                        (int)GSSwapBigI16ToHost(sin.sin6_port)];
                    }
                }
            }
            break;
#endif
        }
    }
  return result;
}

- (NSInteger) _read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

- (void) _sendEvent: (NSStreamEvent)event
{
  /* If the receiver has a TLS handshake in progress,
   * we must send events to the TLS handler rather than
   * the stream delegate.
   */
  if (_handler != nil && [_handler handshake] == YES)
    {
      id        del = _delegate;
      BOOL      val = _delegateValid;

      _delegate = _handler;
      _delegateValid = YES;
      [super _sendEvent: event];
      _delegate = del;
      _delegateValid = val;
    }
  else
    {
      [super _sendEvent: event];
    }
}

- (BOOL) _setSocketAddress: (NSString*)address
                      port: (NSInteger)port
                    family: (NSInteger)family
{
  uint16_t	p = (uint16_t)port;

  switch (family)
    {
      case AF_INET:
        {
          int           ptonReturn;
          const char    *addr_c;
          struct	sockaddr_in	peer;

          addr_c = [address cStringUsingEncoding: NSUTF8StringEncoding];
          memset(&peer, '\0', sizeof(peer));
          peer.sin_family = AF_INET;
          peer.sin_port = GSSwapHostI16ToBig(p);
          ptonReturn = inet_pton(AF_INET, addr_c, &peer.sin_addr);
          if (ptonReturn == 0)   // error
            {
              return NO;
            }
          else
            {
              [self _setAddress: (struct sockaddr*)&peer];
              return YES;
            }
        }

#if	defined(AF_INET6)
      case AF_INET6:
        {
          int           ptonReturn;
          const char    *addr_c;
          struct	sockaddr_in6	peer;

          addr_c = [address cStringUsingEncoding: NSUTF8StringEncoding];
          memset(&peer, '\0', sizeof(peer));
          peer.sin6_family = AF_INET6;
          peer.sin6_port = GSSwapHostI16ToBig(p);
          ptonReturn = inet_pton(AF_INET6, addr_c, &peer.sin6_addr);
          if (ptonReturn == 0)   // error
            {
              return NO;
            }
          else
            {
              [self _setAddress: (struct sockaddr*)&peer];
              return YES;
            }
        }
#endif

#ifndef	__MINGW32__
      case AF_LOCAL:
	{
	  struct sockaddr_un	peer;
	  const char                *c_addr;

	  c_addr = [address fileSystemRepresentation];
	  memset(&peer, '\0', sizeof(peer));
	  peer.sun_family = AF_LOCAL;
	  if (strlen(c_addr) > sizeof(peer.sun_path)-1) // too long
	    {
	      return NO;
	    }
	  else
	    {
	      strncpy(peer.sun_path, c_addr, sizeof(peer.sun_path)-1);
	      [self _setAddress: (struct sockaddr*)&peer];
	      return YES;
	    }
	}
#endif

      default:
        return NO;
    }
}

- (void) _setAddress: (struct sockaddr*)address
{
  if (_address != 0
    && GSPrivateSockaddrLength(_address) != GSPrivateSockaddrLength(address))
    {
      NSZoneFree(NSDefaultMallocZone(), _address);
      _address = 0;
    }
  if (_address == 0)
    {
      _address = (struct sockaddr*)
	NSZoneMalloc(NSDefaultMallocZone(), GSPrivateSockaddrLength(address));
    }
  memcpy(_address, address, GSPrivateSockaddrLength(address));
}

- (void) _setLoopID: (void *)ref
{
#if	!defined(__MINGW32__)
  _sock = (SOCKET)(intptr_t)ref;        // On gnu/linux _sock is _loopID
#endif
  _loopID = ref;
}

- (void) _setClosing: (BOOL)closing
{
  _closing = closing;
}

- (void) _setPassive: (BOOL)passive
{
  _passive = passive;
}

- (void) _setSibling: (GSSocketStream*)sibling
{
  _sibling = sibling;
}

- (void) _setSock: (SOCKET)sock
{
  setNonBlocking(sock);
  _sock = sock;

  /* As well as recording the socket, we set up the stream for monitoring it.
   * On unix style systems we set the socket descriptor as the _loopID to be
   * monitored, and on mswindows systems we create an event object to be
   * monitored (the socket events are assoociated with this object later).
   */
#if	defined(__MINGW32__)
  _loopID = CreateEvent(NULL, NO, NO, NULL);
#else
  _loopID = (void*)(intptr_t)sock;      // On gnu/linux _sock is _loopID
#endif
}

- (void) _setHandler: (id)h
{
  ASSIGN(_handler, h);
}

- (SOCKET) _sock
{
  return _sock;
}

- (NSInteger) _write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

@end


@implementation GSSocketInputStream

+ (void) initialize
{
  if (self == [GSSocketInputStream class])
    {
      GSObjCAddClassBehavior(self, [GSSocketStream class]);
    }
}

- (void) open
{
  // could be opened because of sibling
  if ([self _isOpened])
    return;
  if (_passive || (_sibling && [_sibling _isOpened]))
    goto open_ok;
  // check sibling status, avoid double connect
  if (_sibling && [_sibling streamStatus] == NSStreamStatusOpening)
    {
      [self _setStatus: NSStreamStatusOpening];
      return;
    }
  else
    {
      int result;

      if ([self _sock] == INVALID_SOCKET)
        {
          SOCKET        s;

          if (_handler == nil)
            {
              [GSSOCKS tryInput: self output: _sibling];
            }
          s = socket(_address->sa_family, SOCK_STREAM, 0);
          if (BADSOCKET(s))
            {
              [self _recordError];
              return;
            }
          else
            {
              [self _setSock: s];
              [_sibling _setSock: s];
            }
        }

      if (_handler == nil)
        {
          [GSTLS tryInput: self output: _sibling];
        }
      result = connect([self _sock], _address,
        GSPrivateSockaddrLength(_address));
      if (socketError(result))
        {
          if (!socketWouldBlock())
            {
              [self _recordError];
              [self _setHandler: nil];
              [_sibling _setHandler: nil];
              return;
            }
          /*
           * Need to set the status first, so that the run loop can tell
           * it needs to add the stream as waiting on writable, as an
           * indication of opened
           */
          [self _setStatus: NSStreamStatusOpening];
#if	defined(__MINGW32__)
          WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
	  if (NSCountMapTable(_loops) > 0)
	    {
	      [self _schedule];
	      return;
	    }
          else
            {
              NSRunLoop *r;
              NSDate    *d;

              /* The stream was not scheduled in any run loop, so we
               * implement a blocking connect by running in the default
               * run loop mode.
               */
              r = [NSRunLoop currentRunLoop];
              d = [NSDate distantFuture];
              [r addStream: self mode: NSDefaultRunLoopMode];
              while ([r runMode: NSDefaultRunLoopMode beforeDate: d] == YES)
                {
                  if (_currentStatus != NSStreamStatusOpening)
                    {
                      break;
                    }
                }
              [r removeStream: self mode: NSDefaultRunLoopMode];
              return;
            }
        }
    }

 open_ok:
#if	defined(__MINGW32__)
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
  [super open];
}

- (void) close
{
  if (_currentStatus == NSStreamStatusNotOpen)
    {
      NSDebugMLLog(@"NSStream",
        @"Attempt to close unopened stream %@", self);
      return;
    }
  if (_currentStatus == NSStreamStatusClosed)
    {
      NSDebugMLLog(@"NSStream",
        @"Attempt to close already closed stream %@", self);
      return;
    }
  [_handler bye];
#if	defined(__MINGW32__)
  if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
    {
      /*
       * Windows only permits a single event to be associated with a socket
       * at any time, but the runloop system only allows an event handle to
       * be added to the loop once, and we have two streams for each socket.
       * So we use two events, one for each stream, and when one stream is
       * closed, we must call WSAEventSelect to ensure that the event handle
       * of the sibling is used to signal events from now on.
       */
      WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
      shutdown(_sock, SHUT_RD);
      WSAEventSelect(_sock, [_sibling _loopID], FD_ALL_EVENTS);
    }
  else
    {
      closesocket(_sock);
    }
  WSACloseEvent(_loopID);
  [super close];
  _loopID = WSA_INVALID_EVENT;
#else
  // read shutdown is ignored, because the other side may shutdown first.
  if (!_sibling || [_sibling streamStatus] == NSStreamStatusClosed)
    close((intptr_t)_loopID);
  else
    shutdown((intptr_t)_loopID, SHUT_RD);
  [super close];
  _loopID = (void*)(intptr_t)-1;
#endif
  _sock = INVALID_SOCKET;
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte read requested"];
    }

  if (_handler == nil)
    return [self _read: buffer maxLength: len];
  else
    return [_handler read: buffer maxLength: len];
}

- (NSInteger) _read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  int readLen;

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }
  if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      readLen = 0;
    }
  else
    {
#if	defined(__MINGW32__)
      readLen = recv([self _sock], (char*) buffer, (socklen_t) len, 0);
#else
      readLen = read([self _sock], buffer, len);
#endif
    }
  if (socketError(readLen))
    {
      if (_closing == YES)
        {
          /* If a read fails on a closing socket,
           * we have reached the end of all data sent by
           * the remote end before it shut down.
           */
          [self _setClosing: NO];
          [self _setStatus: NSStreamStatusAtEnd];
          [self _sendEvent: NSStreamEventEndEncountered];
          readLen = 0;
        }
      else
        {
          if (socketWouldBlock())
            {
              /* We need an event from the operating system
               * to tell us we can start reading again.
               */
              [self _setStatus: NSStreamStatusReading];
            }
          else
            {
              [self _recordError];
            }
          readLen = -1;
        }
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
      [self _sendEvent: NSStreamEventEndEncountered];
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
    }
  return readLen;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (unsigned int *)len
{
  return NO;
}

- (void) _dispatch
{
#if	defined(__MINGW32__)
  AUTORELEASE(RETAIN(self));
  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams for each socket.
   * So we use two events, one for each stream, and the _dispatch method
   * must handle things for both streams.
   */
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      /*
       * It is possible the stream is closed yet recieving event because
       * of not closed sibling
       */
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
	@"Received event for closed stream");
      [_sibling _dispatch];
    }
  else
    {
      WSANETWORKEVENTS events;
      int error = 0;
      int getReturn = -1;

      if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
	{
	  error = WSAGetLastError();
	}
// else NSLog(@"EVENTS 0x%x on %p", events.lNetworkEvents, self);

      if ([self streamStatus] == NSStreamStatusOpening)
	{
	  [self _unschedule];
	  if (error == 0)
	    {
	      socklen_t len = sizeof(error);

	      getReturn = getsockopt(_sock, SOL_SOCKET, SO_ERROR,
		(char*)&error, &len);
	    }

	  if (getReturn >= 0 && error == 0
	    && (events.lNetworkEvents & FD_CONNECT))
	    { // finish up the opening
	      _passive = YES;
	      [self open];
	      // notify sibling
	      if (_sibling)
		{
		  [_sibling open];
		  [_sibling _sendEvent: NSStreamEventOpenCompleted];
		}
	      [self _sendEvent: NSStreamEventOpenCompleted];
	    }
	}

      if (error != 0)
	{
	  errno = error;
	  [self _recordError];
	  [_sibling _recordError];
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  [_sibling _sendEvent: NSStreamEventErrorOccurred];
	}
      else
	{
	  if (events.lNetworkEvents & FD_WRITE)
	    {
	      NSAssert([_sibling _isOpened], NSInternalInconsistencyException);
	      /* Clear NSStreamStatusWriting if it was set */
	      [_sibling _setStatus: NSStreamStatusOpen];
	    }

	  /* On winsock a socket is always writable unless it has had
	   * failure/closure or a write blocked and we have not been
	   * signalled again.
	   */
	  while ([_sibling _unhandledData] == NO
	    && [_sibling hasSpaceAvailable])
	    {
	      [_sibling _sendEvent: NSStreamEventHasSpaceAvailable];
	    }

	  if (events.lNetworkEvents & FD_READ)
	    {
	      [self _setStatus: NSStreamStatusOpen];
	      while ([self hasBytesAvailable]
		&& [self _unhandledData] == NO)
		{
	          [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }

	  if (events.lNetworkEvents & FD_CLOSE)
	    {
	      [self _setClosing: YES];
	      [_sibling _setClosing: YES];
	      while ([self hasBytesAvailable]
		&& [self _unhandledData] == NO)
		{
		  [self _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents == 0)
	    {
	      [self _sendEvent: NSStreamEventHasBytesAvailable];
	    }
	}
    }
#else
  NSStreamEvent myEvent;

  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int error;
      int result;
      socklen_t len = sizeof(error);

      IF_NO_GC([[self retain] autorelease];)
      [self _unschedule];
      result = getsockopt([self _sock], SOL_SOCKET, SO_ERROR, &error, &len);

      if (result >= 0 && !error)
        { // finish up the opening
          myEvent = NSStreamEventOpenCompleted;
          _passive = YES;
          [self open];
          // notify sibling
          [_sibling open];
          [_sibling _sendEvent: myEvent];
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
          [_sibling _recordError];
          [_sibling _sendEvent: myEvent];
        }
    }
  else if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      myEvent = NSStreamEventHasBytesAvailable;
    }
  [self _sendEvent: myEvent];
#endif
}

#if	defined(__MINGW32__)
- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;
  return YES;
}
#endif

@end


@implementation GSSocketOutputStream

+ (void) initialize
{
  if (self == [GSSocketOutputStream class])
    {
      GSObjCAddClassBehavior(self, [GSSocketStream class]);
    }
}

- (NSInteger) _write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  int writeLen;

  _events &= ~NSStreamEventHasSpaceAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }
  if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      [self _sendEvent: NSStreamEventEndEncountered];
      return 0;
    }

#if	defined(__MINGW32__)
  writeLen = send([self _sock], (char*) buffer, (socklen_t) len, 0);
#else
  writeLen = write([self _sock], buffer, (socklen_t) len);
#endif

  if (socketError(writeLen))
    {
      if (_closing == YES)
        {
          /* If a write fails on a closing socket,
           * we know the other end is no longer reading.
           */
          [self _setClosing: NO];
          [self _setStatus: NSStreamStatusAtEnd];
          [self _sendEvent: NSStreamEventEndEncountered];
          writeLen = 0;
        }
      else
        {
          if (socketWouldBlock())
            {
              /* We need an event from the operating system
               * to tell us we can start writing again.
               */
              [self _setStatus: NSStreamStatusWriting];
            }
          else
            {
              [self _recordError];
            }
          writeLen = -1;
        }
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
    }
  return writeLen;
}

- (void) open
{
  // could be opened because of sibling
  if ([self _isOpened])
    return;
  if (_passive || (_sibling && [_sibling _isOpened]))
    goto open_ok;
  // check sibling status, avoid double connect
  if (_sibling && [_sibling streamStatus] == NSStreamStatusOpening)
    {
      [self _setStatus: NSStreamStatusOpening];
      return;
    }
  else
    {
      int result;
      
      if ([self _sock] == INVALID_SOCKET)
        {
          SOCKET        s;

          if (_handler == nil)
            {
              [GSSOCKS tryInput: _sibling output: self];
            }
          s = socket(_address->sa_family, SOCK_STREAM, 0);
          if (BADSOCKET(s))
            {
              [self _recordError];
              return;
            }
          else
            {
              [self _setSock: s];
              [_sibling _setSock: s];
            }
        }

      if (_handler == nil)
        {
          [GSTLS tryInput: _sibling output: self];
        }

      result = connect([self _sock], _address,
        GSPrivateSockaddrLength(_address));
      if (socketError(result))
        {
          if (!socketWouldBlock())
            {
              [self _recordError];
              [self _setHandler: nil];
              [_sibling _setHandler: nil];
              return;
            }
          /*
           * Need to set the status first, so that the run loop can tell
           * it needs to add the stream as waiting on writable, as an
           * indication of opened
           */
          [self _setStatus: NSStreamStatusOpening];
#if	defined(__MINGW32__)
          WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
	  if (NSCountMapTable(_loops) > 0)
	    {
	      [self _schedule];
	      return;
	    }
          else
            {
              NSRunLoop *r;
              NSDate    *d;

              /* The stream was not scheduled in any run loop, so we
               * implement a blocking connect by running in the default
               * run loop mode.
               */
              r = [NSRunLoop currentRunLoop];
              d = [NSDate distantFuture];
              [r addStream: self mode: NSDefaultRunLoopMode];
              while ([r runMode: NSDefaultRunLoopMode beforeDate: d] == YES)
                {
                  if (_currentStatus != NSStreamStatusOpening)
                    {
                      break;
                    }
                }
              [r removeStream: self mode: NSDefaultRunLoopMode];
              return;
            }
        }
    }

 open_ok: 
#if	defined(__MINGW32__)
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
  [super open];

}


- (void) close
{
  if (_currentStatus == NSStreamStatusNotOpen)
    {
      NSDebugMLLog(@"NSStream",
        @"Attempt to close unopened stream %@", self);
      return;
    }
  if (_currentStatus == NSStreamStatusClosed)
    {
      NSDebugMLLog(@"NSStream",
        @"Attempt to close already closed stream %@", self);
      return;
    }
  [_handler bye];
#if	defined(__MINGW32__)
  if (_sibling && [_sibling streamStatus] != NSStreamStatusClosed)
    {
      /*
       * Windows only permits a single event to be associated with a socket
       * at any time, but the runloop system only allows an event handle to
       * be added to the loop once, and we have two streams for each socket.
       * So we use two events, one for each stream, and when one stream is
       * closed, we must call WSAEventSelect to ensure that the event handle
       * of the sibling is used to signal events from now on.
       */
      WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
      shutdown(_sock, SHUT_WR);
      WSAEventSelect(_sock, [_sibling _loopID], FD_ALL_EVENTS);
    }
  else
    {
      closesocket(_sock);
    }
  WSACloseEvent(_loopID);
  [super close];
  _loopID = WSA_INVALID_EVENT;
#else
  // read shutdown is ignored, because the other side may shutdown first.
  if (!_sibling || [_sibling streamStatus] == NSStreamStatusClosed)
    close((intptr_t)_loopID);
  else
    shutdown((intptr_t)_loopID, SHUT_WR);
  [super close];
  _loopID = (void*)(intptr_t)-1;
#endif
  _sock = INVALID_SOCKET;
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte length write requested"];
    }

  if (_handler == nil)
    return [self _write: buffer maxLength: len];
  else
    return [_handler write: buffer maxLength: len];
}

- (void) _dispatch
{
#if	defined(__MINGW32__)
  AUTORELEASE(RETAIN(self));
  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams for each socket.
   * So we use two events, one for each stream, and the _dispatch method
   * must handle things for both streams.
   */
  if ([self streamStatus] == NSStreamStatusClosed)
    {
      /*
       * It is possible the stream is closed yet recieving event because
       * of not closed sibling
       */
      NSAssert([_sibling streamStatus] != NSStreamStatusClosed, 
	@"Received event for closed stream");
      [_sibling _dispatch];
    }
  else
    {
      WSANETWORKEVENTS events;
      int error = 0;
      int getReturn = -1;

      if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
	{
	  error = WSAGetLastError();
	}
// else NSLog(@"EVENTS 0x%x on %p", events.lNetworkEvents, self);

      if ([self streamStatus] == NSStreamStatusOpening)
	{
	  [self _unschedule];
	  if (error == 0)
	    {
	      socklen_t len = sizeof(error);

	      getReturn = getsockopt(_sock, SOL_SOCKET, SO_ERROR,
		(char*)&error, &len);
	    }

	  if (getReturn >= 0 && error == 0
	    && (events.lNetworkEvents & FD_CONNECT))
	    { // finish up the opening
	      events.lNetworkEvents ^= FD_CONNECT;
	      _passive = YES;
	      [self open];
	      // notify sibling
	      if (_sibling)
		{
		  [_sibling open];
		  [_sibling _sendEvent: NSStreamEventOpenCompleted];
		}
	      [self _sendEvent: NSStreamEventOpenCompleted];
	    }
	}

      if (error != 0)
	{
	  errno = error;
	  [self _recordError];
	  [_sibling _recordError];
	  [self _sendEvent: NSStreamEventErrorOccurred];
	  [_sibling _sendEvent: NSStreamEventErrorOccurred];
	}
      else
	{
	  if (events.lNetworkEvents & FD_WRITE)
	    {
	      /* Clear NSStreamStatusWriting if it was set */
	      [self _setStatus: NSStreamStatusOpen];
	    }

	  /* On winsock a socket is always writable unless it has had
	   * failure/closure or a write blocked and we have not been
	   * signalled again.
	   */
	  while ([self _unhandledData] == NO && [self hasSpaceAvailable])
	    {
	      [self _sendEvent: NSStreamEventHasSpaceAvailable];
	    }

	  if (events.lNetworkEvents & FD_READ)
	    {
	      [_sibling _setStatus: NSStreamStatusOpen];
	      while ([_sibling hasBytesAvailable]
		&& [_sibling _unhandledData] == NO)
		{
	          [_sibling _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents & FD_CLOSE)
	    {
	      [self _setClosing: YES];
	      [_sibling _setClosing: YES];
	      while ([_sibling hasBytesAvailable]
		&& [_sibling _unhandledData] == NO)
		{
		  [_sibling _sendEvent: NSStreamEventHasBytesAvailable];
		}
	    }
	  if (events.lNetworkEvents == 0)
	    {
	      [self _sendEvent: NSStreamEventHasSpaceAvailable];
	    }
	}
    }
#else
  NSStreamEvent myEvent;

  if ([self streamStatus] == NSStreamStatusOpening)
    {
      int error;
      socklen_t len = sizeof(error);
      int result;

      IF_NO_GC([[self retain] autorelease];)
      [self _schedule];
      result
	= getsockopt((intptr_t)_loopID, SOL_SOCKET, SO_ERROR, &error, &len);
      if (result >= 0 && !error)
        { // finish up the opening
          myEvent = NSStreamEventOpenCompleted;
          _passive = YES;
          [self open];
          // notify sibling
          [_sibling open];
          [_sibling _sendEvent: myEvent];
        }
      else // must be an error
        {
          if (error)
            errno = error;
          [self _recordError];
          myEvent = NSStreamEventErrorOccurred;
          [_sibling _recordError];
          [_sibling _sendEvent: myEvent];
        }
    }
  else if ([self streamStatus] == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      myEvent = NSStreamEventHasSpaceAvailable;
    }
  [self _sendEvent: myEvent];
#endif
}

#if	defined(__MINGW32__)
- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  *trigger = YES;
  if ([self _unhandledData] == YES && [self streamStatus] == NSStreamStatusOpen)
    {
      /* In winsock, a writable status is only signalled if an earlier
       * write failed (because it would block), so we must simulate the
       * writable event by having the run loop trigger without blocking.
       */
      return NO;
    }
  return YES;
}
#endif

@end

@implementation GSSocketServerStream

+ (void) initialize
{
  if (self == [GSSocketServerStream class])
    {
      GSObjCAddClassBehavior(self, [GSSocketStream class]);
    }
}

- (Class) _inputStreamClass
{
  [self subclassResponsibility: _cmd];
  return Nil;
}

- (Class) _outputStreamClass
{
  [self subclassResponsibility: _cmd];
  return Nil;
}

#define SOCKET_BACKLOG 256

- (void) open
{
  int bindReturn;
  int listenReturn;
  SOCKET s;

  if (_currentStatus != NSStreamStatusNotOpen)
    {
      NSDebugMLLog(@"NSStream",
        @"Attempt to re-open stream %@", self);
      return;
    }

  s = socket(_address->sa_family, SOCK_STREAM, 0);
  if (BADSOCKET(s))
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  else
    {
      [(GSSocketStream*)self _setSock: s];
    }

#ifndef	BROKEN_SO_REUSEADDR
  if (_address->sa_family == AF_INET
#ifdef  AF_INET6
    || _address->sa_family == AF_INET6
#endif
  )
    {
      /*
       * Under decent systems, SO_REUSEADDR means that the port can be reused
       * immediately that this process exits.  Under some it means
       * that multiple processes can serve the same port simultaneously.
       * We don't want that broken behavior!
       */
      int	status = 1;

      setsockopt([self _sock], SOL_SOCKET, SO_REUSEADDR,
        (char *)&status, sizeof(status));
    }
#endif

  bindReturn = bind([self _sock], _address, GSPrivateSockaddrLength(_address));
  if (socketError(bindReturn))
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
  listenReturn = listen([self _sock], SOCKET_BACKLOG);
  if (socketError(listenReturn))
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
      return;
    }
#if	defined(__MINGW32__)
  WSAEventSelect(_sock, _loopID, FD_ALL_EVENTS);
#endif
  [super open];
}

- (void) close
{
#if	defined(__MINGW32__)
  if (_loopID != WSA_INVALID_EVENT)
    {
      WSACloseEvent(_loopID);
    }
  if (_sock != INVALID_SOCKET)
    {
      closesocket(_sock);
      [super close];
      _loopID = WSA_INVALID_EVENT;
    }
#else
  if (_loopID != (void*)(intptr_t)-1)
    {
      close((intptr_t)_loopID);
      [super close];
      _loopID = (void*)(intptr_t)-1;
    }
#endif
  _sock = INVALID_SOCKET;
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
  GSSocketStream *ins = AUTORELEASE([[self _inputStreamClass] new]);
  GSSocketStream *outs = AUTORELEASE([[self _outputStreamClass] new]);
  uint8_t		buf[BUFSIZ];
  struct sockaddr	*addr = (struct sockaddr*)buf;
  socklen_t		len = sizeof(buf);
  int			acceptReturn;

  acceptReturn = accept([self _sock], addr, &len);
  _events &= ~NSStreamEventHasBytesAvailable;
  if (socketError(acceptReturn))
    { // test for real error
      if (!socketWouldBlock())
	{
          [self _recordError];
	}
      ins = nil;
      outs = nil;
    }
  else
    {
      // no need to connect again
      [ins _setPassive: YES];
      [outs _setPassive: YES];
      // copy the addr to outs
      [ins _setAddress: addr];
      [outs _setAddress: addr];
      [ins _setSock: acceptReturn];
      [outs _setSock: acceptReturn];
    }
  if (inputStream)
    {
      [ins _setSibling: outs];
      *inputStream = (NSInputStream*)ins;
    }
  if (outputStream)
    {
      [outs _setSibling: ins];
      *outputStream = (NSOutputStream*)outs;
    }
}

- (void) _dispatch
{
#if	defined(__MINGW32__)
  WSANETWORKEVENTS events;
  
  if (WSAEnumNetworkEvents(_sock, _loopID, &events) == SOCKET_ERROR)
    {
      errno = WSAGetLastError();
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
    }
  else if (events.lNetworkEvents & FD_ACCEPT)
    {
      events.lNetworkEvents ^= FD_ACCEPT;
      [self _setStatus: NSStreamStatusReading];
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
#else
  NSStreamEvent myEvent;

  [self _setStatus: NSStreamStatusOpen];
  myEvent = NSStreamEventHasBytesAvailable;
  [self _sendEvent: myEvent];
#endif
}

@end



@implementation GSInetInputStream

- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  if ((self = [super init]) != nil)
    {
      if ([self _setSocketAddress: addr port: port family: AF_INET] == NO)
        {
          DESTROY(self);
        }
    }
  return self;
}

@end

@implementation GSInet6InputStream
#if	defined(AF_INET6)

- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  if ((self = [super init]) != nil)
    {
      if ([self _setSocketAddress: addr port: port family: AF_INET6] == NO)
        {
          DESTROY(self);
        }
    }
  return self;
}

#else
- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  RELEASE(self);
  return nil;
}
#endif
@end

@implementation GSInetOutputStream

- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  if ((self = [super init]) != nil)
    {
      if ([self _setSocketAddress: addr port: port family: AF_INET] == NO)
        {
          DESTROY(self);
        }
    }
  return self;
}

@end

@implementation GSInet6OutputStream
#if	defined(AF_INET6)

- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  if ((self = [super init]) != nil)
    {
      if ([self _setSocketAddress: addr port: port family: AF_INET6] == NO)
        {
          DESTROY(self);
        }
    }
  return self;
}

#else
- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  RELEASE(self);
  return nil;
}
#endif
@end

@implementation GSInetServerStream

- (Class) _inputStreamClass
{
  return [GSInetInputStream class];
}

- (Class) _outputStreamClass
{
  return [GSInetOutputStream class];
}

- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  if ((self = [super init]) != nil)
    {
      if ([addr length] == 0)
        {
          addr = @"0.0.0.0";
        }
      if ([self _setSocketAddress: addr port: port family: AF_INET] == NO)
        {
          DESTROY(self);
        }
    }
  return self;
}

@end

@implementation GSInet6ServerStream
#if	defined(AF_INET6)
- (Class) _inputStreamClass
{
  return [GSInet6InputStream class];
}

- (Class) _outputStreamClass
{
  return [GSInet6OutputStream class];
}

- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  if ([super init] != nil)
    {
      if ([addr length] == 0)
        {
          addr = @"0:0:0:0:0:0:0:0";   /* Bind on all addresses */
        }
      if ([self _setSocketAddress: addr port: port family: AF_INET6] == NO)
        {
          DESTROY(self);
        }
    }
  return self;
}
#else
- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
  RELEASE(self);
  return nil;
}
#endif
@end

