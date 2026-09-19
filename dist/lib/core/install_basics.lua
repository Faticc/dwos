local computer = require("computer")
local shell = require("shell")
local fs = require("filesystem")
local args, options = shell.parse(...)
if options.help then
io.write([[Usage: install [OPTION]...
  --from=ADDR        install filesystem at ADDR
                     default: builds list of
                     candidates and prompts user
  --to=ADDR          same as --from but for target
  --fromDir=PATH     install PATH from source
  --root=PATH        same as --fromDir but target
  --toDir=PATH       same as --root
  -u, --update       update files interactively
  --label            override label from .prop
  --nosetlabel       do not label target
  --nosetboot        do not use target for boot
  --noreboot         do not reboot after install
  --text             plain text interface
]])
return nil
end
local rootfs = fs.get("/")
if not rootfs then
io.stderr:write("no root filesystem, aborting\n")
os.exit(1)
end
local label = args[1]
options.label = label
local function resolveFilter(key)
local filter = options[key]
if not filter then return nil end
local path = shell.resolve(filter)
if fs.isDirectory(path) then
local dev = fs.get(path)
options[key] = path
return dev.address, dev
end
return filter
end
local source_filter, source_filter_dev = resolveFilter("from")
local target_filter, target_filter_dev = resolveFilter("to")
local comps = require("component").list("filesystem")
local devices = {}
for dev, path in fs.mounts() do
if comps[dev.address] then
local known = devices[dev]
devices[dev] = known and #known < #path and known or path
end
end
local dev_dev = fs.get("/dev")
devices[dev_dev == rootfs or dev_dev] = nil
local tmpAddress = computer.tmpAddress()
local targets = {}
for dev, path in pairs(devices) do
local address = dev.address
local install_path = dev == target_filter_dev and options.to or path
local specified = target_filter and address:find(target_filter, 1, true) == 1
if dev.isReadOnly() then
if specified then
io.stderr:write("Cannot install to " .. options.to .. ", it is read only\n")
os.exit(1)
end
elseif specified or
not (source_filter and address:find(source_filter, 1, true) == 1) and
not target_filter and address ~= tmpAddress then
targets[#targets + 1] = { dev = dev, path = install_path, specified = specified }
end
end
if #targets == 1 then
devices[targets[1].dev] = nil
end
local sources = {}
for dev, path in pairs(devices) do
local address = dev.address
local install_path = dev == source_filter_dev and options.from or path
local specified = source_filter and address:find(source_filter, 1, true) == 1
if fs.list(install_path)() and (specified or not source_filter and address ~= tmpAddress) then
local prop, has_prop = {}, false
local prop_file = fs.open(path .. "/.prop")
if prop_file then
has_prop = true
local prop_data = prop_file:read(math.maxinteger or math.huge)
prop_file:close()
local prop_load = load("return " .. prop_data)
prop = prop_load and prop_load()
if not prop then
io.stderr:write("Ignoring " .. path .. " due to malformed prop file\n")
prop = { ignore = true }
end
end
local may_source = specified or has_prop
or address ~= rootfs.address or rootfs.isReadOnly()
if not prop.ignore and may_source and
(not label or label:lower() == (prop.label or dev.getLabel() or ""):lower()) then
sources[#sources + 1] = { dev = dev, path = install_path, prop = prop, specified = specified }
end
end
end
table.sort(sources, function(a, b) return a.path < b.path end)
table.sort(targets, function(a, b) return a.path < b.path end)
return {
options = options,
sources = sources,
targets = targets,
label = label,
}
