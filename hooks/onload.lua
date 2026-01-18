local packageName, installPath = ...

local cachedPackages = {}

local orderPath = "/" .. fs.combine(installPath, "..", "load.order")
print(orderPath)
if not fs.exists(orderPath) then
    local orderFile = fs.open(orderPath, "w")
    orderFile.writeLine(textutils.serialise({ [packageName] = installPath }))
    orderFile.close()
end

local orderFile = fs.open(orderPath, "r")
local order = textutils.unserialise(orderFile.readAll())
orderFile.close()

local function filename_without_extension(path)
    return path:match("([^/]+)%.%w+$") or path
end

_G.sol = _G.sol or {}
_G.sol.require = function(modname)
    if not modname or modname == "" then error("No modname provided") end
    if cachedPackages[modname] then return cachedPackages[modname] end

    local ip = order[modname]
    if not ip then
        for k, v in pairs(order) do
            if k:sub(1, #modname) == modname then
                ip = v
                break
            end
        end
    end

    if not ip then error("Module '" .. modname .. "' not found") end

    local mod = {}
    cachedPackages[modname] = mod

    local path = package.path
    package.path = path .. ";/" .. fs.combine(ip, "?.lua")

    local success, err = pcall(function()
        local function loadFile(folder, prefix, p)
            if p:sub(1, 1) ~= "/" then p = "/" .. p end
            if fs.isDir(p) then
                local dirName = fs.getName(p)
                local newPrefix = prefix and (prefix .. "." .. dirName) or dirName
                folder[dirName] = folder[dirName] or {}
                for _, subpath in ipairs(fs.list(p)) do
                    loadFile(folder[dirName], newPrefix, fs.combine(p, subpath))
                end
            elseif p:match("%.lua$") then
                local filename = filename_without_extension(p)
                local requirePath = prefix and (prefix .. "." .. filename) or filename

                local mod = require(requirePath)
                if type(mod) == "table" then
                    if filename == modname or filename == "init" then
                        for k, v in pairs(mod) do
                            folder[k] = v
                        end
                    else
                        folder[filename] = mod
                    end
                end
            end
        end

        local function cleanup(tbl)
            for k, v in pairs(tbl) do
                if type(v) == "table" then
                    cleanup(v)
                    if next(v) == nil then
                        tbl[k] = nil
                    end
                elseif v == true then
                    tbl[k] = nil
                end
            end
        end

        for _, p in ipairs(fs.list(ip)) do
            loadFile(mod, nil, fs.combine(ip, p))
        end

        cleanup(mod)
    end)

    if not success then
        cachedPackages[modname] = nil
        printError(err)
    end

    package.path = path
    return mod
end

shell.setAlias("sol", fs.combine(installPath, "sol.lua"))
