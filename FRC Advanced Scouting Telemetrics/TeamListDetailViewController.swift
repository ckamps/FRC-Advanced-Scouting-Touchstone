//
//  TeamListDetailViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 5/1/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import UIKit
import NYTPhotoViewer
import Crashlytics

class TeamListDetailViewController: UIViewController, TeamSelectionDelegate {
	@IBOutlet weak var frontImageButton: UIButton!
	@IBOutlet weak var teamLabel: UILabel!
	@IBOutlet weak var standsScoutingButton: UIBarButtonItem!
    @IBOutlet weak var pitScoutingButton: UIBarButtonItem!
	@IBOutlet weak var navBar: UINavigationItem!
    @IBOutlet var frontImageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var notesButton: UIButton!
    @IBOutlet weak var generalInfoTableView: UITableView?
    @IBOutlet weak var contentScrollView: TeamInfoScrollView!
    @IBOutlet weak var detailTableViewHeight: NSLayoutConstraint!
    
    var detailCollectionVC: TeamDetailCollectionViewController?
    
    //Insets for the scroll view
    var contentViewInsets: UIEdgeInsets {
        get {
            return UIEdgeInsetsMake(frontImageHeightConstraint.constant, 0, 0, 0)
        }
    }
    var noContentInsets: UIEdgeInsets {
        get {
            return UIEdgeInsetsMake(0, 0, 0, 0)
        }
    }
	
	var frontImage: TeamImagePhoto? {
		didSet {
			frontImageButton.setImage(frontImage?.image, for: .normal)
		}
	}
	
	var sideImage: TeamImagePhoto?

	let teamManager = TeamDataManager()
	var selectedTeam: ObjectPair<Team,LocalTeam>? {
		didSet {
			if let team = selectedTeam {
				navBar.title = team.universal.teamNumber
				teamLabel.text = team.universal.nickname
				
				//Populate the images, if there are images
				if let image = team.local.frontImage {
					frontImage = TeamImagePhoto(image: UIImage(data: image as Data), attributedCaptionTitle: NSAttributedString(string: "Team \(team.universal.teamNumber!): Front Image"))
                    frontImageHeightConstraint.isActive = true
                    
                    contentScrollView.contentInset = contentViewInsets
                    contentScrollView.scrollIndicatorInsets = contentViewInsets
                    
                    contentScrollView.contentOffset = CGPoint(x: 0, y: -frontImageHeightConstraint.constant)
				} else {
					frontImage = nil
                    frontImageHeightConstraint.isActive = false
                    
                    contentScrollView.contentInset = noContentInsets
                    contentScrollView.scrollIndicatorInsets = noContentInsets
				}
				if let image = team.local.sideImage {
					sideImage = TeamImagePhoto(image: UIImage(data: image as Data), attributedCaptionTitle: NSAttributedString(string: "Team \(team.universal.teamNumber!): Side Image"))
				} else {
					sideImage = nil
				}
				
				if let _ = selectedEvent {
					standsScoutingButton.isEnabled = true
				} else {
					standsScoutingButton.isEnabled = false
				}
                
                pitScoutingButton.isEnabled = true
                
                notesButton.isEnabled = true
			} else {
                navBar.title = "Select Team"
                teamLabel.text = "Select Team"
                
                frontImage = nil
                sideImage = nil
                
                standsScoutingButton.isEnabled = false
                
                pitScoutingButton.isEnabled = false
                
                notesButton.isEnabled = false
			}
            
            generalInfoTableView?.reloadData()
            generalInfoTableView?.layoutIfNeeded()
            
            detailCollectionVC?.load(withTeam: selectedTeam?.universal)
            
            self.detailTableViewHeight.constant = self.generalInfoTableView?.contentSize.height ?? 10
			
			NotificationCenter.default.post(name: Notification.Name(rawValue: "TeamSelectedChanged"), object: self)
		}
	}
	var selectedEvent: Event?
	var teamEventPerformance: TeamEventPerformance? {
		get {
			if let team = selectedTeam {
				if let event = selectedEvent {
					//Get two sets
					let eventPerformances: Set<TeamEventPerformance> = Set(event.teamEventPerformances?.allObjects as! [TeamEventPerformance])
					let teamPerformances = Set(team.universal.eventPerformances?.allObjects as! [TeamEventPerformance])
					
					//Combine the two sets to find the one in both
					let teamEventPerformance = Array(eventPerformances.intersection(teamPerformances)).first!
					
					return teamEventPerformance
				}
			}
			return nil
		}
	}
	
    var teamSelectedBeforeViewLoading: ObjectPair<Team,LocalTeam>?
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		
		(UIApplication.shared.delegate as! AppDelegate).teamListDetailVC = self
		
		navigationItem.leftItemsSupplementBackButton = true
		
		//Set the stands scouting button to not selectable since there is no team selected
		standsScoutingButton.isEnabled = false
        pitScoutingButton.isEnabled = false
		
		//Set the images(buttons) content sizing property
		frontImageButton.imageView?.contentMode = .scaleAspectFill
        frontImageButton.setTitle(nil, for: .normal)
        
        contentScrollView.delegate = self
        if teamSelectedBeforeViewLoading?.local.frontImage != nil {
            frontImageHeightConstraint.isActive = true
            
            contentScrollView.contentInset = contentViewInsets
            contentScrollView.scrollIndicatorInsets = contentViewInsets
            
            contentScrollView.contentOffset = CGPoint(x: 0, y: -frontImageHeightConstraint.constant)
        } else {
            frontImageHeightConstraint.isActive = false
            
            contentScrollView.contentInset = noContentInsets
            contentScrollView.scrollIndicatorInsets = noContentInsets
            
            contentScrollView.contentOffset = CGPoint(x: 0, y: 0)
        }
		
		let displayModeButtonItem = splitViewController!.displayModeButtonItem
//		displayModeButtonItem.title = "Teams"
		
		if navigationItem.leftBarButtonItems?.isEmpty ?? true {
			navigationItem.leftBarButtonItems = [displayModeButtonItem]
		} else {
			navigationItem.leftBarButtonItems?.insert(displayModeButtonItem, at: 0)
		}
        
        generalInfoTableView?.delegate = self
        generalInfoTableView?.dataSource = self
        generalInfoTableView?.rowHeight = UITableViewAutomaticDimension
        generalInfoTableView?.estimatedRowHeight = 44
        
        //Load the data if a team was selected beforehand
        selectedTeam = teamSelectedBeforeViewLoading
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
        
        self.navigationController?.setToolbarHidden(true, animated: true)
	}
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		super.prepare(for: segue, sender: sender)
		
		if segue.identifier == "standsScouting" {
			let destinationVC = segue.destination as! StandsScoutingViewController
			destinationVC.teamEventPerformance = teamEventPerformance
        } else if segue.identifier == "pitScouting" {
            let pitScoutingVC = segue.destination as! PitScoutingViewController
            pitScoutingVC.scoutedTeam = selectedTeam?.universal
        } else if segue.identifier == "teamDetailCollection" {
            detailCollectionVC = segue.destination as! TeamDetailCollectionViewController
        }
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        //Reset the content insets
        coordinator.animate(alongsideTransition: {_ in
            if self.selectedTeam?.local.frontImage != nil {
                self.contentScrollView.contentInset = self.contentViewInsets
                self.contentScrollView.scrollIndicatorInsets = self.contentViewInsets
                
                self.contentScrollView.contentOffset = CGPoint(x: 0, y: -self.frontImageHeightConstraint.constant)
            } else {
                self.frontImageHeightConstraint.isActive = false
                
                self.contentScrollView.contentInset = self.noContentInsets
                self.contentScrollView.scrollIndicatorInsets = self.noContentInsets
                
                self.contentScrollView.contentOffset = CGPoint(x: 0, y: 0)
            }
            
            self.detailTableViewHeight.constant = self.generalInfoTableView?.contentSize.height ?? 10
        }, completion: nil)
    }
	
	//MARK: - Master View Delegate
	func selectedTeam(_ team: ObjectPair<Team,LocalTeam>?) {
        if self.isViewLoaded {
            selectedTeam = team
        } else {
            //The view isn't loaded yet, save it to be updated later during loading
            teamSelectedBeforeViewLoading = team
        }
	}
	
	func selectedEvent(_ event: Event?) {
		selectedEvent = event
	}
	
	@IBAction func listPressed(_ sender: UIBarButtonItem) {
		//splitViewController?.showViewController(splitViewController!.viewControllers.first!, sender: self)
	}
    
    @IBAction func notesButtonPressed(_ sender: UIButton) {
        let notesNavVC = storyboard?.instantiateViewController(withIdentifier: "notesNavVC") as! UINavigationController
        (notesNavVC.topViewController as! NotesViewController).dataSource = self
        
        notesNavVC.modalPresentationStyle = .popover
        notesNavVC.popoverPresentationController?.sourceView = sender
        
        present(notesNavVC, animated: true, completion: nil)
    }
	
	//MARK: Displaying full screen photos
	@IBAction func selectedImage(_ sender: UIButton) {
		let photo: NYTPhoto
		var photosArray: [NYTPhoto] = []
		switch sender {
		case frontImageButton:
			if let image = frontImage {
				photo = image
			} else {return}
//		case sideImageButton:
//			if let image = sideImage {
//				photo = image
//			} else {return}
		default:
			return
		}
		
		if let image = frontImage {
			photosArray.append(image)
		}
		if let image = sideImage {
			photosArray.append(image)
		}
		
		let photoVC = NYTPhotosViewController(photos: photosArray, initialPhoto: photo, delegate: self)
		present(photoVC, animated: true, completion: nil)
		Answers.logContentView(withName: "Team Robot Images", contentType: "Photo", contentId: nil, customAttributes: ["Team":"\(selectedTeam?.universal.teamNumber ?? "")"])
	}
}

extension TeamListDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        print()
    }
}

extension TeamListDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let team = selectedTeam {
            if let _ = team.universal.website {
                return 4
            } else {
                return 3
            }
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "nameValue")
            
            (cell?.contentView.viewWithTag(1) as! UILabel).text = "Location"
            (cell?.contentView.viewWithTag(2) as! UILabel).text = selectedTeam?.universal.location
            
            return cell!
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "nameValue")
            
            (cell?.contentView.viewWithTag(1) as! UILabel).text = "Rookie Year"
            (cell?.contentView.viewWithTag(2) as! UILabel).text = selectedTeam?.universal.rookieYear?.description
            
            return cell!
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "nameValue")
            
            (cell?.contentView.viewWithTag(1) as! UILabel).text = "Attending Events"
            
            let attendingEvents = (selectedTeam?.universal.eventPerformances?.allObjects as! [TeamEventPerformance]).map() {eventPerformance in
                return eventPerformance.event
            }
            //Create a string of all the attending events
            var eventString = ""
            
            for (index, event) in attendingEvents.enumerated() {
                eventString += "\(event.name!)"
                
                if !(attendingEvents.count - 1 == index) {
                    eventString += ", "
                }
            }
            
            (cell?.contentView.viewWithTag(2) as! UILabel).text = eventString
            
            return cell!
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "websiteButton")
            
            (cell?.contentView.viewWithTag(1) as! UIButton).addTarget(self, action: #selector(websiteButtonPressed(_:)), for: .touchUpInside)
            
            return cell!
        default:
            return UITableViewCell()
        }
    }
    
    func websiteButtonPressed(_ sender: UIButton) {
        if let url = URL(string: selectedTeam?.universal.website ?? "") {
            UIApplication.shared.openURL(url)
        }
    }
}

extension TeamListDetailViewController: NotesDataSource {
    func currentTeamContext() -> Team {
        return selectedTeam!.universal
    }
    
    func notesShouldSave() -> Bool {
        return true
    }
}

class TeamImagePhoto: NSObject, NYTPhoto {
	var image: UIImage?
	var imageData: Data?
	var placeholderImage: UIImage?
	var attributedCaptionTitle: NSAttributedString?
	var attributedCaptionCredit: NSAttributedString?
	var attributedCaptionSummary: NSAttributedString?
	
	init(image: UIImage?, imageData: Data? = nil, attributedCaptionTitle: NSAttributedString) {
		self.image = image
		self.imageData = imageData
		self.attributedCaptionTitle = attributedCaptionTitle
	}
}

extension TeamListDetailViewController: UITextViewDelegate {
	func textViewDidEndEditing(_ textView: UITextView) {
//		selectedTeam?.notes = textView.text
		teamManager.commitChanges()
	}
}

extension TeamListDetailViewController: NYTPhotosViewControllerDelegate {
	func photosViewController(_ photosViewController: NYTPhotosViewController, captionViewFor photo: NYTPhoto) -> UIView? {
		return nil
	}
	
	func photosViewController(_ photosViewController: NYTPhotosViewController, referenceViewFor photo: NYTPhoto) -> UIView? {
		if let photo = photo as? TeamImagePhoto {
			if photo == frontImage {
				return frontImageButton
			} else if photo == sideImage {
				return nil //sideImageButton
			} else {
				return nil
			}
		} else {
			return nil
		}
	}
	
	func photosViewController(_ photosViewController: NYTPhotosViewController, titleFor photo: NYTPhoto, at photoIndex: UInt, totalPhotoCount: UInt) -> String? {
		return nil
	}
	
	func photosViewController(_ photosViewController: NYTPhotosViewController, maximumZoomScaleFor photo: NYTPhoto) -> CGFloat {
		return CGFloat(2)
	}
	
	func photosViewController(_ photosViewController: NYTPhotosViewController, actionCompletedWithActivityType activityType: String?) {
		NSLog("Completed Action: \(activityType ?? "Unknown")")
		Answers.logShare(withMethod: activityType, contentName: "Team Photos", contentType: "Photo", contentId: nil, customAttributes: nil)
	}
}

