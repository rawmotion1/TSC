--- @type Mq
local mq = require('mq')

local tip = {}

tip.tie = [[
If multiple toons have the same
number of an item and a winner 
can't be decided based on mode, 
everyone gives to the tiebreaker.]]

tip.art = [[
If an artisan is set, all items
will be checked against your 
artisan.lua file. All artisan
items will go to the artisan,
overruling any quantity and 
mode considerations.
]]

tip.self = [[
Consolidate just this toon's
items across inventory, bank,
and depot. No trading unless
you have leftovers enabled.
]]

tip.mode = [[
When multiple toons have the same
item, by default everyone will give 
to the toon with the highest 
quantity. Generous and greedy modes
take precedence over quantity. If a
greedy toon has 1 opal and another 
toon has 5, the greedy toon will win.
If a generous toon has 10 diamonds
and another has 2, the generous toon
will give.
]]

tip.rest = [[
This tells a toon what to do with
leftover items in their inventory after
consolidation is complete. D = depot. B = 
bank. M = mules. If set to DBM, for example,
the toon will try to dump everything into 
their depot. When that's full, they'll
move to the bank. When that's full they'll 
start giving to mules. In that order.
]]

tip.give = [[
This simply tells your toon to give all their 
TS items or collectibles to another toon. You
can choose whether to include everything stored
in your bank/depot as well. If your inventory
is not big enough, you will make several trips.
]]

tip.mule = [[
Mules are used for the Leftovers routine. A
mule can be someone in your toons list, but
doesn't have to be. They just need to be
connected to DanNet. The order in which they
appear is the order in which your toons will
give items to them. When one is full, your
toons will automatically move to the next one.
You can right-click to rearrange them.
]]

tip.toon = [[
These are the toons that will be scanned 
and trade among each other to eliminate 
duplicates and free up slots. They must
all be in the same zone (with a banker) 
and be connected to DanNet. Right-click
for options.
]]

tip.stats = [[
Report stats about how many items and
slots each toon gained or lost. Requires
an extra scan.
]]

tip.go = [[
Run the full consolidation routine on all
your toons. Can take a while depending on
how many toons you have, and how big your
artisan list is.
]]

tip.stop = [[
If something is going wrong, or you started
with the wrong settings, this will kill all
proccesses.
]]
return tip