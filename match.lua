--- @type Mq
local mq = require('mq')
local utils = require('utils')

local settingPath = 'TSC/settings.lua'
local toonPath = 'TSC/toons.lua'
local artisanPath = 'TSC/artisan.lua'
local matchesPath = 'TSC/tmp/matches.lua'
local consolPath = 'TSC/tmp/consolidate.lua'

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
for _,toon in pairs(toons) do
    if mq.TLO.Spawn('PC ='..toon.name)() then --Only load results of toons in-zone
        local path = 'TSC/tmp/allitems_'..toon.name..'.lua'
        local table, error = loadfile(mq.configDir..'/'..path)
        if error then
            --nothing
        elseif table then
            --allitems[toon.name] = {}
            allitems[toon.name] = table()
            ltoons = ltoons + 1
        end
    end
end

---Reformat table for easier comparison
local lqtable = 0
local qTable = {}
for toon,items in pairs(allitems) do
    for item,qty in pairs(items) do
        if not qTable[item] then
            qTable[item] = {}
            lqtable = lqtable + 1
        end
        qTable[item][toon] = qty.total
        if qty.depot > 0 then qTable[item][toon] = 99999 end
    end
end

--Add artisan items to qTable
if isArtisan == true then
    for _,item in pairs(artList) do
        if not qTable[item] then
            qTable[item] = {['Artisan'] = 0}
        else
            qTable[item]['Artisan'] = 0
        end
    end
end


--Get modes from toons.lua into a separate table
local modes = {}
for _,toon in pairs(toons) do
    if toon.mode == 'Default' then
        modes[toon.name] = 'Default'
    elseif toon.mode == 'Greedy' then
        modes[toon.name] = 'Greedy'
    elseif toon.mode == 'Generous' then
        modes[toon.name] = 'Generous'
    end
end


--------Compare everyone's items--------
local matches = {}
local function defineTrades()

    print('\at[TsC]\ao Tiebreaker: \ag'..tiebreaker)
    if isArtisan == true then
        print('\at[TsC]\ao Artisan: \ag'..artisan)
    else
        print('\at[TsC]\ao Artisan: \aynone')
    end
    print('\at[TsC]\ao Comparing results across toons...')
    mq.delay(1000)

    for item,player in pairs(qTable) do --Start iterating through items

        --Create trade entries function
        local function createEntries(owners,receiver,msg)

            for _,owner in pairs(owners) do
                if owner.name ~= receiver and owner.name ~= 'Artisan' then
                    if not matches[owner.name] then matches[owner.name] = {} end

                    --Add destination in allitems table
                    allitems[owner.name][item].destination = receiver

                    --Add entry in trades table
                    matches[owner.name][item] = receiver

                    if msg == 'art' then
                        print('\at[TsC]\ag [Artisan] \ar'..owner.name..'\'s \ag'..owner.qty..' \ay'..item..' \aowill go to \ar'..receiver..' \aowho is the \ag Artisan')
                    elseif msg == 'tie' then
                        print('\at[TsC]\ag [Tie] \ar'..owner.name..'\'s \ag'..owner.qty..' \ay'..item..' \aowill go to \ar'..receiver..' \aobecause there was a tie.')
                    elseif player[receiver] == 99999 then
                        print('\at[TsC]\ag [Match] \ar'..owner.name..'\'s \ag'..owner.qty..' \ay'..item..' \aowill go to \ar'..receiver..' \aowho has \ag this item in their depot')
                    else
                        print('\at[TsC]\ag [Match] \ar'..owner.name..'\'s \ag'..owner.qty..' \ay'..item..' \aowill go to \ar'..receiver..' \aowho has \ag'..player[receiver])
                    end
                    matchCount = matchCount + 1
                end
                mq.delay(100)
            end

            --Ensure receiver is appears in the traders table. Necesry?
            if not matches[receiver] then matches[receiver] = {} end

            --Already add item that receiver will receive to their inventory to ensure item gets pulled into self-consolidate tree
            if not allitems[receiver][item] then --In case this is the tiebreaker and they don't have this item
                allitems[receiver][item] = {
                    inventory = {},
                    bank = {},
                    plots = {},
                    depot = 0,
                    total = 0,
                    locations = 0,
                    destination = ""
                }
            end
            allitems[receiver][item]['locations'] = allitems[receiver][item]['locations'] + 1
            allitems[receiver][item]['inventory']['General'] = 1
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

            --Check if artisan item. if true, give to artisan and move to next item
            local artItem = false
            if isArtisan == true then
                for _,owner in pairs(owners) do
                    if owner.name == 'Artisan' then artItem = true createEntries(owners, artisan, 'art') break end
                end
            end

            if artItem == false then

                local generousToons = {} --List of generous givers
                local lgen = 0 --List length

                local nonGenerousToons = {} --Inverse of agGivers (combo of modes 1 and 3)
                local lnon = 0 --List length

                local greedyToons = {} --List of greedy receivers
                local lgre = 0 --List length

                --Put all item owners with their quantities in the appropriate list
                for _,owner in pairs(owners) do
                    if modes[owner.name] == 'Generous' then table.insert(generousToons, owner) lgen = lgen + 1
                    elseif modes[owner.name] == 'Greedy' then table.insert(greedyToons, owner) lgre = lgre + 1
                    end
                    if modes[owner.name] ~= 'Generous' then table.insert(nonGenerousToons, owner) lnon = lnon + 1 end
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

                if lgre == 1 then
                    --print('Case 1')
                    createEntries(owners, greedyToons[1].name)
                elseif lgre > 1 then
                    local winner = findWinner(greedyToons, lgre)
                    if winner == 'tie' then
                        --print('Case 2')
                        createEntries(owners, greedyToons[1].name)
                    else
                        --print('Case 3')
                        createEntries(owners, winner)
                    end
                elseif lgen > 0 then
                    if lgen == low then
                        --print('Case 4')
                        createEntries(owners, tiebreaker, 'tie')
                    else
                        local winner = findWinner(nonGenerousToons, lnon)
                        if winner == 'tie' then
                            if modes[tiebreaker] ~= 'Generous' then
                                --print('Case 5')
                                createEntries(owners, tiebreaker, 'tie')
                            else
                                --print('Case 5b')
                                createEntries(owners, nonGenerousToons[1])
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
end
defineTrades()

--If in more than one plot location, find winner
local function findHighestValueKey(tbl)
    local highestKey = nil
    local highestValue = -math.huge
    
    for key, value in pairs(tbl) do
        if value > highestValue then
            highestKey = key
            highestValue = value
        end
    end
    return highestKey
end

---Self-consolidate logic tree on whatever is left
local consolidate = {}
for toon, items in pairs(allitems) do
    for item, stuff in pairs(items) do

        --If destination is empty, no trades were found and it needs to be self-consolidated
        if stuff.destination == "" or stuff.destination == "BankRestack" then
            if stuff.locations <= 1 then
                if utils.listSize(stuff.inventory) == 0 then
                    --Already consolidated
                else
                    stuff.destination = 'Leftovers'
                end
            else
                if stuff.depot > 0 then
                    stuff.destination = 'Depot'
                else
                    if utils.listSize(stuff.bank) > 0 and utils.listSize(stuff.plots) > 0 then
                        if settings.preferPlots == true then
                            stuff.destination = findHighestValueKey(stuff.plots)
                        else
                            stuff.destination = 'Bank'
                        end
                    elseif utils.listSize(stuff.plots) > 0 then
                        stuff.destination = findHighestValueKey(stuff.plots)
                    elseif utils.listSize(stuff.bank) > 0 then
                        if utils.listSize(stuff.inventory) > 0 then
                            stuff.destination = 'Bank'
                        else
                            --Leave as "" or bankrestack
                        end
                    else
                        stuff.destination = 'Leftovers'
                    end
                end
            end
            --Anything blank is already consolidated
            if stuff.destination ~= '' then
                if not consolidate[toon] then
                    consolidate[toon] = {}
                end
                consolidate[toon][item] = stuff.destination
                if utils.listSize(stuff.plots) > 0 then
                    consolidate[toon]['Real Estate'] = true
                end
            end
        end
    end
end
mq.pickle(matchesPath, matches)
mq.pickle(consolPath, consolidate)



--Decombine allitems back into individual files
for toon, items in pairs(allitems) do
    local path = 'TSC/tmp/allitems_'..toon..'.lua'
    mq.pickle(path, items)
end


print('\at[TsC]\ao Done identifying trades. Compared \ag'..lqtable..' \aounique items among \ag'..ltoons..' \aotoons and found \ag'..matchCount..' \aoitems that need to change hands.')
mq.cmd('/tsc donematching')