//
//  EventStatsGraphViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 3/4/18.
//  Copyright © 2018 Kampfire Technologies. All rights reserved.
//

import UIKit
import Charts
import Crashlytics

class EventStatsGraphViewController: UIViewController {
    var barChart: BarChartView!
    
    private var statsToGraph = [TeamEventPerformance.StatName]()
    private var teamEventPerformances = [TeamEventPerformance]()
    
//    let startSpace = 0.8
    let groupSpace = 0.12
    let barSpace = 0.02
//    let barWidth = 0.7
    var barWidth = 0.0
    
    var groupWidth: Double = 0
    
    var barColors = ChartColorTemplates.joyful()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        barColors += ChartColorTemplates.colorful()

        // Do any additional setup after loading the view.
        barChart = BarChartView()
        view.addSubview(barChart)
        
        barChart.delegate = self
        
        barChart.doubleTapToZoomEnabled = false
        
        barChart.highlighter = nil
        
        barChart.xAxis.valueFormatter = self
        barChart.xAxis.labelPosition = .bottom
//        barChart.xAxis.centerAxisLabelsEnabled = true
        barChart.xAxis.drawGridLinesEnabled = false
        barChart.xAxis.setLabelCount(25, force: false)
//        barChart.xAxis.labelRotationAngle = -90
        barChart.xAxis.labelFont = UIFont.systemFont(ofSize: 9)
        barChart.xAxis.axisMinimum = -0.5
        barChart.xAxis.granularity = 1
        
        barChart.rightAxis.enabled = false
        barChart.leftAxis.gridLineDashLengths = [4]
        barChart.leftAxis.zeroLineWidth = 10
        barChart.leftAxis.drawAxisLineEnabled = false
        
        barChart.noDataText = "Select Stats to Graph"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    
    func setUp(forEvent event: Event) {
        //Order the team performances according to pick list
        let eventPerformances = Array(event.teamEventPerformances)
        
        let ranker = RealmController.realmController.getTeamRanker(forEvent: event)!
        self.teamEventPerformances = eventPerformances.sorted {first, second in
            if let firstScouted = first.team?.scouted {
                if let secondScouted = second.team?.scouted {
                    return ranker.rankedTeams.index(of: firstScouted) ?? 0 < ranker.rankedTeams.index(of: secondScouted) ?? 0
                }
            }
            Crashlytics.sharedInstance().recordCustomExceptionName("Event Stats Sorting Failed", reason: "Event: \(event.key)", frameArray: [])
            return false
        }
    }
    
    override func viewWillLayoutSubviews() {
        if #available(iOS 11.0, *) {
            barChart.frame.origin.x = view.safeAreaInsets.left
            barChart.frame.origin.y = view.safeAreaInsets.top
            barChart.frame.size.width = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
            barChart.frame.size.height = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom - 5
        } else {
            barChart.frame.origin.x = view.frame.origin.x
            barChart.frame.origin.y = view.frame.origin.y
            barChart.frame.size.width = view.bounds.width
            barChart.frame.size.height = view.bounds.height - 5
        }
        barChart.chartDescription?.position = CGPoint(x: barChart.frame.width - 20, y: barChart.frame.height - 15)
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func selectStatsPressed(_ sender: UIBarButtonItem) {
        //Show select stats vc
        let selectStatsVC = storyboard!.instantiateViewController(withIdentifier: "selectStatsVC") as! SelectStatsTableViewController
        let navController = UINavigationController(rootViewController: selectStatsVC)
        
        selectStatsVC.delegate = self
        
        navController.modalPresentationStyle = .popover
        
        navController.popoverPresentationController?.barButtonItem = sender
        navController.preferredContentSize = CGSize(width: 300, height: 650)
        
        present(navController, animated: true, completion: nil)
    }
    
    func loadGraph() {
        //Must create multiple BarChartDataSets for grouped bar charts
        var barChartDataSets = [BarChartDataSet]()
        
        for (index, stat) in statsToGraph.enumerated() {
            //Create a BarChartDataSet which takes in BarChartDataEntries
            var barChartDataEntries = [BarChartDataEntry]()
            for (index, teamEventPerformance) in teamEventPerformances.enumerated() {
                //Create a BarChartDataEntry
                var statDouble: Double
                var isNoValue: Bool = false
                switch teamEventPerformance.statValue(forStat: stat) {
                case .Double(let val):
                    statDouble = val
                case .Integer(let val):
                    statDouble = Double(val)
                case .Percent(let val):
                    //TODO: Add in formatting for percents
                    statDouble = val
                case .Bool(let val):
                    //TODO: Format for bools
                    statDouble = Double(val.hashValue)
                case .String:
                    //TODO: Show warning for graphing strings
                    statDouble = 0
                    isNoValue = true
                case .NoValue:
                    statDouble = 0
                    isNoValue = true
                }
                let entry = FASTBarChartDataEntry(x: Double(index), y: statDouble)
                entry.isNoValue = isNoValue
                barChartDataEntries.append(entry)
            }
            
            let dataSet = BarChartDataSet(values: barChartDataEntries, label: stat.description)
            dataSet.colors = [barColors[index % barColors.count]]
            dataSet.valueFormatter = self
            barChartDataSets.append(dataSet)
        }
        
        let barChartData = BarChartData(dataSets: barChartDataSets)
        
        barWidth = (1 - groupSpace - (Double(barChartDataSets.count) * barSpace)) / Double(barChartDataSets.count) //So that the group space always equals 1
        barChartData.barWidth = barWidth
        groupWidth = barChartData.groupWidth(groupSpace: groupSpace, barSpace: barSpace) //Should be one
        
        barChartData.groupBars(fromX: -0.5, groupSpace: groupSpace, barSpace: barSpace)
        
        //Check the y min and if it's not below 0 than scale the y axis down
        var hasDataBelowZero = false
        for set in barChartDataSets {
            if set.yMin < 0 {hasDataBelowZero = true}
        }
        
        if !hasDataBelowZero {
            barChart.leftAxis.axisMinimum = 0
        } else {
            barChart.leftAxis.resetCustomAxisMin()
        }
        
        barChart.animate(xAxisDuration: 0.5, yAxisDuration: 0.7, easingOption: .easeInOutQuart)
        
        barChart.data = barChartData
        
        if let key = self.teamEventPerformances.first?.event?.key {
            barChart.chartDescription?.text = "Event \(key)"
        } else {
            barChart.chartDescription?.text = "No Event"
        }
        
        Answers.logContentView(withName: "Event Stats Graph", contentType: "Graph", contentId: nil, customAttributes: ["Num of Stats Graphed":statsToGraph.count])
    }
}

extension EventStatsGraphViewController: IAxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        //X-axis
        let groupNumber: Double
        groupNumber = value
        
        //Check it is a whole number
        if groupNumber - Double(Int(groupNumber)) == 0 {
            //It is whole number
            if (teamEventPerformances.count > Int(groupNumber)) {
                return "\(teamEventPerformances[Int(groupNumber)].team?.teamNumber ?? 0)"
            } else {
                return ""
            }
        } else {
            return ""
        }
    }
}

class FASTBarChartDataEntry: BarChartDataEntry {
    var isNoValue = false
}

extension EventStatsGraphViewController: IValueFormatter {
    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        if let entry = entry as? FASTBarChartDataEntry {
            if entry.isNoValue {
                return "NA"
            } else {
                return value.description(roundedAt: 2)
            }
        } else {
            return value.description(roundedAt: 2)
        }
    }
}

extension EventStatsGraphViewController: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        
    }
    
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        
    }
    
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        
    }
}

extension EventStatsGraphViewController: SelectStatsDelegate {
    func currentlySelectedStats() -> [TeamEventPerformance.StatName] {
        return statsToGraph
    }
    
    func selectStatsTableViewController(_ vc: SelectStatsTableViewController, didSelectStats selectedStats: [TeamEventPerformance.StatName]) {
        self.statsToGraph = selectedStats
        loadGraph()
    }
}
