#import <Cocoa/Cocoa.h>
#import <Adium/AIWindowController.h>

@interface AIAddSmileyController : NSWindowController {
    IBOutlet NSTextField *textField;
    IBOutlet id okButton;
    IBOutlet NSTextField *textLabel;
	NSString* smileyPath;
	NSString* smileyShortcut;
}

- (NSString*) smileyShortcut;
- (void)setSmileyPath:(NSString*) path;
- (IBAction)ok:(id)sender;
+ (NSString*)runAddSmiley:(NSString*) filePath;
@end
