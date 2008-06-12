/* Test that the compiler supports the -fconstant-string-class option
   Copyright (C) 2001 Free Software Foundation, Inc.

   Written by: Nicola Pero <nicola@brainstorm.co.uk>
   Created: June 2001

   This file is part of the GNUstep Base Library.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
*/

/* must be compiled compile using -fconstant-string-class=NSConstantString
   as an option to gcc.  If it doesn't work, it means your gcc doesn't
   support this option. */

#include <objc/objc.h>
#include <objc/Object.h>

/* Define our custom constant string class */
@interface FooConstantString : Object
{
   char *c_string;
   unsigned int len;
}
- (char *) customString;
@end

#ifdef NeXT_RUNTIME
/* This structure shouldn't be seen outside the compiler.
   See Apple Radar 2870817 and the memcpy() in main(). */
struct objc_class _FooConstantStringClassReference;
#endif

@implementation FooConstantString
- (char *) customString
{
    return c_string;
}
@end


int main (int argc, char **argv)
{
   /* Create a test constant string */
   FooConstantString *string = @"Antonio Valente";

#ifdef NeXT_RUNTIME
   /* This memcpy is needed here due to a bug in ObjC gcc when using
      next runtime. It has to be done once per program and before
      the first message is sent to a constant string. Can't be moved to
      the constant string's +initialize since this is already a message.
      See Apple Radar 2870817 */
   memcpy(&_FooConstantStringClassReference,
          objc_getClass("FooConstantString"),
          sizeof(_FooConstantStringClassReference));
#endif

   /* Check that it really works */
   if (strcmp ([string customString], "Antonio Valente"))
     {
       abort ();
     }

   /* Do another, more direct test. */
   if (strcmp ([@"Jump" customString], "Jump"))
       {
         abort ();
       }
   return 0;
}

