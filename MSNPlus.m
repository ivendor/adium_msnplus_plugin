//
//  MSNPlus.m
//  MSNPlus
//
//  Created by Tiziano Carotti on 05/09/09.
//  Copyright 2009 Tiziano Carotti. All rights reserved.
//



#import "MSNPlus.h"
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIEmoticonControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIPreferenceControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIToolbarControllerProtocol.h>
#import <AdiumLibpurple/ESMSNService.h>
#import <AIUtilities/AIStringUtilities.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <AIUtilities/AIImageAdditions.h>
#import "BBStringCategory.h"
#import "AISmileyController.h"
#import "AIAddSmileyController.h"

#define	TOOLBAR_CUSTOM_EMOTICON_IDENTIFIER		@"CustomEmoticon"
#define	TITLE_INSERT_CUSTOM_EMOTICON			AILocalizedString(@"Custom emoticons panel",nil)
#define	TOOLTIP_INSERT_CUSTOM_EMOTICON			AILocalizedString(@"Open custom emoticons panel",nil)
#define	TITLE_CUSTOM_EMOTICON					AILocalizedString(@"Custom Emoticons",nil)
#define TITLE_ADDAS_CUSTOM_EMOTICON				AILocalizedString(@"Add As Custom Emoticon",nil)

@interface AIMSNPlus (PRIVATE)
- (NSSet *)_applyBBCode:(AIListObject*) listObject;
@end

@implementation AIMSNPlus

/*!
 * @brief Install plugin
 */
- (void)installPlugin {
	customEmoticonController = [[AICustomEmoticonController alloc] init];
	
    [NOTIFICATION_CENTER addObserver:self
								   selector:@selector(applyMSNColour:)
									   name:Contact_ApplyDisplayName
									 object:nil];
	
	[[adium contentController] registerContentFilter:self ofType:AIFilterMessageDisplay direction:AIFilterOutgoing];
	
	//Add Toolbar item
	
	toolbarItem = [[NSMutableSet alloc] init];
	
	NSToolbarItem	*chatItem = [AIToolbarUtilities toolbarItemWithIdentifier:TOOLBAR_CUSTOM_EMOTICON_IDENTIFIER
																	  label:TITLE_CUSTOM_EMOTICON
															   paletteLabel:TITLE_INSERT_CUSTOM_EMOTICON
																	toolTip:TOOLTIP_INSERT_CUSTOM_EMOTICON
																	 target:self
															settingSelector:@selector(setImage:)
																itemContent:[NSImage imageNamed:@"custom-emoticon" forClass:[self class] loadLazily:YES]
																	 action:@selector(openCustomEmoticonPanel:)
																	   menu:nil];
	
	[[adium toolbarController] registerToolbarItem:chatItem forToolbarType:@"TextEntry"];
	
	//Add Menu Items
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toolbarWillAddItem:)
												 name:NSToolbarWillAddItemNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toolbarDidRemoveItem:)
												 name:NSToolbarDidRemoveItemNotification
											   object:nil];
	
	quickCustomMenuItem = [[NSMenuItem alloc] initWithTitle:TITLE_INSERT_CUSTOM_EMOTICON
													 target:self
						   							 action:@selector(openCustomEmoticonPanel:) 
						   					  keyEquivalent:@""];
	
	quickContextualCustomMenuItem = [[NSMenuItem alloc] initWithTitle:TITLE_INSERT_CUSTOM_EMOTICON
															   target:self
															   action:@selector(openCustomEmoticonPanel:)
														keyEquivalent:@""];	
	[[adium menuController] addContextualMenuItem:quickContextualCustomMenuItem toLocation:Context_TextView_Edit];
	[[adium menuController] addMenuItem:quickCustomMenuItem toLocation:LOC_Edit_Additions];
	
	addAsMenuItem = [[NSMenuItem alloc]		 initWithTitle:[TITLE_ADDAS_CUSTOM_EMOTICON stringByAppendingEllipsis]
													target:self
													action:@selector(addCustomSmiley:)
											 keyEquivalent:@""];
	[[adium menuController] addContextualMenuItem:addAsMenuItem toLocation:Context_Contact_ChatAction];
}

/*!
 * @brief Uninstall plugin
 */
- (void)uninstallPlugin {
	[CONTACTOBSERVER_MANAGER unregisterListObjectObserver:self];
	[[adium contentController] unregisterContentFilter:self];
	[NOTIFICATION_CENTER removeObserver:self];
	
	[customEmoticonController release];
	[toolbarItem release];
}

- (NSString *)pluginAuthor {
	return @"iVendor";
}

- (NSString *)pluginVersion {
	return @"0.6";
}

- (NSString *)pluginDescription {
	return AILocalizedString(@"Support for MSN Custom Emoticon and MSN Plus Nickname tags.",nil);
}

- (NSAttributedString *)filterAttributedString:(NSAttributedString *)inAttributedString context:(id)context {
	return [customEmoticonController filterAttributedString:inAttributedString context:context];
}

- (void)openCustomEmoticonPanel:(id)sender {
	AISmileyController* contr=[AISmileyController smileyPanelWindowController];
	if(contr)
		[contr displayPane];
}

/*!
 * @brief Add the emoticon menu as an item goes into a toolbar
 */
- (void)toolbarWillAddItem:(NSNotification *)notification {
	NSToolbarItem	*item = [[notification userInfo] objectForKey:@"item"];
	
	if ([[item itemIdentifier] isEqualToString:TOOLBAR_CUSTOM_EMOTICON_IDENTIFIER]) {
		NSMenu		*theEmoticonMenu = [[[NSMenu alloc] init] autorelease];
		
		[theEmoticonMenu setDelegate:self];
		
		//Add menu to view
		[[item view] setMenu:theEmoticonMenu];
		
		//Add menu to toolbar item (for text mode)
		NSMenuItem	*mItem = [[[NSMenuItem allocWithZone:[NSMenu menuZone]] init] autorelease];
		[mItem setSubmenu:theEmoticonMenu];
		[mItem setTitle:TITLE_CUSTOM_EMOTICON];
		[item setMenuFormRepresentation:mItem];
		
		[toolbarItem addObject:item];
	}
}

/*!
 * @brief Stop tracking when an item is removed from a toolbar
 */
- (void)toolbarDidRemoveItem:(NSNotification *)notification {
	NSToolbarItem	*item = [[notification userInfo] objectForKey:@"item"];
	if ([[item itemIdentifier] isEqualToString:TOOLBAR_CUSTOM_EMOTICON_IDENTIFIER]) {
		[item setView:nil];
		[toolbarItem removeObject:item];
	}
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
#ifndef ADIUM_14	
	if(![[[adium preferenceController] preferenceForKey:KEY_MSN_DISPLAY_CUSTOM_EMOTICONS
												  group:PREF_GROUP_MSN_SERVICE] boolValue])
		return NO;
#endif
	
	if ([[menuItem title] isEqualToString:TITLE_INSERT_CUSTOM_EMOTICON]) {
		return YES;
	} 
	else if([[menuItem title] isEqualToString:[TITLE_ADDAS_CUSTOM_EMOTICON stringByAppendingEllipsis]]) {
		return [[menuItem menu] itemWithTitle:NSLocalizedStringFromTableInBundle(@"Open Image", nil, WEBKIT_BUNDLE , nil)] != nil;
	}
	
	return NO;
}

- (void)addCustomSmiley:(id)sender {
	NSMenuItem* image_menu=[[sender menu] itemWithTitle:NSLocalizedStringFromTableInBundle(@"Open Image", nil, WEBKIT_BUNDLE, nil)];
	if(image_menu) {
		NSURL		*imageURL = [image_menu representedObject];
		NSString	*path = [imageURL path];
		[AIAddSmileyController runAddSmiley:path];
	}
}


- (void)applyMSNColour:(NSNotification *)notification {
	AIListObject	*listObject = [notification object];
		
	if([[[listObject service] serviceID] isEqualToString:@"MSN"]) {
		[self _applyBBCode:listObject];
	}	
	
}

- (NSSet *)_applyBBCode:(AIListObject*) listObject {
	NSSet	*modifiedAttributes;
	
	[[listObject displayArrayForKey:@"Display Name"] setObject:[[listObject displayName] transBBCode:FALSE] withOwner:self priorityLevel:High_Priority];
	
	[[listObject displayArrayForKey:@"Long Display Name"] setObject:[[listObject longDisplayName] transBBCode:FALSE] withOwner:self];
	
	modifiedAttributes = [NSSet setWithObjects:@"Display Name", @"Long Display Name", nil];
	
	[CONTACTOBSERVER_MANAGER listObjectAttributesChanged:listObject
												  modifiedKeys:modifiedAttributes];
	
	return modifiedAttributes;
}

/*!
 * @brief Update list object
 *
 * As contacts are created or a formattedUID is received, update their alias, display name, and long display name
 */
- (NSSet *)updateListObject:(AIListObject *)inObject keys:(NSSet *)inModifiedKeys silent:(BOOL)silent {
    if ((inModifiedKeys == nil) || ([inModifiedKeys containsObject:@"FormattedUID"])) {
		return [self _applyBBCode:inObject];
    }
	
	return nil;
}

- (float)filterPriority {
	return HIGHEST_FILTER_PRIORITY;
}

@end
