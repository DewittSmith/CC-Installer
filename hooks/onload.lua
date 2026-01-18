local _, installPath = ...

local path = shell.path()
if not string.find(path, installPath, 1, true) then
    shell.setPath(path .. ":" .. installPath)
    print("Added sol to shell path.")
end

if not shell.aliases()["sol"] then
    print("Add alias for sol? (y/n, default: y)")
    local answer = read()

    if answer ~= "n" and answer ~= "N" then
        shell.setAlias("sol", fs.combine(installPath, "sol.lua"))
    end
end