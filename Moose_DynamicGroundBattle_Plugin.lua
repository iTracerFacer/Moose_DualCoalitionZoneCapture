--[[
- **Author**: F99th-TracerFacer
- **Discord:** https://discord.gg/NdZ2JuSU (The Fighting 99th Discord Server where I spend most of my time.)

    Script: Moose_DynamicGroundBattle_Plugin.lua
    Written by: [F99th-TracerFacer]
    Version: 1.0.0
    Date: 15 November 2024
    Description: Warehouse-driven ground unit spawning system that works as a plugin with Moose_DualCoalitionZoneCapture.lua
    
    This script handles:
        - Warehouse-based reinforcement system
        - Dynamic spawn frequency based on warehouse survival
        - Automated AI tasking to patrol nearest enemy zones
        - Zone garrison system (defenders stay in captured zones)
        - Optional infantry patrol control
        - Warehouse status intel markers
        - CTLD troop integration
    
    What this script DOES NOT do:
        - Zone capture logic (handled by Moose_DualCoalitionZoneCapture.lua)
        - Win conditions (handled by Moose_DualCoalitionZoneCapture.lua)
        - Zone coloring/messaging (handled by Moose_DualCoalitionZoneCapture.lua)
    
    Load Order (in Mission Editor Triggers):
        1. DO SCRIPT FILE Moose_.lua
        2. DO SCRIPT FILE Moose_DualCoalitionZoneCapture.lua
        3. DO SCRIPT FILE Moose_DynamicGroundBattle_Plugin.lua  <-- This file
        4. DO SCRIPT FILE CTLD.lua (optional)
        5. DO SCRIPT FILE CSAR.lua (optional)

    Requirements:
        - MOOSE framework must be loaded first
        - Moose_DualCoalitionZoneCapture.lua must be loaded BEFORE this script
        - Zone configuration comes from DualCoalitionZoneCapture's ZONE_CONFIG
        - Groups and warehouses must exist in mission editor (see below)

    Warehouse System & Spawn Frequency Behavior:
        1. Each side has warehouses defined in `redWarehouses` and `blueWarehouses` tables
        2. Spawn frequency dynamically adjusts based on alive warehouses:
           - 100% alive = 100% spawn rate (base frequency)
           - 50% alive = 50% spawn rate (2x delay)
           - 0% alive = no spawns (critical attrition)
        3. Map markers show warehouse locations and nearby units
        4. Updated every UPDATE_MARK_POINTS_SCHED seconds

    AI Task Assignment:
        - Groups spawn in friendly zones
        - Each zone maintains a minimum garrison (defenders) that patrol only their zone
        - Non-defender groups patrol toward nearest enemy zone
        - Election system assigns defenders automatically based on zone needs
        - Defenders are never reassigned and stay permanently in their zone
        - Reassignment occurs every ASSIGN_TASKS_SCHED seconds for non-defenders only
        - Only stationary units get new orders (moving units are left alone)
        - CTLD-dropped troops automatically integrate

    Groups to Create in Mission Editor (all LATE ACTIVATE):
        RED SIDE:
        - Infantry Templates: RedInfantry1, RedInfantry2, RedInfantry3, RedInfantry4, RedInfantry5, RedInfantry6
        - Armor Templates: RedArmor1, RedArmor2, RedArmor3, RedArmor4, RedArmor5, RedArmor6
        - Spawn Groups: Names defined by RED_INFANTRY_SPAWN_GROUP and RED_ARMOR_SPAWN_GROUP variables (default: RedInfantryGroup, RedArmorGroup)
        - Warehouses (Static Objects): RedWarehouse1-1, RedWarehouse2-1, RedWarehouse3-1, etc.
        
        BLUE SIDE:
        - Infantry Templates: BlueInfantry1, BlueInfantry2, BlueInfantry3, BlueInfantry4, BlueInfantry5, BlueInfantry6
        - Armor Templates: BlueArmor1, BlueArmor2, BlueArmor3, BlueArmor4, BlueArmor5
        - Spawn Groups: Names defined by BLUE_INFANTRY_SPAWN_GROUP and BLUE_ARMOR_SPAWN_GROUP variables (default: BlueInfantryGroup, BlueArmorGroup)
        - Warehouses (Static Objects): BlueWarehouse1-1, BlueWarehouse2-1, BlueWarehouse3-1, etc.

        NOTE: Warehouse names use the static "Unit Name" in mission editor, not the "Name" field!
        NOTE: Spawn groups should be simple groups set to LATE ACTIVATE. You can customize their names in the USER CONFIGURATION section.

    Integration with DualCoalitionZoneCapture:
        - This script reads zoneCaptureObjects and zoneNames from DualCoalitionZoneCapture
        - Spawns occur in zones controlled by the appropriate coalition
        - AI tasks units to patrol zones from DualCoalitionZoneCapture's ZONE_CONFIG
--]]
---@diagnostic disable: undefined-global, lowercase-global
-- MOOSE framework globals are defined at runtime by DCS World

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- USER CONFIGURATION SECTION
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Zone Garrison (Defender) Settings
local DEFENDERS_PER_ZONE = 2  -- Minimum number of groups that will garrison each friendly zone (recommended: 2)
local ALLOW_DEFENDER_ROTATION = false  -- If true, fresh units can replace existing defenders when zone is over-garrisoned
local DEFENDER_PATROL_INTERVAL = 3600  -- How often defenders may get a patrol task (seconds, e.g. 3600 = 1 hour)

-- Infantry Patrol Settings
local MOVING_INFANTRY_PATROLS = false  -- Set to false to disable infantry movement (they spawn and hold position)

-- Warehouse Marker Settings
local ENABLE_WAREHOUSE_MARKERS = true  -- Enable/disable warehouse map markers (disabled by default if you have other marker systems)
local UPDATE_MARK_POINTS_SCHED = 300    -- Update warehouse markers every 300 seconds (5 minutes)
local MAX_WAREHOUSE_UNIT_LIST_DISTANCE = 5000  -- Max distance to search for units near warehouses for markers

-- Warehouse Status Message Settings
local ENABLE_WAREHOUSE_STATUS_MESSAGES = true  -- Enable/disable periodic warehouse status announcements
local WAREHOUSE_STATUS_MESSAGE_FREQUENCY = 1800  -- How often to announce warehouse status (seconds, default: 1800 = 30 minutes)

-- Spawn Frequency and Limits
-- Red Side Settings
local INIT_RED_INFANTRY = 15            -- Initial number of Red Infantry groups
local MAX_RED_INFANTRY = 100           -- Maximum number of Red Infantry groups
local SPAWN_SCHED_RED_INFANTRY = 1200  -- Base spawn frequency for Red Infantry (seconds)

local INIT_RED_ARMOR = 30              -- Initial number of Red Armor groups
local MAX_RED_ARMOR = 500              -- Maximum number of Red Armor groups
local SPAWN_SCHED_RED_ARMOR = 200      -- Base spawn frequency for Red Armor (seconds)

-- Blue Side Settings
local INIT_BLUE_INFANTRY = 15           -- Initial number of Blue Infantry groups
local MAX_BLUE_INFANTRY = 100          -- Maximum number of Blue Infantry groups
local SPAWN_SCHED_BLUE_INFANTRY = 1200 -- Base spawn frequency for Blue Infantry (seconds)

local INIT_BLUE_ARMOR = 30             -- Initial number of Blue Armor groups
local MAX_BLUE_ARMOR = 500             -- Maximum number of Blue Armor groups
local SPAWN_SCHED_BLUE_ARMOR = 200     -- Base spawn frequency for Blue Armor (seconds)

local ASSIGN_TASKS_SCHED = 900         -- How often to reassign tasks to idle groups (seconds)

-- Per-side cadence scalars (tune to make one side faster/slower without touching base frequencies)
local RED_INFANTRY_CADENCE_SCALAR = 1.0
local RED_ARMOR_CADENCE_SCALAR = 1.0
local BLUE_INFANTRY_CADENCE_SCALAR = 1.0
local BLUE_ARMOR_CADENCE_SCALAR = 1.0

-- When a side loses every warehouse we pause spawning and re-check after this delay
local NO_WAREHOUSE_RECHECK_DELAY = 180

-- Spawn Group Names (these are the base groups SPAWN:New() uses for spawning)
local RED_INFANTRY_SPAWN_GROUP = "RedInfantryGroup"
local RED_ARMOR_SPAWN_GROUP = "RedArmorGroup"
local BLUE_INFANTRY_SPAWN_GROUP = "BlueInfantryGroup"
local BLUE_ARMOR_SPAWN_GROUP = "BlueArmorGroup"

-- AI Tasking Behavior
-- Note: DCS engine can crash with "CREATING PATH MAKES TOO LONG" if units try to path too far
-- Keep these values conservative to reduce pathfinding load and avoid server crashes
-- OPTIMIZATION: Reduced MAX_ATTACK_DISTANCE from 25km to 20km to reduce pathfinding complexity
local MAX_ATTACK_DISTANCE = 20000 -- Maximum distance in meters for attacking enemy zones. Units won't attack zones farther than this. (20km ≈ 10.8nm)
local ATTACK_RETRY_COOLDOWN = 1800   -- Seconds a group will wait before re-attempting an attack if no valid enemy zone was found (30 minutes)

-- Define warehouses for each side
local redWarehouses = {
    STATIC:FindByName("RedWarehouse1-1"),
    STATIC:FindByName("RedWarehouse2-1"),
    STATIC:FindByName("RedWarehouse3-1"),
    STATIC:FindByName("RedWarehouse4-1"),
    STATIC:FindByName("RedWarehouse5-1"),
    STATIC:FindByName("RedWarehouse6-1"),
    STATIC:FindByName("RedWarehouse7-1"),
}

local blueWarehouses = {
    STATIC:FindByName("BlueWarehouse1-1"),
    STATIC:FindByName("BlueWarehouse2-1"),
    STATIC:FindByName("BlueWarehouse3-1"),
    STATIC:FindByName("BlueWarehouse4-1"),
    STATIC:FindByName("BlueWarehouse5-1"),
    STATIC:FindByName("BlueWarehouse6-1"),
}

-- Define unit templates (these groups must exist in mission editor as LATE ACTIVATE)
local redInfantryTemplates = {
    "RedInfantry1",
    "RedInfantry2",
    "RedInfantry3",
    "RedInfantry4",
    "RedInfantry5",
    "RedInfantry6"
}

local redArmorTemplates = {
    "RedArmor1",
    "RedArmor2",
    "RedArmor3",
    "RedArmor4",
    "RedArmor5",
    "RedArmor6"
}

local blueInfantryTemplates = {
    "BlueInfantry1",
    "BlueInfantry2",
    "BlueInfantry3",
    "BlueInfantry4",
    "BlueInfantry5",
    "BlueInfantry6"
}

local blueArmorTemplates = {
    "BlueArmor1",
    "BlueArmor2",
    "BlueArmor3",
    "BlueArmor4",
    "BlueArmor5"
}



----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- DO NOT EDIT BELOW THIS LINE
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

env.info("[DGB PLUGIN] Dynamic Ground Battle Plugin initializing...")

-- Validate that DualCoalitionZoneCapture is loaded
if not zoneCaptureObjects or not zoneNames then
    env.error("[DGB PLUGIN] ERROR: Moose_DualCoalitionZoneCapture.lua must be loaded BEFORE this plugin!")
    env.error("[DGB PLUGIN] Make sure zoneCaptureObjects and zoneNames are available.")
    return
end

-- Validate warehouses exist
local function ValidateWarehouses(warehouses, label)
    local foundCount = 0
    local missingCount = 0
    
    for i, wh in ipairs(warehouses) do
        if wh then
            foundCount = foundCount + 1
            env.info(string.format("[DGB PLUGIN] %s warehouse %d: %s (OK)", label, i, wh:GetName()))
        else
            missingCount = missingCount + 1
            env.warning(string.format("[DGB PLUGIN] %s warehouse at index %d NOT FOUND in mission editor!", label, i))
        end
    end
    
    env.info(string.format("[DGB PLUGIN] %s warehouses: %d found, %d missing", label, foundCount, missingCount))
    return foundCount > 0
end

-- Validate unit templates exist
local function ValidateTemplates(templates, label)
    local foundCount = 0
    local missingCount = 0
    
    for i, templateName in ipairs(templates) do
        local group = GROUP:FindByName(templateName)
        if group then
            foundCount = foundCount + 1
            env.info(string.format("[DGB PLUGIN] %s template %d: %s (OK)", label, i, templateName))
        else
            missingCount = missingCount + 1
            env.warning(string.format("[DGB PLUGIN] %s template '%s' NOT FOUND in mission editor!", label, templateName))
        end
    end
    
    env.info(string.format("[DGB PLUGIN] %s templates: %d found, %d missing", label, foundCount, missingCount))
    return foundCount > 0
end

env.info("[DGB PLUGIN] Validating configuration...")

-- Validate all warehouses
local redWarehousesValid = ValidateWarehouses(redWarehouses, "Red")
local blueWarehousesValid = ValidateWarehouses(blueWarehouses, "Blue")

if not redWarehousesValid then
    env.warning("[DGB PLUGIN] WARNING: No valid Red warehouses found! Red spawning will be disabled.")
end

if not blueWarehousesValid then
    env.warning("[DGB PLUGIN] WARNING: No valid Blue warehouses found! Blue spawning will be disabled.")
end

-- Validate all templates
local redInfantryValid = ValidateTemplates(redInfantryTemplates, "Red Infantry")
local redArmorValid = ValidateTemplates(redArmorTemplates, "Red Armor")
local blueInfantryValid = ValidateTemplates(blueInfantryTemplates, "Blue Infantry")
local blueArmorValid = ValidateTemplates(blueArmorTemplates, "Blue Armor")

if not redInfantryValid then
    env.warning("[DGB PLUGIN] WARNING: No valid Red Infantry templates found! Red Infantry spawning will fail.")
end

if not redArmorValid then
    env.warning("[DGB PLUGIN] WARNING: No valid Red Armor templates found! Red Armor spawning will fail.")
end

if not blueInfantryValid then
    env.warning("[DGB PLUGIN] WARNING: No valid Blue Infantry templates found! Blue Infantry spawning will fail.")
end

if not blueArmorValid then
    env.warning("[DGB PLUGIN] WARNING: No valid Blue Armor templates found! Blue Armor spawning will fail.")
end

env.info("[DGB PLUGIN] Found " .. #zoneCaptureObjects .. " zones from DualCoalitionZoneCapture")

-- Track active markers to prevent memory leaks
local activeMarkers = {}

-- Zone Garrison Tracking System
-- Structure: zoneGarrisons[zoneName] = { defenders = {groupName1, groupName2, ...}, lastUpdate = timestamp }
local zoneGarrisons = {}

-- Group garrison assignments
-- Structure: groupGarrisonAssignments[groupName] = zoneName (or nil if not a defender)
local groupGarrisonAssignments = {}

-- Track all groups spawned by this plugin
-- Structure: spawnedGroups[groupName] = true
local spawnedGroups = {}

-- Track per-group attack cooldowns to avoid hammering the pathfinder for problematic routes
-- Structure: groupAttackCooldown[groupName] = nextAllowedTime (DCS timer.getTime())
local groupAttackCooldown = {}

-- Reusable SET_GROUP to prevent repeated creation within a single function call
local function getAllGroups()
    -- Only return groups that were spawned by this plugin
    local groupSet = SET_GROUP:New()
    for groupName, _ in pairs(spawnedGroups) do
        local group = GROUP:FindByName(groupName)
        if group and group:IsAlive() then
            groupSet:AddGroup(group)
        else
            -- Clean up dead groups from tracking table to prevent memory bloat
            if group == nil or not group:IsAlive() then
                spawnedGroups[groupName] = nil
                groupGarrisonAssignments[groupName] = nil
                groupAttackCooldown[groupName] = nil
            end
        end
    end
    return groupSet
end

-- Function to get zones controlled by a specific coalition
local function GetZonesByCoalition(targetCoalition)
    local zones = {}
    
    for idx, zoneCapture in ipairs(zoneCaptureObjects) do
        if zoneCapture and zoneCapture:GetCoalition() == targetCoalition then
            local zone = zoneCapture:GetZone()
            if zone then
                table.insert(zones, zone)
            end
        end
    end
    
    env.info(string.format("[DGB PLUGIN] Found %d zones for coalition %d", #zones, targetCoalition))
    return zones
end

-- Helper to count warehouse availability
local function GetWarehouseStats(warehouses)
    local alive = 0
    local total = 0

    for _, warehouse in ipairs(warehouses) do
        if warehouse then
            total = total + 1
            local life = warehouse:GetLife()
            if life and life > 0 then
                alive = alive + 1
            end
        end
    end

    return alive, total
end

-- Function to calculate spawn frequency based on warehouse survival
local function CalculateSpawnFrequency(warehouses, baseFrequency, cadenceScalar)
    local aliveWarehouses, totalWarehouses = GetWarehouseStats(warehouses)
    cadenceScalar = cadenceScalar or 1

    if totalWarehouses == 0 then
        return baseFrequency * cadenceScalar
    end

    if aliveWarehouses == 0 then
        return nil -- Pause spawning until logistics return
    end

    local frequency = baseFrequency * cadenceScalar * (totalWarehouses / aliveWarehouses)
    return frequency
end

-- Function to calculate spawn frequency as a percentage
local function CalculateSpawnFrequencyPercentage(warehouses)
    local aliveWarehouses, totalWarehouses = GetWarehouseStats(warehouses)

    if totalWarehouses == 0 then
        return 0
    end

    local percentage = (aliveWarehouses / totalWarehouses) * 100
    return math.floor(percentage)
end

-- Function to add warehouse markers on the map
local function addMarkPoints(warehouses, coalition)
    for _, warehouse in ipairs(warehouses) do
        if warehouse then
            local warehousePos = warehouse:GetVec3()
            local details
            
            if coalition == 2 then  -- Blue viewing
                if warehouse:GetCoalition() == 2 then
                    details = "Warehouse: " .. warehouse:GetName() .. "\nThis warehouse needs to be protected.\n"
                else
                    details = "Warehouse: " .. warehouse:GetName() .. "\nThis is a primary target as it is directly supplying enemy units.\n"
                end
            elseif coalition == 1 then  -- Red viewing
                if warehouse:GetCoalition() == 1 then
                    details = "Warehouse: " .. warehouse:GetName() .. "\nThis warehouse needs to be protected.\n"
                else
                    details = "Warehouse: " .. warehouse:GetName() .. "\nThis is a primary target as it is directly supplying enemy units.\n"
                end
            end

            local coordinate = COORDINATE:NewFromVec3(warehousePos)
            local marker = MARKER:New(coordinate, details):ToCoalition(coalition):ReadOnly()
            table.insert(activeMarkers, marker)
        end
    end
end

-- Function to update warehouse markers
local function updateMarkPoints()
    -- Clean up old markers first
    for i = #activeMarkers, 1, -1 do
        local marker = activeMarkers[i]
        if marker then
            marker:Remove()
        end
        activeMarkers[i] = nil
    end
    
    addMarkPoints(redWarehouses, 2)   -- Blue coalition sees red warehouses
    addMarkPoints(blueWarehouses, 2)  -- Blue coalition sees blue warehouses
    addMarkPoints(redWarehouses, 1)   -- Red coalition sees red warehouses
    addMarkPoints(blueWarehouses, 1)  -- Red coalition sees blue warehouses
    
    env.info(string.format("[DGB PLUGIN] Updated warehouse markers (%d total)", #activeMarkers))
end

-- Function to check if a group contains infantry units
local function IsInfantryGroup(group)
    for _, unit in ipairs(group:GetUnits()) do
        local unitTypeName = unit:GetTypeName()
        if unitTypeName:find("Infantry") or unitTypeName:find("Soldier") or unitTypeName:find("Paratrooper") then
            return true
        end
    end
    return false
end

-- Function to check if a group is assigned as a zone defender
local function IsDefender(group)
    if not group then return false end
    local groupName = group:GetName()
    return groupGarrisonAssignments[groupName] ~= nil
end

-- Function to get garrison info for a zone
local function GetZoneGarrison(zoneName)
    if not zoneGarrisons[zoneName] then
        zoneGarrisons[zoneName] = {
            defenders = {},
            lastUpdate = timer.getTime()
        }
    end
    return zoneGarrisons[zoneName]
end

-- Function to count alive defenders in a zone
local function CountAliveDefenders(zoneName)
    local garrison = GetZoneGarrison(zoneName)
    local aliveCount = 0
    local deadDefenders = {}
    
    for _, groupName in ipairs(garrison.defenders) do
        local group = GROUP:FindByName(groupName)
        if group and group:IsAlive() then
            aliveCount = aliveCount + 1
        else
            -- Mark for cleanup
            table.insert(deadDefenders, groupName)
        end
    end
    
    -- Clean up dead defenders
    for _, deadGroupName in ipairs(deadDefenders) do
        for i, groupName in ipairs(garrison.defenders) do
            if groupName == deadGroupName then
                table.remove(garrison.defenders, i)
                groupGarrisonAssignments[deadGroupName] = nil
                env.info(string.format("[DGB PLUGIN] Removed destroyed defender %s from zone %s", deadGroupName, zoneName))
                break
            end
        end
    end
    
    return aliveCount
end

-- Function to elect a group as a zone defender
local function ElectDefender(group, zone, reason)
    if not group or not zone then return false end
    
    local groupName = group:GetName()
    local zoneName = zone:GetName()
    
    -- Check if already a defender
    if IsDefender(group) then
        return false
    end
    
    local garrison = GetZoneGarrison(zoneName)
    
    -- Add to garrison
    table.insert(garrison.defenders, groupName)
    groupGarrisonAssignments[groupName] = zoneName
    garrison.lastUpdate = timer.getTime()

    -- Record last patrol time for this defender so we can give them
    -- an occasional "stretch their legs" patrol without hammering pathfinding.
    garrison.lastPatrolTime = garrison.lastPatrolTime or {}
    garrison.lastPatrolTime[groupName] = timer.getTime()

    env.info(string.format("[DGB PLUGIN] Elected %s as defender of zone %s (%s)", groupName, zoneName, reason))
    return true
end

-- Function to check if a zone needs more defenders
local function ZoneNeedsDefenders(zoneName)
    local aliveDefenders = CountAliveDefenders(zoneName)
    return aliveDefenders < DEFENDERS_PER_ZONE
end

-- Function to handle defender rotation (replace old defender with fresh unit)
local function TryDefenderRotation(group, zone)
    if not ALLOW_DEFENDER_ROTATION then return false end
    
    local zoneName = zone:GetName()
    local garrison = GetZoneGarrison(zoneName)
    
    -- Count idle groups in zone (including current group)
    local idleGroups = {}
    local allGroups = getAllGroups()
    
    allGroups:ForEachGroup(function(g)
        if g and g:IsAlive() and g:GetCoalition() == group:GetCoalition() then
            if g:IsCompletelyInZone(zone) then
                local velocity = g:GetVelocityVec3()
                local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
                if speed <= 0.5 then
                    table.insert(idleGroups, g)
                end
            end
        end
    end)
    
    -- Only rotate if we have more than DEFENDERS_PER_ZONE idle units
    if #idleGroups > DEFENDERS_PER_ZONE then
        -- Find oldest defender to replace
        local oldestDefender = nil
        local oldestDefenderGroup = nil
        
        for _, defenderName in ipairs(garrison.defenders) do
            local defenderGroup = GROUP:FindByName(defenderName)
            if defenderGroup and defenderGroup:IsAlive() then
                if not oldestDefender then
                    oldestDefender = defenderName
                    oldestDefenderGroup = defenderGroup
                end
                break -- Just take the first one for rotation
            end
        end
        
        if oldestDefender and oldestDefenderGroup and oldestDefenderGroup:GetName() ~= group:GetName() then
            -- Remove old defender
            for i, defenderName in ipairs(garrison.defenders) do
                if defenderName == oldestDefender then
                    table.remove(garrison.defenders, i)
                    groupGarrisonAssignments[oldestDefender] = nil
                    env.info(string.format("[DGB PLUGIN] Rotated out defender %s from zone %s", oldestDefender, zoneName))
                    break
                end
            end
            
            -- Elect new defender
            ElectDefender(group, zone, "rotation")
            
            -- Old defender becomes mobile force
            return true
        end
    end
    
    return false
end

local function AssignTasks(group, currentZoneCapture)
    -- This function is no longer needed as its logic has been integrated into AssignTasksToGroups
end

-- Function to assign tasks to all groups
local function AssignTasksToGroups()
    env.info("[DGB PLUGIN] ============================================")
    env.info("[DGB PLUGIN] Starting task assignment cycle...")
    local allGroups = getAllGroups()
    local tasksAssigned = 0
    local defendersActive = 0
    local mobileAssigned = 0
    local groupsProcessed = 0
    local groupsSkipped = 0

    -- Create a quick lookup table for zone objects by name
    local zoneLookup = {}
    for _, zc in ipairs(zoneCaptureObjects) do
        local zone = zc:GetZone()
        if zone then
            zoneLookup[zone:GetName()] = { zone = zone, capture = zc }
        end
    end

    allGroups:ForEachGroup(function(group)
        if not group or not group:IsAlive() then return end

        groupsProcessed = groupsProcessed + 1
        local groupName = group:GetName()
        local groupCoalition = group:GetCoalition()
        env.info(string.format("[DGB PLUGIN] Processing group %s (coalition %d)", groupName, groupCoalition))

        -- 1. HANDLE DEFENDERS
        if IsDefender(group) then
            defendersActive = defendersActive + 1

            -- Very slow, in-zone patrol for defenders, at most once per DEFENDER_PATROL_INTERVAL.
            -- This keeps them mostly static while adding some life, without constantly re-pathing.
            local zoneName = groupGarrisonAssignments[groupName]
            local garrison = zoneName and GetZoneGarrison(zoneName) or nil
            local lastPatrolTime = garrison and garrison.lastPatrolTime and garrison.lastPatrolTime[groupName] or 0
            local now = timer.getTime()

            if garrison and zoneName and now - lastPatrolTime >= DEFENDER_PATROL_INTERVAL then
                local zoneInfo = zoneLookup[zoneName]
                if zoneInfo and zoneInfo.zone then
                    env.info(string.format("[DGB PLUGIN] %s: Defender patrol in zone %s", groupName, zoneName))
                    -- Use simpler patrol method to reduce pathfinding memory
                    -- Reduced patrol radius from 0.5 to 0.3 to create simpler paths
                    local zoneCoord = zoneInfo.zone:GetCoordinate()
                    if zoneCoord then
                        local patrolPoint = zoneCoord:GetRandomCoordinateInRadius(zoneInfo.zone:GetRadius() * 0.3)  -- Reduced from 0.5
                        local speed = IsInfantryGroup(group) and 15 or 25 -- km/h - slow patrol
                        group:RouteGroundTo(patrolPoint, speed, "Vee", 1)
                    end
                    garrison.lastPatrolTime[groupName] = now
                    tasksAssigned = tasksAssigned + 1
                else
                    env.info(string.format("[DGB PLUGIN] %s: Defender holding (zone not found)", groupName))
                end
            else
                env.info(string.format("[DGB PLUGIN] %s: Defender holding (patrol not due)", groupName))
            end

            return -- Defenders do not get any other tasks
        end

        -- 2. HANDLE MOBILE FORCES (NON-DEFENDERS)

        -- Skip infantry if movement is disabled
        if IsInfantryGroup(group) and not MOVING_INFANTRY_PATROLS then
            env.info(string.format("[DGB PLUGIN] %s: Skipped (infantry movement disabled)", groupName))
            groupsSkipped = groupsSkipped + 1
            return
        end

        -- Don't reassign if already moving
        local velocity = group:GetVelocityVec3()
        local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
        env.info(string.format("[DGB PLUGIN] %s: Current speed %.2f m/s", groupName, speed))
        if speed > 0.5 then
            env.info(string.format("[DGB PLUGIN] %s: Skipped (already moving)", groupName))
            groupsSkipped = groupsSkipped + 1
            return
        end

        -- Find which zone the group is in
        local currentZone = nil
        local currentZoneCapture = nil
        for _, zc in ipairs(zoneCaptureObjects) do
            local zone = zc:GetZone()
            if zone and group:IsCompletelyInZone(zone) then
                currentZone = zone
                currentZoneCapture = zc
                break
            end
        end

        -- 3. HANDLE GROUPS IN FRIENDLY ZONES
        if currentZone and currentZoneCapture and currentZoneCapture:GetCoalition() == groupCoalition then
            local zoneName = currentZone:GetName()
            
            -- PRIORITY 1: If the zone is under attack, all non-defenders should help defend it
            local zoneState = currentZoneCapture.GetCurrentState and currentZoneCapture:GetCurrentState() or nil
            if zoneState == "Attacked" then
                env.info(string.format("[DGB PLUGIN] %s defending contested zone %s", groupName, zoneName))
                -- Use simpler routing to reduce pathfinding memory
                local zoneCoord = currentZone:GetCoordinate()
                if zoneCoord then
                    local defendPoint = zoneCoord:GetRandomCoordinateInRadius(currentZone:GetRadius() * 0.6)
                    local speed = IsInfantryGroup(group) and 30 or 50 -- km/h - faster response
                    group:RouteGroundTo(defendPoint, speed, "Vee", 2)
                end
                tasksAssigned = tasksAssigned + 1
                mobileAssigned = mobileAssigned + 1
                return
            end
            
            -- PRIORITY 2: Elect as defender if zone needs one (before attacking)
            if ZoneNeedsDefenders(zoneName) then
                if ElectDefender(group, currentZone, "zone under-garrisoned") then
                    tasksAssigned = tasksAssigned + 1
                    defendersActive = defendersActive + 1
                    return
                end
            end
            
            -- PRIORITY 3: Defender rotation (if enabled and zone is over-garrisoned)
            if TryDefenderRotation(group, currentZone) then
                tasksAssigned = tasksAssigned + 1
                defendersActive = defendersActive + 1
                return -- Rotated in as a defender, task is set
            end
        end

        -- 4. PATROL TO NEAREST ENEMY ZONE (for all mobile forces, regardless of current location)
        -- Respect per-group attack cooldown to avoid hammering the pathfinder for problematic routes
        local now = timer.getTime()
        local nextAllowed = groupAttackCooldown[groupName]
        if nextAllowed and now < nextAllowed then
            env.info(string.format("[DGB PLUGIN] %s: Attack on cooldown for another %.0fs", groupName, nextAllowed - now))
            groupsSkipped = groupsSkipped + 1
            return
        end

        local closestEnemyZone = nil
        local closestDistance = math.huge
        local groupCoordinate = group:GetCoordinate()

        for _, zc in ipairs(zoneCaptureObjects) do
            local zoneCoalition = zc:GetCoalition()
            if zoneCoalition ~= groupCoalition and zoneCoalition ~= coalition.side.NEUTRAL then
                local zone = zc:GetZone()
                if zone then
                    local distance = groupCoordinate:Get2DDistance(zone:GetCoordinate())
                    if distance < closestDistance and distance <= MAX_ATTACK_DISTANCE then
                        closestDistance = distance
                        closestEnemyZone = zone
                    end
                end
            end
        end

        if closestEnemyZone then
            env.info(string.format("[DGB PLUGIN] %s: Attacking enemy zone %s (%.1fkm away)", 
                groupName, closestEnemyZone:GetName(), closestDistance / 1000))
            
            -- Use simpler waypoint-based routing instead of TaskRouteToZone to reduce pathfinding memory load
            -- This prevents the "CREATING PATH MAKES TOO LONG" memory buildup
            -- Reduced radius from 0.7 to 0.5 to create simpler, shorter paths
            local zoneCoord = closestEnemyZone:GetCoordinate()
            if zoneCoord then
                local randomPoint = zoneCoord:GetRandomCoordinateInRadius(closestEnemyZone:GetRadius() * 0.5)  -- Reduced from 0.7
                local speed = IsInfantryGroup(group) and 20 or 40 -- km/h
                group:RouteGroundTo(randomPoint, speed, "Vee", 1)
            end
            
            tasksAssigned = tasksAssigned + 1
            mobileAssigned = mobileAssigned + 1
            return -- Task assigned, done with this group
        end
        
        -- 5. FALLBACK: No valid enemy zone within range - set cooldown to avoid repeated failed attempts
        groupAttackCooldown[groupName] = now + ATTACK_RETRY_COOLDOWN
        if closestDistance > MAX_ATTACK_DISTANCE and closestDistance < math.huge then
            env.info(string.format("[DGB PLUGIN] %s: No enemy zones within range (closest is %.1fkm away, max is %.1fkm). Putting attacks on cooldown for %ds", 
                groupName, closestDistance / 1000, MAX_ATTACK_DISTANCE / 1000, ATTACK_RETRY_COOLDOWN))
        else
            env.info(string.format("[DGB PLUGIN] %s: No tasks available (no enemy zones found). Putting attacks on cooldown for %ds", groupName, ATTACK_RETRY_COOLDOWN))
        end
    end)

    env.info(string.format("[DGB PLUGIN] Task assignment complete. Processed: %d, Skipped: %d, Tasked: %d (%d defenders, %d mobile)", 
        groupsProcessed, groupsSkipped, tasksAssigned, defendersActive, mobileAssigned))
    env.info("[DGB PLUGIN] ============================================")
end

-- Function to monitor and announce warehouse status
local function MonitorWarehouses()
    local blueWarehousesAlive, blueWarehouseTotal = GetWarehouseStats(blueWarehouses)
    local redWarehousesAlive, redWarehouseTotal = GetWarehouseStats(redWarehouses)

    local redSpawnFrequencyPercentage = CalculateSpawnFrequencyPercentage(redWarehouses)
    local blueSpawnFrequencyPercentage = CalculateSpawnFrequencyPercentage(blueWarehouses)

    if ENABLE_WAREHOUSE_STATUS_MESSAGES then
        local msg = "[Warehouse Status]\n"
        msg = msg .. "Red warehouses alive: " .. redWarehousesAlive .. " Reinforcements: " .. redSpawnFrequencyPercentage .. "%\n"
        msg = msg .. "Blue warehouses alive: " .. blueWarehousesAlive .. " Reinforcements: " .. blueSpawnFrequencyPercentage .. "%\n"
        MESSAGE:New(msg, 30):ToAll()
    end
    
    env.info(string.format("[DGB PLUGIN] Warehouse status - Red: %d/%d (%d%%), Blue: %d/%d (%d%%)",
        redWarehousesAlive, redWarehouseTotal, redSpawnFrequencyPercentage,
        blueWarehousesAlive, blueWarehouseTotal, blueSpawnFrequencyPercentage))
end

-- Function to count active units by coalition and type
local function CountActiveUnits(targetCoalition)
    local infantry = 0
    local armor = 0
    local total = 0
    local defenders = 0
    local mobile = 0
    
    local allGroups = getAllGroups()
    
    allGroups:ForEachGroup(function(group)
        if group and group:IsAlive() and group:GetCoalition() == targetCoalition then
            total = total + 1
            
            if IsDefender(group) then
                defenders = defenders + 1
            else
                mobile = mobile + 1
            end
            
            if IsInfantryGroup(group) then
                infantry = infantry + 1
            else
                armor = armor + 1
            end
        end
    end)
    
    return {
        total = total,
        infantry = infantry,
        armor = armor,
        defenders = defenders,
        mobile = mobile
    }
end

-- Function to get garrison status across all zones
local function GetGarrisonStatus(targetCoalition)
    local garrisonedZones = 0
    local underGarrisonedZones = 0
    local totalFriendlyZones = 0
    
    for idx, zoneCapture in ipairs(zoneCaptureObjects) do
        if zoneCapture:GetCoalition() == targetCoalition then
            totalFriendlyZones = totalFriendlyZones + 1
            local zone = zoneCapture:GetZone()
            if zone then
                local zoneName = zone:GetName()
                local defenderCount = CountAliveDefenders(zoneName)
                
                if defenderCount >= DEFENDERS_PER_ZONE then
                    garrisonedZones = garrisonedZones + 1
                else
                    underGarrisonedZones = underGarrisonedZones + 1
                end
            end
        end
    end
    
    return {
        totalZones = totalFriendlyZones,
        garrisoned = garrisonedZones,
        underGarrisoned = underGarrisonedZones
    }
end

-- Function to display comprehensive system statistics
local function ShowSystemStatistics(playerCoalition)
    -- Get warehouse stats
    local redWarehousesAlive, redWarehouseTotal = GetWarehouseStats(redWarehouses)
    local blueWarehousesAlive, blueWarehouseTotal = GetWarehouseStats(blueWarehouses)
    
    -- Get unit counts
    local redUnits = CountActiveUnits(coalition.side.RED)
    local blueUnits = CountActiveUnits(coalition.side.BLUE)
    
    -- Get garrison info
    local redGarrison = GetGarrisonStatus(coalition.side.RED)
    local blueGarrison = GetGarrisonStatus(coalition.side.BLUE)
    
    -- Get spawn frequencies
    local redSpawnFreqPct = CalculateSpawnFrequencyPercentage(redWarehouses)
    local blueSpawnFreqPct = CalculateSpawnFrequencyPercentage(blueWarehouses)
    
    -- Calculate actual spawn intervals
    local redInfantryInterval = CalculateSpawnFrequency(redWarehouses, SPAWN_SCHED_RED_INFANTRY, RED_INFANTRY_CADENCE_SCALAR)
    local redArmorInterval = CalculateSpawnFrequency(redWarehouses, SPAWN_SCHED_RED_ARMOR, RED_ARMOR_CADENCE_SCALAR)
    local blueInfantryInterval = CalculateSpawnFrequency(blueWarehouses, SPAWN_SCHED_BLUE_INFANTRY, BLUE_INFANTRY_CADENCE_SCALAR)
    local blueArmorInterval = CalculateSpawnFrequency(blueWarehouses, SPAWN_SCHED_BLUE_ARMOR, BLUE_ARMOR_CADENCE_SCALAR)
    
    -- Build comprehensive report
    local msg = "═══════════════════════════════════════\n"
    msg = msg .. "DYNAMIC GROUND BATTLE - SYSTEM STATUS\n"
    msg = msg .. "═══════════════════════════════════════\n\n"
    
    -- Configuration Section
    msg = msg .. "【CONFIGURATION】\n"
    msg = msg .. "  Defenders per Zone: " .. DEFENDERS_PER_ZONE .. "\n"
    msg = msg .. "  Defender Rotation: " .. (ALLOW_DEFENDER_ROTATION and "ENABLED" or "DISABLED") .. "\n"
    msg = msg .. "  Infantry Movement: " .. (MOVING_INFANTRY_PATROLS and "ENABLED" or "DISABLED") .. "\n"
    msg = msg .. "  Task Reassignment: Every " .. ASSIGN_TASKS_SCHED .. "s\n"
    msg = msg .. "  Warehouse Markers: " .. (ENABLE_WAREHOUSE_MARKERS and "ENABLED" or "DISABLED") .. "\n\n"
    
    -- Spawn Limits Section
    msg = msg .. "【SPAWN LIMITS】\n"
    msg = msg .. "  Red Infantry: " .. INIT_RED_INFANTRY .. "/" .. MAX_RED_INFANTRY .. "\n"
    msg = msg .. "  Red Armor: " .. INIT_RED_ARMOR .. "/" .. MAX_RED_ARMOR .. "\n"
    msg = msg .. "  Blue Infantry: " .. INIT_BLUE_INFANTRY .. "/" .. MAX_BLUE_INFANTRY .. "\n"
    msg = msg .. "  Blue Armor: " .. INIT_BLUE_ARMOR .. "/" .. MAX_BLUE_ARMOR .. "\n\n"
    
    -- Red Coalition Section
    msg = msg .. "【RED COALITION】\n"
    msg = msg .. "  Warehouses: " .. redWarehousesAlive .. "/" .. redWarehouseTotal .. " (" .. redSpawnFreqPct .. "%)\n"
    msg = msg .. "  Active Units: " .. redUnits.total .. " (" .. redUnits.infantry .. " inf, " .. redUnits.armor .. " armor)\n"
    msg = msg .. "  Defenders: " .. redUnits.defenders .. " | Mobile: " .. redUnits.mobile .. "\n"
    msg = msg .. "  Controlled Zones: " .. redGarrison.totalZones .. "\n"
    msg = msg .. "    - Garrisoned: " .. redGarrison.garrisoned .. "\n"
    msg = msg .. "    - Under-Garrisoned: " .. redGarrison.underGarrisoned .. "\n"
    
    if redInfantryInterval then
        msg = msg .. "  Infantry Spawn: " .. math.floor(redInfantryInterval) .. "s\n"
    else
        msg = msg .. "  Infantry Spawn: PAUSED (no warehouses)\n"
    end
    
    if redArmorInterval then
        msg = msg .. "  Armor Spawn: " .. math.floor(redArmorInterval) .. "s\n\n"
    else
        msg = msg .. "  Armor Spawn: PAUSED (no warehouses)\n\n"
    end
    
    -- Blue Coalition Section
    msg = msg .. "【BLUE COALITION】\n"
    msg = msg .. "  Warehouses: " .. blueWarehousesAlive .. "/" .. blueWarehouseTotal .. " (" .. blueSpawnFreqPct .. "%)\n"
    msg = msg .. "  Active Units: " .. blueUnits.total .. " (" .. blueUnits.infantry .. " inf, " .. blueUnits.armor .. " armor)\n"
    msg = msg .. "  Defenders: " .. blueUnits.defenders .. " | Mobile: " .. blueUnits.mobile .. "\n"
    msg = msg .. "  Controlled Zones: " .. blueGarrison.totalZones .. "\n"
    msg = msg .. "    - Garrisoned: " .. blueGarrison.garrisoned .. "\n"
    msg = msg .. "    - Under-Garrisoned: " .. blueGarrison.underGarrisoned .. "\n"
    
    if blueInfantryInterval then
        msg = msg .. "  Infantry Spawn: " .. math.floor(blueInfantryInterval) .. "s\n"
    else
        msg = msg .. "  Infantry Spawn: PAUSED (no warehouses)\n"
    end
    
    if blueArmorInterval then
        msg = msg .. "  Armor Spawn: " .. math.floor(blueArmorInterval) .. "s\n\n"
    else
        msg = msg .. "  Armor Spawn: PAUSED (no warehouses)\n\n"
    end
    
    -- System Info
    msg = msg .. "【SYSTEM INFO】\n"
    msg = msg .. "  Total Zones: " .. #zoneCaptureObjects .. "\n"
    msg = msg .. "  Active Garrisons: " .. (redGarrison.garrisoned + blueGarrison.garrisoned) .. "\n"
    msg = msg .. "  Total Active Units: " .. (redUnits.total + blueUnits.total) .. "\n"
    
    -- Memory and Performance Tracking
    local totalSpawnedGroups = 0
    for _ in pairs(spawnedGroups) do
        totalSpawnedGroups = totalSpawnedGroups + 1
    end
    
    local luaMemoryKB = collectgarbage("count")
    msg = msg .. "  Tracked Groups: " .. totalSpawnedGroups .. "\n"
    msg = msg .. "  Lua Memory: " .. string.format("%.1f MB", luaMemoryKB / 1024) .. "\n"
    
    -- Warning if memory is high
    if luaMemoryKB > 512000 then -- More than 500MB
        msg = msg .. "  ⚠️ WARNING: High memory usage!\n"
    end
    
    -- Warning if too many groups
    if totalSpawnedGroups > 200 then
        msg = msg .. "  ⚠️ WARNING: High group count!\n"
    end
    
    msg = msg .. "\n"
    msg = msg .. "═══════════════════════════════════════"
    
    MESSAGE:New(msg, 45):ToCoalition(playerCoalition)
    
    env.info("[DGB PLUGIN] System statistics displayed to coalition " .. playerCoalition)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Get initial zone lists for each coalition
local redZones = GetZonesByCoalition(coalition.side.RED)
local blueZones = GetZonesByCoalition(coalition.side.BLUE)

-- Calculate and display initial spawn frequency percentages
local redSpawnFrequencyPercentage = CalculateSpawnFrequencyPercentage(redWarehouses)
local blueSpawnFrequencyPercentage = CalculateSpawnFrequencyPercentage(blueWarehouses)

MESSAGE:New("Red reinforcement capacity: " .. redSpawnFrequencyPercentage .. "%", 30):ToRed()
MESSAGE:New("Blue reinforcement capacity: " .. blueSpawnFrequencyPercentage .. "%", 30):ToBlue()

-- Initialize spawners
env.info("[DGB PLUGIN] Initializing spawn systems...")

-- Note: Spawn zones will be dynamically updated based on zone capture states
-- We'll use a function to get current friendly zones on each spawn
local function GetRedZones()
    return GetZonesByCoalition(coalition.side.RED)
end

local function GetBlueZones()
    return GetZonesByCoalition(coalition.side.BLUE)
end

-- Validate spawn groups exist before creating spawners
local spawnGroups = {
    {name = RED_INFANTRY_SPAWN_GROUP, label = "Red Infantry Spawn Group"},
    {name = RED_ARMOR_SPAWN_GROUP, label = "Red Armor Spawn Group"},
    {name = BLUE_INFANTRY_SPAWN_GROUP, label = "Blue Infantry Spawn Group"},
    {name = BLUE_ARMOR_SPAWN_GROUP, label = "Blue Armor Spawn Group"}
}

for _, spawnGroup in ipairs(spawnGroups) do
    local group = GROUP:FindByName(spawnGroup.name)
    if group then
        env.info(string.format("[DGB PLUGIN] %s '%s' found (OK)", spawnGroup.label, spawnGroup.name))
    else
        env.error(string.format("[DGB PLUGIN] ERROR: %s '%s' NOT FOUND! Create this group in mission editor as LATE ACTIVATE.", spawnGroup.label, spawnGroup.name))
    end
end

-- Red Infantry Spawner
redInfantrySpawn = SPAWN:New(RED_INFANTRY_SPAWN_GROUP)
    :InitRandomizeTemplate(redInfantryTemplates)
    :InitLimit(INIT_RED_INFANTRY, MAX_RED_INFANTRY)

-- Red Armor Spawner
redArmorSpawn = SPAWN:New(RED_ARMOR_SPAWN_GROUP)
    :InitRandomizeTemplate(redArmorTemplates)
    :InitLimit(INIT_RED_ARMOR, MAX_RED_ARMOR)

-- Blue Infantry Spawner
blueInfantrySpawn = SPAWN:New(BLUE_INFANTRY_SPAWN_GROUP)
    :InitRandomizeTemplate(blueInfantryTemplates)
    :InitLimit(INIT_BLUE_INFANTRY, MAX_BLUE_INFANTRY)

-- Blue Armor Spawner
blueArmorSpawn = SPAWN:New(BLUE_ARMOR_SPAWN_GROUP)
    :InitRandomizeTemplate(blueArmorTemplates)
    :InitLimit(INIT_BLUE_ARMOR, MAX_BLUE_ARMOR)

-- Helper to schedule spawns per category. This is a self-rescheduling function.
local function ScheduleSpawner(spawnObject, getZonesFn, warehouses, baseFrequency, label, cadenceScalar)
    local function spawnAndReschedule()
        -- Calculate the next spawn interval first
        local spawnInterval = CalculateSpawnFrequency(warehouses, baseFrequency, cadenceScalar)

        if not spawnInterval then
            -- No warehouses. Pause spawning and check again after the delay.
            env.info(string.format("[DGB PLUGIN] %s spawn paused (no warehouses). Rechecking in %ds.", label, NO_WAREHOUSE_RECHECK_DELAY))
            SCHEDULER:New(nil, spawnAndReschedule, {}, NO_WAREHOUSE_RECHECK_DELAY)
            return
        end

        -- Get friendly zones
        local friendlyZones = getZonesFn()
        if #friendlyZones > 0 then
            local chosenZone = friendlyZones[math.random(#friendlyZones)]
            local spawnedGroup = spawnObject:SpawnInZone(chosenZone, true)
            
            if spawnedGroup then
                local groupName = spawnedGroup:GetName()
                spawnedGroups[groupName] = true
                env.info(string.format("[DGB PLUGIN] Spawned %s in zone %s. Task assignment will occur on next cycle.", 
                    groupName, chosenZone:GetName()))
            end
        else
            env.info(string.format("[DGB PLUGIN] %s spawn skipped (no friendly zones).", label))
        end

        -- Schedule the next run
        SCHEDULER:New(nil, spawnAndReschedule, {}, spawnInterval)
        env.info(string.format("[DGB PLUGIN] Next %s spawn scheduled in %d seconds.", label, math.floor(spawnInterval)))
    end

    -- Kick off the first spawn with a random delay to stagger the different spawners
    local initialDelay = math.random(5, 15)
    SCHEDULER:New(nil, spawnAndReschedule, {}, initialDelay)
    env.info(string.format("[DGB PLUGIN] %s spawner initialized. First check in %d seconds.", label, initialDelay))
end

-- Schedule spawns (each spawner now runs at its own configured cadence)
if redInfantryValid and redWarehousesValid then
    ScheduleSpawner(redInfantrySpawn, GetRedZones, redWarehouses, SPAWN_SCHED_RED_INFANTRY, "Red Infantry", RED_INFANTRY_CADENCE_SCALAR)
end
if redArmorValid and redWarehousesValid then
    ScheduleSpawner(redArmorSpawn, GetRedZones, redWarehouses, SPAWN_SCHED_RED_ARMOR, "Red Armor", RED_ARMOR_CADENCE_SCALAR)
end
if blueInfantryValid and blueWarehousesValid then
    ScheduleSpawner(blueInfantrySpawn, GetBlueZones, blueWarehouses, SPAWN_SCHED_BLUE_INFANTRY, "Blue Infantry", BLUE_INFANTRY_CADENCE_SCALAR)
end
if blueArmorValid and blueWarehousesValid then
    ScheduleSpawner(blueArmorSpawn, GetBlueZones, blueWarehouses, SPAWN_SCHED_BLUE_ARMOR, "Blue Armor", BLUE_ARMOR_CADENCE_SCALAR)
end

-- Schedule warehouse marker updates
if ENABLE_WAREHOUSE_MARKERS then
    SCHEDULER:New(nil, updateMarkPoints, {}, 10, UPDATE_MARK_POINTS_SCHED)
end

-- Schedule warehouse monitoring
if ENABLE_WAREHOUSE_STATUS_MESSAGES then
    SCHEDULER:New(nil, MonitorWarehouses, {}, 30, WAREHOUSE_STATUS_MESSAGE_FREQUENCY)
end

-- Comprehensive cleanup function to prevent memory accumulation
local function CleanupStaleData()
    local cleanedGroups = 0
    local cleanedCooldowns = 0
    local cleanedGarrisons = 0
    
    -- Clean up spawnedGroups, groupGarrisonAssignments, and groupAttackCooldown
    for groupName, _ in pairs(spawnedGroups) do
        local group = GROUP:FindByName(groupName)
        if not group or not group:IsAlive() then
            spawnedGroups[groupName] = nil
            cleanedGroups = cleanedGroups + 1
            
            if groupGarrisonAssignments[groupName] then
                groupGarrisonAssignments[groupName] = nil
            end
            
            if groupAttackCooldown[groupName] then
                groupAttackCooldown[groupName] = nil
                cleanedCooldowns = cleanedCooldowns + 1
            end
        end
    end
    
    -- Clean up garrison data for zones that changed ownership or have stale defenders
    for zoneName, garrison in pairs(zoneGarrisons) do
        local zoneStillExists = false
        local currentZoneCoalition = nil
        
        -- Check if zone still exists and get its current owner
        for _, zc in ipairs(zoneCaptureObjects) do
            local zone = zc:GetZone()
            if zone and zone:GetName() == zoneName then
                zoneStillExists = true
                currentZoneCoalition = zc:GetCoalition()
                break
            end
        end
        
        if not zoneStillExists then
            -- Zone doesn't exist anymore, clean up all garrison data
            for _, defenderName in ipairs(garrison.defenders) do
                groupGarrisonAssignments[defenderName] = nil
            end
            zoneGarrisons[zoneName] = nil
            cleanedGarrisons = cleanedGarrisons + 1
        else
            -- Zone exists, clean up dead defenders from the garrison list
            local deadDefenders = {}
            for i, defenderName in ipairs(garrison.defenders) do
                local group = GROUP:FindByName(defenderName)
                if not group or not group:IsAlive() then
                    table.insert(deadDefenders, i)
                    groupGarrisonAssignments[defenderName] = nil
                end
            end
            
            -- Remove dead defenders in reverse order to maintain indices
            for i = #deadDefenders, 1, -1 do
                table.remove(garrison.defenders, deadDefenders[i])
            end
            
            -- Clean up lastPatrolTime for dead defenders
            if garrison.lastPatrolTime then
                for defenderName, _ in pairs(garrison.lastPatrolTime) do
                    local group = GROUP:FindByName(defenderName)
                    if not group or not group:IsAlive() then
                        garrison.lastPatrolTime[defenderName] = nil
                    end
                end
            end
        end
    end
    
    -- Force aggressive Lua garbage collection to reclaim memory
    -- Step-based collection helps ensure thorough cleanup
    collectgarbage("collect")  -- Full collection
    collectgarbage("collect")  -- Second pass to catch finalized objects
    
    if cleanedGroups > 0 or cleanedCooldowns > 0 or cleanedGarrisons > 0 then
        env.info(string.format("[DGB PLUGIN] Cleanup: Removed %d groups, %d cooldowns, %d garrisons", 
            cleanedGroups, cleanedCooldowns, cleanedGarrisons))
    end
end

-- Optional periodic memory usage logging (Lua-only; shows in dcs.log)
local ENABLE_MEMORY_LOGGING = true
local MEMORY_LOG_INTERVAL = 600 -- seconds (10 minutes) - reduced from 15 minutes
local CLEANUP_INTERVAL = 300 -- seconds (5 minutes) - reduced from 10 minutes for more aggressive cleanup

local function LogMemoryUsage()
    -- Force garbage collection before measuring to get accurate readings
    collectgarbage("collect")
    
    local luaMemoryKB = collectgarbage("count")
    local luaMemoryMB = luaMemoryKB / 1024

    local totalSpawnedGroups = 0
    for _ in pairs(spawnedGroups) do
        totalSpawnedGroups = totalSpawnedGroups + 1
    end
    
    local totalCooldowns = 0
    for _ in pairs(groupAttackCooldown) do
        totalCooldowns = totalCooldowns + 1
    end
    
    local totalGarrisons = 0
    local totalDefenders = 0
    for _, garrison in pairs(zoneGarrisons) do
        totalGarrisons = totalGarrisons + 1
        totalDefenders = totalDefenders + #garrison.defenders
    end

    local msg = string.format("[DGB PLUGIN] Memory: Lua=%.1f MB, Groups=%d, Cooldowns=%d, Garrisons=%d, Defenders=%d", 
        luaMemoryMB, totalSpawnedGroups, totalCooldowns, totalGarrisons, totalDefenders)
    env.info(msg)
end

if ENABLE_MEMORY_LOGGING then
    SCHEDULER:New(nil, LogMemoryUsage, {}, 60, MEMORY_LOG_INTERVAL)
end

-- Schedule periodic cleanup
SCHEDULER:New(nil, CleanupStaleData, {}, 120, CLEANUP_INTERVAL)

-- Schedule task assignments (runs quickly at start, then every ASSIGN_TASKS_SCHED seconds)
SCHEDULER:New(nil, AssignTasksToGroups, {}, 15, ASSIGN_TASKS_SCHED)

-- Add F10 menu for manual checks (using MenuManager if available)
if MenuManager then
    -- Create coalition-specific menus under Mission Options
    local blueMenu = MenuManager.CreateCoalitionMenu(coalition.side.BLUE, "Ground Battle")
    MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Check Warehouse Status", blueMenu, MonitorWarehouses)
    MENU_COALITION_COMMAND:New(coalition.side.BLUE, "Show System Statistics", blueMenu, function()
        ShowSystemStatistics(coalition.side.BLUE)
    end)
    
    local redMenu = MenuManager.CreateCoalitionMenu(coalition.side.RED, "Ground Battle")
    MENU_COALITION_COMMAND:New(coalition.side.RED, "Check Warehouse Status", redMenu, MonitorWarehouses)
    MENU_COALITION_COMMAND:New(coalition.side.RED, "Show System Statistics", redMenu, function()
        ShowSystemStatistics(coalition.side.RED)
    end)
else
    -- Fallback to root-level mission menu
    local missionMenu = MENU_MISSION:New("Ground Battle")
    MENU_MISSION_COMMAND:New("Check Warehouse Status", missionMenu, MonitorWarehouses)
    MENU_MISSION_COMMAND:New("Show Blue Statistics", missionMenu, function()
        ShowSystemStatistics(coalition.side.BLUE)
    end)
    MENU_MISSION_COMMAND:New("Show Red Statistics", missionMenu, function()
        ShowSystemStatistics(coalition.side.RED)
    end)
end

env.info("[DGB PLUGIN] Dynamic Ground Battle Plugin initialized successfully!")
env.info(string.format("[DGB PLUGIN] Zone garrison system: %d defenders per zone", DEFENDERS_PER_ZONE))
env.info(string.format("[DGB PLUGIN] Defender rotation: %s", ALLOW_DEFENDER_ROTATION and "ENABLED" or "DISABLED"))
env.info(string.format("[DGB PLUGIN] Infantry movement: %s", MOVING_INFANTRY_PATROLS and "ENABLED" or "DISABLED"))
env.info(string.format("[DGB PLUGIN] Warehouse markers: %s", ENABLE_WAREHOUSE_MARKERS and "ENABLED" or "DISABLED"))
