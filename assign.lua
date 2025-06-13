---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local im = require('TSC.itemmanager')

local assign = {}

function assign.run(tbl, target)
    im.combinedItems[target] = nil
    for toon in pairs(tbl) do
        local items = cm:loadTmp('items', toon)
        im.combinedItems[toon] = {}
        for itemName, itemData in pairs(items) do
            if cm.hoard[toon][itemName] then
                itemName = nil
            else
                itemData.destination = target
                im.combinedItems[toon][itemName] = itemData
            end
        end
    end
    cm.saveData('combined', im.combinedItems)
end

return assign