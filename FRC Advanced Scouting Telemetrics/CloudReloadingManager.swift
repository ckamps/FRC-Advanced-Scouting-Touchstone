//
//  CloudReloadingManager.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 2/18/17.
//  Copyright © 2017 Kampfire Technologies. All rights reserved.
//

import Foundation
import Crashlytics

typealias CloudReloadingCompletionHandler = (Bool) -> Void

class CloudReloadingManager {
    let eventToReload: Event
    
    let completionHandler: CloudReloadingCompletionHandler
    let cloudConnection = CloudData()
    let realmController = RealmController.realmController
    
    init(eventToReload: Event, completionHandler: @escaping CloudReloadingCompletionHandler) {
        self.eventToReload = eventToReload
        self.completionHandler = completionHandler
    }
    
    func reload() {
        //To reload, it removes the event and then calls a CloudImportManager to re-import it
        cloudConnection.event(forKey: eventToReload.key, withCompletionHandler: reloadEvent)
        realmController.delete(object: eventToReload)
    }
    
    private func reloadEvent(frcEvent: FRCEvent?) {
        if let frcEvent = frcEvent {
            CLSNSLogv("Beginning event reload", getVaList([]))
            CloudEventImportManager(shouldPreload: false, forEvent: frcEvent) {(successful, importError) in
                self.completionHandler(successful)
                
                CLSNSLogv("Finished re-imported (reloaded) cloud event: \(frcEvent.key), withError: \(String(describing: importError))", getVaList([]))
            }
                .import()
        }
    }
}

class MatchUpdateManager {
    
    var event: Event
    
    let cloudConnection = CloudData()
    let realmController = RealmController.realmController
    
    init(eventToUpdateMatchesIn event: Event) {
        self.event = event
    }
    
    ///Asynchronously update all the scores in the event's matches
    func update() {
        cloudConnection.matches(forEventKey: event.key, withCompletionHandler: updateMatches)
    }
    
    private func updateMatches(withCloudMatches cloudMatches: [FRCMatch]?) {
        if let cloudMatches = cloudMatches {
            for match in (event.matches) {
                if let cloudMatch = cloudMatches.first(where: {$0.key == match.key}) {
                    let cloudAlliances = cloudMatch.alliances!
                    let blueScore = cloudAlliances["blue"]?.score
                    let redScore = cloudAlliances["red"]?.score
                    
                    //TBA represents unknown score values as -1 so if the score is -1, then put nil in for the score.
                    //TODO: Update to use realm writes
                    if blueScore == -1 {
                        match.scouted.blueScore.value = nil
                    } else {
                        match.scouted.blueScore.value = blueScore
                    }
                    if redScore == -1 {
                        match.scouted.redScore.value = nil
                    } else {
                        match.scouted.redScore.value = redScore
                    }
                }
            }
        }
    }
}
