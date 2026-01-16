local API = "https://api.github.com/repos/%s/%s/contents"

local function read_file(url)
    local content = http.get(url)
    if not content then error("Failed to read file from " .. url) end
    local responseCode = content.getResponseCode()
    if responseCode ~= 200 then error("Failed to read file from " .. url .. " (response code " .. responseCode .. ")") end
    local data = content.readAll()
    content.close()
    return data
end

local function load_package(inputs)
    local result = {
        author = inputs.owner,
        package = inputs.name,
        version = "unknown"
    }

    local url = string.format(API, inputs.owner, inputs.name) .. "/package.json"
    if inputs.ref then url = url .. "?ref=" .. inputs.ref end

    local success, metadata = pcall(read_file, url)
    if not success then return result end
    metadata = textutils.unserialiseJSON(metadata)

    local success, packageData = pcall(read_file, metadata.download_url)
    if not success then return result end
    packageData = textutils.unserialiseJSON(packageData)

    for k, v in pairs(packageData) do 
        result[k] = v
    end

    return result
end

local function list_files(package, inputs)
    local url = string.format(API, inputs.owner, inputs.name)
    if inputs.ref then url = url .. "?ref=" .. inputs.ref end

    local tree = read_file(url)
    tree = textutils.unserialiseJSON(tree)

    local function download(entry)
        if not package.is_included(entry.path) then return end

        local co = coroutine.create(function()
            if entry.type == "dir" then
                local dir = read_file(entry.url)
                dir = textutils.unserialiseJSON(dir)
                for _, subentry in pairs(dir) do 
                    for path, url in download(subentry) do
                        coroutine.yield(path, url)
                    end
                end
            elseif entry.type == "file" then
                coroutine.yield(entry.path, entry.download_url)
            end
        end)

        return function()
            local success, path, url = coroutine.resume(co)
            if not success then error("Error downloading file: " .. path) end
            return path, url
        end
    end

    local co = coroutine.create(function()
        for _, entry in pairs(tree) do
            for path, url in download(entry) do
                coroutine.yield(path, url)
            end
        end
    end)

    return function()
        local success, path, url = coroutine.resume(co)
        if not success then error("Error listing files: " .. path) end
        return path, url
    end
end

return {
    load_package = load_package,
    list_files = list_files,
    inputs = {
        "github.com/{owner}/{name}",
        "github.com/{owner}/{name}/tree/{ref}",
    },
}