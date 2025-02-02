//
//  HeroPicking.swift
//  HSTracker
//
//  Created by Francisco Moraes on 12/4/22.
//  Copyright © 2022 Benjamin Michotte. All rights reserved.
//

import Foundation

class BattlegroundsHeroPickingViewModel: ViewModel {
    var visibility: Bool {
        get {
            if !Settings.showBattlegroundsHeroPicking {
                return false
            }
            return getProp(false)
        }
        set {
            setProp(newValue)
        }
    }
    
    var heroStats: [BattlegroundsSingleHeroViewModel]? {
        get {
            return getProp(nil)
        }
        set {
            setProp(newValue)
        }
    }
    
    let message = OverlayMessageViewModel()
    
    func reset() {
        heroStats = nil
        visibility = false
        message.clear()
    }
    
    var scaling: Double {
        get {
            return getProp(1.0)
        }
        set {
            setProp(newValue)
        }
    }
    
    var selectedHeroDbfId: Int {
        get {
            getProp(0)
        }
        set {
            setProp(newValue)
            guard let heroStats else {
                return
            }
            let selectedHeroIndex = heroStats.firstIndex { x in x.heroDbfId == newValue }
            
            if let selectedHeroIndex {
                let direction = (selectedHeroIndex >= heroStats.count / 2) ? -1 : 1
                for i in 0 ..< heroStats.count {
                    heroStats[i].setHiddenByHeroPower(i == selectedHeroIndex + direction)
                }
            } else {
                for i in 0 ..< heroStats.count {
                    heroStats[i].setHiddenByHeroPower(false)
                }
            }
        }
    }
    
    var statsText: String? {
        get {
            return getProp("")
        }
        set {
            setProp(newValue)
        }
    }
    
    @available(macOS 10.15.0, *)
    func setHeroes(heroIds: [Int]) async {
        if !Settings.enableTier7Overlay {
            return
        }
        let game = AppDelegate.instance().coreManager.game
        
        // Trials not supported for now.
        if game.spectator {
            return
        }
        // No Trials for anonymous users
        if !HSReplayAPI.isFullyAuthenticated {
            return
        }
        let userOwnsTier7 = HSReplayAPI.accountData?.is_tier7 ?? false
        
        if !userOwnsTier7 && (Tier7Trial.remainingTrials ?? 0) == 0 {
            return
        }
        
        message.loading()
        
        // Avoid using a trial when we can't get the api params anyway.
        guard let requestParams = getApiParams(game: game, heroIds: heroIds) else {
            message.error()
            return
        }
        if !userOwnsTier7 {
            let trialActive = await Tier7Trial.activate()
            if !trialActive {
                message.error()
                return
            }
        }
        
        // At this point the user either owns tier7 or has an active trial!
        guard let stats = await HSReplayAPI.getTier7HeroPickStats(parameters: requestParams) else {
            message.error()
            return
        }
        
        heroStats = heroIds.compactMap { x in
            let heroStats = stats.first { heroData in heroData.hero_dbf_id == x }
            if let heroStats {
                return BattlegroundsSingleHeroViewModel(stats: heroStats, onPlacementHover: setPlacementVisible)
            }
            return nil
        }
        message.mmr(filterValue: stats[0].mmr_filter_value, minMMR: stats[0].min_mmr)
        visibility = true
    }
    
    func setPlacementVisible(_ isVisible: Bool) {
        guard let heroStats else {
            return
        }
        let visibility = isVisible
        for hero in heroStats {
            hero.bgsHeroHeaderVM.placementDistributionVisibility = visibility
        }
    }
    
    private func getApiParams(game: Game, heroIds: [Int]) -> BattlegroundsHeroPickStatsParams? {
        guard let availableRaces = game.availableRaces else {
            return nil
        }
        
        return BattlegroundsHeroPickStatsParams(hero_dbf_ids: heroIds, minion_types: availableRaces.compactMap { x in Int(Race.allCases.firstIndex(of: x)!) }, game_language: "\(Settings.hearthstoneLanguage ?? .enUS)")

    }
}
