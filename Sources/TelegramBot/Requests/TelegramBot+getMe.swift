//
// TelegramBot+getMe.swift
//
// Copyright (c) 2015 Andrey Fidrya
//
// Licensed under the MIT license. For full copyright and license information,
// please see the LICENSE file.
//

import Foundation

extension TelegramBot {
    
    /// A simple method for testing your bot's auth token. Requires no parameters.
    ///
    /// This is an asynchronous version of the method,
    /// a blocking one is also available.
    ///
    /// - Parameter completion: Completion handler which will be called on main
    ///                         queue by default. The queue can be overridden
    ///                         by setting `queue` property of TelegramBot.
    /// - Returns: Basic information about the bot in form of a `User` object.
    ///            Null on error, in which case `error` contains the details.
    /// - SeeAlso: `func getMe() -> User?`
    public func getMeAsync(completion: (user: /*NS*/User?, error: /*NS*/DataTaskError?)->()) {
        getMeAsync(queue: queue, completion: completion)
    }
    
    /// A simple method for testing your bot's auth token. Requires no parameters.
    ///
    /// This is a blocking version of the method,
    /// an asynchronous one is also available.
    ///
    /// - Returns: Basic information about the bot in form of a `User` object.
    ///            Null on error, in which case details can be obtained using
    ///            `lastError` property.
    /// - SeeAlso: `func getMe(completion:)->()`
    public func getMeSync() -> /*NS*/User? {
        var result: /*NS*/User!
        let sem = dispatch_semaphore_create(0)
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        getMeAsync(queue: queue) {
                user, error in
            result = user
            self.lastError = error
            dispatch_semaphore_signal(sem)
        }
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER)
        return result
    }

    private func getMeAsync(queue: dispatch_queue_t, completion: (user: /*NS*/User?, error: /*NS*/DataTaskError?)->()) {
        startDataTaskForEndpoint("getMe") {
                result, error in
			var error = error
            var user: /*NS*/User?
            if error == nil {
                user = /*NS*/User(json: result)
                if user == nil {
                    error = .ResultParseError(json: result)
                }
            }
            dispatch_async(queue) {
                completion(user: user, error: error)
            }
        }
    }
}
