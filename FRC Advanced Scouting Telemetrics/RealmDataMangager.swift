//
//  RealmDataMangager.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 1/7/18.
//  Copyright © 2018 Kampfire Technologies. All rights reserved.
//

//NOTE: With realm, you can only use objects on the thread they were created! See Realm Swift Model docs. You can use ThreadSafeReference to pass objects.

import Foundation
import RealmSwift
import Crashlytics

let DidLogIntoSyncServerNotification = NSNotification.Name(rawValue: "DidLogIntoSyncServer")
private let rosServerAddress = "fastapp.tech:9443"

class RealmController {
    
    static var realmController: RealmController = RealmController()
    
    var generalRealm: Realm!
    var syncedRealm: Realm!
    
    let syncAuthURL = URL(string: "https://\(rosServerAddress)")!
    var syncedRealmURL: URL?
    var generalRealmURL: URL?
    var scoutedRealmConfig: Realm.Configuration?
    var generalRealmConfig: Realm.Configuration?
    var currentSyncUser: SyncUser?
    
    var tbaUpdatingReloader: TBAUpdatingDataReloader?
    
    static let isSpectatorModeKey = "FAST-IsInSpectatorMode"
    static var isInSpectatorMode: Bool {
        return UserDefaults.standard.value(forKey: isSpectatorModeKey) as? Bool ?? false
    }
    
    private init() {
        generalRealm = nil
        
        syncedRealm = nil
        if let currentUser = SyncUser.current {
            //Use this user to log in
            currentSyncUser = currentUser
            openSyncedRealm(withSyncUser: currentUser, shouldOpenSyncedRealmAsync: false)
        } else {
            //Is not logged in
            currentSyncUser = nil
        }
        
        SyncManager.shared.errorHandler = {error, session in
            CLSNSLogv("Realm Sync Error: \(error)", getVaList([]))
            Crashlytics.sharedInstance().recordError(error)
        }
    }
    
    func openLocalRealm() {
        var generalConfig = Realm.Configuration()
        generalConfig.fileURL = generalConfig.fileURL?.deletingLastPathComponent().appendingPathComponent("LocalGeneralRealm.realm")
        generalRealmConfig?.objectTypes = [Team.self,Match.self,TeamEventPerformance.self,Event.self,TeamMatchPerformance.self]
        generalConfig.schemaVersion = 2
        generalConfig.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 2 {
                
            }
        }
        
        var scoutedConfig = Realm.Configuration()
        scoutedConfig.fileURL = scoutedConfig.fileURL?.deletingLastPathComponent().appendingPathComponent("LocalScoutedRealm.realm")
        scoutedRealmConfig?.objectTypes = [EventRanker.self, ScoutedTeam.self, ScoutedMatch.self, ScoutedMatchPerformance.self, TimeMarker.self, ComputedStats.self, TeamComment.self]
        scoutedConfig.schemaVersion = 2
        scoutedConfig.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 1 {
                
            }
            if oldSchemaVersion < 2 {
                
            }
        }
        
        do {
            self.generalRealm = try Realm(configuration: generalConfig)
            self.syncedRealm = try Realm(configuration: scoutedConfig)
            
            self.tbaUpdatingReloader = TBAUpdatingDataReloader(withScoutedRealmConfig: scoutedConfig, andGeneralRealmConfig: generalConfig)
            self.tbaUpdatingReloader?.setGeneralUpdaters()
        } catch {
            CLSNSLogv("Error opening local realms: \(error)", getVaList([]))
            Crashlytics.sharedInstance().recordError(error)
        }
    }
    
    func openSyncedRealm(withSyncUser syncUser: SyncUser, shouldOpenSyncedRealmAsync: Bool, completionHandler:  ((Error?) -> Void)? = nil) {
        
        let scoutedRealmURL = URL(string: "realms://\(rosServerAddress)/~/scouted_data")!
        syncedRealmURL = scoutedRealmURL
        
        //Create sync config with sync user
        let scoutedSyncConfig = SyncConfiguration(user: syncUser, realmURL: scoutedRealmURL)
        scoutedRealmConfig = Realm.Configuration(syncConfiguration: scoutedSyncConfig)
        
        //Set the object types to be used in the Synced Realm to keep it separate from the other realm
        scoutedRealmConfig?.objectTypes = [EventRanker.self, ScoutedTeam.self, ScoutedMatch.self, ScoutedMatchPerformance.self, TimeMarker.self, ComputedStats.self, TeamComment.self]
        
        //Now for the general realm
        let generalStructureRealmURL = URL(string: "realms://\(rosServerAddress)/~/general_structure")!
        generalRealmURL = generalStructureRealmURL
        let generalSyncConfig = SyncConfiguration(user: syncUser, realmURL: generalStructureRealmURL)
        generalRealmConfig = Realm.Configuration(syncConfiguration: generalSyncConfig)
        generalRealmConfig?.objectTypes = [Team.self,Match.self,TeamEventPerformance.self,Event.self,TeamMatchPerformance.self]
        
        let realmErrorHandler: (Error) -> Void = { (error: Error) in
            CLSNSLogv("Error opening realms: \(error)", getVaList([]))
            Crashlytics.sharedInstance().recordError(error)
            Answers.logCustomEvent(withName: "Opened Realms", customAttributes: ["Success":false])
            
            //Show an alert
            let alert = UIAlertController(title: "Error Opening Databases", message: "There was an error opening the database files, this could be because your device is too low on storage space: \(error)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            (UIApplication.shared.delegate as! AppDelegate).presentViewControllerOnTop(alert, animated: true)
        }
        
        do {
            //Attempt to open the realm
            self.generalRealm = try Realm(configuration: generalRealmConfig!)
            
            let syncedRealmCompletionHandler: () -> Void = {
                NotificationCenter.default.post(name: DidLogIntoSyncServerNotification, object: self)
                CLSNSLogv("Did log into and open realms", getVaList([]))
                Answers.logCustomEvent(withName: "Opened Realms", customAttributes: ["Success":true])
                
                self.performSanityChecks()
                
                self.tbaUpdatingReloader = TBAUpdatingDataReloader(withScoutedRealmConfig: self.scoutedRealmConfig!, andGeneralRealmConfig: self.generalRealmConfig!)
                self.tbaUpdatingReloader?.setGeneralUpdaters()
            }
            
            if shouldOpenSyncedRealmAsync {
                Realm.asyncOpen(configuration: scoutedRealmConfig!) {realm, error in
                    if let realm = realm {
                        self.syncedRealm = realm
                        syncedRealmCompletionHandler()
                    } else if let error = error {
                        realmErrorHandler(error)
                    }
                    
                    completionHandler?(error)
                }
            } else {
                //Not async (Normal)
                self.syncedRealm = try Realm(configuration: scoutedRealmConfig!)
                syncedRealmCompletionHandler()
                
                completionHandler?(nil)
            }
        } catch {
            realmErrorHandler(error)
        }
    }
    
    func performSanityChecks() {
        syncedRealm.beginWrite()
        
        //Remove duplicates in the rankers (still not sure what causes them)
        let eventRankers = syncedRealm.objects(EventRanker.self)
        
        var didRemoveDuplicates = false
        for ranker in eventRankers {
            var seen = [ScoutedTeam]()
            for team in ranker.rankedTeams {
                if seen.contains(team) {
                    let indexOfTeam = ranker.rankedTeams.index(of: team)!
                    ranker.rankedTeams.remove(at: indexOfTeam)
                    didRemoveDuplicates = true
                } else {
                    seen.append(team)
                }
            }
        }
        
        if didRemoveDuplicates {
            CLSNSLogv("Did remove duplicates in ranker", getVaList([]))
            
            Crashlytics.sharedInstance().recordCustomExceptionName("Did have to remove duplicates", reason: "There were duplicates in the event rankers.", frameArray: [])
            
            do {
                try syncedRealm.commitWrite()
            } catch {
                CLSNSLogv("Unable to commit sanity checks: \(error)", getVaList([]))
                Crashlytics.sharedInstance().recordError(error)
            }
        } else {
            syncedRealm.cancelWrite()
        }
    }
    
    func closeRealms() {
        
        self.tbaUpdatingReloader = nil
        
        //Remove user default
        UserDefaults.standard.setValue(nil, forKeyPath: "LoggedInTeam")
        
        //Logout button pressed
        currentSyncUser?.logOut()
        currentSyncUser = nil
        
        syncedRealm = nil
        generalRealm = nil
        
        //Now return to the log in screen
        let onboarding = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        UIApplication.shared.delegate!.window??.rootViewController = onboarding
    }
    
    func sanityCheckStructure(ofEvent event: Event) -> Bool {
        guard let eventRanker = syncedRealm.object(ofType: EventRanker.self, forPrimaryKey: event.key) else {
            return false
        }
        
        //Check if the event and everything associated with it has a scouted object companion as well. If they do not then return false.
        
        //Matches
        let matches = event.matches
        
        for match in matches {
            if match.scouted == nil {
                return false
            }
        }
        
        //Match Performances
        let matchPerformances = matches.reduce([TeamMatchPerformance]()) {matchPerformances, nextMatch in
            return matchPerformances + nextMatch.teamPerformances
        }
        
        for matchPerformance in matchPerformances {
            if matchPerformance.scouted == nil {
                return false
            }
        }
        
        //Teams
        let teams = event.teamEventPerformances.reduce([Team]()) {teams, nextTeamEventPerformance in
            return teams + [nextTeamEventPerformance.team!]
        }
        
        for team in teams {
            if team.scouted == nil {
                return false
            }
        }
        
        //Then check the event ranker
        for scoutedTeam in eventRanker.rankedTeams {
            if scoutedTeam.general == nil {
                return false
            }
        }
        
        return true
    }
    
    func delete(object: Object) {
        delete(objects: [object])
    }
    
    func delete<T: Object>(objects: [T]) {
        let realm = objects.first?.realm
        
        var didStartWrite = false
        if !(realm?.isInWriteTransaction ?? false) {
            didStartWrite = true
            realm?.beginWrite()
        }
        
        for object in objects {
            realm?.delete(object)
        }
        
        if didStartWrite {
            do {
                try realm?.commitWrite()
            } catch {
                CLSNSLogv("Unable to delete objects", getVaList([]))
                Crashlytics.sharedInstance().recordError(error)
            }
        }
    }
    
    //MARK: - Team Ranking
    func getTeamRanker(forEvent event: Event) -> EventRanker? {
        return syncedRealm.object(ofType: EventRanker.self, forPrimaryKey: event.key)
    }
    
    func teamRanking(forEvent event: Event) -> [ScoutedTeam] {
        if let eventRanker = getTeamRanker(forEvent: event) {
            return Array(eventRanker.rankedTeams)
        } else {
            return []
        }
    }
    
    func teamRanking(forEvent event: Event) -> [Team] {
        let rankedTeams: [ScoutedTeam] = teamRanking(forEvent: event)
        
        return rankedTeams.map {$0.general!}
    }
    
    func moveTeam(from fromIndex: Int, to toIndex: Int, inEvent event: Event) {
        try! syncedRealm.write {
            let ranker = getTeamRanker(forEvent: event)
            ranker!.rankedTeams.move(from: fromIndex, to: toIndex)
        }
    }
    
    //MARK: - Teams
    func team(forTeamNumber teamNumber: String) -> Team? {
        if let team = generalRealm.object(ofType: Team.self, forPrimaryKey: "frc\(teamNumber)") {
            return team
        } else {
            CLSNSLogv("Unable to find team for team number: \(teamNumber)", getVaList([]))
            return nil
        }
    }
    
    func eventPerformance(forTeam team: Team, atEvent event: Event) -> TeamEventPerformance? {
        //Find the team event performance that ties to both the team and the event
        let proposedKey = "\(team.key)_\(event.key)"
        return generalRealm.object(ofType: TeamEventPerformance.self, forPrimaryKey: proposedKey)
    }
    
    //MARK: - Editing a realm
    enum RealmType {
        case General
        case Synced
        
        var realm: Realm {
            get {
                switch self {
                case .General:
                    return RealmController.realmController.generalRealm
                case .Synced:
                    return RealmController.realmController.syncedRealm
                }
            }
        }
    }
    @discardableResult func genericWrite(onRealm realm: RealmType, blockToWrite: (() throws ->Void)) -> Bool {
        if realm.realm.isInWriteTransaction {
            //If it's already in a write transaction just execute it
            try? blockToWrite()
            return true
        } else {
            do {
                try realm.realm.write(blockToWrite)
                return true
            } catch {
                CLSNSLogv("Failed to write to realm with error: \(error)", getVaList([]))
                Crashlytics.sharedInstance().recordError(error)
                return false
            }
        }
    }
}

//MARK: - General vs Scouted Models
protocol HasScoutedEquivalent: class {
    associatedtype SelfObject: Object
    associatedtype ScoutedType: Object
    var key: String {get set}
    var cache: ScoutedType? {get set}
}

protocol HasGeneralEquivalent: class {
    associatedtype SelfObject: Object
    associatedtype GeneralType: Object, HasScoutedEquivalent
    var key: String {get set}
    var cache: GeneralType? {get set}
}

extension HasGeneralEquivalent {
    ///Returns the universal object and sets the transient property for quick future fetching
    var general: GeneralType? {
        get {
            if let universalObject = cache {
                return universalObject
            } else {
                let universalObject = fetchGeneralObject()
                
                if universalObject == nil {
                    //TODO: There is no general object for the scouted object, we should throw an error
                }
                
                self.cache = universalObject
                return universalObject
            }
        }
    }
    
    ///Fetches the universal object, does not set it into the transient property
    func fetchGeneralObject() -> GeneralType? {
        return RealmController.realmController.generalRealm.object(ofType: GeneralType.self, forPrimaryKey: key)
    }
}

extension HasScoutedEquivalent {
    ///Returns the local object and sets the transient property for quick future fetching
    var scouted: ScoutedType? {
        get {
            if let localObject = cache {
                return localObject
            } else {
                let localObject = fetchScoutedObject()
                
                if let object = localObject {
                    self.cache = object
                    return object
                } else {
                    return nil
                }
            }
        }
    }
    
    ///Fetches the local object, does not set it into the transient property
    func fetchScoutedObject() -> ScoutedType? {
        return RealmController.realmController.syncedRealm.object(ofType: ScoutedType.self, forPrimaryKey: key)
    }
}

//MARK: - Enums
enum ProgrammingLanguage: String, CustomStringConvertible {
    case Java
    case CPlusPlus = "C++"
    case LabView = "Lab View"
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static var allValues: [ProgrammingLanguage] {
        get {
            return [.Java, .CPlusPlus, .LabView]
        }
    }
    
    static var allStringValues: [String] {
        get {
            return ProgrammingLanguage.allValues.map({$0.description})
        }
    }
}

enum GamePlayStrategy: String, CustomStringConvertible {
    case Offensive
    case Defensive
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static var allValues: [GamePlayStrategy] {
        get {
            return [.Offensive, .Defensive]
        }
    }
    
    static var allStringValues: [String] {
        get {
            return GamePlayStrategy.allValues.map({$0.description})
        }
    }
}

enum Capability: String, CustomStringConvertible {
    case Yes
    case Somewhat
    case No
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static var allValues: [Capability] {
        get {
            return [.Yes, .Somewhat, .No]
        }
    }
    
    static var allStringValues: [String] {
        get {
            return Capability.allValues.map({$0.description})
        }
    }
}

enum SimpleCapability: String, CustomStringConvertible {
    case Yes
    case No
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static var allValues: [SimpleCapability] {
        get {
            return [.Yes, .No]
        }
    }
    
    static var allStringValues: [String] {
        get {
            return SimpleCapability.allValues.map({$0.description})
        }
    }
}

enum ClimbStatus: String, CustomStringConvertible {
    case Successful
    case Attempted
    case NotAttempted = "Not Attempted"
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static let allValues: [ClimbStatus] = [.Successful, .Attempted, .NotAttempted]
}

enum ClimbAssistStatus: String, CustomStringConvertible {
    case SuccessfullyAssisted = "Successfully Assisted"
    case AttemptedAssist = "Attempted Assist"
    case DidNotAssist = "Did Not Assist"
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static let allValues: [ClimbAssistStatus] = [.SuccessfullyAssisted, .AttemptedAssist, .DidNotAssist]
}

//2018
enum CubeSource: String, CustomStringConvertible {
    case Pile
    case Line
    case Portal
    case Other
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static let allValues: [CubeSource] = [.Pile, .Line, .Portal, .Other]
}

enum CubeDestination: String, CustomStringConvertible {
    case Scale
    case Switch
    case OpponentSwitch = "Opponent's Switch"
    case Vault
    case Dropped
    
    var description: String {
        get {
            return self.rawValue
        }
    }
    
    static let allValues: [CubeDestination] = [.Scale, .Switch, .OpponentSwitch, .Vault, .Dropped]
}

enum ClimberType: String, CustomStringConvertible {
    case None
    case SlideBar = "Slide Bar"
    case HalfBar = "Half Bar"
    case FullBar = "Full Bar"
    case Deployable
    case BuddyDouble = "Buddy Double"
    case BuddyTriple = "Buddy Triple"
    
    var description: String {
        return self.rawValue
    }
    
    static let allValues: [ClimberType] = [.None, .SlideBar, .HalfBar, .FullBar, .Deployable, .BuddyDouble, .BuddyTriple]
}
