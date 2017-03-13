//
//  M3u8Parser.m
//  Wi-Fi_Disk
//
//  Created by dsw on 16/9/5.
//  Copyright © 2016年 LiuMaoWen. All rights reserved.
//

#import "M3u8Parser.h"
#import "AFNetworking.h"
#import "GlCommMethod.h"

@interface M3u8Parser ()
@property (nonatomic, retain)AFHTTPRequestOperationManager * managerAf;
@end
@implementation M3u8Parser
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _managerAf= [AFHTTPRequestOperationManager manager];
        _managerAf.requestSerializer = [AFHTTPRequestSerializer serializer];
        _managerAf.responseSerializer = [AFHTTPResponseSerializer serializer];
    }
    return self;
}
- (void)m3u8ParserWithUrl:(NSString *)m3u8Url
{
    //请求m3u8文件
    [_managerAf GET:m3u8Url parameters:nil success:^(AFHTTPRequestOperation * _Nonnull operation, id  _Nonnull responseObject)
     {
         NSString *str=[[NSString alloc]initWithData:responseObject encoding:NSUTF8StringEncoding];
         NSLog(@"responseObject---responseObject:%@",str);
         
         
     } failure:^(AFHTTPRequestOperation * _Nonnull operation, NSError * _Nonnull error)
     {
         NSLog(@"error:%@",error);
     }];
}

+ (NSString *)createLocalM3U8fileWithModel:(GlDownLoadTaskModel *)taskmodel httpHead:(NSString *)httpHead
{
    
    if ([GlCommMethod isNUllObject:httpHead])
    {
        httpHead = @"";
    }
    
    NSString *taskName = [GlCommMethod getFileNameNoFormat:[taskmodel getShowName]];
    NSString *fileName = [NSString stringWithFormat:@"%@.m3u8",taskName];
    NSString * newSavePath = [taskmodel getNewSavePath];
    NSString *fullpath = [newSavePath stringByAppendingPathComponent:fileName];
    NSLog(@"createLocalM3U8file:%@",fullpath);
    
    //NSRange range = [newSavePath rangeOfString:@"/Documents/"];
    //NSString * siteName = [newSavePath substringFromIndex:(range.location + range.length)];
    NSString *maxDuration = @"500";
    if ([taskmodel.requestTasks count] > 0)
    {
        GlDownTask *task0 = [taskmodel.requestTasks firstObject];
        NSString *nowMax = [task0.m3u8Dict objectForKey:GlM3U8MaxDuration];
        if ([nowMax integerValue] > 0)
        {
            maxDuration = nowMax;
        }
    }
    
    //创建文件头部
    NSString* head = [NSString stringWithFormat:@"#EXTM3U\n#EXT-X-TARGETDURATION:%@\n#EXT-X-VERSION:3\n",maxDuration];
    NSString* segmentPrefix = httpHead;
    
    //填充片段数据
    for(int i = 0;i< [taskmodel.requestTasks count];i++)
    {
        GlDownTask * task = taskmodel.requestTasks[i];
        NSString* filename = [task getFileName];
        CGFloat duration = [[task.m3u8Dict objectForKey:GlDURATION] floatValue];
        NSString *durationStr = [task.m3u8Dict objectForKey:GlDURATION];
        if (duration < 1)
        {
            duration = task.seconds;
            durationStr = [NSString stringWithFormat:@"%.1f",duration];
        }
        NSString* length = [NSString stringWithFormat:@"#EXTINF:%@,\n",durationStr];
        
        NSString* url = [segmentPrefix stringByAppendingString:filename];
        head = [NSString stringWithFormat:@"%@%@%@\n",head,length,url];
    }
    //创建尾部
    NSString* end = @"#EXT-X-ENDLIST";
    head = [head stringByAppendingString:end];
    NSMutableData *writer = [[[NSMutableData alloc] init] autorelease];
    [writer appendData:[head dataUsingEncoding:NSUTF8StringEncoding]];
    
    BOOL bSucc =[writer writeToFile:fullpath atomically:YES];
    if(bSucc)
    {
        NSLog(@"create m3u8file succeed; fullpath:%@, content:%@",fullpath,head);
        return fullpath;
    }
    else
    {
        NSLog(@"create m3u8file failed");
        return nil;
    }
}
@end
