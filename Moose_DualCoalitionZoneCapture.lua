-- Refactored version with configurable zone ownership
---@diagnostic disable: undefined-global, lowercase-global
-- MOOSE framework globals are defined at runtime by DCS World
-- **Author**: F99th-TracerFacer
-- **Discord:** https://discord.gg/NdZ2JuSU (The Fighting 99th Discord Server where I spend most of my time.)


-- ==========================================
-- MESSAGE AND TIMING CONFIGURATION
-- ==========================================
local MESSAGE_CONFIG = {
  STATUS_BROADCAST_FREQUENCY = 3602,     -- Zone status broadcast cadence (seconds)
  STATUS_BROADCAST_START_DELAY = 10,     -- Delay before first broadcast (seconds)
  COLOR_VERIFICATION_FREQUENCY = 240,    -- Zone color verification cadence (seconds)
  COLOR_VERIFICATION_START_DELAY = 60,   -- Delay before first color check (seconds)
  TACTICAL_UPDATE_FREQUENCY = 180,       -- Tactical marker update cadence (seconds)
  TACTICAL_UPDATE_START_DELAY = 30,      -- Delay before first tactical update (seconds)
  STATUS_MESSAGE_DURATION = 15,          -- How long general status messages stay onscreen
  VICTORY_MESSAGE_DURATION = 300,        -- How long victory/defeat alerts stay onscreen
  CAPTURE_MESSAGE_DURATION = 15,         -- Duration for capture/guard/empty notices
  ATTACK_MESSAGE_DURATION = 15           -- Duration for attack alerts
}

-- ==========================================
-- ZONE COLOR CONFIGURATION (Centralized)
-- ==========================================
-- Colors are in RGB format: {Red, Green, Blue} where each value is 0.0 to 1.0
local ZONE_COLORS = {
  -- Blue coalition zones
  BLUE_CAPTURED = {0, 0, 1},        -- Blue (owned by Blue)
  BLUE_ATTACKED = {0, 1, 1},        -- Cyan (owned by Blue, under attack)

  -- Red coalition zones  
  RED_CAPTURED = {1, 0, 0},         -- Red (owned by Red)
  RED_ATTACKED = {1, 0.5, 0},       -- Orange (owned by Red, under attack)

  -- Neutral/Empty zones
  EMPTY = {0, 1, 0}                 -- Green (no owner)
}

-- Helper to get the appropriate color for a zone based on state/ownership
local function GetZoneColor(zoneCapture)
  local zoneCoalition = zoneCapture:GetCoalition()
  local state = zoneCapture:GetCurrentState()

  -- Priority 1: Attacked overrides ownership color
  if state == "Attacked" then
    if zoneCoalition == coalition.side.BLUE then
      return ZONE_COLORS.BLUE_ATTACKED
    elseif zoneCoalition == coalition.side.RED then
      return ZONE_COLORS.RED_ATTACKED
    end
  end

  -- Priority 2: Empty/neutral
  if state == "Empty" then
    return ZONE_COLORS.EMPTY
  end

  -- Priority 3: Ownership color
  if zoneCoalition == coalition.side.BLUE then
    return ZONE_COLORS.BLUE_CAPTURED
  elseif zoneCoalition == coalition.side.RED then
    return ZONE_COLORS.RED_CAPTURED
  end

  -- Fallback
  return ZONE_COLORS.EMPTY
end

-- ==========================================
-- ZONE CONFIGURATION
-- ==========================================
-- Mission makers: Edit this table to define zones and their initial ownership
-- Just list the zone names under RED, BLUE, or NEUTRAL coalition
-- The script will automatically create and configure all zones
-- Make sure the zone names match exactly with those defined in the mission editor
-- Zones must be defined in the mission editor as trigger zones named "Capture <ZoneName>"
-- Note: Red/Blue/Neutral zones defined below are only setting their initial ownership state.
-- If there are existing units in the zone at mission start, ownership may change based on unit presence.


local ZONE_CONFIG = {
  -- Zones that start under RED coalition control
  -- IMPORTANT: Use the EXACT zone names from the mission editor (including "Capture " prefix if present)
  RED = {
    "Capture Zone-1",
    "Capture Zone-2",
    "Capture Zone-3",
    
    -- Add more zone names here for RED starting zones
  },
  
  -- Zones that start under BLUE coalition control
  BLUE = {
    "Capture Zone-4",
    "Capture Zone-5",
    "Capture Zone-6",
  },
  
  -- Zones that start neutral (empty/uncontrolled)
  NEUTRAL = {

  }
}

-- Advanced settings (usually don't need to change these)
local ZONE_SETTINGS = {
  guardDelay = 1,        -- Delay before entering Guard state after capture
  scanInterval = 30,     -- How often to scan for units in the zone (seconds)
  captureScore = 200     -- Points awarded for capturing a zone
}

-- ==========================================
-- END OF CONFIGURATION
-- ==========================================

-- Build Command Center and Mission for Blue Coalition
local blueHQ = GROUP:FindByName("BLUEHQ")
if blueHQ then
    US_CC = COMMANDCENTER:New(blueHQ, "USA HQ")
    US_Mission = MISSION:New(US_CC, "Zone Capture Example Mission", "Primary", "", coalition.side.BLUE)
    US_Score = SCORING:New("Zone Capture Example Mission")
    --US_Mission:AddScoring(US_Score)
    --US_Mission:Start()
    env.info("Blue Coalition Command Center and Mission started successfully")
else
    env.info("ERROR: BLUEHQ group not found! Blue mission will not start.")
end

--Build Command Center and Mission Red
local redHQ = GROUP:FindByName("REDHQ")
if redHQ then
    RU_CC = COMMANDCENTER:New(redHQ, "Russia HQ")
    RU_Mission = MISSION:New(RU_CC, "Zone Capture Example Mission", "Primary", "Hold what we have, take what we don't.", coalition.side.RED)
    --RU_Score = SCORING:New("Zone Capture Example Mission")
    --RU_Mission:AddScoring(RU_Score)
    RU_Mission:Start()
    env.info("Red Coalition Command Center and Mission started successfully")
else
    env.info("ERROR: REDHQ group not found! Red mission will not start.")
end


-- Setup BLUE Missions 
do -- BLUE Mission
  
  US_Mission_Capture_Airfields = MISSION:New( US_CC, "Capture the Zones", "Primary",
    "Capture the Zones marked on your F10 map.\n" ..
    "Destroy enemy ground forces in the surrounding area, " ..
    "then occupy each capture zone with a platoon.\n " .. 
    "Your orders are to hold position until all capture zones are taken.\n" ..
    "Use the map (F10) for a clear indication of the location of each capture zone.\n" ..
    "Note that heavy resistance can be expected at the airbases!\n"
    , coalition.side.BLUE)
    
  --US_Score = SCORING:New( "Capture Airfields" )
    
  --US_Mission_Capture_Airfields:AddScoring( US_Score )
  
  US_Mission_Capture_Airfields:Start()

end

-- Setup RED Missions
do -- RED Mission
  
  RU_Mission_Capture_Airfields = MISSION:New( RU_CC, "Defend the Motherland", "Primary",
    "Defend Russian airfields and recapture lost territory.\n" ..
    "Eliminate enemy forces in capture zones and " ..
    "maintain control with ground units.\n" .. 
    "Your orders are to prevent the enemy from capturing all strategic zones.\n" ..
    "Use the map (F10) for a clear indication of the location of each capture zone.\n" ..
    "Expect heavy NATO resistance!\n"
    , coalition.side.RED)
    
  --RU_Score = SCORING:New( "Defend Territory" )
    
  --RU_Mission_Capture_Airfields:AddScoring( RU_Score )
  
  RU_Mission_Capture_Airfields:Start()

end


-- Logging configuration: toggle logging behavior for this module
-- Set `CAPTURE_ZONE_LOGGING.enabled = false` to silence module logs
if not CAPTURE_ZONE_LOGGING then
  CAPTURE_ZONE_LOGGING = { enabled = false, prefix = "[CAPTURE Module]" }
end

local function log(message, detailed)
  if CAPTURE_ZONE_LOGGING.enabled then
    -- Preserve the previous prefixing used across the module
    if CAPTURE_ZONE_LOGGING.prefix then
      env.info(tostring(CAPTURE_ZONE_LOGGING.prefix) .. " " .. tostring(message))
    else
      env.info(tostring(message))
    end
  end
end


-- ==========================================
-- ZONE INITIALIZATION SYSTEM
-- ==========================================

-- Storage for all zone capture objects and metadata
-- NOTE: These are exported as globals for plugin compatibility (e.g., Moose_DynamicGroundBattle_Plugin.lua)
zoneCaptureObjects = {}  -- Global: accessible by other scripts
zoneNames = {}           -- Global: accessible by other scripts
local zoneMetadata = {} -- Stores coalition ownership info

-- Function to initialize all zones from configuration
local function InitializeZones()
  log("[INIT] Starting zone initialization from configuration...")
  
  local totalZones = 0
  
  -- Process each coalition's zones
  for coalitionName, zones in pairs(ZONE_CONFIG) do
    local coalitionSide = nil
    
    -- Map coalition name to DCS coalition constant
    if coalitionName == "RED" then
      coalitionSide = coalition.side.RED
    elseif coalitionName == "BLUE" then
      coalitionSide = coalition.side.BLUE
    elseif coalitionName == "NEUTRAL" then
      coalitionSide = coalition.side.NEUTRAL
    else
      log(string.format("[INIT] WARNING: Unknown coalition '%s' in ZONE_CONFIG", coalitionName))
    end
    
    if coalitionSide then
      for _, zoneName in ipairs(zones) do
        log(string.format("[INIT] Creating zone: %s (Coalition: %s)", zoneName, coalitionName))
        
        -- Create the MOOSE zone object (using exact name from config)
        local zone = ZONE:New(zoneName)
        
        if zone then
          -- Create the zone capture coalition object
          local zoneCapture = ZONE_CAPTURE_COALITION:New(zone, coalitionSide)
          
          if zoneCapture then
            -- Configure the zone
            zoneCapture:__Guard(ZONE_SETTINGS.guardDelay)
            zoneCapture:Start(ZONE_SETTINGS.scanInterval, ZONE_SETTINGS.scanInterval)
            
            -- Store in our data structures
            table.insert(zoneCaptureObjects, zoneCapture)
            table.insert(zoneNames, zoneName)
            zoneMetadata[zoneName] = {
              coalition = coalitionSide,
              index = #zoneCaptureObjects
            }
            
            totalZones = totalZones + 1
            log(string.format("[INIT] ✓ Zone '%s' initialized successfully", zoneName))
          else
            log(string.format("[INIT] ✗ ERROR: Failed to create ZONE_CAPTURE_COALITION for '%s'", zoneName))
          end
        else
          log(string.format("[INIT] ✗ ERROR: Zone '%s' not found in mission editor!", zoneName))
          log(string.format("[INIT]    Make sure you have a trigger zone named exactly: '%s'", zoneName))
        end
      end
    end
  end
  
  log(string.format("[INIT] Zone initialization complete. Total zones created: %d", totalZones))
  return totalZones
end

-- Initialize all zones
local totalZones = InitializeZones()


-- Global cached unit set - created once and maintained automatically by MOOSE
local CachedUnitSet = nil

-- Utility guard to safely test whether a unit is inside a zone without throwing
local function IsUnitInZone(unit, zone)
  if not unit or not zone then
    return false
  end

  local ok, point = pcall(function()
    return unit:GetPointVec3()
  end)

  if not ok or not point then
    return false
  end

  local inZone = false
  pcall(function()
    inZone = zone:IsPointVec3InZone(point)
  end)

  return inZone
end

-- Initialize the cached unit set once
local function InitializeCachedUnitSet()
  if not CachedUnitSet then
    CachedUnitSet = SET_UNIT:New()
      :FilterCategories({"ground", "plane", "helicopter"}) -- Only scan relevant unit types
      :FilterStart() -- Keep the set updated by MOOSE without recreating it
    log("[PERFORMANCE] Initialized cached unit set for zone scanning")
  end
end

local function GetZoneForceStrengths(ZoneCapture)
  if not ZoneCapture then
    return { red = 0, blue = 0, neutral = 0 }
  end

  local success, zone = pcall(function()
    return ZoneCapture:GetZone()
  end)

  if not success or not zone then
    return { red = 0, blue = 0, neutral = 0 }
  end

  local redCount = 0
  local blueCount = 0
  local neutralCount = 0

  InitializeCachedUnitSet()

  if CachedUnitSet then
    CachedUnitSet:ForEachUnit(function(unit)
      if unit and unit:IsAlive() and IsUnitInZone(unit, zone) then
        local unitCoalition = unit:GetCoalition()
        if unitCoalition == coalition.side.RED then
          redCount = redCount + 1
        elseif unitCoalition == coalition.side.BLUE then
          blueCount = blueCount + 1
        elseif unitCoalition == coalition.side.NEUTRAL then
          neutralCount = neutralCount + 1
        end
      end
    end)
  end

  log(string.format("[TACTICAL] Zone %s scan result: R:%d B:%d N:%d",
    ZoneCapture:GetZoneName(), redCount, blueCount, neutralCount))

  return {
    red = redCount,
    blue = blueCount,
    neutral = neutralCount
  }
end

local function GetEnemyUnitMGRSCoords(ZoneCapture, enemyCoalition)
  if not ZoneCapture or not enemyCoalition then
    return {}
  end

  local success, zone = pcall(function()
    return ZoneCapture:GetZone()
  end)

  if not success or not zone then
    return {}
  end

  InitializeCachedUnitSet()

  local coords = {}
  local totalUnits = 0
  local enemyUnits = 0
  local unitsWithCoords = 0

  if CachedUnitSet then
    CachedUnitSet:ForEachUnit(function(unit)
      if unit and unit:IsAlive() and IsUnitInZone(unit, zone) then
        totalUnits = totalUnits + 1
        local unitCoalition = unit:GetCoalition()

        if unitCoalition == enemyCoalition then
          enemyUnits = enemyUnits + 1
          local coord = unit:GetCoordinate()

          if coord then
            local mgrs = nil
            local success_mgrs = false

            success_mgrs, mgrs = pcall(function()
              return coord:ToStringMGRS(5)
            end)

            if not success_mgrs or not mgrs then
              success_mgrs, mgrs = pcall(function()
                return coord:ToStringMGRS()
              end)
            end

            if not success_mgrs or not mgrs then
              success_mgrs, mgrs = pcall(function()
                return coord:ToMGRS()
              end)
            end

            if not success_mgrs or not mgrs then
              success_mgrs, mgrs = pcall(function()
                local lat, lon = coord:GetLLDDM()
                return string.format("N%s E%s", lat, lon)
              end)
            end

            if success_mgrs and mgrs then
              unitsWithCoords = unitsWithCoords + 1
              local unitType = unit:GetTypeName() or "Unknown"
              table.insert(coords, {
                name = unit:GetName(),
                type = unitType,
                mgrs = mgrs
              })
            else
              log(string.format("[TACTICAL DEBUG] All coordinate methods failed for unit %s", unit:GetName() or "unknown"))
            end
          else
            log(string.format("[TACTICAL DEBUG] No coordinate for unit %s", unit:GetName() or "unknown"))
          end
        end
      end
    end)
  end

  log(string.format("[TACTICAL DEBUG] %s - Total units scanned: %d, Enemy units: %d, units with MGRS: %d",
    ZoneCapture:GetZoneName(), totalUnits, enemyUnits, unitsWithCoords))

  log(string.format("[TACTICAL] Found %d enemy units with coordinates in %s",
    #coords, ZoneCapture:GetZoneName()))

  return coords
end

local function CreateTacticalInfoMarker(ZoneCapture)
  -- Validate ZoneCapture
  if not ZoneCapture then 
    log("[TACTICAL ERROR] ZoneCapture object is nil")
    return 
  end

  -- Safely get the zone with error handling
  local ok, zone = pcall(function() return ZoneCapture:GetZone() end)
  if not ok or not zone then 
    log("[TACTICAL ERROR] Failed to get zone from ZoneCapture object")
    return 
  end

  local forces = GetZoneForceStrengths(ZoneCapture)
  local zoneName = ZoneCapture:GetZoneName()

  -- Build coalition-specific tactical info text
  local function buildTacticalText(viewerCoalition)
    local text = string.format("TACTICAL: %s\nForces: R:%d B:%d", zoneName, forces.red, forces.blue)
    if forces.neutral and forces.neutral > 0 then
      text = text .. string.format(" C:%d", forces.neutral)
    end

    -- Append TGTS for the enemy of the viewer, capped at 10 units
    local enemyCoalition = (viewerCoalition == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
    local enemyCount = (enemyCoalition == coalition.side.RED) and (forces.red or 0) or (forces.blue or 0)
    if enemyCount > 0 and enemyCount <= 10 then
      local enemyCoords = GetEnemyUnitMGRSCoords(ZoneCapture, enemyCoalition)
      log(string.format("[TACTICAL DEBUG] Building marker text for %s viewer: %d enemy units", (viewerCoalition==coalition.side.BLUE and "BLUE" or "RED"), #enemyCoords))
      if #enemyCoords > 0 then
        text = text .. "\nTGTS:"
        for i, unit in ipairs(enemyCoords) do
          if i <= 10 then
            local shortType = (unit.type or "Unknown"):gsub("^%w+%-", ""):gsub("%s.*", "")
            local cleanMgrs = (unit.mgrs or ""):gsub("^MGRS%s+", ""):gsub("%s+", " ")
            if i == 1 then
              text = text .. string.format(" %s@%s", shortType, cleanMgrs)
            else
              text = text .. string.format(", %s@%s", shortType, cleanMgrs)
            end
          end
        end
        if #enemyCoords > 10 then
          text = text .. string.format(" (+%d)", #enemyCoords - 10)
        end
      end
    end

    return text
  end

  local tacticalTextBLUE = buildTacticalText(coalition.side.BLUE)
  local tacticalTextRED  = buildTacticalText(coalition.side.RED)

  -- Debug: Log what will be displayed
  log(string.format("[TACTICAL DEBUG] Marker text (BLUE) for %s:\n%s", zoneName, tacticalTextBLUE))
  log(string.format("[TACTICAL DEBUG] Marker text (RED)  for %s:\n%s", zoneName, tacticalTextRED))

  -- Create tactical marker offset from zone center
  local coord = zone:GetCoordinate()
  if coord then
    local offsetCoord = coord:Translate(200, 45) -- 200m NE

    local function removeMarker(markerID)
      if not markerID then
        return
      end

      local removed = pcall(function()
        offsetCoord:RemoveMark(markerID)
      end)

      if not removed then
        removed = pcall(function()
          trigger.action.removeMark(markerID)
        end)
      end

      if not removed then
        pcall(function()
          coord:RemoveMark(markerID)
        end)
      end
    end

    -- Remove legacy single marker if present
    if ZoneCapture.TacticalMarkerID then
      log(string.format("[TACTICAL] Removing old marker ID %d for %s", ZoneCapture.TacticalMarkerID, zoneName))
      removeMarker(ZoneCapture.TacticalMarkerID)
      ZoneCapture.TacticalMarkerID = nil
    end

    -- BLUE Coalition Marker
    if ZoneCapture.TacticalMarkerID_BLUE then
      log(string.format("[TACTICAL] Removing old BLUE marker ID %d for %s", ZoneCapture.TacticalMarkerID_BLUE, zoneName))
      removeMarker(ZoneCapture.TacticalMarkerID_BLUE)
      ZoneCapture.TacticalMarkerID_BLUE = nil
    end
    local successBlue, markerIDBlue = pcall(function()
      return offsetCoord:MarkToCoalition(tacticalTextBLUE, coalition.side.BLUE)
    end)
    if successBlue and markerIDBlue then
      ZoneCapture.TacticalMarkerID_BLUE = markerIDBlue
      pcall(function() offsetCoord:SetMarkReadOnly(markerIDBlue, true) end)
      log(string.format("[TACTICAL] Created BLUE marker for %s", zoneName))
    else
      log(string.format("[TACTICAL] Failed to create BLUE marker for %s", zoneName))
    end

    -- RED Coalition Marker
    if ZoneCapture.TacticalMarkerID_RED then
      log(string.format("[TACTICAL] Removing old RED marker ID %d for %s", ZoneCapture.TacticalMarkerID_RED, zoneName))
      removeMarker(ZoneCapture.TacticalMarkerID_RED)
      ZoneCapture.TacticalMarkerID_RED = nil
    end
    local successRed, markerIDRed = pcall(function()
      return offsetCoord:MarkToCoalition(tacticalTextRED, coalition.side.RED)
    end)
    if successRed and markerIDRed then
      ZoneCapture.TacticalMarkerID_RED = markerIDRed
      pcall(function() offsetCoord:SetMarkReadOnly(markerIDRed, true) end)
      log(string.format("[TACTICAL] Created RED marker for %s", zoneName))
    else
      log(string.format("[TACTICAL] Failed to create RED marker for %s", zoneName))
    end
  end
end

-- Event handler functions - define them separately for each zone
local function OnEnterGuarded(ZoneCapture, From, Event, To)
  if From ~= To then
    local Coalition = ZoneCapture:GetCoalition()
    if Coalition == coalition.side.BLUE then
      ZoneCapture:Smoke( SMOKECOLOR.Blue )
      -- Update zone visual markers to BLUE
      ZoneCapture:UndrawZone()
      local color = ZONE_COLORS.BLUE_CAPTURED
      ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
      US_CC:MessageTypeToCoalition( string.format( "%s is under protection of the USA", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
      RU_CC:MessageTypeToCoalition( string.format( "%s is under protection of the USA", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
    else
      ZoneCapture:Smoke( SMOKECOLOR.Red )
      -- Update zone visual markers to RED
      ZoneCapture:UndrawZone()
      local color = ZONE_COLORS.RED_CAPTURED
      ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
      RU_CC:MessageTypeToCoalition( string.format( "%s is under protection of Russia", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
      US_CC:MessageTypeToCoalition( string.format( "%s is under protection of Russia", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
    end
    -- Create/update tactical information marker
    CreateTacticalInfoMarker(ZoneCapture)
  end
end

local function OnEnterEmpty(ZoneCapture)
  ZoneCapture:Smoke( SMOKECOLOR.Green )
  -- Update zone visual markers to GREEN (neutral)
  ZoneCapture:UndrawZone()
  local color = ZONE_COLORS.EMPTY
  ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
  US_CC:MessageTypeToCoalition( string.format( "%s is unprotected, and can be captured!", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
  RU_CC:MessageTypeToCoalition( string.format( "%s is unprotected, and can be captured!", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
  -- Create/update tactical information marker
  CreateTacticalInfoMarker(ZoneCapture)
end

local function OnEnterAttacked(ZoneCapture)
  ZoneCapture:Smoke( SMOKECOLOR.White )
  -- Update zone visual markers based on owner (attacked state)
  ZoneCapture:UndrawZone()
  local Coalition = ZoneCapture:GetCoalition()
  local color
  if Coalition == coalition.side.BLUE then
    color = ZONE_COLORS.BLUE_ATTACKED
    US_CC:MessageTypeToCoalition( string.format( "%s is under attack by Russia", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION )
    RU_CC:MessageTypeToCoalition( string.format( "We are attacking %s", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION )
  else
    color = ZONE_COLORS.RED_ATTACKED
    RU_CC:MessageTypeToCoalition( string.format( "%s is under attack by the USA", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION )
    US_CC:MessageTypeToCoalition( string.format( "We are attacking %s", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION )
  end
  ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
  -- Create/update tactical information marker
  CreateTacticalInfoMarker(ZoneCapture)
end

-- Victory condition monitoring for BOTH coalitions
local function CheckVictoryCondition()
  local blueZonesCount = 0
  local redZonesCount = 0
  local totalZones = #zoneCaptureObjects
  
  for i, zoneCapture in ipairs(zoneCaptureObjects) do
    if zoneCapture then
      local zoneCoalition = zoneCapture:GetCoalition()
      if zoneCoalition == coalition.side.BLUE then
        blueZonesCount = blueZonesCount + 1
      elseif zoneCoalition == coalition.side.RED then
        redZonesCount = redZonesCount + 1
      end
    end
  end
  
  log(string.format("[VICTORY CHECK] Blue owns %d/%d zones, Red owns %d/%d zones", 
    blueZonesCount, totalZones, redZonesCount, totalZones))
  
  -- Check for BLUE victory
  if blueZonesCount >= totalZones then
    log("[VICTORY] All zones captured by BLUE! Triggering victory sequence...")
    
    US_CC:MessageTypeToCoalition( 
      "VICTORY! All capture zones have been secured by coalition forces!\n\n" ..
      "Operation Polar Shield is complete. Outstanding work!\n" ..
      "Mission will end in 60 seconds.", 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
    
    RU_CC:MessageTypeToCoalition( 
      "DEFEAT! All strategic positions have been lost to coalition forces.\n\n" ..
      "Operation Polar Shield has failed. Mission ending in 60 seconds.", 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
    
    -- Add victory celebration effects
    for _, zoneCapture in ipairs(zoneCaptureObjects) do
      if zoneCapture then
        zoneCapture:Smoke( SMOKECOLOR.Blue )
        local zone = zoneCapture:GetZone()
        if zone then
          zone:FlareZone( FLARECOLOR.Blue, 90, 60 )
        end
      end
    end
    
    SCHEDULER:New( nil, function()
      log("[VICTORY] Ending mission due to complete zone capture by BLUE")
      trigger.action.setUserFlag("BLUE_VICTORY", 1)
      
      US_CC:MessageTypeToCoalition( 
        string.format("Mission Complete! Congratulations on your victory!\nFinal Status: All %d strategic zones secured.", totalZones), 
        MESSAGE.Type.Information, 10 
      )
    end, {}, 60 )
    
    return true
  end
  
  -- Check for RED victory
  if redZonesCount >= totalZones then
    log("[VICTORY] All zones captured by RED! Triggering victory sequence...")
    
    RU_CC:MessageTypeToCoalition( 
      "VICTORY! All strategic positions secured for the Motherland!\n\n" ..
      "NATO forces have been repelled. Outstanding work!\n" ..
      "Mission will end in 60 seconds.", 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
    
    US_CC:MessageTypeToCoalition( 
      "DEFEAT! All capture zones have been lost to Russian forces.\n\n" ..
      "Operation Polar Shield has failed. Mission ending in 60 seconds.", 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
    
    -- Add victory celebration effects
    for _, zoneCapture in ipairs(zoneCaptureObjects) do
      if zoneCapture then
        zoneCapture:Smoke( SMOKECOLOR.Red )
        local zone = zoneCapture:GetZone()
        if zone then
          zone:FlareZone( FLARECOLOR.Red, 90, 60 )
        end
      end
    end
    
    SCHEDULER:New( nil, function()
      log("[VICTORY] Ending mission due to complete zone capture by RED")
      trigger.action.setUserFlag("RED_VICTORY", 1)
      
      RU_CC:MessageTypeToCoalition( 
        string.format("Mission Complete! Congratulations on your victory!\nFinal Status: All %d strategic zones secured.", totalZones), 
        MESSAGE.Type.Information, 10 
      )
    end, {}, 60 )
    
    return true
  end
  
  return false -- Victory not yet achieved by either side
end

local function OnEnterCaptured(ZoneCapture)
  local Coalition = ZoneCapture:GetCoalition()
  if Coalition == coalition.side.BLUE then
    -- Update zone visual markers to BLUE for captured
    ZoneCapture:UndrawZone()
    local color = ZONE_COLORS.BLUE_CAPTURED
    ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
    RU_CC:MessageTypeToCoalition( string.format( "%s is captured by the USA, we lost it!", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
    US_CC:MessageTypeToCoalition( string.format( "We captured %s, Excellent job!", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
  else
    -- Update zone visual markers to RED for captured
    ZoneCapture:UndrawZone()
    local color = ZONE_COLORS.RED_CAPTURED
    ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
    US_CC:MessageTypeToCoalition( string.format( "%s is captured by Russia, we lost it!", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
    RU_CC:MessageTypeToCoalition( string.format( "We captured %s, Excellent job!", ZoneCapture:GetZoneName() ), MESSAGE.Type.Information, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION )
  end
  
  ZoneCapture:AddScore( "Captured", "Zone captured: Extra points granted.", ZONE_SETTINGS.captureScore )    
  ZoneCapture:__Guard( 30 )
  
  -- Create/update tactical information marker
  CreateTacticalInfoMarker(ZoneCapture)
  
  -- Check victory condition after any zone capture
  CheckVictoryCondition()
end

-- Set up event handlers for each zone with proper MOOSE methods and debugging
for i, zoneCapture in ipairs(zoneCaptureObjects) do
  if zoneCapture then
    local zoneName = zoneNames[i] or ("Zone " .. i)
    
    -- Proper MOOSE event handlers for ZONE_CAPTURE_COALITION
    zoneCapture.OnEnterGuarded = OnEnterGuarded
    zoneCapture.OnEnterEmpty = OnEnterEmpty  
    zoneCapture.OnEnterAttacked = OnEnterAttacked
    zoneCapture.OnEnterCaptured = OnEnterCaptured
    
    -- Debug: Check if the underlying zone exists
    local success, zone = pcall(function() return zoneCapture:GetZone() end)
    if success and zone then
      log("✓ Zone '" .. zoneName .. "' successfully created and linked")
      
      -- Get initial coalition color for this zone
      local initialCoalition = zoneCapture:GetCoalition()
      local colorRGB = ZONE_COLORS.EMPTY

      if initialCoalition == coalition.side.RED then
        colorRGB = ZONE_COLORS.RED_CAPTURED
      elseif initialCoalition == coalition.side.BLUE then
        colorRGB = ZONE_COLORS.BLUE_CAPTURED
      end

      -- Initialize zone borders with appropriate initial color
      local drawSuccess, drawError = pcall(function()
        zone:DrawZone(-1, {0, 0, 0}, 1, colorRGB, 0.2, 2, true)
      end)
      
      if not drawSuccess then
        log("⚠ Zone 'Capture " .. zoneName .. "' border drawing failed: " .. tostring(drawError))
        -- Alternative: Try simpler zone marking
        pcall(function()
          if initialCoalition == coalition.side.RED then
            zone:SmokeZone(SMOKECOLOR.Red, 30)
          elseif initialCoalition == coalition.side.BLUE then
            zone:SmokeZone(SMOKECOLOR.Blue, 30)
          else
            zone:SmokeZone(SMOKECOLOR.Green, 30)
          end
        end)
      else
        local coalitionName = "NEUTRAL"
        if initialCoalition == coalition.side.RED then
          coalitionName = "RED"
        elseif initialCoalition == coalition.side.BLUE then
          coalitionName = "BLUE"
        end
        log("✓ Zone '" .. zoneName .. "' border drawn successfully with " .. coalitionName .. " initial color")
      end
    else
      log("✗ ERROR: Zone '" .. zoneName .. "' not found in mission editor!")
      log("   Make sure you have a trigger zone named exactly: '" .. zoneName .. "'")
    end
  else
    log("✗ ERROR: Zone capture object " .. i .. " (" .. (zoneNames[i] or "Unknown") .. ") is nil!")
  end
end

-- ==========================================
-- VICTORY MONITORING SYSTEM
-- ==========================================

-- Function to get current zone ownership status
local function GetZoneOwnershipStatus()
  local status = {
    blue = 0,
    red = 0,
    neutral = 0,
    total = #zoneCaptureObjects,
    zones = {}
  }
  
  -- Explicitly reference the global coalition table to avoid parameter shadowing
  local coalitionTable = _G.coalition or coalition
  
  for i, zoneCapture in ipairs(zoneCaptureObjects) do
    if zoneCapture then
      local zoneCoalition = zoneCapture:GetCoalition()
      local zoneName = zoneNames[i] or ("Zone " .. i)
      
      -- Get the current state of the zone
      local currentState = zoneCapture:GetCurrentState()
      local stateString = ""
      
      -- Determine status based on coalition and state
      if zoneCoalition == coalitionTable.side.BLUE then
        status.blue = status.blue + 1
        if currentState == "Attacked" then
          status.zones[zoneName] = "BLUE (Under Attack)"
        else
          status.zones[zoneName] = "BLUE"
        end
      elseif zoneCoalition == coalitionTable.side.RED then
        status.red = status.red + 1
        if currentState == "Attacked" then
          status.zones[zoneName] = "RED (Under Attack)"
        else
          status.zones[zoneName] = "RED"
        end
      else
        status.neutral = status.neutral + 1
        if currentState == "Attacked" then
          status.zones[zoneName] = "NEUTRAL (Under Attack)"
        else
          status.zones[zoneName] = "NEUTRAL"
        end
      end
    end
  end
  
  return status
end

-- Function to broadcast zone status report to BOTH coalitions
local function BroadcastZoneStatus()
  local status = GetZoneOwnershipStatus()
  
  -- Build coalition-neutral report
  local reportMessage = string.format(
    "ZONE CONTROL REPORT:\n" ..
    "Blue Coalition: %d/%d zones\n" ..
    "Red Coalition: %d/%d zones\n" ..
    "Neutral: %d/%d zones",
    status.blue, status.total,
    status.red, status.total,
    status.neutral, status.total
  )
  
  -- Add detailed zone status
  local detailMessage = "\nZONE DETAILS:\n"
  for zoneName, owner in pairs(status.zones) do
    detailMessage = detailMessage .. string.format("• %s: %s\n", zoneName, owner)
  end
  
  local fullMessage = reportMessage .. detailMessage
  
  -- Broadcast to BOTH coalitions with their specific victory progress
  local totalZones = math.max(status.total, 1)
  local blueProgressPercent = math.floor((status.blue / totalZones) * 100)
  local blueFullMessage = fullMessage .. string.format("\n\nYour Progress to Victory: %d%%", blueProgressPercent)
  US_CC:MessageTypeToCoalition( blueFullMessage, MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION )
  
  local redProgressPercent = math.floor((status.red / totalZones) * 100)
  local redFullMessage = fullMessage .. string.format("\n\nYour Progress to Victory: %d%%", redProgressPercent)
  RU_CC:MessageTypeToCoalition( redFullMessage, MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION )
  
  log("[ZONE STATUS] " .. reportMessage:gsub("\n", " | "))
  
  return status
end

-- Periodic zone monitoring (every 5 minutes) for BOTH coalitions
local ZoneMonitorScheduler = SCHEDULER:New( nil, function()
  local status = BroadcastZoneStatus()
  
  -- Check if BLUE is close to victory (80% or more zones captured)
  if status.blue >= math.floor(status.total * 0.8) and status.blue < status.total then
    US_CC:MessageTypeToCoalition( 
      string.format("APPROACHING VICTORY! %d more zone(s) needed for complete success!", 
        status.total - status.blue), 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
    
    RU_CC:MessageTypeToCoalition( 
      string.format("CRITICAL SITUATION! Coalition forces control %d/%d zones! We must recapture territory!", 
        status.blue, status.total), 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
  end
  
  -- Check if RED is close to victory (80% or more zones captured)
  if status.red >= math.floor(status.total * 0.8) and status.red < status.total then
    RU_CC:MessageTypeToCoalition( 
      string.format("APPROACHING VICTORY! %d more zone(s) needed for complete success!", 
        status.total - status.red), 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
    
    US_CC:MessageTypeToCoalition( 
      string.format("CRITICAL SITUATION! Russian forces control %d/%d zones! We must recapture territory!", 
        status.red, status.total), 
      MESSAGE.Type.Information, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION 
    )
  end
  
end, {}, MESSAGE_CONFIG.STATUS_BROADCAST_START_DELAY, MESSAGE_CONFIG.STATUS_BROADCAST_FREQUENCY )

-- Periodic zone color verification system (every 2 minutes)
local ZoneColorVerificationScheduler = SCHEDULER:New( nil, function()
  log("[ZONE COLORS] Running periodic zone color verification...")
  
  -- Verify each zone's visual marker matches its CURRENT STATE (not just coalition)
  for i, zoneCapture in ipairs(zoneCaptureObjects) do
    if zoneCapture then
      local zoneCoalition = zoneCapture:GetCoalition()
      local zoneName = zoneNames[i] or ("Zone " .. i)
      local currentState = zoneCapture:GetCurrentState()

      local zoneColor = GetZoneColor(zoneCapture)
      
      -- Force redraw the zone with correct color based on CURRENT STATE
  zoneCapture:UndrawZone()
  zoneCapture:DrawZone(-1, {0, 0, 0}, 1, zoneColor, 0.2, 2, true)

      -- Log the color assignment for debugging
      local colorName = "UNKNOWN"
      if currentState == "Attacked" then
        colorName = (zoneCoalition == coalition.side.BLUE) and "LIGHT BLUE (Blue Attacked)" or "ORANGE (Red Attacked)"
      elseif currentState == "Empty" then
        colorName = "GREEN (Empty)"
      elseif zoneCoalition == coalition.side.BLUE then
        colorName = "BLUE (Owned)"
      elseif zoneCoalition == coalition.side.RED then
        colorName = "RED (Owned)"
      else
        colorName = "GREEN (Fallback)"
      end
      log(string.format("[ZONE COLORS] %s: Set to %s", zoneName, colorName))
    end
  end
  
end, {}, MESSAGE_CONFIG.COLOR_VERIFICATION_START_DELAY, MESSAGE_CONFIG.COLOR_VERIFICATION_FREQUENCY )

-- Periodic tactical marker update system with change detection
local __lastForceCountsByZone = {}
local TacticalMarkerUpdateScheduler = SCHEDULER:New( nil, function()
  log("[TACTICAL] Running periodic tactical marker update (change-detected)...")

  for i, zoneCapture in ipairs(zoneCaptureObjects) do
    if zoneCapture then
      local zoneName = zoneCapture.GetZoneName and zoneCapture:GetZoneName() or (zoneNames[i] or ("Zone " .. i))
      local counts = GetZoneForceStrengths(zoneCapture)
      local last = __lastForceCountsByZone[zoneName]
      local changed = (not last)
        or (last.red ~= counts.red)
        or (last.blue ~= counts.blue)
        or (last.neutral ~= counts.neutral)

      if changed then
        __lastForceCountsByZone[zoneName] = {
          red = counts.red,
          blue = counts.blue,
          neutral = counts.neutral
        }
        CreateTacticalInfoMarker(zoneCapture)
      end
    end
  end

end, {}, MESSAGE_CONFIG.TACTICAL_UPDATE_START_DELAY, MESSAGE_CONFIG.TACTICAL_UPDATE_FREQUENCY )

-- Function to refresh all zone colors based on current ownership
local function RefreshAllZoneColors()
  log("[ZONE COLORS] Refreshing all zone visual markers...")
  
  for i, zoneCapture in ipairs(zoneCaptureObjects) do
    if zoneCapture then
      local zoneCoalition = zoneCapture:GetCoalition()
      local zoneName = zoneNames[i] or ("Zone " .. i)
      local currentState = zoneCapture:GetCurrentState()

      -- Get color for current state/ownership
      local zoneColor = GetZoneColor(zoneCapture)

    -- Clear existing drawings
    zoneCapture:UndrawZone()

    -- Redraw with correct color
    zoneCapture:DrawZone(-1, {0, 0, 0}, 1, zoneColor, 0.2, 2, true)

      -- Log the color assignment for debugging
      local colorName = "UNKNOWN"
      if currentState == "Attacked" then
        colorName = (zoneCoalition == coalition.side.BLUE) and "LIGHT BLUE (Blue Attacked)" or "ORANGE (Red Attacked)"
      elseif currentState == "Empty" then
        colorName = "GREEN (Empty)"
      elseif zoneCoalition == coalition.side.BLUE then
        colorName = "BLUE (Owned)"
      elseif zoneCoalition == coalition.side.RED then
        colorName = "RED (Owned)"
      else
        colorName = "GREEN (Fallback)"
      end
      log(string.format("[ZONE COLORS] %s: Set to %s", zoneName, colorName))
    end
  end
  
  -- Notify BOTH coalitions
  US_CC:MessageTypeToCoalition("Zone visual markers have been refreshed!", MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION)
  RU_CC:MessageTypeToCoalition("Zone visual markers have been refreshed!", MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION)
end

-- Manual zone status commands for players (F10 radio menu) - BOTH COALITIONS
local function SetupZoneStatusCommands()
  -- Add F10 radio menu commands for BLUE coalition
  if US_CC then
    -- Use MenuManager to create zone control menu under Mission Options
    local USMenu = MenuManager and MenuManager.CreateCoalitionMenu(coalition.side.BLUE, "Zone Control") 
                   or MENU_COALITION:New( coalition.side.BLUE, "Zone Control" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Get Zone Status Report", USMenu, BroadcastZoneStatus )
    
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Check Victory Progress", USMenu, function()
      local status = GetZoneOwnershipStatus()
      local totalZones = math.max(status.total, 1)
      local progressPercent = math.floor((status.blue / totalZones) * 100)
      
      US_CC:MessageTypeToCoalition( 
        string.format(
          "VICTORY PROGRESS: %d%%\n" ..
          "Zones Captured: %d/%d\n" ..
          "Remaining: %d zones\n\n" ..
          "%s",
          progressPercent,
          status.blue, status.total,
          status.total - status.blue,
          progressPercent >= 100 and "MISSION COMPLETE!" or 
          progressPercent >= 80 and "ALMOST THERE!" or
          progressPercent >= 50 and "GOOD PROGRESS!" or
          "KEEP FIGHTING!"
        ), 
        MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION 
      )
    end )
    
    -- Add command to refresh zone colors (troubleshooting tool)
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Refresh Zone Colors", USMenu, RefreshAllZoneColors )
  end
  
  -- Add F10 radio menu commands for RED coalition
  if RU_CC then
    -- Use MenuManager to create zone control menu under Mission Options
    local RUMenu = MenuManager and MenuManager.CreateCoalitionMenu(coalition.side.RED, "Zone Control")
                   or MENU_COALITION:New( coalition.side.RED, "Zone Control" )
    MENU_COALITION_COMMAND:New( coalition.side.RED, "Get Zone Status Report", RUMenu, BroadcastZoneStatus )
    
    MENU_COALITION_COMMAND:New( coalition.side.RED, "Check Victory Progress", RUMenu, function()
      local status = GetZoneOwnershipStatus()
      local totalZones = math.max(status.total, 1)
      local progressPercent = math.floor((status.red / totalZones) * 100)
      
      RU_CC:MessageTypeToCoalition( 
        string.format(
          "VICTORY PROGRESS: %d%%\n" ..
          "Zones Captured: %d/%d\n" ..
          "Remaining: %d zones\n\n" ..
          "%s",
          progressPercent,
          status.red, status.total,
          status.total - status.red,
          progressPercent >= 100 and "MISSION COMPLETE!" or 
          progressPercent >= 80 and "ALMOST THERE!" or
          progressPercent >= 50 and "GOOD PROGRESS!" or
          "KEEP FIGHTING!"
        ), 
        MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION 
      )
    end )
    
    -- Add command to refresh zone colors (troubleshooting tool)
    MENU_COALITION_COMMAND:New( coalition.side.RED, "Refresh Zone Colors", RUMenu, RefreshAllZoneColors )
  end
end

-- Initialize zone status monitoring
SCHEDULER:New( nil, function()
  log("[VICTORY SYSTEM] Initializing zone monitoring system...")
  
  -- Initialize performance optimization caches
  InitializeCachedUnitSet()
  
  SetupZoneStatusCommands()
  
  -- Initial status report
  SCHEDULER:New( nil, function()
    log("[VICTORY SYSTEM] Broadcasting initial zone status...")
    BroadcastZoneStatus()
  end, {}, 30 ) -- Initial report after 30 seconds
  
end, {}, 5 ) -- Initialize after 5 seconds

log("[VICTORY SYSTEM] Zone capture victory monitoring system loaded successfully!")
log(string.format("[CONFIG] Loaded %d zones from configuration", totalZones))
