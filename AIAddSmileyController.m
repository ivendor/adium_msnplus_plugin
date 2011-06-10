#import "AIAddSmileyController.h"
#import "AISmileyController.h"
#import <libpurple/smiley.h>
#import <AIUtilities/AIStringUtilities.h>

#define ADD_SMILEY_NIB_NAME @"AddCustomSmiley"

@implementation AIAddSmileyController

- (void)setSmileyPath:(NSString*) path {
	smileyPath=[path retain];
	smileyShortcut=nil;
}

- (PurpleSmiley*)findSmileyByChecksum: (const char*) checksum {

	// purple_smileys_find_by_checksum seems bugged
	
	PurpleSmiley* result=NULL;
	GList *l;
	GList *smleys = purple_smileys_get_all();
	for (l = smleys; l; l = l->next) {
		PurpleSmiley *smile = (PurpleSmiley *)l->data;
		const char* p_checksum=purple_smiley_get_checksum(smile);
		if(g_str_equal(checksum,p_checksum))
		{
			result=smile;
			break;
		}
	}
	
	g_list_free(smleys);
	
	return result;
}

- (IBAction)ok:(id)sender {
	NSString* shortcut=[textField stringValue];
	const char* shortcut_s=[shortcut cStringUsingEncoding:NSUTF8StringEncoding];
	PurpleSmiley* ex_smile;
	if((ex_smile=purple_smileys_find_by_shortcut(shortcut_s))!=NULL) {
		NSAlert* alert=[NSAlert alertWithMessageText:AILocalizedString(@"Emoticon with this shortcut already exist. Do you want to overwrite it?",nil) defaultButton:AILocalizedString(@"No",nil) alternateButton:AILocalizedString(@"Yes",nil) otherButton:nil informativeTextWithFormat:@""];
		[alert setAlertStyle:NSWarningAlertStyle];
		if([alert runModal]==NSAlertDefaultReturn)
		{
			[self close];
			return;
		}
		purple_smiley_delete(ex_smile);
	}
	NSFileHandle* sml=[NSFileHandle fileHandleForReadingAtPath:smileyPath];
	if(!sml) {
		NSAlert* alert=[NSAlert alertWithMessageText:AILocalizedString(@"Cannot open image file!",nil) defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert runModal];
		[self close];
		return;
	}
	
	NSData* data=[sml readDataToEndOfFile];
	[sml closeFile];
	
	char* checksum=purple_util_get_image_checksum([data bytes],[data length]);
	if((ex_smile=[self findSmileyByChecksum:checksum])!=NULL) {
		NSAlert* alert=[NSAlert alertWithMessageText:AILocalizedString(@"This emoticon is already been added with another shortcut. Do you want to overwrite it?",nil) defaultButton:AILocalizedString(@"No",nil) alternateButton:AILocalizedString(@"Yes",nil) otherButton:nil informativeTextWithFormat:@""];
		[alert setAlertStyle:NSWarningAlertStyle];
		if([alert runModal]==NSAlertDefaultReturn)
		{
			g_free(checksum);
			[self close];
			return;
		}
		purple_smiley_delete(ex_smile);
	}
	g_free(checksum);
	purple_smiley_new_from_file(shortcut_s,[smileyPath cStringUsingEncoding:NSUTF8StringEncoding]);
	smileyShortcut=[shortcut retain];
    [self close];
}

- (void)windowWillClose:(NSNotification *)notification {
	[NSApp abortModal];
}

- (NSString*) smileyShortcut {
	return smileyShortcut;
}

-(void) windowDidLoad {
	[textLabel setStringValue: AILocalizedString(@"Enter the shortcut for the emoticon:",nil)];
	[[self window] setDefaultButtonCell: [okButton cell]];
}

+ (NSString*)runAddSmiley:(NSString*) filePath  {
	[filePath retain];
	NSString* result=nil;
	AIAddSmileyController* contr=[[self alloc] initWithWindowNibName:ADD_SMILEY_NIB_NAME];
	if(contr)
	{
		[contr setSmileyPath: filePath];
		
		[NSApp runModalForWindow: [contr window]];
		
		result=[contr smileyShortcut];
		
		[contr release];
		
		if(result)
			[AISmileyController sendChangedNotification];
	}
	[filePath release];
	return [result autorelease];
}

- (void) dealloc {
	[smileyPath release];
	[super dealloc];
}

@end
