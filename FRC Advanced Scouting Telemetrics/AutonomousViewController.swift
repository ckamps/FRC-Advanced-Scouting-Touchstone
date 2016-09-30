//
//  AutonomousViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 2/13/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import UIKit

class AutonomousViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var optionsList: UITableView!
	@IBOutlet weak var cycleStepper: UIStepper!
	
	var standsScoutingVC: StandsScoutingViewController?
	let dataManager = TeamDataManager()
	
	var autonomousCycles: [AutonomousCycle] = [AutonomousCycle]()
	var sections: [AutonomousSection] = []
	var cachedSections: [AutonomousSection] = []
	
    var rowStage = 0
	
	var spySection = AutonomousSection(title: "Spy")
	
	var normalRows: [AutonomousRow] = [AutonomousRow]()
	
	struct AutonomousSection {
		let title: String
		var rows = [AutonomousRow]()
		var autonomousCycle: AutonomousCycle?
		
		init(title: String) {
			self.title = title
		}
		
		init(title: String, withRows rows: [AutonomousRow], andAutonomousCycle cycle: AutonomousCycle) {
			self.title = title
			self.rows = rows
			self.autonomousCycle = cycle
		}
	}
	
	struct AutonomousRow {
		var cellType: UITableViewCell.Type
		var associatedProperty: TeamMatchPerformance.AutonomousVariable?
		var label: String
		
		var firstLabel: String?
		var secondLabel: String?
		
		init(cellType: UITableViewCell.Type, label: String) {
			self.cellType = cellType
			self.label = label
		}
		
		init(cellType: UITableViewCell.Type, label: String, property: TeamMatchPerformance.AutonomousVariable) {
			self.cellType = cellType
			self.label = label
			self.associatedProperty = property
		}
		
		init(cellType: UITableViewCell.Type, label: String, property: TeamMatchPerformance.AutonomousVariable, first: String, second: String) {
			self.cellType = cellType
			self.label = label
			self.associatedProperty = property
			self.firstLabel = first
			self.secondLabel = second
		}
	}

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        optionsList.dataSource = self
        optionsList.delegate = self
        optionsList.allowsSelection = false
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		setup()
	}
	
	var isSetup = false
	func setup() {
		if !isSetup {
			isSetup = true
			standsScoutingVC = (parent as! StandsScoutingViewController)
			if standsScoutingVC?.matchPerformance?.autonomousCycles?.count == 0 {
				let cycle = dataManager.createAutonomousCycle(inMatchPerformance: standsScoutingVC!.matchPerformance!, atPlace: 0)
				autonomousCycles.append(cycle)
			} else {
				autonomousCycles = standsScoutingVC?.matchPerformance?.autonomousCycles?.array as! [AutonomousCycle]
			}
			
			normalRows = [
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Did they move?", property: .moved),
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Did they reach a defense?", property: .reachedDefense),
				AutonomousRow(cellType: AutonomousPickerCell.self, label: "Defense Reached"),
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Did they cross it successfully?", property: .crossedDefense),
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Did they shoot?", property: .shot),
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Did they return?", property: .returned)
			]
			
			spySection.rows = [
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Start in the spy box", property: .autoSpy),
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Did they shoot?", property: .autoSpyDidShoot),
				AutonomousRow(cellType: AutonomousSwitchCell.self, label: "Did they make it?", property: .autoSpyDidMakeShot),
				AutonomousRow(cellType: AutonomousSegmentCell.self, label: "In what goal?", property: .autoSpyShotHighGoal, first: "Low Goal", second: "High Goal")
			]
			spySection.autonomousCycle = autonomousCycles.first! //Add random cycle to use for referencing to the match performance
			
			sections.append(spySection)
			sections.append(AutonomousSection(title: "Cycle 1", withRows: normalRows, andAutonomousCycle: autonomousCycles.first!))
			optionsList.reloadData()
		}
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
	}
	
	@IBAction func cycleStepperChangedValue(_ sender: UIStepper) {
		while Int(sender.value) + 1 > sections.count {
			optionsList.beginUpdates()
			if cachedSections.isEmpty {
				sections.append(AutonomousSection(title: "Cycle \(sections.count)", withRows: normalRows, andAutonomousCycle: getAutoCycle(atIndex: sections.count - 1)))
			} else {
				sections.append(cachedSections.removeLast())
			}
			optionsList.insertSections(IndexSet.init(integer: Int(sender.value)), with: .top)
			optionsList.endUpdates()
		}
		
		while Int(sender.value) + 1 < sections.count {
			optionsList.beginUpdates()
			cachedSections.append(sections.removeLast())
			optionsList.deleteSections(IndexSet.init(integer: Int(sender.value) + 1), with: .top)
			optionsList.endUpdates()
		}
	}
	
	private func getAutoCycle(atIndex index: Int) -> AutonomousCycle {
		if autonomousCycles.count > index {
			return autonomousCycles[index]
		} else {
			autonomousCycles.append(dataManager.createAutonomousCycle(inMatchPerformance: standsScoutingVC!.matchPerformance!, atPlace: index))
			return autonomousCycles[index]
		}
	}
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return sections.count
	}
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return sections[section].title
	}
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let row = sections[(indexPath as NSIndexPath).section].rows[(indexPath as NSIndexPath).row]
		switch row.cellType {
		case is AutonomousPickerCell.Type:
			let cell = tableView.dequeueReusableCell(withIdentifier: "defenseReachedCell") as! AutonomousPickerCell
			cell.associatedAutonomousCycle = sections[(indexPath as NSIndexPath).section].autonomousCycle
			cell.autonomousVC = self
			cell.defenses = standsScoutingVC?.defenses
			return cell
		case is AutonomousSwitchCell.Type:
			let cell = tableView.dequeueReusableCell(withIdentifier: "mainCell") as! AutonomousSwitchCell
			cell.label.text = row.label
			cell.autonomousCycle = sections[(indexPath as NSIndexPath).section].autonomousCycle
			cell.associatedProperty = row.associatedProperty
			return cell
		case is AutonomousSegmentCell.Type:
			let cell = tableView.dequeueReusableCell(withIdentifier: "segmentCell") as! AutonomousSegmentCell
			cell.label.text = row.label
			cell.autonomousCycle = sections[(indexPath as NSIndexPath).section].autonomousCycle
			cell.associatedProperty = row.associatedProperty
			cell.firstOption = row.firstLabel
			cell.secondOption = row.secondLabel
			return cell
		default:
			return UITableViewCell()
		}
    }
}

class AutonomousSwitchCell: UITableViewCell {
	@IBOutlet weak var toggleSwitch: UISwitch!
	@IBOutlet weak var label: UILabel!
	
	var autonomousCycle: AutonomousCycle?
	var associatedProperty: TeamMatchPerformance.AutonomousVariable? {
		didSet {
			if let property = associatedProperty {
				toggleSwitch.isOn = property.getValue(inCycle: autonomousCycle!) as? Bool ?? false
			} else {
				toggleSwitch.isOn = false
			}
		}
	}
	
	@IBAction func switchSwitched(_ sender: UISwitch) {
		associatedProperty?.setValue(sender.isOn, inCycle: autonomousCycle!)
	}
}

class AutonomousSegmentCell: UITableViewCell {
	@IBOutlet weak var label: UILabel!
	@IBOutlet weak var segmentedControl: UISegmentedControl!
	
	var autonomousCycle: AutonomousCycle?
	var associatedProperty: TeamMatchPerformance.AutonomousVariable? {
		didSet {
			if let property = associatedProperty {
				if let selectedSegment = property.getValue(inCycle: autonomousCycle!) as? Bool {
					segmentedControl.selectedSegmentIndex = Int(selectedSegment)
				} else {
					segmentedControl.selectedSegmentIndex = -1
				}
			} else {
				segmentedControl.selectedSegmentIndex = -1
			}
		}
	}
	var firstOption: String? {
		didSet {
			segmentedControl.setTitle(firstOption, forSegmentAt: 0)
		}
	}
	var secondOption: String? {
		didSet {
			segmentedControl.setTitle(secondOption, forSegmentAt: 1)
		}
	}
	
	@IBAction func segmentChanged(_ sender: UISegmentedControl) {
		associatedProperty?.setValue(Bool(sender.selectedSegmentIndex), inCycle: autonomousCycle!)
	}
}

class AutonomousPickerCell: UITableViewCell, UIPickerViewDataSource, UIPickerViewDelegate {
	@IBOutlet weak var selectButton: UIButton!
	var associatedAutonomousCycle: AutonomousCycle? {
		didSet {
			if let cycle = associatedAutonomousCycle {
				selectButton.setTitle(cycle.defenseReached ?? "Select Defense", for: UIControlState())
			}
		}
	}
	var autonomousVC: AutonomousViewController?
	var defenses: [Defense]?
	
	@IBAction func selectDefenseButtonPressed(_ sender: UIButton) {
		let defensePickerVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "defensePicker") as! PopoverPickerViewController
		defensePickerVC.modalPresentationStyle = .popover
		defensePickerVC.preferredContentSize = CGSize(width: 300, height: 250)
		let popoverController = defensePickerVC.popoverPresentationController!
		popoverController.sourceView = sender
		
		autonomousVC?.present(defensePickerVC, animated: true) {
			defensePickerVC.picker.dataSource = self
			defensePickerVC.picker.delegate = self
		}
	}
	
	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}
	
	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return (autonomousVC?.standsScoutingVC?.defenses?.count ?? 0) + 1
	}
	
	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		if row < (defenses?.count)! {
			return defenses![row].description
		} else {
			return "Low Bar"
		}
	}
	
	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		//Update core data
		if row < (defenses?.count)! {
			associatedAutonomousCycle?.defenseReachedDefense = defenses?[row]
		} else {
			associatedAutonomousCycle?.defenseReachedDefense = Defense.LowBar
		}
		
		selectButton.setTitle((associatedAutonomousCycle?.defenseReached) ?? "ERROR", for: UIControlState())
	}
}
