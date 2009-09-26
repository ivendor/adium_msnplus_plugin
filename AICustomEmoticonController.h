//
//  AICustomEmoticonController.h
//  MSNColorNicknames
//
//  Created by Tiziano Carotti on 05/09/09.
//  Copyright 2009 Tiziano Carotti. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface AICustomEmoticonController : NSObject {
	NSCharacterSet				*_customEmoticonHintCharacterSet;
	NSCharacterSet				*_customEmoticonStartCharacterSet;
	NSMutableDictionary         *_customEmoticonIndexDict;
}

- (NSAttributedString *)filterAttributedString:(NSAttributedString *)inAttributedString context:(id)context;

@end
