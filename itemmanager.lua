---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local utils = require('TSC.utils')

---@class ItemManager
local ItemManager = {
    combinedItems = {},
    lists = {
        tograb = {}, -- Bank and depot
        toplotgrab = {},
        totrade = {},
        tobank = {}, -- Including bankrestack
        todepot = {},
        tomovedepot = {}, -- Bank to depot
        tomoveplot = {}, -- Plot to plot
        toplot = {},
        todump = {},
    },
}

function ItemManager:clearLists()
    self.lists = {
        tograb = {},
        toplotgrab = {},
        totrade = {},
        tobank = {},
        todepot = {},
        tomovedepot = {},
        tomoveplot = {},
        toplot = {},
        todump = {},
    }
end

function ItemManager:createLists()
    for toon, items in pairs(self.combinedItems) do
        for itemName, itemData in pairs(items) do
            if itemData.destination:find('skip') or itemData.destination:find('ignored') or itemData.destination:find('pgnored') then
                -- Skip items that are marked to skip
            elseif itemData.destination:match('^[A-Z]') and not itemData.destination:find(',') then
                self.lists.totrade[toon] = self.lists.totrade[toon] or {}
                self.lists.totrade[toon][itemName] = itemData.destination
                if self.combinedItems[toon][itemName].depot > 0 or utils.tableLength(self.combinedItems[toon][itemName].bank) > 0 then
                    self.lists.tograb[toon] = self.lists.tograb[toon] or {}
                    self.lists.tograb[toon][itemName] = true
                end
                if utils.tableLength(self.combinedItems[toon][itemName].plots) > 0 then
                    self.lists.toplotgrab[toon] = self.lists.toplotgrab[toon] or {}
                    self.lists.toplotgrab[toon][itemName] = true
                end
            elseif itemData.destination:find(',') then
                self.lists.toplot[toon] = self.lists.toplot[toon] or {}
                self.lists.toplot[toon][itemName] = itemData.destination
                if self.combinedItems[toon][itemName].depot > 0 or utils.tableLength(self.combinedItems[toon][itemName].bank) > 0 then
                    self.lists.tograb[toon] = self.lists.tograb[toon] or {}
                    self.lists.tograb[toon][itemName] = true
                end
                if utils.tableLength(self.combinedItems[toon][itemName].plots) > 1 then
                    self.lists.tomoveplot[toon] = self.lists.tomoveplot[toon] or {}
                    self.lists.tomoveplot[toon][itemName] = true
                end
            elseif itemData.destination == 'bankrestack' or itemData.destination == 'bank' then
                self.lists.tobank[toon] = self.lists.tobank[toon] or {}
                self.lists.tobank[toon][itemName] = true
                if itemData.destination == 'bankrestack' then
                    self.lists.tograb[toon] = self.lists.tograb[toon] or {}
                    self.lists.tograb[toon][itemName] = 'bankrestack'
                end
                if utils.tableLength(self.combinedItems[toon][itemName].plots) > 0 then
                    self.lists.toplotgrab[toon] = self.lists.toplotgrab[toon] or {}
                    self.lists.toplotgrab[toon][itemName] = true
                end
            elseif itemData.destination == 'depot' then
                self.lists.todepot[toon] = self.lists.todepot[toon] or {}
                self.lists.todepot[toon][itemName] = true
                if utils.tableLength(self.combinedItems[toon][itemName].plots) > 0 then
                    self.lists.toplotgrab[toon] = self.lists.toplotgrab[toon] or {}
                    self.lists.toplotgrab[toon][itemName] = true
                end
                if utils.tableLength(self.combinedItems[toon][itemName].bank) > 0 then
                    self.lists.tomovedepot[toon] = self.lists.tomovedepot[toon] or {}
                    self.lists.tomovedepot[toon][itemName] = itemData.destination
                end
            elseif itemData.destination == 'leftovers' then
                self.lists.todump[toon] = self.lists.todump[toon] or {}
                self.lists.todump[toon][itemName] = true
            end
        end
    end
    cm.saveData('lists', self.lists)
end


--[[Example of combinedItems table:
['Ruinette'] = {
		['Brick of Black Acrylia'] = {
			['total'] = 110,
			['inventory'] = {},
			['bank'] = {
				['Bank 1-27'] = 110,
			},
			['depot'] = 0,
			['plots'] = {},
			['locations'] = 1,
			['destination'] = 'Fertilia',
		},
		['Bone Chips'] = {
			['total'] = 1404,
			['inventory'] = {
				['General 9-31'] = 1000,
				['General 9-30'] = 404,
			},
			['bank'] = {},
			['depot'] = 0,
			['plots'] = {},
			['locations'] = 2,
			['destination'] = 'leftovers',
		},
]]

-- Gui function to reverse the trade direction of an item
function ItemManager:reverseTradeDirection(itemName, newDestination)
    for toon, items in pairs(self.combinedItems) do
        for name, itemData in pairs(items) do
            if name == itemName then
                -- If the new destination is the current toon, determine where they will store the item
                if toon == newDestination then
                    itemData.destination = self:determineDestination(itemData, itemName)
                else
                    -- Update everyone elses destination to the new toon
                    itemData.destination = newDestination
                end
            end
        end
    end
    -- Update the lists
    self:createLists()
    print('\at[TsC]\ao \ay' .. itemName .. '\ao will now go to \ar' .. utils.fname(newDestination) .. '\ao for this run.')
end

-- Helper function to determine the self-destination for an item
function ItemManager:determineDestination(itemData, itemName)
    if itemData.depot > 0 then
        return 'depot'
    elseif utils.tableLength(itemData.plots) > 0 and (utils.tableLength(itemData.plots) > utils.tableLength(itemData.bank) or cm.settings.preferPlots) then
        local maxPlot = next(itemData.plots)
        for plot, qty in pairs(itemData.plots) do
            if qty > itemData.plots[maxPlot] then
                maxPlot = plot
            end
        end
        return maxPlot
    elseif utils.tableLength(itemData.bank) > 0 then
        if utils.tableLength(itemData.plots) == 0 --[[and utils.tableLength(itemData.inventory) == 0]] then
            local max = mq.TLO.FindItemBank(itemName).StackSize() or 0
            local x = 0
            for _, qty in pairs(itemData.bank) do
                if qty < max then x = x + 1 end
            end
            if utils.tableLength(itemData.inventory) ~= 0 then
                return 'bank'
            elseif x > 1 then
                return 'bankrestack'
            else
                --Multiple stacks already consolidated in bank
            end
        else
            return 'bank'
        end
    else
        return 'leftovers'
    end
end


return ItemManager