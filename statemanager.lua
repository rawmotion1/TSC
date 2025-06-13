--- @type Mq
local mq = require('mq')

--- @class StateManager
local states = {
    start = false,
    routine = 'none',
    status = 'Idle',
    itemType = 'Tradeskill',
    activeToon = 'none',
    giveTarget = 'Choose...',
    deliverItem = 'none',
    deliverQty = 0,
    includeBank = false,
    tradeConfirmWnd = false,
    skipTrading = false,
    leftoverConfirmWnd = false,
    searchWnd = false,
    skipLeftovers = false,
    stats = {},
}

function states:clear()
    self.start = false
    self.routine = 'none'
    self.status = 'Idle'
    self.activeToon = 'none'
    self.giveTarget = 'Choose...'
    self.deliverItem = 'none'
    self.deliverQty = 0
    self.includeBank = false
    self.includeDepot = false
    self.skipTrading = false
    self.skipLeftovers = false
end


return states