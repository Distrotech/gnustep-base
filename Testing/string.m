#include <Foundation/NSString.h>

// Fri Oct 23 02:58:47 MET DST 1998 	dave@turbocat.de
// cStringNoCopy -> cString

/* For demo of Strings as Collections of char's. */
#include <Foundation/NSString.h>
#include    <Foundation/NSAutoreleasePool.h>

void
print_string(NSString* s)
{
  printf("The string [%s], length %d\n", [s cString], [s length]);
}

#include <Foundation/NSString.h>


int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  id s = @"This is a test string";
  id s2, s3;

  print_string(s);

  s2 = [s copy];
  print_string(s2);
  s3 = [s2 mutableCopy];
  [s2 release];
  s2 = [s3 copy];
  [s3 release];
  [s2 release];

  s2 = [s copyWithZone: NSDefaultMallocZone ()];
  print_string(s2);

  s2 = [s stringByAppendingString:@" with something added"];
  print_string(s2);

  s2 = [s mutableCopy];
  [s2 replaceCharactersInRange:((NSRange){10,4})
      withString:@"changed"];
  print_string(s2);

  /* Test the use of the `%@' format directive. */
  s2 = [NSString stringWithFormat: @"foo %@ bar",
		 @"test"];
  print_string(s2);

#if 0
  /* An example of treating a string like a Collection:  
     Increment each char. */
  {
    id s3;
    void rot13(elt c)
      {
	[s3 appendElement:(char)(c.char_u + 1)];
      }

    s3 = [NSMutableString stringWithCapacity:[s2 length]];
    [s2 withElementsCall:rot13];
    print_string(s3);
  }
#endif  

  [arp release];
  exit(0);
}
