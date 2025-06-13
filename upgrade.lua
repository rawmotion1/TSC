--- @type Mq
local mq = require('mq')
local cm = require('TSC.configmanager')

local upgrade = {
    oldSettings = {},
    newSettings = {},
    oldIgnore = {},
    newIgnore = {},
    oldPignore = {},
    newPignore = {},
    oldArtisan = {},
    newHoard = {},
    oldToons = {},
    newToons = {},
    newMules = {},
}

local oldPaths = {
    settings = mq.configDir..'/TSC/settings.lua',
    toons = mq.configDir..'/TSC/toons.lua',
    ignore = mq.configDir..'/TSC/ignore.lua',
    artisan = mq.configDir..'/TSC/artisan.lua',
    pignore = mq.configDir..'/TSC/ignore_',
}

print('\at[TsC]\ao ## Upgrading from \ayTSC v3.x \ato to \ayTSC v4.x\a.')

print('\at[TsC]\ao ## Loading old settings from \ay'..oldPaths.settings..'\ao...')
local oldSettings = loadfile(oldPaths.settings)
if oldSettings then
    upgrade.oldSettings = oldSettings()
end

print('\at[TsC]\ao ## Upgrading old settings to new format...')
upgrade.newSettings.driver = mq.TLO.Me.Name()
upgrade.newSettings.tiebreaker = upgrade.oldSettings.tiebreaker or mq.TLO.Me.Name()
upgrade.newSettings.stats = upgrade.oldSettings.stats or true
upgrade.newSettings.includePlots = upgrade.oldSettings.includePlots or false
upgrade.newSettings.preferPlots = upgrade.oldSettings.preferPlots or false
upgrade.newSettings.fullAuto = upgrade.oldSettings.fullAuto or false
upgrade.newSettings.upgraded = true
cm.saveData('settings', upgrade.newSettings)

print('\at[TsC]\ao ## Upgrading old mules lists...')
if #upgrade.oldSettings.mules > 0 then
    for _, mules in pairs(upgrade.oldSettings.mules) do
        upgrade.newMules[mules.name] = true
    end
    cm.saveData('mules', upgrade.newMules)
end

print('\at[TsC]\ao ## Upgrading old toons lists...')
local oldToons = loadfile(oldPaths.toons)
if oldToons then
    upgrade.oldToons = oldToons()
end

if #upgrade.oldToons > 0 then
    for _, toon in pairs(upgrade.oldToons) do
        upgrade.newToons[toon.name] = {
            mode = toon.mode or 'Default',
            leftovers = toon.leftovers or 'Off'
        }
    end
    cm.saveData('toons', upgrade.newToons)
end

print('\at[TsC]\ao ## Upgrading old ignore lists...')
local oldIgnore = loadfile(oldPaths.ignore)
if oldIgnore then
    upgrade.oldIgnore = oldIgnore()
end

if #upgrade.oldIgnore > 0 then
    for _, item in pairs(upgrade.oldIgnore) do
        upgrade.newIgnore[item] = true
    end
    cm.saveData('ignore', upgrade.newIgnore)
end

print('\at[TsC]\ao ## Upgrading old personal ignore lists...')
for _, toon in pairs(upgrade.oldToons) do
    local oldPignore = loadfile(oldPaths.pignore .. toon.name .. '.lua')
    if oldPignore then
        upgrade.oldPignore[toon.name] = oldPignore()
    else
        upgrade.oldPignore[toon.name] = {}
    end

    if #upgrade.oldPignore[toon.name] > 0 then
        upgrade.newPignore[toon.name] = {}
        for _, item in pairs(upgrade.oldPignore[toon.name]) do
            upgrade.newPignore[toon.name][item] = true
        end
    end
end
cm.saveData('pignore', upgrade.newPignore)

print('\at[TsC]\ao ## Upgrading old artisan lists...')
local oldArtisan = loadfile(oldPaths.artisan)
if oldArtisan then
    upgrade.oldArtisan = oldArtisan()
else
    upgrade.oldArtisan = {}
end

if #upgrade.oldArtisan > 0 then
    upgrade.newHoard[upgrade.oldSettings.artisan] = {}
    for _, item in pairs(upgrade.oldArtisan) do
        upgrade.newHoard[upgrade.oldSettings.artisan][item] = true
    end
    cm.saveData('hoard', upgrade.newHoard)
end

print('\at[TsC]\ao ## Cleaning up old files...')
for _, toon in pairs(upgrade.oldToons) do
    local pignoreFile = oldPaths.pignore .. toon.name .. '.lua'
    if os.remove(pignoreFile) then
        print('\at[TsC]\ao ## Deleted file: ' .. pignoreFile)
    else
        print('\at[TsC]\ao ## Failed to delete file: ' .. pignoreFile)
    end
end
if os.remove(oldPaths.artisan) then
    print('\at[TsC]\ao ## Deleted file: ' .. oldPaths.artisan)
else
    print('\at[TsC]\ao ## Failed to delete file: ' .. oldPaths.artisan)
end

print('\at[TsC]\ao ## Upgrade complete!')