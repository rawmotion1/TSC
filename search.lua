---@type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')
local im = require('TSC.itemmanager')

--- @class Search
local search = {
    results = {}
}

function search.run(tbl)

    -- Load all toons' items into combinedItems
    for toon in pairs(tbl) do
        local items = cm:loadTmp('items', toon)
        im.combinedItems[toon] = {}
        for itemName, itemData in pairs(items) do
            im.combinedItems[toon][itemName] = itemData
        end
    end
    cm.saveData('combined', im.combinedItems)

    -- Create an indexed list of items
    search.results = {}
    for toon,items in pairs(im.combinedItems) do
        for item,details in pairs(items) do
            local exists = false
            for _,v in pairs(search.results) do
                if v['item'] == item then
                    exists = true
                    v[toon] = details
                end
            end
            if exists == false then
                local x = {
                    ['item'] = item,
                    [toon] = details
                }
                table.insert(search.results, x)
            end
        end
    end
end

return search