/* Simple benchmark program.
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Modified:	Richard Frith-Macdonald <richard@brainstorm.co.uk>

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

#include <stdio.h>
#include <Foundation/Foundation.h>
#include <objc/Object.h>

#define MAX_COUNT 100000

#define START_TIMER sTime = [NSDate date]
#define END_TIMER eTime = [NSDate date]
#define PRINT_TIMER(str) printf("  %-20s\t %6.3f \t %6.3f\n", str, \
			[eTime timeIntervalSinceDate: sTime], \
			[eTime timeIntervalSinceDate: sTime]/baseline)

#define AUTO_START id pool = [NSAutoreleasePool new]
#define AUTO_END   [pool release]

NSDate	*sTime = nil;
NSDate	*eTime = nil;
/* Set to a baseline to null out speed of runtime */
NSTimeInterval baseline = 0.0;

NSZone	*myZone;
Class	rootClass;
Class	stringClass;
IMP	cstring;

void
bench_object()
{
  int i;
  id obj;
  AUTO_START;

  START_TIMER;
  for (i = 0; i < MAX_COUNT*10; i++)
    {
      id i = [rootClass class];
    }
  END_TIMER;
  baseline = [eTime timeIntervalSinceDate: sTime];
  PRINT_TIMER("Baseline: method call");

  START_TIMER;
  for (i = 0; i < MAX_COUNT*10; i++)
    {
      id i = [NSObject class];
    }
  END_TIMER;
  PRINT_TIMER("Class: overhead      ");

  START_TIMER;
  myZone = NSCreateZone(2048, 2048, 1);
  for (i = 0; i < MAX_COUNT; i++)
    {
      void	*mem = NSZoneMalloc(myZone, 32);
      NSZoneFree(myZone, mem);
    }
  NSRecycleZone(myZone);
  END_TIMER;
  PRINT_TIMER("Function: zone alloc ");

  START_TIMER;
  myZone = NSCreateZone(2048, 2048, 0);
  for (i = 0; i < MAX_COUNT; i++)
    {
      void	*mem = NSZoneMalloc(myZone, 32);
      NSZoneFree(myZone, mem);
    }
  NSRecycleZone(myZone);
  END_TIMER;
  PRINT_TIMER("Function: zone2alloc ");

  myZone = NSDefaultMallocZone();
  START_TIMER;
  for (i = 0; i < MAX_COUNT; i++)
    {
      void	*mem = NSZoneMalloc(myZone, 32);
      NSZoneFree(myZone, mem);
    }
  END_TIMER;
  PRINT_TIMER("Function: def alloc  ");

  START_TIMER;
  myZone = NSCreateZone(2048, 2048, 1);
  for (i = 0; i < MAX_COUNT; i++)
    {
      obj = [[rootClass allocWithZone: myZone] init];
      [obj release];
    }
  NSRecycleZone(myZone);
  END_TIMER;
  PRINT_TIMER("NSObject: zone alloc ");

  START_TIMER;
  myZone = NSCreateZone(2048, 2048, 0);
  for (i = 0; i < MAX_COUNT; i++)
    {
      obj = [[rootClass allocWithZone: myZone] init];
      [obj release];
    }
  NSRecycleZone(myZone);
  END_TIMER;
  PRINT_TIMER("NSObject: zone2alloc ");

  myZone = NSDefaultMallocZone();
  START_TIMER;
  for (i = 0; i < MAX_COUNT; i++)
    {
      obj = [[rootClass allocWithZone: myZone] init];
      [obj release];
    }
  END_TIMER;
  PRINT_TIMER("NSObject: def alloc  ");

  START_TIMER;
  for (i = 0; i < MAX_COUNT*10; i++)
    {
      BOOL dummy = [rootClass instancesRespondToSelector: @selector(hash)];
    }
  END_TIMER;
  PRINT_TIMER("ObjC: method/sel     ");

  AUTO_END;
}

bench_array()
{
  int i;
  id array;
  NSString	*strings[MAX_COUNT];
 
  AUTO_START;
  for (i = 0; i < MAX_COUNT; i++)
    {
      char buf1[100];
      sprintf(buf1, "str%0d", i);
      strings[i] = [stringClass stringWithCString: buf1];
    }
  printf("NSArray\n");
  array = [NSMutableArray arrayWithCapacity: 16];
  START_TIMER;
  for (i = 0; i < MAX_COUNT*10; i++)
    {
      [array addObject: strings[i/10]];
    }
  END_TIMER;
  PRINT_TIMER("NSArray (addObject:) ");

  START_TIMER;
  for (i = 0; i < MAX_COUNT/100; i++)
    {
      [array indexOfObject: strings[i]];
    }
  END_TIMER;
  PRINT_TIMER("NSArray (indexOfObj)");

  START_TIMER;
  for (i = 0; i < MAX_COUNT/100; i++)
    {
      [array indexOfObjectIdenticalTo: strings[i]];
    }
  END_TIMER;
  PRINT_TIMER("NSArray (indexIdent)");

  START_TIMER;
  for (i = 0; i < 1; i++)
    {
      [array makeObjectsPerformSelector: @selector(hash)];
    }
  END_TIMER;
  PRINT_TIMER("NSArray (perform)   ");
  AUTO_END;
}

bench_dict()
{
  int i;
  NSMutableDictionary *dict;
  id obj2;
  NSString	*keys[MAX_COUNT/10];
  NSString	*vals[MAX_COUNT/10];
 
  AUTO_START;
  for (i = 0; i < MAX_COUNT/10; i++)
    {
      char buf1[100], buf2[100];
      sprintf(buf1, "key%0d", i);
      sprintf(buf2, "val%0d", i);
      keys[i] = [stringClass stringWithCString: buf1];
      vals[i] = [stringClass stringWithCString: buf2];
    }
  printf("NSDictionary\n");
  dict = [NSMutableDictionary dictionaryWithCapacity: 16];
  START_TIMER;
  for (i = 0; i < MAX_COUNT/10; i++)
    {
      int j;

      for (j = 0; j < 10; j++)
	{
          [dict setObject: vals[i] forKey: keys[i]];
	}
    }
  END_TIMER;
  PRINT_TIMER("NSDict (setObject:) ");

  START_TIMER;
  for (i = 0; i < MAX_COUNT; i++)
    {
      int j;

      for (j = 0; j < 10; j++)
        {
          id dummy = [dict objectForKey: keys[i/10]];
        }
    }
  END_TIMER;
  PRINT_TIMER("NSDict (objectFor:) ");

  START_TIMER;
  for (i = 0; i < MAX_COUNT*10; i++)
    {
      int dummy = [dict count];
    }
  END_TIMER;
  PRINT_TIMER("NSDictionary (count)");

  obj2 = [dict copy];
  START_TIMER;
  for (i = 0; i < 10; i++)
    {
      BOOL dummy = [dict isEqual: obj2];
    }
  END_TIMER;
  PRINT_TIMER("NSDict (isEqual:)   ");
  AUTO_END;
}

bench_str()
{
  int i;
  NSString *str;
  id plist;
  NSString *plstr;
  Class	arc = [NSArchiver class];
  Class	una = [NSUnarchiver class];
  Class	ser = [NSSerializer class];
  Class	des = [NSDeserializer class];
  Class md = [NSMutableDictionary class];

  AUTO_START;

  plist = [NSDictionary dictionaryWithObjectsAndKeys:
	@"Value1", @"Key1",
	@"", @"Key2",
	[NSArray array], @"Key3",
	[NSArray arrayWithObjects:
	    @"Array1 entry1",
	    @"Array1 entry2",
	    [NSArray arrayWithObjects:
		@"Array2 entry1",
		@"Array2 entry2",
		nil],
	    [NSDictionary dictionary],
	    [NSDictionary dictionaryWithObjectsAndKeys:
		@"Value", @"Key",
		nil],
	    nil], @"Key4",
	[NSDictionary dictionary], @"Key5",
	[NSDictionary dictionaryWithObjectsAndKeys:
	    @"Value", @"Key",
	    nil], @"Key6",
	[NSData data], @"Key7",
	[NSData dataWithBytes: "hello" length: 5], @"Key8",
	nil];
  plstr = [plist description];
 
  printf("NSString\n");
  START_TIMER;
  for (i = 0; i < MAX_COUNT; i++)
    {
      str = [stringClass stringWithCString: "hello world"];
    }
  END_TIMER;
  PRINT_TIMER("NSString (cstring:) ");

  START_TIMER;
  for (i = 0; i < MAX_COUNT*10; i++)
    {
      int dummy = [str length];
    }
  END_TIMER;
  PRINT_TIMER("NSString (length)   ");

  START_TIMER;
  for (i = 0; i < MAX_COUNT/100; i++)
    {
      id arp = [NSAutoreleasePool new];
      NSString	*s = [plist description];
      [arp release];
    }
  END_TIMER;
  PRINT_TIMER("NSString (mkplist) ");

  START_TIMER;
  for (i = 0; i < MAX_COUNT/1000; i++)
    {
      id p = [plstr propertyList];
    }
  END_TIMER;
  PRINT_TIMER("NSString (plparse)");

  START_TIMER;
  for (i = 0; i < MAX_COUNT/1000; i++)
    {
      id arp = [NSAutoreleasePool new];
      NSString	*s = [plist description];
      id p = [s propertyList];
      if ([p isEqual: plist] == NO)
	printf("Argh 1\n");
      if ([s isEqual: plstr] == NO)
	printf("Argh 2\n");
      [arp release];
    }
  END_TIMER;
  PRINT_TIMER("NSString (plcomp)");

  START_TIMER;
  for (i = 0; i < MAX_COUNT/100; i++)
    {
      NSData	*d = [ser serializePropertyList: plist];
      id 	p = [des deserializePropertyListFromData: d
				       mutableContainers: NO];
    }
  END_TIMER;
  PRINT_TIMER("NSString (ser/des)");

  START_TIMER;
  for (i = 0; i < MAX_COUNT/100; i++)
    {
      NSData	*d = [arc archivedDataWithRootObject: plist];
      id 	p = [una unarchiveObjectWithData: d];
    }
  END_TIMER;
  PRINT_TIMER("NSString (arc/una)");

  AUTO_END;
}

bench_data()
{
  int i;
  id d, o;
  AUTO_START;
  Class	dataClass = [NSData class];

  printf("NSData\n");
  START_TIMER;
  for (i = 0; i < MAX_COUNT/10; i++)
    { 
      d = [[dataClass alloc] initWithContentsOfFile:@"benchmark.m"];
      [d length];
      o = [d copy];
      [o release];
      o = [d mutableCopy];
      [o release];
      [d release];
    }
  END_TIMER;
  PRINT_TIMER("NSData (various)    ");
  AUTO_END;
}

int main(int argc, char *argv[], char **env)
{
  id pool;

#if 0 || LIB_FOUNDATION_LIBRARY
   [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  /*
   *	Cache classes to remove overhead of objc runtime class lookup from 
   *	the benchmark.
   */
  rootClass = [NSObject class];
  stringClass = [NSString class];
 
  pool = [NSAutoreleasePool new];
  printf(" Test         	\t time (sec) \t index\n");
  bench_object();
  bench_str();
  bench_array();
  bench_dict();
  bench_data();
  AUTO_END;
  return 0;
}

