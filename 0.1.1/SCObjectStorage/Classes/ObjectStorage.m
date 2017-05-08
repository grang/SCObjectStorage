//
//  Network.m
//  SpeedyCloud
//
//  Created by 郭煌 on 2017/4/17.
//  Copyright © 2017年 SpeedyCloud. All rights reserved.
//

#import "ObjectStorage.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>

#import <Foundation/Foundation.h>

@implementation ObjectStorage

@synthesize BASE_SERVER, SECRET_KEY, ACCESS_KEY;
@synthesize SHOW_DEBUG;

-(id) initWithKeySecret:(NSString *)access secret:(NSString *)secret {
    if(self = [super init]) {
        ACCESS_KEY = access;
        SECRET_KEY = secret;
        BASE_SERVER = @"http://cos.speedycloud.org";
        SHOW_DEBUG = YES;
    }
    
    return self;
}

-(NSString *) dateFormat {
    NSTimeInterval interval = 8 * 3600;
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-interval];

    NSDateFormatter *forMatter = [[NSDateFormatter alloc] init];
    [forMatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"];
    
    NSString *dateStr = [forMatter stringFromDate:date];
    NSString *result = [NSString stringWithFormat:@"%@ GMT", dateStr];
        
    return result;
}

-(NSString *) genSigStr:(NSDictionary *)params {
    NSString *result = @"";
    
    NSString *http_method = params[@"http_method"];
    if(http_method != nil) {
        result = [NSString stringWithFormat:@"%@", http_method];
    }
    
    NSString *content_md5 = params[@"content_md5"];
    if(content_md5 == nil) {
        content_md5 = @"";
    }
    result = [NSString stringWithFormat:@"%@\n%@", result, content_md5];
    
    NSString *content_type = params[@"content_type"];
    if(content_type == nil) {
        content_type = @"";
    }
    result = [NSString stringWithFormat:@"%@\n%@", result, content_type];

    
    result = [NSString stringWithFormat:@"%@\n%@", result, [self dateFormat]];
    
    NSString *canonicalized_amz_headers = params[@"canonicalized_amz_headers"];
    if(canonicalized_amz_headers != nil) {
        result = [NSString stringWithFormat:@"%@\n%@", result, canonicalized_amz_headers];
    }
    
    result = [NSString stringWithFormat:@"%@\n/%@", result, params[@"url"]];
    if(self.SHOW_DEBUG) {
        NSLog(@"%@", result);
    }
    return result;
}

-(NSString *) hmacsha1:(NSString *)str {
    const char *cKey  = [self.SECRET_KEY cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [str cStringUsingEncoding:NSASCIIStringEncoding];

    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    NSString *hash = [HMAC base64EncodedStringWithOptions:0];
    
    return hash;
}

-(NSString *) genSig:(NSString *)method params:(NSMutableDictionary *)params{
    NSString *canonicalized_amz_headers = @"";
    
    NSString *amz = params[@"x-amz-acl"];
    if(amz != nil) {
        canonicalized_amz_headers = [NSString stringWithFormat:@"x-amz-acl:%@", amz];
        params[@"canonicalized_amz_headers"] = canonicalized_amz_headers;
    }
    
    NSString *sigStr = [self genSigStr:params];
    NSString *result = [self hmacsha1:sigStr];
    
    return result;
}

-(NSDictionary *) generateHeaders:(NSString *)method params:(NSDictionary *)params isJson:(BOOL)isJson{
    NSString *dateStr = [self dateFormat];
    NSString *sign = [self genSig:method params:params];
    
    if(self.SHOW_DEBUG) {
        NSLog(@"sign is %@", sign);
    }
    
    NSString *authorization = [NSString stringWithFormat:@"AWS %@:%@", self.ACCESS_KEY, sign];
    NSMutableDictionary *header_data = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                        dateStr, @"Date",
                                        authorization, @"Authorization",
                                        nil];
    
    NSString *acl = params[@"x-amz-acl"];
    if(acl != nil) {
        header_data[@"x-amz-acl"] = acl;
    }
    
    NSString *content_length = params[@"content_length"];
    if(content_length != nil) {
        header_data[@"Content-Length"] = content_length;
    }
    
    
    NSString *content_type = params[@"content_type"];
    if(content_type != nil) {
        header_data[@"Content-Type"] = content_type;
    }
    
    if(isJson) {
        header_data[@"Accept-Encoding"] = @"";
    }
    
    return header_data;
}

-(NSString *) request:(NSString *)path method:(NSString *) method params:(NSMutableDictionary *)params data:(NSData *)data isJson:(BOOL)isJson {
    NSString *urlStr = [NSString stringWithFormat:@"%@/%@", self.BASE_SERVER, path];
    if(self.SHOW_DEBUG) {
        NSLog(@"request url is %@", urlStr);
    }
    
    if(isJson) {
        if([urlStr containsString:@"?"]) {
            urlStr = [NSString stringWithFormat:@"%@&ctype=json", urlStr];
        } else {
            urlStr = [NSString stringWithFormat:@"%@?ctype=json", urlStr];
        }
    }
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setHTTPMethod:method];
    
    if(data != nil) {
        [req setHTTPBody:data];
    }
    NSDictionary *headers = [self generateHeaders:method params:params isJson:isJson];
    
    for(NSString *key in headers) {
        NSString *value = [headers objectForKey:key];
        [req addValue:value forHTTPHeaderField:key];
        
        if(self.SHOW_DEBUG) {
            NSLog(@"%@: %@", key, value);
        }
    }
    
    
    NSData *res = [NSURLConnection sendSynchronousRequest:req returningResponse:NULL error:NULL];
    NSString *myString = [[NSString alloc] initWithData:res encoding:NSUTF8StringEncoding];
    
    if(self.SHOW_DEBUG) {
        NSLog(@"response %@", myString);
    }
    return myString;
}

-(NSString *) doRequest:(NSString *)path method:(NSString *)method extends:(NSDictionary *)extends data:(NSData *)data isJson:(BOOL)isJson {
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                            path, @"url",
                            method, @"http_method",
                            nil];
    if(extends != nil) {
        [params addEntriesFromDictionary:extends];
    }
    
    return [self request:path method:method params:params data:data isJson:isJson];
}

// 创建桶
- (NSString *) createBucket:(NSString *)bucket isJson:(BOOL)isJson {
    return [self doRequest:bucket method:@"PUT" extends:nil data:nil isJson:isJson];
}

// 删除桶
- (NSString *) deleteBucket:(NSString *)bucket isJson:(BOOL)isJson{
    return [self doRequest:bucket method:@"DELETE" extends:nil data:nil isJson:isJson];
}

// 查询桶存储桶的权限
- (NSString *) queryBucketAcl:(NSString *)bucket isJson:(BOOL)isJson {
    NSString *bucketStr = [NSString stringWithFormat:@"%@?acl", bucket];
    return [self doRequest:bucketStr method:@"GET" extends:nil data:nil isJson:isJson];
}

// 修改存储桶的权限
- (NSString *) updateBucketAcl:(NSString *)bucket acl:(NSString *)acl isJson:(BOOL)isJson {
    if([acl isEqualToString:@"private"] || [acl isEqualToString:@"public-read"] || [acl isEqualToString:@"public-read-write"]) {
        NSDictionary *extends = [[NSDictionary alloc] initWithObjectsAndKeys:acl, @"x-amz-acl", nil];
        NSString *bucketStr = [NSString stringWithFormat:@"%@?acl", bucket];
        
        return [self doRequest:bucketStr method:@"PUT" extends:extends data:nil isJson:isJson];
    }
    return nil;
}

// 设置存储桶的版本控制
- (NSString *) setBucketVersioning:(NSString *)bucket status:(NSString *)status isJson:(BOOL)isJson {
    if([status isEqualToString:@"Enabled"] || [status isEqualToString:@"Suspended"]) {
        NSString *bucketStr = [NSString stringWithFormat:@"%@?versioning", bucket];
        
        NSString *body =[NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<VersioningConfiguration xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">\n<Status>%@</Status>\n</VersioningConfiguration>", status];
        NSData *data = [body dataUsingEncoding:NSASCIIStringEncoding];

        return [self doRequest:bucketStr method:@"PUT" extends:nil data:data isJson:isJson];
    }
    return nil;
}

// 查询存储桶的版本信息
- (NSString *) queryBucketVersioning:(NSString *)bucket isJson:(BOOL)isJson {
    NSString *path = [NSString stringWithFormat:@"%@?versioning", bucket];
    return [self doRequest:path method:@"GET" extends:nil data:nil isJson:isJson];
}


// 在存储桶内创建对象（上传小文件，小于100M）
- (NSString *) createObject:(NSString *)bucket key:(NSString *)key data:(NSData *)data isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@", bucket, key];
    
    NSString *length = [NSString stringWithFormat:@"%lu", data.length];
    NSDictionary *extends = [[NSDictionary alloc] initWithObjectsAndKeys:@"application/x-www-form-urlencoded", @"content_type", length, @"content_length", nil];

    return [self doRequest:path method:@"PUT" extends:extends data:data isJson:isJson];
}

// 删除存储桶内的对象
- (NSString *) deleteObject:(NSString *)bucket key:(NSString *)key isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@", bucket, key];
    return [self doRequest:path method:@"DELETE" extends:nil data:nil isJson:isJson];
}

// 查询存储桶内所有对象的版本信息
- (NSString *) queryObjectVersions:(NSString *)bucket isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@?versions", bucket];
    return [self doRequest:path method:@"GET" extends:nil data:nil isJson:isJson];
}

// 删除存储桶内指定版本的对象
- (NSString *) deleteObjectVersion:(NSString *)bucket key:(NSString *)key version:(NSString *)version isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@?versionId=%@", bucket, key, version];
    return [self doRequest:path method:@"DELETE" extends:nil data:nil isJson:isJson];
}

// 查询存储桶内的对象的权限
- (NSString *) queryObjectAcl:(NSString *)bucket key:(NSString *)key isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@?acl", bucket, key];
    return [self doRequest:path method:@"GET" extends:nil data:nil isJson:isJson];
}

// 修改存储桶内对象的权限
- (NSString *) updateObjectAcl:(NSString *)bucket key:(NSString *)key acl:(NSString *)acl isJson:(BOOL)isJson {
    if([acl isEqualToString:@"private"] || [acl isEqualToString:@"public-read"] || [acl isEqualToString:@"public-read-write"]) {
        NSDictionary *extends = [[NSDictionary alloc] initWithObjectsAndKeys:acl, @"x-amz-acl", nil];
        NSString *path = [NSString stringWithFormat:@"%@/%@?acl", bucket, key];

        return [self doRequest:path method:@"PUT" extends:extends data:nil isJson:isJson];
    }
    return nil;
}

// 修改存储桶内指定版本的对象的权限
- (NSString *) updateObjectVersionAcl:(NSString *)bucket key:(NSString *)key version:(NSString *)version acl:(NSString *)acl isJson:(BOOL)isJson{
    if([acl isEqualToString:@"private"] || [acl isEqualToString:@"public-read"] || [acl isEqualToString:@"public-read-write"]) {
        NSDictionary *extends = [[NSDictionary alloc] initWithObjectsAndKeys:acl, @"x-amz-acl", nil];
        NSString *path = [NSString stringWithFormat:@"%@/%@?acl&versionId=%@", bucket, key, version];
        
        return [self doRequest:path method:@"PUT" extends:extends data:nil isJson:isJson];
    }
    return nil;
}

// 查询存储桶内所有对象
- (NSString *) queryAllObjects:(NSString *)bucket isJson:(BOOL)isJson{
    return [self doRequest:bucket method:@"GET" extends:nil data:nil isJson:isJson];
}

// 下载存储桶内的对象
-(NSString *) downloadObject:(NSString *)bucket key:(NSString *)key isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@", bucket, key];
    return [self doRequest:path method:@"GET" extends:nil data:nil isJson:isJson];
}

// 大数据上传(步骤一)
-(NSString *) uploadBigObjectStep1:(NSString *)bucket key:(NSString *)key isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@?uploads", bucket, key];
    return [self doRequest:path method:@"POST" extends:nil data:nil isJson:isJson];
}

// 大数据上传(步骤二)
-(NSString *) uploadBigObjectStep2:(NSString *)bucket key:(NSString *)key step:(NSUInteger *)step uploadId:(NSString *)uploadId data:(NSData *)data isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@?partNumber=%ld&uploadId=%@", bucket, key, step, uploadId];
    NSDictionary *extends = [[NSDictionary alloc] initWithObjectsAndKeys:@"application/x-www-form-urlencoded", @"content_type", nil];

    return [self doRequest:path method:@"PUT" extends:extends data:data isJson:isJson];
}

//  大数据上传(步骤三)
-(NSString *) uploadBigObject3:(NSString *)bucket key:(NSString *)key uploadId:(NSString *)uploadId data:(NSData *)data isJson:(BOOL)isJson{
    NSString *path = [NSString stringWithFormat:@"%@/%@?uploadId=%@", bucket, key, uploadId];
    
    NSString *length = [NSString stringWithFormat:@"%lu", data.length];
    NSDictionary *extends = [[NSDictionary alloc] initWithObjectsAndKeys:@"application/x-www-form-urlencoded", @"content_type", length, @"content_length", nil];
    
    return [self doRequest:path method:@"POST" extends:extends data:data isJson:isJson];
}
@end
