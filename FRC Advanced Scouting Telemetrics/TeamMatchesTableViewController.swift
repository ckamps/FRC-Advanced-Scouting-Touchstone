//
//  TeamMatchesTableViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 2/17/17.
//  Copyright © 2017 Kampfire Technologies. All rights reserved.
//

import UIKit

class TeamMatchesTableViewController: UITableViewController {
    
    var teamEventPerformance: TeamEventPerformance? {
        didSet {
            if let eventPerformance = teamEventPerformance {
                let unsortedMatches = (eventPerformance.matchPerformances?.allObjects as? [TeamMatchPerformance])?.map({$0.match!}) ?? []
                let sortedMatches = unsortedMatches.sorted() {(firstMatch, secondMatch) in
                    if firstMatch.competitionLevelEnum.rankedPosition > secondMatch.competitionLevelEnum.rankedPosition {
                        return true
                    } else if firstMatch.competitionLevelEnum.rankedPosition == secondMatch.competitionLevelEnum.rankedPosition {
                        return firstMatch.matchNumber!.int32Value < secondMatch.matchNumber!.int32Value
                    } else {
                        return false
                    }
                }
                
                matches = sortedMatches
            } else {
                matches = []
            }
        }
    }
    var matches: [Match] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 62
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func load(forTeamEventPerformance teamEventPerformance: TeamEventPerformance?) {
        self.teamEventPerformance = teamEventPerformance
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.preferredContentSize = tableView.contentSize
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return matches.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "matchCell") as! MatchListTableViewCell
        
        let match = matches[indexPath.row]
        cell.matchLabel.text = "\(match.competitionLevelEnum) \(match.matchNumber!)"
        
        for teamLabel in cell.teamLabels {
            teamLabel.layer.borderColor = nil
        }
        
        cell.red1.text = match.teamMatchPerformance(forColor: .Red, andSlot: .One).eventPerformance?.team.teamNumber
        cell.red2.text = match.teamMatchPerformance(forColor: .Red, andSlot: .Two).eventPerformance?.team.teamNumber
        cell.red3.text = match.teamMatchPerformance(forColor: .Red, andSlot: .Three).eventPerformance?.team.teamNumber
        
        cell.blue1.text = match.teamMatchPerformance(forColor: .Blue, andSlot: .One).eventPerformance?.team.teamNumber
        cell.blue2.text = match.teamMatchPerformance(forColor: .Blue, andSlot: .Two).eventPerformance?.team.teamNumber
        cell.blue3.text = match.teamMatchPerformance(forColor: .Blue, andSlot: .Three).eventPerformance?.team.teamNumber
        
        
        if let date = match.time {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current
            
            dateFormatter.dateFormat = "EEE dd, HH:mm"
            cell.timeLabel.text = dateFormatter.string(from: date)
        } else {
            cell.timeLabel.text = ""
        }
        
        return cell
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}