local DEV_SERVER_URL = "http://localhost:56748/run-queue"

print "GMod Workspace loading"

local function cofetch(url, headers)
    local co = coroutine.running()
    assert(co)

    -- ensure we wait at least one tick
    timer.Simple(0, function()
        http.Fetch(url, function(body, size, headers, code)
            coroutine.resume(co, body, size, headers, code)
        end, function(err)
            coroutine.resume(co, false, err)
        end, headers)
    end)

    return coroutine.yield()
end

local function cosleep(secs)
    local co = coroutine.running()
    assert(co)

    timer.Simple(secs, function()
        coroutine.resume(co)
    end)

    coroutine.yield()
end

local active, passive

function active(version, callback)
    print "[GModDev] Active scanning enabled"

    while true do
        if __gmod_workspace_v ~= version then
            print "[GModDev] New workspace loop detected"
            return
        end
        local res = cofetch(DEV_SERVER_URL)
        if res then
            callback(util.JSONToTable(res))
        else
            break
        end
        cosleep(1)
    end
    return passive(version, callback)
end

-- Passively scan the URL for an available HTTP server
function passive(version, callback)
    print "[GModDev] Reducing to passive scanning"

    while true do
        if __gmod_workspace_v ~= version then
            print "[GModDev] New workspace loop detected"
            return
        end
        local res = cofetch(DEV_SERVER_URL)
        if res then
            callback(util.JSONToTable(res))
            break
        end
        cosleep(15)
    end
    return active(version, callback)
end

local function processCommands(cmds)
    --print(util.TableToJSON(cmds))
    for _,cmd in pairs(cmds) do
        if cmd.path then
            local src = file.Read(cmd.path, "GAME")
            print("[GModDev] running ", cmd.path, "on", cmd.type)
            if cmd.type == "file-server" then
                luadev.RunOnServer(src, cmd.path)
            elseif cmd.type == "file-shared" then
                luadev.RunOnShared(src, cmd.path)
            elseif cmd.type == "file-clients" then
                luadev.RunOnClients(src, cmd.path)
            else
                print("unsupported cmd type", cmd.type)
            end
        end
    end
end

-- Create a global so that GC doesn't bite us
__gmod_workspace_v = math.random()
__gmod_workspace_co = coroutine.create(function()
    passive(__gmod_workspace_v, processCommands)
end)
coroutine.resume(__gmod_workspace_co)
