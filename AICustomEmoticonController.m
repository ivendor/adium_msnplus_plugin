//
//  AICustomEmoticonController.m
//  MSNColorNicknames
//
//  Created by Tiziano Carotti on 05/09/09.
//  Copyright 2009 Tiziano Carotti. All rights reserved.
// 
//	This code has been taken from Adium - AIEmoticonController class and has been slightly modified

#import "AICustomEmoticonController.h"
#import "AISmileyController.h"
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIEmoticon.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/ESDebugAILog.h>
#import <AdiumLibpurple/CBPurpleAccount.h>
#import <AdiumLibpurple/ESMSNService.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <AIUtilities/AICharacterSetAdditions.h>
#import <Adium/AIContentEvent.h>

@interface AICustomEmoticonController (PRIVATE)
- (BOOL)_isCustomEmoticonApplicable:(id)context;
- (void)_buildCharacterSetsAndIndexCustomEmoticons;
- (NSMutableAttributedString *)_convertEmoticonsInMessage:(NSAttributedString *)inMessage context:(id)context;

- (AIEmoticon *) _bestReplacementFromEmoticons:(NSArray *)candidateEmoticons
							   withEquivalents:(NSArray *)candidateEmoticonTextEquivalents
									   context:(NSString *)serviceClassContext
									equivalent:(NSString **)replacementString
							  equivalentLength:(NSInteger *)textLength;

- (NSUInteger)replaceAnEmoticonStartingAtLocation:(NSUInteger *)currentLocation
                                       fromString:(NSString *)messageString
                              messageStringLength:(NSUInteger)messageStringLength
                         originalAttributedString:(NSAttributedString *)originalAttributedString
                                       intoString:(NSMutableAttributedString **)newMessage
                                 replacementCount:(NSUInteger *)replacementCount
                               callingRecursively:(BOOL)callingRecursively
                              serviceClassContext:(id)serviceClassContext
                        emoticonStartCharacterSet:(NSCharacterSet *)emoticonStartCharacterSet
                                    emoticonIndex:(NSDictionary *)emoticonIndex
                                        isMessage:(BOOL)isMessage;
@end

@implementation AICustomEmoticonController

- (id)init {
	self = [super init];
	if(self == nil)
		return nil;
	
	_customEmoticonHintCharacterSet = nil;
	_customEmoticonStartCharacterSet = nil;
	_customEmoticonIndexDict = nil;
	[NOTIFICATION_CENTER addObserver:self selector:@selector(resetCustomEmoticon) name:AICustomSmileyChangeNotification object:nil];	
	return self;
}

- (void) dealloc {
	[NOTIFICATION_CENTER removeObserver:self];
	
	[_customEmoticonHintCharacterSet release];
	[_customEmoticonStartCharacterSet release];
	[_customEmoticonIndexDict release];
	
	[super dealloc];
}

//For optimization, we build a list of characters that could possibly be an emoticon and will require additional scanning.
//We also build a dictionary categorizing the emoticons by their first character to quicken lookups.
- (void)_buildCharacterSetsAndIndexCustomEmoticons
{    
    NSEnumerator        *emoticonEnumerator;
    AIEmoticon          *emoticon;
	PurpleCustomSmiley  *pemoticon;
    
    //Start with a fresh character set, and a fresh index
	NSMutableCharacterSet	*tmpEmoticonHintCharacterSet = [[NSMutableCharacterSet alloc] init];
	NSMutableCharacterSet	*tmpEmoticonStartCharacterSet = [[NSMutableCharacterSet alloc] init];
    
	[_customEmoticonIndexDict release]; _customEmoticonIndexDict = [[NSMutableDictionary alloc] init];
    
    //Process all the text equivalents of each active emoticon
    NSArray* smileys=[AISmileyController getAllSmileys];
	
	emoticonEnumerator = [smileys objectEnumerator];
	while ((pemoticon = [emoticonEnumerator nextObject])) {
        emoticon = [AIEmoticon emoticonWithIconPath:[pemoticon path] equivalents:[NSArray arrayWithObject:[pemoticon shortcut]] name:[[pemoticon shortcut] stringByAppendingString:@"#custom"]  pack:nil];        
        [emoticon setEnabled:TRUE];
        for (NSString *text in emoticon.textEquivalents) {
            NSMutableArray  *subIndex;
            unichar         firstCharacter;
            NSString        *firstCharacterString;
            
            if ([text length] != 0) { //Invalid emoticon files may let empty text equivalents sneak in
                firstCharacter = [text characterAtIndex:0];
                firstCharacterString = [NSString stringWithFormat:@"%C",firstCharacter];
                
                // -- Emoticon Hint Character Set --
                //If any letter in this text equivalent already exists in the quick scan character set, we can skip it
                if ([text rangeOfCharacterFromSet:tmpEmoticonHintCharacterSet].location == NSNotFound) {
                    //Potential for optimization!: Favor punctuation characters ( :();- ) over letters (especially vowels).                
                    [tmpEmoticonHintCharacterSet addCharactersInString:firstCharacterString];
                }
                
                // -- Emoticon Start Character Set --
                //First letter of this emoticon goes in the start set
                if (![tmpEmoticonStartCharacterSet characterIsMember:firstCharacter]) {
                    [tmpEmoticonStartCharacterSet addCharactersInString:firstCharacterString];
                }
                
                // -- Index --
                //Get the index according to this emoticon's first character
                if (!(subIndex = [_customEmoticonIndexDict objectForKey:firstCharacterString])) {
                    subIndex = [[NSMutableArray alloc] init];
                    [_customEmoticonIndexDict setObject:subIndex forKey:firstCharacterString];
                    [subIndex release];
                }
                
                //Place the emoticon into that index (If it isn't already in there)
                if (![subIndex containsObject:emoticon]) {
                    //Keep emoticons in order from largest to smallest.  This prevents icons that contain other
                    //icons from being masked by the smaller icons they contain.
                    //This cannot work unless the emoticon equivelents are broken down.
                    /*
                     for (int i = 0;i < [subIndex count]; i++) {
                     if ([subIndex objectAtIndex:i] equivelentLength] < ourLength]) break;
                     }*/
                    
                    //Instead of adding the emoticon, add all of its equivalents... ?
                    
                    [subIndex addObject:emoticon];
                }
            }
            
        }
    }
    
	[_customEmoticonHintCharacterSet release]; _customEmoticonHintCharacterSet = [tmpEmoticonHintCharacterSet immutableCopy];
	[tmpEmoticonHintCharacterSet release];
    
    [_customEmoticonStartCharacterSet release]; _customEmoticonStartCharacterSet = [tmpEmoticonStartCharacterSet immutableCopy];
	[tmpEmoticonStartCharacterSet release];
    
	//After building all the subIndexes, sort them by length here
}


//Returns a characterset containing characters that hint at the presence of an emoticon
- (NSCharacterSet *)customEmoticonHintCharacterSet {
	if (!_customEmoticonHintCharacterSet) [self _buildCharacterSetsAndIndexCustomEmoticons];
	return _customEmoticonHintCharacterSet;
}

//Returns a characterset containing all the characters that may start an emoticon
- (NSCharacterSet *)customEmoticonStartCharacterSet {
	if (!_customEmoticonStartCharacterSet) [self _buildCharacterSetsAndIndexCustomEmoticons];
	return _customEmoticonStartCharacterSet;
}

- (NSDictionary *)customEmoticonIndex {
	if (!_customEmoticonIndexDict) [self _buildCharacterSetsAndIndexCustomEmoticons];
	return _customEmoticonIndexDict;
}

- (BOOL)_isCustomEmoticonApplicable:(id)context {
	BOOL result=FALSE;
    
	if ([context isKindOfClass:[AIContentMessage class]]) {
		AIContentMessage* contMessage=context;
		
		if([contMessage isOutgoing] && ![contMessage isAutoreply] && [[contMessage type] isEqualToString:CONTENT_MESSAGE_TYPE] && [[[[[contMessage chat] account] service] serviceID] isEqualToString:@"MSN"])
		{
			if([[[[contMessage chat] account] preferenceForKey:KEY_DISPLAY_CUSTOM_EMOTICONS
                                                          group:GROUP_ACCOUNT_STATUS] boolValue])
				result=TRUE;
		}
	}
	return result;
}

//Reset the active emoticons cache
- (void)resetCustomEmoticon {
	[_customEmoticonHintCharacterSet release]; _customEmoticonHintCharacterSet = nil;
	[_customEmoticonStartCharacterSet release]; _customEmoticonStartCharacterSet = nil;
	[_customEmoticonIndexDict release]; _customEmoticonIndexDict = nil;
}

//Filter a content object before display, inserting graphical emoticons
- (NSAttributedString *)filterAttributedString:(NSAttributedString *)inAttributedString context:(id)context
{
    NSMutableAttributedString   *replacementMessage = nil;
    
	if(![self _isCustomEmoticonApplicable:context])
		return inAttributedString;
    
    // We want to filter some status event messages (e.g. changes in status messages), but not fileTransfer messages.
    // Filenames, afterall, should not have emoticons in them.
    if (inAttributedString) {
            /* First, we do a quick scan of the message for any characters that might end up being emoticons
             * This avoids having to do the slower, more complicated scan for the majority of messages.
             *
             * We also look for emoticons if this messsage is for a chat and it has one or more custom emoticons
             */
            if (([[inAttributedString string] rangeOfCharacterFromSet:[self customEmoticonHintCharacterSet]].location != NSNotFound) ||
                ([context isKindOfClass:[AIContentObject class]] && ([[(AIContentObject *)context chat] customEmoticons]))){
                //If an emoticon character was found, we do a more thorough scan
                replacementMessage = [self _convertEmoticonsInMessage:inAttributedString context:context];
            }
        }
    return (replacementMessage ? replacementMessage : inAttributedString);
}


//Insert graphical emoticons into a string
- (NSAttributedString *)_convertEmoticonsInMessage:(NSAttributedString *)inMessage context:(id)context
{
    NSString                    *messageString = [inMessage string];
    NSMutableAttributedString   *newMessage = nil; //We avoid creating a new string unless necessary
	NSString					*serviceClassContext = nil;
    NSUInteger					currentLocation = 0, messageStringLength;
	NSCharacterSet				*emoticonStartCharacterSet = self.customEmoticonStartCharacterSet;
	NSDictionary				*emoticonIndex = self.customEmoticonIndex;
	//we can avoid loading images if the emoticon is headed for the wkmv, since it will just load from the original path anyway
	BOOL						isMessage = NO;  
    
	//Determine our service class context
	if ([context isKindOfClass:[AIContentObject class]]) {
		isMessage = YES;
		serviceClassContext = ((AIContentObject *)context).destination.service.serviceClass;
		//If there's no destination, try to use the source for context
		if (!serviceClassContext) {
			serviceClassContext = ((AIContentObject *)context).source.service.serviceClass;
		}
		
		//Expand our emoticon information to include any custom emoticons in this chat
		NSSet *customEmoticons = ((AIContentObject *)context).chat.customEmoticons;
		if (customEmoticons && [self _isCustomEmoticonApplicable:context] && !((AIContentObject *)context).isOutgoing) {
			/* XXX Note that we only display custom emoticons for incoming messages; we can not set our own custom emotcions
			 * at this time
			 */
			NSMutableCharacterSet	*newEmoticonStartCharacterSet = [emoticonStartCharacterSet mutableCopy];
			NSMutableDictionary		*newEmoticonIndex = [emoticonIndex mutableCopy];
            
			AIEmoticon	 *emoticon;
			
			for (emoticon in customEmoticons) {
				for (NSString *textEquivalent in emoticon.textEquivalents) {
					if (textEquivalent.length) {
						NSMutableArray	*subIndex;
						NSString		*firstCharacterString;
                        
						firstCharacterString = [NSString stringWithFormat:@"%C",[textEquivalent characterAtIndex:0]];
                        
						//'First characters' set
						[newEmoticonStartCharacterSet addCharactersInString:firstCharacterString];
						
						// -- Index --
						//Get the index according to this emoticon's first character
						if ((subIndex = [newEmoticonIndex objectForKey:firstCharacterString])) {
							subIndex = [subIndex mutableCopy];
						} else {
							subIndex = [[NSMutableArray alloc] init];
						}
						
						[newEmoticonIndex setObject:subIndex forKey:firstCharacterString];
						[subIndex release];
						
						//Place the emoticon into that index (If it isn't already in there)
						if (![subIndex containsObject:emoticon]) {
							[subIndex addObject:emoticon];
						}
					}
				}
			}
			
			//Use our new index and character set for processing emoticons in this message
			emoticonIndex = [newEmoticonIndex autorelease];
			emoticonStartCharacterSet = [newEmoticonStartCharacterSet autorelease];
		}
        
	} else if ([context isKindOfClass:[AIListContact class]]) {
		serviceClassContext = [[[adium.accountController preferredAccountForSendingContentType:CONTENT_MESSAGE_TYPE
                                                                                     toContact:(AIListContact *)context] service] serviceClass];
	} else if ([context isKindOfClass:[AIListObject class]] && [context respondsToSelector:@selector(service)]) {
		serviceClassContext = ((AIListObject *)context).service.serviceClass;
	}
	
    //Number of characters we've replaced so far (used to calcluate placement in the destination string)
	NSUInteger	replacementCount = 0; 
    
	messageStringLength = [messageString length];
    while (currentLocation != NSNotFound && currentLocation < messageStringLength) {
		[self replaceAnEmoticonStartingAtLocation:&currentLocation
									   fromString:messageString
							  messageStringLength:messageStringLength
						 originalAttributedString:inMessage
									   intoString:&newMessage
								 replacementCount:&replacementCount
							   callingRecursively:NO
							  serviceClassContext:serviceClassContext
						emoticonStartCharacterSet:emoticonStartCharacterSet
									emoticonIndex:emoticonIndex
										isMessage:isMessage];
    }
    
    return (newMessage ? [newMessage autorelease] : inMessage);
}



/*!
 * @brief Perform a single emoticon replacement
 *
 * This method may call itself recursively to perform additional adjacent emoticon replacements
 *
 * @result The location in messageString of the beginning of the emoticon replaced, or NSNotFound if no replacement was made
 */
- (NSUInteger)replaceAnEmoticonStartingAtLocation:(NSUInteger *)currentLocation
                                       fromString:(NSString *)messageString
                              messageStringLength:(NSUInteger)messageStringLength
                         originalAttributedString:(NSAttributedString *)originalAttributedString
                                       intoString:(NSMutableAttributedString **)newMessage
                                 replacementCount:(NSUInteger *)replacementCount
                               callingRecursively:(BOOL)callingRecursively
                              serviceClassContext:(id)serviceClassContext
                        emoticonStartCharacterSet:(NSCharacterSet *)emoticonStartCharacterSet
                                    emoticonIndex:(NSDictionary *)emoticonIndex
                                        isMessage:(BOOL)isMessage
{
	NSUInteger	originalEmoticonLocation = NSNotFound;
    
	//Find the next occurence of a suspected emoticon
	*currentLocation = [messageString rangeOfCharacterFromSet:emoticonStartCharacterSet
													  options:NSLiteralSearch
														range:NSMakeRange(*currentLocation, 
																		  messageStringLength - *currentLocation)].location;
	if (*currentLocation != NSNotFound) {
		//Use paired arrays so multiple emoticons can qualify for the same text equivalent
		NSMutableArray  *candidateEmoticons = nil;
		NSMutableArray  *candidateEmoticonTextEquivalents = nil;		
		unichar         currentCharacter = [messageString characterAtIndex:*currentLocation];
		NSString        *currentCharacterString = [NSString stringWithFormat:@"%C", currentCharacter];
        
		//Check for the presence of all emoticons starting with this character
		for (AIEmoticon *emoticon in [emoticonIndex objectForKey:currentCharacterString]) {			
			for (NSString *text in [emoticon textEquivalents]) {
				NSInteger     textLength = [text length];
				
				if (textLength != 0) { //Invalid emoticon files may let empty text equivalents sneak in
                    //If there is not enough room in the string for this text, we can skip it
					if (*currentLocation + textLength <= messageStringLength) {
						if ([messageString compare:text
										   options:NSLiteralSearch
											 range:NSMakeRange(*currentLocation, textLength)] == NSOrderedSame) {
							//Ignore emoticons within links
							if ([originalAttributedString attribute:NSLinkAttributeName
															atIndex:*currentLocation
													 effectiveRange:nil] == nil) {
								if (!candidateEmoticons) {
									candidateEmoticons = [[NSMutableArray alloc] init];
									candidateEmoticonTextEquivalents = [[NSMutableArray alloc] init];
								}
								
								[candidateEmoticons addObject:emoticon];
								[candidateEmoticonTextEquivalents addObject:text];
							}
						}
					}
				}
			}
		}
        
		BOOL currentLocationNeedsUpdate = YES;
        
		if ([candidateEmoticons count]) {
			NSString					*replacementString;
			NSMutableAttributedString   *replacement;
			NSInteger					textLength;
			NSRange						emoticonRangeInNewMessage;
            
			originalEmoticonLocation = *currentLocation;
            
			//Use the most appropriate, longest string of those which could be used for the emoticon text we found here
			AIEmoticon *emoticon = [self _bestReplacementFromEmoticons:candidateEmoticons
                                                       withEquivalents:candidateEmoticonTextEquivalents
                                                               context:serviceClassContext
                                                            equivalent:&replacementString
                                                      equivalentLength:&textLength];
			emoticonRangeInNewMessage = NSMakeRange(*currentLocation - *replacementCount, textLength);
			
			/* We want to show this emoticon if there is:
			 *		It begins or ends the string
			 *		It is bordered by spaces or line breaks or quotes on both sides
			 *		It is bordered by a period on the left and a space or line break or quote the right
			 *		It is bordered by emoticons on both sides or by an emoticon on the left and a period, space, or line break on the right
			 */
			BOOL	acceptable = NO;
			if ((messageStringLength == ((originalEmoticonLocation + textLength))) || //Ends the string
				(originalEmoticonLocation == 0)) { //Begins the string
				acceptable = YES;
			}
			if (!acceptable) {
				/* Bordered by spaces or line breaks or quotes, or by a period on the left and a space or a line break or quote on the right
				 * If we're being called recursively, we have a potential emoticon to our left;  we only need to check the right.
				 * This is also true if we're not being called recursively but there's an NSAttachmentAttribute to our left.
				 *		That will happen if, for example, the string is ":):) ". The first emoticon is at the start of the line and
				 *		so is immediately acceptable. The second should be acceptable because it is to the right of an emoticon and
				 *		the left of a space.
				 */
				char	previousCharacter = [messageString characterAtIndex:(originalEmoticonLocation - 1)] ;
				char	nextCharacter = [messageString characterAtIndex:(originalEmoticonLocation + textLength)] ;
                
				if ((callingRecursively || (previousCharacter == ' ') || (previousCharacter == '\t') ||
					 (previousCharacter == '\n') || (previousCharacter == '\r') || (previousCharacter == '.') || (previousCharacter == '?') || (previousCharacter == '!') ||
					 (previousCharacter == '\"') || (previousCharacter == '\'') ||
					 (previousCharacter == '(') || (previousCharacter == '*') ||
					 (*newMessage && [*newMessage attribute:NSAttachmentAttributeName
													atIndex:(emoticonRangeInNewMessage.location - 1) 
											 effectiveRange:NULL])) &&
                    
					((nextCharacter == ' ') || (nextCharacter == '\t') || (nextCharacter == '\n') || (nextCharacter == '\r') ||
					 (nextCharacter == '.') || (nextCharacter == ',') || (nextCharacter == '?') || (nextCharacter == '!') ||
					 (nextCharacter == ')') || (nextCharacter == '*') ||
					 (nextCharacter == '\"') || (nextCharacter == '\''))) {
                        acceptable = YES;
                    }
			}
			if (!acceptable) {
				/* If the emoticon would end the string except for whitespace, newlines, or punctionation at the end, or it begins the string after removing
				 * whitespace, newlines, or punctuation at the beginning, it is acceptable even if the previous conditions weren't met.
				 */
				NSCharacterSet *endingTrimSet = nil;
				static NSMutableDictionary *endingSetDict = nil;
				if(!endingSetDict) {
					endingSetDict = [[NSMutableDictionary alloc] initWithCapacity:10];
				}
				if (!(endingTrimSet = [endingSetDict objectForKey:replacementString])) {
					NSMutableCharacterSet *tempSet = [[NSCharacterSet punctuationCharacterSet] mutableCopy];
					[tempSet formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					[tempSet formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
					//remove any characters *in* the replacement string from the trimming set
					[tempSet removeCharactersInString:replacementString];
					[endingSetDict setObject:[tempSet immutableCopy] forKey:replacementString];
					[tempSet release];
					endingTrimSet = [endingSetDict objectForKey:replacementString];
				}
                
				NSString	*trimmedString = [messageString stringByTrimmingCharactersInSet:endingTrimSet];
				NSUInteger trimmedLength = [trimmedString length];
				if (trimmedLength == (originalEmoticonLocation + textLength)) {
					// Replace at end of string
					acceptable = YES;
				} else if ([trimmedString characterAtIndex:0] == [replacementString characterAtIndex:0]) {
					// Replace at start of string
					acceptable = YES;					
				}
			}
			if (!acceptable) {
				/* If we still haven't determined it to be acceptable, look ahead.
				 * If we do a replacement adjacent to this emoticon, we can do this one, too.
				 */
				NSUInteger newCurrentLocation = *currentLocation;
				NSUInteger nextEmoticonLocation;
                
				/* Call ourself recursively, starting just after the end of the current emoticon candidate
				 * If the return value is not NSNotFound, an emoticon was found and replaced ahead of us. Discontinuous searching for the win.
				 */
				newCurrentLocation += textLength;
				nextEmoticonLocation = [self replaceAnEmoticonStartingAtLocation:&newCurrentLocation
																	  fromString:messageString
															 messageStringLength:messageStringLength
														originalAttributedString:originalAttributedString
																	  intoString:newMessage
																replacementCount:replacementCount
															  callingRecursively:YES
															 serviceClassContext:serviceClassContext
													   emoticonStartCharacterSet:emoticonStartCharacterSet
																   emoticonIndex:emoticonIndex
																	   isMessage:isMessage];
				if (nextEmoticonLocation != NSNotFound) {
					if (nextEmoticonLocation == (*currentLocation + textLength)) {
						/* The next emoticon is immediately after the candidate we're looking at right now. That means
                         * our current candidate is in fact an emoticon (since it borders another emoticon).
                         */
						acceptable = YES;
					}
					
					currentLocationNeedsUpdate = NO;
					*currentLocation = newCurrentLocation;
				} else {
					/* If there isn't a next emoticon, we can skip ahead to the end of the string. */			
					*currentLocation = messageStringLength;
					currentLocationNeedsUpdate = NO;
				}
			}
            
			if (acceptable) {
				replacement = [emoticon attributedStringWithTextEquivalent:replacementString attachImages:!isMessage];
				
				NSDictionary *originalAttributes = [originalAttributedString attributesAtIndex:originalEmoticonLocation
																				effectiveRange:nil];
				
				originalAttributes = [originalAttributes dictionaryWithDifferenceWithSetOfKeys:[NSSet setWithObject:NSAttachmentAttributeName]];
				
				//grab the original attributes, to ensure that the background is not lost in a message consisting only of an emoticon
				[replacement addAttributes:originalAttributes
									 range:NSMakeRange(0,1)];
				
				//insert the emoticon
				if (!(*newMessage)) *newMessage = [originalAttributedString mutableCopy];
				[*newMessage replaceCharactersInRange:emoticonRangeInNewMessage
								 withAttributedString:replacement];
				
				//Update where we are in the original and replacement messages
				*replacementCount += textLength-1;
				
				if (currentLocationNeedsUpdate)
					*currentLocation += textLength-1;
			} else {
				//Didn't find an acceptable emoticon, so we should return NSNotFound
				originalEmoticonLocation = NSNotFound;
			}			
		}
        
		//Always increment the loop
		if (currentLocationNeedsUpdate) {
			*currentLocation += 1;
		}
		
		[candidateEmoticons release];
		[candidateEmoticonTextEquivalents release];
	}
    
	return originalEmoticonLocation;
}


- (AIEmoticon *) _bestReplacementFromEmoticons:(NSArray *)candidateEmoticons
							   withEquivalents:(NSArray *)candidateEmoticonTextEquivalents
									   context:(NSString *)serviceClassContext
									equivalent:(NSString **)replacementString
							  equivalentLength:(NSInteger *)textLength
{
	NSUInteger	i = 0;
	NSUInteger	bestIndex = 0, bestLength = 0;
	NSUInteger	bestServiceAppropriateIndex = 0, bestServiceAppropriateLength = 0;
	NSString	*serviceAppropriateReplacementString = nil;
	NSUInteger	count;
	
	count = [candidateEmoticonTextEquivalents count];
	while (i < count) {
		NSString	*thisString = [candidateEmoticonTextEquivalents objectAtIndex:i];
		NSUInteger thisLength = [thisString length];
		if (thisLength > bestLength) {
			bestLength = thisLength;
			bestIndex = i;
			*replacementString = thisString;
		}
        
		//If we are using service appropriate emoticons, check if this is on the right service and, if so, compare.
		if (thisLength > bestServiceAppropriateLength) {
			AIEmoticon	*thisEmoticon = [candidateEmoticons objectAtIndex:i];
			if ([thisEmoticon isAppropriateForServiceClass:serviceClassContext]) {
				bestServiceAppropriateLength = thisLength;
				bestServiceAppropriateIndex = i;
				serviceAppropriateReplacementString = thisString;
			}
		}
		
		i++;
	}
    
	/* Did we get a service appropriate replacement? If so, use that rather than the current replacementString if it
	 * differs. */
	if (serviceAppropriateReplacementString && (serviceAppropriateReplacementString != *replacementString)) {
		bestLength = bestServiceAppropriateLength;
		bestIndex = bestServiceAppropriateIndex;
		*replacementString = serviceAppropriateReplacementString;
	}
    
	//Return the length by reference
	*textLength = bestLength;
    
	//Return the AIEmoticon we found to be best
    return [candidateEmoticons objectAtIndex:bestIndex];
}

@end
