/* Interface for NSComparisonPredicate for GNUStep
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by:  Dr. H. Nikolaus Schaller
   Created: 2005
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#ifndef __NSComparisonPredicate_h_GNUSTEP_BASE_INCLUDE
#define __NSComparisonPredicate_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSExpression.h>
#include <Foundation/NSPredicate.h>

typedef enum _NSComparisonPredicateModifier
{
  NSDirectPredicateModifier=0,
  NSAllPredicateModifier,
  NSAnyPredicateModifier,
} NSComparisonPredicateModifier;

typedef enum _NSComparisonPredicateOptions
{
  NSCaseInsensitivePredicateOption=0x01,
  NSDiacriticInsensitivePredicateOption=0x02,
} NSComparisonPredicateOptions;

typedef enum _NSPredicateOperatorType
{
  NSLessThanPredicateOperatorType = 0,
  NSLessThanOrEqualToPredicateOperatorType,
  NSGreaterThanPredicateOperatorType,
  NSGreaterThanOrEqualToPredicateOperatorType,
  NSEqualToPredicateOperatorType,
  NSNotEqualToPredicateOperatorType,
  NSMatchesPredicateOperatorType,
  NSLikePredicateOperatorType,
  NSBeginsWithPredicateOperatorType,
  NSEndsWithPredicateOperatorType,
  NSInPredicateOperatorType,
  NSCustomSelectorPredicateOperatorType
} NSPredicateOperatorType;

@interface NSComparisonPredicate : NSPredicate
{
  NSComparisonPredicateModifier	_modifier;
  SEL				_selector;
  unsigned			_options;
  NSPredicateOperatorType	_type;
  @public
  NSExpression			*_left;
  NSExpression			*_right;
}

+ (NSPredicate *) predicateWithLeftExpression: (NSExpression *)left
			      rightExpression: (NSExpression *)right
			       customSelector: (SEL)sel;
+ (NSPredicate *) predicateWithLeftExpression: (NSExpression *)left
  rightExpression: (NSExpression *)right
  modifier: (NSComparisonPredicateModifier)modifier
  type: (NSPredicateOperatorType)type
  options: (unsigned) opts;

- (NSComparisonPredicateModifier) comparisonPredicateModifier;
- (SEL) customSelector;
- (NSPredicate *) initWithLeftExpression: (NSExpression *)left
			 rightExpression: (NSExpression *)right
			  customSelector: (SEL)sel;
- (id) initWithLeftExpression: (NSExpression *)left
	      rightExpression: (NSExpression *)right
		     modifier: (NSComparisonPredicateModifier)modifier
			 type: (NSPredicateOperatorType)type
		      options: (unsigned) opts;
- (NSExpression *) leftExpression;
- (unsigned) options;
- (NSPredicateOperatorType) predicateOperatorType;
- (NSExpression *) rightExpression;

@end

#endif
