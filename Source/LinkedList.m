/* Implementation for Objective-C LinkedList collection object
   Copyright (C) 1993, 1994, 1995, 1996 Free Software Foundation, Inc.

   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

   This file is part of the GNU Objective C Class Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/ 

#include <objects/LinkedList.h>
#include <objects/IndexedCollectionPrivate.h>
#include <objects/Coder.h>

@implementation LinkedList

/* This is the designated initializer of this class */
- init
{
  _count = 0;
  _first_link = nil;
  _last_link = nil;
  return self;
}

- initWithObjects: (id*)objs count: (unsigned)c
{
  [self init];
  while (c--)
    [self prependObject: objs[c]];
}

/* Archiving must mimic the above designated initializer */

- _initCollectionWithCoder: aCoder
{
  [super _initCollectionWithCoder:aCoder];
  _count = 0;
  _first_link = nil;
  _last_link = nil;
  return self;
}

- (void) _encodeContentsWithCoder: (id <Encoding>)aCoder
{
  [aCoder startEncodingInterconnectedObjects];
  [super _encodeContentsWithCoder:aCoder];
  [aCoder finishEncodingInterconnectedObjects];
}

/* xxx See Collection _decodeContentsWithCoder:.
   We shouldn't do an -addElement.  finishEncodingInterconnectedObjects
   should take care of all that. */

- (void) _decodeContentsWithCoder: (id <Decoding>)aCoder
{
  [aCoder startDecodingInterconnectedObjects];
  [super _decodeContentsWithCoder:aCoder];
  [aCoder finishDecodingInterconnectedObjects];
}

/* Empty copy must empty an allocCopy'ed version of self */
- emptyCopy
{
  LinkedList *copy = [super emptyCopy];
  copy->_first_link = nil;
  copy->_last_link = nil;
  copy->_count = 0;
  return copy;
}

/* This must work without sending any messages to content objects */
- (void) _empty
{
  _count = 0;
  _first_link = nil;
  _last_link = nil;
}

/* These next four methods are the only ones that change the values of
   the instance variables _count, _first_link, except for
   "-init". */

- (void) removeObject: oldObject
{
  assert ([oldObject linkedList] == self);
  if (_first_link == oldObject)
    {
      if (_count > 1)
	_first_link = [oldObject nextLink];
      else
	_first_link = nil;
    }
  else
    [[oldObject prevLink] setNextLink:[oldObject nextLink]];
  if (_last_link == oldObject)
    {
      if (_count > 1)
	_last_link = [oldObject prevLink];
      else
	_first_link = nil;
    }
  else
    [[oldObject nextLink] setPrevLink:[oldObject prevLink]];
  _count--;
  [oldObject setNextLink: NO_OBJECT];
  [oldObject setPrevLink: NO_OBJECT];
  [oldObject release];
}
  
- (void) insertObject: newObject after: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Insert it. */
  if (_count == 0)
    {
      _first_link = newObject;
      _last_link = newObject;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    {
      if (oldObject == _last_link)
	_last_link = newObject;
      [newObject setNextLink: [oldObject nextLink]];
      [newObject setPrevLink: oldObject];
      [[oldObject nextLink] setPrevLink: newObject];
      [oldObject setNextLink: newObject];
    }
  _count++;
}

- (void) insertObject: newObject before: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Insert it. */
  if (_count == 0)
    {
      _first_link = newObject;
      _last_link = newObject;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    {
      if (oldObject == _first_link)
	_first_link = newObject;
      [newObject setPrevLink: [oldObject prevLink]];
      [newObject setNextLink: oldObject];
      [[oldObject prevLink] setNextLink: newObject];
      [oldObject setPrevLink: newObject];
    }
  _count++;
}

- (void) replaceObject: oldObject with: newObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Do the replacement. */
  if (oldObject == _first_link)
    _first_link = newObject;
  [newObject setNextLink:[oldObject nextLink]];
  [newObject setPrevLink:[oldObject prevLink]];
  [[oldObject prevLink] setNextLink:newObject];
  [[oldObject nextLink] setPrevLink:newObject];

  /* Release ownership of the oldObject. */
  [oldObject setNextLink: NO_OBJECT];
  [oldObject setPrevLink: NO_OBJECT];
  [oldObject setLinkedList: NO_OBJECT];
  [oldObject release];
}

/* End of methods that change the instance variables. */


- (void) appendObject: newObject
{
  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Insert it. */
  if (_count == 0)
    {
      _first_link = newObject;
      _last_link = newObject;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    [self insertObject: newObject after: _last_link];
}

- prependElement: newObject
{
  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Insert it. */
  if (_count == 0)
    {
      _first_link = newObject;
      _last_link = newObject;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else
    [self insertObject: newObject before: _first_link];
}

- insertElement: newObject atIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, (_count+1));

  /* Make sure no one else already owns the newObject. */
  assert ([newObject linkedList] == NO_OBJECT);

  /* Claim ownership of the newObject. */
  [newObject retain];
  [newObject setLinkedList: self];

  /* Insert it. */
  if (_count == 0)
    {
      _first_link = newObject;
      _last_link = newObject;
      [newObject setNextLink: NO_OBJECT];
      [newObject setPrevLink: NO_OBJECT];
    }
  else if (index == _count)
    [self insertObject: newObject after: _last_link];
  else
    [self insertObject:newObject before: [self objectAtIndex: index]];
  return self;
}

- (void) removeObjectAtIndex: (unsigned)index
{
  CHECK_INDEX_RANGE_ERROR(index, _count);
  [self removeObject: [self objectAtIndex: index]];
}

- objectAtIndex: (unsigned)index
{
  id <LinkedListComprising> link;

  CHECK_INDEX_RANGE_ERROR(index, _count);

  if (index < _count / 2)
    for (link = _first_link;
	 index;
	 link = [link nextLink], index--)
      ;
  else
    for (link = _last_link, index = _count - index - 1;
	 index;
	 link = [link prevLink], index--)
      ;
  return link;
}

- firstObject
{
  return _first_link;
}

- lastObject
{
  return _last_link;
}

- successorOfObject: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  return [oldObject nextLink];
}

- predecessorOfObject: oldObject
{
  /* Make sure we actually own the oldObject. */
  assert ([oldObject linkedList] == self);

  return [oldObject prevLink];
}

- nextObjectWithEnumState: (void**)enumState
{
  /* *enumState points to the next object to be returned. */
  id ret;

  if (*enumState == _first_link)
    return NO_OBJECT;
  else if (!(*enumState))
    *enumState = _first_link;
  ret = (id) *enumState;
  *enumState = [(id)(*enumState) nextLink];
  return ret;
}

- prevObjectWithEnumState: (void**)enumState
{
  id ret;

  if (*enumState == _last_link)
    return NO_OBJECT;
  else if (!(*enumState))
    *enumState = _last_link;
  ret = (id) *enumState;
  *enumState = [(id)(*enumState) prevLink];
  return ret;
}

- (unsigned) count
{
  return _count;
}

@end



