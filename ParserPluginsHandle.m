//
//  ParserPluginsHandle.m
//  PlayerWebURLDemo
//  Copyright © 2016年 liguanglei. All rights reserved.

#import "ParserPluginsHandle.h"

@interface ParserPluginsHandle()
@property (nonatomic, assign) BOOL isTimeOutGetData;//获取数据是否超时
@property (nonatomic, assign) NSInteger curM3u8Index;
@property (nonatomic, strong) NSMutableArray *m3u8AllArray;
@property (nonatomic, strong) NSMutableArray *rankTwoM3u8TmpArray;//二级m3u8数组临时数组
@end
@implementation ParserPluginsHandle
{
    AFHTTPRequestOperationManager * managerAf;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.originArray = [[NSArray alloc]init];
        self.taskArray = [[NSMutableArray alloc]init];
        self.defaultFileType = GlFilmFile;
        self.isAbroad = NO;
        managerAf= [AFHTTPRequestOperationManager manager];
        managerAf.requestSerializer = [AFHTTPRequestSerializer serializer];
        managerAf.responseSerializer = [AFHTTPResponseSerializer serializer];
        self.isTimeOutGetData = YES;
        self.repeatTimes = 0;
        if (!SnifferVersion)
        {
            [self saveNeedFilterArray];
        }
        
    }
    return self;
}


- (NSString *)getFormat:(GlDownLoadTaskModel *)taskModel fileType:(GlFileType)fileType url:(NSString *)url
{

    NSString *format = [taskModel getFormatWithUrl:url];
    if ([GlCommMethod isNUllObject:format])
    {
        if (fileType == GlFilmFile)
        {
            format = @"mp4";
        }
        else if (fileType == GlMusicFile)
        {
            format = @"mp3";
        }
    }
    return format;
}


#pragma mark 解析m3u8
/**
 *  处理服务器发来的m3u8数组
 *
 *  @param segArray 服务器获取的m3u8链接数组
 *  @param complete 完成
 */
- (void)handleM3u8WithSegArray:(NSArray *)segArray complete:(void(^)(NSMutableArray *m3u8Array))complete
{
    //self.completeParserM3u8 = complete;
    //self.m3u8AllArray = [[NSMutableArray alloc] init];
    NSMutableArray *muarray = [[NSMutableArray alloc] init];
    [self circleHandleWithSegArray:segArray curIndex:0 completeArray:muarray complete:^(NSMutableArray *m3u8Array)
    {
        NSLog(@"所有m3u8处理完成");
        NSMutableArray *newAllArray = [[NSMutableArray alloc] init];
        for (NSDictionary *segDict in m3u8Array)
        {
            NSArray *smallM3u8Array = [segDict objectForKey:@"m3u8Array"];
            //服务器传过来的大小
            long long size = [[segDict objectForKey:@"size"] longLongValue] / (float)[smallM3u8Array count];
            //平均计算每个子文件的时长
            long long seconds = [[segDict objectForKey:@"seconds"] longLongValue] / (float)[smallM3u8Array count];
            
            for (NSDictionary *smDict in smallM3u8Array )
            {
                NSString *furl = [smDict objectForKey:GlURL];
                NSMutableDictionary *newSeg =[[NSMutableDictionary alloc] init];
                
                [newSeg setObject:furl forKey:GlDLURL];
                [newSeg setObject:[NSNumber numberWithLongLong:size] forKey:@"size"];
                [newSeg setObject:[NSNumber numberWithLongLong:seconds] forKey:@"seconds"];
                [newSeg setObject:[smDict objectForKey:GlDURATION] forKey:GlDURATION];
                [newSeg setObject:[smDict objectForKey:GlM3U8MaxDuration] forKey:GlM3U8MaxDuration];
                [newAllArray addObject:newSeg];
            }
            
        }
        complete(newAllArray);
    }];
}


/**
 *  递归顺序解析
 *
 *  @param segArray 服务器获取的m3u8链接数组
 *  @param index    当前解析到的序号
 *  @param completeArray   已经解析好的子链接数组
 */
- (void)circleHandleWithSegArray:(NSArray *)segArray curIndex:(NSInteger)index completeArray:(NSMutableArray *)completeArray complete:(void(^)(NSMutableArray *m3u8Array))complete
{
    if ([segArray count] > index)
    {
        NSDictionary *segDict = segArray[index];
        
        __weak typeof(self)weakSelf = self;
        NSMutableDictionary *muSegDict = [[NSMutableDictionary alloc] initWithDictionary:segDict];
        [self handleM3u8WithDict:muSegDict complete:^(NSMutableArray *m3u8Array)
        {
            NSLog(@"得到一组数据后");
            NSInteger newIndex = index + 1;
            if (!m3u8Array)
            {
                m3u8Array = [[NSMutableArray alloc] init];
            }
            [muSegDict setObject:m3u8Array forKey:@"m3u8Array"];
            [completeArray addObject:muSegDict];
            [weakSelf circleHandleWithSegArray:segArray curIndex:newIndex completeArray:completeArray complete:complete];
        }];
    }
    else
    {
        complete(completeArray);
    }
}


/**
 *  解析m3u8请求链接获取字典数据
 *
 *  @param m3u8Url  m3u8链接
 *  @param complete 完成回掉
 */
- (void)handleM3u8WithDict:(NSMutableDictionary *) muSegDict  complete:(void(^)(NSMutableArray *m3u8Array))complete
 {
     NSString *m3u8Url = [muSegDict objectForKey:GlDLURL];
     NSLog(@"处理m3u8链接：%@",m3u8Url);
     if (![GlCommMethod isNUllObject:m3u8Url])
     {
         //请求m3u8文件
         [managerAf GET:m3u8Url parameters:nil success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject)
         {
             NSString *str=[[NSString alloc]initWithData:responseObject encoding:NSUTF8StringEncoding];
             NSLog(@"m3u8---responseObject:%@",str);
         
         [self handleM3U8WithStr:str muSegDict:muSegDict complete:complete];
         }
         failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error)
         {
             NSLog(@"m3u8-error:%@",error);
             complete(nil);
         }];
     
     }
 }

//请求m3u8链接后得到结果
- (void)handleM3U8WithStr:(NSString *) m3u8Str muSegDict:(NSMutableDictionary *) muSegDict complete:(void(^)(NSMutableArray *m3u8Array))complete
{
    NSInteger nowM3u8Rank = 1;//当前m3u8等级
    NSRange segmentRange = [m3u8Str rangeOfString:@"#EXTINF:"];
    if (segmentRange.location == NSNotFound)
    {
        segmentRange = [m3u8Str rangeOfString:@"#EXT-X-STREAM-INF:"];
        nowM3u8Rank = 2;
    }
    
    if (nowM3u8Rank == 1)//一级
    {
        complete([self handleRankOneM3u8:m3u8Str muSegDict:muSegDict]);
    }
    else if (nowM3u8Rank == 2)//二级
    {
        [self handleRankTwoM3u8:m3u8Str muSegDict:muSegDict complete:complete];
    }
}


/**
 *  处理一级m3u8
 *
 *  @param remainData m3u8字符串
 *
 *  @return 里面的子链接
 */
- (NSMutableArray *)handleRankOneM3u8:(NSString *)remainData muSegDict:(NSMutableDictionary *) muSegDict
{
    //获取相对路径的头部路径
    NSString *fatherUrlHead = [self removeLastPathComponent:[muSegDict objectForKey:GlDLURL]];
    
    //处理 max duration
    NSString* maxDuration = @"0";
    NSString *startDuration = @"#EXT-X-TARGETDURATION:";
    NSRange maxRange = [remainData rangeOfString:startDuration];
    if (maxRange.location != NSNotFound)
    {
        remainData = [remainData substringFromIndex:maxRange.location];
        NSRange comRange = [remainData rangeOfString:@"\n"];
        maxDuration = [remainData substringWithRange:NSMakeRange([startDuration length], (comRange.location -[startDuration length]))];
        maxDuration = [maxDuration stringByReplacingOccurrencesOfString:@"," withString:@""];
    }
    
    NSMutableArray *m3u8DictArray = [[NSMutableArray alloc]init];
    NSRange segmentRange = [remainData rangeOfString:@"#EXTINF:"];
    while (segmentRange.location != NSNotFound)
    {
        remainData = [remainData substringFromIndex:segmentRange.location];
        // 读取片段时长
        NSRange commaRange = [remainData rangeOfString:@"\n"];//离#EXTINF 最近的一个换行
        
        //获取#EXTINF 与 换行之间的数字
        NSString* value = [remainData substringWithRange:NSMakeRange([@"#EXTINF:" length], commaRange.location -([@"#EXTINF:" length]))];
        value = [value stringByReplacingOccurrencesOfString:@"," withString:@""];
        value = [value stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        
        /** 截掉上面换行符前面的东西*/
        remainData = [remainData substringFromIndex:commaRange.location + commaRange.length];
        
        // 读取片段url
        NSRange linkRangeEnd = [remainData rangeOfString:@"\n"];
        NSString* linkurl = [remainData substringWithRange:NSMakeRange(0, linkRangeEnd.location)];
        
        NSString *urlTemp = [linkurl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSRange haveHead = [urlTemp rangeOfString:@"http://"];
        if (haveHead.location == NSNotFound)//如果是相对路径
        {
            NSString *nowFatherUrlHead = fatherUrlHead;
            if ([urlTemp hasPrefix:@"../"])
            {
                nowFatherUrlHead = [self removeLastPathComponent:fatherUrlHead];
                
                urlTemp = [urlTemp stringByReplacingOccurrencesOfString:@"../" withString:@""];
            }
            nowFatherUrlHead = [nowFatherUrlHead stringByAppendingString:@"/"];
            urlTemp = [nowFatherUrlHead stringByAppendingString:urlTemp];
        }
        
        remainData = [remainData substringFromIndex:linkRangeEnd.location];
        segmentRange = [remainData rangeOfString:@"#EXTINF:"];
        
        NSDictionary *dictM = [[NSDictionary alloc] initWithObjectsAndKeys:value,GlDURATION,urlTemp,GlURL,maxDuration,GlM3U8MaxDuration, nil];
        [m3u8DictArray addObject:dictM];
    }
    NSLog(@"解析好的一级m3u8数据：%@",m3u8DictArray);
    return m3u8DictArray;
}


/**
 *  有两级的m3u8
 *
 *  @param remainData m3u8内容
 *  @param fatherUrl  父链接
 */
- (void)handleRankTwoM3u8:(NSString *)remainData muSegDict:(NSMutableDictionary *) muSegDict complete:(void(^)(NSMutableArray *m3u8Array))complete
{
    //获取相对路径的头部路径
    NSString *fatherUrlHead = [self removeLastPathComponent:[muSegDict objectForKey:GlDLURL]];
    
    NSMutableArray *segArray = [[NSMutableArray alloc] init];
    NSRange segmentRange = [remainData rangeOfString:@"#EXT-X-STREAM-INF:"];
    
    while (segmentRange.location != NSNotFound && segmentRange.length > 0 )
    {
        remainData = [remainData substringFromIndex:segmentRange.location + segmentRange.length];
        // 读取片段url
//        NSRange linkRangeBegin = [remainData rangeOfString:@"../"];//有些有这个头部
//        if (linkRangeBegin.location == NSNotFound || linkRangeBegin.length <= 0)
//        {
           NSRange linkRangeBegin = [remainData rangeOfString:@"\n"];
            linkRangeBegin = NSMakeRange(linkRangeBegin.location + linkRangeBegin.length, 0);
        remainData = [remainData substringFromIndex:linkRangeBegin.location + linkRangeBegin.length];
//        }
        
        //获取url
        NSRange linkRangeEnd = [remainData rangeOfString:@"\n"];//.m3u8
        NSInteger linkStart = 0;//链接的起始坐标
        NSInteger linkLenght = linkRangeEnd.location;//链接的长度
        if (linkRangeEnd.location == NSNotFound)//链接中未有.m3u8标识
        {
            NSLog(@"二级的m3u8解析出错");
            break;
        }
        
        NSString* linkurl = [remainData substringWithRange:NSMakeRange(linkStart, linkLenght)];
        
        NSString *urlTemp = [linkurl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSRange haveHead = [urlTemp rangeOfString:@"http://"];
        if (haveHead.location == NSNotFound)//如果是相对路径
        {
            NSString *nowFatherUrlHead = fatherUrlHead;
            if ([urlTemp hasPrefix:@"../"])
            {
                nowFatherUrlHead = [self removeLastPathComponent:fatherUrlHead];
                
                urlTemp = [urlTemp stringByReplacingOccurrencesOfString:@"../" withString:@""];
            }
            nowFatherUrlHead = [nowFatherUrlHead stringByAppendingString:@"/"];
           urlTemp = [nowFatherUrlHead stringByAppendingString:urlTemp];
        }
        
        if (!urlTemp)
        {
            urlTemp = @"http://error";
        }
        NSMutableDictionary *newSegDict = [[NSMutableDictionary alloc] initWithDictionary:muSegDict];
        [newSegDict setObject:urlTemp forKey:GlDLURL];
        [segArray addObject:newSegDict];
        
        remainData = [remainData substringFromIndex:linkRangeEnd.location];
        segmentRange = [remainData rangeOfString:@"#EXT-X-STREAM-INF:"];
    }
    [self comBinateRankTwoDictArray:segArray muSegDict:muSegDict];
    
    //递归得到该文件里面所有的m3u8子链接
    NSMutableArray *rankTwoArray = [[NSMutableArray alloc] init];
    [self circleHandleWithSegArray:segArray curIndex:0 completeArray:rankTwoArray complete:^(NSMutableArray *m3u8Array)
     {
         NSLog(@"一个链接的所有子链接处理完成");
         NSMutableArray *smallAllArray = [[NSMutableArray alloc] init];
         for (NSDictionary *dict in m3u8Array)
         {
             NSArray *smallNOw = [dict objectForKey:@"m3u8Array"];
             [smallAllArray addObjectsFromArray:smallNOw];
         }
         complete(smallAllArray);
     }];
}


//将给数组中的对象平均分配大小和时长
- (void)comBinateRankTwoDictArray:(NSMutableArray *)segArray muSegDict:(NSMutableDictionary *) muSegDict
{
    //服务器传过来的大小
    long long size = [[muSegDict objectForKey:@"size"] longLongValue] / (float)[segArray count];
    //平均计算每个子文件的时长
    long long seconds = [[muSegDict objectForKey:@"seconds"] longLongValue] / (float)[segArray count];
    for (NSMutableDictionary *segDict in segArray)
    {
        [segDict setObject:[NSNumber numberWithLongLong:size] forKey:@"size"];
        [segDict setObject:[NSNumber numberWithLongLong:seconds] forKey:@"seconds"];
    }
}

/*
//获取父链接的头部
- (NSString *)getHeadOfFatherUrl:(NSString *)fatherUrl
{
    NSString *lastPart = [fatherUrl lastPathComponent];
    NSString *headUrl = [fatherUrl stringByReplacingOccurrencesOfString:lastPart withString:@""];

//    if (!pathType || [pathType isEqualToString:@"./"])//当前目录
//    {
//         headUrl = [self removeLastPathComponent:fatherUrl];
//    }
//    else if ([pathType isEqualToString:@"../"])//父级目录
//    {
//        headUrl = [self removeLastPathComponent:fatherUrl];
//        headUrl = [self removeLastPathComponent:headUrl];
//    }
    return headUrl;
}
*/

/**
 *  移除链接的最后的组成部分
 *
 *  @param fatherUrl 完成路径
 *
 *  @return 移除后的路径
 */
- (NSString *)removeLastPathComponent:(NSString *)fatherUrl
{
    if (!fatherUrl)
    {
        return @"";
    }
    NSRange range = [fatherUrl rangeOfString:@"/" options:NSBackwardsSearch];
    NSString  *headUrl = [fatherUrl substringToIndex:range.location];
    return headUrl;
}


@end
