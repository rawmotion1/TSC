---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local im = require('TSC.itemmanager')
local sm = require('TSC.statemanager')
local utils = require('TSC.utils')


---@class Compare
local compare = {}

-- Helper function to initialize an item in combinedItems
local function initializeItem(toon, itemName)
    if not im.combinedItems[toon] then
        im.combinedItems[toon] = {}
    end
    if not im.combinedItems[toon][itemName] then
        im.combinedItems[toon][itemName] = {total = 0, inventory = {['general'] = 1}, bank = {}, depot = 0, plots = {}, locations = 1, destination = ''}
    elseif utils.tableLength(im.combinedItems[toon][itemName].inventory) == 0 then
        im.combinedItems[toon][itemName].inventory['general'] = 1
        im.combinedItems[toon][itemName].locations = im.combinedItems[toon][itemName].locations + 1
    end
end

function compare.run(tbl, clean)

    local totalItems = 0
    for toon in pairs(tbl) do
        totalItems = totalItems + sm.stats[toon]['beforeItems']
    end
    print('\at[TsC]\ao Comparing \ay '..totalItems..' \ao items across \ay '..utils.tableLength(tbl)..' \ao toons...')

    local quantityTable = {}

    -- Combine all item tables into one table
    for toon in pairs(tbl) do
        local items = cm:loadTmp('items', toon)
        im.combinedItems[toon] = {}
        for itemName, itemData in pairs(items) do
            im.combinedItems[toon][itemName] = itemData

            -- Create a table of all items and their quantities for comparison later
            quantityTable[itemName] = quantityTable[itemName] or {}
            quantityTable[itemName][toon] = itemData.total
        end
    end

    if clean then goto continue end

    -- Find winner for each item based on qty and mode
    for item, names in pairs(quantityTable) do
        -- Check if the item is on someone's hoard list
        local hoarder = nil
        for toon, list in pairs(cm.hoard) do
            if list[item] then
                hoarder = toon
                break
            end
        end
        if utils.tableLength(names) > 1 or hoarder then
            local owners, depotOwners, greedyToons, generousToons, nonGenerousToons = {}, {}, {}, {}, {}

            -- Categorize toons based on their mode and check depot
            for toon, qty in pairs(names) do
                local mode = cm.toons[toon].mode or 'Default'
                table.insert(owners, {name = toon, qty = qty, mode = mode})
                if im.combinedItems[toon][item].depot > 0 then
                    table.insert(depotOwners, {name = toon, qty = qty, mode = mode})
                end
                if mode == 'Greedy' then
                    table.insert(greedyToons, {name = toon, qty = qty})
                elseif mode == 'Generous' then
                    table.insert(generousToons, {name = toon, qty = qty})
                else
                    table.insert(nonGenerousToons, {name = toon, qty = qty})
                end
            end

            -- Determine the winner
            local winner, reason
            if hoarder then
                winner = hoarder
                reason = "it's on their hoard list"
            elseif #greedyToons > 0 then
                table.sort(greedyToons, function(a, b)
                    return (a.depot or 0) > (b.depot or 0) or a.qty > b.qty
                end)
                winner = greedyToons[1].name
                reason = "they are greedy"
            elseif #depotOwners > 0 then
                table.sort(depotOwners, function(a, b) return a.qty > b.qty end)
                winner = depotOwners[1].name
                reason = "they have it in their depot"
            elseif #generousToons == #owners then
                winner = cm.settings.tiebreaker
                reason = "there was a tie"
            elseif #nonGenerousToons > 0 then
                table.sort(nonGenerousToons, function(a, b) return a.qty > b.qty end)
                if nonGenerousToons[1].qty > (nonGenerousToons[2] and nonGenerousToons[2].qty or -1) then
                    winner = nonGenerousToons[1].name
                    reason = "they have the most"
                else
                    winner = cm.settings.tiebreaker
                    reason = "there was a tie"
                end
            else
                table.sort(owners, function(a, b) return a.qty > b.qty end)
                if owners[1].qty > (owners[2] and owners[2].qty or -1) then
                    winner = owners[1].name
                    reason = "they have the most"
                else
                    winner = cm.settings.tiebreaker
                    reason = "there was a tie"
                end
            end

            -- Winner anticipates receiving this item
            if #owners > 1 then
                initializeItem(winner, item)
            end

            -- Set the destination to the winner for all non-winning toons
            for _, owner in pairs(owners) do
                if owner.name ~= winner then
                    im.combinedItems[owner.name][item].destination = winner
                    print(string.format('\at[TsC]\ar %s\'s \ay%s\ao will go to \ar%s\ao because %s.', utils.fname(owner.name), item, utils.fname(winner), reason))
                end
            end
        end
    end

    ::continue::

    -- Self-consolidate items with no destination
    for name, items in pairs(im.combinedItems) do
        for itemName, itemData in pairs(items) do
            if itemData.destination == '' then
                if itemData.locations == 1 and utils.tableLength(itemData.inventory) == 0 then
                    im.combinedItems[name][itemName] = nil --already consolidated.
                else
                    local destination = im:determineDestination(itemData, itemName)
                    itemData.destination = destination
                    if destination == nil then
                        im.combinedItems[name][itemName] = nil --Multiple stack in bank, already consolidated.
                    elseif destination ~= 'leftovers'then
                        print(string.format('\at[TsC]\ar %s\'s\ay %s\ao will go to \ay%s\ao for consolidation.', utils.fname(name), itemName, destination))
                    elseif destination == 'leftovers' and cm.hoard[name][itemName] then
                        itemData.destination = '' --Prevent adding hoard items to leftovers
                    end
                end
            end
        end
    end
    compare.save()
end



-- For testing. Remove later
function compare.save()
    cm.saveData('combined', im.combinedItems)
end

return compare