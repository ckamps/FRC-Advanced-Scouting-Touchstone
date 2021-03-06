//
//  AdminConsoleController.swift
//  FRC Advanced Scouting Telemetrics
//
//  Created by Aaron Kampmeier on 1/17/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import UIKit
import RealmSwift
import Crashlytics
import VTAcknowledgementsViewController

class AdminConsoleController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    var events: Results<Event>!
    
    var notificationToken: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        events = RealmController.realmController.generalRealm.objects(Event.self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
        
        //Reload the table view
        tableView.reloadData()
        
        //Set the observer
        notificationToken = events.observe {[weak self] collectionChange in
            switch collectionChange {
            case .update(_, deletions: let deletions, insertions: let insertions, _):
                if deletions.count > 0 || insertions.count > 0 {
                    self?.tableView.beginUpdates()
                    self?.tableView.deleteRows(at: deletions.map {IndexPath(row: $0, section: 0)}, with: .automatic)
                    self?.tableView.insertRows(at: insertions.map {IndexPath(row: $0, section: 0)}, with: .automatic)
                    self?.tableView.endUpdates()
                }
            default:
                break
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        notificationToken?.invalidate()
        self.notificationToken = nil
    }
    
    enum adminConsoleSections: Int {
        case events
        case about
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            //Events
            return events.count + 1
        case tableView.numberOfSections - 1:
            //About Section
            return 4
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            //Events
            if indexPath.row == tableView.numberOfRows(inSection: 0) - 1 {
                //Return the add event cell
                return tableView.dequeueReusableCell(withIdentifier: "addEvent")!
            } else {
                //Return the event cell with event name and type
                let cell = tableView.dequeueReusableCell(withIdentifier: "event")!
                cell.textLabel?.text = "\(events[indexPath.row].name) (\(events[indexPath.row].year))"
                cell.detailTextLabel?.text = events[indexPath.row].location
                return cell
            }
        case tableView.numberOfSections - 1:
            //About Section
            switch indexPath.row {
            case 0:
                return tableView.dequeueReusableCell(withIdentifier: "about")!
            case 1:
                return tableView.dequeueReusableCell(withIdentifier: "acknowledgments")!
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "syncStatus")!
                
                if RealmController.isInSpectatorMode {
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.isEnabled = false
                } else {
                    cell.isUserInteractionEnabled = true
                    cell.textLabel?.isEnabled = true
                }
                
                return cell
            case 3:
                let cell = tableView.dequeueReusableCell(withIdentifier: "logout")!
                
                if RealmController.isInSpectatorMode {
                    (cell.viewWithTag(1) as! UILabel).text = "Exit Spectator Mode"
                } else {
                    let teamNumber: String = UserDefaults.standard.value(forKey: "LoggedInTeam") as? String ?? "?"
                    (cell.viewWithTag(1) as! UILabel).text = "Log Out of Team \(teamNumber)"
                }
                
                return cell
            default:
                return tableView.dequeueReusableCell(withIdentifier: "about")!
            }
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Events (swipe left to reload/export/remove)"
        default:
            return ""
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            //Events
            if indexPath.row == tableView.numberOfRows(inSection: 0) - 1 {
                //Did select add event
                if RealmController.isInSpectatorMode {
                    self.performSegue(withIdentifier: "addEvent", sender: tableView)
                } else {
                    //First present warning
                    let warning = UIAlertController(title: "Do Not Repeat", message: "Events need only be added to a team's FAST account once. This should be done by your scouting lead. Please make sure someone else has not already added the same event as this may cause data inconsistencies in rare cases.", preferredStyle: .alert)
                    warning.addAction(UIAlertAction(title: "I Understand", style: .default, handler: {_ in self.performSegue(withIdentifier: "addEvent", sender: tableView); Answers.logCustomEvent(withName: "Add Event Pressed", customAttributes: ["Route":"I Understand"])}))
                    warning.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {_ in self.viewWillAppear(false) /*This is just to clear the table view selection*/ ; Answers.logCustomEvent(withName: "Add Event Pressed", customAttributes: ["Route":"Cancel"])}))
                    self.present(warning, animated: true, completion: nil)
                }
            } else {
                //Did select event info
                // TODO: Display event info
            }
        case tableView.numberOfSections - 1:
            if indexPath.row == 0 {
                performSegue(withIdentifier: "about", sender: self)
            } else if indexPath.row == 1 {
                if let path = Bundle.main.path(forResource: "Pods-acknowledgments", ofType: "plist") {
                    
                    let ackVC = VTAcknowledgementsViewController(path: path)!
                    ackVC.headerText = "Portions of this app run on the following libraries"
                    
                    if let path = Bundle.main.path(forResource: "Additional Licenses", ofType: "plist") {
                        let additionalLicensesDict = NSDictionary(contentsOfFile: path)! as! Dictionary<String, Dictionary<String, String>>
                        
                        let keys = additionalLicensesDict.keys
                        for key in keys {
                            let ack = VTAcknowledgement(title: additionalLicensesDict[key]!["Title"]!, text: additionalLicensesDict[key]!["Text"]!, license: additionalLicensesDict[key]?["License"])
                            
                            ackVC.acknowledgements?.append(ack)
                        }
                    }
                    
                    self.navigationController?.pushViewController(ackVC, animated: true)
                    Answers.logContentView(withName: "Acknowledgements", contentType: "App Informational", contentId: nil, customAttributes: nil)
                } else {
                    assertionFailure()
                }
            } else if indexPath.row == 2 {
                performSegue(withIdentifier: "syncStatus", sender: self)
            } else if indexPath.row == 3 {
                //Logout
                if RealmController.isInSpectatorMode {
                    Answers.logCustomEvent(withName: "Exit Spectator Mode", customAttributes: nil)
                } else {
                    let loggedInTeam: String = UserDefaults.standard.value(forKey: "LoggedInTeam") as? String ?? "Unknown"
                    Answers.logCustomEvent(withName: "Sign Out", customAttributes: ["Team":loggedInTeam])
                }
                RealmController.realmController.closeRealms()
                UserDefaults.standard.setValue(false, forKey: RealmController.isSpectatorModeKey)
            }
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 0:
            //Events
            if indexPath.row == tableView.numberOfRows(inSection: 0) - 1 {
                return false
            } else {
                return true
            }
        default:
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        switch indexPath.section {
        case 0:
            if indexPath.row == tableView.numberOfRows(inSection: 0) - 1 {
                return nil
            } else {
                let reloadAction = UITableViewRowAction.init(style: .normal, title: "Reload") {(rowAction, indexPath) in
                    self.reloadAt(indexPath: indexPath, inTableView: tableView)
                }
                reloadAction.backgroundColor = UIColor.blue
                
                let delete = UITableViewRowAction.init(style: .destructive, title: "Delete") {(rowAction, indexPath) in
                    self.deleteAt(indexPath: indexPath, inTableView: tableView)
                }
                
                let exportToCSV = UITableViewRowAction(style: .default, title: "CSV Export") {(rowAction, indexPath) in
                    self.exportToCSV(event: self.events[indexPath.row], withSourceView: nil) {_ in
                    }
                }
                exportToCSV.backgroundColor = .purple
                
                return [reloadAction, exportToCSV, delete]
            }
        default:
            return nil
        }
    }
    
    func reloadAt(indexPath: IndexPath, inTableView tableView: UITableView, withCompletionHandler onCompletion: (() -> Void)? = nil) {
        let event = self.events[indexPath.row]
        if RealmController.realmController.sanityCheckStructure(ofEvent: event) {
            showLoadingIndicator()
            
            CloudReloadingManager(eventToReload: event) {successful in
                self.removeLoadingIndicator()
                
                onCompletion?()
                }
                .reload()
        } else {
            //The event is not fully loaded from cloud
            let alert = UIAlertController(title: "Unable to Reload", message: "This event cannot be reloaded becuase it contains an incomplete object structure. Before reloading make sure to be fully in sync with the rest of your team by checking the \"Sync Status\" page. To force a reload, delete this event and then re-add it.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    var grayView: UIView?
    func showLoadingIndicator() {
        //Create a loading view
        let spinnerView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
        grayView = UIView(frame: CGRect(x: self.tableView.frame.width / 2 - 50, y: self.tableView.frame.height / 2 - 50, width: 120, height: 120))
        grayView?.backgroundColor = UIColor.lightGray
        grayView?.backgroundColor?.withAlphaComponent(0.7)
        grayView?.layer.cornerRadius = 10
        spinnerView.frame = CGRect(x: grayView!.frame.width / 2 - 25, y: grayView!.frame.height / 2 - 25, width: 50, height: 50)
        grayView?.addSubview(spinnerView)
        spinnerView.startAnimating()
        self.tableView.addSubview(grayView!)
        
        //Prevent user interaction
        self.view.isUserInteractionEnabled = false
        self.navigationController?.navigationBar.isUserInteractionEnabled = false
    }
    
    func removeLoadingIndicator() {
        //Return user interaction
        self.view.isUserInteractionEnabled = true
        self.navigationController?.navigationBar.isUserInteractionEnabled = true
        
        grayView?.removeFromSuperview()
        
        grayView = nil
    }
    
    func deleteAt(indexPath: IndexPath, inTableView tableView: UITableView) {
        //Remove the event
        let removalManager = CloudEventRemovalManager(eventToRemove: self.events[indexPath.row]) {finished in
            if !finished {
                let alert = UIAlertController(title: "Problem Removing Event", message: "An error occured when removing the event.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            } else {
                tableView.beginUpdates()
                tableView.deleteRows(at: [indexPath], with: .left)
                tableView.endUpdates()
            }
            
            tableView.reloadData()
        }
        removalManager.remove(withoutNotifying: notificationToken ?? NotificationToken())
    }
    
    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch indexPath.section {
        case 0:
            if indexPath.row == tableView.numberOfRows(inSection: 0) - 1 {
                return nil
            } else {
                let deleteAction = UIContextualAction(style: .destructive, title: "Delete") {action, view, completionHandler in
                    self.deleteAt(indexPath: indexPath, inTableView: tableView)
                    completionHandler(true)
                }
                
                let reloadAction = UIContextualAction(style: .normal, title: "Reload") {action, view, completionHandler in
                    self.reloadAt(indexPath: indexPath, inTableView: tableView)
                    completionHandler(true)
                }
                reloadAction.backgroundColor = .blue
                
                let exportToCSVAction = UIContextualAction(style: .normal, title: "CSV Export") {action, view, completionHandler in
                    self.exportToCSV(event: self.events[indexPath.row], withSourceView: view) {successful in
                        completionHandler(true)
                    }
                }
                exportToCSVAction.backgroundColor = .purple
                
                return UISwipeActionsConfiguration(actions: [reloadAction, exportToCSVAction, deleteAction])
            }
        default:
            return nil
        }
    }
    
    func exportToCSV(event: Event, withSourceView view: UIView?, onCompletion: @escaping (Bool) -> Void) {
        showLoadingIndicator()
        
        let finishingActions: (URL?, Error?) -> Void = {path, error in
            self.removeLoadingIndicator()
            DispatchQueue.main.async {
                if let error = error {
                    let alert = UIAlertController(title: "Export Failed", message: "There was an error exporting to CSV: \(error)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    
                    onCompletion(false)
                    
                    CLSNSLogv("Failed to write csv text to file: \(error)", getVaList([]))
                    Crashlytics.sharedInstance().recordError(error)
                    
                    Answers.logCustomEvent(withName: "Export Event to CSV", customAttributes: ["Event":event.key, "Successful":false])
                } else if let path = path {
                    let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: [])
                    
                    activityVC.excludedActivityTypes = [UIActivityType.addToReadingList, UIActivityType.assignToContact, UIActivityType.openInIBooks, UIActivityType.postToFacebook, UIActivityType.postToVimeo, UIActivityType.postToWeibo, UIActivityType.postToFlickr, UIActivityType.postToTwitter, UIActivityType.postToTencentWeibo, UIActivityType.saveToCameraRoll]
                    
                    activityVC.popoverPresentationController?.sourceView = self.tableView
                    if let index = self.events.index(of: event) {
                        if let tableViewCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) {
                            activityVC.popoverPresentationController?.sourceView = tableViewCell
                        }
                    }
                    
                    activityVC.completionWithItemsHandler = {(activityType: UIActivityType?, completed: Bool, returnedItems: [Any]?, error: Error?) in
                        if let activityType = activityType {
                            Answers.logShare(withMethod: activityType.rawValue, contentName: path.lastPathComponent, contentType: "CSV Event Export", contentId: "csv_\(event.key)", customAttributes: nil)
                        }
                        
                        if let error = error {
                            CLSNSLogv("Activity share of csv export failed with error: \(error)", getVaList([]))
                            Crashlytics.sharedInstance().recordError(error)
                        }
                    }
                    
                    onCompletion(true)
                    self.present(activityVC, animated: true, completion: nil)
                    
                    Answers.logCustomEvent(withName: "Export Event to CSV", customAttributes: ["Event":event.key, "Successful":true])
                }
            }
        }
        
        DispatchQueue.main.async {
            let filename = "\(event.key).csv"
            let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
            
            let teamStats = Team.StatName.allValues
            let teamEventStats = TeamEventPerformance.StatName.allValues
            
            var csvText = ""
            //First add in the header row of all stat names
            //        csvText += "Team Number,"
            for statName in teamStats {
                csvText += statName.description
                csvText += ","
            }
            for (index, statName) in teamEventStats.enumerated() {
                csvText += statName.description
                
                if index == teamEventStats.count - 1 {
                    //End index
                    csvText += "\n"
                } else {
                    csvText += ","
                }
            }
            
            //Now for all the stat values
            for teamEventPerformance in event.teamEventPerformances {
                let team = teamEventPerformance.team!
                //Start with the team number in column 1
                //            csvText += "\(teamEventPerformance.team!.teamNumber),"
                
                //Next the team stats
                for statName in teamStats {
                    let value = team.statValue(forStat: statName)
                    csvText += "\(value)"
                    csvText += ","
                }
                
                //Next all the performance stat values seperated by commas
                for (index, statName) in teamEventStats.enumerated() {
                    let value = teamEventPerformance.statValue(forStat: statName)
                    csvText += "\(value)"
                    
                    if index == teamEventStats.count - 1 {
                        //End index
                        csvText += "\n"
                    } else {
                        csvText += ","
                    }
                }
            }
            
            do {
                try csvText.write(to: path, atomically: true, encoding: String.Encoding.utf8)
                
                finishingActions(path, nil)
            } catch {
                finishingActions(nil, error)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath.section {
        case 0:
            //Matches
            if indexPath.row == tableView.numberOfRows(inSection: 0) - 1 {
                return indexPath
            } else {
                return nil
            }
        default:
            return indexPath
        }
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
    }
    
    @IBAction func advancedPressed(_ sender: UIBarButtonItem) {
        
//        let advancedController = storyboard?.instantiateViewController(withIdentifier: "advancedControl") as! HiddenDebugViewController
//        present(advancedController, animated: true, completion: nil)
    }
}
