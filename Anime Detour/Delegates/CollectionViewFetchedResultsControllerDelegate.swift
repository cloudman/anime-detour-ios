//
//  CollectionViewFetchedResultsControllerDelegate.swift
//  Anime Detour
//
//  Created by Brendon Justin on 1/11/15.
//  Copyright (c) 2015 Anime Detour. All rights reserved.
//

import UIKit
import CoreData

class CollectionViewFetchedResultsControllerDelegate: NSObject, NSFetchedResultsControllerDelegate {
    private enum FetchedResultsControllerChange {
        case Object(anObject: AnyObject, indexPath: NSIndexPath?, type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?)
        case Section(sectionInfo: NSFetchedResultsSectionInfo, sectionIndex: Int, type: NSFetchedResultsChangeType)
    }

    var collectionView: UICollectionView?
    private var sectionsChangedDuringUpdate: Bool = false
    private var cumulativeChanges: [FetchedResultsControllerChange] = []

    // MARK: Fetched Results Controller Delegate

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.cumulativeChanges.removeAll(keepCapacity: false)
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        if let cv = self.collectionView {
            cv.performBatchUpdates({ () -> Void in
                for change in self.cumulativeChanges {
                    switch change {
                    case let .Object(anObject, indexPath, type, newIndexPath):
                        switch type {
                        case .Insert:
                            cv.insertItemsAtIndexPaths([newIndexPath!])
                        case .Delete:
                            cv.deleteItemsAtIndexPaths([indexPath!])
                        case .Move:
                            if self.sectionsChangedDuringUpdate {
                                cv.deleteItemsAtIndexPaths([indexPath!])
                                cv.insertItemsAtIndexPaths([newIndexPath!])

                                self.sectionsChangedDuringUpdate = false
                            } else {
                                cv.moveItemAtIndexPath(indexPath!, toIndexPath: newIndexPath!)
                            }
                        case .Update:
                            cv.reloadItemsAtIndexPaths([indexPath!])
                        }
                    case let .Section(sectionInfo, sectionIndex, type):
                        let indexSet = NSIndexSet(index: sectionIndex)
                        switch type {
                        case .Insert:
                            cv.insertSections(indexSet)
                        case .Delete:
                            cv.deleteSections(indexSet)
                        default:
                            assertionFailure("Unexpected fetched results controller section change type: \(type)")
                        }

                        self.sectionsChangedDuringUpdate = true
                    }
                }
                }, completion: nil)
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        self.cumulativeChanges.append(.Section(sectionInfo: sectionInfo, sectionIndex: sectionIndex, type: type))

    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        self.cumulativeChanges.append(.Object(anObject: anObject, indexPath: indexPath, type: type, newIndexPath: newIndexPath))
    }
}