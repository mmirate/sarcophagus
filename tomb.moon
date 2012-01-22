-- celibate command-line text snippets

-- require()s {{{
tns = require'tnetstrings'
apr = require'apr'
__ = require'underscore'
lpeg, re = require'lpeg', require're'
posix = require'posix'

-- }}}

-- load tombfile {{{
f = io.open(apr.filepath_merge(os.getenv'HOME', '.tomb', 'not-relative'), 'rb')
if not f
	f = io.open(apr.filepath_merge(os.getenv'HOME', '.tomb', 'not-relative'), 'wb')
	assert f\write tns.dump {}
	assert f\close!
	f = assert io.open(apr.filepath_merge(os.getenv'HOME', '.tomb', 'not-relative'), 'rb')
data = assert tns.parse(f\read'*a','}')
assert f\close!
union = __.reduce(__.values(data), {}, ((x,y) -> __.extend y,x))
dirty = false
-- }}}

-- secondary functions {{{

anywhere = (p) -> -- {{{
	lpeg.P{ p + 1 * lpeg.V(1) }
-- }}}

urlextract = (text) -> -- {{{
	lpeg.match anywhere(re.compile[=====[ { 'http://' [^ ]+ } ]=====])
-- }}}

-- }}}

-- primary functions {{{

delete = (list, key) -> -- {{{
	data[list][key] = nil
	dirty = true
	print('\226\128\156'..key..'\226\128\157 in list \226\128\156'..list..'\226\128\157 deleted.')
-- }}}

open = (text) -> -- {{{
	url = urlextract text
	print('URL \226\128\156'..url..'\226\128\157 opened in Chromium.')
	pid = assert posix.fork!
	if pid==0
		apr.proc_detach true
		assert posix.execp('chromium', url)
-- }}}

show = (tab) -> -- {{{
	if not tab
		for name, list in pairs data
			print name
			show list
	else
		for k, v in pairs tab do print('\t' .. k .. ':\t\t' .. v)
--}}}

lists = -> -- {{{
	for k, _ in pairs data do print(k .. ' (' .. #k .. ')')
-- }}}

edit = -> -- {{{
	print'Launching editor...'
	pid = assert posix.fork!
	if pid==0
		apr.proc_detach true
		assert posix.execp(os.getenv'EDITOR' or 'vi', apr.filepath_merge(os.getenv'HOME', '.tomb', 'not-relative'))
-- }}}

copy = (text) -> -- {{{
	xclip1 = apr.proc_create'xclip'
	xclip2 = apr.proc_create'xclip'
	xclip1\cmdtype_set'program/env/path'
	xclip2\cmdtype_set'program/env/path'
	xclip1\io_set('child-block','parent-block','none')
	xclip2\io_set('child-block','parent-block','none')
	xclip1\exec{'-i','-selection','clipboard'}
	xclip2\exec{'-i'}
	input1, input2 = xclip1\in_get!, xclip2\in_get!
	input1\write text
	input2\write text
	xclip1\wait true
	xclip2\wait true
	print('\226\128\156'..text..'\226\128\157 copied to clipboard and primary.')
-- }}}

set = (name, key, value) -> -- {{{
	print('\226\128\156'..key..'\226\128\157 in list \226\128\156'..name..'\226\128\157 set to \226\128\156'..value..'\226\128\157.')
	data[name][key] = value
	dirty = true
-- }}}

create = (name) -> -- {{{
	data[name] = {}
	dirty = true
	print('New list \226\128\156'..name..'\226\128\157 created.')
-- }}}

help = -> -- {{{
	print[==[tomb v0.0.1 usage:

	tomb							display high-level overview
	tomb all						show all items in all lists
	tomb edit						edit the tomb tnetstring file in $EDITOR
	tomb help						this help text

	tomb <list>						create a new list
	tomb <list>						show items in a list
	tomb <list> delete				delete a list

	tomb <list> <name> <value>		create a new list item
	tomb <name>						copy item's value to clipboard
	tomb <list> <name>				copy item's value to clipboard
	tomb open <name>				open item's URL in Chromium
	tomb open <list> <name>			open the URL of all lists' items in Chromium
	tomb echo <name>				echo the item's value without copying
	tomb echo <list> <name>			echo the item's value without copying
	tomb <list> <name> delete		delete an item

All other documentation is located at <http://github.com/mmirate/tomb>.]==]
-- }}}

-- }}}

-- argument parsing {{{
if #arg == 0 then lists!
elseif arg[1] == 'all' then show!
elseif arg[1] == 'edit' then edit!
elseif arg[1] == 'help' then help!
elseif arg[#arg] == 'delete'
	if arg[2] and arg[2] != 'delete'
		if data[arg[1]][arg[2]] then delete data[arg[1]], arg[2]
	elseif arg[1] and arg[1] != 'delete'
		if data[arg[1]] then delete data[arg[1]]
elseif arg[1] == 'open'
	if arg[3]
		if data[arg[2]][arg[3]] then open data[arg[2]][arg[3]]
	elseif arg[2]
		if union[arg[2]] then open union[arg[2]]
elseif arg[1] == 'echo'
	if arg[3]
		if data[arg[2]][arg[3]] then print data[arg[2]][arg[3]]
	elseif arg[2]
		if union[arg[2]] then print union[arg[2]]
elseif #arg == 1
	if data[arg[1]] then show data[arg[1]] elseif union[arg[1]] then copy union[arg[1]] else create arg[1]
elseif #arg == 2
	if data[arg[1]][arg[2]] then copy data[arg[1]][arg[2]]
elseif #arg == 3
	if not data[arg[1]] then create arg[1]
	set arg[1], arg[2], arg[3]
-- }}}

-- tombfile writeback {{{
if dirty
	f = assert io.open(apr.filepath_merge(os.getenv'HOME', '.tomb', 'not-relative'), 'wb')
	assert f\write tns.dump data
	assert f\close!
-- }}}

