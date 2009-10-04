/** callframe.m - Wrapper/Objective-C interface for ffcall function interface

   Copyright (C) 2000, Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Created: Nov 2000

   This file is part of the GNUstep Base Library.

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
#include <stdlib.h>
#ifdef HAVE_ALLOCA_H
#include <alloca.h>
#endif

#include "callframe.h"
#include "Foundation/NSException.h"
#include "Foundation/NSData.h"
#include "Foundation/NSDebug.h"
#include "GSInvocation.h"

#if defined(ALPHA) || (defined(MIPS) && (_MIPS_SIM == _ABIN32))
typedef long long smallret_t;
#else
typedef int smallret_t;
#endif

callframe_t *
callframe_from_info (NSArgumentInfo *info, int numargs, void **retval)
{
  unsigned      size = sizeof(callframe_t);
  unsigned      align = __alignof(double);
  unsigned      offset = 0;
  void          *buf;
  int           i;
  callframe_t   *cframe;

  if (numargs > 0)
    {
      if (size % align != 0)
        {
          size += align - (size % align);
        }
      offset = size;
      size += numargs * sizeof(void*);
      if (size % align != 0)
        {
          size += (align - (size % align));
        }
      for (i = 0; i < numargs; i++)
        {
          size += info[i+1].size;

          if (size % align != 0)
            {
              size += (align - size % align);
            }
        }
    }

  /*
   * If we need space allocated to store a return value,
   * make room for it at the end of the callframe so we
   * only need to do a single malloc.
   */
  if (retval)
    {
      unsigned	full = size;
      unsigned	pos;

      if (full % align != 0)
	{
	  full += (align - full % align);
	}
      pos = full;
      full += MAX(info[0].size, sizeof(smallret_t));
#if	GS_WITH_GC
      cframe = buf = NSAllocateCollectable(full, NSScannedOption);
#else
      cframe = buf = NSZoneCalloc(NSDefaultMallocZone(), full, 1);
#endif
      if (cframe)
	{
	  *retval = buf + pos;
	}
    }
  else
    {
#if	GS_WITH_GC
      cframe = buf = NSAllocateCollectable(size, NSScannedOption);
#else
      cframe = buf = NSZoneCalloc(NSDefaultMallocZone(), size, 1);
#endif
    }

  if (cframe)
    {
      cframe->nargs = numargs;
      cframe->args = buf + offset;
      offset += numargs * sizeof(void*);
      if (offset % align != 0)
        {
          offset += align - (offset % align);
        }
      for (i = 0; i < cframe->nargs; i++)
        {
          cframe->args[i] = buf + offset;

          offset += info[i+1].size;

          if (offset % align != 0)
            {
              offset += (align - offset % align);
            }
        }
    }

  return cframe;
}

void
callframe_set_arg(callframe_t *cframe, int index, void *buffer, int size)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(cframe->args[index], buffer, size);
}

void
callframe_get_arg(callframe_t *cframe, int index, void *buffer, int size)
{
  if (index < 0 || index >= cframe->nargs)
     return;
  memcpy(buffer, cframe->args[index], size);
}

void *
callframe_arg_addr(callframe_t *cframe, int index)
{
  if (index < 0 || index >= cframe->nargs)
     return NULL;
  return cframe->args[index];
}

