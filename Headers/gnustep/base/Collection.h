/* Interface for Objective-C Collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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

/* This is the abstract superclass that satisfies the Collecting
   protocol, without using any instance variables.
*/

#ifndef __Collection_h_GNUSTEP_BASE_INCLUDE
#define __Collection_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <Foundation/NSObject.h>
#include <base/Collecting.h>
#include <base/preface.h>
#include <base/Coding.h>

@interface ConstantCollection : NSObject <ConstantCollecting>
- printForDebugger;  /* This method will disappear later. */
@end

@interface Collection : ConstantCollection <Collecting>
@end

@interface Enumerator : NSObject <Enumerating>
{
  id collection;
  void *enum_state;
}
@end

#define FOR_COLLECTION(ACOLL, ELT) \
{ \
   void *_es = [ACOLL newEnumState]; \
   while ((ELT = [ACOLL nextObjectWithEnumState: &_es])) \
     {

#define END_FOR_COLLECTION(ACOLL) \
     } \
   [ACOLL freeEnumState: &_es]; \
}

#define FOR_COLLECTION_WHILE_TRUE(ACOLL, ELT, FLAG) \
{ \
   void *_es = [ACOLL newEnumState]; \
   while (FLAG && (ELT = [ACOLL nextObjectWithEnumState: &_es])) \
     {

#define END_FOR_COLLECTION_WHILE_TRUE(ACOLL) \
     } \
   [ACOLL freeEnumState: &_es]; \
}

/* The only subclassResponsibilities in Collection are:

      addElement:
      removeElement:
      getNextElement:withEnumState:
      empty

   But subclasses may need to override the following for correctness:

      contentType
      comparisonFunction

   but subclasses will want to override others as well in order to 
   increase efficiency, especially:

      count

   and perhaps:

      includesElement:
      occurrencesOfElement:
      uniqueContents
      withElementsCall:whileTrue:
      withElementsCall:
      isEmpty
      releaseObjects

*/

#endif /* __Collection_h_GNUSTEP_BASE_INCLUDE */

