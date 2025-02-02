//
//  BattlegroundsQuestPickingViewModel.swift
//  HSTracker
//
//  Created by Francisco Moraes on 12/6/22.
//  Copyright © 2022 Benjamin Michotte. All rights reserved.
//

import Foundation
import PromiseKit

class BattlegroundsQuestPickingViewModel: ViewModel {
    private var _entities = SynchronizedArray<Entity>()
    
    var quests: [BattlegroundsSingleQuestViewModel]? {
        get {
            return getProp(nil)
        }
        set {
            setProp(newValue)
        }
    }
    
    var visibility: Bool {
        get {
            if !Settings.showBattlegroundsQuestPicking {
                return false
            }
            return getProp(false)
        }
        set {
            setProp(newValue)
        }
    }
    
    var scaling: Double {
        get {
            return getProp(1.0)
        }
        set {
            setProp(newValue)
        }
    }
    
    let message = OverlayMessageViewModel()
    
    private func expectedQuestCount() -> Int? {
        switch AppDelegate.instance().coreManager.game.turnNumber() {
        case 1: return 2
        case 4: return 3
        default: return nil
        }
    }

    @available(macOS 10.15.0, *)
    func onBattlegroundsQuest(questEntity: Entity) async {
        logger.debug("Quest: \(questEntity)")
        guard let copy = questEntity.copy() as? Entity else {
            return
        }
        _entities.append(copy)
        if _entities.count == expectedQuestCount() {
            await update()
        }
    }
    
    func reset() {
        _entities.removeAll()
        quests = nil
        visibility = false
        _watchChoices = false
        message.clear()
    }
    
    @available(macOS 10.15.0, *)
    func update() async {
        if !Settings.enableTier7Overlay {
            return
        }
        if AppDelegate.instance().coreManager.game.spectator {
            return
        }
        if quests != nil {
            return
        }
        let userOwnsTier7 = HSReplayAPI.accountData?.is_tier7 ?? false
        
        // The trial would have been activated at hero picking. If it is
        // not active we do not try to activate it here.
        if !userOwnsTier7 && !Tier7Trial.isActive {
            return
        }
        
        logger.debug("Expected entities: \(expectedQuestCount() ?? -1), got \(_entities.count)")
        if _entities.count != expectedQuestCount() {
            return
        }
        message.loading()
        
        // delay to allow tag changes to update
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
        } catch {
            logger.error(error)
        }
        
        guard let requestParams = getApiParams() else {
            message.error()
            return
        }
        
        guard let questData = await HSReplayAPI.getTier7QuestStats(parameters: requestParams) else {
            message.error()
            return
        }

        guard let choices = MirrorHelper.getCardChoices() else {
            self.message.error()
            return
        }

        let orderedEntries = choices.cards.compactMap { id in
            self._entities.first(where: { x in x.cardId == id })
        }

        self.quests = orderedEntries.compactMap { quest in
            let reward = quest[.quest_reward_database_id]
            let data = questData.first { x in x.reward_dbf_id == reward }
            if let card = Cards.by(dbfId: reward, collectible: false) {
                logger.debug("QUEST reward: \(card.name)")
            }
            
            return BattlegroundsSingleQuestViewModel(stats: data)
        }
        
        message.mmr(filterValue: questData[0].mmr_filter_value, minMMR: questData[0].min_mmr)
        if choices.isVisible {
            visibility = true
        }
        
        Task.init {
            await watchChoices()
        }
    }
    
    private var _watchChoices = false
    
    @available(macOS 10.15, *)
    private func watchChoices() async {
        _watchChoices = true
        while _watchChoices {
            do {
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                logger.error(error)
            }
            guard let choices = MirrorHelper.getCardChoices() else {
                _watchChoices = false
                visibility = false
                break
            }
            visibility = choices.isVisible
        }
    }
    
    private func getApiParams() -> BattlegroundsQuestStatsParams? {
        let game = AppDelegate.instance().coreManager.game
        guard let hero = game.entities.values.first(where: { x in x.isPlayer(eventHandler: game) && x.isHero }) else {
            return nil
        }
        let heroCardId = BattlegroundsUtils.getOriginalHeroId(heroId: hero.cardId)
        guard let heroCard = Cards.by(cardId: heroCardId) else {
            return nil
        }
        guard let availableRaces = game.availableRaces else {
            return nil
        }
        
        return BattlegroundsQuestStatsParams(hero_dbf_id: heroCard.dbfId, hero_power_dbf_ids: game.player.pastHeroPowers.compactMap({ x in Cards.any(byId: x)?.dbfId }), turn: game.turnNumber(), minion_types: availableRaces.compactMap { x in Int(Race.allCases.firstIndex(of: x)!) }, offered_rewards: getOfferedRewards(), game_language: "\(Settings.hearthstoneLanguage ?? .enUS)")
    }
    
    private func getOfferedRewards() -> [BattlegroundsQuestStatsParams.OfferedReward] {
        var result = [BattlegroundsQuestStatsParams.OfferedReward]()
        let quests = _entities.array()
        for quest in quests {
            if !quest.hasCardId {
                continue
            }
            let rewardCardDbfId = quest[.bacon_card_dbid_reward]
            let optRewardCardDbfId: Int? = rewardCardDbfId != 0 ? rewardCardDbfId : nil
            
            result.append(BattlegroundsQuestStatsParams.OfferedReward(reward_dbf_id: quest[.quest_reward_database_id], reward_card_dbf_id: optRewardCardDbfId))
        }
        return result
    }
}
