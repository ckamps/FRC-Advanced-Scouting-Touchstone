//
//  TrasnferInfoTableViewController.swift
//  FRC Advanced Scouting Touchstone
//
//  Created by Aaron Kampmeier on 4/29/16.
//  Copyright © 2016 Kampfire Technologies. All rights reserved.
//

import UIKit
import RealmSwift

class TransferInfoTableViewController: UITableViewController {
    
	let realmController = RealmController.realmController
    
    var uploadToken: SyncSession.ProgressNotificationToken?
    var downloadToken: SyncSession.ProgressNotificationToken?
    
    weak var uploadProgressIndicator: UIProgressView?
    weak var downloadProgressIndicator: UIProgressView?
    
    weak var uploadImage: UIImageView?
    weak var downloadImage: UIImageView?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        if let syncUser = realmController.currentSyncUser {
            uploadToken = syncUser.session(for: realmController.syncedRealmURL!)?.addProgressNotification(for: .upload, mode: .reportIndefinitely) {[weak self] progress in
                DispatchQueue.main.async {
                    if progress.isTransferComplete {
                        self?.uploadProgressIndicator?.setProgress(1, animated: false)
                        self?.uploadImage?.image = #imageLiteral(resourceName: "CorrectIcon")
                    } else {
                        self?.uploadImage?.image = #imageLiteral(resourceName: "Up Arrow")
                        self?.uploadProgressIndicator?.setProgress(Float(progress.fractionTransferred), animated: true)
                    }
                }
            }
            
            downloadToken = syncUser.session(for: realmController.syncedRealmURL!)?.addProgressNotification(for: .download, mode: .reportIndefinitely) {[weak self] progress in
                DispatchQueue.main.async {
                    if progress.isTransferComplete {
                        self?.downloadProgressIndicator?.setProgress(1, animated: false)
                        self?.downloadImage?.image = #imageLiteral(resourceName: "CorrectIcon")
                    } else {
                        self?.downloadImage?.image = #imageLiteral(resourceName: "Down Arrow")
                        self?.downloadProgressIndicator?.setProgress(Float(progress.fractionTransferred), animated: true)
                    }
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        uploadToken?.invalidate()
        downloadToken?.invalidate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 2 //1 upload, 1 download
    }

	
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
		
        if indexPath.row == 0 {
            //Upload
            (cell.viewWithTag(1) as! UILabel).text = "Upload Progress"
            uploadProgressIndicator = (cell.viewWithTag(2) as! UIProgressView)
            uploadImage = (cell.viewWithTag(3) as! UIImageView)
            uploadImage?.image = #imageLiteral(resourceName: "Up Arrow")
        } else {
            (cell.viewWithTag(1) as! UILabel).text = "Download Progress"
            downloadProgressIndicator = (cell.viewWithTag(2) as! UIProgressView)
            downloadImage = (cell.viewWithTag(3) as! UIImageView)
            downloadImage?.image = #imageLiteral(resourceName: "Down Arrow")
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
