local SOL_URL = "https://raw.githubusercontent.com/DewittSmith/sol/refs/heads/main/sol.lua"
local GH_REGISTRY_URL = "https://raw.githubusercontent.com/DewittSmith/sol/refs/heads/main/registries/github.lua"

local function read_file(url)
    local response = http.get(url, HEADERS)
    if not response then error("Failed to fetch URL: " .. url) end
    local content = response.readAll()
    response.close()
    return content
end

local registry = read_file(GH_REGISTRY_URL)
registry = assert(loadstring(registry))()

local sol = read_file(SOL_URL)
sol = assert(loadstring(sol))()

sol.install("https://github.com/DewittSmith/sol", registry)