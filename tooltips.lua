--- @type Mq
local mq = require('mq')

local tip = {}

tip.tie = "If there\'s a QTY tie for an item and it can\'t be resolved by mode, everyone gives it to the tiebreaker."

tip.art = "Set one toon as artisan to ensure they always win on items in your artisan list, regardless of mode or QTY. The artisan will never give away items in the artisan list."

tip.hoardlist = "Manage the list of items you want your artisan to always win and never give away."

tip.self = "Make this toon self-consolidate their bank, depot, inventory, and plots without comparing against other toons. No trading unless you have leftovers enabled."

tip.mode = "When toons have the same item, the default is to give to the one with most. Generous and greedy modes override this: a greedy toon wins even with fewer items, while a generous one gives away despite having more."

tip.rest = "This tells a toon what to do with leftover items in their inventory after consolidation is complete. E.g., dump them into your bank."

tip.give = "This tells your toon to give all their mats or collectibles to another toon. You can include everything stored in your bank/depot as well. If your inventory is not big enough, you will make several trips."

tip.mule = "Mules are only used for Leftovers. When one is full, you will automatically move to the next one. You can right-click to rearrange them."

tip.toon = "These toons will be scanned, trade among each other, and self-consolidate to free up slots. They must all be in the same zone (with a banker)."

tip.stats = "Report stats about how many items and slots each toon gained or lost. Requires an extra scan."

tip.real = "Include items stored in your real estate plots. This may involve one or two runs to Sunrise Hills and back to grab and/or deposit items."

tip.prefReal = "If you have the same item in your bank and on your plot, move it to your plot. If this is off, it will move it to your bank."

tip.go = "Run the full consolidation routine on all your toons."

tip.stop = "If something is going wrong, or you started with the wrong settings, this will kill all processes and restart TSC."

tip.name = 'Right-click for options.'

tip.addignoreitem = "Click here with an item on your cursor to add it to your list."

tip.importignore = "Import items from a text file. The text file must be in your config directory, in the TSC folder."

tip.ignorebutton = "Manage the list of items you want your toons to ignore. I recommend adding items like food and drink, and other items you don't want traded."

tip.confirmself = " will self-consolidate, which may involve banking, and dropping items into the depot. If you have a Leftovers option set, you may give items to mules. Make sure your settings are the way you want them before proceeding."

tip.goall = 'Make sure your settings are the way you want them before proceeding. And make sure everyone is easy to navigate to and there is a banker nearby.'

tip.depotwarning = 'To deposit items into the tradeskill depot, TSC will take over your mouse and change focus to each toon\'s EQ window. You won\'t be able to use your PC while this is happening. Please confirm that you are ready.'

tip.tidyall = 'Make every toon self-consolidate their bank, depot, inventory, and plots without comparing against other toons. Then, run leftovers.'
return tip