//
//  MTTiVo.m
//  cTiVo
//
//  Created by Scott Buchanan on 1/5/13.
//  Copyright (c) 2013 Scott Buchanan. All rights reserved.
//

#import "MTTiVo.h"
#import "MTTiVoShow.h"
#import "NSString+HTML.h"
#import "MTTiVoManager.h"

#define kMTStringType 0
#define kMTBoolType 1
#define kMTNumberType 2
#define kMTDateType 3

#define kMTValue @"KeyValue"
#define kMTType @"KeyType"


#define kMTNumberShowToGet 50
#define kMTNumberShowToGetFirst 15


@interface MTTiVo ()
@property SCNetworkReachabilityRef reachability;
@property (nonatomic, assign) NSArray *downloadQueue;
@end

@implementation MTTiVo

+(MTTiVo *)tiVoWithTiVo:(id)tiVo withOperationQueue:(NSOperationQueue *)queue
{
	return [[[MTTiVo alloc] initWithTivo:tiVo withOperationQueue:(NSOperationQueue *)queue] autorelease];
}
	
-(id)init
{
	self = [super init];
	if (self) {
		self.shows = [NSMutableArray array];
		urlData = [NSMutableData new];
		_tiVo = nil;
		previousShowList = nil;
		_mediaKey = @"";
		isConnecting = NO;
		_mediaKeyIsGood = NO;
        managingDownloads = NO;
        _manualTiVo = NO;
		firstUpdate = YES;
		_enabled = YES;
        itemStart = 0;
        itemCount = 50;
        reachabilityContext.version = 0;
        reachabilityContext.info = self;
        reachabilityContext.retain = NULL;
        reachabilityContext.release = NULL;
        reachabilityContext.copyDescription = NULL;
        elementToPropertyMap = @{
            @"Title" : @{kMTValue : @"seriesTitle", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"EpisodeTitle" : @{kMTValue : @"episodeTitle", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"CopyProtected" : @{kMTValue : @"protectedShow", kMTType : [NSNumber numberWithInt:kMTBoolType]},
            @"InProgress" : @{kMTValue : @"protectedShow", kMTType : [NSNumber numberWithInt:kMTBoolType]},
            @"SourceSize" : @{kMTValue : @"fileSize", kMTType : [NSNumber numberWithInt:kMTNumberType]},
            @"Duration" : @{kMTValue : @"showLengthString", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"CaptureDate" : @{kMTValue : @"showDate", kMTType : [NSNumber numberWithInt:kMTDateType]},
            @"Description" : @{kMTValue : @"showDescription", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"SourceChannel" : @{kMTValue : @"channelString", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"SourceStation" : @{kMTValue : @"stationCallsign", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"HighDefinition" : @{kMTValue : @"isHD", kMTType : [NSNumber numberWithInt:kMTBoolType]},
            @"ProgramId" : @{kMTValue : @"programId", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"SeriesId" : @{kMTValue : @"seriesId", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"TvRating" : @{kMTValue : @"tvRating", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"SourceType" : @{kMTValue : @"sourceType", kMTType : [NSNumber numberWithInt:kMTStringType]},
            @"IdGuideSource" : @{kMTValue : @"idGuidSource", kMTType : [NSNumber numberWithInt:kMTStringType]}};
		elementToPropertyMap = [[NSDictionary alloc] initWithDictionary:elementToPropertyMap];
	}
	return self;
	
}

-(id) initWithTivo:(id)tiVo withOperationQueue:(NSOperationQueue *)queue
{
	self = [self init];
	if (self) {
		self.tiVo = tiVo;
		self.queue = queue;
        _reachability = SCNetworkReachabilityCreateWithAddress(NULL, [self.tiVo.addresses[0] bytes]);
		self.networkAvailability = [NSDate date];
		BOOL didSchedule = NO;
		if (_reachability) {
			SCNetworkReachabilitySetCallback(_reachability, tivoNetworkCallback, &reachabilityContext);
			didSchedule = SCNetworkReachabilityScheduleWithRunLoop(_reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
		}
		_isReachable = YES;
		NSLog(@"%@ reachability for tivo %@",didSchedule ? @"Scheduled" : @"Failed to schedule", _tiVo.name);
		[self getMediaKey];
		if (_mediaKey.length == 0) {
			[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationMediaKeyNeeded object:self];
		} else {
			[self updateShows:nil];
		}
        NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
        [defaultCenter addObserver:self selector:@selector(manageDownloads:) name:kMTNotificationDownloadQueueUpdated object:nil];
        [defaultCenter addObserver:self selector:@selector(manageDownloads:) name:kMTNotificationDownloadDidFinish object:nil];
        [defaultCenter addObserver:self selector:@selector(manageDownloads:) name:kMTNotificationDecryptDidFinish object:nil];
	}
	return self;
}

void tivoNetworkCallback    (SCNetworkReachabilityRef target,
							 SCNetworkReachabilityFlags flags,
							 void *info)
{
    MTTiVo *thisTivo = (MTTiVo *)info;
	thisTivo.isReachable = (flags >>17) && 1 ;
	if (thisTivo.isReachable) {
		thisTivo.networkAvailability = [NSDate date];
		[NSObject cancelPreviousPerformRequestsWithTarget:thisTivo selector:@selector(manageDownloads:) object:thisTivo];
//        NSLog(@"QQQcalling managedownloads from MTTiVo:tivoNetworkCallback with delay+2");
		[thisTivo performSelector:@selector(manageDownloads:) withObject:thisTivo afterDelay:kMTTiVoAccessDelay+2];
		[thisTivo performSelector:@selector(updateShows:) withObject:nil afterDelay:kMTTiVoAccessDelay];
	} 
    [[NSNotificationCenter defaultCenter] postNotificationName: kMTNotificationNetworkChanged object:nil];
	NSLog(@"Tivo %@ is now %@", thisTivo.tiVo.name, thisTivo.isReachable ? @"online" : @"offline");
}

-(NSString * ) description {
    return self.tiVo.name;
}

//-(void) reportNetworkFailure {
//    [[NSNotificationCenter defaultCenter] postNotificationName: kMTNotificationNetworkNotAvailable object:self];
////    [self performSelector:@selector(updateShows:) withObject:nil afterDelay:kMTRetryNetworkInterval];
//}

//-(BOOL) isReachable {
//    uint32_t    networkReachabilityFlags;
//    SCNetworkReachabilityGetFlags(self.reachability , &networkReachabilityFlags);
//    BOOL result = (networkReachabilityFlags >>17) && 1 ;  //if the 17th bit is set we are reachable.
//    return result;
//}
//
-(void)getMediaKey
{
	NSString *mediaKeyString = @"";
    NSMutableDictionary *mediaKeys = [NSMutableDictionary dictionary];
    if ([[NSUserDefaults standardUserDefaults] dictionaryForKey:kMTMediaKeys]) {
        mediaKeys = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:kMTMediaKeys]];
    }
    if ([mediaKeys objectForKey:_tiVo.name]) {
        mediaKeyString = [mediaKeys objectForKey:_tiVo.name];
    }else {
        NSArray *keys = [mediaKeys allKeys];
        if (keys.count) {
            mediaKeyString = [mediaKeys objectForKey:[keys objectAtIndex:0]];
            [mediaKeys setObject:mediaKeyString forKey:_tiVo.name];
            [[NSUserDefaults standardUserDefaults] setObject:mediaKeys  forKey:kMTMediaKeys];
        }
    }
    self.mediaKey = mediaKeyString;
}

-(void)updateShows:(id)sender
{
	if (isConnecting) {
		return;
	}
//	if (!sender && [[NSDate date] compare:[_lastUpdated dateByAddingTimeInterval:kMTUpdateIntervalMinutes * 60]] == NSOrderedAscending) {
//		return;
//	}
	if (showURLConnection) {
		[showURLConnection cancel];
		[showURLConnection release];
		showURLConnection = nil;
	}
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateShows:) object:nil];
//	if (![self isReachable]){
//        [self reportNetworkFailure];
//        return;
//    }
    isConnecting = YES;
	if (previousShowList) {
		[previousShowList release];
	}
	previousShowList = [[NSMutableDictionary dictionary] retain];
	for (MTTiVoShow * show in _shows) {
		NSString * idString = [NSString stringWithFormat:@"%d",show.showID];
//		NSLog(@"prevID: %@ %@",idString,show.showTitle);
		[previousShowList setValue:show forKey:idString];
	}
    [_shows removeAllObjects];
	[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationShowListUpdating object:self];
	[self updateShowsStartingAt:0 withCount:kMTNumberShowToGetFirst];
}

-(NSInteger)numberOfShowsInProcess
{
    NSInteger n = 0;
    for (MTTiVoShow *show in _shows) {
        if (show.isInProgress) {
            n++;
        }
    }
    return n;
}

-(void)rescheduleAllShows
{
    for (MTTiVoShow *show in _shows) {
        if (show.isInProgress) {
            [show rescheduleShow:@NO];
        }
    }
    
}

-(void)updateShowsStartingAt:(int)anchor withCount:(int)count
{
	NSString *portString = @"";
	if ([_tiVo isKindOfClass:[MTNetService class]]) {
		portString = [NSString stringWithFormat:@":%d",_tiVo.userPortSSL];
	}
	
	NSString *tivoURLString = [[NSString stringWithFormat:@"https://%@%@/TiVoConnect?Command=QueryContainer&Container=%%2FNowPlaying&Recurse=Yes&AnchorOffset=%d&ItemCount=%d",_tiVo.hostName,portString,anchor,count] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//	NSLog(@"Tivo URL String %@",tivoURLString);
	NSURL *tivoURL = [NSURL URLWithString:tivoURLString];
	NSURLRequest *tivoURLRequest = [NSURLRequest requestWithURL:tivoURL];
	showURLConnection = [[NSURLConnection connectionWithRequest:tivoURLRequest delegate:self] retain];
	[urlData setData:[NSData data]];
	[showURLConnection start];
		
}

#pragma mark - NSXMLParser Delegate Methods

-(void)parserDidStartDocument:(NSXMLParser *)parser
{
    parsingShow = NO;
    gettingContent = NO;
    gettingDetails = NO;
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    element = [NSMutableString string];
    if ([elementName compare:@"Item"] == NSOrderedSame) {
        parsingShow = YES;
        currentShow = [[MTTiVoShow alloc] init];
        gettingContent = NO;
        gettingDetails = NO;
    }
    if ([elementName compare:@"Content"] == NSOrderedSame) {
        gettingContent = YES;
    }
    if ([elementName compare:@"TiVoVideoDetails"] == NSOrderedSame) {
        gettingDetails = YES;
    }
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [element appendString:string];
}


-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
//	NSLog(@"ZZZEnding element parse for tivo %@ and element %@ with value %@",_tiVo.name,elementName,element);
    if (parsingShow) {
        //extract show parameters here
//        [currentShow setValue:element forKey:elementToPropertyMap[elementName]];
		if ([elementName compare:@"TiVoVideoDetails"] == NSOrderedSame) {
			gettingDetails = NO;
		} else if ([elementName compare:@"Content"] == NSOrderedSame) {
			gettingContent = NO;
		} else if (gettingDetails) {
            //Get URL for details here
			if ([elementName caseInsensitiveCompare:@"Url"] == NSOrderedSame) {
				//If a manual tivo put in port information
				if (self.manualTiVo) {
					[self updatePortsInURLString:element];
				}
				[currentShow setValue:[NSURL URLWithString:element] forKey:@"detailURL"];
			}
        } else if (gettingContent) {
            //Get URL for Content here
			if ([elementName caseInsensitiveCompare:@"Url"] == NSOrderedSame) {
				NSRegularExpression *idRx = [NSRegularExpression regularExpressionWithPattern:@"id=(\\d+)" options:NSRegularExpressionCaseInsensitive error:nil];
				NSTextCheckingResult *idResult = [idRx firstMatchInString:element options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(0, element.length)];
				if(idResult.range.location != NSNotFound){
					currentShow.showID = [[element substringWithRange:[idResult rangeAtIndex:1]] intValue];
				}
				if (self.manualTiVo) {
					[self updatePortsInURLString:element];
				}
				[currentShow setValue:[NSURL URLWithString:element] forKey:@"downloadURL"];
			}
        } else if ([elementToPropertyMap objectForKey:elementName]){
//        [currentShow setValue:element forKey:elementToPropertyMap[elementName]];
            int type = [elementToPropertyMap[elementName][kMTType] intValue];
			double timestamp = 0;
			NSDate *thisDate = nil;
            switch (type) {
                case kMTStringType:
                    //Process String Type here
					[currentShow setValue:element forKey:elementToPropertyMap[elementName][kMTValue]];
                    break;
                    
                case kMTBoolType:
                    //Process String Type here
					[currentShow setValue:[NSNumber numberWithBool:[element boolValue]] forKey:elementToPropertyMap[elementName][kMTValue]];
//					NSLog(@"set %@ property to %@ for %@ element",elementToPropertyMap[elementName][kMTValue],[NSNumber numberWithBool:[element boolValue]], element);
                    break;
                                        
                case kMTNumberType:
                    //Process String Type here
 					[currentShow setValue:[NSNumber numberWithDouble:[element doubleValue]] forKey:elementToPropertyMap[elementName][kMTValue]];
                   break;
                    
                case kMTDateType:
                    //Process date type which are hex timestamps
					[[NSScanner scannerWithString:element] scanHexDouble:&timestamp];
//					timestamp = [element doubleValue];
					thisDate = [NSDate dateWithTimeIntervalSince1970:timestamp];
 					[currentShow setValue:thisDate forKey:elementToPropertyMap[elementName][kMTValue]];
                   break;
                    
                default:
                    break;
            }
        } else if ([elementName compare:@"Item"] == NSOrderedSame) {
            MTTiVoShow *thisShow = [previousShowList valueForKey:[NSString stringWithFormat:@"%d",currentShow.showID]];
			if (!thisShow) {
				currentShow.tiVo = self;
				currentShow.mediaKey = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kMTMediaKeys][self.tiVo.name];
				[_shows addObject:currentShow];
				NSInvocationOperation *nextDetail = [[[NSInvocationOperation alloc] initWithTarget:currentShow selector:@selector(getShowDetail) object:nil] autorelease];
				[_queue addOperation:nextDetail];
			} else {
				[_shows addObject:thisShow];
			}
			[currentShow release];
			currentShow = nil;
            parsingShow = NO;
        }
    } else {
        if ([elementName compare:@"TotalItems"] == NSOrderedSame) {
            totalItemsOnTivo = [element intValue];
        }
        if ([elementName compare:@"ItemStart"] == NSOrderedSame) {
            itemStart = [element intValue];
        }
        if ([elementName compare:@"ItemCount"] == NSOrderedSame) {
            itemCount = [element intValue];
        }
        if ([elementName compare:@"LastChangeDate"] == NSOrderedSame) {
            int newLastChangeDate = [element intValue];
            if (newLastChangeDate != lastChangeDate) {
                //Implement start over here
            }
            lastChangeDate = newLastChangeDate;
        }
    }
}

-(void)updatePortsInURLString:(NSMutableString *)elementToUpdate
{
	NSRegularExpression *portRx = [NSRegularExpression regularExpressionWithPattern:@"\\:(\\d+)\\/" options:NSRegularExpressionCaseInsensitive error:nil];
	NSTextCheckingResult *portMatch = [portRx firstMatchInString:elementToUpdate options:0 range:NSMakeRange(0, elementToUpdate.length)];
	if (portMatch.numberOfRanges == 2) {
		NSString *portString = [elementToUpdate substringWithRange:[portMatch rangeAtIndex:1]];
		NSString *portReplaceString = portString;
		if ([portString compare:@"443"] == NSOrderedSame) {
			portReplaceString = [NSString stringWithFormat:@"%d",self.tiVo.userPortSSL];
		}
		if ([portString compare:@"80"] == NSOrderedSame) {
			portReplaceString = [NSString stringWithFormat:@"%d",self.tiVo.userPort];
		}
		[elementToUpdate replaceOccurrencesOfString:portString withString:portReplaceString options:0 range:NSMakeRange(0, elementToUpdate.length)];
	}
}

-(void)parserDidEndDocument:(NSXMLParser *)parser
{
	//Check if we're done yet
	[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationTiVoShowsUpdated object:nil];
	if (itemStart+itemCount < totalItemsOnTivo) {
		[self updateShowsStartingAt:itemStart + itemCount withCount:kMTNumberShowToGet];
	} else {
//		NSLog(@"sss All done");
		if (firstUpdate) {
			[self restoreQueue]; //performSelector:@selector(restoreQueue) withObject:nil afterDelay:10]; //should this post the TiVoShowsUpdated?
			firstUpdate = NO;
		}
		isConnecting = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationShowListUpdated object:self];
		[self performSelector:@selector(updateShows:) withObject:nil afterDelay:(kMTUpdateIntervalMinutes * 60.0) + 1.0];
		//	NSLog(@"Avialable Recordings are %@",_recordings);
	}
    [parser release];
}


#pragma mark - Download Management

-(NSArray *)downloadQueue
{
    return [tiVoManager downloadQueueForTiVo:self];
}

-(void)manageDownloads:(id)info
{
//	NSLog(@"QQQCalled managedownloads on TiVo %@ from notification %@",_tiVo.name,notification.name);
    if ([tiVoManager.hasScheduledQueueStart boolValue]  && [tiVoManager.queueStartTime compare:[NSDate date]] == NSOrderedDescending) { //Don't start unless we're after the scheduled time if we're supposed to be scheduled.
        return;
    }
    if (info) {
        if ([info isKindOfClass:[NSNotification class]]) {
            NSNotification *notification = (NSNotification *)info;
            if (!notification.object || notification.object == self) {
                [self manageDownloads];
            }
        }
        if ([info isKindOfClass:[self class]]) {
            if (info == self ) {
                [self manageDownloads];
            }
        }
    }

}

-(void)manageDownloads
{
//	NSLog(@"QQQ-manageDownloads");
	if (managingDownloads) {
        return;
    }
    managingDownloads = YES;
    //We are only going to have one each of Downloading, Encoding, and Decrypting.  So scan to see what currently happening
//	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(manageDownloads) object:nil];
    BOOL isDownloading = NO, isDecrypting = NO;
    for (MTTiVoShow *s in self.downloadQueue) {
        if ([s.downloadStatus intValue] == kMTStatusDownloading) {
            isDownloading = YES;
        }
        if ([s.downloadStatus intValue] == kMTStatusDecrypting) {
            isDecrypting = YES;
        }
    }
    if (!isDownloading) {
        for (MTTiVoShow *s in self.downloadQueue) {
            if ([s.downloadStatus intValue] == kMTStatusNew && (tiVoManager.numEncoders < kMTMaxNumDownloaders || !s.simultaneousEncode)) {
                if(s.tiVo.isReachable) {
                    if (s.simultaneousEncode) {
                        tiVoManager.numEncoders++;
                    }
					[s download];
                    //                } else {    //We'll try again in kMTRetryNetworkInterval seconds at a minimum;
                    //                    [s.tiVo reportNetworkFailure];
                    //                    NSLog(@"Could not reach %@ tivo will try later",s.tiVo.tiVo.name);
                    //                    [self performSelector:@selector(manageDownloads) withObject:nil afterDelay:kMTRetryNetworkInterval];
                }
                break;
            }
        }
    }
    if (!isDecrypting) {
        for (MTTiVoShow *s in self.downloadQueue) {
            if ([s.downloadStatus intValue] == kMTStatusDownloaded && !s.simultaneousEncode) {
                [s decrypt];
                break;
            }
        }
    }
    if (tiVoManager.numEncoders < kMTMaxNumDownloaders) {
        for (MTTiVoShow *s in self.downloadQueue) {
            if ([s.downloadStatus intValue] == kMTStatusDecrypted && tiVoManager.numEncoders < kMTMaxNumDownloaders) {
				tiVoManager.numEncoders++;
                [s encode];
            }
        }
    }
    managingDownloads = NO;
}


#define kMTQueueShow @"MTQueueShow"
//only used in next two methods, marks shows that have already been requeued
-(MTTiVoShow *) findNextShow:(NSInteger) index {
	for (NSInteger nextIndex = index+1; nextIndex  < tiVoManager.oldQueue.count; nextIndex++) {
		MTTiVoShow * nextShow = tiVoManager.oldQueue[nextIndex][kMTQueueShow];
		if (nextShow != nil) {
			return nextShow;
		}
	}
	return nil;
}

-(void) restoreQueue {
	//find any shows in oldQueue from this TiVo to reload
	NSMutableArray * showsToSubmit = nil;  //signal for not optimize
	if ([tiVoManager downloadQueue].count == 0) {
		//no previous shows to sort against, so we'll optimize first pass through
		showsToSubmit= [NSMutableArray arrayWithCapacity:tiVoManager.oldQueue.count];
	}
	for (NSInteger index = 0; index < tiVoManager.oldQueue.count; index++) {
		NSDictionary * queueEntry = tiVoManager.oldQueue[index];
		//So For each queueEntry, if we haven't found it before, and it's this TiVo
		if (queueEntry[kMTQueueShow] == nil && [self.tiVo.name compare: queueEntry [kMTQueueTivo]] == NSOrderedSame) {
			for (MTTiVoShow * show in self.shows) {
				//see if it's available in shows
				if ([show isSameAs: queueEntry]) {
					NSLog(@"Restoring show %@",queueEntry[kMTQueueTitle]);
					[queueEntry setValue: show forKey:kMTQueueShow];
					if ([[tiVoManager downloadQueue] indexOfObject:show] == NSNotFound ){
						[show restoreDownloadData:queueEntry];
						if (showsToSubmit) {
							[showsToSubmit addObject:show];
						} else {
							MTTiVoShow * nextShow = [self findNextShow:index];
							[tiVoManager addProgramsToDownloadQueue: [NSArray arrayWithObject: show] beforeShow:nextShow];
						}
					} else {
						//otherwise already scheduled. probably Subscription.
						NSLog(@"Already restored: %@",show.showTitle );
					}
					break; //found it so move on
				}
			}
		}
	}
	if (showsToSubmit) {
		[tiVoManager addProgramsToDownloadQueue: showsToSubmit beforeShow:nil];
	}
	for (NSDictionary * queueEntry in tiVoManager.oldQueue) {
		if (queueEntry[kMTQueueShow]== nil && [self.tiVo.name compare: queueEntry [kMTQueueTivo]] == NSOrderedSame) {
			NSLog(@"TiVo no longer has show: %@", queueEntry[kMTQueueTitle]);
		}
	}
}

#pragma mark - Helper Methods

-(long) parseTime: (NSString *) timeString {
	NSRegularExpression *timeRx = [NSRegularExpression regularExpressionWithPattern:@"([0-9]{1,3}):([0-9]{1,2}):([0-9]{1,2})" options:NSRegularExpressionCaseInsensitive error:nil];
	NSTextCheckingResult *timeResult = [timeRx firstMatchInString:timeString options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(0, timeString.length)];
	if (timeResult) {
		NSInteger hr = [timeString substringWithRange:[timeResult rangeAtIndex:1]].integerValue ;
		NSInteger min = [timeString substringWithRange:[timeResult rangeAtIndex:2]].integerValue ;
		NSInteger sec = [timeString substringWithRange:[timeResult rangeAtIndex:3]].integerValue ;
		return hr*3600+min*60+sec;
	} else {
		return 0;
	}
}


#pragma mark - NSURL Delegate Methods

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[urlData appendData:data];
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
//    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
	return YES;  //Ignore self-signed certificate
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:kMTMediaKeys][_tiVo.name];
	if (challenge.previousFailureCount == 0) {
		NSURLCredential *myCredential = [NSURLCredential credentialWithUser:@"tivo" password:password persistence:NSURLCredentialPersistenceForSession];
		[challenge.sender useCredential:myCredential forAuthenticationChallenge:challenge];
	} else {
		[challenge.sender cancelAuthenticationChallenge:challenge];
		[showURLConnection cancel];
		[showURLConnection release];
		showURLConnection = nil;
		isConnecting = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationMediaKeyNeeded object:self];
	}
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"URL Connection Failed with error %@",error);
    [[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationShowListUpdated object:self];
//    [self reportNetworkFailure];
    
    isConnecting = NO;
	
}


-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
//	NSLog(@"Data received is %@",[[[NSString alloc] initWithData:urlData encoding:NSUTF8StringEncoding] autorelease]);
//    [self parseListingData];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:urlData];
	parser.delegate = self;
	[parser parse];
    [showURLConnection release];
    showURLConnection = nil;
}

#pragma mark - Memory Management

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	SCNetworkReachabilityUnscheduleFromRunLoop(_reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
	self.networkAvailability = nil;
	if (_reachability) {
		CFRelease(_reachability);
	}
    _reachability = nil;
	self.mediaKey = nil;
	[urlData release];
	self.shows = nil;
	self.tiVo = nil;
	[elementToPropertyMap release];
	[super dealloc];
}

@end
