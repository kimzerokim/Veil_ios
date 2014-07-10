//
//  PNEntireFeedViewController.m
//  Pine
//
//  Created by soojin on 6/20/14.
//  Copyright (c) 2014 Recover39. All rights reserved.
//

#import "PNFeedContentViewController.h"
#import "PNPostCell.h"
#import <RestKit/RestKit.h>
#import "TMPThread.h"

@interface PNFeedContentViewController ()

@property (strong, nonatomic) NSMutableArray *threads;
@property (strong, nonatomic) NSString *isFriend;
@property (strong, nonatomic) UIRefreshControl *refreshControl;

@end

@implementation PNFeedContentViewController

- (NSMutableArray *)threads
{
    if (!_threads) {
        _threads = [[NSMutableArray alloc] init];
    }
    
    return _threads;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (self.pageIndex == 0) {
        self.isFriend = @"true";
    } else {
        self.isFriend = @"false";
    }
    
    self.tableView.allowsSelection = NO;
    self.tableView.separatorColor = [UIColor clearColor];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(getNewThreads) forControlEvents:UIControlEventValueChanged];

    [self fetchInitialThreads];
}

#pragma mark - Helper methods

- (void)getNewThreads
{
    NSNumber *latestThreadID = [[self.threads objectAtIndex:0] threadID];
    
    NSString *URLString = [NSString stringWithFormat:@"http://10.73.45.42:5000/threads/%@/offset?user=%@&is_friend=%@", latestThreadID, kUserID, self.isFriend];
    NSURL *url = [NSURL URLWithString:URLString];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if ([httpResponse statusCode] == 200) {
                //SUCCESSFUL RESPONSE WITH RESPONSE CODE 200
                NSError *error;
                //NSLog(@"response : %@", response);
                //NSLog(@"data : %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                NSDictionary *responseDic = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                
                NSInteger latestThreadOffset = [responseDic[@"offset"] integerValue];
                
                if (latestThreadOffset == 0) {
                    //NO MORE NEW THREADS
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.refreshControl isRefreshing]) [self.refreshControl endRefreshing];
                    });
                    return;
                } else {
                    //THERE ARE NEW THREADS
                    [self fetchNewThreadsWithLatestOffset:latestThreadOffset completion:^(NSArray *newThreads) {
                        NSRange range = {0, latestThreadOffset};
                        [self.threads insertObjects:newThreads atIndexes:[NSIndexSet indexSetWithIndexesInRange: range]];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            //[self.tableView reloadData];
                            if ([self.refreshControl isRefreshing]) [self.refreshControl endRefreshing];
                            
                            NSMutableArray  *indexPaths = [NSMutableArray array];
                            for (NSInteger i = 0 ; i < latestThreadOffset ; i++) {
                                [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                            }
                            [self.tableView beginUpdates];
                            [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
                            [self.tableView endUpdates];
                            
                        });
                    }];
                }
                
            } else {
                //WRONG RESPONSE CODE ERROR
                NSLog(@"Error with response code : %d", [httpResponse statusCode]);
            }
        } else {
            //HTTP REQUEST ERROR
            NSLog(@"Error : %@", error);
        }
    }];
    [task resume];
}

- (void)getMoreThreads
{
    
}

- (void)fetchInitialThreads
{
    RKObjectMapping *threadMapping = [RKObjectMapping mappingForClass:[TMPThread class]];
    [threadMapping addAttributeMappingsFromDictionary:@{@"id": @"threadID",
                                                        @"like" : @"likeCount",
                                                        @"pub_date" : @"publishedDate",
                                                        @"is_user_like" : @"userLiked",
                                                        @"image_url" : @"imageURL",
                                                        @"content" : @"content"}];
    
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:threadMapping method:RKRequestMethodGET pathPattern:nil keyPath:@"data" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    NSString *urlString = [NSString stringWithFormat:@"http://10.73.45.42:5000/threads?user=%@&is_friend=%@&offset=%d&limit=%d", kUserID, self.isFriend, 0, 20];
    NSURL *URL = [NSURL URLWithString:urlString];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:URL];
    
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[responseDescriptor]];
    [objectRequestOperation setCompletionBlockWithSuccess:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        self.threads = [mappingResult.array mutableCopy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            if ([self.refreshControl isRefreshing]) [self.refreshControl endRefreshing];
        });
        
    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
        NSLog(@"Operation failed With Error : %@", error);
    }];
    [objectRequestOperation start];
}

- (void)fetchNewThreadsWithLatestOffset:(NSInteger)offset completion:(void(^)(NSArray *newThreads))completion
{
    RKObjectMapping *threadMapping = [RKObjectMapping mappingForClass:[TMPThread class]];
    [threadMapping addAttributeMappingsFromDictionary:@{@"id": @"threadID",
                                                        @"like" : @"likeCount",
                                                        @"pub_date" : @"publishedDate",
                                                        @"is_user_like" : @"userLiked",
                                                        @"image_url" : @"imageURL",
                                                        @"content" : @"content"}];
    
    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:threadMapping method:RKRequestMethodGET pathPattern:nil keyPath:@"data" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    
    NSString *urlString = [NSString stringWithFormat:@"http://10.73.45.42:5000/threads?user=%@&is_friend=%@&offset=%d&limit=%d", kUserID, self.isFriend, 0, offset];
    NSURL *URL = [NSURL URLWithString:urlString];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:URL];
    
    RKObjectRequestOperation *objectRequestOperation = [[RKObjectRequestOperation alloc] initWithRequest:request responseDescriptors:@[responseDescriptor]];
    [objectRequestOperation setCompletionBlockWithSuccess:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        completion(mappingResult.array);
    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
        NSLog(@"Operation failed With Error : %@", error);
    }];
    [objectRequestOperation start];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.threads count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PNPostCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    // Configure the cell...
    [cell configureCellForThread:self.threads[indexPath.row]];
    
    return cell;
}

- (UITableViewCell *)loadingCell
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityIndicator.center = cell.center;
    [cell addSubview:activityIndicator];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat currentOffset = scrollView.contentOffset.y;
    CGFloat maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;
    //NSLog(@"%f", maximumOffset);
    
    if (maximumOffset - currentOffset <= 320.0f * 4) {
        //NSLog(@"add data");
    }
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
