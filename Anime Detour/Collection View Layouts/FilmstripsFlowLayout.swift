//
//  FilmstripsFlowLayout.swift
//  Anime Detour
//
//  Created by Brendon Justin on 10/19/14.
//  Copyright (c) 2014 Naga Softworks, LLC. All rights reserved.
//

import UIKit

/**
Collection view layout that shows each section in a film strip, i.e. a horizontally scrolling list.
Otherwise similar to a standard flow layout.
*/
class FilmstripsFlowLayout: UICollectionViewFlowLayout, UIGestureRecognizerDelegate {
    /// Dictionary of section numbers to scroll offsets
    private var cumulativeOffsets: [Int : CGFloat] = [:]
    private var currentPanOffsets: [Int : CGFloat] = [:]
    private var sectionDynamicItems: [Int : SectionDynamicItem] = [:]
    private var sectionDynamicBehaviors: [Int : [UIDynamicBehavior]] = [:]
    private var springsForFirstItems: [Int : UISnapBehavior] = [:]
    private var springsForLastItems: [Int : UISnapBehavior] = [:]
    lazy private var positiveRect = CGRect(x: 0, y: 0, width: Int.max, height: Int.max)
    
    /// Animator to animate horizontal cell scrolling
    lazy private var dynamicAnimator: UIDynamicAnimator = UIDynamicAnimator()
    
    private var sectionHeight: CGFloat {
        get {
            let size = self.itemSize
            let lineSpacing = self.minimumLineSpacing
            let headerSize = self.headerReferenceSize
            
            let sectionHeight = headerSize.height + lineSpacing + size.height + lineSpacing
            return sectionHeight
        }
    }
    
    // MARK: Collection View Layout
    
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [AnyObject]? {
        let positiveRect = rect.rectByIntersecting(self.positiveRect)
        let size = self.itemSize
        let lineSpacing = self.minimumLineSpacing
        let cellSpacing = self.minimumInteritemSpacing
        let headerSize = self.headerReferenceSize
        
        let sectionHeight = self.sectionHeight
        let sectionsBeforeRect = self.section(forYCoordinate: positiveRect.minY)
        let lastPossibleSectionInRect = self.section(forYCoordinate: positiveRect.maxY)
        
        let totalSections = self.collectionView?.numberOfSections() ?? 0
        if totalSections == 0 {
            return [AnyObject]()
        }
        
        let firstSectionInRect = Int(min(sectionsBeforeRect, totalSections - 1))
        let lastSectionInRect = Int(min(totalSections, lastPossibleSectionInRect))
        let sectionsInRect = firstSectionInRect..<lastSectionInRect
        
        let maxItemsPerSectionInRect = Int(ceil(positiveRect.width / (size.width + cellSpacing)))
        
        let itemsPerSectionInRect: [Int : [Int]] = { () -> [Int : [Int]] in
            var itemSectionsAndNumbers = [Int : [Int]]()
            
            for section in sectionsInRect {
                let scrollOffsetForSection = self.totalOffset(forSection: section)
                let xOffsetForFirstItem: CGFloat = floor(positiveRect.minX / ceil(size.width + cellSpacing))
                
                let itemsInSection = self.collectionView?.numberOfItemsInSection(section) ?? 0
                
                let firstPossibleItemInRect = Int(ceil(positiveRect.minX / max(xOffsetForFirstItem, CGFloat(1))))
                let firstItemInRect = Int(min(itemsInSection, firstPossibleItemInRect))
                
                var itemNumbers = [Int]()
                for itemNumber in firstItemInRect..<itemsInSection {
                    let xOffsetForItemNumber: CGFloat = ceil((size.width + cellSpacing) * CGFloat(itemNumber)) + xOffsetForFirstItem
                    if xOffsetForItemNumber <= positiveRect.maxX {
                        itemNumbers.append(itemNumber)
                    } else {
                        break
                    }
                }

                itemSectionsAndNumbers[section] = itemNumbers
            }
            
            return itemSectionsAndNumbers
        }()
        
        var attributes: [UICollectionViewLayoutAttributes] = []
        for (section, itemNumbers) in itemsPerSectionInRect {
            for itemNumber in itemNumbers {
                attributes.append(self.layoutAttributesForItemAtIndexPath(NSIndexPath(forItem: itemNumber, inSection: section)))
            }
        }
        
        return attributes
    }
    
    override func layoutAttributesForItemAtIndexPath(indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes! {
        let size = self.itemSize
        let lineSpacing = self.minimumLineSpacing
        let cellSpacing = self.minimumInteritemSpacing
        let headerSize = self.headerReferenceSize
        
        let xOffsetForItemNumber: CGFloat = ceil((size.width + cellSpacing) * CGFloat(indexPath.item))
        let yOffsetForSectionNumber: CGFloat = ceil((size.height + lineSpacing + headerSize.height) * CGFloat(indexPath.section))

        let section = indexPath.section
        let frame = CGRect(origin: CGPoint(x: xOffsetForItemNumber + self.totalOffset(forSection: section), y: yOffsetForSectionNumber), size: size)
        let attributes = super.layoutAttributesForItemAtIndexPath(indexPath)
        attributes.frame = frame
        
        return attributes
    }
    
    override func collectionViewContentSize() -> CGSize {
        // Find the size needed of the rect that starts at 0,0 and ends at the bottom right
        // coordinates of the last collection view item. If the size is wider than the collection view's
        // frame, trim it down, then return it.
        
        let numberOfSections = self.collectionView?.numberOfSections() ?? 0
        if numberOfSections == 0 {
            return CGSizeZero
        }
        
        let itemsInLastSection = self.collectionView?.numberOfItemsInSection(numberOfSections - 1) ?? 0
        if itemsInLastSection == 0 {
            return CGSizeZero
        }
        
        let attributesForLastSection = self.layoutAttributesForItemAtIndexPath(NSIndexPath(forItem: itemsInLastSection - 1, inSection: numberOfSections - 1))
        let startsAtZero = CGRectUnion(attributesForLastSection.frame, CGRectZero)
        
        var collectionViewFrame = self.collectionView?.frame ?? CGRectZero
        collectionViewFrame.size = CGSize(width: collectionViewFrame.width, height: CGFloat.max)
        let noWiderThanCollectionView = CGRectIntersection(startsAtZero, collectionViewFrame)
        
        return noWiderThanCollectionView.size
    }

    // MARK: Offset Calculation

    private func totalOffset(forSection section: Int) -> CGFloat {
        let cumulativeOffset = self.cumulativeOffsets[section] ?? 0
        let panOffset = self.currentPanOffsets[section] ?? 0

        return cumulativeOffset + panOffset
    }
    
    // MARK: Section and Item/Row Calculation
    
    /**
    Find the section number corresponding to a Y-coordinate in the collection view.
    May be greater than the actual number of sections in the collection view.
    */
    private func section(forYCoordinate coordinate: CGFloat) -> Int {
        let size = self.itemSize
        let lineSpacing = self.minimumLineSpacing
        let headerSize = self.headerReferenceSize
        
        let sectionHeight = self.sectionHeight
        let sectionForCoordinate = Int(floor(coordinate / sectionHeight))
        
        return sectionForCoordinate
    }

    /**
    Get the item number that should appear at the specified coordinate.
    :param: forXCoordinate The X coordinate for which to get the item
    */
    private func itemNumber(forXCoordinate coordinate: CGFloat, inSection section: Int) -> Int {
        let size = self.itemSize
        let itemWidth = size.width
        let layoutWidth = self.collectionView!.frame.width
        let cellSpacing = self.minimumInteritemSpacing
        let widthPlusPaddingPerCell = itemWidth + cellSpacing

        let itemForCoordinate = Int(floor(coordinate / widthPlusPaddingPerCell))

        return itemForCoordinate
    }

    /**
    Get the index paths corresponding to all items in a section that are currently
    or are close to being displayed, e.g. the items that are just outside of the frame.
    */
    private func indexPathsCurrentlyDisplayed(inSection section: Int) -> [NSIndexPath] {
        let xOffset = self.totalOffset(forSection: section)
        let minXCoordinate = -xOffset
        let itemWidth = self.itemSize.width
        let collectionViewWidth = self.collectionView!.frame.width
        let firstDisplayedItem = self.itemNumber(forXCoordinate: minXCoordinate, inSection: section)
        let lastDisplayedItem = self.itemNumber(forXCoordinate: minXCoordinate + collectionViewWidth + itemWidth, inSection: section)
        let lastItemInSection = self.collectionView!.numberOfItemsInSection(section)

        let firstItem = max(firstDisplayedItem - 1, 0)
        let lastItem = max(min(lastDisplayedItem + 1, lastItemInSection), firstItem)

        let paths = (firstItem...lastItem).map { (itemNumber: Int) -> NSIndexPath in
            return NSIndexPath(forItem: itemNumber, inSection: section)
        }

        return paths
    }

    private func width(ofSection sectionNumber: Int) -> CGFloat {
        let itemsInSection = self.collectionView!.numberOfItemsInSection(sectionNumber)
        let attributesForLastItemInSection = self.layoutAttributesForItemAtIndexPath(NSIndexPath(forItem: itemsInSection - 1, inSection: sectionNumber))
        return attributesForLastItemInSection.frame.maxX
    }

    // MARK: Dynamics

    private func addSpringsAsNecessary(toDynamicItem sectionDynamicItem: SectionDynamicItem, forOffset offset: CGFloat, inSection sectionNumber: Int) {
        if (offset > 0) {
            if let behavior = self.springsForFirstItems[sectionNumber] {
                // empty
            } else {
                let springBehavior = UISnapBehavior(item: sectionDynamicItem, snapToPoint: CGPoint(x: 0, y: sectionDynamicItem.center.y))!
                springBehavior.damping = 0.75
                self.springsForFirstItems[sectionNumber] = springBehavior
                self.dynamicAnimator.addBehavior(springBehavior)
            }
        }

        let collectionView = self.collectionView!
        let widthOfSection = self.width(ofSection: sectionNumber)
        if (offset < -widthOfSection) {
            if let behavior = self.springsForLastItems[sectionNumber] {
                // empty
            } else {
                let springBehavior = UISnapBehavior(item: sectionDynamicItem, snapToPoint: CGPoint(x: collectionView.frame.width, y: sectionDynamicItem.center.y))!
                springBehavior.damping = 0.75
                self.springsForLastItems[sectionNumber] = springBehavior
                self.dynamicAnimator.addBehavior(springBehavior)
            }
        }
    }

    private func dynamicItem(forSection sectionNumber: Int) -> SectionDynamicItem {
        if let sectionItem = self.sectionDynamicItems[sectionNumber] {
            return sectionItem
        } else {
            let sectionItem = SectionDynamicItem(sectionNumber: sectionNumber)
            return sectionItem
        }
    }

    // MARK: Pan Gesture Action

    /**
    Receive a pan gesture to pan the items in a row. The pan must take place within our collection view's frame.
    */
    @IBAction func pan(recognizer: UIPanGestureRecognizer) {
        let collectionView = self.collectionView!
        let collectionViewLocation = recognizer.locationInView(collectionView)
        
        let sectionOfPan = self.section(forYCoordinate: collectionViewLocation.y)
        let translation = recognizer.translationInView(collectionView)

        // Update the amount of panning done
        let currentPanOffset = translation.x
        self.currentPanOffsets[sectionOfPan] = currentPanOffset

        let indexPaths = self.indexPathsCurrentlyDisplayed(inSection: sectionOfPan)
        let context = UICollectionViewFlowLayoutInvalidationContext()
        context.invalidateItemsAtIndexPaths(indexPaths)
        self.invalidateLayoutWithContext(context)

        let newCumulativeOffset = self.totalOffset(forSection: sectionOfPan)

        let sectionDynamicItem = self.dynamicItem(forSection: sectionOfPan)
        sectionDynamicItem.center = CGPoint(x: newCumulativeOffset, y: 0)
        self.sectionDynamicItems[sectionOfPan] = sectionDynamicItem

        if recognizer.state == .Ended {
            self.cumulativeOffsets[sectionOfPan] = newCumulativeOffset
            self.currentPanOffsets[sectionOfPan] = nil

            let velocity = recognizer.velocityInView(self.collectionView)

            sectionDynamicItem.delegate = self
            let items = [sectionDynamicItem]
            let behavior = UIPushBehavior(items: items, mode: .Instantaneous)
            behavior.pushDirection = CGVector(dx: velocity.x > 0 ? 1 : -1, dy: 0)
            behavior.magnitude = abs(velocity.x)

            let resistance = UIDynamicItemBehavior(items: items)
            resistance.resistance = 1

            self.dynamicAnimator.addBehavior(behavior)
            self.dynamicAnimator.addBehavior(resistance)
            self.sectionDynamicBehaviors[sectionOfPan] = [behavior, resistance]
        } else {
            if let behaviors = self.sectionDynamicBehaviors.removeValueForKey(sectionOfPan) {
                for behavior in behaviors {
                    self.dynamicAnimator.removeBehavior(behavior)
                }
            }

            if let snapbehavior = self.springsForFirstItems.removeValueForKey(sectionOfPan) {
                self.dynamicAnimator.removeBehavior(snapbehavior)
            }
            if let snapbehavior = self.springsForLastItems.removeValueForKey(sectionOfPan) {
                self.dynamicAnimator.removeBehavior(snapbehavior)
            }

            sectionDynamicItem.delegate = nil
            self.addSpringsAsNecessary(toDynamicItem: sectionDynamicItem, forOffset: newCumulativeOffset, inSection: sectionOfPan)
        }
    }
}

extension FilmstripsFlowLayout: SectionDynamicItemDelegate {
    private func itemDidMove(sectionDynamicItem: SectionDynamicItem) {
        let newCenter = sectionDynamicItem.center
        let sectionNumber = sectionDynamicItem.sectionNumber
        let cumulativeOffset = (self.currentPanOffsets[sectionNumber] ?? 0) + newCenter.x
        self.cumulativeOffsets[sectionNumber] = cumulativeOffset

        self.addSpringsAsNecessary(toDynamicItem: sectionDynamicItem, forOffset: cumulativeOffset, inSection: sectionNumber)

        let indexPaths = self.indexPathsCurrentlyDisplayed(inSection: sectionNumber)

        let context = UICollectionViewFlowLayoutInvalidationContext()
        context.invalidateItemsAtIndexPaths(indexPaths)
        self.invalidateLayoutWithContext(context)
    }
}

private protocol SectionDynamicItemDelegate: NSObjectProtocol {
    func itemDidMove(sectionDynamicItem: SectionDynamicItem)
}

/**
Placeholder dynamic item whose sole purpose is to keep track of the scroll offset for a given section.
*/
private class SectionDynamicItem: NSObject, UIDynamicItem {
    /// The location and size of the item. 1000x1000 is the size to get 1 pt/s^2 acceleration for
    /// a magnitude 1 push behavior.
    var bounds: CGRect = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 1000, height: 1000))
    var center: CGPoint = CGPointZero {
        didSet {
            self.delegate?.itemDidMove(self)
        }
    }
    var transform: CGAffineTransform = CGAffineTransformIdentity
    
    let sectionNumber: Int
    weak var delegate: SectionDynamicItemDelegate?
    
    init(sectionNumber: Int) {
        self.sectionNumber = sectionNumber
        super.init()
    }
}