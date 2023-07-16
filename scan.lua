--- @type Mq
local mq = require('mq')
local utils = require('utils')

local args = {...}
local mode = tonumber(args[1]) --1 normal, 2 give mode
local scope = tonumber(args[2]) -- 1 everywhere, 4 inventory
local what = tonumber(args[3]) -- 42 mats, 19 collectibles

local me = mq.TLO.Me.Name()
local settingPath = 'TSC/settings.lua'
local itemsPath = 'TSC/tmp/allitems_'..me..'.lua'
local artisanPath = 'TSC/artisan.lua'
local pIgnorePath = 'TSC/ignore_'..me..'.lua'
local ignorePath = 'TSC/ignore.lua'
local statPath = 'TSC/tmp/stats_'..me..'.lua'

local settings = {}
local items = {}
local pignore = {}
local gignore = {}
local ignore = {}
local stats = {}
local artList = {}

local isArtisan = false
local isPignore

local function loadfiles()
    local loadSettings, setError = loadfile(mq.configDir..'/'..settingPath)
    if setError then
        mq.exit()
    elseif loadSettings then
        settings = loadSettings()
    end

    --Load global and personal ignore files
    local pignoreList, pignoreerror = loadfile(mq.configDir..'/'..pIgnorePath)
    if pignoreerror then
        --nothing
    elseif pignoreList then
        pignore = pignoreList()
        isPignore = true
    end

    local ignoreList, ignoreerror = loadfile(mq.configDir..'/'..ignorePath)
    if ignoreerror then
        print('\at[TsC]\ao Error loading ignore.lua')
        mq.exit()
    elseif ignoreList then
        gignore = ignoreList()
    end

    local statList, staterror = loadfile(mq.configDir..'/'..statPath)
    if staterror then
        --nothing
    elseif statList then
        stats = statList()
    end

    local loadArt, artError = loadfile(mq.configDir..'/'..artisanPath)
    if artError then
        --Nothing
    elseif loadArt then
        if mode == 2 then
            if me == settings.artisan then
                isArtisan = true
                artList = loadArt()
            end
        end
    end
end
loadfiles()

if isPignore == true then --Combine personal and global ignore files
    local tempTable = {}
    local n = 0
    for _,item in pairs(pignore) do
        n = n + 1
        tempTable[n] = item
    end
    for _,item in pairs(gignore) do
        n = n + 1
        tempTable[n] = item
    end
    ignore = tempTable
else
    ignore = gignore
end

--If in givemode and I am artisan, add artisan list to ignore file.
--In givemode, I want to filter out artisan items in the scan phase because there is no matching.
if mode == 2 and isArtisan then
    local tempTable = {}
    local n = 0
    for _,item in pairs(ignore) do
        n = n + 1
        tempTable[n] = item
    end
    for _,item in pairs(artList) do
        n = n + 1
        tempTable[n] = item
    end
    ignore = tempTable
end

utils.cleanup()

print('\at[TsC]\ao Scanning items...')


--Scan this toon. Send scope, ignore file, blank items table, ts or col mode. Returns # items, # slots, and populated items table.
local countSlots, countItems = utils.scan(scope, ignore, items, what)

--Look for multiple incomplete stacks in inventory and restack them
utils.sortBags(items, ignore)

--Save items file for this toon
mq.pickle(itemsPath, items)

if stats['beforeItems'] == 'unset' then
    stats['beforeItems'] = countItems
    stats['beforeSlots'] = countSlots
else
    stats['afterItems'] = countItems
    stats['afterSlots'] = countSlots
end

--Save stats file for this toon
mq.pickle(statPath, stats)

mq.cmdf('/dt %s \awDone scanning. Found \ay%s \awunique items using up \ay%s \awslots.', settings.driver, countItems, countSlots)

--Tell init that this script is done
if settings.driver == me then
    mq.cmd('/tsc donescanning')
else
    mq.cmdf('/dex %s /tsc donescanning', settings.driver)
end