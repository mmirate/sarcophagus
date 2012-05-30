local tns = require('tnetstrings')
local apr = require('apr')
local __ = require('underscore')
local lpeg, re = require('lpeg'), require('re')
local posix = require('posix')
local f = io.open(apr.filepath_merge(os.getenv('HOME'), '.tomb', 'not-relative'), 'rb')
if not f then
  f = io.open(apr.filepath_merge(os.getenv('HOME'), '.tomb', 'not-relative'), 'wb')
  assert(f:write(tns.dump({ })))
  assert(f:close())
  f = assert(io.open(apr.filepath_merge(os.getenv('HOME'), '.tomb', 'not-relative'), 'rb'))
end
local data = assert(tns.parse(f:read('*a'), '}'))
assert(f:close())
local union = __.reduce(__.values(data), { }, (function(x, y)
  return __.extend(y, x)
end))
local dirty = false
local anywhere
anywhere = function(p)
  return lpeg.P({
    p + 1 * lpeg.V(1)
  })
end
local urlextract
urlextract = function(text)
  return lpeg.match(anywhere(re.compile([=====[ { 'http://' [^ ]+ } ]=====])))
end
local delete
delete = function(list, key)
  data[list][key] = nil
  dirty = true
  return print('\226\128\156' .. key .. '\226\128\157 in list \226\128\156' .. list .. '\226\128\157 deleted.')
end
local open
open = function(text)
  local url = urlextract(text)
  print('URL \226\128\156' .. url .. '\226\128\157 opened in Chromium.')
  local pid = assert(posix.fork())
  if pid == 0 then
    apr.proc_detach(true)
    return assert(posix.execp('chromium', url))
  end
end
local show
show = function(tab)
  if not tab then
    for name, list in pairs(data) do
      print(name)
      show(list)
    end
  else
    for k, v in pairs(tab) do
      print('\t' .. k .. ':\t\t' .. v)
    end
  end
end
local lists
lists = function()
  for k, _ in pairs(data) do
    print(k .. ' (' .. #k .. ')')
  end
end
local edit
edit = function()
  print('Launching editor...')
  local pid = assert(posix.fork())
  if pid == 0 then
    apr.proc_detach(true)
    return assert(posix.execp(os.getenv('EDITOR') or 'vi', apr.filepath_merge(os.getenv('HOME'), '.tomb', 'not-relative')))
  end
end
local copy
copy = function(text)
  local xclip1 = apr.proc_create('xclip')
  local xclip2 = apr.proc_create('xclip')
  xclip1:cmdtype_set('program/env/path')
  xclip2:cmdtype_set('program/env/path')
  xclip1:io_set('child-block', 'parent-block', 'none')
  xclip2:io_set('child-block', 'parent-block', 'none')
  xclip1:exec({
    '-i',
    '-selection',
    'clipboard'
  })
  xclip2:exec({
    '-i'
  })
  local input1, input2 = xclip1:in_get(), xclip2:in_get()
  input1:write(text)
  input2:write(text)
  xclip1:wait(true)
  xclip2:wait(true)
  return print('\226\128\156' .. text .. '\226\128\157 copied to clipboard and primary.')
end
local set
set = function(name, key, value)
  print('\226\128\156' .. key .. '\226\128\157 in list \226\128\156' .. name .. '\226\128\157 set to \226\128\156' .. value .. '\226\128\157.')
  data[name][key] = value
  dirty = true
end
local create
create = function(name)
  data[name] = { }
  dirty = true
  return print('New list \226\128\156' .. name .. '\226\128\157 created.')
end
local help
help = function()
  return print([==[tomb v0.0.1 usage:

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

All other documentation is located at <http://github.com/mmirate/tomb>.]==])
end
if #arg == 0 then
  lists()
elseif arg[1] == 'all' then
  show()
elseif arg[1] == 'edit' then
  edit()
elseif arg[1] == 'help' then
  help()
elseif arg[#arg] == 'delete' then
  if arg[2] and arg[2] ~= 'delete' then
    if data[arg[1]][arg[2]] then
      delete(data[arg[1]], arg[2])
    end
  elseif arg[1] and arg[1] ~= 'delete' then
    if data[arg[1]] then
      delete(data[arg[1]])
    end
  end
elseif arg[1] == 'open' then
  if arg[3] then
    if data[arg[2]][arg[3]] then
      open(data[arg[2]][arg[3]])
    end
  elseif arg[2] then
    if union[arg[2]] then
      open(union[arg[2]])
    end
  end
elseif arg[1] == 'echo' then
  if arg[3] then
    if data[arg[2]][arg[3]] then
      print(data[arg[2]][arg[3]])
    end
  elseif arg[2] then
    if union[arg[2]] then
      print(union[arg[2]])
    end
  end
elseif #arg == 1 then
  if data[arg[1]] then
    show(data[arg[1]])
  elseif union[arg[1]] then
    copy(union[arg[1]])
  else
    create(arg[1])
  end
elseif #arg == 2 then
  if data[arg[1]][arg[2]] then
    copy(data[arg[1]][arg[2]])
  end
elseif #arg == 3 then
  if not data[arg[1]] then
    create(arg[1])
  end
  set(arg[1], arg[2], arg[3])
end
if dirty then
  f = assert(io.open(apr.filepath_merge(os.getenv('HOME'), '.tomb', 'not-relative'), 'wb'))
  assert(f:write(tns.dump(data)))
  assert(f:close())
end
