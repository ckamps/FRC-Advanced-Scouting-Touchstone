//
//  DataSyncer.swift
//  FRC Advanced Scouting Telemetrics
//
//  Created by Aaron Kampmeier on 4/2/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import Ensembles
import Crashlytics

let CDEMultipeerCloudFileSystemDidImportFilesNotification = "CDEMultipeerCloudFileSystemDidImportFilesNotification"
let DSTransferNumberChanged = "DSTransferNumberChanged"

class DataSyncer: NSObject, CDEPersistentStoreEnsembleDelegate {
	private static var sharedInstance: DataSyncer = DataSyncer()
	
	let fileSystem: CDECloudFileSystem
	let ensemble: CDEPersistentStoreEnsemble
	let multipeerConnection: MultipeerConnection
	
	override init() {
		let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
		
		let syncSecret: String
		if let stringValue = NSUserDefaults.standardUserDefaults().stringForKey("SharedSyncSecret") {
			syncSecret = stringValue
		} else {
			NSLog("No sync secret exists, using default.")
			syncSecret = "FRC-4256-FAST-EnsembleSync"
		}
		
		multipeerConnection = MultipeerConnection(syncSecret: syncSecret)
		let rootDir = appDelegate.applicationDocumentsDirectory.URLByAppendingPathComponent("EnsembleMultipeerSync", isDirectory: true).path
		
		fileSystem = CDEMultipeerCloudFileSystem(rootDirectory: rootDir, multipeerConnection: multipeerConnection)
		multipeerConnection.fileSystem = (fileSystem as! CDEMultipeerCloudFileSystem)
		ensemble = CDEPersistentStoreEnsemble(ensembleIdentifier: "FASTStore", persistentStoreURL: appDelegate.coreDataURL, managedObjectModelURL: appDelegate.managedObjectModelURL, cloudFileSystem: fileSystem)
		
		super.init()
		
		ensemble.delegate = self
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(DataSyncer.didImportFiles), name: CDEMultipeerCloudFileSystemDidImportFilesNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserverForName(CDEMonitoredManagedObjectContextDidSaveNotification, object: nil, queue: nil) {notification in
			self.syncWithCompletion() {error in
				if let error = error {NSLog("Commit-Sync failed with error: \(error)")} else {NSLog("Commit-Sync completed")}
			}
		}
		NSTimer.scheduledTimerWithTimeInterval(5 * 60, target: self, selector: #selector(DataSyncer.autoSync(_:)), userInfo: nil, repeats: true)
	}
	
	static func sharedDataSyncer() -> DataSyncer {
		return sharedInstance
	}
	
	///Attaches local ensemble object to the cloud (shared data store).
	static func begin() {
		NSLog("Starting Data Syncer")
		//Leech the ensemble if it hasn't already been done
		if !sharedDataSyncer().ensemble.leeched {
			NSLog("Leeching ensemble")
			sharedDataSyncer().ensemble.leechPersistentStoreWithCompletion() {error in
				if let error = error {
					NSLog("Unable to leech the persistent store. Error: \(error)")
				} else {
					NSLog("Leech successful")
				}
			}
		} else {
			NSLog("Already leeched")
		}
	}
	
	func disconnectFromCloud() {
		NSLog("Disconnecting")
		ensemble.deleechPersistentStoreWithCompletion() {error in
			if let error = error {NSLog("Deleech failed with error: \(error)")} else {NSLog("Deleech Successful")}
		}
	}
	
	@objc private func didImportFiles() {
		//syncWithCompletion(nil)
		NSLog("Did import files")
		multipeerConnection.syncFilesWithAllPeers()
	}
	
	@objc private func autoSync(timer: NSTimer) {
		if !connectedPeers().isEmpty {
			syncWithCompletion() {error in
				if let error = error {NSLog("Auto-Sync failed with error: \(error)")} else {NSLog("Auto-Sync completed")}
			}
		}
	}
	
	///Begins an Ensemble merge. Retrieves files from the other devices and merges them with this one.
	func syncWithCompletion(completion: CDECompletionBlock?) {
		NSLog("Syncing Files")
		self.multipeerConnection.syncFilesWithAllPeers()
		
		//Wait one second before syncing to allow for remote files to download
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
			NSLog("Merging")
			self.ensemble.mergeWithCompletion() {error in
				if let error = error {NSLog("Error merging: \(error)")} else {NSLog("Merging completed")}
				completion?(error)
			}
		}
	}
	
	func connectedPeers() -> [MCPeerID] {
		return multipeerConnection.session.connectedPeers
	}
	
	func attemptToFixDeelechError() {
		DataSyncer.begin()
	}
	
	//MARK: Ensemble Delegate
	func persistentStoreEnsembleWillImportStore(ensemble: CDEPersistentStoreEnsemble!) {
		NSLog("Ensemble will import store")
	}
	
	func persistentStoreEnsembleDidImportStore(ensemble: CDEPersistentStoreEnsemble!) {
		NSLog("Ensemble did import store")
	}
	
	func persistentStoreEnsemble(ensemble: CDEPersistentStoreEnsemble!, shouldSaveMergedChangesInManagedObjectContext savingContext: NSManagedObjectContext!, reparationManagedObjectContext reparationContext: NSManagedObjectContext!) -> Bool {
		NSLog("Ensemble should save merged changes")
		return true
	}
	
	func persistentStoreEnsemble(ensemble: CDEPersistentStoreEnsemble!, didFailToSaveMergedChangesInManagedObjectContext savingContext: NSManagedObjectContext!, error: NSError!, reparationManagedObjectContext reparationContext: NSManagedObjectContext!) -> Bool {
		CLSNSLogv("Ensemble did fail to save merged changes. Error: \(error)", getVaList([]))
		let alert = UIAlertController(title: "Save Failed", message: "The save and sync failed. Ask your admin for help with this issue. Attempting to fix...", preferredStyle: .Alert)
		alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
		(UIApplication.sharedApplication().delegate as! AppDelegate).presentViewControllerOnTop(alert, animated: true)
		
//		savingContext.performBlockAndWait() {
//			for object in savingContext.updatedObjects {
//				switch object {
//				case is Match:
//					var defenses = object.valueForKey("redDefenses")
//					do {
//						try object.validateValue(&defenses, forKey: "redDefenses")
//					} catch {
//						reparationContext.performBlockAndWait() {
//							reparationContext.objectWithID(object.objectID).setValue(nil, forKey: "redDefenses")
//						}
//					}
//				default:
//					break
//				}
//			}
//		}
		
		Crashlytics.sharedInstance().recordError(error)
		return true
	}
	
	func persistentStoreEnsemble(ensemble: CDEPersistentStoreEnsemble!, didSaveMergeChangesWithNotification notification: NSNotification!) {
		NSLog("Ensemble did save merged changes")
		
		//Merge the changes into the main managed object context
		TeamDataManager.managedContext.performBlock() {
			TeamDataManager.managedContext.mergeChangesFromContextDidSaveNotification(notification)
			NSLog("Did merge changes into main context")
			NSNotificationCenter.defaultCenter().postNotificationName("DataSyncer:NewChangesMerged", object: self)
		}
	}
	
	func persistentStoreEnsemble(ensemble: CDEPersistentStoreEnsemble!, didDeleechWithError error: NSError!) {
		let alert = UIAlertController(title: "Sync Error: Deleech", message: "There was an internal data integrity error which forced your app to disconnect from the shared cloud of data. Ask your admin for help with fixing this.", preferredStyle: .Alert)
		alert.addAction(UIAlertAction(title: "Attempt to Fix", style: .Default, handler: {_ in self.attemptToFixDeelechError()}))
		alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
		(UIApplication.sharedApplication().delegate as! AppDelegate).presentViewControllerOnTop(alert, animated: true)
		
		CLSNSLogv("Did deleech with error: \(error)", getVaList([]))
		Crashlytics.sharedInstance().recordError(error)
	}
	
	func persistentStoreEnsemble(ensemble: CDEPersistentStoreEnsemble!, globalIdentifiersForManagedObjects objects: [AnyObject]!) -> [AnyObject]! {
		NSLog("Setting global identifiers")
		var globalIdentifiers = [AnyObject]()
		for object in objects {
			switch object {
			case is DraftBoard:
				globalIdentifiers.append("DraftBoard" as NSString)
				NSLog("Global identifier is DraftBoard")
			case is Team:
				globalIdentifiers.append("Team:\(object.valueForKey("teamNumber")!)")
			case is Regional:
				globalIdentifiers.append("Regional:\(object.valueForKey("regionalNumber")!)")
			case is TeamRegionalPerformance:
				globalIdentifiers.append("RegionalPerformance:\(object.valueForKey("team")!.valueForKey("teamNumber")!):\(object.valueForKey("regional")!.valueForKey("regionalNumber")!)")
			case is Match:
				globalIdentifiers.append("Match:\(object.valueForKey("regional")!.valueForKey("regionalNumber")!):\(object.valueForKey("matchNumber")!)")
			case is TeamMatchPerformance:
				globalIdentifiers.append("MatchPerformance:\(object.valueForKey("regionalPerformance")!.valueForKey("team")!.valueForKey("teamNumber")!):\(object.valueForKey("regionalPerformance")!.valueForKey("regional")!.valueForKey("regionalNumber")!):\(object.valueForKey("match")!.valueForKey("matchNumber")!)")
			case is AutonomousCycle:
				globalIdentifiers.append("\(NSUUID().UUIDString)")
			case is Shot:
				//Use a unique identifier for the shots because two inserted seperately will never be logically equivalent
				globalIdentifiers.append("\(NSUUID().UUIDString)")
			case is DefenseCrossTime:
				globalIdentifiers.append("\(NSUUID().UUIDString)")
			case is TimeMarker:
				globalIdentifiers.append("\(NSUUID().UUIDString)")
			default:
				globalIdentifiers.append(NSNull())
			}
		}
		return globalIdentifiers
	}
}

///For other files to access MCPeerIDs without importing MultipeerConnectivity
typealias FASTPeer = MCPeerID

class MultipeerConnection: NSObject, CDEMultipeerConnection {
	let serviceType = "frc-4256-fast"
	let mySyncSecret: String
	
	private let myPeerID = MCPeerID(displayName: UIDevice.currentDevice().name)
	
	private let serviceAdvertiser: MCNearbyServiceAdvertiser
	private let serviceBrowser: MCNearbyServiceBrowser
	
	let session: MCSession
	
	var currentFileTransfers = [String:(NSProgress, FASTPeer)]() {
		didSet {
			let oldKeys = Set(oldValue.keys)
			let newKeys = Set(currentFileTransfers.keys)
			let updatedKeys = oldKeys.exclusiveOr(newKeys)
			NSNotificationCenter.defaultCenter().postNotificationName(DSTransferNumberChanged, object: self, userInfo: ["UpdatedKeys":Array(updatedKeys)])
		}
	}
	
	weak var fileSystem: CDEMultipeerCloudFileSystem?
	
	init(syncSecret: String) {
		mySyncSecret = syncSecret
		serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["syncSecret":mySyncSecret], serviceType: serviceType)
		serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
		session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .None)
		
		super.init()
		
		serviceAdvertiser.delegate = self
		serviceAdvertiser.startAdvertisingPeer()
		
		serviceBrowser.delegate = self
		serviceBrowser.startBrowsingForPeers()
		
		session.delegate = self
	}
	
	deinit {
		session.disconnect()
		
		serviceAdvertiser.stopAdvertisingPeer()
		serviceBrowser.stopBrowsingForPeers()
	}
	
	func returnServiceBrowser() -> MCNearbyServiceBrowser {
		return serviceBrowser
	}
	
	func returnServiceAdvertiser() -> MCNearbyServiceAdvertiser {
		return serviceAdvertiser
	}
	
	func sendData(data: NSData!, toPeerWithID peerID: protocol<NSCoding, NSCopying, NSObjectProtocol>!) -> Bool {
		let peer = peerID as! MCPeerID
		do {
			try session.sendData(data, toPeers: [peer], withMode: .Reliable)
			return true
		} catch {
			return false
		}
	}
	
	func sendAndDiscardFileAtURL(url: NSURL!, toPeerWithID peerID: protocol<NSCoding, NSCopying, NSObjectProtocol>!) -> Bool {
		NSLog("Sending file")
		let peer = peerID as! MCPeerID
		let progress = session.sendResourceAtURL(url, withName: url.lastPathComponent!, toPeer: peer) {sendError in
			if let error = sendError {
				NSLog("Unable to send file. Error: \(error)")
			}
			
			do {
				try NSFileManager.defaultManager().removeItemAtURL(url)
			} catch {
				NSLog("Unable to delete tmp file. Error: \(error)")
			}
		}
		
		return progress != nil
	}
	
	func syncFilesWithAllPeers() {
		if session.connectedPeers.count > 0 {
			fileSystem?.retrieveFilesFromPeersWithIDs(session.connectedPeers)
		}
	}
}

//MARK: Advertiser Delegate
/** Advertiser Delegate */
extension MultipeerConnection: MCNearbyServiceAdvertiserDelegate {
	func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
		NSLog("Did not start advertising peer: \(error)")
	}
	
	func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: (Bool, MCSession) -> Void) {
		NSLog("Did receive invitation from peer: \(peerID); \(peerID.displayName)")
		dispatch_async(dispatch_get_main_queue()) {
			NSNotificationCenter.defaultCenter().postNotificationName("DataSyncing:ReceivedInvitation", object: self, userInfo: ["peer":peerID.displayName, "context":context ?? "none"])
		}
		
		if let context = context {
			let otherPeerSecret = String(NSString(data: context, encoding: NSUTF8StringEncoding) ?? "")
			if otherPeerSecret == mySyncSecret {
				NSLog("Accepting invite from \(peerID.displayName).")
				invitationHandler(true, session)
			} else {
				NSLog("Rejecting invite from \(peerID.displayName), because it has a different sync secret.")
				invitationHandler(false, session)
			}
		} else {
			invitationHandler(false, session)
		}
	}
}

//MARK: Browser Delegate
/** Browser Delegate */
extension MultipeerConnection: MCNearbyServiceBrowserDelegate {
	func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
		NSLog("Didn't start browsing: \(error)")
	}
	
	func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
		NSLog("Found peer: \(peerID.displayName)")
		dispatch_async(dispatch_get_main_queue()) {
			NSNotificationCenter.defaultCenter().postNotificationName("DataSyncing:FoundPeer", object: self, userInfo: ["peer":peerID.displayName, "info":info ?? [:]])
		}
		
		if !peerID.isEqual(myPeerID) && !session.connectedPeers.contains(peerID) {
			//The peer is not me and is not yet connected, check if it has the same sync secret as me
			if info?["syncSecret"] == mySyncSecret {
				//Invite them
				let context = mySyncSecret.dataUsingEncoding(NSUTF8StringEncoding)
				browser.invitePeer(peerID, toSession: session, withContext: context, timeout: 30)
			}
		}
	}
	
	func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
		NSLog("Lost Peer: \(peerID.displayName)")
	}
}

//MARK: Session Delegate
/** Session Delegate */
extension MultipeerConnection: MCSessionDelegate {
	func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
		CLSNSLogv("Received Data", getVaList([]))
		fileSystem?.receiveData(data, fromPeerWithID: peerID)
	}
	
	func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
		CLSNSLogv("Peer: \(peerID.displayName), Did change state: \(state)", getVaList([]))
		
		dispatch_async(dispatch_get_main_queue()) {
			NSNotificationCenter.defaultCenter().postNotificationName("DataSyncing:DidChangeState", object: self, userInfo: ["peer":peerID as FASTPeer, "state":state.rawValue])
		}
		
		if state == .Connected {
			dispatch_async(dispatch_get_main_queue()) {
				DataSyncer.sharedDataSyncer().syncWithCompletion(nil)
			}
		}
	}
	
	func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		NSLog("Received Stream")
	}
	
	func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
		CLSNSLogv("Did finish receiving resource: \(resourceName)", getVaList([]))
		currentFileTransfers.removeValueForKey(resourceName)
		dispatch_async(dispatch_get_main_queue()) {
			NSNotificationCenter.defaultCenter().postNotificationName("DataSyncing:DidFinishReceiving", object: self, userInfo: ["peer": peerID.displayName, "url":localURL, "name":resourceName])
		}
		
		if error != nil {
			CLSNSLogv("Error receiving file: \(error)", getVaList([]))
			return
		} else {
			fileSystem?.receiveResourceAtURL(localURL, fromPeerWithID: peerID)
		}
	}
	
	func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
		CLSNSLogv("Did start receiving resource: \(resourceName)", getVaList([]))
		currentFileTransfers[resourceName] = (progress, peerID)
	}
}

extension MCSessionState: CustomStringConvertible {
	func stringValue() -> String {
		switch self {
		case .NotConnected:
			return "Not Connected"
		case .Connecting:
			return "Connecting"
		case .Connected:
			return "Connected"
		}
	}
	
	public var description: String {
		return self.stringValue()
	}
}

///For other classes to use instead of importing MultipeerConnectivity and using MCSessionState
typealias SessionState = MCSessionState