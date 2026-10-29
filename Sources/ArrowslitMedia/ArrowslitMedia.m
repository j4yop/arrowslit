#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <math.h>
#include <unistd.h>
#include "ArrowslitMedia.h"

typedef void (*ARRegister)(dispatch_queue_t);
typedef void (*ARInfo)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*ARPlaying)(dispatch_queue_t, void (^)(Boolean));
typedef void (*ARPeerPID)(dispatch_queue_t, void (^)(int));
typedef void (*ARClient)(dispatch_queue_t, void (^)(id));
typedef Boolean (*ARSend)(int, NSDictionary *);
typedef void (*ARSeek)(double);

static ARRegister arRegister;
static ARInfo arInfo;
static ARPlaying arPlaying;
static ARPeerPID arPeerPID;
static ARClient arClient;
static ARSend arSend;
static ARSeek arSeek;

static dispatch_queue_t mediaQueue;
static NSString *lastPayloadSignature;
static NSString *lastArtworkSignature;
static BOOL refreshPending;
static const NSUInteger maxArtworkBytes = 4 * 1024 * 1024;
static const NSUInteger maxTextLength = 4096;
static const NSUInteger maxCommandBytes = 4096;

static void emit(NSDictionary *payload) {
    if (![NSJSONSerialization isValidJSONObject:payload]) {
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (data == nil) {
        return;
    }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static NSString *text(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return @"";
    }
    NSString *string = value;
    return string.length > maxTextLength ? [string substringToIndex:maxTextLength] : string;
}

static NSNumber *finite(id value) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    double number = [value doubleValue];
    return isfinite(number) ? value : nil;
}

static NSString *clientIdentifier(id client) {
    if (client == nil) {
        return nil;
    }
    for (NSString *key in @[@"parentApplicationBundleIdentifier", @"bundleIdentifier"]) {
        SEL selector = NSSelectorFromString(key);
        if ([client respondsToSelector:selector]) {
            id value = [client valueForKey:key];
            if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
                return text(value);
            }
        }
    }
    return nil;
}

static void publish(NSDictionary *info, BOOL playing, int pid, NSString *bundleID) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"type"] = @"track";
    payload[@"hasInfo"] = info.count > 0 ? @YES : @NO;
    payload[@"playing"] = @(playing);
    payload[@"pid"] = @(pid);
    if (bundleID.length > 0) {
        payload[@"bundleID"] = bundleID;
    }
    payload[@"title"] = text(info[@"kMRMediaRemoteNowPlayingInfoTitle"]);
    payload[@"artist"] = text(info[@"kMRMediaRemoteNowPlayingInfoArtist"]);
    payload[@"album"] = text(info[@"kMRMediaRemoteNowPlayingInfoAlbum"]);

    NSNumber *duration = finite(info[@"kMRMediaRemoteNowPlayingInfoDuration"]);
    NSNumber *elapsed = finite(info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"]);
    NSNumber *rate = finite(info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"]);
    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    if (duration != nil) payload[@"duration"] = duration;
    if (elapsed != nil) payload[@"elapsed"] = elapsed;
    if (rate != nil) payload[@"rate"] = rate;
    if ([timestamp isKindOfClass:[NSDate class]] && isfinite(timestamp.timeIntervalSince1970)) {
        payload[@"timestamp"] = @(timestamp.timeIntervalSince1970);
    }

    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    NSString *artworkKey = nil;
    if ([artwork isKindOfClass:[NSData class]] && artwork.length > 0 && artwork.length <= maxArtworkBytes) {
        id identifier = info[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"];
        artworkKey = [identifier isKindOfClass:[NSString class]]
            ? text(identifier)
            : [NSString stringWithFormat:@"%lu-%lu", (unsigned long)artwork.length, (unsigned long)artwork.hash];
        payload[@"artworkKey"] = artworkKey;
    }

    NSData *signatureData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingSortedKeys error:nil];
    NSString *signature = [[NSString alloc] initWithData:signatureData encoding:NSUTF8StringEncoding];
    if (signature != nil && [signature isEqualToString:lastPayloadSignature]) {
        return;
    }
    lastPayloadSignature = signature;

    if (artworkKey == nil) {
        lastArtworkSignature = nil;
    } else if (![artworkKey isEqualToString:lastArtworkSignature]) {
        payload[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
        lastArtworkSignature = artworkKey;
    }
    emit(payload);
}

static void refreshNow(void) {
    __block NSDictionary *info = nil;
    __block Boolean playing = false;
    __block int pid = 0;
    __block NSString *bundleID = nil;
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t callbackQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

    dispatch_group_enter(group);
    arInfo(callbackQueue, ^(NSDictionary *value) {
        info = value;
        dispatch_group_leave(group);
    });
    if (arPlaying != NULL) {
        dispatch_group_enter(group);
        arPlaying(callbackQueue, ^(Boolean value) {
            playing = value;
            dispatch_group_leave(group);
        });
    }
    if (arPeerPID != NULL) {
        dispatch_group_enter(group);
        arPeerPID(callbackQueue, ^(int value) {
            pid = value;
            dispatch_group_leave(group);
        });
    }
    if (arClient != NULL) {
        dispatch_group_enter(group);
        arClient(callbackQueue, ^(id value) {
            bundleID = clientIdentifier(value);
            dispatch_group_leave(group);
        });
    }

    dispatch_async(mediaQueue, ^{
        dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
        NSNumber *rate = finite(info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"]);
        BOOL isPlaying = playing || (rate != nil && rate.doubleValue > 0);
        publish(info ?: @{}, isPlaying, pid, bundleID);
    });
}

static void scheduleRefresh(void) {
    dispatch_async(mediaQueue, ^{
        if (refreshPending) {
            return;
        }
        refreshPending = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_MSEC), mediaQueue, ^{
            refreshPending = NO;
            refreshNow();
        });
    });
}

static void handleCommand(NSString *line) {
    NSString *command = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (command.length == 0) {
        return;
    }
    NSArray<NSString *> *parts = [command componentsSeparatedByString:@" "];
    NSString *verb = parts.firstObject;

    if ([verb isEqualToString:@"refresh"]) {
        lastPayloadSignature = nil;
        lastArtworkSignature = nil;
        scheduleRefresh();
        return;
    }
    if ([verb isEqualToString:@"seek"] && parts.count > 1 && arSeek != NULL) {
        double target = parts[1].doubleValue;
        if (!isfinite(target) || target < 0) {
            return;
        }
        arSeek(target);
        scheduleRefresh();
        return;
    }
    if (arSend == NULL) {
        return;
    }
    NSDictionary<NSString *, NSNumber *> *commands = @{
        @"play": @0,
        @"pause": @1,
        @"toggle": @2,
        @"next": @4,
        @"previous": @5,
    };
    NSNumber *value = commands[verb];
    if (value != nil) {
        arSend(value.intValue, nil);
        scheduleRefresh();
    }
}

static void startCommandReader(void) {
    static NSMutableData *pending;
    pending = [NSMutableData data];
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, mediaQueue);
    dispatch_source_set_event_handler(source, ^{
        char buffer[1024];
        ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
        if (count <= 0) {
            exit(0);
        }
        [pending appendBytes:buffer length:(NSUInteger)count];
        if (pending.length > maxCommandBytes) {
            [pending setLength:0];
            return;
        }
        while (YES) {
            NSRange newline = [pending rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, pending.length)];
            if (newline.location == NSNotFound) {
                break;
            }
            NSData *lineData = [pending subdataWithRange:NSMakeRange(0, newline.location)];
            [pending replaceBytesInRange:NSMakeRange(0, newline.location + 1) withBytes:NULL length:0];
            NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
            if (line != nil) {
                handleCommand(line);
            }
        }
    });
    dispatch_resume(source);
    static dispatch_source_t retained;
    retained = source;
}

static NSString *notificationName(void *framework, const char *symbol) {
    NSString *__unsafe_unretained *pointer = (NSString *__unsafe_unretained *)dlsym(framework, symbol);
    return (pointer != NULL && *pointer != nil) ? *pointer : @(symbol);
}

void arrowslit_media_stream(void *interpreter, void *cv) {
    (void)interpreter;
    (void)cv;
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOFBF, 1 << 16);
        void *framework = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
        if (framework == NULL) {
            emit(@{@"type": @"error", @"message": @"MediaRemote unavailable"});
            exit(1);
        }
        arRegister = (ARRegister)dlsym(framework, "MRMediaRemoteRegisterForNowPlayingNotifications");
        arInfo = (ARInfo)dlsym(framework, "MRMediaRemoteGetNowPlayingInfo");
        arPlaying = (ARPlaying)dlsym(framework, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
        arPeerPID = (ARPeerPID)dlsym(framework, "MRMediaRemoteGetNowPlayingApplicationPID");
        arClient = (ARClient)dlsym(framework, "MRMediaRemoteGetNowPlayingClient");
        arSend = (ARSend)dlsym(framework, "MRMediaRemoteSendCommand");
        arSeek = (ARSeek)dlsym(framework, "MRMediaRemoteSetElapsedTime");
        if (arInfo == NULL || arRegister == NULL) {
            emit(@{@"type": @"error", @"message": @"MediaRemote symbols missing"});
            exit(1);
        }

        mediaQueue = dispatch_queue_create("com.j4yop.arrowslit.media", DISPATCH_QUEUE_SERIAL);
        arRegister(mediaQueue);

        const char *names[] = {
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationClientStateDidChange",
            "kMRMediaRemotePlaybackStateDidChangeNotification",
        };
        for (size_t index = 0; index < sizeof(names) / sizeof(names[0]); index++) {
            [NSNotificationCenter.defaultCenter addObserverForName:notificationName(framework, names[index])
                                                            object:nil
                                                             queue:nil
                                                        usingBlock:^(NSNotification *note) {
                (void)note;
                scheduleRefresh();
            }];
        }

        startCommandReader();
        emit(@{@"type": @"ready"});
        scheduleRefresh();

        dispatch_source_t poll = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, mediaQueue);
        dispatch_source_set_timer(poll, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), 5 * NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(poll, ^{
            refreshNow();
        });
        dispatch_resume(poll);
        static dispatch_source_t retainedPoll;
        retainedPoll = poll;
    }
    CFRunLoopRun();
    exit(0);
}
