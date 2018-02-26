//
//  TeamMatchPerformance+CoreDataProperties.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 12/18/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers class TeamMatchPerformance: Object, HasScoutedEquivalent {
    dynamic var allianceColor = ""
    dynamic var allianceTeam = 0
    dynamic var key = ""
    
    dynamic var match: Match?
    
    dynamic var teamEventPerformance: TeamEventPerformance?
    
    override static func primaryKey() -> String {
        return "key"
    }
    
    typealias SelfObject = TeamMatchPerformance
    typealias LocalType = ScoutedMatchPerformance
    dynamic var cache: ScoutedMatchPerformance?
    override static func ignoredProperties() -> [String] {
        return ["cache"]
    }
    
    enum Alliance: String {
        case Red = "Red"
        case Blue = "Blue"
    }
    
    enum Slot: Int {
        case One = 1
        case Two = 2
        case Three = 3
    }
    
    var alliance: Alliance {
        get {
            return Alliance(rawValue: self.allianceColor)!
        }
    }
    
    var slot: Slot {
        get {
            return Slot(rawValue: self.allianceTeam)!
        }
    }
    
    var rankingPoints: Int? {
        switch allianceColor {
        case "Blue":
            return match?.scouted.blueRP.value
        case "Red":
            return match?.scouted.redRP.value
        default:
            assertionFailure()
            return -1
        }
    }
    
    var finalScore: Int? {
        switch allianceColor {
        case "Blue":
            return match?.scouted.blueScore.value
        case "Red":
            return match?.scouted.redScore.value
        default:
            assertionFailure()
            return -1
        }
    }
    
    var winningMargin: Int {
        let selfFinalScore = finalScore ?? 0
        switch allianceColor {
        case "Blue":
            return selfFinalScore - (match?.scouted.redScore.value ?? 0)
        case "Red":
            return selfFinalScore - (match?.scouted.blueScore.value ?? 0)
        default:
            assertionFailure()
            return -1
        }
    }
}

extension TeamMatchPerformance: HasStats {
    var stats: [StatName:()->StatValue] {
        get {
            return [
                StatName.TotalPoints:{
                    if let val = self.finalScore {
                        return StatValue.Integer(val)
                    } else {
                        return StatValue.NoValue
                    }
                },
                StatName.TotalRankingPoints:{
                    if let val = self.rankingPoints {
                        return StatValue.Integer(val)
                    } else {
                        return StatValue.NoValue
                    }
                },
                StatName.ClimbingStatus: {
                    if self.scouted.hasBeenScouted {
                        return StatValue.initWithOptional(value: self.scouted.climbStatus)
                    } else {
                        return StatValue.NoValue
                    }
                },
                StatName.ClimbAssistStatus: {
                    StatValue.initWithOptional(value: self.scouted.climbAssistStatus)
                },
                StatName.DidCrossAutoLine: {
                    StatValue.initWithOptional(value: self.scouted.didCrossAutoLine)
                },
                StatName.PercentCubesFromPile: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeSource.Pile.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalGrabbedCubes)
                },
                StatName.PercentCubesFromLine: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeSource.Line.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalGrabbedCubes)
                },
                StatName.PercentCubesFromPortal: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeSource.Portal.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalGrabbedCubes)
                },
                StatName.TotalGrabbedCubes: {
                    if self.scouted.hasBeenScouted {
                        let timeMarkers = self.scouted.timeMarkers(forScoutID: self.scouted.defaultScoutID).filter {$0.timeMarkerEventType == .GrabbedCube}
                        return StatValue.Integer(timeMarkers.count)
                    } else {
                        return StatValue.NoValue
                    }
                },
                StatName.PercentCubesPlacedInScale: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeDestination.Scale.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalPlacedCubes)
                },
                StatName.PercentCubesPlacedInSwitch: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeDestination.Switch.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalPlacedCubes)
                },
                StatName.PercentCubesPlacedInOpponentSwitch: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeDestination.OpponentSwitch.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalPlacedCubes)
                },
                StatName.PercentCubesPlacedInVault: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeDestination.Vault.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalPlacedCubes)
                },
                StatName.PercentCubesDropped: {
                    let timeMarkers = self.getTimeMarkers(withAssociatedLocation: CubeDestination.Dropped.rawValue)
                    return StatValue.Integer(timeMarkers.count) / self.statValue(forStat: .TotalPlacedCubes)
                },
                StatName.TotalPlacedCubes: {
                    if self.scouted.hasBeenScouted {
                        let timeMarkers = self.scouted.timeMarkers(forScoutID: self.scouted.defaultScoutID).filter {$0.timeMarkerEventType == .PlacedCube}
                        return StatValue.Integer(timeMarkers.count)
                    } else {
                        return StatValue.NoValue
                    }
                }
            ]
        }
    }
    
    func getTimeMarkers(withAssociatedLocation assocLocation: String) -> [TimeMarker] {
        return self.scouted.timeMarkers(forScoutID: self.scouted.defaultScoutID).filter {$0.associatedLocation == assocLocation}
    }
    
    enum StatName: String, CustomStringConvertible, StatNameable {
        case TotalPoints = "Total Points"
        case TotalRankingPoints = "Total Ranking Points"
        case ClimbingStatus = "Climbing Status"
        
        case ClimbAssistStatus = "Did Assist a Climb"
        
        //2018
        case DidCrossAutoLine = "Did Cross Auto Line"
        case PercentCubesFromPile = "Percent Cubes From Pile"
        case PercentCubesFromLine = "Percent Cubes From Line"
        case PercentCubesFromPortal = "Percent Cubes From Portal"
        case TotalGrabbedCubes = "Total Grabbed Cubes"
        
        case PercentCubesPlacedInScale = "Percent Cubes in Scale"
        case PercentCubesPlacedInSwitch = "Percent Cubes in Switch"
        case PercentCubesPlacedInOpponentSwitch = "Cubes in Opp. Switch"
        case PercentCubesPlacedInVault = "Percent Cubes in Vault"
        case PercentCubesDropped = "Percent Cubes Dropped"
        case TotalPlacedCubes = "Total Placed Cubes"
        
        var description: String {
            get {
                return self.rawValue
            }
        }
        
        static let allValues: [StatName] = [.TotalPoints, .TotalRankingPoints, .ClimbingStatus, .ClimbAssistStatus, .DidCrossAutoLine, .PercentCubesFromPile, .PercentCubesFromLine, .PercentCubesFromPortal, .TotalGrabbedCubes, .PercentCubesPlacedInScale, .PercentCubesPlacedInSwitch, .PercentCubesPlacedInOpponentSwitch, .PercentCubesPlacedInVault, .PercentCubesDropped, .TotalPlacedCubes]
    }
}