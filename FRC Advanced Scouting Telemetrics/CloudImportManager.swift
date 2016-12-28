//
//  CloudImportManager.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 12/27/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import Foundation
import CoreData
import Crashlytics

class CloudEventImportManager {
    private let dataManager = DataManager()
    private let managedContext = DataManager.managedContext
    private let cloudConnection = CloudData()
    
    private let completionHandler: (Bool, ImportError?) -> Void
    
    //Pre-existing objects
    private let currentTeams: [Team]
    private let currentMatches: [Match]
    private let currentLocalMatchPerformances: [LocalMatchPerformance]
    private let currentLocalMatches: [LocalMatch]
    private let frcEvent: FRCEvent
    
    //Created objects (Including objects that were pre-existing but still would have been created were they not)
    private var eventObject: Event?
    private var localEventObject: LocalEvent?
    private var teamObjects: [Team] = []
    private var teamEventPerformanceObjects: [TeamEventPerformance] = []
    private var matchObjects: [Match] = []
    private var teamMatchPerformanceObjects: [TeamMatchPerformance] = []
    
    init(shouldPreload: Bool, forEvent frcEvent: FRCEvent, withCompletionHandler completionHandler: @escaping (Bool, ImportError?) -> Void) {
        if shouldPreload {
            
        }
        
        self.completionHandler = completionHandler
        currentTeams = dataManager.localTeamRanking()
        currentMatches = dataManager.matches()
        do {
            currentLocalMatchPerformances = try managedContext.fetch(LocalMatchPerformance.fetchRequest())
        } catch {
            NSLog("Unable to fetch local match performances")
            currentLocalMatchPerformances = []
        }
        do {
            currentLocalMatches = try managedContext.fetch(LocalMatch.fetchRequest())
        } catch {
            NSLog("Unable to fetch current local matches")
            currentLocalMatches = []
        }
        self.frcEvent = frcEvent
    }
    
    ///Takes an FRCEvent and creates core data objects in the database
    func `import`() {
        CLSNSLogv("Beginning import of event: %@", getVaList([frcEvent.key]))
        //Create an event object
        let event: Event
        event = Event(entity: NSEntityDescription.entity(forEntityName: "Event", in: managedContext)!, insertInto: managedContext)
//        if #available(iOS 10.0, *) {
//            event = Event(entity: Event.entity(), insertInto: managedContext)
//        } else {
//            event = Event(entity: NSEntityDescription.entity(forEntityName: "Event", in: managedContext)!, insertInto: managedContext)
//        }
        
        //Start loading the teams
        cloudConnection.teams(forEventKey: frcEvent.key, withCompletionHandler: importTeams)
        
        event.code = frcEvent.eventCode
        event.eventType = frcEvent.eventType as NSNumber
        event.eventTypeString = frcEvent.eventTypeString
        event.key = frcEvent.key
        event.name = frcEvent.name
        event.year = frcEvent.year as NSNumber
        
        //Create the local one
        if (event.value(forKey: "localFP") as? [LocalEvent])?.count ?? 0 == 0 {
            let localEvent: LocalEvent
            localEvent = LocalEvent(entity: NSEntityDescription.entity(forEntityName: "LocalEvent", in: managedContext)!, insertInto: managedContext)
//            if #available(iOS 10.0, *) {
//                localEvent = LocalEvent(entity: LocalEvent.entity(), insertInto: managedContext)
//            } else {
//                localEvent = LocalEvent(entity: NSEntityDescription.entity(forEntityName: "LocalEvent", in: managedContext)!, insertInto: managedContext)
//            }
            localEvent.key = event.key
            localEventObject = localEvent
        }
        
        eventObject = event
    }
    
    private func importTeams(fromTeams teams: [FRCTeam]?) {
        CLSNSLogv("Beginning import of teams from event", getVaList([]))
        if let frcTeams = teams {
            for frcTeam in frcTeams {
                //Check to make sure the team isn't already in the database
                let team: Team
                if let index = currentTeams.index(where: {team in
                    return team.key == frcTeam.key
                }) {
                    //If it is in the database, use that team and just update its properties if out of date
                    team = currentTeams[index]
                } else {
                    //Create a new team and set its properties
                    team = Team(entity: NSEntityDescription.entity(forEntityName: "Team", in: managedContext)!, insertInto: managedContext)
//                    if #available(iOS 10.0, *) {
//                        team = Team(entity: Team.entity(), insertInto: managedContext)
//                    } else {
//                        team = Team(entity: NSEntityDescription.entity(forEntityName: "Team", in: managedContext)!, insertInto: managedContext)
//                    }
                }
                
                team.key = frcTeam.key
                team.location = frcTeam.location
                team.name = frcTeam.name
                team.nickname = frcTeam.nickname
                team.rookieYear = frcTeam.rookieYear as NSNumber
                team.teamNumber = frcTeam.teamNumber.description
                team.website = frcTeam.website
                
                //Check if it already has a local equivalent
                let localTeam: LocalTeam
                if (team.value(forKey: "localFP") as? NSSet)?.allObjects.count ?? 0 > 0 {
                    localTeam = team.local()
                } else {
                    //Doesn't have a local equivalent, make one
                    localTeam = LocalTeam(entity: NSEntityDescription.entity(forEntityName: "LocalTeam", in: managedContext)!, insertInto: managedContext)
                    //                    if #available(iOS 10.0, *) {
                    //                        localTeam = LocalTeam(entity: LocalTeam.entity(), insertInto: managedContext)
                    //                    } else {
                    //                        localTeam = LocalTeam(entity: NSEntityDescription.entity(forEntityName: "LocalTeam", in: managedContext)!, insertInto: managedContext)
                    //                    }
                    localTeam.key = team.key
                }
                //Add the local team to the local event object's ranked teams
                if !(localTeam.localEvents?.contains(where: {lEvent in
                    return (lEvent as! LocalEvent) == localEventObject
                }))! {
                    localTeam.addToLocalEvents(localEventObject!)
                }
                //Add the local team to the local ranking object
                if localTeam.ranker == nil {
                    localTeam.ranker = dataManager.getLocalTeamRankingObject()
                }
                
                //Now create the TeamEventPerformance object
                let teamEventPerformance: TeamEventPerformance
                teamEventPerformance = TeamEventPerformance(entity: NSEntityDescription.entity(forEntityName: "TeamEventPerformance", in: managedContext)!, insertInto: managedContext)
//                if #available(iOS 10.0, *) {
//                    teamEventPerformance = TeamEventPerformance(entity: TeamEventPerformance.entity(), insertInto: managedContext)
//                } else {
//                    teamEventPerformance = TeamEventPerformance(entity: NSEntityDescription.entity(forEntityName: "TeamEventPerformance", in: managedContext)!, insertInto: managedContext)
//                }
                teamEventPerformance.event = eventObject!
                teamEventPerformance.team = team
                
                teamEventPerformanceObjects.append(teamEventPerformance)
                
                teamObjects.append(team)
            }
            
            //Now get the matches
            cloudConnection.matches(forEventKey: frcEvent.key, withCompletionHandler: importMatches)
        } else {
            completionHandler(false, .ErrorLoadingTeams)
        }
    }
    
    private func importMatches(fromMatches matches: [FRCMatch]?) {
        CLSNSLogv("Beginning import of matches from event", getVaList([]))
        if let frcMatches = matches {
            for frcMatch in frcMatches {
                let match: Match
                if let index = currentMatches.index(where: {match in
                    return match.key == frcMatch.key
                }) {
                    match = currentMatches[index]
                } else {
                    //Create a new match
                    match = Match(entity: NSEntityDescription.entity(forEntityName: "Match", in: managedContext)!, insertInto: managedContext)
//                    if #available(iOS 10.0, *) {
//                        match = Match(entity: Match.entity(), insertInto: managedContext)
//                    } else {
//                        match = Match(entity: NSEntityDescription.entity(forEntityName: "Match", in: managedContext)!, insertInto: managedContext)
//                    }
                }
                
                match.key = frcMatch.key
                match.matchNumber = frcMatch.matchNumber as NSNumber
                match.time = frcMatch.time
                
                match.event = eventObject
                
                //Set up all the teams in the match
                if let matchAlliances = frcMatch.alliances {
                    for matchAlliance in matchAlliances {
                        if let teamStrings = matchAlliance.value.teams {
                            for teamString in teamStrings {
                                //Find the TeamEventPerformance that pertains to this team and match
                                let eventPerformance = teamEventPerformanceObjects[teamEventPerformanceObjects.index(where: {eventPerformance in
                                    return eventPerformance.team.key == teamString
                                })!]
                                
                                //Create the matchPerformance object
                                let matchPerformance: TeamMatchPerformance
                                matchPerformance = TeamMatchPerformance(entity: NSEntityDescription.entity(forEntityName: "TeamMatchPerformance", in: managedContext)!, insertInto: managedContext)
//                                if #available(iOS 10.0, *) {
//                                    matchPerformance = TeamMatchPerformance(entity: TeamMatchPerformance.entity(), insertInto: managedContext)
//                                } else {
//                                    matchPerformance = TeamMatchPerformance(entity: NSEntityDescription.entity(forEntityName: "TeamMatchPerformance", in: managedContext)!, insertInto: managedContext)
//                                }
                                
                                matchPerformance.match = match
                                matchPerformance.eventPerformance = eventPerformance
                                matchPerformance.allianceColor = matchAlliance.key.rawValue
                                matchPerformance.allianceTeam = (teamStrings.index(of: teamString)! + 1) as NSNumber //The array of team strings comes in the correct order from the cloud
                                matchPerformance.key = "\(match.key!)_\(teamString)"
                                
                                //Check for a local object
                                if !currentLocalMatchPerformances.contains(where: {localMatchPerformance in
                                    return localMatchPerformance.key == matchPerformance.key
                                }) {
                                    //Create a local object
                                    let localMatchPerformance = LocalMatchPerformance(entity: NSEntityDescription.entity(forEntityName: "LocalMatchPerformance", in: managedContext)!, insertInto: managedContext)
                                    localMatchPerformance.key = matchPerformance.key
                                }
                                
                                teamMatchPerformanceObjects.append(matchPerformance)
                            }
                        }
                    }
                } else {
                    //TODO: Send an error saying the alliance data isn't up yet
                }
                
                //Create the local match
                if !currentLocalMatches.contains(where: {localMatch in
                    return localMatch.key == match.key
                }) {
                    let localMatch: LocalMatch
                    localMatch = LocalMatch(entity: NSEntityDescription.entity(forEntityName: "LocalMatch", in: managedContext)!, insertInto: managedContext)
//                    if #available(iOS 10, *) {
//                        localMatch = LocalMatch(entity: LocalMatch.entity(), insertInto: managedContext)
//                    } else {
//                        localMatch = LocalMatch(entity: NSEntityDescription.entity(forEntityName: "LocalMatch", in: managedContext)!, insertInto: managedContext)
//                    }
                    localMatch.key = match.key
                }
                
                matchObjects.append(match)
            }
            
            finalize()
        } else {
            //TODO: Send an error saying the match data isn't up yet and to check back later
            completionHandler(false, .ErrorLoadingMatches)
        }
    }
    
    private func finalize() {
        CLSNSLogv("Finalizing event import", getVaList([]))
        //Do any last cleanup
        dataManager.commitChanges()
        completionHandler(true, nil)
    }
    
    enum ImportError: Error {
        case ErrorLoadingTeams
        case ErrorLoadingMatches
        
        
    }
}
