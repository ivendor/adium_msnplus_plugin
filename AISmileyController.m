#import "AISmileyController.h"
#import "AIAddSmileyController.h"
#import <AdiumLibPurple/SLPurpleCocoaAdapter.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIVerticallyCenteredTextCell.h>
#import <AIUtilities/AIStringUtilities.h>
#import <AIUtilities/AIStringAdditions.h>
#import <libpurple/smiley.h>


#define	CUSTOM_SMILEY_NIB	@"CustomSmiley"	

@interface AISmileyController (PRIVATE)
- (id)initWithWindowNibName:(NSString *)windowNibName;
- (void)dealloc;
- (void)windowDidLoad;

- (int)numberOfRowsInTableView:(NSTableView *)mtableView;
- (id)tableView:(NSTableView *)mtableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
- (void)tableView:(NSTableView *)mtableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row;

+ (NSString *)_emoticonCachePathForCustomEmoticon:(NSString*) realpath checksum:(NSString*) checksum;
@end

@implementation AISmileyController

static AISmileyController *sharedSmileyControllerInstance = nil;

static BOOL firstTime=YES;

static NSMutableArray* smileyArray = nil;

+ (void) sendChangedNotification {
	[smileyArray release];
	smileyArray = nil;
	[NOTIFICATION_CENTER postNotificationName:AICustomSmileyChangeNotification object:nil];
}

+ (void) unloadController {
	[smileyArray release];
	smileyArray = nil;
}

+ (NSString *)_emoticonCachePathForCustomEmoticon:(NSString*) realpath checksum:(NSString*) checksum
{
    NSString    *filename = [NSString stringWithFormat:@"TEMP-MSNPlus_%@.%@",
							 checksum, [realpath pathExtension]];
    NSString	*cache_path = [[adium cachesPath] stringByAppendingPathComponent:[filename safeFilenameString]];	
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	if(![mgr fileExistsAtPath:cache_path])
	{
#if __MAC_OS_X_VERSION_MIN_REQUIRED < 1050
		[mgr copyPath:realpath toPath:cache_path handler:nil];
#else
		[mgr copyItemAtPath:realpath toPath:cache_path error:NULL];
#endif		
	}
	return cache_path;
}

int compareSmiley(id first, id second, void* context)
{
	NSString* first_shortcut=[first shortcut];
	NSString* second_shortcut=[second shortcut];
	return [first_shortcut caseInsensitiveCompare:second_shortcut];
}

+ (NSArray*) getAllSmileys {
	
	if(smileyArray)
		return smileyArray;
	
	GList *l;
	GList *smleys = purple_smileys_get_all();
	if(!smleys) {
		return [NSArray array];
	}
	guint lenn = g_list_length(smleys);
	smileyArray=[[NSMutableArray alloc] initWithCapacity:lenn];
	for (l = smleys; l; l = l->next) {
		PurpleSmiley *smile = (PurpleSmiley *)l->data;
		const char* shortcut=purple_smiley_get_shortcut(smile);
		char* data=purple_smiley_get_full_path(smile);
		const char* checksum=purple_smiley_get_checksum(smile);
		if(data && shortcut && checksum) {
			NSString* my_shortcut=[NSString stringWithCString:shortcut encoding:NSUTF8StringEncoding];
			NSString* file=[NSString stringWithCString:data  encoding:NSUTF8StringEncoding];
			NSString* my_checksum=[NSString stringWithCString:checksum  encoding:NSUTF8StringEncoding];
			PurpleCustomSmiley* pc=[[PurpleCustomSmiley alloc] initWithShortcut:my_shortcut andPath:[self _emoticonCachePathForCustomEmoticon:file checksum:my_checksum]];
			[smileyArray addObject: pc];
			[pc release];
		}
		g_free(data);
	}
	
	g_list_free(smleys);
	
	[smileyArray sortUsingFunction: compareSmiley context: nil ];
	
	return smileyArray; 
}

+ (id)smileyPanelWindowController {
	if(firstTime) { // Ensure libpurple was initalized
		CBPurpleAccount* acc=[[CBPurpleAccount alloc] init];
		[acc purpleAdapter];
		[acc release];
		firstTime=NO;
	}
	
    if (!sharedSmileyControllerInstance) {
        sharedSmileyControllerInstance = [[self alloc] initWithWindowNibName:CUSTOM_SMILEY_NIB];
    }
	
    return sharedSmileyControllerInstance;
}

+ (void)closeSharedInstance {
    if (sharedSmileyControllerInstance) {
        [sharedSmileyControllerInstance close];
    }
}

- (void)windowWillClose:(NSNotification *)notification {		
	sharedSmileyControllerInstance = nil;
	
    [self autorelease];
}

- (int)numberOfRowsInTableView:(NSTableView *)mtableView {
	if(!userArray)
		return 0;
	return [userArray count];
}

- (void)tableView:(NSTableView *)mtableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	if(!userArray || row<0 || row>=[userArray count])
		return;
	if([[tableColumn identifier] isEqualToString:@"IMG"])
			return;
	NSString* shortcut_new=object;
	if([shortcut_new length]==0)
		return;
	PurpleCustomSmiley* smiley=[userArray objectAtIndex:row];
	if([shortcut_new isEqualToString:[smiley shortcut]])
		return;
	
	PurpleSmiley* ex_smile;
	if((ex_smile=purple_smileys_find_by_shortcut([shortcut_new cStringUsingEncoding:NSUTF8StringEncoding]))!=NULL) {
		NSAlert* alert=[NSAlert alertWithMessageText:AILocalizedString(@"Emoticon with this shortcut already exist!",nil) defaultButton:AILocalizedString(@"OK",nil) alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		return;
	}
	
    PurpleSmiley* smile=purple_smileys_find_by_shortcut([[smiley shortcut] cStringUsingEncoding:NSUTF8StringEncoding]);
	if(purple_smiley_set_shortcut(smile,[shortcut_new cStringUsingEncoding:NSUTF8StringEncoding])) {
		[smiley setShortcut:shortcut_new];
		[AISmileyController sendChangedNotification];
	}
}

- (id)tableView:(NSTableView *)mtableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row; {
	NSString* ident=[tableColumn identifier];
	PurpleCustomSmiley* smiley=[userArray objectAtIndex:row];
	if([ident isEqualToString:@"IMG"])
		return [smiley image];
	else
		return [smiley shortcut];
}

- (IBAction)click:(id)sender {
    [self close];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo {
	if(returnCode==NSOKButton) {
		[panel orderOut:self];
		NSString* shortcut=[AIAddSmileyController runAddSmiley: [[panel filenames] objectAtIndex:0]];
		if(shortcut) {
			PurpleSmiley* smile=purple_smileys_find_by_shortcut([shortcut cStringUsingEncoding:NSUTF8StringEncoding]);
			if(smile) {
				size_t size;
				gconstpointer data=purple_smiley_get_data(smile, &size);
				if(data && size>0) {
					NSData* my_data=[NSData dataWithBytes:data length:size];
					NSImage* image=[[NSImage alloc] initWithData:my_data];
					[image setDataRetained:TRUE];
					PurpleCustomSmiley* pc=[[PurpleCustomSmiley alloc] initWithShortcut:shortcut andImage:image];
					[userArray addObject: pc];
					[image release];
					[tableView reloadData];
				}
			}	
		}
	}
}

- (IBAction)addSmiley:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetForDirectory:nil
								 file:nil
								types:[NSImage imageFileTypes]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:nil];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSIndexSet *selection = contextInfo;
	if(returnCode!=NSAlertDefaultReturn) {
		unsigned int idx;
		
		for (idx = [selection lastIndex]; idx != NSNotFound; idx = [selection indexLessThanIndex:idx]) {
			PurpleCustomSmiley* smiley=[userArray objectAtIndex:idx];
			purple_smiley_delete(purple_smileys_find_by_shortcut([[smiley shortcut]  cStringUsingEncoding:NSUTF8StringEncoding]));
			[userArray removeObject:smiley];
		}
		[tableView reloadData];
		[AISmileyController sendChangedNotification];
	}
	[selection release];
}

- (IBAction)removeSmiley:(id)sender {
	
    NSIndexSet *selection = [tableView selectedRowIndexes];
	
	if([selection count]) {
		NSAlert* alert=[NSAlert alertWithMessageText:[NSString stringWithFormat: AILocalizedString(@"Remove the %d emoticons selected?",nil), [selection count]] defaultButton:AILocalizedString(@"No",nil) alternateButton:AILocalizedString(@"Yes",nil) otherButton:nil informativeTextWithFormat:@""];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:[selection retain]];
	}
	
}

-(void)displayPane {
	[[self window] orderFront:nil];
}

- (void)dealloc {	
	[userArray release]; userArray = nil;
	
	[super dealloc];
}

- (void)windowDidLoad {
	
	//Center
	[[self window] center];
	
	[tableView setAllowsMultipleSelection:TRUE];
	[tableView setAllowsColumnSelection:FALSE];
	[tableView setAllowsColumnReordering:FALSE];
	
	[tableView setIntercellSpacing:NSMakeSize(1.0f, 3.0f)];
	
	[tableView setRowHeight:30.0f];
	
	NSTableColumn	*tableColumn2 = [[NSTableColumn alloc] initWithIdentifier:@"IMG"];
	NSImageCell *imageCell = [[NSImageCell alloc] initImageCell:nil];
	if ([imageCell respondsToSelector:@selector(_setAnimates:)]) [imageCell _setAnimates:NO];
	
#if __MAC_OS_X_VERSION_MIN_REQUIRED < 1050
	[imageCell setImageScaling:NSScaleProportionally];
#else
	[imageCell setImageScaling:NSImageScaleProportionallyDown];	
#endif
	[tableColumn2 setDataCell: imageCell];
	[tableColumn2 setEditable:NO];
	[[tableColumn2 headerCell] setStringValue:AILocalizedString(@"Image",nil)];
	[tableView addTableColumn:tableColumn2];
	[tableColumn2 release];
	[imageCell release];
	
	NSTableColumn	*tableColumn = [[NSTableColumn alloc] initWithIdentifier:@"SHORTCUT"];
	AIVerticallyCenteredTextCell *textCell = [[AIVerticallyCenteredTextCell alloc] initTextCell:@""];
	[textCell setEditable:YES];
	[tableColumn setMaxWidth:500.0f];
	[tableColumn setWidth:200.0f];
	[tableColumn setDataCell: textCell];
	[tableColumn setEditable:YES];
	[[tableColumn headerCell] setStringValue:AILocalizedString(@"Shortcut",nil)];
	[tableView addTableColumn:tableColumn];
	[tableColumn release];
	[textCell release];
	
	GList *l;
	GList *smleys = purple_smileys_get_all();
	guint lenn = g_list_length(smleys);
	userArray=[[NSMutableArray alloc] initWithCapacity:lenn];
	for (l = smleys; l; l = l->next) {
		PurpleSmiley *smile = (PurpleSmiley *)l->data;
		const char* shortcut=purple_smiley_get_shortcut(smile);
		size_t size;
		gconstpointer data=purple_smiley_get_data(smile, &size);
		if(data && shortcut) {
			NSString* my_shortcut=[NSString stringWithCString:shortcut encoding:NSUTF8StringEncoding];
			NSData* my_data=[NSData dataWithBytes:data
										 length:size];
			NSImage* image=[[NSImage alloc] initWithData:my_data];
			[image setDataRetained:TRUE];
			PurpleCustomSmiley* pc=[[PurpleCustomSmiley alloc] initWithShortcut:my_shortcut andImage:image];
			[userArray addObject: pc];
			[pc release];
			[image release];
		}
	}
	
	g_list_free(smleys);
	
	[userArray sortUsingFunction: compareSmiley context: nil ];

	
	[tableView reloadData];

}

@end

@implementation PurpleCustomSmiley
	   
- (NSString*) shortcut {
	return shortcut;
}
	   
- (void) setShortcut:(NSString*)new_shortcut {
	[shortcut release];
	shortcut=[new_shortcut retain];
}
	
- (NSImage*) image {
	if(!image && path)
	{
		return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	}
	
	return image;
}

- (NSString*) path {
	return path;
}
	   
- (id) initWithShortcut:(NSString*)shortc andImage:(NSImage*) img {
	if((self = [super init])) {
		image=[img retain];
		shortcut=[shortc retain];
		path=nil;
	}
	return self;
}

- (id) initWithShortcut:(NSString*)shortc andPath:(NSString*) img_path {
	if((self = [super init])) {
		path=[img_path retain];
		shortcut=[shortc retain];
		image=nil;
	}
	return self;
}

- (void)dealloc {	
	[image release];

	[path release];
	
	[shortcut release];
	
	[super dealloc];
}

@end

