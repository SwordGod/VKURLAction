//
//  VKRoute.m
//  Yuedu
//
//  Created by Awhisper on 16/6/3.
//  Copyright © 2016年 baidu.com. All rights reserved.
//

#import "VKURLParser.h"
#import "VKMediatorAction.h"
#include <CommonCrypto/CommonCrypto.h>

static NSString *_vkInstanceMethodURL = @"instanceMethodURL";


@implementation NSURL (VKURL)

- (NSURL *)addParams:(NSDictionary *)params {
    NSMutableString *_add = nil;
    if (NSNotFound != [self.absoluteString rangeOfString:@"?"].location) {
        _add = [NSMutableString stringWithString:@"&"];
    }else {
        _add = [NSMutableString stringWithString:@"?"];
    }
    for (NSString* key in [params allKeys]) {
        if ([params objectForKey:key] && 0 < [[params objectForKey:key] length]) {
            [_add appendFormat:@"%@=%@&",key,[[params objectForKey:key] urlencode]];
        }
    }
    
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",
                                 self.absoluteString,
                                 [_add substringToIndex:[_add length] - 1]]];
}

- (NSDictionary *)params {
    NSMutableDictionary* pairs = [NSMutableDictionary dictionary];
    if (NSNotFound != [self.absoluteString rangeOfString:@"?"].location) {
        NSString *paramString = [self.absoluteString substringFromIndex:
                                 ([self.absoluteString rangeOfString:@"?"].location + 1)];
        NSCharacterSet* delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@"&"];
        NSScanner* scanner = [[NSScanner alloc] initWithString:paramString];
        while (![scanner isAtEnd]) {
            NSString* pairString = nil;
            [scanner scanUpToCharactersFromSet:delimiterSet intoString:&pairString];
            [scanner scanCharactersFromSet:delimiterSet intoString:NULL];
            NSArray* kvPair = [pairString componentsSeparatedByString:@"="];
            if (kvPair.count == 2) {
                NSString* key = [[kvPair objectAtIndex:0] urldecode];
                NSString* value = [[kvPair objectAtIndex:1] urldecode];
                [pairs setValue:value forKey:key];
            }
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:pairs];
}

@end






@implementation NSString (VKURLString)

#pragma mark MD5
-(NSString *)vkMD5HexDigest
{
    const char *original_str = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(original_str, strlen(original_str),result);
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < 16 ; i ++ ) {
        [hash appendFormat:@"%02x", result[i]];
    }
    return [hash lowercaseString];
}

- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions)options {
    NSRange rng = [self rangeOfString:string options:options];
    return rng.location != NSNotFound;
}

- (BOOL)containsString:(NSString *)string {
    return [self containsString:string options:0];
}

- (NSString *)urldecode {
    return [self stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)urlencode {
    NSString *encUrl = [self stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSUInteger len = [encUrl length];
    const char *c;
    c = [encUrl UTF8String];
    NSString *ret = @"";
    for(int i = 0; i < len; i++) {
        switch (*c) {
            case '~':
                ret = [ret stringByAppendingString:@"%7E"];
                break;
            case '/':
                ret = [ret stringByAppendingString:@"%2F"];
                break;
            case '\'':
                ret = [ret stringByAppendingString:@"%27"];
                break;
            case ';':
                ret = [ret stringByAppendingString:@"%3B"];
                break;
            case '?':
                ret = [ret stringByAppendingString:@"%3F"];
                break;
            case ':':
                ret = [ret stringByAppendingString:@"%3A"];
                break;
            case '@':
                ret = [ret stringByAppendingString:@"%40"];
                break;
            case '&':
                ret = [ret stringByAppendingString:@"%26"];
                break;
            case '=':
                ret = [ret stringByAppendingString:@"%3D"];
                break;
            case '+':
                ret = [ret stringByAppendingString:@"%2B"];
                break;
            case '$':
                ret = [ret stringByAppendingString:@"%24"];
                break;
            case ',':
                ret = [ret stringByAppendingString:@"%2C"];
                break;
            case '[':
                ret = [ret stringByAppendingString:@"%5B"];
                break;
            case ']':
                ret = [ret stringByAppendingString:@"%5D"];
                break;
            case '#':
                ret = [ret stringByAppendingString:@"%23"];
                break;
            case '!':
                ret = [ret stringByAppendingString:@"%21"];
                break;
            case '(':
                ret = [ret stringByAppendingString:@"%28"];
                break;
            case ')':
                ret = [ret stringByAppendingString:@"%29"];
                break;
            case '*':
                ret = [ret stringByAppendingString:@"%2A"];
                break;
            default:
                ret = [ret stringByAppendingFormat:@"%c", *c];
        }
        c++;
    }
    
    return ret;
}

@end



@interface VKURLParser ()


@end

@implementation VKURLParser


-(BOOL)parseURL:(NSURL *)url toAction:(NSString *__autoreleasing*)action toParamDic:(NSDictionary *__autoreleasing*)params;
{
    if (![url.scheme isEqualToString:self.scheme]) {
        return NO;
    }
    
    if (![url.host isEqualToString:self.host]) {
        return NO;
    }
    
    
    NSString *relp = url.relativePath;
    NSArray *pathcomponent = [relp componentsSeparatedByString:@"/"];
    NSString *actionName = pathcomponent.lastObject;
    NSString *actionNamePlus = [actionName stringByAppendingString:@":"];
    
    
    if (actionName && actionName.length > 0 &&
        ([VKMediatorAction instancesRespondToSelector:NSSelectorFromString(actionName)] ||
         [VKMediatorAction instancesRespondToSelector:NSSelectorFromString(actionNamePlus)])) {
        //符合mediatorAction 可以响应的selector 才算action正确
        if (action) {
            *action = actionName;
        }
        
    }else{
        return NO;
    }
    
    NSDictionary *paramInfo = [url params];
    if (params) {
        *params = paramInfo;
    }
    
    
    if (self.signSalt && self.signSalt.length > 0) {
        NSMutableString *checkContent = [[NSMutableString alloc]initWithString:actionName];
        [checkContent appendString:@"_"];
        NSString *md5Sign;
        for (NSString *key in paramInfo.allKeys) {
            if (![key containsString:@"sign"]) {
                [checkContent appendString:key];
                [checkContent appendString:@"_"];
            }else{
                md5Sign = paramInfo[key];
            }
        }
        NSString *content = [NSString stringWithString:checkContent];
        NSString *contentMd5 = [content vkMD5HexDigest];
        if ([contentMd5 isEqualToString:md5Sign]) {
            return YES;
        }else
        {
            return NO;
        }
        
    }else{
        //无签名校验的时候 默认通过check
        return YES;
    }
}

+(void)parseURL:(NSURL *)url
{
    NSURL * urla = [NSURL URLWithString:@"http://localhost:8081/aaaa/index.ios.bundle?platform=ios&dev=true"];
    
    NSString * schema = urla.scheme;
    NSString * name = urla.host;
    NSString *path = urla.path;
    NSString *fra = urla.fragment;
    NSString *qurry = urla.query;
    NSString *rpath = urla.relativePath;
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:urla resolvingAgainstBaseURL:NO];
    NSArray *queryItemsArray = [urlComponents queryItems];
    NSMutableDictionary *queryItems = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in queryItemsArray) {
        [queryItems setObject:item.value forKey:item.name];
        
    }
    
    return;
}

@end
