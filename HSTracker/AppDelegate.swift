//
//  AppDelegate.swift
//  HSTracker
//
//  Created by Benjamin Michotte on 19/02/16.
//  Copyright © 2016 Benjamin Michotte. All rights reserved.
//

import Cocoa
import CocoaLumberjack
import MagicalRecord

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var splashscreen: Splashscreen?
    var playerTracker: Tracker?
    var opponentTracker: Tracker?
    var initalConfig: InitialConfiguration?
    var deckManager: DeckManager?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        /*for (key,_) in NSUserDefaults.standardUserDefaults().dictionaryRepresentation() {
            NSUserDefaults.standardUserDefaults().removeObjectForKey(key)
        }
        NSUserDefaults.standardUserDefaults().synchronize()*/
        
        if let _ = NSUserDefaults.standardUserDefaults().objectForKey("hstracker_v2") {
            // welcome to HSTracker v2
        } else {
            for (key,_) in NSUserDefaults.standardUserDefaults().dictionaryRepresentation() {
                NSUserDefaults.standardUserDefaults().removeObjectForKey(key)
            }
            NSUserDefaults.standardUserDefaults().synchronize()
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hstracker_v2")
        }
        
        // init core data stuff
        MagicalRecord.setupAutoMigratingCoreDataStack()

        // init logger
#if DEBUG
        DDTTYLogger.sharedInstance().colorsEnabled = true
        DDLog.addLogger(DDTTYLogger.sharedInstance())
#else
        var fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(fileLogger)
#endif

        if Settings.instance.hearthstoneLanguage != nil && Settings.instance.hsTrackerLanguage != nil {
            loadSplashscreen()
        } else {
            initalConfig = InitialConfiguration(windowNibName: "InitialConfiguration")
            initalConfig!.completionHandler = {
                self.loadSplashscreen()
            }
            initalConfig!.showWindow(nil)
            initalConfig!.window?.orderFrontRegardless()
        }
    }

    func loadSplashscreen() {
        splashscreen = Splashscreen(windowNibName: "Splashscreen")
        splashscreen!.showWindow(self)
        let operationQueue = NSOperationQueue()

        let startUpCompletionOperation = NSBlockOperation(block: {
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                self.hstrackerReady()
            }
        })

        let databaseOperation = NSBlockOperation(block: {
            let database = Database()
            if let images = database.loadDatabaseIfNeeded(self.splashscreen!) {
                DDLogVerbose("need to download \(images)")
                let imageDownloader = ImageDownloader()
                imageDownloader.downloadImagesIfNeeded(images, splashscreen: self.splashscreen!)
            }
        })
        let loggingOperation = NSBlockOperation(block: {
            while true {
                if self.playerTracker != nil && self.opponentTracker != nil {
                    break
                }
                NSThread.sleepForTimeInterval(0.2)
            }
            DDLogInfo("Starting logging \(self.playerTracker) vs \(self.opponentTracker)")
            Game.instance.setPlayerTracker(self.playerTracker)
            Game.instance.setOpponentTracker(self.opponentTracker)
            Hearthstone.instance.start()
        })
        let trackerOperation = NSBlockOperation(block: {
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                DDLogInfo("Opening trackers")
                self.openTrackers()
            }
        })

        startUpCompletionOperation.addDependency(loggingOperation)
        loggingOperation.addDependency(trackerOperation)
        trackerOperation.addDependency(databaseOperation)
        
        operationQueue.addOperation(startUpCompletionOperation)
        operationQueue.addOperation(trackerOperation)
        operationQueue.addOperation(databaseOperation)
        operationQueue.addOperation(loggingOperation)
    }

    func hstrackerReady() {
        DDLogInfo("HSTracker is now ready !")
        if let splashscreen = splashscreen {
            splashscreen.close()
            self.splashscreen = nil
        }
    }

    func openTrackers() {
        self.playerTracker = Tracker(windowNibName: "Tracker")
        if let tracker = self.playerTracker {
            tracker.playerType = .Player
            tracker.showWindow(self)
        }

        self.opponentTracker = Tracker(windowNibName: "Tracker")
        if let tracker = self.opponentTracker {
            tracker.playerType = .Opponent
            tracker.showWindow(self)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {

    }
    
    // MARK: - Menu
    @IBAction func openDeckManager(sender: AnyObject) {
        let storyBoard = NSStoryboard(name: "DeckManager", bundle: nil)
        deckManager = storyBoard.instantiateControllerWithIdentifier("deckManager") as? DeckManager
        deckManager?.showWindow(self)

    }

}

