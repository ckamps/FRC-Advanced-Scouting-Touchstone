//
//  SSOffenseFuelViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 1/18/17.
//  Copyright © 2017 Kampfire Technologies. All rights reserved.
//

import UIKit
import VerticalSlider

class SSOffenseFuelViewController: UIViewController {
    @IBOutlet weak var addFuelButton: UIButton!
    @IBOutlet weak var fuelTankSlider: VerticalSlider!
    @IBOutlet weak var setFuelIncreaseLabel: UILabel!
    
    let ssDataManager = SSDataManager.currentSSDataManager()!
    
    var loadingWhereVC: SSOffenseWhereViewController! {
        didSet {
            loadingWhereVC.delegate = self
            loadingWhereVC.setUpWithButtons(buttons: [FuelLoadingLocations.Hopper.button(color: .orange), FuelLoadingLocations.LoadingStation.button(color: .orange), FuelLoadingLocations.Floor.button(color: .orange)], time: 3)
        }
    }
    var scoringWhereVC: SSOffenseWhereViewController! {
        didSet {
            scoringWhereVC.delegate = self
            scoringWhereVC.setUpWithButtons(buttons: [FuelScoringLocations.HighGoal.button(color: .orange), FuelScoringLocations.LowGoal.button(color: .orange)], time: 3)
        }
    }
    
    var hasLoadedFuel: Bool = false {
        didSet {
            if hasLoadedFuel {
                scoringWhereVC.show()
            } else {
                scoringWhereVC.hide()
                setFuelIncreaseLabel.isHidden = true
                fuelTankSlider.slider.isEnabled = false
                fuelTankSlider.slider.value = 0
            }
        }
    }
    
    var currentFuelTankLevel = 0.0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setFuelIncreaseLabel.isHidden = true
        fuelTankSlider.slider.addTarget(self, action: #selector(fuelSliderChanged(_:)), for: .touchUpInside)
        fuelTankSlider.slider.isEnabled = false
        
        //Account for preloaded fuel
        let preloadedFuel = ssDataManager.preloadedFuel
        if preloadedFuel == 0 {
            hasLoadedFuel = false
        } else {
            hasLoadedFuel = true
        }
        
        fuelTankSlider.slider.value = Float(preloadedFuel)
        currentFuelTankLevel = preloadedFuel
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addFuelButtonPressed(_ sender: UIButton) {
        loadingWhereVC.show()
        setFuelIncreaseLabel.isHidden = false
        fuelTankSlider.slider.isEnabled = true
    }

    func fuelSliderChanged(_ sender: UISlider) {
        ssDataManager.setAssociatedFuelIncrease(withFuelIncrease: currentFuelTankLevel - Double(sender.value))
        currentFuelTankLevel = Double(sender.value)
        fuelTankSlider.slider.isEnabled = false
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        switch segue.identifier ?? "" {
        case "loadingWhereVC":
            loadingWhereVC = segue.destination as! SSOffenseWhereViewController
        case "scoringWhereVC":
            scoringWhereVC = segue.destination as! SSOffenseWhereViewController
        default:
            break
        }
    }
    
    enum FuelLoadingLocations: String, CustomStringConvertible, FASTSSButtonable {
        case Hopper
        case LoadingStation = "Loading Station"
        case Floor
        
        var description: String {
            get {
                return self.rawValue
            }
        }
    }
    
    enum FuelScoringLocations: String, CustomStringConvertible, FASTSSButtonable {
        case LowGoal = "Low Goal"
        case HighGoal = "High Goal"
        
        var description: String {
            return self.rawValue
        }
    }
}

extension SSOffenseFuelViewController: WhereDelegate {
    func selected(_ whereVC: SSOffenseWhereViewController, id: String) {
        switch whereVC {
        case loadingWhereVC:
            ssDataManager.recordFuelLoading(location: id, atTime: ssDataManager.stopwatch.elapsedTime)
            hasLoadedFuel = true
        case scoringWhereVC:
            ssDataManager.recordFuelScoring(inGoal: id, atTime: ssDataManager.stopwatch.elapsedTime, scoredFrom: CGPoint(x: 8, y: 8))
            hasLoadedFuel = false
        default:
            break
        }
    }
}
