-- Syntax compilation only; this does not typecheck Roblox API calls.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local count = 0
local function compileDirectory(path)
	for _, name in fs.readDir(path) do
		local file = path .. "/" .. name
		if fs.isDir(file) then
			compileDirectory(file)
		elseif string.sub(name, -5) == ".luau" then
			luau.compile(fs.readFile(file))
			count += 1
			print("COMPILED " .. file)
		end
	end
end
compileDirectory("src")
assert(count == 36, "Source discovery incomplete or source manifest needs updating")
print(count .. " runtime modules/scripts compiled.")
