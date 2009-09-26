//
//  Created by Andrea Gianarro on 23/06/08.
//  Copyright 2008 Andrea Gianarro. All rights reserved.
//	Revised by Tiziano Carotti
//

#import <Cocoa/Cocoa.h>


@interface BBNode : NSObject {
	NSString *type;
	NSString *value;
	NSMutableArray *children;
	BBNode *parent;
}

- (id) init;
- (void) addChild: (BBNode *) node;
- (NSMutableArray *) children;
- (void) setType: (NSString *) myType andValue: (NSString *) myValue;
- (NSString *) type;
- (NSString *) value;
- (void) setParent: (BBNode *) myParent;
- (BBNode *) parent;
- (NSString *) parseIntoHTML;
- (NSMutableAttributedString *) parseIntoAttributedString: (NSDictionary *)dict;
- (NSString *) getPlainTextString;
- (void) dealloc;

@end
