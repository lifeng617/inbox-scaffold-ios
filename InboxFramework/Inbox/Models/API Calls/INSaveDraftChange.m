//
//  INSaveDraftChange.m
//  InboxFramework
//
//  Created by Ben Gotow on 5/16/14.
//  Copyright (c) 2014 Inbox. All rights reserved.
//

#import "INSaveDraftChange.h"
#import "INThread.h"
#import "INTag.h"

@implementation INSaveDraftChange


- (NSURLRequest *)buildRequest
{
	NSError * error = nil;
    NSString * path = [NSString stringWithFormat:@"/n/%@/create_draft", [self.model namespaceID]];
    NSString * url = [[NSURL URLWithString:path relativeToURL:[INAPIManager shared].baseURL] absoluteString];
	return [[[INAPIManager shared] requestSerializer] requestWithMethod:@"POST" URLString:url parameters:[self.model resourceDictionary] error:&error];
}

- (void)handleSuccess:(AFHTTPRequestOperation *)operation withResponse:(id)responseObject
{
    INMessage * message = (INMessage *)[self model];
    INThread * oldThread = [message thread];
    
    if ([responseObject isKindOfClass: [NSDictionary class]])
        [message updateWithResourceDictionary: responseObject];
    
    // if we've orphaned a temporary thread object, go ahead and clean it up
    if ([[oldThread ID] isEqualToString: [[message thread] ID]] == NO) {
        if ([oldThread hasSelfAssignedID])
            [[INDatabaseManager shared] unpersistModel: oldThread];
    }
}

- (void)applyLocally
{
    INMessage * message = (INMessage *)[self model];
    [[INDatabaseManager shared] persistModel: message];
    
    // Until we're able to save the draft, it's orphaned because it has no thread.
    // In order to present it in the app and give it the draft tag, let's create a
    // thread with a self-assigned ID for it. We'll keep that thread object in sync
    // and when this operation succeeds we'll destroy it.
    INThread * thread = [message thread];
    if (!thread) {
        thread = [[INThread alloc] init];
        [thread setNamespaceID: [message namespaceID]];
        [message setThreadID: [thread ID]];
    }
    
    if ([thread hasSelfAssignedID]) {
        [thread setSubject: [message subject]];
        [thread setParticipants: [message to]];
        [thread setTagIDs: @[INTagIDDraft]];
        [thread setSnippet: [message body]];
        [thread setMessageIDs: @[[message ID]]];
        [[INDatabaseManager shared] persistModel: thread];
    }
}

@end