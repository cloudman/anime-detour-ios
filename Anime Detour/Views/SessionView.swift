//
//  SessionView.swift
//  Anime Detour
//
//  Created by Brendon Justin on 10/18/14.
//  Copyright (c) 2014 Anime Twin Cities, Inc. All rights reserved.
//

import Foundation
import UIKit

@objc protocol SessionViewDelegate {
    func didTapBookmarkButton()
}

/**
 UIScrollView so it can adjust the photo during scrolling.
 */
class SessionView: UIScrollView, AgeRequirementDisplayingView, SessionViewModelDelegate {
    /// The view which contains all of our subviews that actually have content,
    /// since we're a scroll view.
    @IBOutlet var contentView: UIView!
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var ageRequirementLabel: InsettableLabel!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var locationLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var categoryLabel: InsettableLabel!
    @IBOutlet var panelistsLabel: UILabel!
    @IBOutlet var ageRequirementInfoLabel: UILabel!
    
    /// The view displaying the session's description and any associated views.
    @IBOutlet var descriptionView: UIView!
    /// The view displaying the session's panelists and any associated views.
    @IBOutlet var panelistsView: UIView!
    /// The views displaying the session's age requirement info text and any associated views.
    /// They may not all be contained in one stack view, so use a collection.
    @IBOutlet var ageRequirementViews: [UIView]!
    
    @IBOutlet var imageHeaderView: ImageHeaderView!

    @IBOutlet var bookmarkButton: UIButton!
    
    @IBOutlet weak var sessionDelegate: SessionViewDelegate?
    
    private var ageRequirementDescriptionText: String?
    
    private var originalCategoryLabelColor: UIColor = UIColor.blackColor()

    private var image: UIImage? {
        didSet {
            imageHeaderView.image = image
            
            switch image {
            case _?:
                imageHeaderView.hidden = false
            default:
                imageHeaderView.hidden = true
            }
        }
    }
    
    var viewModel: SessionViewModel? {
        didSet {
            nameLabel.text = viewModel?.name
            timeLabel.text = viewModel?.dateAndTime
            
            if let viewModel = viewModel {
                showAgeRequirementOrHideLabel(forViewModel: viewModel)
                showAgeRequirementInfoOrHideViews(viewModel)
            }
            
            locationLabel.text = viewModel?.location
            if let sessionDescription = viewModel?.sessionDescription where !sessionDescription.isEmpty {
                descriptionView.hidden = false
                descriptionLabel.text = sessionDescription
            } else {
                descriptionView.hidden = true
            }
            categoryLabel.text = viewModel?.category
            let categoryColor = viewModel?.categoryColor ?? originalCategoryLabelColor
            categoryLabel.textColor = categoryColor
            let categoryLabelLayer = categoryLabel.layer
            categoryLabelLayer.borderColor = categoryColor.CGColor
            
            if let panelists = viewModel?.panelists where !panelists.isEmpty {
                panelistsView.hidden = false
                panelistsLabel.text = panelists
            } else {
                panelistsView.hidden = true
            }

            bookmarkButton.setImage(viewModel?.bookmarkImage, forState: .Normal)
            bookmarkButton.accessibilityLabel = viewModel?.bookmarkAccessibilityLabel
            
            if case true? = viewModel?.hasImage {
                imageHeaderView.hidden = false
                imageHeaderView.image = nil
            } else {
                imageHeaderView.hidden = true
            }
            
            viewModel?.image({ [weak self] (image, error) -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    switch image {
                    case let .Some(image):
                        self?.image = image
                    default:
                        self?.imageHeaderView.hidden = true
                    }
                })
            })
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        ageRequirementDescriptionText = ageRequirementInfoLabel.text
        originalCategoryLabelColor = categoryLabel.textColor
    }
    
    @IBAction func bookmarkButtonTapped(sender: AnyObject) {
        sessionDelegate?.didTapBookmarkButton()
    }
    
    private func showAgeRequirementInfoOrHideViews(viewModel: SessionViewModel) {
        let ageRequired: Int?
        if viewModel.is18Plus {
            ageRequired = 18
        } else if viewModel.is21Plus {
            ageRequired = 21
        } else {
            ageRequired = nil
        }
        
        if let ageRequired = ageRequired, ageRequirementDescriptionText = ageRequirementDescriptionText {
            ageRequirementInfoLabel.text = String(format: ageRequirementDescriptionText, ageRequired)
            for view in ageRequirementViews {
                view.hidden = false
            }
        } else {
            for view in ageRequirementViews {
                view.hidden = true
            }
        }
    }

    // MARK: - Session View Model Delegate

    func bookmarkImageChanged(bookmarkImage: UIImage, accessibilityLabel: String) {
        bookmarkButton.setImage(bookmarkImage, forState: .Normal)
        bookmarkButton.accessibilityLabel = accessibilityLabel
    }
}
