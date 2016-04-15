//
//  ViewController.m
//  WebView一些 js 方法
//
//  Created by 王斌 on 16/4/14.
//  Copyright © 2016年 HiveView. All rights reserved.
//

#import "ViewController.h"
#import <CommonCrypto/CommonDigest.h>
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"

@interface ViewController ()<UIWebViewDelegate>
{
    UIWebView *_webView;
    //获取的图片组数据，包括替换图片所需要的标签和图片链接，内部是字典数据
    //thumb 是图片链接
    //info 是标识标签
    NSArray *_imagesArray;
    //#带井号的是为 webView 添加缓存图片的方法
}
#warning 试试更新一下代码－－－提交
@property (nonatomic, strong) NSMutableArray *imageViews;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _webView = [[UIWebView alloc]init];
    _webView.delegate = self;
    _webView.frame = self.view.bounds;
    [self.view addSubview:_webView];
    
    [self loadCSS];
}
//读取本地css
- (void)loadCSS{
    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<html>"];
    [html appendString:@"<head>"];
    [html appendFormat:@"<link rel=\"stylesheet\" href=\"%@\">",[[NSBundle mainBundle] URLForResource:@"WBDetails.css" withExtension:nil]];
    [html appendString:@"</head>"];
    
    [html appendString:@"<body>"];
    [html appendString:[self loadHtml]];
    [html appendString:@"</body>"];
    
    [html appendString:@"</html>"];
    [_webView loadHTMLString:html baseURL:nil];
}
- (NSString *)touchBody{
    NSMutableString *body = [NSMutableString string];
    //这是用于计算 webView 内容高度的方法
    [body appendString:@"<div id=\"webview_content_wrapper\">"];
    //这是根据本地css设置标题
    [body appendFormat:@"<div class=\"title\">%@</div>",@"为什么唐僧死活不让打白骨精？说的太现实了！"];
    //这是根据本地css设置时间
    [body appendFormat:@"<div class=\"time\">%@</div>",[NSString stringWithFormat:@"这是时间"]];
    
    [body appendString:[self loadHtml]];
    //这是用于计算 webView 内容高度的方法的结束字段
    [body appendString:@"</div>"];
    
     return body;
}
//根据标签替换html内容
- (NSString *)fixedBody:(NSString *)body withFixedArray:(NSArray *)fixedArray{

    NSMutableString *bodyed = [NSMutableString stringWithString:body];

    for (NSDictionary  *detailImgModel in fixedArray) {
        NSMutableString *imgHtml = [NSMutableString string];
        // 设置img的div
        [imgHtml appendString:@"<div class=\"img-parent\">"];
        //为图片添加点击事件
        NSString *onload = @"this.onclick = function() {"
        "  window.location.href = 'sx:src=' +this.src;"
        "};";
        //设置图片大小 和链接detailImgModel[@"thumd"]
        [imgHtml appendFormat:@"<img onload=\"%@\" width=\"%f\" height=\"%f\" src=\"%@\">",onload, 300.0f,200.0f,detailImgModel[@"thumb"]];
        // 结束标记
        [imgHtml appendString:@"</div>"];
        // 替换标记detailImgModel[@"info"]
        [bodyed replaceOccurrencesOfString:detailImgModel[@"info"] withString:imgHtml options:NSCaseInsensitiveSearch range:NSMakeRange(0, bodyed.length)];
    }
    return bodyed;
}
//为HTML添加网络缓存
- (void)loadplaceholderImagewith:(NSString *)htmlString{
    //这里是通过正则表达式获取链接
//  正则表达式查找 HTML 中的图片数据
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<img\\ssrc[^>]*/>" options:NSRegularExpressionAllowCommentsAndWhitespace error:nil];
    //正则表达式查找HTML中的图片数据结果
    NSArray *result = [regex matchesInString:htmlString options:NSMatchingReportCompletion range:NSMakeRange(0, htmlString.length)];
    //创建本地图片与网络图片的映射
    NSMutableDictionary *urlDicts = [[NSMutableDictionary alloc] init];
    //获取本地路径
    NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    
    for (NSTextCheckingResult *item in result) {
        //获取数据
        NSString *imgHtml = [htmlString substringWithRange:[item rangeAtIndex:0]];
        NSArray *tmpArray = nil;
        //取出数据的链接
        if ([imgHtml rangeOfString:@"src=\""].location != NSNotFound) {
       //将字符串切割成数组
            tmpArray = [imgHtml componentsSeparatedByString:@"src=\""];
            
        } else if ([imgHtml rangeOfString:@"src="].location != NSNotFound) {
            tmpArray = [imgHtml componentsSeparatedByString:@"src="];
        }
        if (tmpArray.count >= 2) {
            //src 后面的是图片链接 + @"\"
            NSString *src = tmpArray[1];
            //去除@"\"
            NSUInteger loc = [src rangeOfString:@"\""].location;
            if (loc != NSNotFound) {
                src = [src substringToIndex:loc];
                NSLog(@"正确解析出来的SRC为：%@", src);
                if (src.length > 0) {
                    NSString *localPath = [docPath stringByAppendingPathComponent:[self md5:src]];
                    //先将链接取个本地名字，且获取完整路径
                    //以图片的链接为 key 本地路径为 value
                    [urlDicts setObject:localPath forKey:src];
                }
            }
        }
    }
    // 遍历所有的URL，替换成本地的URL，并异步获取图片
    for (NSString *src in urlDicts.allKeys) {
        NSString *localPath = [urlDicts objectForKey:src];
        htmlString = [htmlString stringByReplacingOccurrencesOfString:src withString:localPath];
        
        // 如果已经缓存过，就不需要重复加载了。
        if (![[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
            [self downloadImageWithUrl:src downloadSuccess:^(NSString *url, NSString *localUrl) {
                //注意
                //如果替换占位图片，应该刷新 webView
                [_webView reload];
            }];
        }
    }
}
- (void)downloadImageWithUrl:(NSString *)src  downloadSuccess:(void(^)(NSString *url,NSString * localUrl))success{
    // 注意：这里并没有写专门下载图片的代码，就直接使用了AFN的扩展，只是为了省麻烦而已。
    UIImageView *imgView = [[UIImageView alloc] init];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:src]];
    [imgView setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull image) {
        
        NSData *data = UIImagePNGRepresentation(image);
        NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        NSString *localPath = [docPath stringByAppendingPathComponent:[self md5:src]];
        
        if (![data writeToFile:localPath atomically:NO]) {
            NSLog(@"写入本地失败：%@", src);
        }else{
            if (success) {
                success(src,localPath);
            }
        }
    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
        NSLog(@"download image url fail: %@", src);
    }];
    
    if (self.imageViews == nil) {
        self.imageViews = [[NSMutableArray alloc] init];
    }
    [self.imageViews addObject:imgView];
}
//除掉html 数据的转义字符
- (NSString *)splitJointHtml:(NSString *)str{
    //除掉转义字符
    NSMutableString *responseString = [NSMutableString stringWithFormat:@"<head>%@</head>",str];
    NSString *character = nil;
    for (int i = 0; i < responseString.length; i ++) {
        character = [responseString substringWithRange:NSMakeRange(i, 1)];
        if ([character isEqualToString:@"\\"])
            [responseString deleteCharactersInRange:NSMakeRange(i, 1)];
    }
    return responseString;
}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    /*******
     如果在
     - (NSString *)fixedBody:(NSString *)body withFixedArray:(NSArray *)fixedArray
     中设置了图片的点击事件
     在这里可以获取点击图片的 Url
     ******/
    NSString *requestString = [[request URL] absoluteString];
    //hasPrefix 判断创建的字符串内容是否以pic:字符开始
    if ([requestString hasPrefix:@"myweb:imageClick:"]) {
        NSString *imageUrl = [requestString substringFromIndex:@"myweb:imageClick:".length];
        
        for (NSDictionary * model in _imagesArray) {
            //发现点击图片链接与数组累的数据一致
            if ([model[@"thumb"] isEqualToString:imageUrl]) {
                //对点击的图片进行操作
            }
        }
        return NO;
    }
    return YES;

}
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    //js 方法调整字号
    NSString *str = @"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '95%'";
    [webView stringByEvaluatingJavaScriptFromString:str];
    
    //js方法遍历图片添加点击事件 返回图片个数
    static  NSString * const jsGetImages =
    @"function getImages(){\
    var objs = document.getElementsByTagName(\"img\");\
    for(var i=0;i<objs.length;i++){\
    objs[i].onclick=function(){\
    document.location=\"myweb:imageClick:\"+this.src;\
    };\
    };\
    return objs.length;\
    };";
    [webView stringByEvaluatingJavaScriptFromString:jsGetImages];//注入js方法
    [webView stringByEvaluatingJavaScriptFromString:@"getImages()"];
//js 方法修改图片大小
    NSString *jsSetImageSize = [NSString stringWithFormat:@"var script = document.createElement('script');"
                                "script.type = 'text/javascript';"
                                "script.text = \"function ResizeImages() { "
                                "var myimg,oldwidth;"
                                "var maxwidth = %f;" // UIWebView中显示的图片宽度
                                "for(i=0;i <document.images.length;i++){"
                                "myimg = document.images[i];"
                                "if(myimg.width > maxwidth){"
                                "oldwidth = myimg.width;"
                                "myimg.width = maxwidth;"
                                "}"
                                "}"
                                "}\";"
                                "document.getElementsByTagName('head')[0].appendChild(script);",300.0f];
    [webView stringByEvaluatingJavaScriptFromString:jsSetImageSize];
    [webView stringByEvaluatingJavaScriptFromString:@"ResizeImages();"];
    
    //调用js方法调整 webView 的高度
    //        NSLog(@"---调用js方法--%@  %s  jsMehtods_result = %@",self.class,__func__,resurlt);
    //获取页面高度（像素）
    NSString * clientheight_str = [webView stringByEvaluatingJavaScriptFromString: @"document.body.offsetHeight"];
    float clientheight = [clientheight_str floatValue];
    //设置到WebView上
    webView.frame = CGRectMake(0, 0, self.view.frame.size.width, clientheight);
    //获取WebView最佳尺寸（点）
    CGSize frame = [webView sizeThatFits:webView.frame.size];
    //获取内容实际高度（像素）
    NSString * height_str= [webView stringByEvaluatingJavaScriptFromString: @"document.getElementById('webview_content_wrapper').offsetHeight + parseInt(window.getComputedStyle(document.getElementsByTagName('body')[0]).getPropertyValue('margin-top'))  + parseInt(window.getComputedStyle(document.getElementsByTagName('body')[0]).getPropertyValue('margin-bottom'))"];
    float height = [height_str floatValue];
    //内容实际高度（像素）* 点和像素的比
    height = height * frame.height / clientheight;
    //再次设置WebView高度（点）
    webView.frame = CGRectMake(0, 0, self.view.frame.size.width, height);
    
}

- (NSString * )loadHtml{
    return @"<div id=\\\"video\\\" style=\\\"width:100%;min-height:300px;\\\"><p>\u5728\u82f1\u56fd\u6c83\u91cc\u514b\u9547\u4e3e\u884c\u7684\u9a6c\u672f\u7ecf\u5178\u969c\u788d\u8ffd\u9010\u8d5b\u4e2d\uff0c\u9a6f\u9a6c\u5e08Kerry Lee\u8c03\u6559\u7684\u7231\u9a6cRusse Blanc\u8d62\u5f97\u51a0\u519b\u3002\u636e\u4e86\u89e3\uff0c\u8fd9\u662fKerry Lee\u4ee5\u9a6f\u9a6c\u5e08\u8eab\u4efd\u6240\u53c2\u52a0\u7684\u7b2c\u4e00\u4e2a\u8d5b\u5b63\uff0c\u5bf9\u6b64\uff0c\u8fd9\u4f4d\u201c\u83dc\u9e1f\u201d\u9a6f\u9a6c\u5e08Kerry Lee\u8868\u793a\uff0c\u5979\u5bf9Russe Blanc\u7684\u80dc\u5229\u201c\u6df1\u611f\u81ea\u8c6a\u201d\u3002<\/p><p><img src=\\\"http:\/\/i.cdn.cchorse.net\/ueditor\/20160118\/569c9814a4317.jpg\\\" title=\\\"\u56fe\u7247\\\" alt=\\\"\u56fe\u7247\\\"><\/p><p>\u5c31\u5728\u4e00\u5468\u524d\uff0cKerry Lee\u8c03\u6559\u7684\u53e6\u4e00\u5339\u8d5b\u9a6cMountainous\u5728\u5a01\u5c14\u58eb\u56fd\u5bb6\u676f\u4e2d\u83b7\u5f97\u51a0\u519b\u3002\u6c83\u91cc\u514b\u9547\u7684\u969c\u788d\u8ffd\u9010\u8d5b\u4e0a\uff0c\u9a91\u624bCharlie Poste\u7b56\u9a91\u7684Russe Blanc\u6240\u53d6\u5f97\u7684\u51a0\u519b\uff0c\u8fd9\u662f\u9a6f\u9a6c\u5e08Kerry Lee\u5728\u4e00\u5468\u65f6\u95f4\u5185\u6240\u6536\u83b7\u7684\u7b2c\u4e8c\u573a\u80dc\u5229\u3002<\/p><p>\u201c\u8ddf\u4e0a\u5468\u593a\u51a0\u7684Mountainous\u4e00\u6837\uff0cRusse Blanc\u662f\u51ed\u501f\u5b83\u5728\u6700\u540e\u4e00\u8df3\u4e2d\u7684\u4f18\u5f02\u8868\u73b0\u6700\u7ec8\u62ff\u4e0b\u8fd9\u573a\u80dc\u5229\u7684\uff0c\u770b\u5f97\u51fa\uff0c\u5b83\u5728\u6bd4\u8d5b\u4e2d\u505a\u5230\u4e86100%\u7684\u6295\u5165\u3002\u201d\u8d5b\u540e\uff0cKerry Lee\u5bf9\u7231\u9a6c\u7684\u8868\u73b0\u8d5e\u4e0d\u7edd\u53e3\u3002\u636e\u4e86\u89e3\uff0cRusse Blanc\u662f\u4e00\u5339\u7eaf\u767d\u8272\u7684\u8d5b\u9a6c\uff0c\u5b83\u7684\u54c1\u79cd\u5728\u8d5b\u9a6c\u754c\u4e5f\u5c5e\u7a00\u6709\u3002<\/p><p>Kerry Lee\u662f\u4ece\u5979\u7684\u7236\u4eb2\u90a3\u91cc\u63a5\u624b\u7684Russe Blanc\uff0c\u201c\u6211\u4eec\u539f\u672c\u5e76\u6ca1\u6709\u6307\u671bRusse Blanc\u80fd\u591f\u5728\u8fd9\u91cc\u593a\u51a0\uff0c\u4ec5\u4ec5\u662f\u5e0c\u671b\u5b83\u80fd\u591f\u53d6\u5f97\u597d\u6210\u7ee9\u3002\u770b\u7684\u51fa\u6765\uff0cRusse Blanc\u975e\u5e38\u4eab\u53d7\u6bd4\u8d5b\u7684\u8fc7\u7a0b\u3002\u201d<\/p><p>\u4e0e\u6b64\u540c\u65f6\uff0c\u7531\u9a6f\u9a6c\u5e08Nicky Henderson\u57f9\u517b\u7684\u8d5b\u9a6cL&#39;Ami Serge\u5728\u82f1\u56fd\u5a01\u745f\u6bd4\u4e3e\u884c\u7684\u65b0\u624b\u8ffd\u9010\u8d5b\u4e2d\uff0c\u6218\u80dc\u4e86\u593a\u51a0\u70ed\u95e8Douvan\uff0c\u4ece\u53c2\u8d5b\u76847\u4f4d\u8d5b\u9a6c\u4e2d\u8131\u9896\u800c\u51fa\uff0c\u593a\u5f97\u6842\u51a0\u3002<\/p><\/div>";
}
- (NSString *)md5:(NSString *)sourceContent {
    if (self == nil || [sourceContent length] == 0) {
        return nil;
    }
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5([sourceContent UTF8String], (int)[sourceContent lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    NSMutableString *ms = [NSMutableString string];
    
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat:@"%02x", (int)(digest[i])];
    }
    
    return [ms copy];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
