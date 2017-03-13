//
//  ParserPluginsHandle.h
//  PlayerWebURLDemo
//
//  Created by huangxianchao on 16/6/16.
//  Copyright © 2016年 liguanglei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebViewJavascriptBridge.h"
#import "WebStatusDelegate.h"
#import "AFNetworking.h"
#import "GlDownLoadTaskModel.h"
#import "GlCommMethod.h"


typedef void (^ConnectionProgressBlock)(NSUInteger bytes, long long totalBytes, long long totalBytesExpected);
typedef void (^CompleteParserM3u8)(NSMutableArray *m3u8Array);


@interface ParserPluginsHandle : NSObject 

//@property WebViewJavascriptBridge* bridge;
@property(nonatomic,assign) WebViewJavascriptBridge* bridge;

//插件处理情况状态通知代理
@property(nonatomic,assign)id<WebStatusDelegate> delegate;

@property (nonatomic,strong) NSArray *originArray;//只有ID的源数组

@property (nonatomic,strong) NSMutableArray * taskArray;//有下载要的url的数组

@property (nonatomic,copy) NSString *homeUrl;//首页网址
@property (nonatomic,copy) NSString *siteName;//站点名
@property (nonatomic, assign)NSInteger curSendIdIndex;  //当前发送的id序号
@property (nonatomic, copy) NSString *curPlugUrl;//当前加载的插件的Url
@property (nonatomic, copy) NSString * thisRequestDataUrl;//本次请求的数据对应的链接
@property (nonatomic, copy) CompleteParserM3u8 completeParserM3u8;// m3u8解析完成
@property (nonatomic, assign) GlFileType defaultFileType;//默认文件类型
@property (nonatomic, assign) NSInteger repeatTimes;//从复嗅探的次数
@property (nonatomic, assign) BOOL isAbroad;//是否国外网站
@property (nonatomic, assign) long nowShowCount;


//注册桥接
-(void)registerHandleBridge;
//收到数据
-(void)receiveDatahandle:(id) data;

-(NSString *)loadJSFromLocalFileWithName:(NSString *)name;

//加载插件,url当前加载插件页面的url，非插件url
- (void)loadJSFromLocalFileWithUrl:(NSString *)url complete:(void(^)(NSString *scriptData))complete;

//从网络获取JS插件
- (void)loadJSFromNetWithName:(NSString *)name complete:(void(^)(NSString *scriptData))complete ;
//获取保存地址
- (NSString *)getSavePathWithSite:(NSString *) siteName;

//判断资源是否可用，可用则发送通知并加入数组
- (void)judgeSourceIsAvailableWithModel:(GlDownLoadTaskModel *)taskModel count:(NSInteger)count;

//发送通知未找到资源
-(void)notificationNoData;


/**
 *  服务器获取该链接的下载链接
 *
 *  @param url 页面链接
 */
//- (void)requestToServiceWithPageUrl:(NSString *)url complete:(void(^)(NSDictionary *scriptData))complete;


/**
 *  解析真实地址
 *
 *  @param array 待解析的数组
 */
- (void)handleGetRealUrlWithArray:(NSArray *)array;

//-(NSString *)getDownLoadPathByURL:(NSString *)url taskID:(NSString *) taskID webSite:(NSString *)webSite ;


/**
 *  处理服务器发来的m3u8数组
 *
 *  @param segArray 服务器获取的m3u8链接数组
 *  @param complete 完成
 */
- (void)handleM3u8WithSegArray:(NSArray *)segArray complete:(void(^)(NSMutableArray *m3u8Array))complete;


/**
 *  解析m3u8请求链接获取字典数据
 *
 *  @param m3u8Url  m3u8链接
 *  @param complete 完成回掉
 */
-(void)handleM3u8WithUrl:(NSString *) m3u8Url complete:(void(^)(NSMutableArray *m3u8Array))complete;

/**
 *  重复的数据通知直接完成
 */
- (void)notificationCompleteNoChange;
@end
