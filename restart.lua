--- @type Mq
local mq = require('mq')

mq.delay(500)

mq.cmd('/lua run tsc')