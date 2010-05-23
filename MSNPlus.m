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
#import <Adium/ESDebugAILog.h>
#import <AIUtilities/AIStringUtilities.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/MVMenuButton.h>
#import "BBStringCategory.h"
#import "AISmileyController.h"
#import "AIAddSmileyController.h"

#define	TOOLBAR_CUSTOM_EMOTICON_IDENTIFIER		@"CustomEmoticon"
#define	TITLE_INSERT_CUSTOM_EMOTICON			AILocalizedString(@"Insert Custom Emoticon",nil)
#define	TOOLTIP_INSERT_CUSTOM_EMOTICON			AILocalizedString(@"Insert a custom emoticon into the text",nil)
#define	TITLE_CUSTOM_EMOTICON					AILocalizedString(@"Custom Emoticons",nil)
#define TITLE_ADDAS_CUSTOM_EMOTICON				AILocalizedString(@"Add As Custom Emoticon",nil)
#define TITLE_CUSTOM_EMOTICON_PANEL				AILocalizedString(@"Open custom emoticons panel",nil)


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
	
	toolbarItems = [[NSMutableSet alloc] init];
	
	MVMenuButton *toolbarButton = [[[MVMenuButton alloc] initWithFrame:NSMakeRect(0,0,32,32)] autorelease];
	[toolbarButton setImage:[NSImage imageNamed:@"custom-emoticon" forClass:[self class] loadLazily:YES]];
	
	NSToolbarItem	*chatItem = [[AIToolbarUtilities toolbarItemWithIdentifier:TOOLBAR_CUSTOM_EMOTICON_IDENTIFIER
																	  label:TITLE_CUSTOM_EMOTICON
															   paletteLabel:TITLE_INSERT_CUSTOM_EMOTICON
																	toolTip:TOOLTIP_INSERT_CUSTOM_EMOTICON
																	 target:self
															settingSelector:@selector(setView:)
																itemContent:toolbarButton
																	 action:@selector(openCustomEmoticonPanel:)
																	   menu:nil] retain];
	
	[chatItem setMinSize:NSMakeSize(32,32)];
	[chatItem setMaxSize:NSMakeSize(32,32)];
	[toolbarButton setToolbarItem:chatItem];	
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
						   							 action:@selector(dummyTarget:) 
						   					  keyEquivalent:@""];
	
	quickContextualCustomMenuItem = [[NSMenuItem alloc] initWithTitle:TITLE_INSERT_CUSTOM_EMOTICON
															   target:self
															   action:@selector(dummyTarget:)
														keyEquivalent:@""];	
	
	/* Create a submenu for these so menu:updateItem:atIndex:shouldCancel: will be called 
	 * to populate them later. Don't need to check respondsToSelector:@selector(setDelegate:).
	 */
	NSMenu	*tempMenu;
	tempMenu = [[NSMenu alloc] init];
	[tempMenu setDelegate:self];
	[quickCustomMenuItem setSubmenu:tempMenu];
	[tempMenu release];
	
	tempMenu = [[NSMenu alloc] init];
	[tempMenu setDelegate:self];
	[quickContextualCustomMenuItem setSubmenu:tempMenu];
	[tempMenu release];	
	
	[[adium menuController] addContextualMenuItem:quickContextualCustomMenuItem toLocation:Context_TextView_Edit];
	[[adium menuController] addMenuItem:quickCustomMenuItem toLocation:LOC_Edit_Additions];
	
	addAsMenuItem = [[NSMenuItem alloc]		 initWithTitle:[TITLE_ADDAS_CUSTOM_EMOTICON stringByAppendingEllipsis]
													target:self
													action:@selector(addCustomSmiley:)
											 keyEquivalent:@""];
	[[adium menuController] addContextualMenuItem:addAsMenuItem toLocation:Context_Contact_ChatAction];
	
	MSNPlusPluginPreferencePane = [[MSNPlusPreferences preferencePaneForPlugin:self] retain];
	NSDictionary *defaults = [NSDictionary dictionaryNamed:@"MSNPlusPluginDefaults"
												  forClass:[self class]];
	
	if (defaults) {
		[[adium preferenceController] registerDefaults:defaults
											  forGroup:PREF_GROUP_MSNPLUS];
	} else {
		AILog(@"MSNPlus: Failed to load defaults.");
	}
}

/*!
 * @brief Uninstall plugin
 */
- (void)uninstallPlugin {
	[CONTACTOBSERVER_MANAGER unregisterListObjectObserver:self];
	[[adium contentController] unregisterContentFilter:self];
	[NOTIFICATION_CENTER removeObserver:self];
	
	[customEmoticonController release];
	[toolbarItems release];
	
	[MSNPlusPluginPreferencePane release];
	
	[AISmileyController unloadController];
}

- (NSString *)pluginAuthor {
	return @"iVendor";
}

- (NSString *)pluginVersion {
	return @"1.01";
}

- (NSString *)pluginDescription {
	return AILocalizedString(@"Support for MSN Custom Emoticon and MSN Plus Nickname tags.",nil);
}

- (NSString *)pluginURL
{
	return @"http://msnplusadium.sourceforge.net/";
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
		
		[toolbarItems addObject:item];
	}
}

/*!
 * @brief Stop tracking when an item is removed from a toolbar
 */
- (void)toolbarDidRemoveItem:(NSNotification *)notification {
	NSToolbarItem	*item = [[notification userInfo] objectForKey:@"item"];
	if ([[item itemIdentifier] isEqualToString:TOOLBAR_CUSTOM_EMOTICON_IDENTIFIER]) {
		[item setView:nil];
		[toolbarItems removeObject:item];
	}
}

/*!
 * @brief Just a target so we get the validateMenuItem: call for the emoticon menu
 */
- (IBAction)dummyTarget:(id)sender
{
	//Empty
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
#ifndef ADIUM_14	
	if(![[[adium preferenceController] preferenceForKey:KEY_MSN_DISPLAY_CUSTOM_EMOTICONS
												  group:PREF_GROUP_MSN_SERVICE] boolValue])
		return NO;
#endif
	
	if ([[menuItem title] isEqualToString:TITLE_INSERT_CUSTOM_EMOTICON] || [[menuItem title] isEqualToString:TITLE_CUSTOM_EMOTICON_PANEL]) {
		return YES;
	} else if([[menuItem title] isEqualToString:[TITLE_ADDAS_CUSTOM_EMOTICON stringByAppendingEllipsis]]) {
		return [[menuItem menu] itemWithTitle:NSLocalizedStringFromTableInBundle(@"Open Image", nil, WEBKIT_BUNDLE , nil)] != nil;
	} else {
		//Disable the emoticon menu items if we're not in a text field
		NSResponder	*responder = [[[NSApplication sharedApplication] keyWindow] firstResponder];
		if (responder && [responder isKindOfClass:[NSText class]]) {
			return [(NSText *)responder isEditable];
		} else {
			return NO;
		}
		
	}
	
	return NO;
}

/*!
 * @brief We don't want to get -menuNeedsUpdate: called on every keystroke. This method suppresses that.
 */
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id *)target action:(SEL *)action {
	*target = nil;  //use menu's target
	*action = NULL; //use menu's action
	return NO;
}

/*!
 * @brief Update our menus if necessary
 *
 * Called each time before any of our menus are displayed.
 * This rebuilds menus incrementally, in place, and only updating items that need it.
 *
 */
- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(int)index shouldCancel:(BOOL)shouldCancel
{
	NSArray			*emoticons = [AISmileyController getAllSmileys];
	
	/* We need special voodoo here to identify if the menu belongs to a toolbar,
	 * add the necessary pad item, and then adjust the index accordingly.
	 * this shouldn't be necessary, but NSToolbar is evil.
	 */
	
	int realIndex=index;
	
	if ([[[menu itemAtIndex:0] title] isEqualToString:TITLE_CUSTOM_EMOTICON]) {
		if (index == 0) {
			return YES;
		} else {
			--index;
		}
	}
	
	if(index==1) // Separator
	{
		[menu removeItemAtIndex:realIndex];
        [menu insertItem:[NSMenuItem separatorItem] atIndex:realIndex];
	}
	else if(index==0) { // Open Panel
		[item setTitle:TITLE_CUSTOM_EMOTICON_PANEL];
		[item setTarget:self];
		[item setAction:@selector(openCustomEmoticonPanel:)];
		[item setKeyEquivalent:@""];
		[item setImage:nil];
		[item setRepresentedObject:nil];
		[item setSubmenu:nil];		
	} else {
		PurpleCustomSmiley	*emoticon = [emoticons objectAtIndex:index-2];
		if (![[item representedObject] isEqualTo:emoticon]) {
			[item setTitle:[emoticon shortcut]];
			[item setTarget:self];
			[item setAction:@selector(insertEmoticon:)];
			[item setKeyEquivalent:@""];
			[item setImage:[[emoticon image] imageByScalingForMenuItem]];
			[item setRepresentedObject:emoticon];
			[item setSubmenu:nil];
		}
	}
	
	return YES;
}

/*!
 * @brief Set the number of items that should be in the menu.
 *
 * Toolbars need one empty item to display properly.  We increase the number by 1, if the menu
 * is in a toolbar
 *
 */
- (int)numberOfItemsInMenu:(NSMenu *)menu
{	
	int				 itemCounts = -1;
	
	itemCounts = [[AISmileyController getAllSmileys] count] + 2;
	
	if ([menu numberOfItems] > 0) {
		if ([[[menu itemAtIndex:0] title] isEqualToString:TITLE_CUSTOM_EMOTICON]) {
			++itemCounts;
		}
	}
	
	return itemCounts;
}

/*!
 * @brief Insert an emoticon into the first responder if possible
 *
 * First responder must be an editable NSTextView.
 *
 * @param sender An NSMenuItem whose representedObject is an AIEmoticon
 */
- (void)insertEmoticon:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		NSString *emoString = [[sender representedObject] shortcut];
		
		NSResponder *responder = [[[NSApplication sharedApplication] keyWindow] firstResponder];
		if (emoString && [responder isKindOfClass:[NSTextView class]] && [(NSTextView *)responder isEditable]) {
			NSRange tmpRange = [(NSTextView *)responder selectedRange];
			if (0 != tmpRange.length) {
				[(NSTextView *)responder setSelectedRange:NSMakeRange((tmpRange.location + tmpRange.length),0)];
			}
			[responder insertText:emoString];
		}
    }
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
	
	if(![[[adium preferenceController] preferenceForKey:KEY_MSNPLUS_COLORED_NICKNAMES
												  group:PREF_GROUP_MSNPLUS] boolValue])
		return;
	
	if(![listObject isKindOfClass:[AIListContact class]])
		return;
	
	AIListContact* contact=(AIListContact*)listObject;
	
	if(![[[[contact account] service] serviceID] isEqualToString:@"MSN"])
		return;
	
	NSString* contactName=[contact serversideDisplayName];
	
	NSString* translated=[contactName transBBCode:FALSE];
	
	if(![translated isEqualToString:contactName])
		[contact setServersideAlias:translated silently:TRUE ];
	
}

- (float)filterPriority {
	return HIGHEST_FILTER_PRIORITY;
}

@end
