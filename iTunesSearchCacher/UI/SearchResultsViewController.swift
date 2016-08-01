//
//  SearchResultsViewController.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 10/07/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import UIKit
import CoreData

protocol ReusableView: class {}
extension ReusableView where Self: UIView {
    static var reuseIdentifier: String {
        return String(self)
    }
}
extension UITableViewCell: ReusableView { }

enum AudioPreviewState {
    case Playing
    case Paused
    case Finished
}

struct CurrentAudioPreview {
    let trackID: Int64
    var state: AudioPreviewState
}

class TrackTableViewCell: UITableViewCell {
    @IBOutlet private weak var thumbnailView: UIImageView!
    @IBOutlet private weak var topLabel: UILabel!
    @IBOutlet private weak var bottomLabel: UILabel!
    @IBOutlet private weak var downloadedStateView: UIImageView!
}

protocol SearchResultsViewControllerDelegate: class {
    func didSelectTrackAt(indexPath: NSIndexPath)
}

class SearchResultsViewController: UIViewController {

    var searchTerm: String!
    private var dataSource = SearchResultsDataSource(mainContext: AppManager.shared().mainContext)
    private weak var delegate: SearchResultsViewControllerDelegate?
    var fetchOnce = false
    
    let player = AudioPlayer()
    var currentAudioPreview = CurrentAudioPreview(trackID: 0, state: .Finished)
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var contentTableView: UITableView!
    @IBOutlet private weak var loadingView: UIView!
    @IBOutlet private weak var noDataView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = searchTerm
        
        noDataView.alpha = 0
        contentView.alpha = 0
        loadingView.alpha = 1
        
        player.delegate = self
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if !fetchOnce {
            dataSource.delegate = self
            dataSource.searchWithMode(SearchMode.Term(searchTerm))
            delegate = dataSource
        }
    }
    
    private func reloadData() {
        contentTableView.reloadData()
        
        UIView.animateWithDuration(0.3) { [unowned self] in
            if self.dataSource.numberOfItems > 0 {
                self.contentView.alpha = 1
                self.loadingView.alpha = 0
            } else {
                self.contentView.alpha = 0
                self.loadingView.alpha = 0
                self.noDataView.alpha = 1
            }
        }
    }
}

extension SearchResultsViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.numberOfItems
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(TrackTableViewCell.className, forIndexPath: indexPath) as! TrackTableViewCell
        
        cell.topLabel.text = dataSource[indexPath.row].topString
        cell.bottomLabel.text = dataSource[indexPath.row].bottomString
        cell.thumbnailView.image = dataSource[indexPath.row].trackImage
        cell.downloadedStateView.image = UIImage(named: dataSource[indexPath.row].previewState.imageName)!
        
        return cell
    }
}

extension SearchResultsViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        delegate?.didSelectTrackAt(indexPath)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}

extension SearchResultsViewController: SearchResultsDataSourceDelegate {
    func didReloadResults() {
        reloadData()
    }
    
    func didUpdateItemsAt(indexPaths: [NSIndexPath]) {
        contentTableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
    }
    
    func dataForAudioPreview(trackID: Int64, data: NSData) {
        if trackID == currentAudioPreview.trackID {
            switch currentAudioPreview.state {
            case .Playing:
                player.pause()
                currentAudioPreview.state = .Paused
            case .Paused, .Finished:
                player.play()
                currentAudioPreview.state = .Playing
            }
        } else {
            currentAudioPreview = CurrentAudioPreview(trackID: trackID, state: .Playing)
            player.play(data)
        }
    }
}

extension SearchResultsViewController: AudioPlayerPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AudioPlayer) {
        currentAudioPreview.state = .Finished
    }
}


