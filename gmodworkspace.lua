AddCSLuaFile()

-- from https://github.com/wyozi/g-ace/blob/master/lua/gace/util/entitypath.lua
local entitypath = {}

local folder_ent_names = {
    ["cl_init"] = "cl",
    ["init"] = "sv",
    ["shared"] = "sh",
}

local gm_subentityfolders = {
    ["entities"] = "entity",
    ["weapons"] = "weapon",
    ["effects"] = "effect",
}

function entitypath.Analyze(path)
    -- if it's a folder ent in other folder with specified name, use that
    local folder, file = string.match(path, ".-([^/]+)/([^/]+)%.lua$")
    if folder and file and folder_ent_names[file] then
        return "entity", folder, folder_ent_names[file]
    end

    -- if it's a one-file entity
    if folder and file and gm_subentityfolders[folder] then
        return gm_subentityfolders[folder], file, "sh"
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
    if folder and file and gm_subentityfolders[folder] then
        local realm = "sh"
        if folder == "effects" then
            realm = "cl"
        end
        return gm_subentityfolders[folder], file, realm
    end
end

local sluaTemplate = {
    weapon = [[
        local SWEP = weapons.GetStored("${entname}") or { t = {} }
        SWEP.Primary = SWEP.Primary or {}
        SWEP.Secondary = SWEP.Secondary or {}
        ${code}
        weapons.Register(SWEP, "${entname}", true)
    ]],
    entity = [[ _OLDENT = ENT; ENT = scripted_ents.GetStored("${entname}") or { t = {} }; ENT = ENT.t;
    ${code}
    scripted_ents.Register(ENT, "${entname}")
    ENT = _OLDENT;
    _OLDENT = nil;
    ]],
    effect = [[
        local EFFECT = effects.Create("${entname}") or {}
        ${code}
        effects.Register(EFFECT, "${entname}")
    ]]
}

-- source: http://lua-users.org/wiki/StringInterpolation
local function interp(s, tab)
    return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

local function RunLua(src, path)
    local specialType, specialId, specialRealm =
        entitypath.Analyze(path)

    local template = specialType and sluaTemplate[specialType]
    if template then
        print("[GModWorkspace] ", path, "recognized as", specialType)
        src = interp(template, {code = src, entname = specialId})
    end

    local func = CompileString(src, path, false)
    if type(func) == "string" then
        print("[GModWorkspace] script ", path, " compilation failed: ", func)
    else
        GMODWS_UPDATE = true
        local b, err = xpcall(function()
            func()
        end, debug.traceback)
        GMODWS_UPDATE = nil
        if not b then
            print("[GModWorkspace] script ", path, " errored: ", err)
        end
    end
end

if SERVER then

    util.AddNetworkString("gmodwslua")

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
        print "[GModWorkspace] Active scanning enabled"

        while true do
            if __gmod_workspace_v ~= version then
                print "[GModWorkspace] New workspace loop detected"
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
        print "[GModWorkspace] Reducing to passive scanning"

        while true do
            if __gmod_workspace_v ~= version then
                print "[GModWorkspace] New workspace loop detected"
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

                    if cmd.type == "file-server" or cmd.type == "file-shared" then
                        RunLua(src, cmd.path)
                    end
                    if cmd.type == "file-shared" or cmd.type == "file-clients" then
                        net.Start("gmodwslua")
                        net.WriteString(src)
                        net.WriteString(cmd.path)
                        net.Broadcast()
                    end
                    
                    if cmd.type == "file-self" then
                        local admins = {}
                        for _,p in pairs(player.GetAll()) do
                            if p:IsSuperAdmin() then
                                table.insert(admins, p)
                            end
                        end
                        if #admins > 0 then
                            net.Start("gmodwslua")
                            net.WriteString(src)
                            net.WriteString(cmd.path)
                            net.Send(admins)
                        end
                    end
                else
                    print("[GModDev] did not find ", cmd.path)
                end
            elseif cmd.script then
                print("[GModDev] running a script on", cmd.type)
                local src = cmd.script

                if cmd.type == "script-server" or cmd.type == "script-shared" then
                    RunLua(src, "gmod-workspace-script")
                end
                if cmd.type == "script-shared" or cmd.type == "script-clients" then
                    net.Start("gmodwslua")
                    net.WriteString(src)
                    net.WriteString("gmod-workspace-script")
                    net.Broadcast()
                end                
                if cmd.type == "script-self" then
                    local admins = {}
                    for _,p in pairs(player.GetAll()) do
                        if p:IsSuperAdmin() then
                            table.insert(admins, p)
                        end
                    end
                    if #admins > 0 then
                        net.Start("gmodwslua")
                        net.WriteString(src)
                        net.WriteString("gmod-workspace-script")
                        net.Send(admins)
                    end
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
            print("[GModWorkspace] Coroutine error: ", err)
        end
    end)
    coroutine.resume(__gmod_workspace_co)
else
    assert(CLIENT)
    net.Receive("gmodwslua", function()
        local lua = net.ReadString()
        local path = net.ReadString()

        RunLua(lua, path)
    end)
end
