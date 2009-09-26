//
//  MSNPlusPreferences.h
//  MSNPlus
//
//  Created by Tiziano Carotti on 26/09/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Adium/AIAdvancedPreferencePane.h>
#import <Adium/AILocalizationAssistance.h>

#define PREF_GROUP_MSNPLUS	@"MSNPlus Plugin"
#define KEY_MSNPLUS_COLORED_NICKNAMES	@"Enable colored nicknames filtering"

@interface MSNPlusPreferences : AIAdvancedPreferencePane {
	IBOutlet			AILocalizationButton*		filter_name_checkbox;
}

- (IBAction)changePreference:(id)sender;
- (void)viewDidLoad;
- (void)localizePane;

@end
