//
//  GlDownLoadTaskModel.h
//  PlayerWebURLDemo
//
//  Created by gleeeli on 16/6/19.
//  Copyright © 2016年 liguanglei. All rights reserved.
//

#import <Foundation/Foundation.h>

#define MAX_RUN_TASK_COUNT 2   //最大同时运行子任务数
#define Gl_TOTAL_READ_BYTE @"totalBytesRead"
#define Gl_TOTASL_EXPET_BYTE @"totalBytesExpectedToRead"
#define Gl_TOTAL_PERCENT @"glToTalProgress"
#define Gl_TOTAL_REMAIN_BYTE @"glToTalRemainByte"//剩余未下载的字节

#define Gl_TASK_TOTAL_EXPET_BYTE @"glTasktotalBytesExpectedToRead"
#define GlDURATION @"m3u8_duration"
#define GlURL @"m3u8_url"
#define GlM3U8Dict @"m3u8_dict"
#define GlM3U8MaxDuration @"m3u8_maxduration"
#define GlDLURL @"furl"

#define M3U8_PORT 12346

//下载状态
typedef enum : NSUInteger {
    GlDownloadUnStart,
    GlDownloadWait,
    GlDownloading,
    GlDownloadPause,
//    GlDownloadSmallTaskAllComplete,//子任务下载完成待组合，单个子任务没有该状态
    GlDownloadFailed,
    GlDownloadCancel,
    GlDownloadComplete,// 下载阶段完成，待上传 6
    GlDownLoadUploading,//上传中 7
    GlDownLoadUploadComplete,//上传完成 8
    GlDownLoadUploadFailed,//上传失败 9
} GlDownloadStatus;

//下载方式
typedef enum : NSUInteger {
    GlDownGET,
    GlDownPOST,
} GlDownLoadMethod;

//文件类型
typedef enum : NSUInteger {
    GlFilmFile,
    GlMusicFile,
} GlFileType;
////文件类型
typedef enum : NSUInteger {
    GlMP4,
    GlMP3,
    GlLRC,
    GlFlV,
    GlM4A,
    GlM3U8,
    GlUnKonow,
} GlFileFormatType;

@class GlDownTask;

@interface GlDownLoadTaskModel : NSObject

@property (nonatomic, copy) NSString * taskID;
@property (nonatomic, copy) NSString * name;
@property (nonatomic, assign) NSInteger tvSet;    //当前第几集
@property (nonatomic, copy) NSString * savePath;    //保存路径
@property (nonatomic, copy) NSArray  * requestArray;   //待下载的所有链接
@property (nonatomic, copy) NSArray * formatArray; //对应格式
@property (nonatomic, strong) NSArray  * requestTasks;   //待下载的所有任务
@property (nonatomic, assign) GlDownLoadMethod downMethod;    //下载方式，get、post
@property (nonatomic, assign) GlDownloadStatus taskStatus;    //总状态，是否全部完成
@property (nonatomic, assign) NSInteger  totalRuningCount;   //当前任务的总运行线程数

@property (nonatomic, assign) GlFileFormatType formatType;//文件格式，已废弃
@property (nonatomic, assign) GlFileType  fileType;   //文件类型

@property (nonatomic, assign) NSTimeInterval  lastNotificationTime;//最后更新进度时间
@property (nonatomic, assign) NSTimeInterval  addTime;//任务添加时间
@property (nonatomic, assign) long long fileSize;//文件总大小,下载完成后才有值
//@property (nonatomic, assign) CGFloat totalPercent;//总完成度

@property (nonatomic, copy) NSString *message;//提示信息
@property (nonatomic, copy) NSString * originWebSiteUrl;    //资源来源
@property (nonatomic, copy) NSString * sourceQuality;    //资源质量
@property (nonatomic, assign) BOOL isPageUrl;// 是否页面url，页面url需要去服务器获取真实下载链接
@property (nonatomic, assign) NSTimeInterval  updateDownLoadUrlTime;//更新下载链接的时间
@property (nonatomic, copy) NSString * format;    //格式
@property (nonatomic, assign) BOOL isAbroad;//是否外国网站

//不存数据库的
@property (nonatomic, assign) BOOL isDelay;//是否延迟显示
@property (nonatomic, copy) NSString *curPlugUrl;//资源来源


- (instancetype)initWithSavePath:(NSString *) savePath ;

//获取下一个子任务
- (GlDownTask *)getNextTask;

//将所有失败和正在下载的子任务设为暂停状态
- (void)setFialedOrLoadingOrCancelTaskToPause;

//所有子任务是否完成,失败，
- (GlDownloadStatus)isAllComplete;

//- (CGFloat)getAllProgress;

//获取已下载数
-(NSDictionary *)getHaveDownLoadBytes;

//获取真实总大小,未上传时nsfilemanage 获取总大小
- (long long)getAllTotalBytes;

//将正在下载的任务设为暂停,不然获取next任务时
- (void)setTaskLoadingToPause;

//获取下载显示用的名字
- (NSString *)getShowName;

//放所有子任务的文件夹路劲
-(NSString *)getNewSavePath;

//获取播放地址，有可能是多链接
- (NSArray *)getPlayerUrls;

//获取只有一个播放链接的地址
-(NSString *)getTaskOnlyFilePath;

//获取需要上传的文件
- (NSArray *)getUploadFiles;

/**
 *  链接是否有效监测
 *
 */
- (BOOL)isAvailableSource;


/**
 *  下载链接是否超时
 *
 *  @return bool
 */
- (BOOL)isDownloadUrlTimeOut;

/**
 *  更新当前任务的下载链接
 *
 *  @param serviceDict 得到的新服务器
 */
- (void)updateTasksDownLoadUrlWithResult:(NSDictionary *)serviceDict complete:(void(^)(NSString *success))complete;

- (NSString *)getFormatWithUrl:(NSString *)url;
@end



@interface GlDownTask : NSObject

@property (nonatomic, copy) NSString * taskID;      //所属父ID
@property (nonatomic, assign) NSInteger curIndex;  //第几段
@property (nonatomic, copy) NSString * requestUrl;  //请求链接
@property (nonatomic, assign) long long  totalBytesRead;   //当前完成字节
@property (nonatomic, assign) long long  totalBytesExpectedToRead;   //总大小，字节
@property (nonatomic, assign) GlDownloadStatus curStatus; //当前子任务状态、下载中,暂停，完成，未开始  ??
@property (nonatomic, copy) NSString * savePath;    //保存路径

@property (nonatomic, assign) GlDownLoadMethod  method;   //请求方式
@property (nonatomic, copy) NSDictionary * curParameters;  //url参数
@property (nonatomic, copy)  NSString * fileFormat;     //文件格式

@property (nonatomic, assign) long long downedTempSize; //已经下载的文件长度
@property (nonatomic, strong) NSMutableDictionary * m3u8Dict;


@property (nonatomic, assign) NSInteger reTryTimes;//重新启动次数

@property (nonatomic, assign) long long size;// 服务器得到的大小
@property (nonatomic, assign) long long seconds;// 服务器得到的秒数
@property (nonatomic, assign) long long seq;// 服务器得到的序号
@property (nonatomic, assign) float durationM3;//m3u8用的

- (instancetype)initWithTaskID:(NSString *) taskID URL:(NSString *) url curIndex:(NSInteger) curIndex savePath:(NSString *)savePath ;

//获取当前连接的下载地址
- (NSString *)getCurDownLoadPath;

//获取当前下载方式
- (NSString *)getDownMethod;

//获得当前文件名
- (NSString *)getFileName;

- (id)initWithCoder:(NSCoder *) aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder ;


@end

