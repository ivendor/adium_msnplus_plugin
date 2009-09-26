//
//  Created by Andrea Gianarro on 23/06/08.
//  Copyright 2008 Andrea Gianarro. All rights reserved.
//	Revised by Tiziano Carotti
//

#import "BBStringCategory.h"

//Helper methods
static regex_t first;
static regex_t second;
static BOOL initvar=FALSE;
static BOOL firsttime=TRUE;

static BOOL initRegexSystem()
{
	int error = regcomp(&first, "\\[[abcius\\/][^]]*\\]", REG_EXTENDED | REG_ICASE);
	if(error)
		return FALSE;
	error = regcomp(&second,  "\\[(\\/)?([abcius])(\\=(.*))?\\]", REG_EXTENDED | REG_ICASE);
	if(error)
	{
		regfree(&first);
		return FALSE;
	}
	return TRUE;
}

inline static BOOL init()
{
	if(firsttime)
	{
		@synchronized([NSNull null])
		{
			if(firsttime)
			{
				firsttime=FALSE;
				initvar=initRegexSystem();
			}
		}
	}
	return initvar;
}

static NSArray* splitStringWithRegex(NSString *string, regex_t *re)
{
	//This only accepts POSIX style Regular Exceptions or Extended Regular Exceptions
	char *temp;
	const char* buffer;
	int error;
	regmatch_t pm;
	buffer = [string UTF8String];
	NSMutableArray *array = [[NSMutableArray alloc] init];
	/* This call to regexec() finds the first match on the line. */
	error = regexec (re, buffer, 1, &pm, 0);
	while (error == 0) {  /* While matches found. */
		//Added what's before the match
		if(pm.rm_so > 0) {
			temp = (char *) malloc(sizeof(char)*(pm.rm_so+1));
			strncpy(temp, buffer, pm.rm_so);
			temp[pm.rm_so] = 0;
			[array addObject: [NSString stringWithUTF8String: temp]];
			free(temp);
		}
		//Add the match
		temp = (char *) malloc(sizeof(char)*(pm.rm_eo - pm.rm_so+1));
		strncpy(temp, buffer+ pm.rm_so, pm.rm_eo - pm.rm_so);
		temp[pm.rm_eo - pm.rm_so] = 0;
		[array addObject: [NSString stringWithUTF8String: temp]];
		free(temp);
		/* Substring found between pm.rm_so and pm.rm_eo. */
		/* This call to regexec() finds the next match. */
		error = regexec (re, (buffer += pm.rm_eo), 1, &pm, REG_NOTBOL);
	}
	
	//Add what's remaining after the last match
	if(buffer[0])
		[array addObject: [NSString stringWithUTF8String: buffer]];
	return [array autorelease];
}

static NSArray* findInStringWithRegex( NSString *string, regex_t *re)
{
	const char* buffer;
	char *temp; 
	int error, i;
	regmatch_t *pm;
	buffer = [string UTF8String];
	NSMutableArray *array = [[NSMutableArray alloc] init];
	pm = (regmatch_t *) malloc(sizeof(regmatch_t)*(re->re_nsub+1));
	/* This call to regexec() finds the first match on the line. */
	error = regexec(re, buffer, re->re_nsub+1, pm, 0);
	if(!error) {
		for(i=0;i<=re->re_nsub;i++) {
			temp = (char *) malloc(sizeof(char)*(pm[i].rm_eo - pm[i].rm_so+1));
			strncpy(temp,buffer+ pm[i].rm_so,pm[i].rm_eo - pm[i].rm_so);
			temp[pm[i].rm_eo - pm[i].rm_so] = 0;
			[array addObject: [NSString stringWithUTF8String:temp]];
			free(temp);
		}
		free(pm);
		return [array autorelease];
	} else {
		free(pm);
		[array release];
		return nil;
	}
}

static BBNode* createRootFromString(NSString *string)
{
	NSArray *results = splitStringWithRegex(string, &first);
	NSEnumerator *enm = [results objectEnumerator];
	NSString* word;
	BBNode *node, *lastNode, *root = [[BBNode alloc] init];
	[root setParent: root];
	lastNode = root;
	NSArray *match;
	while((word = [enm nextObject])) {
		if((match = findInStringWithRegex(word,&second))) {
		//it's a tag
			if ([[match objectAtIndex:1] isEqualToString:@"/"]) {
			//ending tag
				lastNode = [lastNode parent];
			} else {
			//starting tag
				node = [[BBNode alloc] init];
				[node setType: [match objectAtIndex:2] andValue: [match objectAtIndex:4]];
				[lastNode addChild: node];
				lastNode = node;
				[node release];
			}
		} else {
		//it's text
			node = [[BBNode alloc] init];
			[node setType: @"text" andValue: word];
			[lastNode addChild: node];
			[node release];
		}
	}
	return [root autorelease];
}

@implementation NSAttributedString (BBStringCategory)

-(id)initWithBBCode: (NSString *)string
{
	if(!init())
		return [self initWithString: string];
	BBNode *root = createRootFromString(string);
	[self autorelease];
	return [[root parseIntoAttributedString:[NSMutableDictionary dictionaryWithCapacity:0]] retain];
		
}

-(id)initWithBBCode: (NSString *)string attributes: (NSDictionary *)dict
{
	if(!init())
		return [self initWithString: string attributes: dict];
	BBNode *root = createRootFromString(string);
	[self autorelease];
	return [[root parseIntoAttributedString:dict] retain];
}

@end

@implementation NSString (BBStringCategory)

- (NSString *)transBBCode:(BOOL)HTMLTags
{
	if(!init())
		return [NSString stringWithString:self];
	BBNode *root = createRootFromString(self);
	
	if(HTMLTags)
		return [root parseIntoHTML];
	else
		return [root getPlainTextString];
}

@end
