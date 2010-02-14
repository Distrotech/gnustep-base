/** Implementation of NSBundle class
   Copyright (C) 1993-2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: May 1993

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
   Date: October 2000  Added frameworks support

   Author: Nicola Pero <nicola@brainstorm.co.uk>

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


   <title>NSBundle class reference</title>
   $Date$ $Revision$
*/

#include "config.h"
#define	EXPOSE_NSBundle_IVARS	1
#include "GNUstepBase/preface.h"
#include "objc-load.h"
#include "Foundation/NSBundle.h"
#include "Foundation/NSException.h"
#include "Foundation/NSString.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSDictionary.h"
#include "Foundation/NSEnumerator.h"
#include "Foundation/NSProcessInfo.h"
#include "Foundation/NSObjCRuntime.h"
#include "Foundation/NSUserDefaults.h"
#include "Foundation/NSNotification.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSFileManager.h"
#include "Foundation/NSPathUtilities.h"
#include "Foundation/NSData.h"
#include "Foundation/NSValue.h"
#import "GNUstepBase/NSString+GNUstepBase.h"

#include "GSPrivate.h"

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <string.h>

static NSFileManager	*
manager()
{
  static NSFileManager	*mgr = nil;

  if (mgr == nil)
    {
      mgr = RETAIN([NSFileManager defaultManager]);
    }
  return mgr;
}


@interface NSObject (PrivateFrameworks)
+ (NSString*) frameworkEnv;
+ (NSString*) frameworkPath;
+ (NSString*) frameworkVersion;
+ (NSString**) frameworkClasses;
@end

typedef enum {
  NSBUNDLE_BUNDLE = 1,
  NSBUNDLE_APPLICATION,
  NSBUNDLE_FRAMEWORK,
  NSBUNDLE_LIBRARY
} bundle_t;

/* Class variables - We keep track of all the bundles */
static NSBundle		*_mainBundle = nil;
static NSMapTable	*_bundles = NULL;
static NSMapTable	*_byIdentifier = NULL;

/* Store the working directory at startup */
static NSString		*_launchDirectory = nil;

static NSString		*_base_version
  = OBJC_STRINGIFY(GNUSTEP_BASE_MAJOR_VERSION.GNUSTEP_BASE_MINOR_VERSION);

/*
 * An empty strings file table for use when localization files can't be found.
 */
static NSDictionary	*_emptyTable = nil;

/* When we are linking in an object file, GSPrivateLoadModule calls our
   callback routine for every Class and Category loaded.  The following
   variable stores the bundle that is currently doing the loading so we know
   where to store the class names.
*/
static NSBundle		*_loadingBundle = nil;
static NSBundle		*_gnustep_bundle = nil;
static NSRecursiveLock	*load_lock = nil;
static BOOL		_strip_after_loading = NO;

/* List of framework linked in the _loadingBundle */
static NSMutableArray	*_loadingFrameworks = nil;
static NSString         *_currentFrameworkName = nil;

static NSString	*gnustep_target_dir =
#ifdef GNUSTEP_TARGET_DIR
  @GNUSTEP_TARGET_DIR;
#else
  nil;
#endif
static NSString	*gnustep_target_cpu =
#ifdef GNUSTEP_TARGET_CPU
  @GNUSTEP_TARGET_CPU;
#else
  nil;
#endif
static NSString	*gnustep_target_os =
#ifdef GNUSTEP_TARGET_OS
  @GNUSTEP_TARGET_OS;
#else
  nil;
#endif
static NSString	*library_combo =
#ifdef LIBRARY_COMBO
  @LIBRARY_COMBO;
#else
  nil;
#endif


/*
 * Try to find the absolute path of an executable.
 * Search all the directoried in the PATH.
 * The atLaunch flag determines whether '.' is considered to be
 * the  current working directory or the working directory at the
 * time when the program was launched (technically the directory
 * at the point when NSBundle was first used ... so programs must
 * use NSBundle *before* changing their working directories).
 */
static NSString*
AbsolutePathOfExecutable(NSString *path, BOOL atLaunch)
{
  NSFileManager	*mgr = manager();
  NSDictionary	*env;
  NSString	*pathlist;
  NSString	*prefix;
  id		patharr;

  path = [path stringByStandardizingPath];
  if ([path isAbsolutePath])
    {
      return path;
    }

  env = [[NSProcessInfo processInfo] environment];
  pathlist = [env objectForKey:@"PATH"];

/* Windows 2000 and perhaps others have "Path" not "PATH" */
  if (pathlist == nil)
    {
      pathlist = [env objectForKey:@"Path"];
    }
#if defined(__MINGW32__)
  patharr = [pathlist componentsSeparatedByString:@";"];
#else
  patharr = [pathlist componentsSeparatedByString:@":"];
#endif
  /* Add . if not already in path */
  if ([patharr indexOfObject: @"."] == NSNotFound)
    {
      patharr = AUTORELEASE([patharr mutableCopy]);
      [patharr addObject: @"."];
    }
  patharr = [patharr objectEnumerator];
  while ((prefix = [patharr nextObject]))
    {
      if ([prefix isEqual:@"."])
	{
	  if (atLaunch == YES)
	    {
	      prefix = _launchDirectory;
	    }
	  else
	    {
	      prefix = [mgr currentDirectoryPath];
	    }
	}
      prefix = [prefix stringByAppendingPathComponent: path];
      if ([mgr isExecutableFileAtPath: prefix])
	{
	  return [prefix stringByStandardizingPath];
	}
#if defined(__WIN32__)
      {
	NSString	*ext = [path pathExtension];

	/* Also add common executable extensions on windows */
	if (ext == nil || [ext length] == 0)
	  {
	    NSString *wpath;
	    wpath = [prefix stringByAppendingPathExtension: @"exe"];
	    if ([mgr isExecutableFileAtPath: wpath])
	      return [wpath stringByStandardizingPath];
	    wpath = [prefix stringByAppendingPathExtension: @"com"];
	    if ([mgr isExecutableFileAtPath: wpath])
	      return [wpath stringByStandardizingPath];
	    wpath = [prefix stringByAppendingPathExtension: @"cmd"];
	    if ([mgr isExecutableFileAtPath: wpath])
	      return [wpath stringByStandardizingPath];
	  }
	}
#endif
    }
  return nil;
}

/*
 * Return the path to this executable.
 */
NSString *
GSPrivateExecutablePath()
{
  static NSString	*executablePath = nil;
  static BOOL		beenHere = NO;

  if (beenHere == NO)
    {
      [load_lock lock];
      if (beenHere == NO)
	{
#ifdef PROCFS_EXE_LINK
	  executablePath = [manager()
	    pathContentOfSymbolicLinkAtPath:
              [NSString stringWithUTF8String: PROCFS_EXE_LINK]];

	  /*
	  On some systems, the link is of the form "[device]:inode", which
	  can be used to open the executable, but is useless if you want
	  the path to it. Thus we check that the path is an actual absolute
	  path. (Using '/' here is safe; it isn't the path separator
	  everywhere, but it is on all systems that have PROCFS_EXE_LINK.)
	  */
	  if ([executablePath length] > 0
	    && [executablePath characterAtIndex: 0] != '/')
	    {
	      executablePath = nil;
	    }
#endif
	  if (executablePath == nil || [executablePath length] == 0)
	    {
	      executablePath
		= [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
	      executablePath = AbsolutePathOfExecutable(executablePath, YES);
	    }

	  IF_NO_GC([executablePath retain];)
	  beenHere = YES;
	}
      [load_lock unlock];
      NSCAssert(executablePath != nil, NSInternalInconsistencyException);
    }
  return executablePath;
}

static BOOL
bundle_directory_readable(NSString *path)
{
  NSFileManager	*mgr = manager();
  BOOL		directory;

  if ([mgr fileExistsAtPath: path isDirectory: &directory] == NO
    || !directory)
    return NO;

  return [mgr isReadableFileAtPath: path];
}

/* Get the object file that should be located in the bundle of the same name */
static NSString *
bundle_object_name(NSString *path, NSString* executable)
{
  NSFileManager	*mgr = manager();
  NSString	*name, *path0, *path1, *path2;

  if (executable)
    {
      NSString	*exepath;

      name = [executable lastPathComponent];
      exepath = [executable stringByDeletingLastPathComponent];
      if ([exepath isEqualToString: @""] == NO)
	{
	  if ([exepath isAbsolutePath] == YES)
	    path = exepath;
	  else
	    path = [path stringByAppendingPathComponent: exepath];
	}
    }
  else
    {
      name = [[path lastPathComponent] stringByDeletingPathExtension];
      path = [path stringByDeletingLastPathComponent];
    }
  path0 = [path stringByAppendingPathComponent: name];
  path = [path stringByAppendingPathComponent: gnustep_target_dir];
  path1 = [path stringByAppendingPathComponent: name];
  path = [path stringByAppendingPathComponent: library_combo];
  path2 = [path stringByAppendingPathComponent: name];

  if ([mgr isReadableFileAtPath: path2] == YES)
    return path2;
  else if ([mgr isReadableFileAtPath: path1] == YES)
    return path1;
  else if ([mgr isReadableFileAtPath: path0] == YES)
    return path0;
#if defined(__MINGW32__)
  /* If we couldn't find the binary, and we are on windows, and the name
   * has no path extension, then let's try looking for a dll.
   */
  if ([name pathExtension] == nil)
    {
      if ([mgr isReadableFileAtPath:
	[path2 stringByAppendingPathExtension: @"dll"]] == YES)
	return [path2 stringByAppendingPathExtension: @"dll"];
      else if ([mgr isReadableFileAtPath:
	[path1 stringByAppendingPathExtension: @"dll"]] == YES)
	return [path1 stringByAppendingPathExtension: @"dll"];
      else if ([mgr isReadableFileAtPath:
	[path0 stringByAppendingPathExtension: @"dll"]] == YES)
	return [path0 stringByAppendingPathExtension: @"dll"];
    }
#endif
  return path0;
}

/* Construct a path from components */
static NSString *
_bundle_resource_path(NSString *primary, NSString* bundlePath, NSString *lang)
{
  if (bundlePath)
    primary = [primary stringByAppendingPathComponent: bundlePath];
  if (lang)
    primary = [primary stringByAppendingPathComponent:
      [NSString stringWithFormat: @"%@.lproj", lang]];
  return primary;
}

/* Try to locate name framework in standard places
   which are like /Library/Frameworks/(name).framework */
static inline NSString *
_find_framework(NSString *name)
{                
  NSArray	*paths;
  NSFileManager *file_mgr = manager();
  NSString	*file_name = [name stringByAppendingPathExtension:@"framework"];
  NSString	*file_path;
  NSString	*path;
  NSEnumerator	*enumerator;
           
  NSCParameterAssert(name != nil);

  paths = NSSearchPathForDirectoriesInDomains(GSFrameworksDirectory,
            NSAllDomainsMask,YES);

  enumerator = [paths objectEnumerator];
  while ((path = [enumerator nextObject]))
    {
      file_path = [path stringByAppendingPathComponent: file_name];

      if ([file_mgr fileExistsAtPath: file_path] == YES)
        {
          return file_path; // Found it!
        }
    }
  return nil;
}        


/* Try to locate resources for tool name (which is this tool) in
 * standard places like xxx/Library/Tools/Resources/name */
/* This could be converted into a public +bundleForTool:
 * method.  At the moment it's only used privately
 * to locate the main bundle for this tool.
 */
static inline NSString *
_find_main_bundle_for_tool(NSString *toolName)
{
  NSArray *paths;
  NSEnumerator *enumerator;
  NSString *path;
  NSString *tail;
  NSFileManager *fm = manager();

  /*
   * Eliminate any base path or extensions.
   */
  toolName = [toolName lastPathComponent];
  do
    {
      toolName = [toolName stringByDeletingPathExtension];
    }
  while ([[toolName pathExtension] length] > 0);

  if ([toolName length] == 0)
    {
      return nil;
    }

  tail = [@"Tools" stringByAppendingPathComponent:
	     [@"Resources" stringByAppendingPathComponent: 
		 toolName]];

  paths = NSSearchPathForDirectoriesInDomains (NSLibraryDirectory,
					       NSAllDomainsMask, YES);

  enumerator = [paths objectEnumerator];
  while ((path = [enumerator nextObject]))
    {
      BOOL isDir;
      path = [path stringByAppendingPathComponent: tail];

      if ([fm fileExistsAtPath: path  isDirectory: &isDir]  &&  isDir)
	{
	  return path;
	}
    }

  return nil;
}



@interface NSBundle (Private)
+ (NSString *) _absolutePathOfExecutable: (NSString *)path;
+ (void) _addFrameworkFromClass: (Class)frameworkClass;
+ (NSString*) _gnustep_target_cpu;
+ (NSString*) _gnustep_target_dir;
+ (NSString*) _gnustep_target_os;
+ (NSString*) _library_combo;
@end

@implementation NSBundle (Private)

+ (NSString *) _absolutePathOfExecutable: (NSString *)path
{
  return AbsolutePathOfExecutable(path, NO);
}

/* Nicola & Mirko:

   Frameworks can be used in an application in two different ways:

   () the framework is dynamically/manually loaded, as if it were a
   bundle.  This is the easier case, because we already have the
   bundle setup with the correct path (it's the programmer's
   responsibility to find the framework bundle on disk); we get all
   information from the bundle dictionary, such as the version; we
   also create the class list when loading the bundle, as for any
   other bundle.

   () the framework was linked into the application.  This is much
   more difficult, because without using tricks, we have no way of
   knowing where the framework bundle (needed eg for resources) is on
   disk, and we have no way of knowing what the class list is, or the
   version.  So the trick we use in this case to work around those
   problems is that gnustep-make generates a 'NSFramework_xxx' class
   and compiles it into each framework.  By asking to the class, we
   can get the version information and the list of classes which were
   compiled into the framework.  To get the location of the framework
   on disk, we try using advanced dynamic linker features to get the
   shared object file on disk from which the NSFramework_xxx class was
   loaded.  If that doesn't work, because the dynamic linker can't
   provide this information on this platform (or maybe because the
   framework was statically linked into the application), we have a
   fallback trick :-) We look for the framework in the standard
   locations and in the main bundle.  This might fail if the framework
   is not in a standard location or there is more than one installed
   framework of the same name (and different versions?).

   So at startup, we scan all classes which were compiled into the
   application.  For each NSFramework_ class, we call the following
   function, which records the name of the framework, the version,
   the classes belonging to it, and tries to determine the path
   on disk to the framework bundle.

   Bundles (and frameworks if dynamically loaded as bundles) could
   depend on other frameworks (linked togheter on platform that
   supports this behaviour) so whenever we dynamically load a bundle,
   we need to spot out any additional NSFramework_* classes which are
   loaded, and call this method (exactly as for frameworks linked into
   the main application) to record them, and try finding the path on
   disk to those framework bundles.

*/
+ (void) _addFrameworkFromClass: (Class)frameworkClass
{
  NSBundle	*bundle = nil;
  NSString	**fmClasses;
  NSString	*bundlePath = nil;
  unsigned int	len;

  if (frameworkClass == Nil)
    {
      return;
    }

  len = strlen (frameworkClass->name);

  if (len > 12 * sizeof(char)
      && !strncmp ("NSFramework_", frameworkClass->name, 12))
    {
      /* The name of the framework.  */
      NSString *name;

      name = [NSString stringWithUTF8String: &frameworkClass->name[12]];
      /* Important - gnustep-make mangles framework names to encode
       * them as ObjC class names.  Here we need to demangle them.  We
       * apply the reverse transformations in the reverse order.
       */
      name = [name stringByReplacingString: @"_1"  withString: @"+"];
      name = [name stringByReplacingString: @"_0"  withString: @"-"];
      name = [name stringByReplacingString: @"__"  withString: @"_"];

      /* Try getting the path to the framework using the dynamic
       * linker.  When it works it's really cool :-) This is the only
       * really universal way of getting the framework path ... we can
       * locate the framework no matter where it is on disk!
       */
      bundlePath = GSPrivateSymbolPath (frameworkClass, NULL);

      if ([bundlePath isEqualToString: GSPrivateExecutablePath()])
	{
	  /* Ops ... the NSFramework_xxx class is linked in the main
	   * executable.  Maybe the framework was statically linked
	   * into the application ... resort to searching the
	   * framework bundle on the filesystem manually.
	   */
	  bundlePath = nil;
	}

      if (bundlePath != nil)
	{
	  NSString *pathComponent;

	  /* Dereference symlinks, and standardize path.  This will
	   * only work properly if the original bundlePath is
	   * absolute.  This should normally be the case if, as
	   * recommended, you use only absolute paths in
	   * LD_LIBRARY_PATH.
	   */
	  bundlePath = [bundlePath stringByStandardizingPath];

	  /* We now have the location of the shared library object
	   * file inside the framework directory.  We need to walk up
	   * the directory tree up to the top of the framework.  To do
	   * so, we need to chop off the extra subdirectories, the
	   * library combo and the target cpu/os if they exist.  The
	   * framework and this library should match so we can use the
	   * compiled-in settings.
	   */
	  /* library name */
	  bundlePath = [bundlePath stringByDeletingLastPathComponent];
	  /* library combo */
	  pathComponent = [bundlePath lastPathComponent];
	  if ([pathComponent isEqual: library_combo])
	    {
	      bundlePath = [bundlePath stringByDeletingLastPathComponent];
	    }
	  /* target os */
	  pathComponent = [bundlePath lastPathComponent];
	  if ([pathComponent isEqual: gnustep_target_os])
	    {
	      bundlePath = [bundlePath stringByDeletingLastPathComponent];
	    }
	  /* target cpu */
	  pathComponent = [bundlePath lastPathComponent];
	  if ([pathComponent isEqual: gnustep_target_cpu])
	    {
	      bundlePath = [bundlePath stringByDeletingLastPathComponent];
	    }
#if defined(__MINGW32__)
	  /* On windows, the library (dll) is in the Tools area rather than
	   * in the framework, so we can adjust the path here.
	   */
	  if ([[bundlePath lastPathComponent] isEqual: @"Tools"])
	    {
	      bundlePath = [bundlePath stringByDeletingLastPathComponent];
	      bundlePath
		= [bundlePath stringByAppendingPathComponent: @"Library"];
	      bundlePath
		= [bundlePath stringByAppendingPathComponent: @"Frameworks"];
	      bundlePath = [bundlePath stringByAppendingPathComponent:
		[NSString stringWithFormat: @"%@%@", name, @".framework"]];
	    }
#else
	  /* There are no Versions on MinGW.  Skip the Versions check here.  */
	  /* version name */
	  bundlePath = [bundlePath stringByDeletingLastPathComponent];

	  pathComponent = [bundlePath lastPathComponent];
          if ([pathComponent isEqual: @"Versions"])
	    {
	      bundlePath = [bundlePath stringByDeletingLastPathComponent];
#endif
	      pathComponent = [bundlePath lastPathComponent];
	
	      if ([pathComponent isEqualToString:
				   [NSString stringWithFormat: @"%@%@",
					     name, @".framework"]])
		{
		  /* Try creating the bundle.  */
		  if (bundlePath)
		    bundle = [[self alloc] initWithPath: bundlePath];
		}
#if !defined(__MINGW32__)
	    }
#endif

	  /* Failed - buu - try the fallback trick.  */
	  if (bundle == nil)
	    {
	      bundlePath = nil;
	    }
	}

      if (bundlePath == nil)
	{
	  /* NICOLA: In an ideal world, the following is just a hack
	   * for when GSPrivateSymbolPath() fails!  But in real life
	   * GSPrivateSymbolPath() is risky (some platforms don't
	   * have it at all!), so this hack might be used a lot!  It
	   * must be quite robust.  We try to look for the framework
	   * in the standard GNUstep installation dirs and in the main
	   * bundle.  This should be reasonably safe if the user is
	   * not being too clever ... :-)
	  */
          bundlePath = _find_framework(name);
	  if (bundlePath == nil)
	    {
	      bundlePath = [[NSBundle mainBundle] pathForResource: name
						  ofType: @"framework"
						  inDirectory: @"Frameworks"];
	    }

	  /* Try creating the bundle.  */
	  if (bundlePath != nil)
	    {
	      bundle = [[self alloc] initWithPath: bundlePath];
	    }
	}

      if (bundle == nil)
	{
	  NSWarnMLog (@"Could not find framework %@ in any standard location",
	    name);
	  return;
	}

      bundle->_bundleType = NSBUNDLE_FRAMEWORK;
      bundle->_codeLoaded = YES;
      /* frameworkVersion is something like 'A'.  */
      bundle->_frameworkVersion = RETAIN([frameworkClass frameworkVersion]);
      bundle->_bundleClasses = RETAIN([NSMutableArray arrayWithCapacity: 2]);

      /* A NULL terminated list of class names - the classes contained
	 in the framework.  */
      fmClasses = [frameworkClass frameworkClasses];

      while (*fmClasses != NULL)
	{
	  NSValue *value;
	  Class    class = NSClassFromString(*fmClasses);

	  value = [NSValue valueWithPointer: (void*)class];
	
	  [bundle->_bundleClasses addObject: value];
	
	  fmClasses++;
	}

      /* If _loadingBundle is not nil, it means we reached this point
       * while loading a bundle.  This can happen if the framework is
       * linked into the bundle (then, the dynamic linker
       * automatically drags in the framework when the bundle is
       * loaded).  But then, the classes in the framework should be
       * removed from the list of classes in the bundle. Check that
       * _loadingBundle != bundle which happens on Windows machines when
       * loading in Frameworks.
       */
      if (_loadingBundle != nil && _loadingBundle != bundle)
	{
	  int i, j;
          id b = bundle->_bundleClasses;
          id l = _loadingBundle->_bundleClasses;

	  /* The following essentially does:
	   *
	   * [_loadingBundle->_bundleClasses
	   *  removeObjectsInArray: bundle->_bundleClasses];
	   *
	   * The problem with that code is isEqual: gets
	   * sent to the classes, which will cause them to be
	   * initialized (which should not happen.)
	   */
	  for (i = 0; i < [b count]; i++)
	    {
	      for (j = 0; j < [l count]; j++)
		{
		  if ([[l objectAtIndex: j] pointerValue]
		     == [[b objectAtIndex:i] pointerValue])
		    {
		      [l removeObjectAtIndex:j];
		    }
		}
	    }
	}
    }
}

+ (NSString*) _gnustep_target_cpu
{
  return gnustep_target_cpu;
}

+ (NSString*) _gnustep_target_dir
{
  return gnustep_target_dir;
}

+ (NSString*) _gnustep_target_os
{
  return gnustep_target_os;
}

+ (NSString*) _library_combo
{
  return library_combo;
}

@end

/*
  Mirko:

  The gnu-runtime calls the +load method of each class before the
  _bundle_load_callback() is called and we can't provide the list of classes
  ready for this method.

 */

static void
_bundle_load_callback(Class theClass, struct objc_category *theCategory)
{
  NSCAssert(_loadingBundle, NSInternalInconsistencyException);
  NSCAssert(_loadingFrameworks, NSInternalInconsistencyException);

  /* We never record categories - if this is a category, just do nothing.  */
  if (theCategory != 0)
    {
      return;
    }

  /* Don't store the internal NSFramework_xxx class into the list of
     bundle classes, but store the linked frameworks in _loadingFrameworks  */
  if (strlen (theClass->name) > 12   &&  !strncmp ("NSFramework_",
						   theClass->name, 12))
    {
      if (_currentFrameworkName)
	{
	  const char *frameworkName;

	  frameworkName = [_currentFrameworkName cString];

	  if (!strcmp(theClass->name, frameworkName))
	    return;
	}

      [_loadingFrameworks
	addObject: [NSValue valueWithPointer: (void*)theClass]];
      return;
    }

  /* Store classes (but don't store categories) */
  [(_loadingBundle)->_bundleClasses addObject:
    [NSValue valueWithPointer: (void*)theClass]];
}


@implementation NSBundle

+ (void) initialize
{
  if (self == [NSBundle class])
    {
      NSDictionary *env;
      NSString	   *str;

      _emptyTable = RETAIN([NSDictionary dictionary]);

      /* Initialise manager here so it's thread-safe.
       */
      manager();

      /* Need to make this recursive since both mainBundle and
       * initWithPath: want to lock the thread.
       */
      load_lock = [NSRecursiveLock new];
      env = [[NSProcessInfo processInfo] environment];

      /* These variables are used when we are running non-flattened.
       * This means that there are multiple binaries for different
       * OSes, and we need constantly to choose the right one (eg,
       * when loading a bundle or a framework).  The choice is based
       * on these environments variables that are set by GNUstep.sh
       * (you must source GNUstep.sh when non-flattened).
       */
      if ((str = [env objectForKey: @"GNUSTEP_TARGET_CPU"]) != nil)
	gnustep_target_cpu = RETAIN(str);
      else if ((str = [env objectForKey: @"GNUSTEP_HOST_CPU"]) != nil)
	gnustep_target_cpu = RETAIN(str);
      
      if ((str = [env objectForKey: @"GNUSTEP_TARGET_OS"]) != nil)
	gnustep_target_os = RETAIN(str);
      else if ((str = [env objectForKey: @"GNUSTEP_HOST_OS"]) != nil)
	gnustep_target_os = RETAIN(str);
      
      if ((str = [env objectForKey: @"GNUSTEP_TARGET_DIR"]) != nil)
	gnustep_target_dir = RETAIN(str);
      else if ((str = [env objectForKey: @"GNUSTEP_HOST_DIR"]) != nil)
	gnustep_target_dir = RETAIN(str);
      
      if ((str = [env objectForKey: @"LIBRARY_COMBO"]) != nil)
	library_combo = RETAIN(str);
      
      _launchDirectory = RETAIN([manager() currentDirectoryPath]);
      
      _gnustep_bundle = RETAIN([self bundleForLibrary: @"gnustep-base"
					      version: _base_version]);
#if 0
      _loadingBundle = [self mainBundle];
      handle = objc_open_main_module(stderr);
      printf("%08x\n", handle);
#endif
#if NeXT_RUNTIME
      {
	int i, numClasses = 0, newNumClasses = objc_getClassList(NULL, 0);
	Class *classes = NULL;
	while (numClasses < newNumClasses) {
	  numClasses = newNumClasses;
	  classes = objc_realloc(classes, sizeof(Class) * numClasses);
	  newNumClasses = objc_getClassList(classes, numClasses);
	}
	for (i = 0; i < numClasses; i++)
	  {
	    [self _addFrameworkFromClass: classes[i]];
	  }
	objc_free(classes);
      }
#else
      {
	void	*state = NULL;
	Class	class;
	
	while ((class = objc_next_class(&state)))
	  {
	    unsigned int len = strlen (class->name);
	    
	    if (len > sizeof("NSFramework_")
		&& !strncmp("NSFramework_", class->name, 12))
	      {
		[self _addFrameworkFromClass: class];
	      }
	  }
      }
#endif
#if 0
      //  _bundle_load_callback(class, NULL);
      //  bundle = (NSBundle *)NSMapGet(_bundles, bundlePath);
      
      objc_close_main_module(handle);
      _loadingBundle = nil;
#endif
    }
}

/**
 * Returns an array of all the bundles which do not belong to frameworks.<br />
 * This always contains the main bundle.
 */
+ (NSArray *) allBundles
{
  NSMutableArray	*array = [NSMutableArray arrayWithCapacity: 2];

  [load_lock lock];
  if (!_mainBundle)
    {
      [self mainBundle];
    }
  if (_bundles != 0)
    {
      NSMapEnumerator	enumerate;
      void		*key;
      NSBundle		*bundle;

      enumerate = NSEnumerateMapTable(_bundles);
      while (NSNextMapEnumeratorPair(&enumerate, &key, (void **)&bundle))
	{
	  if (bundle->_bundleType == NSBUNDLE_FRAMEWORK)
	    {
	      continue;
	    }
	  if ([array indexOfObjectIdenticalTo: bundle] == NSNotFound)
	    {
	      [array addObject: bundle];
	    }
	}
      NSEndMapTableEnumeration(&enumerate);
    }
  [load_lock unlock];
  return array;
}

/**
 * Returns an array containing all the known bundles representing frameworks.
 */
+ (NSArray *) allFrameworks
{
  NSMapEnumerator  enumerate;
  NSMutableArray  *array = [NSMutableArray arrayWithCapacity: 2];
  void		  *key;
  NSBundle	  *bundle;

  [load_lock lock];
  enumerate = NSEnumerateMapTable(_bundles);
  while (NSNextMapEnumeratorPair(&enumerate, &key, (void **)&bundle))
    {
      if (bundle->_bundleType == NSBUNDLE_FRAMEWORK
	&& [array indexOfObjectIdenticalTo: bundle] == NSNotFound)
	{
	  [array addObject: bundle];
	}
    }
  NSEndMapTableEnumeration(&enumerate);
  [load_lock unlock];
  return array;
}

/**
 * For an application, returns the main bundle of the application.<br />
 * For a tool, returns the main bundle associated with the tool.<br />
 * <br />
 * For an application, the structure is as follows -
 * <p>
 * The executable is Gomoku.app/ix86/linux-gnu/gnu-gnu-gnu/Gomoku
 * and the main bundle directory is Gomoku.app/.
 * </p>
 * For a tool, the structure is as follows -
 * <p>
 * The executable is xxx/Tools/ix86/linux-gnu/gnu-gnu-gnu/Control
 * and the main bundle directory is xxx/Tools/Resources/Control.
 * </p>
 * <p>(when the tool has not yet been installed, it's similar -
 * xxx/obj/ix86/linux-gnu/gnu-gnu-gnu/Control
 * and the main bundle directory is xxx/Resources/Control).
 * </p>
 * <p>(For a flattened structure, the structure is the same without the
 * ix86/linux-gnu/gnu-gnu-gnu directories).
 * </p>
 */
+ (NSBundle *) mainBundle
{
  [load_lock lock];
  if (!_mainBundle)
    {
      /* We figure out the main bundle directory by examining the location
	 of the executable on disk.  */
      NSString *path, *s;

      /* We don't know at the beginning if it's a tool or an application.  */
      BOOL isApplication = YES;

      /* Sometimes we detect that this is a non-installed tool.  That is
       * special because we want to lookup local resources before installed
       * ones.  Keep track of this special case in this variable.
       */
      BOOL isNonInstalledTool = NO;

      /* If it's a tool, we will need the tool name.  Since we don't
         know yet if it's a tool or an application, we always store
         the executable name here - just in case it turns out it's a
         tool.  */
      NSString *toolName = [GSPrivateExecutablePath() lastPathComponent];
#if defined(__WIN32__) || defined(__CYGWIN__)
      toolName = [toolName stringByDeletingPathExtension];
#endif

      /* Strip off the name of the program */
      path = [GSPrivateExecutablePath() stringByDeletingLastPathComponent];

      /* We now need to chop off the extra subdirectories, the library
	 combo and the target cpu/os if they exist.  The executable
	 and this library should match so that is why we can use the
	 compiled-in settings. */
      /* library combo */
      s = [path lastPathComponent];
      if ([s isEqual: library_combo])
	{
	  path = [path stringByDeletingLastPathComponent];
	}
      /* target os */
      s = [path lastPathComponent];
      if ([s isEqual: gnustep_target_os])
	{
	  path = [path stringByDeletingLastPathComponent];
	}
      /* target cpu */
      s = [path lastPathComponent];
      if ([s isEqual: gnustep_target_cpu])
	{
	  path = [path stringByDeletingLastPathComponent];
	}
      /* object dir */
      s = [path lastPathComponent];
      if ([s hasSuffix: @"obj"])
	{
	  path = [path stringByDeletingLastPathComponent];
	  /* if it has an object dir it can only be a
             non-yet-installed tool.  */
	  isApplication = NO;
	  isNonInstalledTool = YES;
	}

      if (isApplication == YES)
	{
	  s = [path lastPathComponent];
	
	  if ((([s hasSuffix: @".app"]  == NO)
	    && ([s hasSuffix: @".debug"] == NO)
	    && ([s hasSuffix: @".profile"] == NO))
	    // GNUstep Web
	    && (([s hasSuffix: @".gswa"] == NO)
		&& ([s hasSuffix: @".woa"] == NO)))
	    {
	      isApplication = NO;
	    }
	}

      if (isApplication == NO)
	{
	  NSString *maybePath = nil;

	  if (isNonInstalledTool)
	    {
	      /* We're pretty confident about this case.  'path' is
	       * obtained by {tool location on disk} and walking up
	       * until we got out of the obj directory.  So we're
	       * now in GNUSTEP_BUILD_DIR.  Resources will be in
	       * Resources/{toolName}.
	       */
	      path = [path stringByAppendingPathComponent: @"Resources"];
	      maybePath = [path stringByAppendingPathComponent: toolName];

	      /* PS: We could check here if we found the resources,
	       * and if not, keep going with the other attempts at
	       * locating them.  But if we know that this is an
	       * uninstalled tool, really we don't want to use
	       * installed resources - we prefer resource lookup to
	       * fail so the developer will fix whatever issue they
	       * have with their building.
	       */
	    }
	  else
	    {
	      if (maybePath == nil)
		{
		  /* This is for gnustep-make version 2, where tool resources
		   * are in GNUSTEP_*_LIBRARY/Tools/Resources/{toolName}.
		   */
		  maybePath = _find_main_bundle_for_tool (toolName);
		}
	      
	      /* If that didn't work, maybe the tool was created with
	       * gnustep-make version 1.  So we try {tool location on
	       * disk after walking up the non-flattened
	       * dirs}/Resources/{toolName}, which is where
	       * gnustep-make version 1 would put resources.
	       */
	      if (maybePath == nil)
		{
		  path = [path stringByAppendingPathComponent: @"Resources"];
		  maybePath = [path stringByAppendingPathComponent: toolName];
		}
	    }

	  path = maybePath;
	}

      NSDebugMLLog(@"NSBundle", @"Found main in %@\n", path);
      /* We do alloc and init separately so initWithPath: knows we are
          the _mainBundle.  Please note that we do *not* autorelease
          mainBundle, because we don't want it to be ever released.  */
      _mainBundle = [self alloc];
      /* Please note that _mainBundle should *not* be nil.  */
      _mainBundle = [_mainBundle initWithPath: path];
      NSAssert(_mainBundle != nil, NSInternalInconsistencyException);
    }

  [load_lock unlock];
  return _mainBundle;
}

/**
 * Returns the bundle whose code contains the specified class.<br />
 * NB: We will not find a class if the bundle has not been loaded yet!
 */
+ (NSBundle *) bundleForClass: (Class)aClass
{
  void		*key;
  NSBundle	*bundle;
  NSMapEnumerator enumerate;

  if (!aClass)
    return nil;

  /* This is asked relatively frequently inside gnustep-base itself;
   * shortcut it.
   */
  if (aClass == [NSObject class])
    {
      return _gnustep_bundle;
    }

  [load_lock lock];
  bundle = nil;
  enumerate = NSEnumerateMapTable(_bundles);
  while (NSNextMapEnumeratorPair(&enumerate, &key, (void **)&bundle))
    {
      int i, j;
      NSArray *bundleClasses = bundle->_bundleClasses;
      BOOL found = NO;

      j = [bundleClasses count];
      for (i = 0; i < j && found == NO; i++)
	{
	  if ([[bundleClasses objectAtIndex: i] pointerValue] == (void*)aClass)
	    found = YES;
	}

      if (found == YES)
	break;

      bundle = nil;
    }

  if (bundle == nil)
    {
      /* Is it in the main bundle or a library? */
      if (class_is_class(aClass))
        {
	  NSString	*lib;

	  /*
	   * Take the path to the binary containing the class and
	   * convert it to the format for a library name as used for
	   * obtaining a library resource bundle.
	   */
	  lib = GSPrivateSymbolPath (aClass, NULL);
	  if ([lib isEqual: GSPrivateExecutablePath()] == YES)
	    {
	      lib = nil;	// In program, not library.
	    }

	  /*
	   * Get the library bundle ... if there wasn't one then we
	   * will assume the class was in the program executable and
	   * return the mainBundle instead.
	   */
	  bundle = [NSBundle bundleForLibrary: lib];
	  if (bundle == nil)
	    {
	      bundle = [self mainBundle];
	    }

	  /*
	   * Add the class to the list of classes known to be in the
	   * library or executable.  We didn't find it there to start
	   * with, so we know it's safe to add now.
	   */
	  if (bundle->_bundleClasses == nil)
	    {
	      bundle->_bundleClasses
		= [[NSMutableArray alloc] initWithCapacity: 2];
	    }
	  [bundle->_bundleClasses addObject:
	    [NSValue valueWithPointer: (void*)aClass]];
	}
    }
  [load_lock unlock];

  return bundle;
}

+ (NSBundle*) bundleWithPath: (NSString*)path
{
  return AUTORELEASE([[self alloc] initWithPath: path]);
}

+ (NSBundle*) bundleWithIdentifier: (NSString*)identifier
{
  NSBundle	*bundle = nil;

  [load_lock lock];
  if (_byIdentifier)
    {
      bundle = (NSBundle *)NSMapGet(_byIdentifier, identifier);
IF_NO_GC(
      if (bundle != nil)
	{
	  [bundle retain]; /* retain - look as if we were alloc'ed */
	}
)
    }
  [load_lock unlock];
  return AUTORELEASE(bundle);
}

- (id) initWithPath: (NSString*)path
{
  NSString	*identifier;

  self = [super init];

  if (!path || [path length] == 0)
    {
      NSDebugMLog(@"No path specified for bundle");
      [self dealloc];
      return nil;
    }

  /*
   * Make sure we have an absolute and fully expanded path,
   * so we can manipulate it without having to worry about
   * details like that throughout the code.
   */
  if ([path isAbsolutePath] == NO)
    {
      NSWarnMLog(@"NSBundle -initWithPath: requires absolute path names, "
	@"given '%@'", path);

#if defined(__MINGW32__)
      if ([path length] > 0 &&
	([path characterAtIndex: 0]=='/' || [path characterAtIndex: 0]=='\\'))
	{
	  NSString	*root;
	  unsigned	length;

	  /* The path has a leading path separator, so we try assuming
	   * that it's a path on the current filesystem, and append it
	   * to the filesystem root.
	   */
	  root = [manager() currentDirectoryPath];
	  length = [root length];
	  root = [root stringByDeletingLastPathComponent];
	  while ([root length] != length)
	    {
	      length = [root length];
	      root = [root stringByDeletingLastPathComponent];
	    }
	  path = [root stringByAppendingPathComponent: path];
	}
      else
	{
	  /* Try appending to the current working directory.
	   */
	  path = [[manager() currentDirectoryPath]
	    stringByAppendingPathComponent: path];
	}
#else
      path = [[manager() currentDirectoryPath]
        stringByAppendingPathComponent: path];
#endif
    }

  /*
   * Standardize the path so we can be sure that cache lookup is consistent.
   */
  path = [path stringByStandardizingPath];

  /* Check if we were already initialized for this directory */
  [load_lock lock];
  if (_bundles)
    {
      NSBundle	*bundle = (NSBundle *)NSMapGet(_bundles, path);

      if (bundle != nil)
	{
	  IF_NO_GC([bundle retain];)
	  [load_lock unlock];
	  [self dealloc];
	  return bundle;
	}
    }
  [load_lock unlock];

  if (bundle_directory_readable(path) == NO)
    {
      NSDebugMLLog(@"NSBundle", @"Could not access path %@ for bundle", path);
      // if this is not the main bundle ... deallocate and return.
      if (self != _mainBundle)
	{
	  [self dealloc];
	  return nil;
	}
    }

  _path = [path copy];

  if ([[[_path lastPathComponent] pathExtension] isEqual: @"framework"] == YES)
    {
      _bundleType = (unsigned int)NSBUNDLE_FRAMEWORK;
    }
  else
    {
      if (self == _mainBundle)
	_bundleType = (unsigned int)NSBUNDLE_APPLICATION;
      else
	_bundleType = (unsigned int)NSBUNDLE_BUNDLE;
    }

  identifier = [self bundleIdentifier];

  [load_lock lock];
  if (!_bundles)
    {
      _bundles = NSCreateMapTable(NSObjectMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);
    }
  if (!_byIdentifier)
    {
      _byIdentifier = NSCreateMapTable(NSObjectMapKeyCallBacks,
	NSNonOwnedPointerMapValueCallBacks, 0);
    }
  if (identifier != nil)
    {
      NSBundle	*bundle = (NSBundle *)NSMapGet(_byIdentifier, identifier);

      if (bundle != nil)
	{
	  IF_NO_GC([bundle retain];)
	  [load_lock unlock];
	  [self dealloc];
	  return bundle;
	}
      NSMapInsert(_byIdentifier, identifier, self);
    }
  NSMapInsert(_bundles, _path, self);
  [load_lock unlock];

  return self;
}

- (void) dealloc
{
  if ([self isLoaded] == YES && self != _mainBundle
    && self ->_bundleType != NSBUNDLE_LIBRARY)
    {
      /*
       * Prevent unloading of bundles where code has been loaded ...
       * the objc runtime does not currently support unloading of
       * dynamically loaded code, so we want to prevent a bundle
       * being loaded twice.
       */
      IF_NO_GC([self retain];)
      return;
    }
  if (_path != nil)
    {
      NSString	*identifier = [self bundleIdentifier];

      [load_lock lock];
      NSMapRemove(_bundles, _path);
      if (identifier != nil)
        {
	  NSMapRemove(_byIdentifier, identifier);
        }
      [load_lock unlock];
      RELEASE(_path);
    }
  TEST_RELEASE(_frameworkVersion);
  TEST_RELEASE(_bundleClasses);
  TEST_RELEASE(_infoDict);
  TEST_RELEASE(_localizations);
  [super dealloc];
}

- (NSString*) description
{
  return  [[super description] stringByAppendingFormat:
    @" <%@>%@", [self bundlePath], [self isLoaded] ? @" (loaded)" : @""];
}

- (NSString*) bundlePath
{
  return _path;
}

- (Class) classNamed: (NSString *)className
{
  int     i, j;
  Class   theClass = Nil;

  if (!_codeLoaded)
    {
      if (self != _mainBundle && ![self load])
	{
	  NSLog(@"No classes in bundle");
	  return Nil;
	}
    }

  if (self == _mainBundle || self == _gnustep_bundle)
    {
      theClass = NSClassFromString(className);
      if (theClass && [[self class] bundleForClass: theClass] != self)
        {
	  theClass = Nil;
	}
    }
  else
    {
      BOOL found = NO;

      theClass = NSClassFromString(className);
      [load_lock lock];
      j = [_bundleClasses count];

      for (i = 0; i < j  &&  found == NO; i++)
	{
	  Class c = (Class)[[_bundleClasses objectAtIndex: i] pointerValue];

	  if (c == theClass)
	    {
	      found = YES;
	    }
	}
      [load_lock unlock];

      if (found == NO)
	{
	  theClass = Nil;
	}
    }

  return theClass;
}

- (Class) principalClass
{
  NSString	*class_name;

  if (_principalClass)
    {
      return _principalClass;
    }

  if ([self load] == NO)
    {
      return Nil;
    }

  class_name = [[self infoDictionary] objectForKey: @"NSPrincipalClass"];

  if (class_name)
    {
      _principalClass = NSClassFromString(class_name);
    }
  else if (self == _gnustep_bundle)
    {
      _principalClass = [NSObject class];
    }

  if (_principalClass == nil)
    {
      [load_lock lock];
      if (_principalClass == nil && [_bundleClasses count] > 0)
	{
	  _principalClass = (Class)[[_bundleClasses objectAtIndex: 0]
	    pointerValue];
	}
      [load_lock unlock];
    }
  return _principalClass;
}

/**
 * Returns YES if the receiver's code is loaded, otherwise, returns NO.
 */
- (BOOL) isLoaded
{
  return _codeLoaded;
}

- (BOOL) load
{
  if (self == _mainBundle || self ->_bundleType == NSBUNDLE_LIBRARY)
    {
      _codeLoaded = YES;
      return YES;
    }

  [load_lock lock];

  if (_codeLoaded == NO)
    {
      NSString       *object;
      NSEnumerator   *classEnumerator;
      NSMutableArray *classNames;
      NSValue        *class;

      object = [self executablePath];
      if (object == nil || [object length] == 0)
	{
	  [load_lock unlock];
	  return NO;
	}
      _loadingBundle = self;
      _bundleClasses = [[NSMutableArray alloc] initWithCapacity: 2];
      _loadingFrameworks = RETAIN([NSMutableArray arrayWithCapacity: 2]);

      /* This code is executed twice if a class linked in the bundle call a
	 NSBundle method inside +load (-principalClass). To avoid this we set
	 _codeLoaded before loading the bundle. */
      _codeLoaded = YES;

      if (GSPrivateLoadModule(object, stderr, _bundle_load_callback, 0, 0))
	{
	  _codeLoaded = NO;
	  DESTROY(_loadingFrameworks);
	  DESTROY(_currentFrameworkName);
	  [load_lock unlock];
	  return NO;
	}

      /* We now construct the list of bundles from frameworks linked with
	 this one */
      classEnumerator = [_loadingFrameworks objectEnumerator];
      while ((class = [classEnumerator nextObject]) != nil)
	{
	  [NSBundle _addFrameworkFromClass: (Class)[class pointerValue]];
	}

      /* After we load code from a bundle, we retain the bundle until
	 we unload it (because we never unload bundles, that is
	 forever).  The reason why we retain it is that we need it!
	 We need it to answer calls like bundleForClass:; also, users
	 normally want all loaded bundles to appear when they call
	 +allBundles.  */
      IF_NO_GC([self retain];)
      _loadingBundle = nil;

      DESTROY(_loadingFrameworks);
      DESTROY(_currentFrameworkName);

      classNames = [NSMutableArray arrayWithCapacity: [_bundleClasses count]];
      classEnumerator = [_bundleClasses objectEnumerator];
      while ((class = [classEnumerator nextObject]) != nil)
	{
	  [classNames addObject:
	    NSStringFromClass((Class)[class pointerValue])];
	}

      [load_lock unlock];

      [[NSNotificationCenter defaultCenter]
        postNotificationName: NSBundleDidLoadNotification
        object: self
        userInfo: [NSDictionary dictionaryWithObject: classNames
	  forKey: NSLoadedClasses]];

      return YES;
    }
  [load_lock unlock];
  return YES;
}

- (void) release
{
  /* We lock during release so that other threads can't grab the
   * object between us checking the reference count and deallocating.
   */
  [load_lock lock];
  if (NSDecrementExtraRefCountWasZero(self))
    {
      [self dealloc];
    }
  [load_lock unlock];
}

/* This method is the backbone of the resource searching for NSBundle. It
   constructs an array of paths, where each path is a possible location
   for a resource in the bundle.  The current algorithm for searching goes:

     <rootPath>/Resources/<bundlePath>
     <rootPath>/Resources/<bundlePath>/<language.lproj>
     <rootPath>/<bundlePath>
     <rootPath>/<bundlePath>/<language.lproj>
*/
+ (NSArray *) _bundleResourcePathsWithRootPath: (NSString *)rootPath
				       subPath: (NSString *)subPath
{
  NSString* primary;
  NSString* language;
  NSArray* languages;
  NSMutableArray* array;
  NSEnumerator* enumerate;

  array = [NSMutableArray arrayWithCapacity: 8];
  languages = [NSUserDefaults userLanguages];

  primary = [rootPath stringByAppendingPathComponent: @"Resources"];
  [array addObject: _bundle_resource_path(primary, subPath, nil)];
  /* This matches OS X behavior, which only searches languages that
     are in the user's preference. Don't use -preferredLocalizations - 
     that would cause a recursive loop.  */
  enumerate = [languages objectEnumerator];
  while ((language = [enumerate nextObject]))
    [array addObject: _bundle_resource_path(primary, subPath, language)];

  primary = rootPath;
  [array addObject: _bundle_resource_path(primary, subPath, nil)];
  enumerate = [languages objectEnumerator];
  while ((language = [enumerate nextObject]))
    [array addObject: _bundle_resource_path(primary, subPath, language)];

  return array;
}

+ (NSString *) _pathForResource: (NSString *)name
			 ofType: (NSString *)ext	
		     inRootPath: (NSString *)rootPath
		    inDirectory: (NSString *)subPath
{
  NSFileManager	*mgr = manager();
  NSString	*path;
  NSEnumerator	*pathlist;

  if (name == nil)
    {
      name = @"";
    }
  if ([ext length] == 0)
    {
      ext = nil;
    }

  pathlist = [[self _bundleResourcePathsWithRootPath: rootPath
    subPath: subPath] objectEnumerator];
  while ((path = [pathlist nextObject]) != nil)
    {
      if (bundle_directory_readable(path))
	{
	  path = [path stringByAppendingPathComponent: name];
	  if (ext != nil)
	    {
	      path = [path stringByAppendingPathExtension: ext];
	    }
	  if ([mgr isReadableFileAtPath: path])
	    {
	      return path;
	    }
	}
    }

  return nil;
}


+ (NSString *) pathForResource: (NSString *)name
			ofType: (NSString *)ext	
		   inDirectory: (NSString *)bundlePath
		   withVersion: (int)version
{
  return [self _pathForResource: name
			 ofType: ext
		     inRootPath: bundlePath
		    inDirectory: nil];
}

+ (NSString *) pathForResource: (NSString *)name
			ofType: (NSString *)ext	
		   inDirectory: (NSString *)bundlePath
{
  return [self _pathForResource: name
			 ofType: ext
		     inRootPath: bundlePath
		    inDirectory: nil];
}

- (NSString *) pathForResource: (NSString *)name
			ofType: (NSString *)ext
{
  return [self pathForResource: name
			ofType: ext
		   inDirectory: nil];
}

- (NSString *) pathForResource: (NSString *)name
			ofType: (NSString *)ext
		   inDirectory: (NSString *)subPath
{
  NSString *rootPath;

#if !defined(__MINGW32__)
  if (_frameworkVersion)
    rootPath = [NSString stringWithFormat:@"%@/Versions/%@", [self bundlePath],
      _frameworkVersion];
  else
#endif
    rootPath = [self bundlePath];

  return [NSBundle _pathForResource: name
			     ofType: ext
			 inRootPath: rootPath
		        inDirectory: subPath];
}

+ (NSArray*) _pathsForResourcesOfType: (NSString*)extension
		      inRootDirectory: (NSString*)bundlePath
		       inSubDirectory: (NSString *)subPath
{
  BOOL allfiles;
  NSString *path;
  NSMutableArray *resources;
  NSEnumerator *pathlist;
  NSFileManager	*mgr = manager();

  pathlist = [[NSBundle _bundleResourcePathsWithRootPath: bundlePath
			subPath: subPath] objectEnumerator];
  resources = [NSMutableArray arrayWithCapacity: 2];
  allfiles = (extension == nil || [extension length] == 0);

  while ((path = [pathlist nextObject]))
    {
      NSEnumerator *filelist;
      NSString *match;

      filelist = [[mgr directoryContentsAtPath: path] objectEnumerator];
      while ((match = [filelist nextObject]))
	{
	  if (allfiles || [extension isEqual: [match pathExtension]])
	    [resources addObject: [path stringByAppendingPathComponent: match]];
	}
    }

  return resources;
}

+ (NSArray*) pathsForResourcesOfType: (NSString*)extension
			 inDirectory: (NSString*)bundlePath
{
  return [self _pathsForResourcesOfType: extension
			inRootDirectory: bundlePath
			 inSubDirectory: nil];
}

- (NSArray *) pathsForResourcesOfType: (NSString *)extension
			  inDirectory: (NSString *)subPath
{
  return [[self class] _pathsForResourcesOfType: extension
			inRootDirectory: [self bundlePath]
			 inSubDirectory: subPath];
}

- (NSArray*) pathsForResourcesOfType: (NSString*)extension
			 inDirectory: (NSString*)subPath
		     forLocalization: (NSString*)localizationName
{
  NSArray         *paths = nil;
  NSMutableArray  *result = nil;
  NSEnumerator    *enumerator = nil;
  NSString        *path = nil;

  result = [NSMutableArray array];
  paths = [self pathsForResourcesOfType: extension
                            inDirectory: subPath];

  enumerator = [paths objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      /* Add all non-localized paths, plus ones in the particular localization
	 (if there is one). */
      NSString *theDir = [path stringByDeletingLastPathComponent];

      if ([[theDir pathExtension] isEqual: @"lproj"] == NO)
	{
	  [result addObject: path];
	}
      else if ([localizationName length] > 0
	&& [[theDir lastPathComponent] hasPrefix: localizationName])
	{ 
	  [result insertObject: path atIndex: 0];
	}
    }
  
  return result;
}

- (NSString*) pathForResource: (NSString*)name
		       ofType: (NSString*)ext
		  inDirectory: (NSString*)subPath
	      forLocalization: (NSString*)localizationName
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString	*result = nil;
  NSArray	*array;

  array = [self pathsForResourcesOfType: ext
                            inDirectory: subPath
                        forLocalization: localizationName];

  if (array != nil)
    {
      NSEnumerator	*enumerator = [array objectEnumerator];
      NSString		*path;

      name = [name stringByAppendingPathExtension: ext];
      while ((path = [enumerator nextObject]) != nil)
	{
	  NSString	*found = [path lastPathComponent];

	  if ([found isEqualToString: name] == YES)
	    {
	      result = path;
	      break;		// localised paths occur before non-localised
	    }
	}
    }
  IF_NO_GC([result retain]; DESTROY(arp);)
  return AUTORELEASE(result);
}

+ (NSArray *) preferredLocalizationsFromArray: (NSArray *)localizationsArray
{
  return [self preferredLocalizationsFromArray: localizationsArray
	         forPreferences: [NSUserDefaults userLanguages]];
}

+ (NSArray *) preferredLocalizationsFromArray: (NSArray *)localizationsArray
			       forPreferences: (NSArray *)preferencesArray
{
  NSString	*locale;
  NSMutableArray	*array;
  NSEnumerator	*enumerate;

  array = [NSMutableArray arrayWithCapacity: 2];
  enumerate = [preferencesArray objectEnumerator];
  while ((locale = [enumerate nextObject]))
    {
      if ([localizationsArray indexOfObject: locale] != NSNotFound)
	[array addObject: locale];
    }
  /* I guess this is arbitrary if we can't find a match? */
  if ([array count] == 0 && [localizationsArray count] > 0)
    [array addObject: [localizationsArray objectAtIndex: 0]];
  return [array makeImmutableCopyOnFail: NO];
}

- (NSDictionary*) localizedInfoDictionary
{
  NSString  *path;
  NSArray   *locales;
  NSString  *locale = nil;
  NSDictionary *dict = nil;

  locales = [self preferredLocalizations];
  if ([locales count] > 0)
    locale = [locales objectAtIndex: 0];
  path = [self pathForResource: @"Info-gnustep"
                        ofType: @"plist"
                   inDirectory: nil
               forLocalization: locale];
  if (path)
    {
      dict = [[NSDictionary alloc] initWithContentsOfFile: path];
    }
  else
    {
      path = [self pathForResource: @"Info"
                            ofType: @"plist"
                       inDirectory: nil
                   forLocalization: locale];
      if (path)
	{
	  dict = [[NSDictionary alloc] initWithContentsOfFile: path];
	}
    }
  if (dict == nil)
    dict = [self infoDictionary];
  return dict;
}

- (id) objectForInfoDictionaryKey: (NSString *)key
{
  return nil;
}

- (NSString*) developmentLocalization
{
  return nil;
}

- (NSArray *) localizations
{
  NSString *locale;
  NSArray *localizations;
  NSEnumerator* enumerate;
  NSMutableArray *array = [NSMutableArray arrayWithCapacity: 2];

  localizations = [self pathsForResourcesOfType: @"lproj"
	                            inDirectory: nil];
  enumerate = [localizations objectEnumerator];
  while ((locale = [enumerate nextObject]))
    {
      locale = [[locale lastPathComponent] stringByDeletingPathExtension];
      [array addObject: locale];
    }
  return [array makeImmutableCopyOnFail: NO];
}

- (NSArray *) preferredLocalizations
{
  return [NSBundle preferredLocalizationsFromArray: [self localizations]];
}

- (NSString *) localizedStringForKey: (NSString *)key	
                               value: (NSString *)value
                               table: (NSString *)tableName
{
  NSDictionary	*table;
  NSString	*newString = nil;

  if (_localizations == nil)
    _localizations = [[NSMutableDictionary alloc] initWithCapacity: 1];

  if (tableName == nil || [tableName isEqualToString: @""] == YES)
    {
      tableName = @"Localizable";
      table = [_localizations objectForKey: tableName];
    }
  else if ((table = [_localizations objectForKey: tableName]) == nil
    && [@"strings" isEqual: [tableName pathExtension]] == YES)
    {
      tableName = [tableName stringByDeletingPathExtension];
      table = [_localizations objectForKey: tableName];
    }

  if (table == nil)
    {
      NSString	*tablePath;

      /*
       * Make sure we have an empty table in place in case anything
       * we do somehow causes recursion.  The recursive call will look
       * up the string in the empty table.
       */
      [_localizations setObject: _emptyTable forKey: tableName];

      tablePath = [self pathForResource: tableName ofType: @"strings"];
      if (tablePath != nil)
        {
          NSStringEncoding	encoding;
          NSString		*tableContent;
          NSData		*tableData;
          const unsigned char	*bytes;
          unsigned		length;
          
          tableData = [[NSData alloc] initWithContentsOfFile: tablePath];
          bytes = [tableData bytes];
          length = [tableData length];
          /*
           * A localisation file can be ...
           * UTF16 with a leading BOM,
           * UTF8 with a leading BOM,
           * or ASCII (the original standard) with \U escapes.
           */
          if (length > 2
              && ((bytes[0] == 0xFF && bytes[1] == 0xFE)
                  || (bytes[0] == 0xFE && bytes[1] == 0xFF)))
            {
              encoding = NSUnicodeStringEncoding;
            }
          else if (length > 2
                   && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
            {
              encoding = NSUTF8StringEncoding;
            }
          else
            {
              encoding = NSASCIIStringEncoding;
            }
          tableContent = [[NSString alloc] initWithData: tableData
                                           encoding: encoding];
          if (tableContent == nil && encoding == NSASCIIStringEncoding)
            {
              encoding = [NSString defaultCStringEncoding];
              tableContent = [[NSString alloc] initWithData: tableData
                                               encoding: encoding];
              if (tableContent != nil)
                {
                  NSWarnMLog (@"Localisation file %@ not in portable encoding"
                              @" so I'm using the default encoding for the current"
                              @" system, which may not display messages correctly.\n"
                              @"The file should be ASCII (using \\U escapes for unicode"
                              @" characters) or Unicode (UTF16 or UTF8) with a leading "
                              @"byte-order-marker.\n", tablePath);
                }
            }
          if (tableContent == nil)
            {
              NSWarnMLog(@"Failed to load strings file %@ - bad character"
                         @" encoding", tablePath);
            }
          else
            {
              NS_DURING
                {
                  table = [tableContent propertyListFromStringsFileFormat];
                }
              NS_HANDLER
                {
                  NSWarnMLog(@"Failed to parse strings file %@ - %@",
                             tablePath, localException);
                }
              NS_ENDHANDLER
            }
          RELEASE(tableData);
          RELEASE(tableContent);
        }
      else
        {
          NSDebugMLLog(@"NSBundle", @"Failed to locate strings file %@",
                       tableName);
        }
      /*
       * If we couldn't found and parsed the strings table, we put it in
       * the cache of strings tables in this bundle, otherwise we will just
       * be keeping the empty table in the cache so we don't keep retrying.
       */
      if (table != nil)
        [_localizations setObject: table forKey: tableName];
    }

  if (key == nil || (newString = [table objectForKey: key]) == nil)
    {
      NSString	*show = [[NSUserDefaults standardUserDefaults]
                            objectForKey: NSShowNonLocalizedStrings];
      if (show && [show isEqual: @"YES"])
        {
          /* It would be bad to localize this string! */
          NSLog(@"Non-localized string: %@\n", key);
          newString = [key uppercaseString];
        }
      else
        {
          newString = value;
          if (newString == nil || [newString isEqualToString: @""] == YES)
            newString = key;
        }
      if (newString == nil)
        newString = @"";
    }

  return newString;
}

+ (void) stripAfterLoading: (BOOL)flag
{
  _strip_after_loading = flag;
}

- (NSArray *) executableArchitectures
{
  return nil;
}
- (BOOL) preflightAndReturnError: (NSError **)error
{
  return NO;
}
- (BOOL) loadAndReturnError: (NSError **)error
{
  return NO;
}


- (NSString *) executablePath
{
  NSString *object, *path;

  if (!_mainBundle)
    {
      [NSBundle mainBundle];
    }
  if (self == _mainBundle)
    {
      return GSPrivateExecutablePath();
    }
  if (self->_bundleType == NSBUNDLE_LIBRARY)
    {
      return GSPrivateSymbolPath ([self principalClass], NULL);
    }
  object = [[self infoDictionary] objectForKey: @"NSExecutable"];
  if (object == nil || [object length] == 0)
    {
      object = [[self infoDictionary] objectForKey: @"CFBundleExecutable"];
      if(object == nil || [object length] == 0)
	  {
	    return nil;
	  }
    }
  if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
      /* Mangle the name before building the _currentFrameworkName,
       * which really is a class name.
       */
      NSString *mangledName = object;
      mangledName = [mangledName stringByReplacingString: @"_"  
				 withString: @"__"];
      mangledName = [mangledName stringByReplacingString: @"-" 
				 withString: @"_0"];
      mangledName = [mangledName stringByReplacingString: @"+" 
				 withString: @"_1"];

#if !defined(__MINGW32__)
      path = [_path stringByAppendingPathComponent:@"Versions/Current"];
#else
      path = _path;
#endif

      _currentFrameworkName = RETAIN(([NSString stringWithFormat:
						  @"NSFramework_%@",
						mangledName]));
    }
  else
    {
      path = _path;
    }

  object = bundle_object_name(path, object);
  return object;
}

- (NSString *) resourcePath
{
  NSString *version = _frameworkVersion;

  if (!version)
    version = @"Current";

  if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
#if !defined(__MINGW32__)
      return [_path stringByAppendingPathComponent:
		      [NSString stringWithFormat:@"Versions/%@/Resources",
				version]];
#else
      /* No Versions (that require symlinks) on MINGW */
      return [_path stringByAppendingPathComponent: @"Resources"];
#endif
    }
  else
    {
      return [_path stringByAppendingPathComponent: @"Resources"];
    }
}

- (NSDictionary *) infoDictionary
{
  NSString* path;

  if (_infoDict)
    return _infoDict;

  path = [self pathForResource: @"Info-gnustep" ofType: @"plist"];
  if (path)
    {
      _infoDict = [[NSDictionary alloc] initWithContentsOfFile: path];
    }
  else
    {
      path = [self pathForResource: @"Info" ofType: @"plist"];
      if (path)
	{
	  _infoDict = [[NSDictionary alloc] initWithContentsOfFile: path];
	}
      else
	{
	  _infoDict = RETAIN([NSDictionary dictionary]);
	}
    }
  return _infoDict;
}

- (NSString *) builtInPlugInsPath
{
  NSString  *version = _frameworkVersion;

  if (!version)
    version = @"Current";

  if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
#if !defined(__MINGW32__)
      return [_path stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"Versions/%@/PlugIns",
                      version]];
#else
      return [_path stringByAppendingPathComponent: @"PlugIns"];
#endif
    }
  else
    {
      return [_path stringByAppendingPathComponent: @"PlugIns"];
    }
}

- (NSString*) bundleIdentifier
{
  return [[self infoDictionary] objectForKey: @"CFBundleIdentifier"];
}

- (unsigned) bundleVersion
{
  return _version;
}

- (void) setBundleVersion: (unsigned)version
{
  _version = version;
}

- (BOOL) unload
{
  return NO;
}
@end

@implementation NSBundle (GNUstep)

+ (NSBundle *) bundleForLibrary: (NSString *)libraryName
{
  return [self bundleForLibrary: libraryName  version: nil];
}

+ (NSBundle *) bundleForLibrary: (NSString *)libraryName
			version: (NSString *)interfaceVersion
{
  /* Important: if you change this code, make sure to also
   * change NSUserDefault's manual gnustep-base resource
   * lookup to match.
   */
  NSArray *paths;
  NSEnumerator *enumerator;
  NSString *path;
  NSFileManager *fm = manager();
  NSRange	r;

  if ([libraryName length] == 0)
    {
      return nil;
    }
  /*
   * Eliminate any base path or extensions.
   */
  libraryName = [libraryName lastPathComponent];

#if defined(__MINGW32__)
  /* A dll is usually of the form 'xxx-maj_min.dll'
   * so we can extract the version info and use it.
   */
  if ([[libraryName pathExtension] isEqual: @"dll"])
    {
      libraryName = [libraryName stringByDeletingPathExtension];
      r = [libraryName rangeOfString: @"-" options: NSBackwardsSearch];
      if (r.length > 0)
	{
	  NSString	*ver;

	  ver = [[libraryName substringFromIndex: NSMaxRange(r)]
	    stringByReplacingString: @"_" withString: @"."];
	  libraryName = [libraryName substringToIndex: r.location];
	  if (interfaceVersion == nil)
	    {
	      interfaceVersion = ver;
	    }
	}
    }
#else
  /* A .so is usually of the form 'libxxx.so.maj.min.sub'
   * so we can extract the version info and use it.
   */
  r = [libraryName rangeOfString: @".so."];
  if (r.length > 0)
    {
      NSString	*s = [libraryName substringFromIndex: NSMaxRange(r)];
      NSArray	*a = [s componentsSeparatedByString: @"."];

      libraryName = [libraryName substringToIndex: r.location];
      if (interfaceVersion == nil && [a count] >= 2)
	{
	  interfaceVersion = [NSString stringWithFormat: @"%@.%@",
	    [a objectAtIndex: 0], [a objectAtIndex: 1]];
	}
    }
#endif

  while ([[libraryName pathExtension] length] > 0)
    {
      libraryName = [libraryName stringByDeletingPathExtension];
    }

  /*
   * Discard leading 'lib'
   */
  if ([libraryName hasPrefix: @"lib"] == YES)
    {
      libraryName = [libraryName substringFromIndex: 3];
    }

  if ([libraryName length] == 0)
    {
      return nil;
    }

  /*
   * We expect to find the library resources in the GNUSTEP_LIBRARY domain in:
   *
   * Libraries/<libraryName>/Versions/<interfaceVersion>/Resources/
   *
   * if no <interfaceVersion> is specified, and if can't find any versioned
   * resources in those directories, we'll also accept the old unversioned
   * subdirectory: 
   *
   * Libraries/Resources/<libraryName>/
   *
   */
  paths = NSSearchPathForDirectoriesInDomains (NSLibraryDirectory,
					       NSAllDomainsMask, YES);
  
  enumerator = [paths objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      NSBundle	*b;
      BOOL isDir;
      path = [path stringByAppendingPathComponent: @"Libraries"];

      if ([fm fileExistsAtPath: path  isDirectory: &isDir]  &&  isDir)
	{
	  /* As a special case, if we have been asked to get the base
	   * library bundle without a version, we check to see if the
	   * bundle for the current version is available and use that
	   * in preference to all others.
	   * This lets older code (using the non-versioned api) work
	   * on systems where multiple versions are installed.
	   */
	  if (interfaceVersion == nil
	    && [libraryName isEqualToString: @"gnustep-base"])
	    {
	      NSString	*p;

	      p = [[[[path stringByAppendingPathComponent: libraryName]
			 stringByAppendingPathComponent: @"Versions"]
			stringByAppendingPathComponent: _base_version]
		       stringByAppendingPathComponent: @"Resources"];
	      if ([fm fileExistsAtPath: p  isDirectory: &isDir]  &&  isDir)
	        {
		  interfaceVersion = _base_version;
		}
	    }

	  if (interfaceVersion != nil)
	    {
	      /* We're looking for a specific version.  */
	      path = [[[[path stringByAppendingPathComponent: libraryName]
			 stringByAppendingPathComponent: @"Versions"]
			stringByAppendingPathComponent: interfaceVersion]
		       stringByAppendingPathComponent: @"Resources"];
	      if ([fm fileExistsAtPath: path  isDirectory: &isDir]  &&  isDir)
		{
		  b = [self bundleWithPath: path];
		  
		  if (b != nil && b->_bundleType == NSBUNDLE_BUNDLE)
		    {
		      b->_bundleType = NSBUNDLE_LIBRARY;
		    }
		  return b;
		}
	    }
	  else
	    {
	      /* Any version will do.  */
	      NSString *versionsPath;

	      versionsPath
		= [[path stringByAppendingPathComponent: libraryName]
			 stringByAppendingPathComponent: @"Versions"];

	      if ([fm fileExistsAtPath: versionsPath  isDirectory: &isDir]
	        && isDir)
		{
		  /* TODO: Ignore subdirectories.  */
		  NSEnumerator *fileEnumerator;
		  NSString *potentialPath;
		  
		  fileEnumerator = [fm enumeratorAtPath: versionsPath];
		  while ((potentialPath = [fileEnumerator nextObject]) != nil)
		    {
		      potentialPath = [potentialPath
			stringByAppendingPathComponent: @"Resources"];
		      potentialPath = [versionsPath
			stringByAppendingPathComponent: potentialPath];
		      if ([fm fileExistsAtPath: potentialPath
				   isDirectory: &isDir]  &&  isDir)
			{
			  b = [self bundleWithPath: potentialPath];
			  
			  if (b != nil && b->_bundleType == NSBUNDLE_BUNDLE)
			    {
			      b->_bundleType = NSBUNDLE_LIBRARY;
			    }
			  return b;
			}
		    }
		}

	      /* We didn't find anything!  For backwards
	       * compatibility, try the unversioned directory itself:
	       * we used to put library resources directly in
	       * unversioned directories such as
	       * GNUSTEP_LIBRARY/Libraries/Resources/gnustep-base/{resources
	       * here}.  This was deprecated/obsoleted on 9 March 2007
	       * when we added library resource versioning.
	       */
	      {
		NSString *oldResourcesPath;

		oldResourcesPath = [path
		  stringByAppendingPathComponent: @"Resources"];
		oldResourcesPath = [oldResourcesPath
		  stringByAppendingPathComponent: libraryName];
		if ([fm fileExistsAtPath: oldResourcesPath
		  isDirectory: &isDir]  &&  isDir)
		  {
		    b = [self bundleWithPath: oldResourcesPath];
		    if (b != nil && b->_bundleType == NSBUNDLE_BUNDLE)
		      {
			b->_bundleType = NSBUNDLE_LIBRARY;
		      }
		    return b;
		  }
	      }
	    }
	}
    }

  return nil;
}

+ (NSString *) pathForLibraryResource: (NSString *)name
			       ofType: (NSString *)ext	
			  inDirectory: (NSString *)bundlePath
{
  NSString	*path = nil;
  NSString	*bundle_path = nil;
  NSArray	*paths;
  NSBundle	*bundle;
  NSEnumerator	*enumerator;

  /* Gather up the paths */
  paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                              NSAllDomainsMask, YES);

  enumerator = [paths objectEnumerator];
  while ((path == nil) && (bundle_path = [enumerator nextObject]))
    {
      bundle = [self bundleWithPath: bundle_path];
      path = [bundle pathForResource: name
                              ofType: ext
                         inDirectory: bundlePath];
    }

  return path;
}

@end

