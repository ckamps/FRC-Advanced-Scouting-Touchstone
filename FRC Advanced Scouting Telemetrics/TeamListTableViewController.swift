//
//  TeamListTableViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 5/1/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import UIKit
import Crashlytics
import AWSAuthUI
import RealmSwift

class EventSelectionTitleButton: UIButton {
    override var intrinsicContentSize: CGSize {
        return UILayoutFittingExpandedSize
    }
}

class TeamListTableViewController: UITableViewController, TeamListDetailDataSource {
    @IBOutlet weak var incompleteEventView: UIView!
    @IBOutlet weak var graphButton: UIBarButtonItem!
    @IBOutlet weak var eventSelectionButton: EventSelectionTitleButton!
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var matchesButton: UIBarButtonItem!
    
    var searchController: UISearchController!
    let realmController = RealmController.realmController
    var teamImages = [String:UIImage]()
    var teamListSplitVC: TeamListSplitViewController {
        get {
            return splitViewController as! TeamListSplitViewController
        }
    }
    
    var statToSortBy: String?
    //Should move functionality in here to a setSortingState func
//    var isSorted = false
    var isSortingAscending: Bool = false
    
    var isSearching = false
    
    //Is a hierarchy
    var currentEventTeams: [Team] = [Team]() {
        didSet {
            sortList(withStat: statToSortBy, isAscending: isSortingAscending)
        }
    }
    var currentSortedTeams: [Team] = [] {
        didSet {
            self.updateSearchResults(for: searchController)
        }
    }
    //Searching would happen right in between here
    var currentTeamsToDisplay = [Team]() { //This is always eaxaclty the end what the table view will display
        didSet {
            tableView.reloadData()
        }
    }
    
    var selectedTeam: Team? {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "Different Team Selected"), object: self)
            if let sTeam = selectedTeam {
                //Select row in table view
                if let index = currentTeamsToDisplay.index(where: {team in
                    return team == sTeam
                }) {
                    tableView.selectRow(at: IndexPath.init(row: index, section: 0), animated: false, scrollPosition: .none)
                }
            } else {
                tableView.deselectRow(at: tableView.indexPathForSelectedRow ?? IndexPath(), animated: false)
            }
            
            teamListSplitVC.teamListDetailVC.reloadData()
        }
    }
    let lastSelectedEventStorageKey = "Last-Selected-Event"
    var selectedEventRanker: EventRanker?
    var selectedEvent: Event? {
        didSet {
            //Set to nil, because the selected team might not be in the new event
            selectedTeam = nil
            
            statToSortBy = nil
            
            if let event = selectedEvent {
                
                if !realmController.sanityCheckStructure(ofEvent: event) {
                    //The event's structure is not there, wait for it to download
                    
                    let alert = UIAlertController(title: "Wait for Downloads to Finish", message: "This event is not fully loaded from the cloud and is unusable until it is. Wait for this event to finish downloading by checking status in the \"Sync Status\" page and making sure you have a steady internet connection. If the issue persits, try logging out and back in again. If you believe this was in error, please contact us.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {_ in self.selectedEvent = nil}))
                    self.present(alert, animated: true, completion: nil)
                    
                    Answers.logCustomEvent(withName: "Event selected before fully loaded", customAttributes: ["Event":event.key])
                } else {
                    UserDefaults.standard.set(event.key, forKey: lastSelectedEventStorageKey)
                    selectedEventRanker = realmController.getTeamRanker(forEvent: event)
                    currentEventTeams = realmController.teamRanking(forEvent: event)
                    
                    eventSelectionButton.setTitle(event.name, for: UIControlState())
                    
                    matchesButton.isEnabled = true
                    graphButton.isEnabled = true
                    
                }
            } else {
                currentEventTeams = []
                selectedEventRanker = nil
                
                eventSelectionButton.setTitle("Select Event", for: UIControlState())
                
                matchesButton.isEnabled = false
                graphButton.isEnabled = false
            }
            
            reloadEventRankerObserver()
            
            teamListSplitVC.teamListDetailVC.reloadData()
        }
    }
    var teamEventPerformance: TeamEventPerformance? {
        get {
            if let team = selectedTeam {
                if let event = selectedEvent {
                    return realmController.eventPerformance(forTeam: team, atEvent: event)
                }
            }
            return nil
        }
    }
    
    var eventsObserverToken: NotificationToken?
    var eventRankerObserverToken: NotificationToken? {
        didSet {
            oldValue?.invalidate()
        }
    }
    var eventPickedTeamsObserverToken: NotificationToken? {
        didSet {
            oldValue?.invalidate()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.clearsSelectionOnViewWillAppear = false
        
        teamListSplitVC.teamListTableVC = self
        
        eventSelectionButton.widthAnchor.constraint(equalToConstant: CGFloat.greatestFiniteMagnitude - (navigationItem.leftBarButtonItem?.width)! - (navigationItem.rightBarButtonItem?.width)!)
        
        //Set up the searching capabilities and the search bar. At the time of coding, Storyboards do not support the new UISearchController, so this is done programatically.
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.obscuresBackgroundDuringPresentation = false
        self.definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
        
        tableView.allowsSelectionDuringEditing = true
        
        //Set background view of table view
        let noEventView = NoEventSelectedView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: tableView.frame.height))
        tableView.backgroundView = noEventView
        
        //Set last selected event
        if let lastSelectedEventKey = UserDefaults.standard.value(forKey: lastSelectedEventStorageKey) as? String {
            //Get event
            if let event = realmController.generalRealm.object(ofType: Event.self, forPrimaryKey: lastSelectedEventKey) {
                if RealmController.realmController.sanityCheckStructure(ofEvent: event) {
                    selectedEvent = event
                }
            }
        }
    }
    
    //For some reason this is called when moving the app to the background during stands scouting, not sure if this a beta issue or what but it does cause crash
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if selectedEvent?.isInvalidated ?? false {
            if let eventKey = UserDefaults.standard.value(forKey: lastSelectedEventStorageKey) as? String {
                selectedEvent = realmController.generalRealm.object(ofType: Event.self, forPrimaryKey: eventKey)
            } else {
                selectedEvent = nil
            }
        }
        
        if selectedEvent == nil {
            let events = RealmController.realmController.generalRealm.objects(Event.self)
            if events.count > 0 {
                //There is no selected event, but there are events to choose from, let's just pick a random one
                selectedEvent = events.first
            }
        }
        
        if let event = selectedEvent {
            if realmController.sanityCheckStructure(ofEvent: event) {
                currentEventTeams = realmController.teamRanking(forEvent: event)
            } else {
                currentEventTeams = []
            }
        } else {
            currentEventTeams = []
        }
        
        if isSearching {
            self.navigationController?.setToolbarHidden(true, animated: true) //Set hidden if we are returning to a search
        } else {
            self.navigationController?.setToolbarHidden(false, animated: true)
        }
        
        //Deselect the current row if the detail vc is not showing at the moment
        if splitViewController?.isCollapsed ?? false {
            if let indexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
        
        if !realmController.generalRealm.isInWriteTransaction {
            //Track if an event was added or deleted
            eventsObserverToken = realmController.generalRealm.objects(Event.self).observe {[weak self] eventsChanges in
                guard let _ = self else {
                    return
                }
                switch eventsChanges {
                case .update(_, let deletions, let insertions, let modifications):
                    if deletions.count > 0 || insertions.count > 0 || modifications.count > 0 {
                        DispatchQueue.main.async {
                            //Attempt to keep in the event in the case that it was reloaded, if not then just move to no selected event
                            if let eventKey = UserDefaults.standard.value(forKey: self?.lastSelectedEventStorageKey ?? "") as? String {
                                self?.selectedEvent = RealmController.realmController.generalRealm.object(ofType: Event.self, forPrimaryKey: eventKey)
                            } else {
                                self?.selectedEvent = nil
                            }
                        }
                        
                        if self?.selectedEvent == nil {
                            let events = RealmController.realmController.generalRealm.objects(Event.self)
                            if events.count > 0 {
                                //There is no selected event, but there are events to choose from, let's just pick a random one
                                self?.selectedEvent = events.first
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
        
        reloadEventRankerObserver()
    }
    
    func reloadEventRankerObserver() {
        guard !realmController.syncedRealm.isInWriteTransaction else {
            return
        }
        
        //Add observer to listen for changes in the pick list
        eventRankerObserverToken = nil
        eventPickedTeamsObserverToken = nil
        
        if let event = selectedEvent {
            if let eventRanker = realmController.getTeamRanker(forEvent: event) {
                
                self.eventRankerObserverToken = eventRanker.rankedTeams.observe {[weak self] collectionChange in
                    switch collectionChange {
                    case .update(_, let deletions, let insertions,_):
                        DispatchQueue.main.async {
                            if deletions.count > 0 || insertions.count > 0 {
                                if !event.isInvalidated {
                                    self?.currentEventTeams = self!.realmController.teamRanking(forEvent: event)
                                } else {
                                    Crashlytics.sharedInstance().recordCustomExceptionName("Unable to update view of team list rank (non fatal)", reason: "Event is invalidated", frameArray: [])
                                }
                            }
                        }
                    default:
                        break
                    }
                }
                
                self.eventPickedTeamsObserverToken = eventRanker.pickedTeams.observe {[weak self] collectionChange in
                    switch collectionChange {
                    case .update:
                        //Reload all visible rows
                        DispatchQueue.main.async {
                            if let visibleRows = self?.tableView.indexPathsForVisibleRows {
                                self?.tableView.reloadRows(at: visibleRows, with: UITableViewRowAnimation.none)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        eventsObserverToken?.invalidate()
        eventRankerObserverToken?.invalidate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let previousOpenKey = "FAST-HasBeenOpened"
        //Show a choose event screen if we are in spectator mode and is the first time opening
        if RealmController.isInSpectatorMode && !(UserDefaults.standard.value(forKey: previousOpenKey) as? Bool ?? false) {
            let chooseEventScreen = storyboard?.instantiateViewController(withIdentifier: "addEvent") as! AddEventTableViewController
            
            let nav = UINavigationController(rootViewController: chooseEventScreen)
            nav.modalPresentationStyle = .formSheet
            
            self.present(nav, animated: true) {
                UserDefaults.standard.setValue(true, forKey: previousOpenKey)
            }
        }
        
        let hasShownInstructionalAlertKey = "FAST-HasShownInstructionalAlert"
        //Show an instructional alert about the event ranks
        if RealmController.isInSpectatorMode && !(UserDefaults.standard.value(forKey: hasShownInstructionalAlertKey) as? Bool ?? false) {
            //Wait until the user has finished adding the first event
            if selectedEvent != nil {
                //Now show it
                let alert = UIAlertController(title: "Important Tip", message: "The edit button on the bottom left allows you to reorder the team list however you would like in order to bring your favorite teams to the top. The rank numbers on the left correspond to this order and not the event qualification ranking. To find the qualification ranking of a team, click into that team's detail page or use the sort menu.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
                UserDefaults.standard.set(true, forKey: hasShownInstructionalAlertKey)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        self.teamImages.removeAll()
    }
    
    //MARK: - TeamListDetailDataSource
    func team() -> Team? {
        return selectedTeam
    }
    
    func inEvent() -> Event? {
        return selectedEvent
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let _ = selectedEvent {
            //Hide the show event text
            tableView.backgroundView?.isHidden = true
            tableView.separatorStyle = .singleLine
            tableView.tableHeaderView?.isHidden = false
            return 1
        } else {
            //Show the select event text
            tableView.backgroundView?.isHidden = false
            tableView.tableHeaderView?.isHidden = true
            tableView.separatorStyle = .none
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentTeamsToDisplay.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "rankedCell", for: indexPath) as! TeamListTableViewCell

        let team = currentTeamsToDisplay[(indexPath as NSIndexPath).row]
        
        cell.teamLabel.text = "Team \(team.teamNumber)"
        cell.teamNameLabel.text = team.nickname
        if let statName = statToSortBy {
            let statValue: StatValue
            if let stat = Team.StatName(rawValue: statName) {
                statValue = team.statValue(forStat: stat)
            } else if let stat = TeamEventPerformance.StatName(rawValue: statName) {
                statValue = realmController.eventPerformance(forTeam: team, atEvent: selectedEvent!)!.statValue(forStat: stat)
            } else {
                statValue = .NoValue
            }
            cell.statLabel.text = "\(statValue)"
        } else {
            cell.statLabel.text = ""
        }
        
        if let index = currentEventTeams.index(where: {$0 == team}) {
            cell.rankLabel.text = "\(index as Int + 1)"
        } else {
            cell.rankLabel.text = "?"
            Crashlytics.sharedInstance().recordCustomExceptionName("Team Event Rank Failed", reason: "Team is not in currentEventTeams. Team: \(team.key), Event: \(selectedEvent?.key)", frameArray: [])
        }
        
        //Show an X if they have been picked
        cell.accessoryView = nil
        if let eventRanker = self.selectedEventRanker {
            if !eventRanker.isInPickList(team: team) {
                //Show indicator that it is not in pick list
                let crossImage = UIImageView(image: #imageLiteral(resourceName: "Cross"))
                crossImage.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                cell.accessoryView = crossImage
                
            }
        }
        
        if let image = teamImages[team.key] {
            cell.frontImage.image = image
        } else {
            if let imageData = team.scouted?.frontImage {
                guard let uiImage = UIImage(data: imageData as Data) else {
                    Crashlytics.sharedInstance().recordCustomExceptionName("Image data corrupted", reason: "Attempt to create UIImage from data failed.", frameArray: [])
                    return cell
                }
                cell.frontImage.image = uiImage
                teamImages[team.key] = uiImage
            } else {
                cell.frontImage.image = UIImage(named: "FRC-Logo")
            }
        }
        
        //Show the indicator if this is the team that is currently logged in
        cell.myTeamIndicatorImageView.isHidden = true
        if let loggedInTeam = UserDefaults.standard.value(forKey: "LoggedInTeam") as? String {
            if let teamInt = Int(loggedInTeam) {
                if teamInt == team.teamNumber {
                    cell.myTeamIndicatorImageView.isHidden = false
                }
            }
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let pressedTeam = currentTeamsToDisplay[indexPath.row]
        
        let teamListDetailVC: TeamListDetailViewController = teamListSplitVC.teamListDetailVC
        
        //Set the selected team (and alert the delegate)
        selectedTeam = pressedTeam
        
        //Show the detail vc
        splitViewController?.showDetailViewController(teamListDetailVC, sender: self)
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        //Only allow editing in an event
        if let _ = self.selectedEvent {
            return true
        } else {
            return false
        }
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }
    
//    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
//        if let event = selectedEvent {
//            guard let ranker = RealmController.realmController.getTeamRanker(forEvent: event) else {
//                return nil
//            }
//            let team = self.currentTeamsToDisplay[indexPath.row]
//
//            let markAsPicked = UITableViewRowAction(style: .default, title: "Mark Picked") {action, indexPath in
//
//            }
//
//        }
//
//        return nil
//    }
//
//    func markAsPicked(atIndexPath indexPath: IndexPath, inTableView tableView: UITableView) {
//
//    }
    
    //For selecting which teams have been picked
    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        guard !RealmController.isInSpectatorMode else {
            return nil
        }
        
        if let event = selectedEvent {
            
            guard let ranker = RealmController.realmController.getTeamRanker(forEvent: event) else {
                return nil
            }
            let team = self.currentTeamsToDisplay[indexPath.row]
            
            let markAsPicked = UIContextualAction(style: .normal, title: "Mark Picked") {(contextAction: UIContextualAction, sourceView: UIView, completionHandler: (Bool) -> Void) in
                
                RealmController.realmController.syncedRealm.beginWrite()
                ranker.setIsInPickList(!ranker.isInPickList(team: team), team: team)
                do {
                    try RealmController.realmController.syncedRealm.commitWrite(withoutNotifying: [self.eventPickedTeamsObserverToken ?? NotificationToken()])
                } catch {
                    CLSNSLogv("Error saving write of change to pick list: \(error)", getVaList([]))
                    Crashlytics.sharedInstance().recordError(error)
                }
                
                completionHandler(true)
                
                //Reload that row
                tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.right)
            }
            
            markAsPicked.backgroundColor = ranker.isInPickList(team: team) ? .purple : .red
            markAsPicked.title = ranker.isInPickList(team: team) ? "Mark As Picked" : "Unmark as Picked"
            
            let swipeConfig = UISwipeActionsConfiguration(actions: [markAsPicked])
            return swipeConfig
        }
        
        return nil
    }
    

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
        //Move the team in the array and in Core Data
        guard let event = selectedEvent else {
            return
        }
        
        realmController.moveTeam(from: fromIndexPath.row, to: toIndexPath.row, inEvent: event)
    }

    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return selectedEvent != nil
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let event = selectedEvent, event.isInvalidated == false {
            return "Event: \(event.name)"
        } else {
            return "Teams"
        }
    }
    
    //MARK: Editing
    //Function for setting the editing of the teams
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        tableView.setEditing(editing, animated: animated)
        
        if editing {
            editButton.image = UIImage(named: "Edit Filled")
        } else {
            editButton.image = UIImage(named: "Edit")
        }
    }
    
    @IBAction func editPressed(_ sender: UIBarButtonItem, forEvent event: UIEvent) {
        guard let touch = event.allTouches?.first else {
            return
        }
        
        if touch.tapCount == 1 {
            //Is asingle short press
            if isEditing {
                setEditing(false, animated: true)
            } else {
                setEditing(true, animated: true)
            }
        } else if touch.tapCount == 0 {
            //Long press
            if let frcEvent = selectedEvent {
                let clearPickListAlert = UIAlertController(title: "Reset Picked Teams", message: "Would you like to reset what teams are picked or not? This will not affect any scouting data, just the Xs next to teams that were marked as picked.", preferredStyle: .alert)
                clearPickListAlert.addAction(UIAlertAction(title: "Reset", style: .default, handler: {_ in
                    //Reset the picked teams
                    let eventRanker = RealmController.realmController.getTeamRanker(forEvent: frcEvent)
                    
                    RealmController.realmController.genericWrite(onRealm: .Synced) {
                        eventRanker?.pickedTeams.removeAll()
                    }
                }))
                clearPickListAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(clearPickListAlert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "eventSelection" {
            let destinationVC = (segue.destination as! UINavigationController).topViewController as! EventPickerViewController
            destinationVC.delegate = self
        }
    }
    
    //MARK: - Sorting
    @IBAction func sortPressed(_ sender: UIBarButtonItem) {
        let sortNavVC = storyboard?.instantiateViewController(withIdentifier: "sortNav") as! UINavigationController
        let sortVC = sortNavVC.topViewController as! SortVC
        sortVC.delegate = self
        sortNavVC.modalPresentationStyle = .popover
        sortNavVC.preferredContentSize = CGSize(width: 350, height: 300)
        
        let popoverVC = sortNavVC.popoverPresentationController
        popoverVC?.delegate = self
        
        popoverVC?.barButtonItem = sender
        present(sortNavVC, animated: true, completion: nil)
    }
    
    func sortList(withStat statName: String?, isAscending ascending: Bool) {
        guard let selectedEvent = selectedEvent else {
            return
        }
        
        self.isSortingAscending = ascending
        
        statToSortBy = statName
        
        if let newStat = statName {
            let teamStat = Team.StatName(rawValue: newStat)
            let eventPerformanceStat = TeamEventPerformance.StatName(rawValue: newStat)
            
            if let stat = teamStat {
                currentSortedTeams = currentEventTeams.sorted {team1, team2 in
                    let isBefore = team1.statValue(forStat: stat) > team2.statValue(forStat: stat)
                    if ascending {
                        return !isBefore
                    } else {
                        return isBefore
                    }
                }
            } else if let stat = eventPerformanceStat {
                
                currentSortedTeams = currentEventTeams.sorted {team1, team2 in
                    let firstTeamEventPerformance: TeamEventPerformance = realmController.eventPerformance(forTeam: team1, atEvent: selectedEvent)!
                    let secondTeamEventPerformance: TeamEventPerformance = realmController.eventPerformance(forTeam: team2, atEvent: selectedEvent)!
                    
                    let firstStatValue = firstTeamEventPerformance.statValue(forStat: stat)
                    let secondStatValue = secondTeamEventPerformance.statValue(forStat: stat)
                    
                    let isBefore = firstStatValue > secondStatValue
                    if ascending {
                        return !isBefore
                    } else {
                        return isBefore
                    }
                }
            } else {
                assertionFailure()
            }
        } else {
            currentSortedTeams = currentEventTeams
        }
        
        if statToSortBy != nil {
            setEditing(false, animated: true)
            editButton.isEnabled = false
        } else {
            editButton.isEnabled = true
        }
    }
    
    @IBAction func matchesButtonPressed(_ sender: UIBarButtonItem) {
        let matchesSplitVC = storyboard?.instantiateViewController(withIdentifier: "matchOverviewSplitVC") as! MatchOverviewSplitViewController
        let matchOverviewMaster = (matchesSplitVC.viewControllers.first as! UINavigationController).topViewController as! MatchOverviewMasterViewController
        
        matchOverviewMaster.dataSource = self
        
        present(matchesSplitVC, animated: true, completion: nil)
        
        Answers.logCustomEvent(withName: "Opened Matches Overview", customAttributes: nil)
    }
    
    @IBAction func chartButtonPressed(_ sender: UIBarButtonItem) {
        if let event = selectedEvent {
            let eventStatGraphVC = storyboard?.instantiateViewController(withIdentifier: "eventStatsGraph") as! EventStatsGraphViewController
            let navVC = UINavigationController(rootViewController: eventStatGraphVC)
            
            navVC.modalPresentationStyle = .fullScreen
            
            eventStatGraphVC.setUp(forEvent: event)
            
            present(navVC, animated: true, completion: nil)
            
            Answers.logCustomEvent(withName: "Event Stats Grapher Button Pressed", customAttributes: nil)
        }
    }
    
    @IBAction func returnToTeamList(_ segue: UIStoryboardSegue) {
        
    }
    
    @IBAction func returningWithSegue(_ segue: UIStoryboardSegue) {
        
    }
}

extension TeamListTableViewController: MatchOverviewMasterDataSource {
    func event() -> Event? {
        return selectedEvent
    }
}

extension TeamListTableViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

extension TeamListTableViewController: EventSelection {
    func eventSelected(_ event: Event?) {
        selectedEvent = event
    }
    
    func currentEvent() -> Event? {
        return selectedEvent
    }
}

extension TeamListTableViewController: SortDelegate {
    func selectedStat(_ stat: String?, isAscending: Bool) {
        sortList(withStat: stat, isAscending: isAscending)
    }
    
    ///Returns all the stats to be potentially sorted by. If there is a selected event, then also return stats for TeamEventPerformances.
    func statsToDisplay() -> [String] {
        return (RealmController.isInSpectatorMode ? [] : Team.StatName.allValues.map {$0.rawValue}) + (selectedEvent != nil ? TeamEventPerformance.StatName.allValues.map {$0.rawValue} : [])
    }
    
    func currentStat() -> String? {
        return statToSortBy
    }
    
    func isAscending() -> Bool {
        return isSortingAscending
    }
}

extension TeamListTableViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        if isSearching {
            if let searchText = searchController.searchBar.text {
                Answers.logSearch(withQuery: searchText, customAttributes: nil)
                
                //For the new realm database
                var universalPredicates: [NSPredicate] = []
                universalPredicates.append(NSPredicate(format: "location CONTAINS[cd] %@", argumentArray: [searchText]))
                universalPredicates.append(NSPredicate(format: "name CONTAINS[cd] %@", argumentArray: [searchText]))
                universalPredicates.append(NSPredicate(format: "nickname CONTAINS[cd] %@", argumentArray: [searchText]))
                //For team number we want to return as many as possible as we are building the string (i.e. "42" should include team 4256 as a result).
                if let inputtedNum = Int(searchText) {
                    if inputtedNum < 9999 && inputtedNum > 0 {
                        var upperTeamNumLimit = inputtedNum
                        while upperTeamNumLimit < 1000 {
                            upperTeamNumLimit = (upperTeamNumLimit * 10) + 9
                        }
                        
                        var lowerTeamNumLimit = inputtedNum
                        while lowerTeamNumLimit < 1000 {
                            lowerTeamNumLimit = lowerTeamNumLimit * 10
                        }
                        
                        //Now create predicate with limits
                        universalPredicates.append(NSPredicate(format: "teamNumber BETWEEN {%@,%@}", argumentArray: [lowerTeamNumLimit, upperTeamNumLimit]))
                        
                        //And for three number teams (like team 931)
                        var upperTeamNumLimit3 = inputtedNum
                        while upperTeamNumLimit3 < 100 {
                            upperTeamNumLimit3 = (upperTeamNumLimit3 * 10) + 9
                        }
                        
                        var lowerTeamNumLimit3 = inputtedNum
                        while lowerTeamNumLimit3 < 100 {
                            lowerTeamNumLimit3 = lowerTeamNumLimit3 * 10
                        }
                        
                        universalPredicates.append(NSPredicate(format: "teamNumber BETWEEN {%@,%@}", argumentArray: [lowerTeamNumLimit3, upperTeamNumLimit3]))
                    }
                }
                universalPredicates.append(NSPredicate(format: "website CONTAINS[cd] %@", argumentArray: [searchText]))
                let universalPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: universalPredicates)
                
                let filteredTeams = self.currentSortedTeams.filter() {team in
                    return universalPredicate.evaluate(with: team)
                }
                
                currentTeamsToDisplay = filteredTeams
                
                tableView.reloadData()
            }
        } else {
            currentTeamsToDisplay = currentSortedTeams
        }
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        isSearching = true
        self.navigationController?.setToolbarHidden(true, animated: true)
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        //Set the current teams to display back
        currentTeamsToDisplay = currentSortedTeams
        isSearching = false
        self.navigationController?.setToolbarHidden(false, animated: true)
    }
}
