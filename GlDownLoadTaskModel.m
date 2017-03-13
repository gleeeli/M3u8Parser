//
//  GlDownLoadTaskModel.m
//  PlayerWebURLDemo
//
//  Created by gleeeli on 16/6/19.
//  Copyright © 2016年 liguanglei. All rights reserved.
//

#import "GlDownLoadTaskModel.h"
#import "GlCommMethod.h"
#import "NSString+AddMethod.h"
#import "ParserJSPlugFactory.h"

@interface GlDownLoadTaskModel ()
@property (nonatomic, strong) ParserPluginsHandle *parser;
@end
@implementation GlDownLoadTaskModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initSome];
        self.savePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"VideoLoad"];
        self.formatType = GlUnKonow;
        self.tvSet = -1;
        self.updateDownLoadUrlTime = 0;
        self.requestArray = nil;
    }
    return self;
}
- (instancetype)initWithSavePath:(NSString *) savePath
{
    self = [super init];
    if (self)
    {
        self.savePath = savePath;
        self.lastNotificationTime = [[NSDate date] timeIntervalSince1970];
        self.isDelay = YES;
        self.formatType = GlUnKonow;
        self.tvSet = -1;
        self.updateDownLoadUrlTime = 0;
        self.requestArray = nil;
    }
    return self;
}
-(void)setSavePath:(NSString *)savePath
{
    if (![GlCommMethod createFileDirectories:savePath])
    {
       NSRange range = [savePath rangeOfString:@"/Documents/"];
       NSString * name = [savePath substringFromIndex:range.location];
        NSString * newSavePath = [NSHomeDirectory() stringByAppendingString:name];
        NSLog(@"地址已发生改变");
        savePath = newSavePath;
    }
    _savePath = savePath;
}
-(void)initSome
{
    self.taskStatus = GlDownloadWait;
    self.downMethod = GlDownGET;

    self.totalRuningCount = 0;
}
//名字中过滤掉特殊字符，因为要用名字创建文件夹
- (void)setName:(NSString *)name
{
    if ([GlCommMethod isNUllObject:name])
    {
        name = @"未知";
    }
    name = [name stringByReplacingOccurrencesOfString:@":" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@"?" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@"*" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@"/" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@"\\" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@"<" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@">" withString:@""];
    name = [name stringByReplacingOccurrencesOfString:@"|" withString:@""];
    _name = name;
}


/**
 *  链接是否有效监测
 *
 */
- (BOOL)isAvailableSource
{
    NSString *newUrl = [self.requestArray count] > 0? self.requestArray[0]:nil;
    if (![GlCommMethod isNUllObject:newUrl]  && newUrl.length > 4)// 下载链接是否有效
    {
        return YES;
    }
    else if (self.isPageUrl && ![GlCommMethod isNUllObject:self.originWebSiteUrl])// 页面链接是否有效
    {
        return YES;
    }
    NSLog(@"无效的：%@",newUrl);
    return NO;
}


/**
 *  下载链接是否超时
 *
 *  @return bool
 */
- (BOOL)isDownloadUrlTimeOut
{
    if (_isPageUrl)
    {
        NSTimeInterval nowTime = [[NSDate date] timeIntervalSince1970];
       long long outTime = nowTime - _updateDownLoadUrlTime;
        if (outTime > 60 * 10 )
        {
            NSLog(@"下载链接过时：%lld",outTime);
            return YES;
        }
    }
    return NO;
}


- (void)setRequestArray:(NSArray *)requestArray
{
    _requestArray = requestArray;
    
    NSMutableArray * taskArray = [[NSMutableArray alloc]init];
    
    for (NSInteger i = 0; i < [requestArray count]; i++ )
    {
        //兼容以前
        id file = requestArray[i];
        NSString * url = nil;
        long long size = 0;
        long long sencond = 0;
        NSInteger seq = -1;
        NSString *duration = @"0";
        NSString *maxDuration = @"0";
        if ([file isKindOfClass:[NSString class]])
        {
            url = file;
        }
        else
        {
            NSDictionary *dict = file;
            url = [dict objectForKey:@"furl"];
            size = [[dict objectForKey:@"size"] longLongValue];
            seq = [[dict objectForKey:@"seq"] integerValue];
            sencond = [[dict objectForKey:@"seconds"] longLongValue];
            duration = [dict objectForKey:GlDURATION];
            maxDuration = [dict objectForKey:GlM3U8MaxDuration];
        }
        
        
        // 创建放所有子任务的文件夹
        NSString * newSavePath = [self getNewSavePath];
        
        GlDownTask * task = [[GlDownTask alloc]initWithTaskID:_taskID URL:url curIndex:i savePath:newSavePath];
        task.size = size;
        task.seq = seq;
        task.seconds = sencond;
        task.durationM3 = [duration floatValue];
        task.m3u8Dict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:duration,GlDURATION,maxDuration,GlM3U8MaxDuration, nil];//为了兼容
        
        NSLog(@"获得的大小，size:%lld，获得得时长：%lld",task.size,task.seconds);
        
        // 数组若记录每个子任务的格式则取数组格式，没有则根据_formatType判断格式
        GlFileFormatType format = i < [_formatArray count]? [_formatArray[i] integerValue]:_formatType;
        if (format == GlM3U8)
        {
            task.fileFormat = @"";// m3u8子任务格式为空
        }
        else
        {
            
            task.fileFormat = [self getSmallFormatWithFormat:_format smallUrl:url];
        }
        [taskArray addObject:task];
    }
    _requestTasks = taskArray;
}

- (NSString *)getSmallFormatWithFormat:(NSString *)format smallUrl:(NSString *)smallUrl
{
    NSString *sFormat = format;
    NSRange range = [format rangeOfString:@".m3u8" options:NSCaseInsensitiveSearch];
    if (range.location > 1 && format.length > range.location)
    {
        sFormat = [format substringWithRange:NSMakeRange(0, range.location)];
    }
    else if([format isEqualToString:@"m3u8"])
    {
        sFormat = [GlCommMethod getFormatFromUrl:smallUrl];
        if ([GlCommMethod isNUllObject:sFormat])
        {
            NSLog(@"m3u8子链接中未得到格式，直接赋值ts");
            sFormat = @"ts";
        }
    }
    if ([GlCommMethod isNUllObject:sFormat])
    {
        sFormat = @"";
    }
    NSLog(@"得到的子任务格式：%@",sFormat);
    return sFormat;
}

- (NSString *)getFormatStringBy:(GlFileFormatType) format
{
    switch (format)
    {
        case GlMP4:
            return  @"mp4";
            break;
        case GlMP3:
            return @"mp3";
            break;
        case GlLRC:
            return @"lrc";
            break;
        case GlFlV:
            return @"flv";
            break;
        case GlM4A:
            return @"m4a";
            break;
        case GlM3U8:
            return @"m3u8";
            break;
            
        default:
            return @"";
            break;
    }
}


//放所有子任务的文件夹路劲
-(NSString *)getNewSavePath
{
    NSString * newSavePath = [NSString stringWithFormat:@"%@/%@_%@_%ld",_savePath,_taskID,_name,(long)_tvSet];
    return newSavePath;
}
//获取只有一个播放链接的地址
-(NSString *)getTaskOnlyFilePath
{
    NSString *filePath = [[self getNewSavePath] stringByAppendingString:@".mp4"];
    return filePath;
}
//获取下一个需要下载的子任务
- (GlDownTask *)getNextTask
{
    for (GlDownTask * task in _requestTasks)
    {
        if (task.curStatus == GlDownloadUnStart || task.curStatus == GlDownloadPause || task.curStatus == GlDownloadWait)
        {
            return task;
        }
    }
    return nil;
}
- (void)setFialedOrLoadingOrCancelTaskToPause
{
    for (GlDownTask * task in _requestTasks)
    {
        if (task.curStatus == GlDownloadFailed || task.curStatus == GlDownloading || task.curStatus == GlDownloadCancel)
        {
            task.curStatus = GlDownloadPause;
        }
    }
}

- (NSDictionary *)getHaveDownLoadBytes
{
    long long totalBytesRead = 0;//已下载大小
    long long totalBytesExpectedToRead = 0;//总大小
    
    long long tempTotalBytesExpectedToRead = 0;
    GlDownTask *haveTotalByteTask = nil;
    
//    WDLog(LOG_MODUL_TRANSFER, @"**************Start Size******************************");
    for (NSInteger i = 0; i < [_requestTasks count]; i++)
    {
        GlDownTask *task = _requestTasks[i];
        
        totalBytesRead += task.totalBytesRead;
        if (task.size > 1 && task.size > task.totalBytesRead)//服务器传来了大小，则去服务器大小
        {
            task.totalBytesExpectedToRead = task.size;
//            WDLog(LOG_MODUL_TRANSFER,@"服务器传来的大小：%lld",task.size);
        }
        
        if (task.totalBytesExpectedToRead > 1)
        {
            //NSLog(@"真实大小：%lld",task.totalBytesExpectedToRead);
            if (!haveTotalByteTask)
            {
                
                haveTotalByteTask = task;
                //WDLog(LOG_MODUL_TRANSFER,@"有值的大小：%lld,duration:%f",haveTotalByteTask.totalBytesExpectedToRead,haveTotalByteTask.durationM3);
            }
            tempTotalBytesExpectedToRead = task.totalBytesExpectedToRead;
        }
        else //没有总大小,给它上一个任务的大小值
        {
            if (_formatType == GlM3U8 || [_format isEqualToString:@"m3u8"])
            {
                long long  digitBytes = [self getExpectedSizeLastTask:haveTotalByteTask nowTask:task];
                tempTotalBytesExpectedToRead = digitBytes > 0? digitBytes:tempTotalBytesExpectedToRead;
            }
            else//比如优酷多段mp4
            {
                //WDLog(LOG_MODUL_TRANSFER,@"开始多段计算");
                if (haveTotalByteTask.totalBytesExpectedToRead > 1)
                {
                    tempTotalBytesExpectedToRead = haveTotalByteTask.totalBytesExpectedToRead;
                    NSLog(@"直接赋值其它任务的大小:%lld",tempTotalBytesExpectedToRead);
                }
                
            }
        }
        
        //统计
        if (task.totalBytesExpectedToRead > 1)
        {
            //WDLog(LOG_MODUL_TRANSFER,@"真实的当前子任务(%@:%ld)大小：%lld",[self getShowName],(long)(long)task.curIndex,task.totalBytesExpectedToRead);
            totalBytesExpectedToRead += task.totalBytesExpectedToRead; //统计总大小
        }
        else
        {
            //WDLog(LOG_MODUL_TRANSFER,@"预料的当前子任务(%@:%ld)大小：%lld",[self getShowName],(long)(long)task.curIndex,tempTotalBytesExpectedToRead);
            totalBytesExpectedToRead += tempTotalBytesExpectedToRead; //统计总大小
        }
    }
    //WDLog(LOG_MODUL_TRANSFER, @"**************END Size******************************");
    if (totalBytesRead > totalBytesExpectedToRead)
    {
        totalBytesExpectedToRead = totalBytesRead + 1024;
    }
    
    NSString *read = [[NSString stringWithFormat:@"%lld",totalBytesRead] byteConvertToStringExact];
    NSString *ExpectedToRead = [[NSString stringWithFormat:@"%lld",totalBytesExpectedToRead] byteConvertToStringExact];
    CGFloat precent = (CGFloat)totalBytesRead / totalBytesExpectedToRead;
    long long remainbyte = totalBytesExpectedToRead - totalBytesRead;//剩余未下载的大小
    
    NSDictionary *dict = [[NSDictionary alloc]initWithObjectsAndKeys:read,Gl_TOTAL_READ_BYTE,
    ExpectedToRead,Gl_TOTASL_EXPET_BYTE,[NSNumber numberWithFloat:precent],Gl_TOTAL_PERCENT,[NSNumber numberWithLongLong:totalBytesExpectedToRead],Gl_TASK_TOTAL_EXPET_BYTE,[NSNumber numberWithLongLong:remainbyte],Gl_TOTAL_REMAIN_BYTE,nil];
    
    NSLog(@"ExpectedToRead:%@",ExpectedToRead);
    return dict;
}


//根据m3u8的时间，计算预计大小
-(long long)getExpectedSizeLastTask:(GlDownTask *)lastTask nowTask:(GlDownTask *)nowTask
{
    float lastDuration = lastTask.durationM3;//5
    float nowDuration = nowTask.durationM3;//10
    
    if (lastDuration < 1 || nowDuration < 1 || !lastTask)
    {
        WDLog(LOG_MODUL_TRANSFER,@"时长为0的，lastDuration:%f,nowDuration:%f",lastDuration,nowDuration);
        return 0;
    }
    
    long long lastExpectBytes = lastTask.totalBytesExpectedToRead;
    long long nowExpectBytes = (nowDuration / lastDuration) * lastExpectBytes;
    //NSString *read = [[NSString stringWithFormat:@"%lld",nowExpectBytes] byteConvertToStringExact];
    //WDLog(LOG_MODUL_TRANSFER,@"根据m3u8的时间，计算预计大小:%lld,转换后：%@",nowExpectBytes,read);
    return nowExpectBytes;
}


//获取真实总大小
- (long long)getAllTotalBytes
{
    unsigned long long downloadedBytes = 0;
    for (GlDownTask *task in _requestTasks)
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[task getCurDownLoadPath]])
        {
            //获取已下载的文件长度
            unsigned long long  tempDownloadedBytes = [GlCommMethod fileSizeForPath:[task getCurDownLoadPath]];
            downloadedBytes += tempDownloadedBytes;
        }
        else
        {
            NSLog(@"获取总大小出错，文件不存在");
        }
    }
    NSLog(@"文件总长度：%lld",downloadedBytes);
    return downloadedBytes;
}


/**
 *  判断下载阶段是否结束
 *
 *  @return 下载阶段完成，下载阶段失败，有正在下载的
 */
-(GlDownloadStatus)isAllComplete
{
    NSInteger complete = 0;
    NSInteger failure = 0;
    NSInteger other = 0;
    for (GlDownTask *task in _requestTasks)
    {
        switch (task.curStatus) {
            case GlDownloadComplete:
            {
                complete ++;
            }
                break;
            case GlDownloadFailed:
            {
                failure ++;
            }
                break;
            case GlDownloading:
            {
                return GlDownloading;
            }
                break;
            case GlDownLoadUploadComplete:
            {
                complete ++;
            }
                break;
            case GlDownLoadUploadFailed:
            {
                complete ++;
            }
                break;
            case GlDownLoadUploading:
            {
                complete ++;
            }
                break;
                
            default:
                other ++;
                break;
        }
    }
    if (other > 0)
    {
        NSLog(@"有其它类型的任务");
        return GlDownloadWait;//返回还有需要下载的
    }
    else if (failure > 0)
    {
        NSLog(@"有失败的任务");
        return GlDownloadFailed;
    }else if (complete == [_requestArray count])
    {
        return GlDownloadComplete ;
    }
    NSLog(@"error:可能任务未全部完成");
    return GlDownloadFailed;
}


- (void)setTaskLoadingToPause
{
    for (GlDownTask *task in _requestTasks) {
        if (task.curStatus == GlDownloading) {
            task.curStatus = GlDownloadPause;
        }
    }
}


- (NSString *)getShowName
{
    NSString *name = _name;
    if (_tvSet >= 0)
    {
       name = [NSString stringWithFormat:@"%@_%ld",name,(long)_tvSet];
    }
//    if (_isPageUrl)//新方法获取的资源
//    {
        if ([GlCommMethod isNUllObject:_format])
        {
            return name;
        }
        return [NSString stringWithFormat:@"%@.%@",name,_format];
//    }
    
//    NSString *format = [self getFormatStringBy:_formatType];
//    return [NSString stringWithFormat:@"%@.%@",name,format];
}


- (NSArray *)getPlayerUrls
{
    NSString *playerUrl= nil;
    NSMutableArray  *urls = [[NSMutableArray alloc]init];
    switch (_formatType) {
        case GlM3U8:
        {
            NSString *fileName = [NSString stringWithFormat:@"%@.m3u8",self.taskID];
            NSString * newSavePath = [self getNewSavePath];
            //真实路径
            //NSString *fullpath = [newSavePath stringByAppendingPathComponent:fileName];
            
            NSRange range = [newSavePath rangeOfString:@"/Documents/"];
            NSString * siteName = [newSavePath substringFromIndex:(range.location + range.length)];
            
            NSString *port = [NSString stringWithFormat:@"%d",M3U8_PORT];
            playerUrl = [NSString stringWithFormat:@"http://127.0.0.1:%@/%@/%@",port,siteName,fileName];
           playerUrl = [GlCommMethod encodeUrl:playerUrl];
            NSLog(@"playerUrl==%@",playerUrl);
            NSURL *nurl = [NSURL URLWithString:playerUrl];
            [urls addObject:nurl];
            
        }
            break;
            case GlMP4:
        {
            //真实路径
            NSString *filepath = [self getTaskOnlyFilePath];
            //存在合成的文件
            if ([[NSFileManager defaultManager] fileExistsAtPath:filepath])
            {
                NSLog(@"存在合成的地址：%@",filepath);
                NSURL *nurl = [NSURL fileURLWithPath:filepath];
                [urls addObject:nurl];
            }
            else
            {
                for (GlDownTask *task in _requestTasks)
                {
                    NSString *curUrl = [task getCurDownLoadPath];
    //                NSRange range = [curUrl rangeOfString:@"/Documents/"];
    //                NSString * siteName = [curUrl substringFromIndex:(range.location + range.length)];
    //
    //                curUrl=[NSString stringWithFormat:@"http://127.0.0.1:12346/%@",siteName];
    //                curUrl = [GlCommMethod encodeUrl:curUrl];

                    NSURL *nurl = [NSURL fileURLWithPath:curUrl];
                    [urls addObject:nurl];
                }
            }
            

            
        }
            break;
        case GlMP3:
        {
            for (GlDownTask *task in _requestTasks)
            {
                NSString *curUrl = [task getCurDownLoadPath];
                NSRange range = [curUrl rangeOfString:@".mp3"];
                if (range.location != NSNotFound)
                {
//                    NSRange range = [curUrl rangeOfString:@"/Documents/"];
//                    NSString * siteName = [curUrl substringFromIndex:(range.location + range.length)];
//                    
//                    curUrl=[NSString stringWithFormat:@"http://127.0.0.1:12346/%@",siteName];
//                    curUrl = [GlCommMethod encodeUrl:curUrl];
                    
                    NSURL *nurl = [NSURL fileURLWithPath:curUrl];
                    [urls addObject:nurl];
                }
                
            }
        }
            break;
        default:
        {
            for (GlDownTask *task in _requestTasks)
            {
                NSString *curUrl = [task getCurDownLoadPath];
                NSURL *nurl = [NSURL fileURLWithPath:curUrl];
                [urls addObject:nurl];
            }
        }
            break;
    }
    return urls;
}


//获取需要上传的文件
- (NSArray *)getUploadFiles
{

    NSMutableArray  *paths = [[NSMutableArray alloc]init];
    
    for (GlDownTask *task in _requestTasks)
    {
        if (task.curStatus != GlDownLoadUploadComplete)
        {
            [paths addObject:task];
        }
    }
    
//    switch (_formatType) {
//        case GlM3U8:
//        {
//            NSString *fileName = [NSString stringWithFormat:@"%@.m3u8",self.taskID];
//            NSString * newSavePath = [self getNewSavePath];
//            //真实路径
//            NSString *fullpath = [newSavePath stringByAppendingPathComponent:fileName];
//            [paths addObject:fullpath];
//            
//            //加入m3u8子文件
//            for (GlDownTask *task in _requestTasks)
//            {
//                NSString *curUrl = [task getCurDownLoadPath];
//                [paths addObject:curUrl];
//            }
//            
//        }
//            break;
//        case GlMP4:
//        {
//            //真实路径
//            NSString *filepath = [self getTaskOnlyFilePath];
//            //存在合成的文件
//            if ([[NSFileManager defaultManager] fileExistsAtPath:filepath])
//            {
//                [paths addObject:filepath];
//            }
//            else
//            {
//                for (GlDownTask *task in _requestTasks)
//                {
//                    NSString *curUrl = [task getCurDownLoadPath];
//                    [paths addObject:curUrl];
//                }
//            }
//        }
//            break;
//        default:
//        {
//            for (GlDownTask *task in _requestTasks)
//            {
//                NSString *curUrl = [task getCurDownLoadPath];
//                [paths addObject:curUrl];
//            }
//        }
//            break;
//    }
    return paths;
}


- (NSString *)message
{
    if ([GlCommMethod isNUllObject:_message])
    {
        _message = @"";
    }
    return _message;
}


#pragma mark 获取服务器的下载地址
/**
 *  更新下载链接
 *
 *  @param serviceDict 从服务器得到的数据
 */
- (void)updateTasksDownLoadUrlWithResult:(NSDictionary *)serviceDict complete:(void(^)(NSString *success))complete
{
    NSString *error = [serviceDict objectForKey:@"error"];
    NSArray *seg = [serviceDict objectForKey:@"data"];
    //NSString *quality = [serviceDict objectForKey:@"quality"];
    
    if (!seg || [seg count] <= 0)
    {
        NSLog(@"更新下载链接出错：%@",serviceDict);
        complete(error);
        return;
    }
    
    
    //NSDictionary *file = [self getDownLoadInfoFromArray:files];
    //NSString *nowQuality = [file objectForKey:@"quality"];
    
    //NSLog(@"当前质量：%@",nowQuality);
    
    
    //NSArray *seg = [file objectForKey:@"seg"];
    
    NSDictionary *firstDict = [seg count] > 0? seg[0]:nil;
    NSString *firstUrl = [firstDict objectForKey:@"furl"];
    NSString *quality = [firstDict objectForKey:@"quality"];
    
//    //测试
//    NSMutableDictionary *muDict = [[NSMutableDictionary alloc] initWithDictionary:firstDict];
//    firstUrl = @"https://15-lvl3-skyfire-gce.vimeocdn.com/1476778065-2e4d83eb6bb99e8cedff7e16b9e3d7873598154c/185891294/video/614044421,614044424,614044423,614044422/master.m3u8";//vimeo测试
//    [muDict setObject:firstUrl forKey:@"furl"];
//    seg = [[NSArray alloc] initWithObjects:muDict, nil];
//    self.originWebSiteUrl = firstUrl;
    
    
    NSString *format = [self getFormatWithQuality:quality url:firstUrl];//[file objectForKey:@"format"]
    
    self.format = format;
    if ([format isEqualToString:@"mp3"] || [format isEqualToString:@"m4a"])
    {
        self.fileType = GlMusicFile;
    }
    
    NSLog(@"当前格式：%@",format);
    if ([_format isEqualToString:@"m3u8"])// 该资源为需要解析的m3u8
    {
        //解析m3u8
        self.parser = [ParserJSPlugFactory createParserPlugingHandleByURL:_originWebSiteUrl];
        [self.parser handleM3u8WithSegArray:seg complete:^(NSMutableArray *m3u8Array)
        {
            [self segHandleSeg:m3u8Array  Complete:^(NSString *success)
            {
                complete(success);
            }];
        }];
    }
    else// 非M3u8
    {
        [self segHandleSeg:seg  Complete:^(NSString *success)
        {
            complete(success);
        }];
    }
}


- (NSString *)getFormatWithUrl:(NSString *)url
{
//    nowQuality = [nowQuality lowercaseString];
    NSString *format = nil;
    format = [GlCommMethod getFormatFromUrl:url];//url解析格式，优酷可能失败
    NSLog(@"解析url得到的格式:%@",format);
    if ([[format lowercaseString] isEqualToString:@"hlv"])
    {
        format = @"flv";
    }
    
    //服务器传的质量解析格式
    if ([GlCommMethod isNUllObject:format])
    {
        NSLog(@"");
        NSArray *array = [GlCommMethod getNeedRegexsFromStr:url regex:@"/mp4|/m4v|/flv|/hlv|\\.mp4|\\.flv|/m3u8"];
        if ([array count] == 1)
        {
           format = array[0];
            format = [format stringByReplacingOccurrencesOfString:@"/" withString:@""];
            format = [format stringByReplacingOccurrencesOfString:@"." withString:@""];
        }
    }
    
    if ([GlCommMethod isNUllObject:format] && ![GlCommMethod isNUllObject:_format])
    {
        NSLog(@"获取到的格式为空，取每个网站预先自定义的格式：%@",_format);
        format = _format;
    }
    
    //格式仍然为空，赋默认值
    if ([GlCommMethod isNUllObject:format] || ![GlCommMethod isSupportFormat:format])//[format isEqualToString:@"letv"]
    {
        if (self.fileType == GlMusicFile)
        {
            format = @"mp3";
        }
        else
        {
            format = @"mp4";
        }
        
    }
    
    return format;
}


/**
 *  根据资源链接和质量字段 获取文件格式
 *
 *  @param quality 当前资源质量
 *  @param url     下载链接
 *
 *  @return 格式
 */
- (NSString *)getFormatWithQuality:(NSString *)quality url:(NSString *)url
{
    NSString *format = [self getFormatWithUrl:url];
    NSString *lowQuality = [quality lowercaseString];//有可能m3u8-Flv
    
    if ([GlCommMethod isNUllObject:quality])
    {
        return format;
    }
    
    if ([lowQuality rangeOfString:@"m3u8"].location != NSNotFound && [lowQuality rangeOfString:@"m3u8"].length > 0)
    {
        format = @"m3u8";
    }
    else if ([lowQuality rangeOfString:@"mp4-aac"].location != NSNotFound && [lowQuality rangeOfString:@"mp4-aac"].length > 0)
    {
        format = @"m4a";
    }
    else if ([lowQuality rangeOfString:@"mp4"].location != NSNotFound && [lowQuality rangeOfString:@"mp4"].length > 0)
    {
        format = @"mp4";
    }
    else if ([lowQuality rangeOfString:@"flv"].location != NSNotFound && [lowQuality rangeOfString:@"flv"].length > 0)
    {
        format = @"flv";
    }
    
    return format;
}


/**
 *  seg数组处理好后
 *
 *  @param seg        处理好的
 *  @param nowQuality 当前质量
 *  @param complete   完成回调
 */
- (void)segHandleSeg:(NSArray *)seg Complete:(void(^)(NSString *success))complete
{
    NSDictionary *dict = [seg count] > 0? seg[0]:nil;
    NSString *nowQuality = [NSString stringWithFormat:@"%@",[dict objectForKey:@"size"]];
    
    if ([self.requestArray count] == [seg count])
    {
        [self updateTAsksWithArray:seg];
    }
    else// 未获取，或链接数量发生了改变，视频质量发生改变，则认为之前的子任务全部失效
    {
        self.sourceQuality = nowQuality;
        self.requestArray = seg;
        
        if (self.requestArray && [self.requestArray count] > 0)
        {
            NSLog(@"warn：链接已发生改变，删除之前下载的子任务");
            NSString * newSavePath = [self getNewSavePath];
            [GlCommMethod deleteDirectoryWithDir:newSavePath];
            
        }
    }
    complete(@"success");
}


/**
 *  更新子任务失效的url
 *
 *  @param requestArray 新的下载链接
 */
-(void)updateTAsksWithArray:(NSArray *)requestArray
{
    for (NSInteger i = 0; i < [_requestTasks count]; i++ )
    {
        //兼容以前
        id file = requestArray[i];
        NSString * url = nil;
        long long size = 0;
        NSInteger seq = -1;
        if ([file isKindOfClass:[NSString class]])
        {
            url = file;
        }
        else
        {
            NSDictionary *dict = file;
            url = [dict objectForKey:@"furl"];
            size = [[dict objectForKey:@"size"] longLongValue];
            seq = [[dict objectForKey:@"seq"] integerValue];
        }
        
        GlDownTask * task = _requestTasks[i];
        task.requestUrl = url;
        task.size = size;
        task.seq = seq;
    }
    
}

/**
 *  选择最好的视频质量
 *
 *  @param array 质量数组
 *
 *  @return 该质量的视频信息
 */
/*
- (NSDictionary *)getDownLoadInfoFromArray:(NSArray *)array
{
    NSInteger selectedPriority = -1;// 最终选择的视频质量
    NSDictionary *selectedDict = nil;
    NSString *format = nil;
    
    for (NSDictionary *dict in array)
    {
        NSString *quality = [dict objectForKey:@"quality"];
        NSDictionary *nowDict = [self getPriorityAndFormatWithQuality:quality];
        NSInteger nowPriority = [[nowDict objectForKey:@"priority"] integerValue];
        
        if (selectedPriority == -1)
        {
            selectedPriority = nowPriority;
            selectedDict = dict;
            format = [nowDict objectForKey:@"format"];
        }
        else if(nowPriority < selectedPriority)// 当前质量优先级高于之前选的
        {
            selectedPriority = nowPriority;
            selectedDict = dict;
            format = [nowDict objectForKey:@"format"];
        }
        
    }
    
//    NSMutableDictionary *muDict = [[NSMutableDictionary alloc]initWithDictionary:selectedDict];
//    [muDict setObject:format forKey:@"format"];
    
    return selectedDict;
}
*/

/*
- (NSDictionary *)getPriorityAndFormatWithQuality:(NSString *)quality
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    NSInteger priority= 1;
    if ((priority ++) && [quality rangeOfString:@"Orignal"].location != NSNotFound )
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"1080P"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"720P"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"SuperHD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"3GP-HD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"FLV-SuperHD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"FLV-HD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"FLV-SD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];//测试
        return dict;
    }else if ((priority ++) && [quality rangeOfString:@"Mobile-m3u8-FLV-HD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }else if ((priority ++) && [quality rangeOfString:@"Mobile-m3u8-FLV-SuperHD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"Mobile-m3u8-MP4-HD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"MP4-SD"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else if ((priority ++) && [quality rangeOfString:@"Mobile-m3u8-FLV-1080P"].location != NSNotFound)
    {
        [dict setObject:[NSNumber numberWithInteger:priority] forKey:@"priority"];
        return dict;
    }
    else
    {
        [dict setObject:[NSNumber numberWithInteger:-1] forKey:@"priority"];
        NSLog(@"********未识别的格式quality：%@",quality);
        return dict;
    }
}
*/
@end


@implementation GlDownTask

- (instancetype)initWithTaskID:(NSString *) taskID URL:(NSString *) url curIndex:(NSInteger) curIndex savePath:(NSString *)savePath
{
     self = [super init];
    if (self) {
        self.taskID = taskID;
        self.curIndex = curIndex;
        self.requestUrl = url;
        self.curStatus = GlDownloadUnStart;
        self.method = GlDownGET;
        self.fileFormat = @"mp4";
        self.curParameters = nil;
        self.savePath = savePath;
        self.m3u8Dict = [[NSMutableDictionary alloc]init];
        self.reTryTimes = 0;
        //NSLog(@"初始化段号：%ld",self.curIndex);
    }
    return self;
}


//获取当前连接的下载地址
- (NSString *)getCurDownLoadPath
{
    //创建好文件
    if (![GlCommMethod createFileDirectories:_savePath])
    {
        //NSLog(@"warn:创建路径时发现路径不存在");
        NSRange range = [_savePath rangeOfString:@"/Documents/"];
        if (range.location != NSNotFound)
        {
            NSString * name = [_savePath substringFromIndex:range.location];
            NSString * newSavePath = [NSHomeDirectory() stringByAppendingString:name];
            //NSLog(@"老地址:%@",_savePath);
            //NSLog(@"新地址:%@",newSavePath);
            _savePath = newSavePath;
            [GlCommMethod createFileDirectories:_savePath];
        }
        else
        {
            NSLog(@"error:以前的保存路径有错");
        }
        
    }
    //m3u8子文件不需要加后缀
    
    NSString * curDownloadPath = [_savePath stringByAppendingPathComponent:[self getFileName]];
    //NSLog(@"_savePath==%@",_savePath);
    //NSLog(@"getFileName==%@",[self getFileName]);
    //NSLog(@"当前文件下载地址：%@",curDownloadPath);
    return curDownloadPath;
}


- (NSString *)getDownMethod
{
    switch (_method) {
        case GlDownPOST:
            return @"POST";
            break;
            
        default:
            return @"GET";
            break;
    }
}


//获得当前文件名
- (NSString *)getFileName
{
    NSString * fileFormat = @"";
    if (![_fileFormat isEqualToString:@""])
    {
        fileFormat = [NSString stringWithFormat:@".%@",_fileFormat];
    }
    NSString *fileName = [NSString stringWithFormat:@"%@_%ld%@",_taskID,(long)_curIndex,fileFormat];
    return fileName;
}


#pragma 归档使用
- (id)initWithCoder:(NSCoder *) aDecoder
{
    if ((self = [super init])) {
        self.taskID = [aDecoder decodeObjectForKey:@"taskID"];
        self.curIndex = [[aDecoder decodeObjectForKey:@"curIndex"]integerValue];
        self.requestUrl = [aDecoder decodeObjectForKey:@"requestUrl"];
        self.totalBytesRead = [[aDecoder decodeObjectForKey:@"totalBytesRead"]longLongValue];
        self.totalBytesExpectedToRead = [[aDecoder decodeObjectForKey:@"totalBytesExpectedToRead"]longLongValue];
        self.curStatus = [[aDecoder decodeObjectForKey:@"curStatus"]integerValue];
        self.savePath = [aDecoder decodeObjectForKey:@"savePath"];
        self.method = [[aDecoder decodeObjectForKey:@"method"]integerValue];
        self.curParameters = [aDecoder decodeObjectForKey:@"curParameters"];
        self.fileFormat = [aDecoder decodeObjectForKey:@"fileFormat"];
        self.m3u8Dict = [aDecoder decodeObjectForKey:@"m3u8Dict"];
        self.reTryTimes = [[aDecoder decodeObjectForKey:@"reTryTimes"]integerValue];
        
        self.size = [[aDecoder decodeObjectForKey:@"size"] longLongValue];
        self.seconds = [[aDecoder decodeObjectForKey:@"seconds"] longLongValue];
        self.seq = [[aDecoder decodeObjectForKey:@"seq"] longLongValue];
        self.durationM3 = [[aDecoder decodeObjectForKey:@"durationM3"] floatValue];
    }
    return self;
}


- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.taskID forKey:@"taskID"];
     [aCoder encodeObject:@(self.curIndex) forKey:@"curIndex"];
    [aCoder encodeObject:self.requestUrl forKey:@"requestUrl"];
     [aCoder encodeObject:@(self.totalBytesRead) forKey:@"totalBytesRead"];
     [aCoder encodeObject:@(self.totalBytesExpectedToRead) forKey:@"totalBytesExpectedToRead"];
     [aCoder encodeObject:@(self.curStatus) forKey:@"curStatus"];
     [aCoder encodeObject:self.savePath forKey:@"savePath"];
    [aCoder encodeObject:@(self.method) forKey:@"method"];
    [aCoder encodeObject:self.curParameters forKey:@"curParameters"];
    [aCoder encodeObject:self.fileFormat forKey:@"fileFormat"];
    [aCoder encodeObject:self.m3u8Dict forKey:@"m3u8Dict"];
    [aCoder encodeObject:@(self.reTryTimes) forKey:@"reTryTimes"];
    
    [aCoder encodeObject:@(self.size) forKey:@"size"];
    [aCoder encodeObject:@(self.seconds) forKey:@"seconds"];
    [aCoder encodeObject:@(self.seq) forKey:@"seq"];
    [aCoder encodeObject:@(self.durationM3) forKey:@"durationM3"];
}

@end
