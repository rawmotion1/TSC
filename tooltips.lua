--- @type Mq
local mq = require('mq')

local tip = {}

tip.tie = [[
If multiple toons have the same
number of an item and a winner 
can't be decided based on mode, 
everyone gives to the tiebreaker.]]

tip.art = [[
Set one of your toons as an artisan
to ensure they always win on items
in your artisan list, regardless of
mode or quantity factors. An artisan
will never give away items in the
artisan list.
]]

tip.hoardlist = [[
Manage the list of items you want
your artisan to always win and never
give away.
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
to the toon with the highest quantity. 
Generous and greedy modes let you
override this default behavior. E.g., 
If a greedy toon has 1 opal and 
another toon has 5, the greedy toon 
will win. If a generous toon has 10 
diamonds and another has 2, the 
generous toon will give instead of
receive.
]]

tip.rest = [[
This tells a toon what to do with
leftover items in their inventory after
consolidation is complete. For example,
if it is set to Depot > Bank > Mules, the 
toon will try to dump everything into 
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
a name for options.
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
processes and restart TSC.
]]

tip.name = 'Right-click for options.'

tip.addignoreitem = [[
Click here with an item on your cursor to 
add it to your list.
]]

tip.importignore = [[
Import items from a text file. The text file 
must be in your config directory, in the TSC 
folder. 
]]


tip.ignorebutton = [[
Manage the list of items you want your toons to 
ignore. I recommend adding items like food and 
drink, and other items you don't want traded.
]]

tip.confirmself = " will self-consolidate, which may involve banking, and dropping items into the depot. If you have a Leftovers option set, you may give items to mules. Make sure your settings are the way you want them before proceeding."

tip.goall = 'Make sure your settings are the way you want them before proceeding. And make sure everyone is easy to navigate to and there is a banker nearby.'

tip.depotwarning = 'To deposit items into the tradeskill depot, TSC will take over your mouse and change focus to each toon\'s EQ window. You won\'t be able to use your PC while this is happening. Please confirm that you are ready.'
return tip