//
//  Created by Andrea Gianarro on 23/06/08.
//  Copyright 2008 Andrea Gianarro. All rights reserved.
//	Revised by Tiziano Carotti
//

#import <Cocoa/Cocoa.h>
#import "BBNode.h"
#import <regex.h>

#define CLEARBBCODE_COND(string, serviceID) ([serviceID isEqualToString:@"MSN"] ? [string transBBCode:FALSE] : string)
#define TRANSBBCODE_COND(string, serviceID) ([serviceID isEqualToString:@"MSN"] ? [string transBBCode:TRUE] : string)

#define ATTRIBUTED_BBCODE(string, serviceID) ([serviceID isEqualToString:@"MSN"] ? [[NSAttributedString alloc] initWithBBCode:string] : [[NSAttributedString alloc] initWithString:string])
#define ATTRIBUTED_BBCODE_DICT(string, serviceID,dict) ([serviceID isEqualToString:@"MSN"] ? [[NSAttributedString alloc] initWithBBCode:string attributes:dict] : [[NSAttributedString alloc] initWithString:string attributes:dict])

@interface NSAttributedString (BBStringCategory)

-(id)initWithBBCode: (NSString *) string;
-(id)initWithBBCode: (NSString *) string attributes: (NSDictionary *)dict;

@end

@interface NSString (BBStringCategory)
- (NSString *)transBBCode:(BOOL)HTMLTags;
@end
