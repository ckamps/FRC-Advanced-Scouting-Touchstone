//
//  TrasnferInfoTableViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 4/29/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import UIKit

class TransferInfoTableViewController: UITableViewController {
	
	var currentTransfers = [String:(NSProgress, FASTPeer)]() {
		didSet {
			resourceNames = Array(currentTransfers.keys)
			tableView.reloadData()
		}
	}
	var resourceNames = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
		
		currentTransfers = DataSyncer.sharedDataSyncer().multipeerConnection.currentFileTransfers
		resourceNames = Array(currentTransfers.keys)
		
		NSNotificationCenter.defaultCenter().addObserverForName(DSTransferNumberChanged, object: nil, queue: nil) {notification in
			dispatch_async(dispatch_get_main_queue()) {
				self.currentTransfers = DataSyncer.sharedDataSyncer().multipeerConnection.currentFileTransfers
				
//				self.tableView.beginUpdates()
//				let updatedKeys = notification.userInfo!["UpdatedKeys"] as! [String]
//				let updatedFileTransfers = DataSyncer.sharedDataSyncer().multipeerConnection.currentFileTransfers
//				for key in updatedKeys {
//					self.currentTransfers[key] = updatedFileTransfers[key]
//					
//					if updatedFileTransfers[key] == nil {
//						if let index = self.resourceNames.indexOf(key) {
//							self.tableView.deleteRowsAtIndexPaths([NSIndexPath.init(forRow: index, inSection: 0)], withRowAnimation: .Top)
//							self.resourceNames.removeAtIndex(index)
//						}
//					} else {
//						if !self.resourceNames.contains(key) {
//							self.resourceNames.append(key)
//							self.tableView.insertRowsAtIndexPaths([NSIndexPath.init(forRow: self.resourceNames.indexOf(key)!, inSection: 0)], withRowAnimation: .Top)
//						}
//					}
//				}
//				
//				self.tableView.endUpdates()
			}
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return currentTransfers.count
    }

	
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)
		
		if let transfer = currentTransfers[resourceNames[indexPath.row]] {
			(cell.viewWithTag(1) as! UILabel).text = transfer.1.displayName ?? "Unknown"
			(cell.viewWithTag(2) as! UIProgressView).observedProgress = transfer.0
		}

        return cell
    }


    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
