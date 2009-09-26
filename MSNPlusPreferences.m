//
//  MSNPlusPreferences.m
//  MSNPlus
//
//  Created by Tiziano Carotti on 26/09/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MSNPlusPreferences.h"
#import <Adium/AIPreferenceControllerProtocol.h>
#import <AIUtilities/AIStringUtilities.h>

@implementation MSNPlusPreferences

- (NSString *)label
{
	return @"MSNPlus";
}

- (NSString *)nibName
{
    return @"MSNPlusPreferences";
}

- (NSImage *)image
{
	NSString* imageName = [[NSBundle bundleForClass:[self class]] pathForResource:@"custom-emoticon" ofType:@"png"];
	NSImage* imageObj = [[NSImage alloc] initWithContentsOfFile:imageName];
	[imageObj autorelease];
	return imageObj;
}

- (AIPreferenceCategory)category
{
    return AIPref_Advanced;
}

- (void)viewDidLoad
{
	[filter_name_checkbox setState:[[[adium preferenceController] preferenceForKey:KEY_MSNPLUS_COLORED_NICKNAMES
																					 group:PREF_GROUP_MSNPLUS] boolValue]];
}

- (void)localizePane
{
	[filter_name_checkbox setLocalizedString:AILocalizedString(@"Enable MSN Plus colored nicknames filtering",nil)];
}

- (IBAction)changePreference:(id)sender {
	if (sender == filter_name_checkbox) {
		[[adium preferenceController] setPreference:[NSNumber numberWithBool:[sender state]] 
											 forKey:KEY_MSNPLUS_COLORED_NICKNAMES
											  group:PREF_GROUP_MSNPLUS];
	}
}

@end
