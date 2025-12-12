--[[
    Unified F10 Menu Manager
    
    Purpose: Provides a centralized menu system to organize all mission scripts
    into a consistent F10 menu structure.
    
    Menu Organization:
    F10 -> F1: Mission Options (all other scripts go here)
    F10 -> F2: CTLD (reserved position)
    F10 -> F3: AFAC Control (reserved position)
    
    Usage:
    1. Load this script FIRST before any other menu-creating scripts
    2. Other scripts should use MenuManager to register their menus
    
    Example:
    -- In your script, instead of:
    -- local MyMenu = MENU_COALITION:New(coalition.side.BLUE, "My Script")
    
    -- Use:
    -- local MyMenu = MenuManager.CreateCoalitionMenu(coalition.side.BLUE, "My Script")
    
]]--

MenuManager = {}
MenuManager.Version = "1.1"

-- Configuration
MenuManager.Config = {
    EnableMissionOptionsMenu = true,  -- Set to false to disable the parent menu system
    MissionOptionsMenuName = "Mission Options",  -- Name of the parent menu
    Debug = false  -- Set to true for debug messages
}

-- Storage for menu references
MenuManager.Menus = {
    Blue = {},
    Red = {},
    Mission = {}
}

-- Parent menu references (created on first use)
MenuManager.ParentMenus = {
    BlueCoalition = nil,
    RedCoalition = nil,
    Mission = nil
}

-- Initialize the parent menus
function MenuManager.Initialize()
    if MenuManager.Config.EnableMissionOptionsMenu then
        -- Create the parent "Mission Options" menu for each coalition
        MenuManager.ParentMenus.BlueCoalition = MENU_COALITION:New(
            coalition.side.BLUE, 
            MenuManager.Config.MissionOptionsMenuName
        )
        
        MenuManager.ParentMenus.RedCoalition = MENU_COALITION:New(
            coalition.side.RED, 
            MenuManager.Config.MissionOptionsMenuName
        )
        
        -- Note: MENU_MISSION not created to avoid duplicate empty menu
        -- Scripts that need mission-wide menus should use MENU_MISSION directly
        
        if MenuManager.Config.Debug then
            env.info("MenuManager: Initialized parent coalition menus")
        end
    end
end

-- Create a coalition menu under "Mission Options"
-- @param coalitionSide: coalition.side.BLUE or coalition.side.RED
-- @param menuName: Name of the menu
-- @param parentMenu: (Optional) If provided, creates as submenu of this parent instead of Mission Options
-- @return: MENU_COALITION object
function MenuManager.CreateCoalitionMenu(coalitionSide, menuName, parentMenu)
    if MenuManager.Config.EnableMissionOptionsMenu and not parentMenu then
        -- Create under Mission Options
        local parent = (coalitionSide == coalition.side.BLUE) 
            and MenuManager.ParentMenus.BlueCoalition 
            or MenuManager.ParentMenus.RedCoalition
        
        local menu = MENU_COALITION:New(coalitionSide, menuName, parent)
        
        if MenuManager.Config.Debug then
            local coalitionName = (coalitionSide == coalition.side.BLUE) and "BLUE" or "RED"
            env.info(string.format("MenuManager: Created coalition menu '%s' for %s", menuName, coalitionName))
        end
        
        return menu
    else
        -- Create as root menu or under provided parent
        local menu = MENU_COALITION:New(coalitionSide, menuName, parentMenu)
        return menu
    end
end

-- Create a mission menu (not nested under Mission Options, as that causes duplicates)
-- @param menuName: Name of the menu
-- @param parentMenu: (Optional) Parent menu
-- @return: MENU_MISSION object
-- Note: Mission menus are visible to all players and cannot be nested under coalition menus
function MenuManager.CreateMissionMenu(menuName, parentMenu)
    -- Always create as root menu or under provided parent
    -- Mission menus can't be nested under coalition-specific "Mission Options"
    local menu = MENU_MISSION:New(menuName, parentMenu)
    
    if MenuManager.Config.Debug then
        env.info(string.format("MenuManager: Created mission menu '%s'", menuName))
    end
    
    return menu
end

-- Helper to disable the parent menu system at runtime
function MenuManager.DisableParentMenus()
    MenuManager.Config.EnableMissionOptionsMenu = false
    env.info("MenuManager: Parent menu system disabled")
end

-- Helper to enable the parent menu system at runtime
function MenuManager.EnableParentMenus()
    MenuManager.Config.EnableMissionOptionsMenu = true
    if not MenuManager.ParentMenus.BlueCoalition then
        MenuManager.Initialize()
    end
    env.info("MenuManager: Parent menu system enabled")
end

-- Initialize on load
MenuManager.Initialize()

-- Announcement
env.info(string.format("MenuManager v%s loaded - Mission Options menu system ready", MenuManager.Version))
