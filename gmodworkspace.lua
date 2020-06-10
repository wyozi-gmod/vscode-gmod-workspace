local DEV_SERVER_URL = "http://localhost:56748/run-queue"

print "GMod Workspace loading"

-- from https://github.com/wyozi/g-ace/blob/master/lua/gace/util/entitypath.lua
local entitypath = {}

local folder_ent_names = {
	["cl_init"] = "cl",
	["init"] = "sv",
	["shared"] = "sh",
}

local gm_subentityfolders = {
	["entities"] = true,
	["weapons"] = true,
	["effects"] = true,
}

function entitypath.Analyze(path)
	-- if it's a folder ent in other folder with specified name, use that
	local folder, file = string.match(path, ".-([^/]+)/([^/]+)%.lua$")
	if folder and file and folder_ent_names[file] then
		return "entity", folder, folder_ent_names[file]
	end
	
	-- try to find a folder entity in entities folder
	-- in this case we can even skip the folder_ent_names and guess the realm
	local folder, file = string.match(path, ".-/entities/([^/]+)/([^/]+)%.lua$")
	if folder and file and not gm_subentityfolders[folder] then
		local realm = "sh"
		if string.match(file, "^cl_") then
			realm = "cl"
		elseif string.match(file, "^sv_") then
			realm = "sv"
		end
		return "entity", folder, realm
	end
end

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
    for _,cmd in pairs(cmds) do
        if cmd.path then
            local src = file.Read(cmd.path, "GAME")
            if src then
                print("[GModDev] running ", cmd.path, "on", cmd.type)

                local specialType, specialId, specialRealm =
                    entitypath.Analyze(cmd.path)

                local extras =
                    specialType == "entity" and {sent = specialId} or
                    specialType == "effect" and {effect = specialId} or
                    specialType == "weapon" and {swep = specialId} or nil

                if cmd.type == "file-server" then
                    luadev.RunOnServer(src, cmd.path, extras)
                elseif cmd.type == "file-shared" then
                    luadev.RunOnShared(src, cmd.path, extras)
                elseif cmd.type == "file-clients" then
                    luadev.RunOnClients(src, cmd.path, extras)
                elseif cmd.type == "file-self" then
                    -- TODO more robust self finding
                
                    local ply
                    for _,p in pairs(player.GetAll()) do
                        if p:IsSuperAdmin() then
                            ply = p
                            break
                        end
                    end
                    luadev.RunOnClient(src, ply, cmd.path, extras)
                else
                    print("[GModDev] unsupported path cmd type", cmd.type)
                end
            else
                print("[GModDev] did not find ", cmd.path)
            end
        elseif cmd.script then
            print("[GModDev] running a script on", cmd.type)
            if cmd.type == "script-server" then
                luadev.RunOnServer(cmd.script, "gmod-workspace-sv")
            elseif cmd.type == "script-shared" then
                luadev.RunOnShared(cmd.script, "gmod-workspace-sh")
            elseif cmd.type == "script-clients" then
                luadev.RunOnClients(cmd.script, "gmod-workspace-cl")
            elseif cmd.type == "script-self" then
                -- TODO more robust self finding

                local ply
                for _,p in pairs(player.GetAll()) do
                    if p:IsSuperAdmin() then
                        ply = p
                        break
                    end
                end
                luadev.RunOnClient(cmd.script, ply, "gmod-workspace-self")
            else
                print("[GModDev] unsupported path cmd type", cmd.type)
            end
        end
    end
end

-- Create a global so that GC doesn't bite us
__gmod_workspace_v = math.random()
__gmod_workspace_co = coroutine.create(function()
    local b, err = xpcall(function()
        passive(__gmod_workspace_v, processCommands)
    end, debug.traceback)
    if not b then
        print("[GModDev] Coroutine error: ", err)
    end
end)
coroutine.resume(__gmod_workspace_co)
