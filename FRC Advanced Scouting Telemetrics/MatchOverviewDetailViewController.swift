//
//  MatchOverviewViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 3/1/17.
//  Copyright © 2017 Kampfire Technologies. All rights reserved.
//

import UIKit

protocol MatchOverviewDetailDataSource {
    func match() -> Match?
}

class MatchOverviewDetailViewController: UIViewController {
    @IBOutlet weak var matchTitleLabel: UILabel!
    @IBOutlet weak var redPointsLabel: UILabel!
    @IBOutlet weak var redRankingPointsLabel: UILabel!
    @IBOutlet weak var bluePointsLabel: UILabel!
    @IBOutlet weak var blueRankingPointsLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    var dataSource: MatchOverviewDetailDataSource?
    
    var matchOverviewSplitVC: MatchOverviewSplitViewController {
        get {
            if let matchSplit = self.splitViewController as? MatchOverviewSplitViewController {
                return matchSplit
            } else {
                return MatchOverviewSplitViewController.default
            }
        }
    }
    var displayedMatch: Match? {
        didSet {
            if let match = displayedMatch {
                matchTitleLabel.text = match.description
                
                redPointsLabel.text = "\(match.local.redFinalScore?.description ?? "-") Pts."
                redRankingPointsLabel.text = "\(match.local.redRankingPoints?.description ?? "-") RP"
                bluePointsLabel.text = "\(match.local.blueFinalScore?.description ?? "-") Pts."
                blueRankingPointsLabel.text = "\(match.local.blueRankingPoints?.description ?? "-") RP"
                
                //Set the teams in the segmented control
                for teamMatchPerformance in match.teamPerformances?.allObjects as! [TeamMatchPerformance] {
                    switch (teamMatchPerformance.alliance) {
                    case .Red:
                        segmentedControl.setTitle(teamMatchPerformance.eventPerformance?.team.teamNumber, forSegmentAt: teamMatchPerformance.slot.rawValue - 1)
                    case .Blue:
                        segmentedControl.setTitle(teamMatchPerformance.eventPerformance?.team.teamNumber, forSegmentAt: teamMatchPerformance.slot.rawValue + 2)
                    }
                }
                
                segmentedControl.selectedSegmentIndex = 0
                self.selectedDifferentTeam(segmentedControl)
            }
        }
    }
    
    var selectedMatchPerformance: TeamMatchPerformance?
    
    var matchPerformanceDetail: MatchOverviewPerformanceDetailViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        matchOverviewSplitVC.matchesDetail = self
        
        self.navigationItem.leftItemsSupplementBackButton = true
        self.navigationItem.leftBarButtonItem = matchOverviewSplitVC.displayModeButtonItem
        
        self.dataSource = matchOverviewSplitVC.matchesMaster
        
        matchPerformanceDetail = self.childViewControllers.first! as! MatchOverviewPerformanceDetailViewController
        matchPerformanceDetail.dataSource = self
        
        reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func reloadData() {
        self.displayedMatch = dataSource?.match()
    }
    
    @IBAction func selectedDifferentTeam(_ sender: UISegmentedControl) {
        //Set the selected match performance
        if sender.selectedSegmentIndex <= 2 {
            selectedMatchPerformance = displayedMatch?.teamMatchPerformance(forColor: .Red, andSlot: TeamMatchPerformance.Slot(rawValue: sender.selectedSegmentIndex + 1)!)
        } else {
            selectedMatchPerformance = displayedMatch?.teamMatchPerformance(forColor: .Blue, andSlot: TeamMatchPerformance.Slot(rawValue: sender.selectedSegmentIndex - 2)!)
        }
        
        matchPerformanceDetail.reloadData()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension MatchOverviewDetailViewController: MatchOverviewPerformanceDetailDataSource {
    func teamMatchPerformance() -> TeamMatchPerformance? {
        return selectedMatchPerformance
    }
}