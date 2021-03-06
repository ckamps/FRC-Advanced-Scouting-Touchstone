//
//  ScoutingModels.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 1/15/18.
//  Copyright © 2018 Kampfire Technologies. All rights reserved.
//

import Foundation
import RealmSwift
import Crashlytics

@objcMembers class EventRanker: Object {
    dynamic var key = "" //One for each event.
    
    dynamic var oprLastModified: String?
    dynamic var matchesLastModified: String?
    dynamic var statusesLastModified: String?
    
    let rankedTeams = List<ScoutedTeam>()
    
    ///Teams that have been picked; the ones that are no longer in pick list
    let pickedTeams = List<ScoutedTeam>()
    
    let computedStats = List<ComputedStats>()
    
    func isInPickList(team: Team) -> Bool {
        return !pickedTeams.contains(team.scouted!)
    }
    
    ///Must be within write transaction
    func setIsInPickList(_ isIn: Bool, team: Team) {
        guard rankedTeams.contains(team.scouted!) else {
            CLSNSLogv("Trying to set team in pick list that is not even part of the event", getVaList([]))
            
            return
        }
        
        if isIn {
            //Remove it from the picked teams
            if let index = pickedTeams.index(of: team.scouted!) {
                pickedTeams.remove(at: index)
            } else {
                //Already not in
            }
        } else {
            //Add it to the picked teams
            guard !pickedTeams.contains(team.scouted!) else {
                //Already in the pick list so return
                return
            }
            
            pickedTeams.append(team.scouted!)
        }
    }
    
    override static func primaryKey() -> String {
        return "key"
    }
}

//Stuff from TBA or cached locally
@objcMembers class ComputedStats: Object {
    dynamic var scoutedTeam: ScoutedTeam?
    dynamic var eventRanker: EventRanker?
    
    //"computedStats_\(ranker.key)_\(team.key)"
    dynamic var key = ""
    
    override static func primaryKey() -> String {
        return "key"
    }
    
    let opr = RealmOptional<Double>()
    let dpr = RealmOptional<Double>()
    let ccwm = RealmOptional<Double>()
    
    ///--Rank and Team Status
    dynamic var rank = RealmOptional<Int>()
    ///An HTML formatted string from TBA about Team's status at an event
    dynamic var overallStatusString: String?
    
//    dynamic var statusLastModified: String?
}

@objcMembers class ScoutedTeam: Object, HasGeneralEquivalent {
    
    typealias SelfObject = ScoutedTeam
    
    typealias GeneralType = Team
    
//    var ranker: GeneralRanker? {
//        get {
//            let rankers = LinkingObjects(fromType: GeneralRanker.self, property: "rankedTeams")
//            return rankers.first
//        }
//    }
    
    let eventRankers = LinkingObjects(fromType: EventRanker.self, property: "rankedTeams")
    
    ///Cross Year Values
    dynamic var key = ""
    
    let comments = List<TeamComment>()
    
    dynamic var programmingLanguage: String?
    dynamic var computerVisionCapability: String?
    let robotHeight = RealmOptional<Double>()
    let robotWeight = RealmOptional<Double>()
    let robotLength = RealmOptional<Double>()
    let robotWidth = RealmOptional<Double>()
    dynamic var frontImage: Data?
    dynamic var strategy: String?
    dynamic var canBanana = false
    let driverXP = RealmOptional<Double>()
    dynamic var driveTrain: String?
    
    ///Game Based Values
    dynamic var scaleCapability: String?
    dynamic var switchCapability: String?
    dynamic var vaultCapability: String?
    dynamic var climbCapability: String?
    
    dynamic var climberType: String?
    
    override static func primaryKey() -> String {
        return "key"
    }
    
    //To connect to the general team
    dynamic var cache: GeneralType?
    
    override static func ignoredProperties() -> [String] {
        return ["cache"]
    }
    
    func computedStats(forEvent event: Event) -> ComputedStats? {
        if let ranker = RealmController.realmController.getTeamRanker(forEvent: event) {
            //Find the computed stats that has this team and this ranker
            let proposedKey = "computedStats_\(ranker.key)_\(self.key)"
            
            if let computedStats = RealmController.realmController.syncedRealm.object(ofType: ComputedStats.self, forPrimaryKey: proposedKey) {
                return computedStats
            } else {
                //Create one and return it
                let computedStats = ComputedStats()
                computedStats.key = proposedKey
                
                computedStats.scoutedTeam = self
                computedStats.eventRanker = ranker
                
                RealmController.realmController.genericWrite(onRealm: .Synced) {
                    RealmController.realmController.syncedRealm.add(computedStats)
                }
                
                return computedStats
            }
        } else {
            Crashlytics.sharedInstance().recordCustomExceptionName("No Event Ranker", reason: "No ranker for event when trying to get Computed Stats", frameArray: [])
            return nil
        }
    }
    
}

@objcMembers class TeamComment: Object {
    dynamic var bodyText: String = ""
    dynamic var datePosted = Date()
    dynamic var author: String = ""
}

@objcMembers class ScoutedMatch: Object, HasGeneralEquivalent {
    dynamic var key = ""
    let blueScore = RealmOptional<Int>()
    let blueRP = RealmOptional<Int>()
    let redScore = RealmOptional<Int>()
    let redRP = RealmOptional<Int>()
    
    override static func primaryKey() -> String {
        return "key"
    }
    
    typealias SelfObject = ScoutedMatch
    typealias GeneralType = Match
    dynamic var cache: Match?
    override static func ignoredProperties() -> [String] {
        return ["cache"]
    }
}

@objcMembers class ScoutedMatchPerformance: Object, HasGeneralEquivalent {
    dynamic var key = ""
    let timeMarkers = LinkingObjects(fromType: TimeMarker.self, property: "scoutedMatchPerformance")
    
    //--- Maybe try to remove
    dynamic var defaultScoutID: String = "default"
    var prefferedScoutID: String {
        if defaultScoutID != "default" {
            return defaultScoutID
        } else {
            //Choose the last scout id to use
            return scoutIDs.last ?? ""
        }
    }
    var scoutIDs: [String] {
        var ids = [String]()
        for marker in timeMarkers {
            if !ids.contains(marker.scoutID) {
                ids.append(marker.scoutID)
            }
        }
        
        //Make sure all of them are represented, TAKE OUT LATER
        var doesNotHaveAll = false
        for id in ids {
            if !trackedScoutIDs.contains(id) {
                RealmController.realmController.genericWrite(onRealm: .Synced) {
                    trackedScoutIDs.append(id)
                }
                doesNotHaveAll = true
            }
        }
        
        return Array(trackedScoutIDs)
    }
    let trackedScoutIDs = List<String>()
    
    dynamic var climbStatus: String? = nil
    dynamic var climbAssistStatus: String? = nil
    
    dynamic var didCrossAutoLine: Bool = false
    
    override static func primaryKey() -> String {
        return "key"
    }
    
    typealias SelfObject = ScoutedMatchPerformance
    typealias GeneralType = TeamMatchPerformance
    dynamic var cache: TeamMatchPerformance?
    override static func ignoredProperties() -> [String] {
        return ["cache"]
    }
    
    var hasBeenScouted: Bool {
        get {
            let scoutIDs = Array(self.scoutIDs)
            if scoutIDs.count >= 1 {
                return true
            } else {
                return false
            }
        }
    }
    
    func timeMarkers(forScoutID scoutID: String) -> [TimeMarker] {
        return timeMarkers.filter {$0.scoutID == scoutID}
    }
}
