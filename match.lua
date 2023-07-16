--- @type Mq
local mq = require('mq')

local settingPath = 'TSC/settings.lua'
local toonPath = 'TSC/toons.lua'
local artisanPath = 'TSC/artisan.lua'
local matchesPath = 'TSC/tmp/matches.lua'

local settings = {}
local toons = {}

local artList = {}
local isArtisan = false
local artisan

local matchCount = 0

local function loadFiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        print('\at[TsC]\ao Error loading settings.lua')
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    local loadToons, toonError = loadfile(mq.configDir..'/'..toonPath)
    if toonError then
        print('\at[TsC]\ao Error loading toons.lua')
        mq.exit()
    elseif loadToons then
        toons = loadToons()
    end

    local loadArt, artError = loadfile(mq.configDir..'/'..artisanPath)
    if artError then
        --Nothing
    elseif loadArt then
        for _,toon in pairs(toons) do
            if toon.name == settings.artisan then
                isArtisan = true
                artisan = settings.artisan
                artList = loadArt()
            end
        end
    end
end
loadFiles()

local tiebreaker
--Ensure tiebreaker is valid, if not assign first toon in list and in-zone
for k,toon in pairs(toons) do
    if mq.TLO.NearestSpawn('='..toon.name)() then
        if toon.name == settings.tiebreaker then
            tiebreaker = settings.tiebreaker
            break
        else
            tiebreaker = toons[k].name
        end
    end
end


--------Combine all toons' results into a single table--------
local ltoons = 0
local allitems = {}
local function loadAllItems()
    allitems = {}
    for _,toon in pairs(toons) do
        if mq.TLO.NearestSpawn('='..toon.name)() then --Only load results of toons in-zone
            local path = 'TSC/tmp/allitems_'..toon.name..'.lua'
            local table, error = loadfile(mq.configDir..'/'..path)
            if error then
                --nothing
            elseif table then
                allitems[toon.name] = {}
                allitems[toon.name] = table()
                ltoons = ltoons + 1
            end
        end
    end
end
loadAllItems()

local lqtable = 0
local qTable = {} 
if isArtisan == true then --Add artisan itels list to table with "Asrtisan" as an owner
    for _,item in pairs(artList) do
        qTable[item] = {['Artisan'] = 0}
    end
end
---Reformat table for easier comparison
for toon,item in pairs(allitems) do
    for k,v in pairs(item) do
        if not qTable[k] then
            qTable[k] = {}
            lqtable = lqtable + 1
        end
        qTable[k][toon] = v.totalQty
    end
end


--Get modes from toons.lua into a separate table
local modes = {}
for owner,_ in pairs(allitems) do
    for _,toon in pairs(toons) do
        if toon.name == owner and toon.mode == 'Generous' then
            modes[toon] = 2
        elseif toon.name == owner and toon.mode == 'Greedy' then
            modes[toon] = 3
        elseif toon.name == owner and toon.mode ~= 'Default' then
            modes[toon] = 1
        end
    end
end

--------Compare everyone's items--------
local matches = {}
local function defineMatches()

    print('\at[TsC]\ao Tiebreaker: \ag'..tiebreaker)
    if isArtisan == true then
        print('\at[TsC]\ao Artisan: \ag'..artisan)
    else
        print('\at[TsC]\ao Artisan: \aynone')
    end
    print('\at[TsC]\ao Comparing results across toons...')
    mq.delay(1000)

    for item,player in pairs(qTable) do --Start iterating through items

        --Create give entry in matches table
        local function createEntries(givers,receiver,msg)
            if not matches[receiver] then matches[receiver] = {} end
            for _,giver in pairs(givers) do
                if giver.name ~= receiver and giver.name ~= 'Artisan' then
                    if not matches[giver.name] then matches[giver.name] = {} end
                    matches[giver.name][item] = receiver

                    if msg == 'art' then
                        print('\at[TsC]\ag [Artisan] \ar'..giver.name..'\'s \ag'..giver.qty..' \ay'..item..' \aowill go to \ar'..receiver..' \aowho is the \ag Artisan')
                    elseif msg == 'tie' then
                        print('\at[TsC]\ag [Tie] \ar'..giver.name..'\'s \ag'..giver.qty..' \ay'..item..' \aowill go to \ar'..receiver..' \aobecause there was a tie.')
                    else
                        print('\at[TsC]\ag [Match] \ar'..giver.name..'\'s \ag'..giver.qty..' \ay'..item..' \aowill go to \ar'..receiver..' \aowho has \ag'..player[receiver])
                    end
                    matchCount = matchCount + 1
                end
            end
        end

        local function findWinner(list,size)
            local winner
            local highest_qty, name = list[1].qty, list[1].name
            for i=2, size do
                if list[i].qty > highest_qty then
                    highest_qty, name = list[i].qty, list[i].name
                end
            end
            winner = name
            for i=1, size do
                if list[i].name ~= winner then
                    if list[i].qty == highest_qty then
                        winner = 'tie'
                    end
                end
            end
            return winner
        end

        --Identify this item's owners
        local owners = {}
        local low = 0
        for name,qty in pairs(qTable[item]) do
            local owner = {
                name = name,
                qty = qty
            }
            table.insert(owners, owner)
            low = low + 1
        end

        if low > 1 then --This item is owned by more than one toon.

            local artItem = false

            if isArtisan == true then
                for _,owner in pairs(owners) do --If artisan item, give to artisan and move to next item
                    if owner.name == 'Artisan' then artItem = true createEntries(owners, artisan, 'art') break end
                end
            end

            if artItem == false then

                local agGivers = {} --List of generous givers
                local lag = 0 --List length

                local nagGivers = {} --Inverse of agGivers (combo of modes 1 and 3)
                local lnag = 0 --List length

                local agReceivers = {} --List of greedy receivers
                local lar = 0 --List length

                --Put all item owners with their quantities in the appropriate list
                for _,owner in pairs(owners) do
                    if modes[owner.name] == 2 then table.insert(agGivers, owner) lag = lag + 1
                    elseif modes[owner.name] == 3 then table.insert(agReceivers, owner) lar = lar + 1
                    end
                    if modes[owner.name] ~= 2 then table.insert(nagGivers, owner) lnag = lnag + 1 end
                end

                --Case1: There is one greedy receiver. Give to them.
                --Case2: There is no qty winner among greedy receivers; give to first on the list.
                --Case3: There is a qty winner among greedy receivers. Give to them.
                --Case4: Everyone is an generous giver. Give to tiebreaker.
                --Case5: Tie among non-generous givers. Give to tiebreaker
                --Case5b: Tie among non-generous givers but tiebreaker is generous. Give to first non-generous on the list.
                --Case6: Winner among non-generous givers. Give to them.
                --Case7: Everyone is mode 1 but there's a tie. Give to tiebreaker.
                --Case8: Everying is mode 1 and there is a winner. Give to them.

                if lar == 1 then
                    --print('Case 1')
                    createEntries(owners, agReceivers[1].name)
                elseif lar > 1 then
                    local winner = findWinner(agReceivers, lar)
                    if winner == 'tie' then
                        --print('Case 2')
                        createEntries(owners, agReceivers[1].name)
                    else
                        --print('Case 3')
                        createEntries(owners, winner)
                    end
                elseif lag > 0 then
                    if lag == low then
                        --print('Case 4')
                        createEntries(owners, tiebreaker, 'tie')
                    else
                        local winner = findWinner(nagGivers, lnag)
                        if winner == 'tie' then
                            if modes[tiebreaker] ~= 2 then
                                --print('Case 5')
                                createEntries(owners, tiebreaker, 'tie')
                            else
                                --print('Case 5b')
                                createEntries(owners, nagGivers[1])
                            end
                        else
                            --print('Case 6')
                            createEntries(owners, winner)
                        end
                    end
                else
                    local winner = findWinner(owners, low)
                    if winner == 'tie' then
                        --print('Case 7')
                        createEntries(owners, tiebreaker, 'tie')
                    else
                        --print('Case 8')
                        createEntries(owners, winner)
                    end
                end
            end
        end
    end
    mq.pickle(matchesPath, matches)
    print('\at[TsC]\ao Done matching. Compared \ag'..lqtable..' \aounique items among \ag'..ltoons..' \aotoons and found \ag'..matchCount..' \aomatches.')
    mq.cmd('/tsc donematching')
end
defineMatches()