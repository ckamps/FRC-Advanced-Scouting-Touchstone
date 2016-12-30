//
//  DataManager.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 12/18/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import Foundation
import UIKit
import CoreData

//Remake of TeamDataManager for the newer data model

class DataManager {
	
	static let managedContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
	
	//MARK: Saving and deleting
	private func save() {
		do {
			try TeamDataManager.managedContext.save()
		} catch let error as NSError {
			NSLog("Could not save: \(error), \(error.userInfo)")
		}
	}
	
	func commitChanges() {
		NSLog("Committing Changes")
		save()
	}
	
	func discardChanges() {
		NSLog("Discarding Changes")
		TeamDataManager.managedContext.rollback()
	}
	
	func delete(_ objectsToDelete: NSManagedObject...) {
		for object in objectsToDelete {
			DataManager.managedContext.delete(object)
		}
	}
    
    func delete(_ objectsToDelete: [NSManagedObject]) {
        for object in objectsToDelete {
            DataManager.managedContext.delete(object)
        }
    }
    
	
	//MARK: - Team Ranking
	func getLocalTeamRankingObject() -> LocalTeamRanking {
        let fetchedObjects: [LocalTeamRanking]
        do {
            fetchedObjects = try DataManager.managedContext.fetch(LocalTeamRanking.fetchRequest())
        } catch {
            fetchedObjects = []
            NSLog("Problem fetching LocalTeamRanking object")
        }
		
		if fetchedObjects.count == 1 {
			return fetchedObjects[0]
		} else if fetchedObjects.count == 0 {
			//Create new localTeamRanking object
			let newObject = LocalTeamRanking(entity: NSEntityDescription.entity(forEntityName: "LocalTeamRanking", in: DataManager.managedContext)!, insertInto: DataManager.managedContext)
			return newObject
		} else {
			//There is more than one LocalTeamRanking objects, compile them into one
			let newObject = LocalTeamRanking(entity: NSEntityDescription.entity(forEntityName: "LocalTeamRanking", in: DataManager.managedContext)!, insertInto: DataManager.managedContext)
			
			let compiledObject = fetchedObjects.reduce(newObject) {reducedObject, partialRanker in
				reducedObject.addToLocalTeams(partialRanker.localTeams ?? NSOrderedSet())
				self.delete(partialRanker)
				return reducedObject
			}
			
			return compiledObject
		}
	}
	
	///Returns an array of Team objects ordered by their local general ranking
	private func simpleLocalTeamRanking() -> [Team] {
		let orderedLocalTeams = getLocalTeamRankingObject().localTeams?.array as! [LocalTeam]
		
        return LocalToUniversalConversion<LocalTeam,Team>(localObjects: orderedLocalTeams).convertToUniversal()!
	}
	
    //Use this function when getting local team rankings, not the simpleLocalTeamRanking
	///Returns an array of Team objects ordered by their local ranking for specified event
	func localTeamRanking(forEvent event: Event? = nil) -> [Team] {
        return event != nil ? localTeamRanking(forLocalEvent: event!.local()) : simpleLocalTeamRanking()
	}
    
    func localTeamRanking(forEvent event: Event) -> [LocalTeam] {
        return localTeamRanking(forLocalEvent: event.local())
    }
	
	///Returns an array of Team objects ordered by their local ranking for specified event
    func localTeamRanking(forLocalEvent localEvent: LocalEvent) -> [Team] {
        let orderedLocalTeams: [LocalTeam] = localTeamRanking(forLocalEvent: localEvent)
		
		return LocalToUniversalConversion<LocalTeam,Team>(localObjects: orderedLocalTeams).convertToUniversal()!
	}
    
    func localTeamRanking(forLocalEvent localEvent: LocalEvent) -> [LocalTeam] {
        return localEvent.rankedTeams?.array as! [LocalTeam]
    }
    
    //Reorder the team ranking
    func move(from fromIndex: Int, to toIndex: Int) {
        let teamRankingObject = getLocalTeamRankingObject()
        let movedTeam = teamRankingObject.localTeams?.array[fromIndex] as! LocalTeam
        teamRankingObject.removeFromLocalTeams(at: fromIndex)
        teamRankingObject.insertIntoLocalTeams(movedTeam, at: toIndex)
    }
    
    //MARK: - Teams
    ///Fetches one team with the specified number. Only use if fetching one team do not use sequentially.
    func team(withTeamNumber teamNumber: String) -> Team? {
        let fetchRequest: NSFetchRequest<Team> = Team.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "teamNumber like %@", argumentArray: [teamNumber])
        
        let teams: [Team]
        do {
            teams = try DataManager.managedContext.fetch(fetchRequest)
        } catch {
            NSLog("Unable to fetch team with error: \(error)")
            teams = []
        }
        
        assert(teams.count <= 1)
        return teams.first
    }
    
    func teamEventPerformances(inEvent event: Event) -> [TeamEventPerformance] {
        return event.teamEventPerformances?.allObjects as! [TeamEventPerformance]
    }
	
	func getEvents() -> [Event] {
		var events = [Event]()
		if #available(iOS 10.0, *) {
			do {
				events = try DataManager.managedContext.fetch(Event.fetchRequest())
			} catch {
				
			}
		} else {
			// Fallback on earlier versions
			do {
				events = try DataManager.managedContext.fetch(Event.fetchRequest())
			} catch {
				
			}
		}
		return events
	}
    
    //MARK: - Events
    func events() -> [Event] {
        let events: [Event]
        do {
            events = try DataManager.managedContext.fetch(Event.fetchRequest())
        } catch {
            NSLog("Unable to fetch events")
            events = []
        }
        
        return events
    }
    
    //MARK: - Matches
    func matches(inEvent event: Event) -> [Match] {
        return event.matches?.allObjects as! [Match]
    }
    
    func matches() -> [Match] {
        let fetchRequest: NSFetchRequest<Match> = Match.fetchRequest()
        let matches: [Match]
        do {
            matches = try DataManager.managedContext.fetch(fetchRequest)
        } catch {
            matches = []
            NSLog("Unable to fetch all matches")
        }
        return matches
    }
	
	enum Alliance: String {
		case Red = "Red"
		case Blue = "Blue"
	}
}

extension NSManagedObject {
	func local<T:NSManagedObject>() -> T {
		let localObject = (self.value(forKey: "localFP") as! [T]).first!
		
		return localObject
	}
	
	func universal<T:NSManagedObject>() -> T? {
		let universalObject = (self.value(forKey: "universalFP") as? NSSet)?.allObjects.first as? T
		
		return universalObject
	}
}

protocol HasLocalEquivalent {
    associatedtype SelfObject: NSManagedObject
    var key: String? {get set}
    static func genericFetchRequest() -> NSFetchRequest<NSManagedObject>
    static func specificFR() -> NSFetchRequest<SelfObject>
}

protocol HasUniversalEquivalent {
    associatedtype SelfObject: NSManagedObject
    associatedtype UniversalType: HasLocalEquivalent
    var key: String? {get set}
    static func genericFetchRequest() -> NSFetchRequest<NSManagedObject>
    static func specificFR() -> NSFetchRequest<SelfObject>
}

//Used for grouping a universal and its local object together
struct ObjectPair<U:HasLocalEquivalent, L:HasUniversalEquivalent> where L.UniversalType == U, L:NSManagedObject, U:NSManagedObject, L.SelfObject == L, U.SelfObject == U {
    let universal: U
    let local: L
    
    var key: String {
        return universal.key!
    }
    
    init(universal: U, local: L) {
        self.universal = universal
        self.local = local
    }
    
    //Init an array of ObjectPairs from an array of universals and locals. The two arrays must be the same size.
    static func fromArrays(universals: [U], locals: [L]) -> [ObjectPair<U,L>]? {
        if universals.count != locals.count {
            return nil
        }
        
        var objectPairs = [ObjectPair<U,L>]()
        for (index, universal) in universals.enumerated() {
            objectPairs.append(ObjectPair<U,L>(universal: universal, local: locals[index]))
        }
        return objectPairs
    }
    
    static func fromArray(universals: [U]) -> [ObjectPair<U,L>]? {
        let locals = UniversalToLocalConversion<U,L>(universalObjects: universals).convertToLocal()
        
        return fromArrays(universals: universals, locals: locals)
    }
    
    static func fromArray(locals: [L]) -> [ObjectPair<U,L>]? {
        let universals = LocalToUniversalConversion<L,U>(localObjects: locals).convertToUniversal()!
        
        return fromArrays(universals: universals, locals: locals)
    }
}

//MARK: - Universal-Local Translations
//When using fetched properties it is not a good idea to individually access many objects' fetched properties together because then numerous fetch requests will be queued at the same time which can be really slow. Instead this method uses one fetch request to grab all the wanted objects.
///Returns the local objects for the universal objects given (and in the same order). Use this instead of accessing multiple fetched properties back-to-back.
class UniversalToLocalConversion<U:HasLocalEquivalent, L:HasUniversalEquivalent> where L:NSManagedObject, L.SelfObject == L, L.UniversalType == U {
    private let universalObjects: [U]
    
    init(universalObjects: [U]) {
        self.universalObjects = universalObjects
    }
    
    func convertToLocal() -> [L] {
        let fetchRequest: NSFetchRequest<L> = L.specificFR() 
        
        //Create the array of predicates to compare local key values with universal key values
        var predicates: [NSPredicate] = []
        for object in universalObjects {
            predicates.append(NSPredicate(format: "key like %@", argumentArray: [object.key!]))
        }
        //Add them all to the compound predicate
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        fetchRequest.predicate = compoundPredicate
        
        let fetchedLocals: [L]
        do {
            fetchedLocals = try DataManager.managedContext.fetch(fetchRequest)
        } catch {
            NSLog("Unable to fetch local objects for multiple universal objects")
            return []
        }
        
        assert(fetchedLocals.count == universalObjects.count)
        
        //Sort the fetched locals to be in the same order as their universal counterparts
        let sortedFetchedLocals = fetchedLocals.sorted() {localFirst, localSecond in
            let universalFirstIndex = universalObjects.index() {$0.key == localFirst.key}
            let universalSecondIndex = universalObjects.index() {$0.key == localSecond.key}
            return universalFirstIndex! < universalSecondIndex!
        }
        
        return sortedFetchedLocals
    }
}

class LocalToUniversalConversion<L: HasUniversalEquivalent, U:HasLocalEquivalent> where U:NSManagedObject, U.SelfObject == U {
    private let localObjects: [L]
    
    init(localObjects: [L]) {
        self.localObjects = localObjects
    }
    
    func convertToUniversal() -> [U]? {
        let fetchRequest: NSFetchRequest<U> = U.specificFR()
        
        //Create the array of predicates to compare local key values with universal key values
        var predicates: [NSPredicate] = []
        for object in localObjects {
            predicates.append(NSPredicate(format: "key like %@", argumentArray: [object.key!]))
        }
        //Add them all to the compound predicate
        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        
        fetchRequest.predicate = compoundPredicate
        
        let fetchedUniversals: [U]
        do {
            fetchedUniversals = try DataManager.managedContext.fetch(fetchRequest)
        } catch {
            NSLog("Unable to fetch local objects for multiple universal objects")
            return []
        }
        
        if fetchedUniversals.count != localObjects.count {
            NSLog("Amount of Fetched Universals not equal to the given objects")
            return nil
        }
        
        //Sort the fetched locals to be in the same order as their universal counterparts
        let sortedFetchedUniversals = fetchedUniversals.sorted() {localFirst, localSecond in
            let universalFirstIndex = localObjects.index() {$0.key == localFirst.key}
            let universalSecondIndex = localObjects.index() {$0.key == localSecond.key}
            return universalFirstIndex! < universalSecondIndex!
        }
        
        return sortedFetchedUniversals
    }
}
