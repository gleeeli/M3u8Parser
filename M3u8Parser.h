//
//  M3u8Parser.h
//  Wi-Fi_Disk
//
//  Created by dsw on 16/9/5.
//  Copyright © 2016年 LiuMaoWen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GlDownLoadTaskModel.h"

@interface M3u8Parser : NSObject
+ (NSString *)createLocalM3U8fileWithModel:(GlDownLoadTaskModel *)taskmodel httpHead:(NSString *)httpHead;
@end
