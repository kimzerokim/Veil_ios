//
//  PNFriendsViewController.m
//  Pine
//
//  Created by soojin on 6/12/14.
//  Copyright (c) 2014 Recover39. All rights reserved.
//

#import "PNFriendsViewController.h"
#import "PNPhoneNumberFormatter.h"
#import "TMPPerson.h"
#import "MSCellAccessory.h"
#import "PNCoreDataStack.h"
#import "Friend.h"

@import AddressBook;

@interface PNFriendsViewController () <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) NSMutableArray *allPeople;
@property (strong, nonatomic) NSMutableArray *searchResults;
@property (strong, nonatomic) NSMutableArray *selectedPeople;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@end

@implementation PNFriendsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self.fetchedResultsController performFetch:nil];
    
    NSLog(@"test commit");
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    PNFriendsViewController * __weak weakSelf = self;
    
    switch (ABAddressBookGetAuthorizationStatus()) {
        case kABAuthorizationStatusNotDetermined:
        {
            ABAddressBookRequestAccessWithCompletion(ABAddressBookCreateWithOptions(NULL, nil), ^(bool granted, CFErrorRef error) {
                if (!granted) return;
                //GRANTED
                [weakSelf rakeInUserContacts];
                [weakSelf.tableView reloadData];
            });
            break;
        }
        case kABAuthorizationStatusAuthorized:
        {
            //Authorized
            if ([self.allPeople count] == 0) {
                //this is when the user denies the first request and changes the settings afterward.
                [self rakeInUserContacts];
                [self.tableView reloadData];
            }
            break;
        }
        case kABAuthorizationStatusDenied:
        case kABAuthorizationStatusRestricted:
        {
            //Do something to encourage user to allow access to his/her contacts
            UIAlertView *cantAccessContactAlert = [[UIAlertView alloc] initWithTitle:nil message: @"연락처에 대한 접근 권한을 허용해주세요" delegate:nil cancelButtonTitle: @"OK" otherButtonTitles: nil];
            [cantAccessContactAlert show];
            
            break;
        }
        
        default:
            break;
    }
    
    [self.fetchedResultsController performFetch:nil];
    //NSLog(@"fetched objects : %@", self.fetchedResultsController.fetchedObjects);
}

- (NSMutableArray *)allPeople
{
    if (!_allPeople) {
        _allPeople = [[NSMutableArray alloc] init];
    }
    
    return _allPeople;
}

- (NSMutableArray *)searchResults
{
    if (!_searchResults) {
        _searchResults = [[NSMutableArray alloc] init];
    }
    
    return _searchResults;
}


#pragma mark - Helpers

- (void)rakeInUserContacts
{
    //If already loaded, just return
    BOOL loaded = [[NSUserDefaults standardUserDefaults] boolForKey:@"loadedContactsToCoreData"];
    if (loaded) {
        return;
    }
    
    NSLog(@"rake in user called");
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, nil);
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
    CFIndex numberOfPeople = ABAddressBookGetPersonCount(addressBook);

    PNPhoneNumberFormatter *phoneFormatter = [[PNPhoneNumberFormatter alloc] init];
    PNCoreDataStack *coreDataStack = [PNCoreDataStack defaultStack];

    for (int i = 0 ; i < numberOfPeople ; i++) {
        ABRecordRef person = CFArrayGetValueAtIndex(allPeople, i);
        
        NSString *compositeName = (__bridge_transfer NSString*) ABRecordCopyCompositeName(person);
        
        ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
        NSString *mainPhoneNumber = (__bridge_transfer NSString *)ABMultiValueCopyValueAtIndex(phoneNumbers, 0);
        if (mainPhoneNumber != nil) {
            NSString *strippedNumber = [phoneFormatter strip:mainPhoneNumber];
            //TMPPerson *person = [[TMPPerson alloc] init];
            //person.name = compositeName;
            //person.phoneNumber = strippedNumber;
            //[self.allPeople addObject:person];
            Friend *friend = [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:coreDataStack.managedObjectContext];
            friend.name = compositeName;
            friend.phoneNumber = strippedNumber;
            friend.selected = [NSNumber numberWithBool:NO];
        }
        CFRelease(phoneNumbers);
    }
    [coreDataStack saveContext];
    [self.fetchedResultsController performFetch:nil];
    //NSLog(@"fetched objects : %@", self.fetchedResultsController.fetchedObjects);

    CFRelease(allPeople);
    CFRelease(addressBook);
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"loadedContactsToCoreData"];
}

#pragma mark - Fetched Results Controller methods

- (NSFetchRequest *)friendsFetchRequest
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Friend"];
    
    NSSortDescriptor *sortSelected = [NSSortDescriptor sortDescriptorWithKey:@"selected" ascending:NO];
    NSSortDescriptor *sortByName = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    
    //sortSelected must be the first sort descriptor
    fetchRequest.sortDescriptors = @[sortSelected, sortByName];
    
    return fetchRequest;
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    PNCoreDataStack *coreDataStack = [PNCoreDataStack defaultStack];
    NSFetchRequest *fetchRequest = [self friendsFetchRequest];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:coreDataStack.managedObjectContext sectionNameKeyPath:@"sectionIdentifier" cacheName:@"Friends"];
    _fetchedResultsController.delegate = self;
    
    return _fetchedResultsController;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    NSLog(@"section count : %d", [self.fetchedResultsController.sections count]);
    return [self.fetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    Friend *friend = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = friend.name;
    cell.detailTextLabel.text = friend.phoneNumber;
    
    return cell;
}


-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    NSLog(@"sections : %@", [self.fetchedResultsController sections]);
    return [sectionInfo name];
}

#pragma mark - Search Method

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
    [self.searchResults removeAllObjects];
    
    /* 초성검색
    //검색 문자열을 초성 문자열로 변환
    NSString *searchString = [self getUTF8String:searchText];
    
    //for 루프로 확인
    for (TMPPerson *person in self.allPeople) {
        NSString *personName = [self getUTF8String:person.name];
        BOOL found = [personName rangeOfString:searchString].location != NSNotFound;
        if (found) {
            [self.searchResults addObject:person];
        }
    }
    */
    
    NSPredicate *resultPredicate = [NSPredicate predicateWithFormat:@"name contains[c] %@", searchText];
    self.searchResults = [[self.selectedPeople filteredArrayUsingPredicate:resultPredicate] mutableCopy];
    [self.searchResults addObjectsFromArray:[self.allPeople filteredArrayUsingPredicate:resultPredicate]];
}

#pragma mark - UISearchDisplayController delegate

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
                                      objectAtIndex:[self.searchDisplayController.searchBar
                                                     selectedScopeButtonIndex]]];
    
    return YES;
}

#pragma mark - 초성 검색 메서드

- (NSString *)getUTF8String:(NSString *)hangeulString
{
    NSArray *choSung = [[NSArray alloc] initWithObjects:@"ㄱ", @"ㄲ", @"ㄴ", @"ㄷ", @"ㄸ", @"ㄹ", @"ㅁ", @"ㅂ", @"ㅃ", @"ㅅ", @"ㅆ", @"ㅇ", @"ㅈ", @"ㅉ", @"ㅊ", @"ㅋ", @"ㅌ", @"ㅍ", @"ㅎ", nil];
    //NSArray *joongSung = [[NSArray alloc] initWithObjects:@"ㅏ",@"ㅐ",@"ㅑ",@"ㅒ",@"ㅓ",@"ㅔ",@"ㅕ",@"ㅖ",@"ㅗ",@"ㅘ",@" ㅙ",@"ㅚ",@"ㅛ",@"ㅜ",@"ㅝ",@"ㅞ",@"ㅟ",@"ㅠ",@"ㅡ",@"ㅢ",@"ㅣ",nil];
    //NSArray *jongSung = [[NSArray alloc] initWithObjects:@"",@"ㄱ",@"ㄲ",@"ㄳ",@"ㄴ",@"ㄵ",@"ㄶ",@"ㄷ",@"ㄹ",@"ㄺ",@"ㄻ",@" ㄼ",@"ㄽ",@"ㄾ",@"ㄿ",@"ㅀ",@"ㅁ",@"ㅂ",@"ㅄ",@"ㅅ",@"ㅆ",@"ㅇ",@"ㅈ",@"ㅊ",@"ㅋ",@" ㅌ",@"ㅍ",@"ㅎ",nil];
    
    NSString *returnString = @"";
    
    for (int i = 0 ; i < [hangeulString length] ; i++) {
        NSInteger code = [hangeulString characterAtIndex:i];
        if (code >= 0xAC00 && code <= 0xD7A3) { //유니코드 한글 영역에서만 처리
            NSInteger uniCode = code - 0xAC00; //한글 시작 영역을 제거
            NSInteger choSungIndex = uniCode / 21 / 28; //초성
            //NSInteger joongSungIndex = uniCode%(21*28)/28; //중성
            //NSInteger jongSungIndex = uniCode%28; //종성
            //returnString = [NSString stringWithFormat:@"%@%@%@%@", returnString, [choSung objectAtIndex:choSungIndex], [joongSung objectAtIndex:joongSungIndex], [jongSung objectAtIndex:jongSungIndex]];
            returnString = [NSString stringWithFormat:@"%@%@", returnString, [choSung objectAtIndex:choSungIndex]];
        } else {
            returnString = [NSString stringWithFormat:@"%@%@", returnString, [hangeulString substringWithRange:NSMakeRange(i, 1)]];
        }
    }
    
    return returnString;
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

- (IBAction)didInviteBarButtonItemPressed:(UIBarButtonItem *)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"초대하기" delegate:nil cancelButtonTitle:@"취소" destructiveButtonTitle:nil otherButtonTitles:@"SMS로 초대", @"이메일로 초대", nil];
    [actionSheet showFromTabBar:self.tabBarController.tabBar];
}
@end
