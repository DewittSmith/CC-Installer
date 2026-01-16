local REGISTRIES_PATH = "registries"

local CONFIG_FILE = "sol.config"
local HEADERS = {
    ["User-Agent"] = "Sol-Package-Manager"
}

local function filename_without_extension(path)
    return path:match("([^/]+)%.%w+$") or path
end

if not http.checkURL("https://www.google.com/") then
    error("HTTP client not available. Please enable it in the ComputerCraft settings.")
end

local config = {
    registries = {}
}

for _, file in ipairs(fs.list(REGISTRIES_PATH)) do
    local path = fs.combine(REGISTRIES_PATH, file)
    local registry = dofile(path)
    local name = filename_without_extension(file)
    config.registries[name] = registry
end

if fs.exists(CONFIG_FILE) then
    local file = fs.open(CONFIG_FILE, "r")
    local localConfig = file.readAll()
    file.close()

    localConfig = textutils.unserialise(localConfig)
    error("Local config loading not yet implemented.")
end

for name, registry in pairs(config.registries) do
    registry.name = name
end

-- Convert a format pattern into a Lua pattern and capture variable names
local function parse_format(format)
    local vars = {}
    local pattern = format
    pattern = pattern:gsub("[%.%-%+%[%]%(%)%^%$%%]", "%%%1")
    pattern = pattern:gsub("{([^}]+)}", function(varname)
        table.insert(vars, varname)
        return "([^/]+)"
    end)

    pattern = pattern .. "$"
    return pattern, vars
end

-- Try to match a target string against a format pattern
local function match_format(target, format)
    local pattern, vars = parse_format(format)
    local captures = { target:match(pattern) }
    if #captures == 0 then
        return nil
    end

    local result = {}
    for i, varname in ipairs(vars) do
        result[varname] = captures[i]
    end

    return result
end

-- Try to match against multiple format patterns
local function reverse_interpolate(target, formats)
    for i, format in ipairs(formats) do
        local result = match_format(target, format)
        if result then
            return result, i  -- Also return the index of matched format
        end
    end

    return nil, nil
end

-- Format a URL template with the extracted arguments
local function format_url(template, args)
    local result = template
    for key, value in pairs(args) do
        result = result:gsub("{" .. key .. "}", value)
    end

    return result
end

-- Parse target and generate URL
local function target_to_url(target, targets)
    for _, target_config in ipairs(targets) do
        local args = match_format(target, target_config.format)
        if args then
            local url = format_url(target_config.api, args)
            return url, nil, args
        end
    end

    return nil, "No matching format found"
end

local function install_url(registry, inputs)
    local package = registry.load_package(inputs)
    if not package.include then package.include = { } end
    if #package.include == 0 then table.insert(package.include, "%.lua$") end
    if package.main then table.insert(package.include, package.main) end
    if not package.exclude then package.exclude = { } end
    package.is_included = function(path)
        if path == nil or path == "" then return false end

        for _, pattern in ipairs(package.include or {}) do
            if not path:match(pattern) then return false end
        end

        for _, pattern in ipairs(package.exclude or {}) do
            if path:match(pattern) then return false end
        end

        return true
    end

    print("Installing package " .. package.package .. " by " .. package.author .. " (version: " .. package.version .. ")")

    local pathPrefix = fs.combine("packages", registry.name, package.package .. "@" .. package.author, package.version)
    for path, url in registry.list_files(package, inputs) do
        print("Downloading " .. path .. "...")

        local request = http.get(url)
        if not request then 
            error("Failed to download file from " .. url) 
        end

        if request.getResponseCode() ~= 200 then
            error("Failed to download file from " .. url .. " (response code " .. request.getResponseCode() .. ")")
        end

        local content = request.readAll()
        request.close()        

        local fullPath = fs.combine(pathPrefix, path)
        local file = fs.open(fullPath, "w")
        file.write(content)
        file.close()
    end
end

local function install(package, registry)
    if package == nil or package == "" then
        error("No package specified.")
    end

    print("Installing package:")
    print(package)

    if registry then
        if type(registry) == "string" then
            registry = config.registries[registry]
            if not registry then
                error("Registry not found: " .. tostring(registry))
            end
        elseif type(registry) ~= "table" then
            error("Invalid registry specified.")
        end

        local apiUrl, err, inputs = target_to_url(package, registry.targets)
        if apiUrl then
            install_url(registry, inputs)
        else
            error("No matching format found in registry: " .. registry.name)
        end
    else
        for _, registry in pairs(config.registries) do
            local apiUrl, err, inputs = target_to_url(package, registry.targets)
            if apiUrl then
                install_url(registry, inputs)
                break
            end
        end
    end
end

local function parseCommand(cmd)
    if cmd[1] == "install" then
        install(cmd[2])
    elseif #cmd == 0 or cmd[1] == "sol" then
        return {
            install = install
        }
    else
        error("Unknown command: " .. tostring(cmd[1]))
    end
end

return parseCommand({ ... })