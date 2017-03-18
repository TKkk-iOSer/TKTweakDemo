//
//  Tweak.xm
//  TKDemo
//
//  Created by TK on 2017/3/18.
//  Copyright © 2017年 TK. All rights reserved.
//
@interface MMUIViewController : UIViewController
- (void)helloWorld;
@end

%hook MMUIViewController

- (void)viewDidAppear:(_Bool)arg1 {
    %orig;
    [self helloWorld];
}

%new
- (void)helloWorld {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"hello World" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}
%end
