//
//  DLRecorder.h
//  AVAudioSessionDemo
//
//  Created by 武得亮 on 2018/10/12.
//  Copyright © 2018年 武得亮. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DLAmrRecorderDelegate;


@interface DLRecorder : NSObject


/**
 涉及功能：
    开始录音
    暂停录音
    结束录音
    录音完毕回调
    中断处理
    继续录音
    是否正在录音
    路径保存
    格式转换
    录音拼接
 */

+(instancetype)shareRecorderManger;

/*
 开始录音
 path: 录音保存的路径
 */
-(void)dlrecordWithURL:(NSURL *)fileUrl saveRelativelyPath:(NSString *)path;

-(NSString *)getRelativelyPath;

/**
 暂停录音
 */
-(void)dlpause;

/**
 继续录音
 */
-(void)dlContinueRecord;

/**
 结束录音
 */
-(void)dlendRecord;

/**
 暂停录音
 */
-(void)dlstop;


/***
 *  目标路径文件所有文件数组
 *  @param pathArray 路径数组
 *  @param fileffix  过滤后缀路径
 */
-(NSMutableArray *)recordcomparefile:(NSArray *)pathArray filesuffix:(NSString *)fileffix;

/** 合成音频文件
 *  @param sourceURLs  需要合并的多个音频文件
 *  @param toURL       合并后音频文件的存放地址
 */
-(void)dlsyntheticPath:(NSArray *)sourceURLs composeToURL:(NSString *)toURL completed:(void (^)(NSError *error))completed;


/**
 格式转换
 */
- (void)dlAudioM4AFile:(NSString *)m4aFileName toMp3File:(NSString *)mp3FileName;


/**
 使用免提，还是耳机线进行录制
 @param speakMode 是否使用免提录制
 */
-(void)dlspeakMode:(BOOL)speakMode;

/**
 是否正在录音
 */
@property(nonatomic,assign,readonly) BOOL dl_is_Recording;

/**
 录音委托
 */
@property(nonatomic, weak)id<DLAmrRecorderDelegate> delegate;

@end


/**
 AMR 文件信息
 */
@interface DLAmrFileInfo:NSObject

/**
 文本路径
 */
@property(nonatomic, copy)NSURL *fileUrl;

/**
 文件时间，单位秒
 */
@property(nonatomic,assign)NSTimeInterval duration;

/**
 文件大小
 */
@property(nonatomic,assign)unsigned long long fileSize;

@end



/**
 录音器委托
 */
@protocol DLAmrRecorderDelegate <NSObject>

@optional

/**
 录音完毕的回调
 
 *@param dlRecorder  录音器;
 *@param fileInfo     产生的录音文件;
 */
-(void)dlrecorder:(DLRecorder *)dlRecorder didRecordWithFile:(DLAmrFileInfo *)fileInfo;

/**
 录音被迫中断
 */
-(void)dlrecorderHasBeInterpurt;

/**
 录音时，语音大小值，录音时间
 
  dlRecorder
  dlpower
  currentTime
 */
-(void)dlrecorder:(DLRecorder *)dlRecorder didPickSpeakPower:(float)dlpower andTime:(double)currentTime;




@end




