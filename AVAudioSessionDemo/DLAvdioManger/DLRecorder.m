//
//  DLRecorder.m
//  AVAudioSessionDemo
//
//  Created by 武得亮 on 2018/10/12.
//  Copyright © 2018年 武得亮. All rights reserved.
//

#import "DLRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


static DLRecorder *_dlrecoreder;

@interface DLRecorder()<AVAudioRecorderDelegate>
{
    AVAudioRecorder *audioRecorder;
    NSURL *tempRecordFileURL;
    NSURL *currentRecordFileURL;
    
    dispatch_source_t  timer;
    NSString *_relativelyPath;
}
/**
 是否正在录音
 */
@property(nonatomic,assign) BOOL isRecording;
@end


@implementation DLRecorder
+(instancetype)shareRecorderManger
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        if (!_dlrecoreder) {
            _dlrecoreder = [self new];
            [_dlrecoreder dl_setupAudioRecorder];
        }
    });
    return _dlrecoreder;
    
    
}

+(instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_dlrecoreder) {
            _dlrecoreder = [super allocWithZone:zone];
        }
    });
    return _dlrecoreder;
}


//录音设置采样率 音频格式，采样位数，默认16  通道数目
-(void)dl_setupAudioRecorder
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *recordFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"records"];
    if (![fileManager fileExistsAtPath:recordFilePath]) {
        [fileManager createDirectoryAtPath:recordFilePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *recordFile = [recordFilePath stringByAppendingPathComponent:@"rec.AAC"];
    tempRecordFileURL = [NSURL URLWithString:recordFile];
    
    NSDictionary *recordSetting = @{ AVSampleRateKey        : @8000.0,                      // 采样率
                                     AVFormatIDKey          : @(kAudioFormatLinearPCM),     // 音频格式
                                     AVLinearPCMBitDepthKey : @16,                          // 采样位数 默认 16
                                     AVNumberOfChannelsKey  : @1                            // 通道的数目
                                     };
    // AVLinearPCMIsBigEndianKey    大端还是小端 是内存的组织方式
    // AVLinearPCMIsFloatKey        采样信号是整数还是浮点数
    //     AVEncoderAudioQualityKey     音频编码质量
    
    audioRecorder = [[AVAudioRecorder alloc] initWithURL:tempRecordFileURL
                                                settings:recordSetting
                                                   error:nil];
    audioRecorder.delegate = self;
    audioRecorder.meteringEnabled = YES;

}


/*
 开始录音
 path: 录音保存的路径
 */
-(void)dlrecordWithURL:(NSURL *)fileUrl saveRelativelyPath:(NSString *)path
{
    _isRecording = [audioRecorder isRecording];
    if ([audioRecorder isRecording]) {
        return;
    }
    _relativelyPath  = path;
    [self dl_prepareRecordFileUrl:fileUrl];
    [audioRecorder prepareToRecord];
    //开始录音
    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [[AVAudioSession sharedInstance]setActive:YES error:nil];
#pragma mark 加大声音
    UInt32 dlaudioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(dlaudioRouteOverride), &dlaudioRouteOverride);
    [audioRecorder record];
    self.isRecording = YES;
    [self dl_createPickSpeakPowerTimer];
}


-(NSString *)getRelativelyPath{
    if (self.isRecording) {
        return _relativelyPath;
    }
    return nil;
}


/**
    保证路径下没有相同文件存在
 */
-(void)dl_prepareRecordFileUrl:(NSURL *)fileUrl
{
    currentRecordFileURL = fileUrl;
    NSString *wavFileUrlString = [fileUrl.absoluteString stringByAppendingString:@".AAC"];
#pragma mark - 如果有删除.AAC文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //判断路径是否包含要存储的路径
    if ([fileManager fileExistsAtPath:wavFileUrlString]) {
        [fileManager removeItemAtPath:wavFileUrlString error:nil];
    }
    NSString *recordFilePath = [NSTemporaryDirectory()stringByAppendingString:@"records"];
    NSString *recordFile = [recordFilePath stringByAppendingPathComponent:@"rec.AAC"];
    if ([fileManager fileExistsAtPath:recordFile]) {
        if ([fileManager removeItemAtPath:recordFile error:nil]) {
            NSLog(@"删除成功");
        }
    }
}

/***
 *  目标路径文件所有文件数组
 *  @param pathArray 路径数组
 *  @param fileffix  过滤后缀路径
 */
-(NSMutableArray *)recordcomparefile:(NSArray *)pathArray filesuffix:(NSString *)fileffix{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    //数组
    NSMutableArray *allaudioPathAry = [[NSMutableArray alloc]init];
    NSArray *paths = pathArray;
    NSString *rootPath = [paths objectAtIndex:0];/*获取根目录*/
    NSArray *pathsArr = [fileMgr subpathsAtPath:rootPath];/*取得文件列表*/
    NSArray *sortedPaths = [pathsArr sortedArrayUsingComparator:^(NSString * firstPath, NSString* secondPath) {
        NSString *firstUrl = [rootPath stringByAppendingPathComponent:firstPath];/*获取前一个文件完整路径*/
        NSString *secondUrl = [rootPath stringByAppendingPathComponent:secondPath];/*获取后一个文件完整路径*/
        NSDictionary *firstFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:firstUrl error:nil];/*获取前一个文件信息*/
        NSDictionary *secondFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:secondUrl error:nil];/*获取后一个文件信息*/
        id firstData = [firstFileInfo objectForKey:NSFileCreationDate];/*获取前一个文件创建时间*/
        id secondData = [secondFileInfo objectForKey:NSFileCreationDate];/*获取后一个文件创建时间*/
        return [firstData compare:secondData];//升序
        // return [secondData compare:firstData];//降序
    }];
    for (int i = 0;  i < sortedPaths.count; i++ ) {
        if ([[sortedPaths objectAtIndex:i] hasSuffix:fileffix]) {
            // 文件路径
            NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[sortedPaths objectAtIndex:i]];
            NSURL *fileURL = [NSURL fileURLWithPath:filePath];
            NSLog(@"输出数据 == %@",fileURL);
            [allaudioPathAry addObject:fileURL];
        }
    }
    NSLog(@"是否是  升序  ---%@ ",allaudioPathAry);
    return allaudioPathAry;
    
    
    
}



/** 合成音频文件 
 *  @param sourceURLs  需要合并的多个音频文件
 *  @param toURL       合并后音频文件的存放地址
 */
-(void)dlsyntheticPath:(NSArray *)sourceURLs composeToURL:(NSString *)toURL completed:(void (^)(NSError *error))completed
{
        //  合并所有的录音文件
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
        //  音频插入的开始时间
    CMTime beginTime = kCMTimeZero;
        //  获取音频合并音轨
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        //  用于记录错误的对象
    NSError *error = nil;
    for (NSURL *sourceURL in sourceURLs) {
        //  音频文件资源
        AVURLAsset  *audioAsset = [[AVURLAsset alloc]initWithURL:sourceURL options:nil];
        //  需要合并的音频文件的区间
        CMTimeRange audio_timeRange = CMTimeRangeMake(kCMTimeZero, audioAsset.duration);
        //  参数说明:
        //  insertTimeRange:源录音文件的的区间
        //  ofTrack:插入音频的内容
        //  atTime:源音频插入到目标文件开始时间
        //  error: 插入失败记录错误
        //  返回:YES表示插入成功,`NO`表示插入失败
        BOOL success = [compositionAudioTrack insertTimeRange:audio_timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:beginTime error:&error];
        //  如果插入失败,打印插入失败信息
        if (!success) {
            NSLog(@"插入音频失败: %@",error);
        }
        //  记录开始时间
        beginTime = CMTimeAdd(beginTime, audioAsset.duration);
    }
        //  创建一个导入M4A格式的音频的导出对象
    AVAssetExportSession* assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetAppleM4A];
    //  文档路径
    NSString *transitPath = [NSSearchPathForDirectoriesInDomains (NSDocumentDirectory , NSUserDomainMask , YES ).firstObject stringByAppendingPathComponent:@"shenmikeaudio.m4a"];
    //  如果目标文件已经存在删除目标文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:transitPath]) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:transitPath error:&error];
        if (!success) {
            NSLog(@"删除文件失败:%@",error);
        }else{
            NSLog(@"删除文件:%@成功",transitPath);
        }
    }
        //  导入音视频的URL
    assetExport.outputURL = [NSURL fileURLWithPath:transitPath];
        //  导出音视频的文件格式
    assetExport.outputFileType = @"com.apple.m4a-audio";
        //  导入出
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
        //  分发到主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            // 文件管理者
            NSFileManager * manager = [NSFileManager defaultManager];
            if ([manager moveItemAtPath:transitPath toPath:toURL error:nil]) {
                NSLog(@"移动成功");
            }else{
                NSLog(@"移动失败");
            }
            completed(assetExport.error);
            
        });
    }];
 
}
#pragma mark 转换MP3
- (void)dlAudioM4AFile:(NSString *)m4aFileName toMp3File:(NSString *)mp3FileName {
    NSLog(@"开始转换");
    
    NSURL*originalUrl = [NSURL fileURLWithPath:m4aFileName];
    NSURL*outPutUrl = [NSURL fileURLWithPath:mp3FileName];
    AVURLAsset*songAsset = [AVURLAsset URLAssetWithURL:originalUrl options:nil];//读取原始文件信息
    NSError*error =nil;
    AVAssetReader*assetReader = [AVAssetReader assetReaderWithAsset:songAsset error:&error];
    if(error) {
        NSLog(@"error: %@", error);
        return;
    }
    AVAssetReaderOutput *assetReaderOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:songAsset.tracks audioSettings:nil];
    if(![assetReader canAddOutput:assetReaderOutput]) {
        NSLog(@"can't add reader output... die!");
        return;
    }
    [assetReader addOutput:assetReaderOutput];

    AVAssetWriter*assetWriter = [AVAssetWriter assetWriterWithURL:outPutUrl fileType:AVFileTypeCoreAudioFormat error:&error];

    if(error) {

        NSLog(@"error: %@", error);

        return;

    }

    AudioChannelLayout channelLayout;

    memset(&channelLayout,0,sizeof(AudioChannelLayout));

    channelLayout.mChannelLayoutTag=kAudioChannelLayoutTag_Stereo;

    NSDictionary*outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,[NSNumber numberWithFloat:44100.0],AVSampleRateKey,[NSNumber numberWithInt:2],AVNumberOfChannelsKey,[NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)],AVChannelLayoutKey,[NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,[NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,[NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,[NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,nil];

    AVAssetWriterInput*assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];

    if([assetWriter canAddInput:assetWriterInput]) {

        [assetWriter addInput:assetWriterInput];

    }else{

        NSLog(@"can't add asset writer input... die!");

        return;

    }

    assetWriterInput.expectsMediaDataInRealTime=NO;

    [assetWriter startWriting];

    [assetReader startReading];

    AVAssetTrack*soundTrack = [songAsset.tracks objectAtIndex:0];

    CMTime startTime =CMTimeMake(0, soundTrack.naturalTimeScale);

    [assetWriter startSessionAtSourceTime:startTime];

    __block UInt64 convertedByteCount =0;

    dispatch_queue_t mediaInputQueue =dispatch_queue_create("mediaInputQueue",NULL);

    [assetWriterInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock: ^{

        while(assetWriterInput.readyForMoreMediaData) {

            CMSampleBufferRef nextBuffer = [assetReaderOutput copyNextSampleBuffer];

            if(nextBuffer) {
                // append buffer
                [assetWriterInput appendSampleBuffer: nextBuffer];

                convertedByteCount +=CMSampleBufferGetTotalSampleSize(nextBuffer);

            }else{

                [assetWriterInput markAsFinished];

                [assetWriter finishWritingWithCompletionHandler:^{

                }];

                [assetReader cancelReading];

                NSDictionary*outputFileAttributes = [[NSFileManager  defaultManager]attributesOfItemAtPath:[outPutUrl path]error:nil];

                NSLog(@"FlyElephant %lld",[outputFileAttributes fileSize]);
                break;
            }

        }
        
    }];
 
}


/** 目标文件路径，返回该路径所有音频文件路径集合
 *  @param destination  目标路径
 *  @param dlType       目标路径下所需文件类型
 */
-(NSArray *)dldestinationFolder:(NSString *)destination recordType:(NSString*)dlType{
    
        //  文件路径
    NSArray *fileNames = [[NSFileManager defaultManager] subpathsAtPath:destination];
        //  获取文档目录保存所有 .AAC 格式的音频文件URL
    NSMutableArray *sourceURLs = [NSMutableArray array];
    
        //  遍历
    for (NSString *fileName in fileNames) {
        NSLog(@"源文件:%@",fileName);
        if (![fileName.pathExtension isEqualToString:dlType]) {
            continue;
        }
        //  文件路径
        NSString *filePath = [destination stringByAppendingPathComponent:fileName];
        //  文件的URL
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        //  源文件数组
        [sourceURLs addObject:fileURL];
    }
    return sourceURLs;
    
}


//录音时间
-(void)dl_createPickSpeakPowerTimer{
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.01*NSEC_PER_SEC, 1ull*NSEC_PER_SEC);
        //  每0.01秒触发一次，误差在纳秒
    __weak __typeof(self)weakSelf = self;
    
    dispatch_source_set_event_handler(timer, ^{
        __strong __typeof(weakSelf) _self = weakSelf;
        if ([_self.delegate respondsToSelector:@selector(dlrecorder:didPickSpeakPower:andTime:)]) {
            [_self->audioRecorder updateMeters];
            double currentTime = _self -> audioRecorder.currentTime;
            
            double lowPassResults = pow(10, (0.05 *[_self->audioRecorder peakPowerForChannel:0]));
            [_self.delegate dlrecorder:_self didPickSpeakPower:lowPassResults andTime:currentTime];
        }
    });
    dispatch_resume(timer);
}

/**
 暂停录音
 */
-(void)dlpause
{
    if ([audioRecorder isRecording]) {
        [audioRecorder pause];
    }
}

/**
 继续录音
 */
-(void)dlContinueRecord
{
    if ([audioRecorder isRecording]) {
        [audioRecorder record];
    }
    
}

/**
 暂停录音
 */
-(void)dlstop{
    
    if (!_isRecording) {
        return;
    }
    [audioRecorder stop];
    if (timer) {
        dispatch_source_cancel(timer);
        timer = NULL;
    }
    self.isRecording = NO;
}

/**
 使用免提，还是耳机线进行录制
 @param speakMode 是否使用免提录制
 */
-(void)dlspeakMode:(BOOL)speakMode
{
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 6.0) {
        AVAudioSessionPortOverride portOVerride = speakMode ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone;
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:portOVerride error:nil];

    }else{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UInt32 route = speakMode ? kAudioSessionOverrideAudioRoute_Speaker : kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(route), &route);
#pragma clang diagnostic pop
        
    }
}


//-----------------------------------------------------------------------------------------
#pragma mark - AVAudioRecorderDelegate
//-----------------------------------------------------------------------------------------

@end

@implementation DLAmrFileInfo
@end









