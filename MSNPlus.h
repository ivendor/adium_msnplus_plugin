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
#import <Adium/AIPreferencePane.h>
#import "AICustomEmoticonController.h"
#import "MSNPlusPreferences.h"

@interface AIMSNPlus : AIPlugin <AIContentFilter> {
	AICustomEmoticonController	*customEmoticonController;
	NSMutableSet				*toolbarItems;
	NSMenuItem					*quickCustomMenuItem;
	NSMenuItem					*quickContextualCustomMenuItem;
	NSMenuItem					*addAsMenuItem;
	
	AIPreferencePane	*MSNPlusPluginPreferencePane;
}

@end
