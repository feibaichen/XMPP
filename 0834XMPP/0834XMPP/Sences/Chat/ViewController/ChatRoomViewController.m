//
//  ChatRoomViewController.m
//  0834XMPP
//
//  Created by 郑建文 on 15/11/25.
//  Copyright © 2015年 Lanou. All rights reserved.
//

#import "ChatRoomViewController.h"
#import "XMPPManager.h"
#import "OutImageCell.h"
#import "ReceiveImageCell.h"

@interface ChatRoomViewController ()<UITextFieldDelegate,UITableViewDelegate,UITableViewDataSource,XMPPStreamDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UIView *view4ChatContent;
//手拖的约束
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *constraint4bottomFromSuper;

@property (weak, nonatomic) IBOutlet UITextField *txt4Chat;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
- (IBAction)action4SendMessage:(id)sender;

//所有聊天消息
@property (nonatomic,strong) NSMutableArray * messages;

@end

@implementation ChatRoomViewController


//加载所有消息(通过单例类通过的上下文获取)
- (void)reloadAllMessage{
    NSManagedObjectContext *context = [XMPPManager sharedManager].context;
    //xmppmessageArchiving : 把接收的消息(xmppmessage)进行归档,归档后的数据类型是(
//    XMPPMessageArchiving_Message_CoreDataObject)
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"XMPPMessageArchiving_Message_CoreDataObject"];
    
    //设置断言
    //查找所有和当前聊天对象一样的message 对象
    XMPPJID *myjid = [[[XMPPManager sharedManager] stream] myJID];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@" bareJidStr == %@  and streamBareJidStr == %@ ",self.jidChatTo.bare,myjid.bare];
    
    //让断言生效
    [fetchRequest setPredicate:predicate];
    
    //获取数据
    NSArray *array = [context executeFetchRequest:fetchRequest error:nil];
    
    if (array) {
        //先移除所有数据源
        [self.messages removeAllObjects];
    }
    
    //将获取到数据添加到当前数据源中
    [self.messages addObjectsFromArray:array];
    
    [self.tableView reloadData];
    if (self.messages.count  > 1) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    //设置代理
    XMPPStream *stream = [XMPPManager sharedManager].stream;
    [stream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"OutImageCell" bundle:nil] forCellReuseIdentifier:@"outimage"];
    [self.tableView registerNib:[UINib nibWithNibName:@"ReceiveImageCell" bundle:nil] forCellReuseIdentifier:@"receimage"];
    self.tableView.estimatedRowHeight = 100;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    //通过通知中心来观察键盘的frame 的变化,当键盘frame 发送变化后触发keyboardFrameChange事件
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameChange:) name:UIKeyboardDidChangeFrameNotification object:nil];
    //加载之前的数据
    [self reloadAllMessage];
}

- (void)keyboardFrameChange:(NSNotification *)not{
    NSLog(@"%@",not);
    //键盘改变后的frame
    CGRect rect = [[not.userInfo objectForKey:@"UIKeyboardFrameEndUserInfoKey"] CGRectValue];
    //计算出聊天窗口的底部偏移量
    CGFloat height = self.view.frame.size.height - rect.origin.y;
    
    //改变约束的值
    self.constraint4bottomFromSuper.constant = height;
    
    if (self.messages.count  > 1) {
//        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        [UIView animateWithDuration:0.5 animations:^{
                self.tableView.contentOffset = CGPointMake(0,  self.tableView.contentSize.height - rect.origin.y + 110) ;
        }];
    }
}


#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}



#pragma mark - UITableViewDelegate,UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.messages.count;
}
-(void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView{
    if ( [self.txt4Chat canResignFirstResponder]) {
        [self.txt4Chat  resignFirstResponder];    
    }
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    XMPPMessageArchiving_Message_CoreDataObject *message = self.messages[indexPath.row];
    //判断是否是自己发出去的.
    if (![[message.message body] isEqualToString:@"image"]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
            if ([message isOutgoing]) {
                cell.textLabel.text = [NSString stringWithFormat:@"我 : %@",message.body];
            }else{
                cell.textLabel.text = [NSString stringWithFormat:@"%@ : %@",message.bareJid.user,message.body];
            }
            return cell;
    }else {
        if ([message isOutgoing]) {
            OutImageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"outimage" forIndexPath:indexPath];
            [cell configCellWithUserName:message.bareJid.user message:message.message];
            return cell;
        }else{
            ReceiveImageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"receimage" forIndexPath:indexPath];
            [cell configCellWithUserName:message.bareJid.user message:message.message];
            return cell;
        }
    }
}

#pragma mark - XMPPStreamDelegate
//接收到一条消息
- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message{
    [self reloadAllMessage];
}
//发送一条消息的回调事件
- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message{
    [self reloadAllMessage];
}

- (IBAction)action4SendImage:(id)sender {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:^{
        
    }];
}

- (IBAction)action4SendMessage:(id)sender {
    XMPPStream *stream = [XMPPManager sharedManager].stream;
    
    //构造一个XMPPMessage 消息类
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:self.jidChatTo];
    [message addBody:self.txt4Chat.text];
    //通过通讯管道发送消息
    [stream sendElement:message];
    
}
#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    NSData *data = UIImagePNGRepresentation([self croppIngimageByImageName:image toRect:CGRectMake(0, 0, 300,200 )]);
    
    XMPPStream *stream = [XMPPManager sharedManager].stream;
    XMPPMessage *message = [XMPPMessage messageWithType:@"chat" to:self.jidChatTo];
    [message addBody:@"image"];
    NSString *base64str = [data base64EncodedStringWithOptions:0];
    XMPPElement *attachment = [XMPPElement elementWithName:@"attachment" stringValue:base64str];
    [message addChild:attachment];
    [stream sendElement:message];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (UIImage *)croppIngimageByImageName:(UIImage *)imageToCrop toRect:(CGRect)rect
{
    //CGRect CropRect = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height+15);
    CGImageRef imageRef = CGImageCreateWithImageInRect([imageToCrop CGImage], rect);
    UIImage *cropped = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return cropped;
}
#pragma mark - lazy load
- (NSMutableArray *)messages{
    if (!_messages) {
        _messages = [NSMutableArray array];
    }
    return _messages;
}
@end
