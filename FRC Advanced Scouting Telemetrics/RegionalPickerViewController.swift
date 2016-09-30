//
//  RegionalPickerViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 2/15/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import UIKit

class RegionalPickerViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
	@IBOutlet weak var regionalPicker: UIPickerView!
	
	var delegate: RegionalSelection?
	var dataManager = TeamDataManager()
	private var regionals: [Regional]?
	private var currentRegional: Regional?
	private var chosenRegional: Regional?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		regionalPicker.dataSource = self
		regionalPicker.delegate = self
		
		//Load all the regionals
		regionals = dataManager.getAllRegionals()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		currentRegional = delegate?.currentRegional()
		
		if let current = currentRegional {
			let index = (regionals?.index(of: current))! + 1
			regionalPicker.selectRow(index, inComponent: 0, animated: false)
			pickerView(regionalPicker, didSelectRow: index, inComponent: 0)
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		delegate?.regionalSelected(chosenRegional)
	}
	
	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}
	
	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return regionals!.count + 1
	}
	
	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		switch row {
		case 0:
			return "All Teams (Default)"
		default:
			return regionals![row-1].name
		}
	}
	
	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		if row == 0 {
			chosenRegional = nil
		} else {
			chosenRegional = regionals![row-1]
		}
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

protocol RegionalSelection {
	func regionalSelected(_ regional: Regional?)
	func currentRegional() -> Regional?
}
