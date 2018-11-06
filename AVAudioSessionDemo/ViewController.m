//
//  ViewController.m
//  AVAudioSessionDemo
//
//  Created by 武得亮 on 2018/10/11.
//  Copyright © 2018年 武得亮. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

#import "DLRecorder.h"


#define AUDIO_FOBIDDENDELETED_USER_PATH NSSearchPathForDirectoriesInDomains (NSDocumentDirectory , NSUserDomainMask , YES ).firstObject


//合并存储路径
#define DlMERGEAUDIO_PATH NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject


/**
 * 不要使用中文命名、转换amr识别不了
 */
static  NSString    *const kfileName = @"dlnewRecord";


@interface ViewController ()<DLAmrRecorderDelegate>
{
    DLRecorder *dlrecorder;
    NSString *fileAppendUrl;   //相对路径
    
}

@property (nonatomic,copy)  NSString *filesign;
//录音按钮
@property (weak, nonatomic) IBOutlet UIButton *dlstartAStopRecordBtn;
//录音时间
@property (weak, nonatomic) IBOutlet UILabel *recordTime;
//文件大小
@property (weak, nonatomic) IBOutlet UILabel *hiddenfileSizeLab;

@property (weak, nonatomic) IBOutlet UILabel *dlrecordPath;
@property (weak, nonatomic) IBOutlet UILabel *dlrecordbeginTime;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self initViewData];
    
    

}


-(void)initViewData{
    
    dlrecorder = [DLRecorder shareRecorderManger];
    dlrecorder.delegate = self;
    NSString * localPath = [dlrecorder getRelativelyPath];
    if (localPath.length > 0) {
        fileAppendUrl = localPath;
    }else{
        NSString *currentSign = [self returnCurentDataIntoSecond];
        self.filesign = currentSign;
    }
}



//开始录音
- (IBAction)beginRecord:(id)sender {
    
    self.dlstartAStopRecordBtn.selected = !self.dlstartAStopRecordBtn.selected;
    
    if (dlrecorder.dl_is_Recording != YES ) {
        //开始录音
        [self startRecord];
        
    }else{
//        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"正在录音" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
//        [alert show];
    }
}

- (IBAction)dlAudioFinishAction:(id)sender {
    
    [self audioFinished];
}

//获取到录音器的时间
- (void)dlrecorder:(DLRecorder *)aRecorder
didPickSpeakPower:(float)power andTime:(double)currentTime{
    
    NSString *currentTimeLabel= [NSString stringWithFormat: @"时间：%02d:%02d",
                                 (int) currentTime/60,(int) currentTime%60];
    self.dlrecordbeginTime.text  =currentTimeLabel;
}

//开始录音
-(void)startRecord{
    
    NSString *recordFile = [self dlrecordFilePath];
    [dlrecorder dlspeakMode:NO];
    [dlrecorder dlrecordWithURL:[NSURL URLWithString:recordFile] saveRelativelyPath:fileAppendUrl];
}

//结束录音
- (void)audioFinished{
    [dlrecorder dlstop];
}

//合成录音
- (IBAction)dlrecordMerge:(id)sender {
    
    //  文档路径
    NSString *destPath = [AUDIO_FOBIDDENDELETED_USER_PATH stringByAppendingPathComponent:@"aaaa.m4a"];
    //mp3 路径
    NSError *error = nil;
    //  如果目标文件已经存在删除目标文件
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:destPath error:&error];
        if (!success) {
            NSLog(@"删除文件失败:%@",error);
        }else{
            NSLog(@"删除文件:%@成功",destPath);
        }
    }
    [dlrecorder dlsyntheticPath:[dlrecorder recordcomparefile:NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) filesuffix:@"AAC"] composeToURL:destPath completed:^(NSError *error) {
        if (error) {
            NSLog(@"合并音频文件失败:%@",error);
        }else{
            NSLog(@"合并音频文件成功");
           
        }
    }];
}



/***
 *  中断处理
 */
- (void)dlrecorderHasBeInterpurt{
    __block __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        //回调或者说是通知主线程刷新，
        [weakSelf audioFinished];
    });
}


#pragma mark - PRNAmrRecorderDelegate
//录音结束后文件信息回传
- (void)dlrecorder:(DLRecorder *)dlRecorder didRecordWithFile:(DLAmrFileInfo *)fileInfo
{
    NSLog(@"=================================================== 123===============");
    NSLog(@"record with file : %@", fileInfo.fileUrl);
    NSLog(@"file size: %llu", fileInfo.fileSize);
    NSLog(@"file duration : %f", fileInfo.duration);
    NSLog(@"==================================================================");
    
    double size = (double)fileInfo.fileSize;
    NSInteger durationT = (NSInteger)fileInfo.duration;
    self.hiddenfileSizeLab.text = [self calculateSize:size];
    self.recordTime.text = [self calculateTime:durationT andRun:NO];
    self.dlrecordPath.text = [NSString stringWithFormat:@"%@", fileInfo.fileUrl];
    
    
}

/**
 *   计算时间
 */
- (NSString *)calculateTime:(NSInteger )countT andRun:(BOOL)isRun{
    NSString  *timeString ;
    NSInteger second  = (countT+1)%60;
    NSInteger mintiue = countT/60;
    if (isRun) {
        timeString = [NSString stringWithFormat:@"%02ld:%02ld",(long)mintiue,(long)second];
    }else{
        timeString = [NSString stringWithFormat:@"%02ld分%02ld秒",(long)mintiue,(long)second];
    }
    return timeString;
}

/**
 *   计算文件大小
 */
- (NSString *)calculateSize:(double)size{
    NSString *audiofileSize = @"0";
    if (size>1024.0*1024.0) {
        double Mb = size / 1024.0 /1024.0;
        audiofileSize = [NSString stringWithFormat:@"%.2fMB",Mb];
    }else{
        double kb = size / 1024.0;
        audiofileSize = [NSString stringWithFormat:@"%.0fKB",kb];
    }
    return audiofileSize;
}

/**
 文件保存路径
 */
-(NSString *)dlrecordFilePath
{
    
    self.filesign = [self returnCurentDataIntoSecond];
    NSString *fileAppend = [NSString stringWithFormat:@"%@%@.AAC",kfileName,_filesign];
    fileAppendUrl = fileAppend;
    NSString *recordFile = [AUDIO_FOBIDDENDELETED_USER_PATH stringByAppendingPathComponent:fileAppendUrl];
    NSLog(@"%@",recordFile);
    return recordFile;
}
/**
 *   获得系统日期的精确值
 */
- (NSString *)returnCurentDataIntoSecond{
    
    
    NSDate * senddate=[NSDate date];
    NSCalendar * cal=[NSCalendar currentCalendar];
    NSUInteger unitFlags=kCFCalendarUnitSecond|kCFCalendarUnitMinute|kCFCalendarUnitHour|kCFCalendarUnitDay|kCFCalendarUnitMonth|kCFCalendarUnitYear;
    NSDateComponents * conponent= [cal components:unitFlags fromDate:senddate];
    NSInteger year     =[conponent year];
    NSInteger month    =[conponent month];
    NSInteger day      =[conponent day];
    NSInteger hour     =[conponent hour];
    NSInteger minitues =[conponent minute];
    NSInteger second   =[conponent second];
    NSString * nstr= [NSString stringWithFormat:@"%4ld%2ld%2ld%2ld%2ld%2ld",(long)year,(long)month,(long)day,(long)hour,(long)minitues,(long)second];
    
    NSString * nsDateString =[nstr stringByReplacingOccurrencesOfString:@" " withString:@"0"];
    //    NSLog(@"nsDateString====%@",nsDateString);
    return nsDateString;
}










@end
