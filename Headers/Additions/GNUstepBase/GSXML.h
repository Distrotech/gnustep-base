/** Interface for XML parsing classes

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Michael Pakhantsov  <mishel@berest.dp.ua> on behalf of
   Brainstorm computer solutions.

   Date: Jule 2000

   Integrated by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: September 2000
   GSXPath by Nicola Pero <nicola@brainstorm.co.uk>

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

   AutogsdocSource: Additions/GSXML.m

*/

#ifndef __GSXML_H__
#define __GSXML_H__

#ifndef NeXT_Foundation_LIBRARY
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef	STRICT_MACOS_X
#ifndef	STRICT_OPENSTEP

@class GSXMLAttribute;
@class GSXMLDocument;
@class GSXMLNamespace;
@class GSXMLNode;
@class GSSAXHandler;


@interface GSXMLDocument : NSObject <NSCopying>
{
  void	*lib;	// pointer to xmllib pointer of xmlDoc struct
  BOOL	_ownsLib;
  id	_parent;
}
+ (GSXMLDocument*) documentWithVersion: (NSString*)version;

- (NSString*) description;
- (NSString*) encoding;

- (void*) lib;

- (GSXMLNode*) makeNodeWithNamespace: (GSXMLNamespace*)ns
				name: (NSString*)name
			     content: (NSString*)content;

- (GSXMLNode*) root;
- (GSXMLNode*) setRoot: (GSXMLNode*)node;

- (NSString*) version;

- (BOOL) writeToFile: (NSString*)filename atomically: (BOOL)useAuxilliaryFile;
- (BOOL) writeToURL: (NSURL*)url atomically: (BOOL)useAuxilliaryFile;

@end



@interface GSXMLNamespace : NSObject <NSCopying>
{
  void	*lib;          /* pointer to struct xmlNs in the gnome xmllib */
  id	_parent;
}

+ (NSString*) descriptionFromType: (int)type;
+ (int) typeFromDescription: (NSString*)desc;

- (NSString*) href;

- (void*) lib;
- (GSXMLNamespace*) next;
- (NSString*) prefix;
- (int) type;
- (NSString*) typeDescription;

@end

/* XML Node */

@interface GSXMLNode : NSObject <NSCopying>
{
  void  *lib;      /* pointer to struct xmlNode from libxml */
  id	_parent;
}

+ (NSString*) descriptionFromType: (int)type;
+ (int) typeFromDescription: (NSString*)desc;

- (NSDictionary*) attributes;
- (NSString*) content;
- (NSString*) description;
- (GSXMLDocument*) document;
- (NSString*) escapedContent;
- (GSXMLAttribute*) firstAttribute;
- (GSXMLNode*) firstChild;
- (GSXMLNode*) firstChildElement;
- (BOOL) isElement;
- (BOOL) isText;
- (void*) lib;
- (GSXMLAttribute*) makeAttributeWithName: (NSString*)name
				    value: (NSString*)value;
- (GSXMLNode*) makeChildWithNamespace: (GSXMLNamespace*)ns
				 name: (NSString*)name
			      content: (NSString*)content;
- (GSXMLNode*) makeComment: (NSString*)content;
- (GSXMLNamespace*) makeNamespaceHref: (NSString*)href
			       prefix: (NSString*)prefix;
- (GSXMLNode*) makePI: (NSString*)name
	      content: (NSString*)content;
- (GSXMLNode*) makeText: (NSString*)content;
- (NSString*) name;
- (GSXMLNamespace*) namespace;
- (GSXMLNamespace*) namespaceDefinitions;
- (GSXMLNode*) next;
- (GSXMLNode*) nextElement;
- (NSString*) objectForKey: (NSString*)key;
- (GSXMLNode*) parent;
- (GSXMLNode*) previous;
- (GSXMLNode*) previousElement;
- (NSMutableDictionary*) propertiesAsDictionaryWithKeyTransformationSel:
  (SEL)keyTransformSel;
- (void) setObject: (NSString*)value forKey:(NSString*)key;
- (int) type;
- (NSString*) typeDescription;
- (void) setNamespace: (GSXMLNamespace *)space;

@end

@interface GSXMLAttribute : GSXMLNode
- (NSString*) value;
@end

@interface GSXMLParser : NSObject
{
   id			src;		/* source for parsing	*/
   void			*lib;		/* parser context	*/
   GSSAXHandler		*saxHandler;	/* handler for parsing	*/
   NSMutableString	*messages;	/* append messages here	*/
}
+ (NSString*) loadEntity: (NSString*)publicId at: (NSString*)location;
+ (GSXMLParser*) parser;
+ (GSXMLParser*) parserWithContentsOfFile: (NSString*)path;
+ (GSXMLParser*) parserWithContentsOfURL: (NSURL*)url;
+ (GSXMLParser*) parserWithData: (NSData*)data;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
		   withContentsOfFile: (NSString*)path;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
		    withContentsOfURL: (NSURL*)url;
+ (GSXMLParser*) parserWithSAXHandler: (GSSAXHandler*)handler
			     withData: (NSData*)data;
+ (NSString*) xmlEncodingStringForStringEncoding: (NSStringEncoding)encoding;

- (GSXMLDocument*) document;
- (BOOL) doValidityChecking: (BOOL)yesno;
- (int) errNo;
- (BOOL) getWarnings: (BOOL)yesno;
- (id) initWithSAXHandler: (GSSAXHandler*)handler;
- (id) initWithSAXHandler: (GSSAXHandler*)handler
       withContentsOfFile: (NSString*)path;
- (id) initWithSAXHandler: (GSSAXHandler*)handler
	withContentsOfURL: (NSURL*)url;
- (id) initWithSAXHandler: (GSSAXHandler*)handler
		 withData: (NSData*)data;

- (BOOL) keepBlanks: (BOOL)yesno;
- (NSString*) messages;
- (BOOL) parse;
- (BOOL) parse: (NSData*)data;
- (void) saveMessages: (BOOL)yesno;
- (BOOL) substituteEntities: (BOOL)yesno;

@end

@interface GSHTMLParser : GSXMLParser
{
}
@end

@interface GSSAXHandler : NSObject
{
  void		*lib;	// xmlSAXHandlerPtr
  GSXMLParser	*parser;
@protected
  BOOL		isHtmlHandler;
}
+ (GSSAXHandler*) handler;
- (void*) lib;
- (GSXMLParser*) parser;

/* callbacks ... */
- (void) attribute: (NSString*)name
	     value: (NSString*)value;
- (void) attributeDecl: (NSString*)nameElement
                  name: (NSString*)name
                  type: (int)type
          typeDefValue: (int)defType
          defaultValue: (NSString*)value;
- (void) characters: (NSString*)name;
- (void) cdataBlock: (NSString*)value;
- (void) comment: (NSString*) value;
- (void) elementDecl: (NSString*)name
		type: (int)type;
- (void) endDocument;
- (void) endElement: (NSString*)elementName;
- (void) entityDecl: (NSString*)name
               type: (int)type
             public: (NSString*)publicId
             system: (NSString*)systemId
            content: (NSString*)content;
- (void) error: (NSString*)e;
- (void) error: (NSString*)e
     colNumber: (int)colNumber
    lineNumber: (int)lineNumber;
- (BOOL) externalSubset: (NSString*)name
             externalID: (NSString*)externalID
               systemID: (NSString*)systemID;
- (void) fatalError: (NSString*)e;
- (void) fatalError: (NSString*)e
          colNumber: (int)colNumber
         lineNumber: (int)lineNumber;
- (void*) getEntity: (NSString*)name;
- (void*) getParameterEntity: (NSString*)name;
- (void) globalNamespace: (NSString*)name
		    href: (NSString*)href
		  prefix: (NSString*)prefix;
- (int) hasExternalSubset;
- (int) hasInternalSubset;
- (void) ignoreWhitespace: (NSString*)ch;
- (BOOL) internalSubset: (NSString*)name
             externalID: (NSString*)externalID
               systemID: (NSString*)systemID;
- (int) isStandalone;
- (NSString*) loadEntity: (NSString*)publicId
		      at: (NSString*)location;
- (void) namespaceDecl: (NSString*)name
		  href: (NSString*)href
		prefix: (NSString*)prefix;
- (void) notationDecl: (NSString*)name
	       public: (NSString*)publicId
	       system: (NSString*)systemId;
- (void) processInstruction: (NSString*)targetName
		       data: (NSString*)PIdata;
- (void) reference: (NSString*)name;
- (void) startDocument;
- (void) startElement: (NSString*)elementName
           attributes: (NSMutableDictionary*)elementAttributes;
- (void) unparsedEntityDecl: (NSString*)name
		     public: (NSString*)publicId
		     system: (NSString*)systemId
	       notationName: (NSString*)notation;
- (void) warning: (NSString*)e;
- (void) warning: (NSString*)e
       colNumber: (int)colNumber
      lineNumber: (int)lineNumber;

@end

@interface GSTreeSAXHandler : GSSAXHandler
@end

@interface GSHTMLSAXHandler : GSSAXHandler
@end

@class GSXPathObject;

/*
 * Using this library class is trivial.  Get your GSXMLDocument.  Create
 * a GSXPathContext for it.
 *
 * GSXPathContext *p = [[GSXPathContext alloc] initWithDocument: document];
 *
 * Then, you can use it to evaluate XPath expressions:
 *
 * GSXPathString *result = [p evaluateExpression: @"string(/body/text())"];
 * NSLog (@"Got %@", [result stringValue]);
 *
 */
@interface GSXPathContext : NSObject
{
  void		*_lib;		// xmlXPathContext
  GSXMLDocument *_document;
}
- (id) initWithDocument: (GSXMLDocument*)d;
- (GSXPathObject*) evaluateExpression: (NSString*)XPathExpression;
@end

/** XPath queries return a GSXPathObject.  GSXPathObject in itself is
 * an abstract class; there are four types of completely different
 * GSXPathObject types, listed below.  I'm afraid you need to check
 * the returned type of each GSXPath query to make sure it's what you
 * meant it to be.
 */
@interface GSXPathObject : NSObject
{
  void		*_lib;		// xmlXPathObject
  GSXPathContext *_context;
}
@end

/**
 * For XPath queries returning true/false.
 */
@interface GSXPathBoolean : GSXPathObject
- (BOOL) booleanValue;
@end

/**
 * For XPath queries returning a number.
 */
@interface GSXPathNumber : GSXPathObject
- (double) doubleValue;
@end

/**
 * For XPath queries returning a string.
 */
@interface GSXPathString : GSXPathObject
- (NSString *) stringValue;
@end

/**
 * For XPath queries returning a node set.
 */
@interface GSXPathNodeSet : GSXPathObject
- (unsigned int) count;
- (unsigned int) length;

/** Please note that index starts from 0.  */
- (GSXMLNode *) nodeAtIndex: (unsigned)index;
@end

@interface GSXMLDocument (XSLT)
+ (GSXMLDocument*) xsltTransformFile: (NSString*)xmlFile
                          stylesheet: (NSString*)xsltStylesheet
		              params: (NSDictionary*)params;
			
+ (GSXMLDocument*) xsltTransformFile: (NSString*)xmlFile
                          stylesheet: (NSString*)xsltStylesheet;
			
+ (GSXMLDocument*) xsltTransformXml: (NSData*)xmlData
                         stylesheet: (NSData*)xsltStylesheet
		             params: (NSDictionary*)params;
			
+ (GSXMLDocument*) xsltTransformXml: (NSData*)xmlData
                         stylesheet: (NSData*)xsltStylesheet;
			
- (GSXMLDocument*) xsltTransform: (GSXMLDocument*)xsltStylesheet
                          params: (NSDictionary*)params;
			
- (GSXMLDocument*) xsltTransform: (GSXMLDocument*)xsltStylesheet;
@end

#endif	/* STRICT_MACOS_X */
#endif	/* STRICT_OPENSTEP */

#endif /* __GSXML_H__ */

