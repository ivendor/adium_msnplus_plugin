//
//  MSNPlus.h
//  MSNPlus
//
//  Created by Tiziano Carotti on 05/09/09.
//  Copyright 2009 Tiziano Carotti. All rights reserved.
//

#import <Adium/AIPlugin.h>
#ifdef ADIUM_14
#import <Adium/AIContactObserverManager.h>
#endif
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import "AICustomEmoticonController.h"

@interface AIMSNPlus : AIPlugin <AIListObjectObserver, AIContentFilter> {
	AICustomEmoticonController	*customEmoticonController;
	NSMutableSet				*toolbarItem;
	NSMenuItem					*quickCustomMenuItem;
	NSMenuItem					*quickContextualCustomMenuItem;
	NSMenuItem					*addAsMenuItem;
}

@end
