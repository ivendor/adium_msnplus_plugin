#import <Cocoa/Cocoa.h>
#import <Adium/AIWindowController.h>

#define AICustomSmileyChangeNotification @"AICustomSmileyChange"

@interface AISmileyController : NSWindowController {
    IBOutlet NSTableView *tableView;
	
	NSMutableArray				*userArray;
}
+ (void) sendChangedNotification;
+ (NSArray*) getAllSmileys;
+ (id)smileyPanelWindowController;
+ (void)closeSharedInstance;

- (IBAction)click:(id)sender;
- (IBAction)addSmiley:(id)sender;
- (IBAction)removeSmiley:(id)sender;

- (void)displayPane;

@end

@interface PurpleCustomSmiley : NSObject {
    NSString *shortcut;
	NSString *path;
	NSImage *image;
}

- (id) initWithShortcut:(NSString*)shortc andImage:(NSImage*) img;

- (id) initWithShortcut:(NSString*)shortc andPath:(NSString*) img_path;

- (NSString*) path;

- (NSString*) shortcut;

- (void) setShortcut:(NSString*)new_shortcut;

- (NSImage*) image;

- (void) dealloc;

@end
