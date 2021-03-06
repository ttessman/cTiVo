//
//  MTiTivoImport.m
//  cTiVo
//
//  Created by Hugh Mackworth on 1/3/13.
//  Copyright (c) 2013 Scott Buchanan. All rights reserved.
//

#import "MTiTiVoImport.h"
#import "NSString+RFC3339Date.h"

@implementation MTiTiVoImport

#define kITTiVo @"TiVo"                             // Example: "Bedroom Tivo";
#define kITMAK @"MAK"                               // Example: 1234567890;
#define kITDL @"DL"                                 // Example: "/Users/joe/Dropbox/Tivoshows/";

#define kITSubsciptionList @"targetDataSList"       // Array of subscription Dicts
#define kITSubscriptionDate  @"LastDLVal"               //Example:
#define kITSubscriptionSeries  @"ShowVal"               //Example:
#define kITiTunes @"iTunes"                         // Example: 0;
#define kITiTivoFormat @"format"                    // Example: AppleTV;
#define kITDownloadFirst @"downloadFirst"           // Example: NO;


//From iTivo; imported, but not currently implemented

#define kITMakeSubdirs @"makeSubdirs"               // Example: NO;   whether to make subdirectories for each series
#define kITShowCopyProtected @"showCopyProtected"   // Example: YES;  whether to display uncopyable shows
#define kITdownloadRetries @"downloadRetries"       // Example: 3;

#define kITComSkip @"comSkip"                       // Example: 0;    whether to run comSkip program after conversion
#define kITtivoMetaData @"tivoMetaData"             // Example: NO;   whether to export XML metadata
#define kITsubtitles @"subtitles"                   // Example: 0;    whether to export subtitles with tsAmi
#define kITTxtMetaData @"txtMetaData"               // Example: NO;   whether to export text metadata for PyTivo
#define kITAPMetaData @"APMetaData"                 // Example: NO;   Whether to export metadata with Atomic Parsley

#define kITuseTime @"useTime"                       // Example: NO;
#define kITuseTimeStartTime @"useTimeStartTime"     // Example: "2009-02-10T06:00:00Z";
#define kITuseTimeEndTime @"useTimeEndTime"         // Example: "2009-02-10T11:00:00Z";
#define kITSchedulingSleep @"schedulingSleep"       // Example: NO;   whether to sleep after scheduled downloads

#define kITiTunesIcon @"iTunesIcon"                 // Example: "Video frame";
#define kITiTunesSync @"iTunesSync"                 // Example: false;  whether to sync after download

#define kITPostDownloadCmd @"postDownloadCmd"       // Example: "# mv \"$file\" ~/.Trash ;;used for Tivo only";

/*
 #define kITEncoderUsed @"encoderUsed"               // Example: mencoder;
 #define kITFilenameExtension @"filenameExtension"   // Example: ".mp4";
 #define kITEncoderAudioOptions @"encoderAudioOptions" // Example: "-channels 2 -oac faac -faacopts mpeg=4:object=2:raw:br=128";
 #define kITencoderVideoOptions @"encoderVideoOptions" // Example: "-of lavf -ofps 30 -lavfopts format=mp4 -ovc x264 -x264encopts nocabac:level_idc=30:bitrate=2000:threads=auto:bframes=0:global_header -vf pp=lb,dsize=960:540:0,scale=-8:-8,harddup";
 #define kITEncoderOtherOptions @"encoderOtherOptions" // Example: "-hr-edl-seek";
 

 //iTivo not imported:
 #define kITOpenDetail @"openDetail"                 // Example: 2;
 
 #define kITDLHistory @"DLHistory"                   // Example: (	"MLB Baseball-5278871", );
 #define kITshouldAutoConnect @"shouldAutoConnect"   // Example: YES;

 #define kITtargetDataQueue @"targetDataQueue"       // Array of Queue Dicts
 #define kITQueueShowVal @"ShowVal"                      // Example: "The Daily Show With Jon Stewart";
 #define kITQueueIDVal @"IDVal"                          // Example: 5610947;
 #define kITQueueSizeVal @"SizeVal"                      // Example: "2960 MB";
 #define kITQueueLengthVal @"LengthVal"                  // Example: "0:31";
 #define kITQueueDateVal @"DateVal"                      // Example: "2012-12-12 23:00";
 #define kITQueueEpisodeVal @"EpisodeVal"                // Example: "Mayor Cory Booker";

 #define kITWebKitStandardFont @"WebKitStandardFont" // Example: "Lucida Grande";
 #define kITIPA @"IPA"                               // Example: "10.0.0.32";
 #define kITTivoSize @"tivoSize"                     // Example: 225;

 #define kITSUAutomaticallyUpdate" @"SUAutomaticallyUpdate" // Example: YES;
 #define kITSUHasLaunchedBefore @"SUHasLaunchedBefore"           // Example: YES;
 #define kITSUEnableAutomaticChecks @"SUEnableAutomaticChecks" // Example: YES;
 #define kITSUSendProfileInfo @"SUSendProfileInfo"   // Example: NO;

 #define kITDebugLog @"debugLog"                     // Example: NO;
 #define kITLaunchCount @"LaunchCount"               // Example: 18;
 
*/

+(NSDate *) testDate: (id) inDate {

    if ([inDate isKindOfClass:[NSDate class]]) {
        return inDate;
    } else if ([inDate isKindOfClass:[NSString class]]) {
        return [((NSString *)inDate) dateForRFC3339DateTimeString ];
    } else {
        return [NSDate date];
    }
}

+(void) checkForiTiVoPrefs {
    NSUserDefaults * sUD = [NSUserDefaults standardUserDefaults];
    if (![sUD objectForKey:kMTSelectedFormat]){
        [sUD addSuiteNamed:@"com.iTivo.iTivo"];
        if ([sUD objectForKey:kITTiVo]) {
           
           
            //Current TiVo
            NSString * currentTivo = [sUD objectForKey:kITTiVo];
            if (currentTivo.length> 0) {
                [sUD setValue: currentTivo forKey:kMTSelectedTiVo];
                
                //Current MAK  (No place to put MAK if no Tivo
                NSString * MAK = [sUD objectForKey:kITMAK];
                if (MAK.length > 0 && [currentTivo compare:@"My Tivos"] != NSOrderedSame) {
                    NSDictionary * MAKs = [sUD objectForKey:kMTMediaKeys];
                    if (MAKs) {
                        NSMutableDictionary * newMAKs = [NSMutableDictionary  dictionaryWithDictionary:MAKs];
						[newMAKs  setValue:MAK forKey:currentTivo];
						MAKs = [NSDictionary dictionaryWithDictionary:newMAKs];
                    } else {
                        MAKs = [NSDictionary dictionaryWithObject:MAK  forKey:currentTivo];
                    }
                    [sUD setValue:MAKs forKey:kMTMediaKeys];
                }
            }
            //iTunes preference
            BOOL iTunes = [sUD boolForKey:kITiTunes];
            [sUD setBool:   iTunes forKey:kMTiTunesSubmit ];
            
            //Simultaneous encode
            BOOL simulEncode = ![sUD boolForKey:kITDownloadFirst];
            [sUD setBool: simulEncode forKey:kMTSimultaneousEncode ];
            
            //download directory
            NSString * downloadDir = [sUD objectForKey:kITDL];
			[sUD setValue: downloadDir  forKey:kMTDownloadDirectory];  //will validate when loaded again
 
            //preferred format
            NSString * format = [sUD objectForKey:kITiTivoFormat];
            if (format.length > 0) {
                [sUD setValue:format       forKey:kMTSelectedFormat];
            } else{
                format =@"iPhone";  //just for the heck of it
            }
             
            //Subscriptions
            NSArray * iTivoSubscriptions = [sUD objectForKey:@"targetDataSList"];
            NSMutableArray * cTivoSubs = [[NSMutableArray alloc] initWithCapacity:iTivoSubscriptions.count];
            for (NSDictionary * sub in iTivoSubscriptions) {
                NSDate * date= [self testDate:[sub objectForKey:@"LastDLVal"]];
                NSString * seriesName = [sub objectForKey:@"ShowVal"];
                
                if (seriesName && date) {
                    [cTivoSubs addObject:[NSDictionary  dictionaryWithObjectsAndKeys:
                                          seriesName,kMTSubscribedSeries,
                                          date, kMTCreatedDate,
                                          format, kMTSubscribedFormat,
                                          [NSNumber numberWithBool: iTunes ],kMTSubscribediTunes,
//                                           [NSNumber numberWithBool: simulEncode ],kMTSimultaneousEncode,
                                          nil]
                     ];
                }
            }
            if (cTivoSubs.count > 0)[sUD setValue:cTivoSubs forKey:kMTSubscriptionList];
 
            // whether to make subdirectories for each series
            [sUD setBool:   [sUD boolForKey:kITMakeSubdirs]         forKey:kMTMakeSubDirs ];

            // whether to display uncopyable shows
            [sUD setObject: [NSNumber numberWithBool:[sUD boolForKey:kITShowCopyProtected]]   forKey:kMTShowCopyProtected ];
            
            // How many retries during download failures
            [sUD setInteger: [sUD integerForKey:kITdownloadRetries]  forKey:kMTNumDownloadRetries ];
            
            // Whether to run comSkip program after conversion
            [sUD setBool:   0 != [sUD integerForKey:kITComSkip]     forKey:kMTRunComSkip ];
            
            
            // Whether to export subtitles with ts2ami
            [sUD setBool:   0 != [sUD boolForKey:kITsubtitles]      forKey:kMTExportSubtitles ];
            
            // Whether to export text metadata for PyTivo
            [sUD setBool:   [sUD boolForKey:kITTxtMetaData]         forKey:kMTExportTextMetaData ];

#ifndef deleteXML
			// Whether to export XML metadata
            [sUD setBool:   [sUD boolForKey:kITtivoMetaData]        forKey:kMTExportTivoMetaData ];
           
            // Whether to export metadata with Atomic Parsley
            [sUD setBool:   [sUD boolForKey:kITAPMetaData]          forKey:kMTExportMetaData ];
#endif            
            //---------------
            // Whether to run queue at a scheduled time;
            [sUD setBool:   [sUD boolForKey:kITuseTime]             forKey:kMTScheduledOperations ];
            
            // When to start queue   Example: "2009-02-10T06:00:00Z";
            
            NSDate * startDate = [self testDate:[sUD objectForKey:kITuseTimeStartTime]];
            if (startDate)[sUD setValue:  startDate forKey:kMTScheduledStartTime ];
                        
            // When to end queue  Example: "2009-02-10T11:00:00Z";
            NSDate * endDate = [self testDate:[sUD objectForKey:kITuseTimeEndTime]];
            if (endDate)[sUD setValue:  endDate forKey:kMTScheduledEndTime ];
        

            // Whether to start queue to sleep after scheduled downloads
            [sUD setBool:   [sUD boolForKey:kITSchedulingSleep]     forKey:kMTScheduledSleep ];
            
            
            // Whether to use video frame (versus cTivo logo) for iTUnes icon  Example: "Video frame";
            [sUD setBool:   [@"Video frame" compare:[sUD objectForKey:kITiTunesIcon]] ==NSOrderedSame
                                             forKey:kMTiTunesIcon ];
            
            // Whether to sync iDevices after iTunes submital
            [sUD setBool:   [sUD boolForKey:kITiTunesSync]          forKey:kMTiTunesSync ];
            
            
            // Example: "# mv \"$file\" ~/.Trash ;;used for Tivo only";
            NSString * postDownload =[sUD objectForKey:kITPostDownloadCmd];
            if (postDownload.length > 0)[sUD setValue: [sUD objectForKey:kITPostDownloadCmd]   forKey:kMTPostDownloadCommand ];

        }
        //And we're done...
        [sUD removeSuiteNamed:@"com.iTivo.iTivo"];
    }
}


@end
