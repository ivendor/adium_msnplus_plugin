//
//  Created by Andrea Gianarro on 23/06/08.
//  Copyright 2008 Andrea Gianarro. All rights reserved.
//	Revised by Tiziano Carotti
//

#import "BBNode.h"

//This values were copied from the pidgin plus extension, released under GPL v2, 2004 Stu Tomlinson <stu@nosnilmot.com>.
NSString *colorCodes[] = {
@"ffffff",@"000000",@"00007D",@"009100",@"FF0000",@"7D0000",@"9A009A",@"FC7D00",
@"FFFF00",@"00FC00",@"009191",@"00FFFF",@"1E1EFC",@"FF00FF",@"7D7D7D",@"D2D2D2",
@"E7E6E4",@"cfcdd0",@"ffdea4",@"ffaeb9",@"ffa8ff",@"c1b4fc",@"bafbe5",@"ccffa3",
@"fafda2",@"b6b4b7",@"a2a0a1",@"f9c152",@"ff6d66",@"ff62ff",@"6c6cff",@"68ffc3",
@"000000",@"f9ff57",@"858482",@"6e6d7b",@"ffa01e",@"F92411",@"FF1EFF",@"1E29FF",
@"7dffa5",@"60f913",@"fff813",@"5e6464",@"4b494c",@"d98812",@"eb0505",@"de00de",
@"0000d3",@"03cc88",@"59d80d",@"d4c804",@"333335",@"18171c",@"944e00",@"9b0008",
@"980299",@"01038c",@"01885f",@"389600",@"9a9e15",@"473400",@"4d0000",@"5f0162",
@"000047",@"06502f",@"1c5300",@"544d05"};

//Helper method
static NSColor* colorFromHexRGB(NSString *inColorString) {
	unsigned int colorCode = 0;
	unsigned char redByte, greenByte, blueByte;
	
	if (inColorString)
	{
		if ([inColorString hasPrefix:@"#"])
			inColorString = [inColorString substringFromIndex: 1];
		NSScanner *scanner = [NSScanner scannerWithString:inColorString];
		if(![scanner scanHexInt:&colorCode])
			colorCode=0;
	}
	redByte		= (unsigned char) (colorCode >> 16);
	greenByte	= (unsigned char) (colorCode >> 8);
	blueByte	= (unsigned char) (colorCode);
	return [NSColor
		colorWithCalibratedRed:		(float)redByte	/ 0xff
							green:	(float)greenByte/ 0xff
							blue:	(float)blueByte	/ 0xff
							alpha:  1.0];
}

@implementation BBNode

- (id) init
{
	self = [super init];
	if (self) {
		children = [[NSMutableArray alloc] init];
		value = @"";
	}
	return self;
}

- (void) addChild: (BBNode *) node
{
	[node setParent: self];
	[children addObject: node];
}

- (NSMutableArray *) children
{
	return children;
}

- (void) setParent: (BBNode *) myParent
{
	parent = myParent;
}

- (BBNode *) parent
{
	return parent;
}

- (void) setType: (NSString *) myType andValue: (NSString *) myValue
{
	if( ![myType isEqualToString:@"text"] && ![myValue hasPrefix:@"#"] && [myValue intValue]>=0 && [myValue intValue]<68) {
		myValue = [@"#" stringByAppendingString:[NSString stringWithString:colorCodes[[myValue intValue]]]];
	}
	[type release];
	[value release];
	type = [[myType lowercaseString] retain];
	value = [myValue retain];
}

- (NSString *) type
{
	return type;
}

- (NSString *) value
{
	return value;
}

- (NSString *) parseIntoHTML
{
	NSEnumerator *enm = [children objectEnumerator];
	BBNode *node;
	NSMutableString *stringa = [NSMutableString stringWithCapacity:1];
	while((node = [enm nextObject])) {
		if([[node type] isEqualToString:@"a"]) {
			[stringa appendFormat:@"<span style=\"background:%@;\">%@</span>", [node value], [node parseIntoHTML]];
		} else if ([[node type] isEqualToString:@"b"]) {
			[stringa appendFormat:@"<span style=\"font-weight:bold;\">%@</span>", [node parseIntoHTML]];
		} else if ([[node type] isEqualToString:@"c"]) {
			[stringa appendFormat:@"<span style=\"color:%@;\">%@</span>", [node value], [node parseIntoHTML]];
		} else if ([[node type] isEqualToString:@"i"]) {
			[stringa appendFormat:@"<span style=\"font-style:italic;\">%@</span>", [node parseIntoHTML]];
		} else if ([[node type] isEqualToString:@"u"]) {
			[stringa appendFormat:@"<span style=\"text-decoration:underline;\">%@</span>", [node parseIntoHTML]];
		} else if ([[node type] isEqualToString:@"s"]) {
			[stringa appendFormat:@"<span style=\"text-decoration:line-through;\">%@</span>", [node parseIntoHTML]];
		} else if ([[node type] isEqualToString:@"text"]) {
			[stringa appendString: [node value]];
			//text nodes have no children
		}
	}
	return stringa;
}

- (NSMutableAttributedString *) parseIntoAttributedString: (NSDictionary *)dict
{
	NSEnumerator *enm = [[self children] objectEnumerator];
	BBNode *node;
	NSMutableAttributedString *stringa = [[NSMutableAttributedString alloc] init];
	NSMutableDictionary *temp;
	id val, newval;
	while((node = [enm nextObject])) {
		if([[node type] isEqualToString:@"a"]) {
			// copy dict and add entries
			temp = [dict mutableCopy];
			[temp addEntriesFromDictionary: [NSMutableDictionary dictionaryWithObject: colorFromHexRGB([node value])
																			   forKey:NSBackgroundColorAttributeName]];
			[stringa appendAttributedString: [node parseIntoAttributedString: temp]];
		} else if ([[node type] isEqualToString:@"b"]) {
			temp = [dict mutableCopy];
			if((val = [temp valueForKey:NSFontAttributeName])) {
				val = [[NSFontManager sharedFontManager] convertFont: val toHaveTrait:NSBoldFontMask];
			} else {
				val = [NSFont boldSystemFontOfSize:0];
			}
			[temp addEntriesFromDictionary: [NSDictionary dictionaryWithObject: val
																		forKey:NSFontAttributeName]];
			[stringa appendAttributedString: [node parseIntoAttributedString: temp]];
		} else if ([[node type] isEqualToString:@"c"]) {
			temp = [dict mutableCopy];
			[temp addEntriesFromDictionary: [NSDictionary dictionaryWithObject: colorFromHexRGB([node value])
																		forKey:NSForegroundColorAttributeName]];
			[stringa appendAttributedString: [node parseIntoAttributedString: temp]];
		} else if ([[node type] isEqualToString:@"i"]) {
			temp = [dict mutableCopy];
			val = ([temp valueForKey:NSFontAttributeName] ? [temp valueForKey:NSFontAttributeName] : [NSFont systemFontOfSize:0]);
			newval = [[NSFontManager sharedFontManager] convertFont: val toHaveTrait:NSItalicFontMask];
			if(newval == val) {
			//if we don't have an italic variant, we italicise it.
				[temp addEntriesFromDictionary: [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat:0.16]
																			forKey:NSObliquenessAttributeName]];
			} else {
				[temp addEntriesFromDictionary: [NSDictionary dictionaryWithObject: newval
																			forKey:NSFontAttributeName]];
			}
			[stringa appendAttributedString: [node parseIntoAttributedString: temp]];
		} else if ([[node type] isEqualToString:@"u"]) {
			temp = [dict mutableCopy];
			[temp addEntriesFromDictionary: [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedInt:NSUnderlineStyleSingle]
																		forKey:NSUnderlineStyleAttributeName]];
			[stringa appendAttributedString: [node parseIntoAttributedString: temp]];
		} else if ([[node type] isEqualToString:@"s"]) {
			temp = [dict mutableCopy];
			[temp addEntriesFromDictionary: [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedInt:NSUnderlineStyleSingle]
																		forKey:NSStrikethroughStyleAttributeName]];
			[stringa appendAttributedString: [node parseIntoAttributedString: temp]];
		} else if ([[node type] isEqualToString:@"text"]) {
			NSAttributedString* str=[[NSAttributedString alloc] initWithString:[node value] attributes:dict];
			[stringa appendAttributedString: str];
			[str release];
			//text nodes have no children
		}
	}
	return [stringa autorelease];
}

- (NSString *) getPlainTextString
{
	NSEnumerator *enm = [[self children] objectEnumerator];
	BBNode *node;
	NSMutableString *stringa = [[NSMutableString alloc] init];
	while((node = [enm nextObject])) {
		if ([[node type] isEqualToString:@"text"]) {
			[stringa appendString: [node value]];
		} else {
			[stringa appendString: [node getPlainTextString]];
		}
	}
	return [stringa autorelease];
}

-(void) dealloc
{
	[type release];
	[value release];
	[children release];
	[super dealloc];
}

@end
