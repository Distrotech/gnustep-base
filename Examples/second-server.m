#include "second-server.h"
#include "second-client.h"
#include <objects/Connection.h>
#include <objects/String.h>
#include <objects/Notification.h>

@implementation SecondServer

- init
{
  [super init];
  array = [[Array alloc] init];
  return self;
}

- addRemoteObject: o
{
  const char *s;
  [array addObject:o];

  /* This next line is a callback */
  s = [o appellation];
  printf("Added remote object with appellation %s\n", s);

  /* Free it because the remote messaging system malloc'ed it for us,
     and we don't need it anymore. */
  (*objc_free)((void*)s);
  return self;
}

- array
{
  return array;
}

- (Connection*) connection: ancestor didConnect: newConn
{
  printf(">>>>New connection 0x%x created\n", (unsigned)newConn);
  [NotificationDispatcher
    addObserver: self
    selector: @selector(connectionBecameInvalid:)
    name: ConnectionBecameInvalidNotification
    object: newConn];
  [newConn setDelegate: self];
  return newConn;
}

- connectionBecameInvalid: notification
{
  id sender = [notification object];
  if ([sender isKindOf:[Connection class]])
    {
      id remotes = [sender proxies];
      int remotesCount = [remotes count];
      int arrayCount = [array count];
      int i, j;

      printf(">>> Connection 0x%x invalidated\n", (unsigned)sender);

      /* This contortion avoids Array's calling -isEqual: on the proxy */
      for (j = 0; j < remotesCount; j++)
	for (i = 0; i < arrayCount; i++)
	  if ([remotes objectAtIndex:j] == [array objectAtIndex:i])
	    {
	      printf("removing remote proxy from the list\n");
	      [array removeObjectAtIndex:j];
	      break;
	    }
      [remotes release];
    }
  else
    {
      [self error:"non-Connection sent invalidation"];
    }
  return self;
}

@end

int main(int argc, char *argv[])
{
  id s;
  id c;

  s = [[SecondServer alloc] init];

  c = [Connection newRegisteringAtName:@"secondserver" withRootObject:s];
  printf("Regsitered server object on localhost with name `secondserver'\n");

  [c setDelegate:s];
  [NotificationDispatcher
    addObserver: s
    selector: @selector(connectionBecameInvalid:)
    name: ConnectionBecameInvalidNotification
    object: c];

  [c runConnection];

  exit(0);
}
