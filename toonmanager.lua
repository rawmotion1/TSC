--- @type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')

---@class ToonManager
local toonManager = {
    onlineToons = {},
    onlineMules = {},
    peers = {},
    availableToons = {},
    availableMules = {},
    offlineToons = {},
    offlineMules = {},
    previousPeers = {},
}

--Included in the main loop to keep track toon status and inventories
function toonManager:runPeriodicTasks()
    self:checkStatus()
    self:getPeers()
    self:createLists()
end

--Set observers for all toons and mules on initialization
function toonManager.setObservers()
    for k,_ in pairs(cm.toons) do
        mq.cmdf('/dobserve %s -q Me.FreeInventory', k)
        mq.delay(100)
    end
    for k,_ in pairs(cm.mules) do
        mq.cmdf('/dobserve %s -q Me.FreeInventory', k)
        mq.delay(100)
    end
end

--Create pignore and keep subtables for each toon on initialization
function toonManager.createSubtables()
    for k,_ in pairs(cm.toons) do
        if not cm.pignore[k] then
            cm.pignore[k] = {}
        end
        if not cm.hoard[k] then
            cm.hoard[k] = {}
        end
    end
    cm:save('pignore')
    cm:save('hoard')
end

--Checks online status and free inventory
function toonManager:checkStatus()
    for k,_ in pairs(cm.toons) do
        if mq.TLO.Spawn('PC ='..k)() then
            self.onlineToons[k] = tonumber(mq.TLO.DanNet(k).O('Me.FreeInventory')()) or 0
        else
            self.onlineToons[k] = nil
        end
    end

    for k,_ in pairs(cm.mules) do
        if mq.TLO.Spawn('PC ='..k)() then
            self.onlineMules[k] = tonumber(mq.TLO.DanNet(k).O('Me.FreeInventory')()) or 0
        else
            self.onlineMules[k] = nil
        end
    end
end

--Get all dannet peers
function toonManager:getPeers()
    local currentPeers = {}
    local peersString = mq.TLO.DanNet.Peers() or ""

    -- Parse the current peers from the DanNet.Peers() string
    for peer in peersString:gmatch("([^|]+)|") do
        peer = (peer:gsub("^%l", string.upper))
        currentPeers[peer] = true
        if not self.peers[peer] then
            self.peers[peer] = true
            --print('\at[TsC]\ao \ay' .. peer .. '\ao has joined the network.')
        end
    end

    -- Remove peers that are no longer online
    for peer in pairs(self.peers) do
        if not currentPeers[peer] then
            self.peers[peer] = nil
            --print('\at[TsC]\ao \ay' .. peer .. '\ao has left the network.')
        end
    end
end

--Create lists for adding toons and mules via dropdown
function toonManager:createLists()
    -- Check if peers have changed
    local peersChanged = false
    local currentPeers = {}

    -- Build a snapshot of the current peers
    for peer, _ in pairs(self.peers) do
        currentPeers[peer] = true
        if not self.previousPeers or not self.previousPeers[peer] then
            peersChanged = true
        end
    end

    -- Check for removed peers
    if self.previousPeers then
        for peer, _ in pairs(self.previousPeers) do
            if not currentPeers[peer] then
                peersChanged = true
                break
            end
        end
    end

    -- If peers have changed, recreate the lists
    if peersChanged then
        self.availableToons = {}
        self.availableMules = {}
        self.offlineToons = {}
        self.offlineMules = {}

        for peer, _ in pairs(self.peers) do
            if not cm.toons[peer] then
                self.availableToons[peer] = true
            end
            if not cm.mules[peer] then
                self.availableMules[peer] = true
            end
        end

        for toon, _ in pairs(cm.toons) do
            if not self.onlineToons[toon] then
                self.offlineToons[toon] = true
            end
        end

        for mule, _ in pairs(cm.mules) do
            if not self.onlineMules[mule] then
                self.offlineMules[mule] = true
            end
        end

        -- Update the snapshot of peers
        self.previousPeers = currentPeers
    end
end

--Add a toon to the list and set an observer for their inventory
function toonManager:addToon(name)
    if not cm.toons[name] then
        cm.toons[name] = {['mode'] = 'Default', ['leftovers'] = 'Off'}
        self.availableToons[name] = nil
        cm:save('toons')

        cm.pignore[name] = {}
        cm:save('pignore')

        cm.hoard[name] = {}
        cm:save('hoard')

        mq.cmdf('/dobserve %s -q Me.FreeInventory', name)

        print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao has been added to the toon list.')
    else
        print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao is already in the toon list.')
    end
end

--Add ALL toons to the list and set observers for their inventories
function toonManager:addAllToons()
    for k,_ in pairs(self.peers) do
        if not cm.toons[k] then
            cm.toons[k] = {['mode'] = 'Default', ['leftovers'] = 'Off'}
            self.availableToons[k] = nil
            cm.pignore[k] = {}
            cm.hoard[k] = {}
            mq.cmdf('/dobserve %s -q Me.FreeInventory', k)
            print('\at[TsC]\ao \ar'..toonManager.fname(k)..'\ao has been added to the toon list.')
        else
            print('\at[TsC]\ao \ar'..toonManager.fname(k)..'\ao is already in the toon list.')
        end
    end
    cm:save('toons')
    cm:save('pignore')
    cm:save('hoard')
    print('\at[TsC]\ao All toons have been added to the list.')
end

--Remove a toon from the list
function toonManager:removeToon(name)
    self.onlineToons[name] = nil
    cm.toons[name] = nil
    self.availableToons[name] = true
    cm:save('toons')

    cm.pignore[name] = nil
    cm:save('pignore')

    cm.hoard[name] = nil
    cm:save('hoard')

    print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao has been removed from the toon list.')

end

--Add a mule to the list and set an observer for their inventory
function toonManager:addMule(name)
    if not cm.mules[name] then
        local order = toonManager.tableLength(cm.mules) + 1
        cm.mules[name] = order
        self.availableMules[name] = nil
        cm:save('mules')
        mq.cmdf('/dobserve %s -q Me.FreeInventory', name)
        print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao has been added to the mule list.')
    else
        print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao is already in the mule list.')
    end
end

--Remove a mule from the list
function toonManager:removeMule(name)
    self.onlineMules[name] = nil
    cm.mules[name] = nil
    cm.mules = toonManager.reindexTableByValue(cm.mules)
    self.availableMules[name] = true
    cm:save('mules')
    print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao has been removed from the mule list.')
end

--Move a mule down in the priority list
function toonManager.moveMuleUp(name)
    if cm.mules[name] and cm.mules[name] > 1 then
        local currentIndex = cm.mules[name]
        local newIndex = currentIndex - 1

        -- Find the mule currently at the new index and increment its value
        for mule, index in pairs(cm.mules) do
            if index == newIndex then
                cm.mules[mule] = currentIndex
                break
            end
        end

        cm.mules[name] = newIndex
        cm.mules = toonManager.reindexTableByValue(cm.mules)
        cm:save('mules')
        print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao has been moved up in the mule list.')
    end
end

function toonManager.moveMuleDown(name)
    if cm.mules[name] and cm.mules[name] < toonManager.tableLength(cm.mules) then
        local currentIndex = cm.mules[name]
        local newIndex = currentIndex + 1

        -- Find the mule currently at the new index and decrement its value
        for mule, index in pairs(cm.mules) do
            if index == newIndex then
                cm.mules[mule] = currentIndex
                break
            end
        end

        cm.mules[name] = newIndex
        cm.mules = toonManager.reindexTableByValue(cm.mules)
        cm:save('mules')
        print('\at[TsC]\ao \ar'..toonManager.fname(name)..'\ao has been moved down in the mule list.')
    end
end

--Alphabetize toons table
function toonManager.alphabetizeTableByKey(inputTable)
    local sortedKeys = {}
    for key in pairs(inputTable) do
        table.insert(sortedKeys, key)
    end
    table.sort(sortedKeys)
    return sortedKeys
end

--Ensure mules table is diplayed in order of priority
function toonManager.orderMulesTable(inputTable)
    local sortedKeys = {}
    for name in pairs(inputTable) do
        table.insert(sortedKeys, name)
    end

    table.sort(sortedKeys, function(a, b)
        return inputTable[a] < inputTable[b] -- Sort by value (ascending)
    end)
    return sortedKeys
end

--Keep order values sequential starting from 1 for mules table
function toonManager.reindexTableByValue(inputTable)
    -- Extract keys and sort them by their corresponding values
    local sortedKeys = {}
    for key in pairs(inputTable) do
        table.insert(sortedKeys, key)
    end
    table.sort(sortedKeys, function(a, b)
        return inputTable[a] < inputTable[b] -- Sort by value (ascending)
    end)

    -- Reindex the table so that values are sequential starting from 1
    local reindexedTable = {}
    for newIndex, key in ipairs(sortedKeys) do
        reindexedTable[key] = newIndex
    end

    return reindexedTable
end

function toonManager.tableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function toonManager.fname(name)
    return name --mq.TLO.NearestSpawn(name).Class()
end

return toonManager