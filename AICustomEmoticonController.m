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
#import <Adium/AIContentMessage.h>
#import <Adium/ESDebugAILog.h>
#import <AdiumLibpurple/CBPurpleAccount.h>
#import <AdiumLibpurple/ESMSNService.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <AIUtilities/AICharacterSetAdditions.h>

@interface AICustomEmoticonController (PRIVATE)
- (BOOL)_isCustomEmoticonApplicable:(id)context;
- (void)_buildCharacterSetsAndIndexCustomEmoticons;
- (NSMutableAttributedString *)_convertEmoticonsInMessage:(NSAttributedString *)inMessage context:(id)context;

- (AIEmoticon *) _bestReplacementFromEmoticons:(NSArray *)candidateEmoticons
							   withEquivalents:(NSArray *)candidateEmoticonTextEquivalents
									   context:(NSString *)serviceClassContext
									equivalent:(NSString **)replacementString
							  equivalentLength:(int *)textLength;

- (unsigned int)replaceAnEmoticonStartingAtLocation:(unsigned *)currentLocation
										 fromString:(NSString *)messageString
								messageStringLength:(unsigned int)messageStringLength
						   originalAttributedString:(NSAttributedString *)originalAttributedString
										 intoString:(NSMutableAttributedString **)newMessage
								   replacementCount:(unsigned *)replacementCount
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

- (void)_buildCharacterSetsAndIndexCustomEmoticons {
    NSEnumerator        *emoticonEnumerator;
    AIEmoticon          *emoticon;
	PurpleCustomSmiley  *pemoticon;
    
    //Start with a fresh character set, and a fresh index
	NSMutableCharacterSet	*tmpEmoticonHintCharacterSet = [[NSMutableCharacterSet alloc] init];
	NSMutableCharacterSet	*tmpEmoticonStartCharacterSet = [[NSMutableCharacterSet alloc] init];
	
	[_customEmoticonIndexDict release]; _customEmoticonIndexDict = [[NSMutableDictionary alloc] init];
    
	NSArray* smileys=[AISmileyController getAllSmileys];
	
	emoticonEnumerator = [smileys objectEnumerator];
	while ((pemoticon = [emoticonEnumerator nextObject])) {
		emoticon = [AIEmoticon emoticonWithIconPath:[pemoticon path] equivalents:[NSArray arrayWithObject:[pemoticon shortcut]] name:[[pemoticon shortcut] stringByAppendingString:@"#custom"]  pack:nil];
		
		NSEnumerator        *textEnumerator;
		NSString            *text;
		
		textEnumerator = [[emoticon textEquivalents] objectEnumerator];
		while ((text = [textEnumerator nextObject])) {
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
			if([[[[contMessage chat] account] preferenceForKey:KEY_DISPLAY_CUSTOM_EMOTICONS group:GROUP_ACCOUNT_STATUS] boolValue])
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

- (NSAttributedString *)filterAttributedString:(NSAttributedString *)inAttributedString context:(id)context {
	if(!inAttributedString || ![inAttributedString length]) 
		return inAttributedString;
	
	NSMutableAttributedString   *replacementMessage = nil;
	
	if(![self _isCustomEmoticonApplicable:context])
		return inAttributedString;
	
	NSCharacterSet* customSet=[self customEmoticonHintCharacterSet];
	
	if ([[inAttributedString string] rangeOfCharacterFromSet:customSet].location != NSNotFound )
		replacementMessage = [self _convertEmoticonsInMessage:inAttributedString context:context];
	
	return (replacementMessage ? replacementMessage : inAttributedString);
	
}


//Insert graphical emoticons into a string
- (NSMutableAttributedString *)_convertEmoticonsInMessage:(NSAttributedString *)inMessage context:(id)context {
    NSString                    *messageString = [inMessage string];
    NSMutableAttributedString   *newMessage = nil; //We avoid creating a new string unless necessary
	NSString					*serviceClassContext = nil;
    unsigned					currentLocation = 0, messageStringLength;
	NSCharacterSet				*emoticonStartCharacterSet = nil;
	NSDictionary				*emoticonIndex = nil;
	//we can avoid loading images if the emoticon is headed for the wkmv, since it will just load from the original path anyway  
	
	//Determine our service class context
	if ([context isKindOfClass:[AIContentObject class]]) {
		serviceClassContext = [[[(AIContentObject *)context destination] service] serviceClass];
		//If there's no destination, try to use the source for context
		if (!serviceClassContext) {
			serviceClassContext = [[[(AIContentObject *)context source] service] serviceClass];
		}
		
		if ([self _isCustomEmoticonApplicable:context])
		{
			emoticonStartCharacterSet=[self customEmoticonStartCharacterSet];
			emoticonIndex=[self customEmoticonIndex];
			
			if(emoticonStartCharacterSet && emoticonIndex) {				
				//Number of characters we've replaced so far (used to calcluate placement in the destination string)
				unsigned int	replacementCount = 0; 
				
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
													isMessage:YES];
				}
				
			}
		}
		
	} 
	
    return (newMessage ? [newMessage autorelease] : [inMessage mutableCopy]);
}



/*!
 * @brief Perform a single emoticon replacement
 *
 * This method may call itself recursively to perform additional adjacent emoticon replacements
 *
 * @result The location in messageString of the beginning of the emoticon replaced, or NSNotFound if no replacement was made
 */
- (unsigned int)replaceAnEmoticonStartingAtLocation:(unsigned *)currentLocation
										 fromString:(NSString *)messageString
								messageStringLength:(unsigned int)messageStringLength
						   originalAttributedString:(NSAttributedString *)originalAttributedString
										 intoString:(NSMutableAttributedString **)newMessage
								   replacementCount:(unsigned *)replacementCount
								 callingRecursively:(BOOL)callingRecursively
								serviceClassContext:(id)serviceClassContext
						  emoticonStartCharacterSet:(NSCharacterSet *)emoticonStartCharacterSet
									  emoticonIndex:(NSDictionary *)emoticonIndex
										  isMessage:(BOOL)isMessage
{
	NSInteger	originalEmoticonLocation = NSNotFound;
	
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
		NSEnumerator    *emoticonEnumerator;
		AIEmoticon      *emoticon;     
		
		//Check for the presence of all emoticons starting with this character
		emoticonEnumerator = [[emoticonIndex objectForKey:currentCharacterString] objectEnumerator];
		while ((emoticon = [emoticonEnumerator nextObject])) {
			NSEnumerator        *textEnumerator;
			NSString            *text;
			
			textEnumerator = [[emoticon textEquivalents] objectEnumerator];
			while ((text = [textEnumerator nextObject])) {
				int     textLength = [text length];
				
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
		
		if ([candidateEmoticons count]) {
			NSString					*replacementString;
			NSMutableAttributedString   *replacement;
			int							textLength;
			NSRange						emoticonRangeInNewMessage;
			int							amountToIncreaseCurrentLocation = 0;
			
			originalEmoticonLocation = *currentLocation;
			
			//Use the most appropriate, longest string of those which could be used for the emoticon text we found here
			emoticon = [self _bestReplacementFromEmoticons:candidateEmoticons
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
				static NSCharacterSet *endingTrimSet = nil;
				if (!endingTrimSet) {
					NSMutableCharacterSet *tempSet = [[NSCharacterSet punctuationCharacterSet] mutableCopy];
					[tempSet formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					endingTrimSet = [tempSet immutableCopy];
					[tempSet release];
				}
				
				NSString	*trimmedString = [messageString stringByTrimmingCharactersInSet:endingTrimSet];
				unsigned int trimmedLength = [trimmedString length];
				if (trimmedLength == (originalEmoticonLocation + textLength)) {
					acceptable = YES;
				} else if ((originalEmoticonLocation - (messageStringLength - trimmedLength)) == 0) {
					acceptable = YES;					
				}
			}
			if (!acceptable) {
				/* If we still haven't determined it to be acceptable, look ahead.
				 * If we do a replacement adjacent to this emoticon, we can do this one, too.
				 */
				unsigned int newCurrentLocation = *currentLocation;
				unsigned int nextEmoticonLocation;
				
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
				}
				
				/* Whether the current candidate is acceptable or not, we can now skip ahead to just after the next emoticon if
				 * there is one. If there isn't, we can skip ahead to the end of the string.
				 *
				 * We do -1 because we will do a +1 at the end of the loop no matter what.
				 */				
				if (newCurrentLocation != NSNotFound) {
					amountToIncreaseCurrentLocation = (newCurrentLocation - *currentLocation) - 1;
				} else {
					amountToIncreaseCurrentLocation = (messageStringLength - *currentLocation) - 1;					
				}
			}
			
			if (acceptable) {
				replacement = [emoticon attributedStringWithTextEquivalent:replacementString attachImages:!isMessage];
				
				//grab the original attributes, to ensure that the background is not lost in a message consisting only of an emoticon
				[replacement addAttributes:[originalAttributedString attributesAtIndex:originalEmoticonLocation
																		effectiveRange:nil] 
									 range:NSMakeRange(0,1)];
				
				//insert the emoticon
				if (!(*newMessage)) *newMessage = [originalAttributedString mutableCopy];
				[*newMessage replaceCharactersInRange:emoticonRangeInNewMessage
								 withAttributedString:replacement];
				
				//Update where we are in the original and replacement messages
				*replacementCount += textLength-1;
				*currentLocation += textLength-1;
			} else {
				//Didn't find an acceptable emoticon, so we should return NSNotFound
				originalEmoticonLocation = NSNotFound;
			}
			
			//If appropriate, skip ahead by amountToIncreaseCurrentLocation
			*currentLocation += amountToIncreaseCurrentLocation;
		}
		
		//Always increment the loop
		*currentLocation += 1;
		
		[candidateEmoticons release];
		[candidateEmoticonTextEquivalents release];
	}
	
	return originalEmoticonLocation;
}


- (AIEmoticon *) _bestReplacementFromEmoticons:(NSArray *)candidateEmoticons
							   withEquivalents:(NSArray *)candidateEmoticonTextEquivalents
									   context:(NSString *)serviceClassContext
									equivalent:(NSString **)replacementString
							  equivalentLength:(int *)textLength
{
	unsigned	i = 0;
	unsigned	bestIndex = 0, bestLength = 0;
	unsigned	bestServiceAppropriateIndex = 0, bestServiceAppropriateLength = 0;
	NSString	*serviceAppropriateReplacementString = nil;
	unsigned	count;
	
	count = [candidateEmoticonTextEquivalents count];
	while (i < count) {
		NSString	*thisString = [candidateEmoticonTextEquivalents objectAtIndex:i];
		unsigned thisLength = [thisString length];
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
