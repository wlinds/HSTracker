//
//  OverlayMessageViewModel.swift
//  HSTracker
//
//  Created by Francisco Moraes on 12/7/22.
//  Copyright © 2022 Benjamin Michotte. All rights reserved.
//

import Foundation

class OverlayMessageViewModel: ViewModel {
    
    var text: String? {
        get {
            return getProp(nil)
        }
        set {
            setProp(newValue)
            if newValue == nil {
                visibility = false
            } else {
                visibility = true
            }
        }
    }
    
    var visibility: Bool {
        get {
            return getProp(false)
        }
        set {
            setProp(newValue)
        }
    }
    
    override init() {
    }
    
    func error() {
        DispatchQueue.global().async {
            let errorText = NSLocalizedString("BattlegroundsOverlayMessage_Error", comment: "")
            self.text = errorText
            Thread.sleep(forTimeInterval: 5.0)
            if self.text == errorText {
                self.clear()
            }
        }
    }
    
    func loading() {
        text = NSLocalizedString("BattlegroundsOverlayMessage_Loading", comment: "")
    }
    
    private static let mmrPercentValues: [String: Int] = [
        "TOP_1_PERCENT": 1,
        "TOP_5_PERCENT": 5,
        "TOP_10_PERCENT": 10,
        "TOP_20_PERCENT": 20,
        "TOP_50_PERCENT": 50
    ]
                                         
    func mmr(filterValue: String, minMMR: Int?) {
        if let percent = OverlayMessageViewModel.mmrPercentValues[filterValue] {
            let mmr = Helper.toPrettyNumber(n: minMMR ?? 0)
            let format = NSLocalizedString("BattlegroundsOverlayMessage_MMR", comment: "")
            text = String(format: format, percent, mmr)
        } else {
            clear()
        }
    }

    func clear() {
        text = nil
    }
}
