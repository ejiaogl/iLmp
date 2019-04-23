//
//  ILSystemController.m
//  iLmp-gui7-www
//
//  Created by CmST0us on 15/7/23.
//  Copyright (c) 2015年 CmST0us. All rights reserved.
//

#import "ILSystemController.h"
#import "ILDefine.h"
#import "NSString+AES256.h"
#import "UIDevice+MobileGestaltCategory.h"
#import <objc/runtime.h>
#import "NSTask.h"
@implementation ILSystemController
+(NSTask*)task{
    NSTask * task = objc_getClass("NSTask");
    
    return task;
}
+(ILCarrier)currentCarrier{
    
    NSString * string = [ILSystemController runShell:@"/bin/ps" withArguments:@[@"aux"]];

    NSError *err;
    NSRegularExpression * regex = [[NSRegularExpression alloc]initWithPattern:@"(?<=nginx-).*(?=.conf)" options:0 error:&err];
    if (!regex) {
        return ILError;
    }
    
    NSTextCheckingResult * firstMatch = [regex firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    if (firstMatch) {
        NSRange resultRange = [firstMatch rangeAtIndex:0];
        NSString * result = [string substringWithRange:resultRange];
        if ([result compare:@"uni"] == NSOrderedSame) {
            return  ILUnionCarrier;
        }
        if ([result compare:@"cmcc"] == NSOrderedSame){
            return ILCmccCarrier;
        }
    }
    return ILError;
    
}
+(ILCarrier)lastCarrier{
    NSDictionary * profileDict = [[NSDictionary alloc]initWithContentsOfFile:kILProfilePath];
    NSString * lastCarrier = [profileDict objectForKey: kILCarrierDictionaryKey];
    if ([lastCarrier compare:kILUnionDictionaryValue]==NSOrderedSame) {
        return ILUnionCarrier;
    }else if([lastCarrier compare:kILCmccDictionaryValue]==NSOrderedSame){
        return ILCmccCarrier;
    }else{
        return ILUnionCarrier;
    }
}

+(void)startNginxWithCarrier:(ILCarrier)carrier{
    if (carrier == ILCmccCarrier) {
        NSString * launchCMD = [[NSString alloc]initWithFormat:@"%@ -p %@ -c %@",kILNginxBinPath,kILNginxPrefixPath,kILNginxCmccConfPath];
        system([launchCMD cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    if (carrier == ILUnionCarrier) {
        NSString * launchCMD = [[NSString alloc]initWithFormat:@"%@ -p %@ -c %@",kILNginxBinPath,kILNginxPrefixPath,kILNginxUniConfPath];
        system([launchCMD cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}
+(void)startPhp{
    NSString *launchCMD = [[NSString alloc]initWithFormat:@"%@ -p %@ -R",kILPhpBinPath,kILPhpPrefixPath];
    system([launchCMD cStringUsingEncoding:NSUTF8StringEncoding]);
}
+(void)stopNginx{
    system("killall -9 nginx");
}
+(void)stopPhp{
    system("killall -9 php-fpm");
}

+(NSString * )currentAPN{
    NSString * t1 = [[NSString alloc]initWithContentsOfFile:@"/var/Managed Preferences/mobile/com.apple.managedCarrier.plist" encoding:NSUTF8StringEncoding error:nil];
    if (t1 .length > 0) {
        NSDictionary * t2 = [[NSDictionary alloc]initWithContentsOfFile:@"/var/Managed Preferences/mobile/com.apple.managedCarrier.plist"];
        NSArray * t4 = [t2 objectForKey:@"apns"];
        NSDictionary * t5 = [t4 objectAtIndex:0];
        NSString * APN = [t5 objectForKey:@"apn"];
        return APN;
    }else{
        return [[ILPreferenceFileController alloc]initWithPreferenceAtPath:kILPreferencePath].apn;
    }
    
}

    /*
    |||||||||||||||||||||||||||
    ||          检查Key       ||
    |||||||||||||||||||||||||||
                  |
    |||||||||||||||||||||||||||
    ||          检查代理      ||
    |||||||||||||||||||||||||||
                  |
    |||||||||||||||||||||||||||
    ||         检查nginx      ||
    |||||||||||||||||||||||||||
                  |
    |||||||||||||||||||||||||||
    ||         检查php        ||
    |||||||||||||||||||||||||||
                  |
    |||||||||||||||||||||||||||
    ||        检查守护        ||
    |||||||||||||||||||||||||||
                |
                    如果没有错误->        返回ILOKState
                |
                    如果有错误 ->        goto ERROR
     ERROR:
            return ILError;
     
     */

+(ILState)checkKey{
    //打开配置文件
    @try {
        NSDictionary *profile = [[NSDictionary alloc]initWithContentsOfFile:kILProfilePath];
        if ([profile count] == 0) {
            return ILActiceNeedKeyState;
        }
        NSString *value = [profile objectForKey:kILKeyDictionaryKey];
        if ([value length] == 0) {
            return ILActiceNeedKeyState;
        }
        
        //AES反向解密
        
        char first = 'T'-1;
        char secend = '1'+1;
        char third = '#';
        char forth = 'J'+1;
        char fifth = 'y'+1;
        char sixth = 'u';
        char seventh = '~';
        char eighth = '!';
        
        NSString * t =[NSString stringWithFormat:@"%c%c%c%c%c%c%c%c",first,secend,third,forth,fifth,sixth,seventh,eighth];
        NSString * decryptString=[value aes256_decrypt:t];
        
        NSArray *t_a1 = [decryptString componentsSeparatedByString:@"||"];
        UIDevice *currentDevice = [UIDevice currentDevice];
        NSString *udid=[currentDevice UDID];
        double timeNowDouble = [NSDate date].timeIntervalSince1970;
        long long timeNow = [NSNumber numberWithDouble:timeNowDouble].longLongValue;
        long long timeFaild =[[t_a1 objectAtIndex:1]longLongValue];
        NSString *waitForConfirmUDID = [t_a1 objectAtIndex:0];
        if ([udid length]!=0&&[udid compare:waitForConfirmUDID]==NSOrderedSame) {
            if (timeNow<=timeFaild) {
                return ILActiveOKState;
            }else{
                return ILActiveTimeFaildState;
            }
        }else{
            return ILActiveUDIDFailedState;
        }

    }
    @catch (NSException *exception) {
        return ILActiveUDIDFailedState;
    }
    @finally {
        
    }
    
}
+(ILState)checkProxy{
    NSDictionary *tDict1 = [[ILPreferenceFileController alloc]initWithPreferenceAtPath:kILPreferencePath].proxyDict;
    int powerHTTP = [[tDict1 objectForKey:@"HTTPEnable"]intValue];
    int powerHTTPS = [[tDict1 objectForKey:@"HTTPSEnable"]intValue];
    
    if (powerHTTP ==1 && powerHTTPS ==1) {
        return ILProxyBothSetState;
    }
    if (powerHTTPS ==1 && powerHTTP ==0 ) {
        return ILProxyHTTPSSetState;
    }
    if (powerHTTP ==1 && powerHTTPS == 0) {
        return ILProxyHTTPSetState;
    }
    if (powerHTTPS == 0 && powerHTTP == 0) {
        return ILProxyUnsetState;
    }
    return ILErrorState;
}
+(ILState)checkNginx{
    if( [ILSystemController currentCarrier] == ILError){
        return ILNginxFailedState;
    }else{
        return ILNginxOKState;
    }

}
+(ILState)checkPhp{

    NSString * string = [ILSystemController runShell:@"/bin/ps" withArguments:@[@"aux"]];
    NSError *err;
    NSRegularExpression * regex = [[NSRegularExpression alloc]initWithPattern:@"/usr/local/php/sbin/php-fpm" options:0 error:&err];
    if (!regex) {
        return ILPhpFailedState;
    }

    NSTextCheckingResult * firstMatch = [regex firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    if (firstMatch) {
        NSRange resultRange = [firstMatch rangeAtIndex:0];
        NSString * result = [string substringWithRange:resultRange];
        if ([result length]>0) {
            return ILPhpOKState;
        }
    }
    return ILPhpFailedState;

}

+(ILState)checkAngel{
    if(![[NSFileManager defaultManager]fileExistsAtPath:@"/usr/libexec/netud"]){
        exit(0);
    }
    
    
    
    NSString * string = [ILSystemController runShell:@"/bin/ps" withArguments:@[@"aux"]];
    NSError *err;
    NSRegularExpression * regex = [[NSRegularExpression alloc]initWithPattern:@"/usr/libexec/netud" options:0 error:&err];
    if (!regex) {
        return ILAngelFailedState;
    }
    
    NSTextCheckingResult * firstMatch = [regex firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    if (firstMatch) {
        NSRange resultRange = [firstMatch rangeAtIndex:0];
        NSString * result = [string substringWithRange:resultRange];
        if ([result length]>0) {
            return ILAngelOKState;
        }
    }
    return ILAngelFailedState;


}


+(void)changAndRefreshProxyWithHTTP:(int)isHTTP
                    HTTPS:(int)isHTTPS{
    ILPreferenceFileController * controller = [[ILPreferenceFileController alloc]initWithPreferenceAtPath:kILPreferencePath];
    
    NSDictionary * proxyDict = [ILPreferenceFileController createAProxyDictWithHTTPEnable:isHTTP HTTPPort:kILHTTPProxyPort HTTPProxy:kILHTTPProxyURL HTTPSEnable:isHTTPS HTTPSPort:kILHTTPSProxyPort HTTPSProxy:kILHTTPSProxyURL];
    controller.proxyDict = proxyDict;
    [controller outputDict];
    
    system("addNetworkInterface > /dev/null");
}
+(NSString*)runShell:(NSString*)shell
       withArguments:(NSArray*)argv{
    NSTask * task = [[NSTask alloc]init];
    [task setLaunchPath:shell];
    [task setArguments:argv];
    
    NSPipe * pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle * file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData * data = [file readDataToEndOfFile];
    NSString * string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}
+(void)chmodAndchownTheWWW{
    system("chmod -R 777 /var/www");
    system("chown -R root:wheel /var/www");
}
+(void)changeApn:(NSString *)apn{
    NSDictionary * tDict = [[NSDictionary alloc]initWithObjectsAndKeys:apn,@"apn", nil];
    NSArray * tArray = [[NSArray alloc]initWithObjects:tDict, nil];
    NSDictionary *apns = [[NSDictionary alloc]initWithObjectsAndKeys:tArray,@"apns", nil];
    [apns writeToFile:@"/var/Managed Preferences/mobile/com.apple.managedCarrier.plist" atomically:YES];
}
+(void)refreshApn{
    system("killall -9 CommCenter");
}
+(void)changeDNS:(NSArray *)DNS{
    ILPreferenceFileController *t_controller = [[ILPreferenceFileController alloc]initWithPreferenceAtPath:kILPreferencePath];
    [t_controller setDNSDict:[ILPreferenceFileController createADNSDict:DNS]];
    [t_controller outputDict];
    
     system("addNetworkInterface > /dev/null");
    
}
+(void)removeDNS{
    ILPreferenceFileController *controller  =[[ILPreferenceFileController alloc]initWithPreferenceAtPath:kILPreferencePath];
    [controller removeCustomDNS];
    [controller outputDict];
    
        system("addNetworkInterface > /dev/null");
}
+(void)changeAndRefreshProxyWithHTTP:(int)isHTTP HTTPProxy:(NSString *)httpProxy HTTPPort:(NSString *)httpPort WithHTTPS:(int)isHTTPS HTTPSProxy:(NSString *)httpsProxy HTTPSPort:(NSString *)httpsPort{
    if ([httpPort length] == 0) {
        httpPort = @"80";
    }
    if ([httpProxy length] == 0) {
        httpProxy  = @"127.0.0.1";
    }
    if (httpsPort.length == 0) {
        httpsPort = @"8001";
    }
    if (httpsProxy.length == 0) {
        httpsProxy =  @"127.0.0.1";
    }
    
    
    
    ILPreferenceFileController * controller = [[ILPreferenceFileController alloc]initWithPreferenceAtPath:kILPreferencePath];
    
    NSDictionary * proxyDict = [ILPreferenceFileController createAProxyDictWithHTTPEnable:isHTTP HTTPPort:[httpPort intValue] HTTPProxy:httpProxy HTTPSEnable:isHTTPS HTTPSPort:[httpsPort intValue] HTTPSProxy:httpsProxy];
    controller.proxyDict = proxyDict;
    [controller outputDict];
    
    system("addNetworkInterface > /dev/null");
}
+(ILState)checkHaproxy{
    NSString * string = [ILSystemController runShell:@"/bin/ps" withArguments:@[@"aux"]];
    NSError *err;
    NSRegularExpression * regex = [[NSRegularExpression alloc]initWithPattern:@"/usr/local/haproxy/sbin/haproxy" options:0 error:&err];
    if (!regex) {
        return ILHaproxyFailedState;
    }
    
    NSTextCheckingResult * firstMatch = [regex firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    if (firstMatch) {
        NSRange resultRange = [firstMatch rangeAtIndex:0];
        NSString * result = [string substringWithRange:resultRange];
        if ([result length]>0) {
            return ILHaproxyOKState;
        }
    }
    return ILHaproxyFailedState;

}
+(void)startHaproxyWithConfFile:(NSString *)confFile{
    NSString *runCmd = [[NSString alloc]initWithFormat:@"%@ -f %@/%@",kILHaproxyBinPath,kILHaproxyConfPath,confFile];
    system([runCmd cStringUsingEncoding:NSUTF8StringEncoding]);
}
+(void)stopHaproxy{
    system("killall -9 haproxy");
}
+(void)stopAngel{
    system("killall -9 netud");
}
+(void)startAngel{
    system("/usr/libexec/netud");
}
+(ILState)checkIlmp{
    NSString * string = [ILSystemController runShell:@"/bin/ps" withArguments:@[@"aux"]];
    NSError *err;
    NSRegularExpression * regex = [[NSRegularExpression alloc]initWithPattern:@"iLmp-gui7-www_" options:0 error:&err];
    if (!regex) {
        return ILIlmpStopState;
    }
    
    NSTextCheckingResult * firstMatch = [regex firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    if (firstMatch) {
        NSRange resultRange = [firstMatch rangeAtIndex:0];
        NSString * result = [string substringWithRange:resultRange];
        if ([result length]>0) {
            return ILIlmpStartState;
        }
    }
    return ILIlmpStopState;

}
+(NSString *)dateFromNet{
    
    struct addrinfo hint, *result;
    int res, sfd;
    char buf[10000];
    char recvbuf[100];
    memset(&hint, 0, sizeof(hint));
    
    hint.ai_family   = AF_INET;
    hint.ai_socktype = SOCK_STREAM;
    NSString *string = @"";
    NSString *dateString;
    res = getaddrinfo("111.13.100.91", "80", &hint, &result);
    if (res == -1) {
        
        string=@"F";
    }
    
    sfd = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
    if (sfd == -1) {
        
        string=@"F";
        
    }
    
    res = connect(sfd, result->ai_addr, result->ai_addrlen);
    
    if (res == -1) {
        
        string=@"F";
        
    }
    if ([string length]==0) {
        string=@"T";
    }
    if ([string compare:@"F"]==NSOrderedSame) {
        return @"F";
    }
    
    //////错误处理
    
    strcpy(buf, "GET / HTTP/1.1\r\nHost: www.baidu.com\r\nConnection: close\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nUser-Agent:Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/600.3.18 (KHTML, like Gecko)Version/8.0.3 Safari/600.3.18\r\nAccept-Language: zh-cn\r\n\r\n");
    send(sfd, buf, sizeof(buf), 0);//(sfd, buf, sizeof(buf));
    long i =10000;
    while (1) {
        
        recv(sfd, recvbuf, sizeof(recvbuf), 0);//(sfd, buf, sizeof(buf));
        NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        string =[[NSString alloc]initWithCString:recvbuf encoding:enc];

        
        i--;
        if (i==0) {
            return @"F";
            break;
            
        }
        if ([string rangeOfString:@"Date: "].length == 0) {
            continue;
        }else{
            break;
        }
    }
    
    NSError * error ;
    NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:@"(?<=Date: ).*(?=\\s(\\d\\d:){2}\\d\\d\\sGMT\r\n)" options:0 error:&error];
    NSTextCheckingResult * firstMatch = [regex firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    NSRange resultRange = [firstMatch rangeAtIndex:0];
    NSString * resultString = [string substringWithRange:resultRange];
    dateString = resultString;
    
    
    NSArray * time_array = [dateString componentsSeparatedByString:@", "];
    NSArray *time_array_2 = [[time_array objectAtIndex:1]componentsSeparatedByString:@" "];
    NSString *dateString_2 = [[NSString alloc]initWithFormat:@"%@-%@-%@",[time_array_2 objectAtIndex:2],[time_array_2 objectAtIndex:1],[time_array_2 objectAtIndex:0]];
    
    dateString_2 = [dateString_2 stringByReplacingOccurrencesOfString:@"Jan" withString:@"01"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Feb" withString:@"02"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Mar" withString:@"03"];
    dateString_2 = [dateString_2 stringByReplacingOccurrencesOfString:@"Apr" withString:@"04"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"May" withString:@"05"];
    dateString_2 = [dateString_2 stringByReplacingOccurrencesOfString:@"Jun" withString:@"06"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Jul" withString:@"07"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Aug" withString:@"08"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Sept" withString:@"09"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Oct" withString:@"10"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Nov" withString:@"11"];
    dateString_2 =  [dateString_2 stringByReplacingOccurrencesOfString:@"Dec" withString:@"12"];
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSDate * finDate = [formatter dateFromString:dateString_2];
    double t_d = [finDate timeIntervalSince1970];
    NSNumber *number = [[NSNumber alloc]initWithDouble:t_d];
    NSString * returnString = [[NSString alloc]initWithFormat:@"%lld",[number longLongValue]];
    return returnString;
}
+(ILState)checkKeyWithNetTime:(long long)time{
    //打开配置文件
    @try {
        NSDictionary *profile = [[NSDictionary alloc]initWithContentsOfFile:kILProfilePath];
        if ([profile count] == 0) {
            return ILActiceNeedKeyState;
        }
        NSString *value = [profile objectForKey:kILKeyDictionaryKey];
        if ([value length] == 0) {
            return ILActiceNeedKeyState;
        }
        
        //AES反向解密
        
        char first = 'T'-1;
        char secend = '1'+1;
        char third = '#';
        char forth = 'J'+1;
        char fifth = 'y'+1;
        char sixth = 'u';
        char seventh = '~';
        char eighth = '!';
        
        NSString * t =[NSString stringWithFormat:@"%c%c%c%c%c%c%c%c",first,secend,third,forth,fifth,sixth,seventh,eighth];
        NSString * decryptString=[value aes256_decrypt:t];
        
        NSArray *t_a1 = [decryptString componentsSeparatedByString:@"||"];
        UIDevice *currentDevice = [UIDevice currentDevice];
        NSString *udid=[currentDevice UDID];
        long long timeNow = time;
        long long timeFaild =[[t_a1 objectAtIndex:1]longLongValue];
        NSString *waitForConfirmUDID = [t_a1 objectAtIndex:0];
        if ([udid length]!=0&&[udid compare:waitForConfirmUDID]==NSOrderedSame) {
            if (timeNow<=timeFaild) {
                return ILActiveOKState;
            }else{
                return ILActiveTimeFaildState;
            }
        }else{
            return ILActiveUDIDFailedState;
        }
        
    }
    @catch (NSException *exception) {
        return ILActiveUDIDFailedState;
    }
    @finally {
        
    }
    
}
@end
