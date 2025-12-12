---@diagnostic disable: undefined-global, lowercase-global
-- MOOSE framework globals are defined at runtime by DCS World
-- **Author**: F99th-TracerFacer
-- **Discord:** https://discord.gg/NdZ2JuSU (The Fighting 99th Discord Server where I spend most of my time.)


-- ==========================================
-- SYNOPSIS
-- ==========================================
-- This script implements a dual-coalition zone capture system for DCS World using the MOOSE framework.
-- It allows two coalitions (Blue and Red) to capture and control strategic zones on the map.
-- Zones change ownership based on unit presence, with visual markers, tactical information, and victory conditions.
--
-- SIMPLE INSTRUCTIONS:
-- 1. Configure the zones in the ZONE_CONFIG table below (add zone names under RED, BLUE, or NEUTRAL).
-- 2. Set coalition display names in COALITION_TITLES (e.g., "USA" for Blue, "Russia" for Red).
-- 3. Adjust zone colors in ZONE_COLORS if needed (RGB values 0.0 to 1.0).
-- 4. Ensure zone names match exactly with trigger zones defined in the DCS mission editor.
-- 5. Load the script in your DCS mission and ensure the MOOSE framework is installed.
-- 6. Use F10 radio menu for zone status reports and victory progress during the mission.



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
  ATTACK_MESSAGE_DURATION = 15,          -- Duration for attack alerts
  GARBAGE_COLLECTION_FREQUENCY = 600     -- Lua garbage collection cadence (seconds) - helps prevent memory buildup
}

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

-- ==========================================
-- COALITION TITLES CONFIGURATION
-- ==========================================
-- Mission makers: Customize the display names for each coalition
-- These will be used in messages, mission names, and UI elements
local COALITION_TITLES = {
  BLUE = "USA",           -- Display name for Blue coalition (e.g., "USA", "NATO", "Allied Forces")
  RED = "Russia",         -- Display name for Red coalition (e.g., "Russia", "Germany", "Axis Powers")
  BLUE_OPERATION = "Operation Polar Shield",  -- Name of Blue coalition's operation
  RED_OPERATION = "Defend the Motherland"     -- Name of Red coalition's operation
}

-- ==========================================
-- LANGUAGE CONFIGURATION
-- ==========================================
local LANGUAGE_CONFIG = {
  defaultLanguage = "EN",  -- Default language: "EN", "DE", "FR", "ES", "RU"
}

-- Multilingual message table
-- Each language contains all messages and menu text
local ZONE_CAPTURE_LANGUAGES = {
  EN = {
    -- Zone state messages
    zoneGuarded = "%s is under protection of the %s",
    zoneEmpty = "%s is unprotected, and can be captured!",
    zoneUnderAttack = "%s is under attack by %s",
    zoneWeAttacking = "We are attacking %s",
    zoneCapturedByEnemy = "%s is captured by the %s, we lost it!",
    zoneCapturedByUs = "We captured %s, Excellent job!",
    
    -- Victory messages
    victoryBlue = "VICTORY! All capture zones have been secured by %s forces!\n\n%s is complete. Outstanding work!\nMission will end in 60 seconds.",
    defeatBlue = "DEFEAT! All strategic positions have been lost to %s forces.\n\n%s has failed. Mission ending in 60 seconds.",
    victoryRed = "VICTORY! All strategic positions secured for %s!\n\n%s forces have been repelled. Outstanding work!\nMission will end in 60 seconds.",
    defeatRed = "DEFEAT! All capture zones have been lost to %s forces.\n\n%s has failed. Mission ending in 60 seconds.",
    missionComplete = "Mission Complete! Congratulations on your victory!\nFinal Status: All %d strategic zones secured.",
    
    -- Status report messages
    zoneControlReport = "ZONE CONTROL REPORT:\nBlue Coalition: %d/%d zones\nRed Coalition: %d/%d zones\nNeutral: %d/%d zones",
    zoneDetails = "\nZONE DETAILS:\n",
    zoneDetailLine = "• %s: %s\n",
    yourProgress = "\n\nYour Progress to Victory: %d%%",
    
    -- Progress warning messages
    blueNearVictory = "TACTICAL ALERT: %s forces control %d%% of strategic zones!\nVictory is within reach!",
    redNearVictory = "WARNING: %s forces have captured %d%% of zones!\nDefend our positions!",
    
    -- Coalition names
    coalitionBlue = "Blue Coalition",
    coalitionRed = "Red Coalition",
    coalitionNeutral = "Neutral",
    
    -- Menu items
    menuZoneControl = "Zone Control",
    menuStatusReport = "Get Zone Status Report",
    menuVictoryProgress = "Check Victory Progress",
    menuRefreshColors = "Refresh Zone Colors",
    menuLanguage = "Language / Sprache / Langue",
    menuEnglish = "English",
    menuGerman = "Deutsch (German)",
    menuFrench = "Français (French)",
    menuSpanish = "Español (Spanish)",
    menuRussian = "Русский (Russian)",
    
    -- Victory progress messages
    victoryProgressTitle = "VICTORY PROGRESS: %d%%",
    zonesCaptured = "Zones Captured: %d/%d",
    zonesRemaining = "Remaining: %d zones",
    progressComplete = "MISSION COMPLETE!",
    progressAlmostThere = "ALMOST THERE!",
    progressGood = "GOOD PROGRESS!",
    progressKeepFighting = "KEEP FIGHTING!",
    
    -- System messages
    zoneMarkersRefreshed = "Zone visual markers have been refreshed!",
    languageChanged = "Language changed to English",
  },
  
  DE = {
    -- Zone state messages
    zoneGuarded = "%s steht unter dem Schutz der %s",
    zoneEmpty = "%s ist ungeschützt und kann erobert werden!",
    zoneUnderAttack = "%s wird von %s angegriffen",
    zoneWeAttacking = "Wir greifen %s an",
    zoneCapturedByEnemy = "%s wurde von %s erobert, wir haben es verloren!",
    zoneCapturedByUs = "Wir haben %s erobert, hervorragende Arbeit!",
    
    -- Victory messages
    victoryBlue = "SIEG! Alle Eroberungszonen wurden von %s Streitkräften gesichert!\n\n%s ist abgeschlossen. Hervorragende Arbeit!\nMission endet in 60 Sekunden.",
    defeatBlue = "NIEDERLAGE! Alle strategischen Positionen wurden an %s Streitkräfte verloren.\n\n%s ist gescheitert. Mission endet in 60 Sekunden.",
    victoryRed = "SIEG! Alle strategischen Positionen für %s gesichert!\n\n%s Streitkräfte wurden zurückgeschlagen. Hervorragende Arbeit!\nMission endet in 60 Sekunden.",
    defeatRed = "NIEDERLAGE! Alle Eroberungszonen wurden an %s Streitkräfte verloren.\n\n%s ist gescheitert. Mission endet in 60 Sekunden.",
    missionComplete = "Mission erfolgreich! Herzlichen Glückwunsch zu Ihrem Sieg!\nEndstatus: Alle %d strategischen Zonen gesichert.",
    
    -- Status report messages
    zoneControlReport = "ZONENKONTROLLBERICHT:\nBlaue Koalition: %d/%d Zonen\nRote Koalition: %d/%d Zonen\nNeutral: %d/%d Zonen",
    zoneDetails = "\nZONENDETAILS:\n",
    zoneDetailLine = "• %s: %s\n",
    yourProgress = "\n\nIhr Fortschritt zum Sieg: %d%%",
    
    -- Progress warning messages
    blueNearVictory = "TAKTISCHER ALARM: %s Streitkräfte kontrollieren %d%% der strategischen Zonen!\nSieg ist in Reichweite!",
    redNearVictory = "WARNUNG: %s Streitkräfte haben %d%% der Zonen erobert!\nVerteidigt unsere Positionen!",
    
    -- Coalition names
    coalitionBlue = "Blaue Koalition",
    coalitionRed = "Rote Koalition",
    coalitionNeutral = "Neutral",
    
    -- Menu items
    menuZoneControl = "Zonenkontrolle",
    menuStatusReport = "Zonenstatusbericht abrufen",
    menuVictoryProgress = "Siegfortschritt prüfen",
    menuRefreshColors = "Zonenfarben aktualisieren",
    menuLanguage = "Language / Sprache / Langue",
    menuEnglish = "English",
    menuGerman = "Deutsch (German)",
    menuFrench = "Français (French)",
    menuSpanish = "Español (Spanish)",
    menuRussian = "Русский (Russian)",
    
    -- Victory progress messages
    victoryProgressTitle = "SIEGFORTSCHRITT: %d%%",
    zonesCaptured = "Zonen erobert: %d/%d",
    zonesRemaining = "Verbleibend: %d Zonen",
    progressComplete = "MISSION ABGESCHLOSSEN!",
    progressAlmostThere = "FAST GESCHAFFT!",
    progressGood = "GUTER FORTSCHRITT!",
    progressKeepFighting = "WEITER KÄMPFEN!",
    
    -- System messages
    zoneMarkersRefreshed = "Zonenmarkierungen wurden aktualisiert!",
    languageChanged = "Sprache auf Deutsch geändert",
  },
  
  FR = {
    -- Zone state messages
    zoneGuarded = "%s est sous la protection de %s",
    zoneEmpty = "%s est sans protection et peut être capturée !",
    zoneUnderAttack = "%s est attaquée par %s",
    zoneWeAttacking = "Nous attaquons %s",
    zoneCapturedByEnemy = "%s est capturée par %s, nous l'avons perdue !",
    zoneCapturedByUs = "Nous avons capturé %s, excellent travail !",
    
    -- Victory messages
    victoryBlue = "VICTOIRE ! Toutes les zones de capture ont été sécurisées par les forces %s !\n\n%s est terminée. Excellent travail !\nLa mission se terminera dans 60 secondes.",
    defeatBlue = "DÉFAITE ! Toutes les positions stratégiques ont été perdues face aux forces %s.\n\n%s a échoué. Mission se terminant dans 60 secondes.",
    victoryRed = "VICTOIRE ! Toutes les positions stratégiques sécurisées pour %s !\n\nLes forces %s ont été repoussées. Excellent travail !\nLa mission se terminera dans 60 secondes.",
    defeatRed = "DÉFAITE ! Toutes les zones de capture ont été perdues face aux forces %s.\n\n%s a échoué. Mission se terminant dans 60 secondes.",
    missionComplete = "Mission accomplie ! Félicitations pour votre victoire !\nStatut final : Toutes les %d zones stratégiques sécurisées.",
    
    -- Status report messages
    zoneControlReport = "RAPPORT DE CONTRÔLE DES ZONES :\nCoalition bleue : %d/%d zones\nCoalition rouge : %d/%d zones\nNeutre : %d/%d zones",
    zoneDetails = "\nDÉTAILS DES ZONES :\n",
    zoneDetailLine = "• %s : %s\n",
    yourProgress = "\n\nVotre progression vers la victoire : %d%%",
    
    -- Progress warning messages
    blueNearVictory = "ALERTE TACTIQUE : Les forces %s contrôlent %d%% des zones stratégiques !\nLa victoire est à portée de main !",
    redNearVictory = "AVERTISSEMENT : Les forces %s ont capturé %d%% des zones !\nDéfendez nos positions !",
    
    -- Coalition names
    coalitionBlue = "Coalition bleue",
    coalitionRed = "Coalition rouge",
    coalitionNeutral = "Neutre",
    
    -- Menu items
    menuZoneControl = "Contrôle des zones",
    menuStatusReport = "Obtenir le rapport d'état des zones",
    menuVictoryProgress = "Vérifier la progression vers la victoire",
    menuRefreshColors = "Actualiser les couleurs des zones",
    menuLanguage = "Language / Sprache / Langue",
    menuEnglish = "English",
    menuGerman = "Deutsch (German)",
    menuFrench = "Français (French)",
    menuSpanish = "Español (Spanish)",
    menuRussian = "Русский (Russian)",
    
    -- Victory progress messages
    victoryProgressTitle = "PROGRÈS DE LA VICTOIRE : %d%%",
    zonesCaptured = "Zones capturées : %d/%d",
    zonesRemaining = "Restantes : %d zones",
    progressComplete = "MISSION ACCOMPLIE !",
    progressAlmostThere = "PRESQUE TERMINÉ !",
    progressGood = "BON PROGRÈS !",
    progressKeepFighting = "CONTINUEZ À COMBATTRE !",
    
    -- System messages
    zoneMarkersRefreshed = "Les marqueurs de zone ont été actualisés !",
    languageChanged = "Langue changée en français",
  },
  
  ES = {
    -- Zone state messages
    zoneGuarded = "%s está bajo la protección de %s",
    zoneEmpty = "¡%s está desprotegida y puede ser capturada!",
    zoneUnderAttack = "%s está siendo atacada por %s",
    zoneWeAttacking = "Estamos atacando %s",
    zoneCapturedByEnemy = "¡%s ha sido capturada por %s, la hemos perdido!",
    zoneCapturedByUs = "¡Hemos capturado %s, excelente trabajo!",
    
    -- Victory messages
    victoryBlue = "¡VICTORIA! ¡Todas las zonas de captura han sido aseguradas por las fuerzas %s!\n\n%s está completa. ¡Excelente trabajo!\nLa misión terminará en 60 segundos.",
    defeatBlue = "¡DERROTA! Todas las posiciones estratégicas se han perdido ante las fuerzas %s.\n\n%s ha fallado. Misión terminando en 60 segundos.",
    victoryRed = "¡VICTORIA! ¡Todas las posiciones estratégicas aseguradas para %s!\n\n¡Las fuerzas %s han sido repelidas. Excelente trabajo!\nLa misión terminará en 60 segundos.",
    defeatRed = "¡DERROTA! Todas las zonas de captura se han perdido ante las fuerzas %s.\n\n%s ha fallado. Misión terminando en 60 segundos.",
    missionComplete = "¡Misión completada! ¡Felicitaciones por tu victoria!\nEstado final: Todas las %d zonas estratégicas aseguradas.",
    
    -- Status report messages
    zoneControlReport = "INFORME DE CONTROL DE ZONAS:\nCoalición Azul: %d/%d zonas\nCoalición Roja: %d/%d zonas\nNeutral: %d/%d zonas",
    zoneDetails = "\nDETALLES DE ZONAS:\n",
    zoneDetailLine = "• %s: %s\n",
    yourProgress = "\n\nTu progreso hacia la victoria: %d%%",
    
    -- Progress warning messages
    blueNearVictory = "ALERTA TÁCTICA: ¡Las fuerzas %s controlan el %d%% de las zonas estratégicas!\n¡La victoria está al alcance!",
    redNearVictory = "ADVERTENCIA: ¡Las fuerzas %s han capturado el %d%% de las zonas!\n¡Defiende nuestras posiciones!",
    
    -- Coalition names
    coalitionBlue = "Coalición Azul",
    coalitionRed = "Coalición Roja",
    coalitionNeutral = "Neutral",
    
    -- Menu items
    menuZoneControl = "Control de zonas",
    menuStatusReport = "Obtener informe de estado de zonas",
    menuVictoryProgress = "Verificar progreso de victoria",
    menuRefreshColors = "Actualizar colores de zonas",
    menuLanguage = "Language / Sprache / Langue",
    menuEnglish = "English",
    menuGerman = "Deutsch (German)",
    menuFrench = "Français (French)",
    menuSpanish = "Español (Spanish)",
    menuRussian = "Русский (Russian)",
    
    -- Victory progress messages
    victoryProgressTitle = "PROGRESO DE VICTORIA: %d%%",
    zonesCaptured = "Zonas capturadas: %d/%d",
    zonesRemaining = "Restantes: %d zonas",
    progressComplete = "¡MISIÓN COMPLETADA!",
    progressAlmostThere = "¡CASI TERMINADO!",
    progressGood = "¡BUEN PROGRESO!",
    progressKeepFighting = "¡SIGUE LUCHANDO!",
    
    -- System messages
    zoneMarkersRefreshed = "¡Los marcadores de zona se han actualizado!",
    languageChanged = "Idioma cambiado a español",
  },
  
  RU = {
    -- Zone state messages
    zoneGuarded = "%s находится под защитой %s",
    zoneEmpty = "%s не защищена и может быть захвачена!",
    zoneUnderAttack = "%s атакована силами %s",
    zoneWeAttacking = "Мы атакуем %s",
    zoneCapturedByEnemy = "%s захвачена %s, мы её потеряли!",
    zoneCapturedByUs = "Мы захватили %s, отличная работа!",
    
    -- Victory messages
    victoryBlue = "ПОБЕДА! Все зоны захвата обеспечены силами %s!\n\n%s завершена. Отличная работа!\nМиссия закончится через 60 секунд.",
    defeatBlue = "ПОРАЖЕНИЕ! Все стратегические позиции потеряны силами %s.\n\n%s провалена. Миссия заканчивается через 60 секунд.",
    victoryRed = "ПОБЕДА! Все стратегические позиции обеспечены для %s!\n\nСилы %s отброшены. Отличная работа!\nМиссия закончится через 60 секунд.",
    defeatRed = "ПОРАЖЕНИЕ! Все зоны захвата потеряны силами %s.\n\n%s провалена. Миссия заканчивается через 60 секунд.",
    missionComplete = "Миссия выполнена! Поздравляем с победой!\nИтоговый статус: Все %d стратегических зон обеспечены.",
    
    -- Status report messages
    zoneControlReport = "ОТЧЁТ О КОНТРОЛЕ ЗОН:\nСиняя коалиция: %d/%d зон\nКрасная коалиция: %d/%d зон\nНейтральные: %d/%d зон",
    zoneDetails = "\nПОДРОБНОСТИ ЗОН:\n",
    zoneDetailLine = "• %s: %s\n",
    yourProgress = "\n\nВаш прогресс к победе: %d%%",
    
    -- Progress warning messages
    blueNearVictory = "ТАКТИЧЕСКАЯ ТРЕВОГА: Силы %s контролируют %d%% стратегических зон!\nПобеда близка!",
    redNearVictory = "ВНИМАНИЕ: Силы %s захватили %d%% зон!\nЗащищайте наши позиции!",
    
    -- Coalition names
    coalitionBlue = "Синяя коалиция",
    coalitionRed = "Красная коалиция",
    coalitionNeutral = "Нейтральные",
    
    -- Menu items
    menuZoneControl = "Контроль зон",
    menuStatusReport = "Получить отчёт о статусе зон",
    menuVictoryProgress = "Проверить прогресс победы",
    menuRefreshColors = "Обновить цвета зон",
    menuLanguage = "Language / Sprache / Langue",
    menuEnglish = "English",
    menuGerman = "Deutsch (German)",
    menuFrench = "Français (French)",
    menuSpanish = "Español (Spanish)",
    menuRussian = "Русский (Russian)",
    
    -- Victory progress messages
    victoryProgressTitle = "ПРОГРЕСС ПОБЕДЫ: %d%%",
    zonesCaptured = "Зоны захвачены: %d/%d",
    zonesRemaining = "Осталось: %d зон",
    progressComplete = "МИССИЯ ВЫПОЛНЕНА!",
    progressAlmostThere = "ПОЧТИ ГОТОВО!",
    progressGood = "ХОРОШИЙ ПРОГРЕСС!",
    progressKeepFighting = "ПРОДОЛЖАЙТЕ БОРОТЬСЯ!",
    
    -- System messages
    zoneMarkersRefreshed = "Маркеры зон обновлены!",
    languageChanged = "Язык изменён на русский",
  }
}

-- ==========================================
-- PLAYER LANGUAGE TRACKING
-- ==========================================
-- Store per-player language preferences
local playerLanguages = {}

-- Helper function to get player's language preference
local function GetPlayerLanguage(playerName)
  if playerName and playerLanguages[playerName] then
    return playerLanguages[playerName]
  end
  return LANGUAGE_CONFIG.defaultLanguage
end

-- Helper function to set player's language preference
local function SetPlayerLanguage(playerName, language)
  if playerName and language then
    playerLanguages[playerName] = language
    env.info(string.format("[LANGUAGE] Player %s language set to %s", playerName, language))
  end
end

-- Helper function to get translated text
local function GetText(textKey, playerName)
  local lang = GetPlayerLanguage(playerName)
  local langTable = ZONE_CAPTURE_LANGUAGES[lang] or ZONE_CAPTURE_LANGUAGES.EN
  return langTable[textKey] or textKey
end

-- Helper function to get coalition-specific text
local function GetCoalitionText(coalitionSide, playerName)
  local lang = GetPlayerLanguage(playerName)
  local langTable = ZONE_CAPTURE_LANGUAGES[lang] or ZONE_CAPTURE_LANGUAGES.EN
  
  if coalitionSide == coalition.side.BLUE then
    return langTable.coalitionBlue
  elseif coalitionSide == coalition.side.RED then
    return langTable.coalitionRed
  else
    return langTable.coalitionNeutral
  end
end

-- Helper function to send message to coalition with language support
local function MessageToCoalition(commandCenter, messageKey, params, coalitionSide, duration)
  if not commandCenter then return end
  
  -- Get all players in the coalition
  local playerList = coalition.getPlayers(coalitionSide)
  
  if not playerList or #playerList == 0 then
    -- No players in coalition, send default language message
    local defaultText = ZONE_CAPTURE_LANGUAGES[LANGUAGE_CONFIG.defaultLanguage][messageKey]
    if params then
      defaultText = string.format(defaultText, unpack(params))
    end
    commandCenter:MessageTypeToCoalition(defaultText, MESSAGE.Type.Information, duration)
    return
  end
  
  -- Group players by language preference
  local languageGroups = {}
  for _, unit in ipairs(playerList) do
    if unit then
      local playerName = unit:getPlayerName()
      if playerName then
        local lang = GetPlayerLanguage(playerName)
        if not languageGroups[lang] then
          languageGroups[lang] = {}
        end
        table.insert(languageGroups[lang], playerName)
      end
    end
  end
  
  -- Send message in each language to respective players
  for lang, players in pairs(languageGroups) do
    local langTable = ZONE_CAPTURE_LANGUAGES[lang] or ZONE_CAPTURE_LANGUAGES.EN
    local text = langTable[messageKey]
    if params then
      text = string.format(text, unpack(params))
    end
    
    -- For now, send to entire coalition (MOOSE doesn't support per-player filtering easily)
    -- This is a limitation, but better than nothing
    commandCenter:MessageTypeToCoalition(text, MESSAGE.Type.Information, duration)
  end
end



-- ==========================================
-- END OF CONFIGURATION
-- ==========================================

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

-- Build Command Center and Mission for Blue Coalition
local blueHQ = GROUP:FindByName("BLUEHQ")
if blueHQ then
    US_CC = COMMANDCENTER:New(blueHQ, COALITION_TITLES.BLUE .. " HQ")
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
    RU_CC = COMMANDCENTER:New(redHQ, COALITION_TITLES.RED .. " HQ")
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
    "Destroy " .. COALITION_TITLES.RED .. " ground forces in the surrounding area, " ..
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
  
  RU_Mission_Capture_Airfields = MISSION:New( RU_CC, "Defend the Territory", "Primary",
    "Defend " .. COALITION_TITLES.RED .. " territory and recapture lost zones.\n" ..
    "Eliminate " .. COALITION_TITLES.BLUE .. " forces in capture zones and " .. 
    "maintain control with ground units.\n" .. 
    "Your orders are to prevent the " .. COALITION_TITLES.BLUE .. " from capturing all strategic zones.\n" ..
    "Use the map (F10) for a clear indication of the location of each capture zone.\n" ..
    "Expect heavy " .. COALITION_TITLES.BLUE .. " resistance!\n"
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
local zoneMetadata = {}  -- Stores coalition ownership info
local activeTacticalMarkers = {}  -- Track tactical markers to prevent memory leaks

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

    -- Append TGTS for the enemy of the viewer, capped at 5 units (reduced from 10 to lower memory usage)
    local enemyCoalition = (viewerCoalition == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
    local enemyCount = (enemyCoalition == coalition.side.RED) and (forces.red or 0) or (forces.blue or 0)
    if enemyCount > 0 and enemyCount <= 8 then  -- Only process if 8 or fewer enemies (reduced from 10)
      local enemyCoords = GetEnemyUnitMGRSCoords(ZoneCapture, enemyCoalition)
      log(string.format("[TACTICAL DEBUG] Building marker text for %s viewer: %d enemy units", (viewerCoalition==coalition.side.BLUE and "BLUE" or "RED"), #enemyCoords))
      if #enemyCoords > 0 then
        text = text .. "\nTGTS:"
        for i, unit in ipairs(enemyCoords) do
          if i <= 5 then  -- Reduced from 10 to 5 to save memory
            local shortType = (unit.type or "Unknown"):gsub("^%w+%-", ""):gsub("%s.*", "")
            local cleanMgrs = (unit.mgrs or ""):gsub("^MGRS%s+", ""):gsub("%s+", " ")
            if i == 1 then
              text = text .. string.format(" %s@%s", shortType, cleanMgrs)
            else
              text = text .. string.format(", %s@%s", shortType, cleanMgrs)
            end
          end
        end
        if #enemyCoords > 5 then  -- Updated threshold
          text = text .. string.format(" (+%d)", #enemyCoords - 5)
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
      MessageToCoalition(US_CC, "zoneGuarded", {ZoneCapture:GetZoneName(), COALITION_TITLES.BLUE}, coalition.side.BLUE, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
      MessageToCoalition(RU_CC, "zoneGuarded", {ZoneCapture:GetZoneName(), COALITION_TITLES.BLUE}, coalition.side.RED, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
    else
      ZoneCapture:Smoke( SMOKECOLOR.Red )
      -- Update zone visual markers to RED
      ZoneCapture:UndrawZone()
      local color = ZONE_COLORS.RED_CAPTURED
      ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
      MessageToCoalition(RU_CC, "zoneGuarded", {ZoneCapture:GetZoneName(), COALITION_TITLES.RED}, coalition.side.RED, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
      MessageToCoalition(US_CC, "zoneGuarded", {ZoneCapture:GetZoneName(), COALITION_TITLES.RED}, coalition.side.BLUE, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
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
  MessageToCoalition(US_CC, "zoneEmpty", {ZoneCapture:GetZoneName()}, coalition.side.BLUE, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
  MessageToCoalition(RU_CC, "zoneEmpty", {ZoneCapture:GetZoneName()}, coalition.side.RED, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
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
    MessageToCoalition(US_CC, "zoneUnderAttack", {ZoneCapture:GetZoneName(), COALITION_TITLES.RED}, coalition.side.BLUE, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION)
    MessageToCoalition(RU_CC, "zoneWeAttacking", {ZoneCapture:GetZoneName()}, coalition.side.RED, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION)
  else
    color = ZONE_COLORS.RED_ATTACKED
    MessageToCoalition(RU_CC, "zoneUnderAttack", {ZoneCapture:GetZoneName(), COALITION_TITLES.BLUE}, coalition.side.RED, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION)
    MessageToCoalition(US_CC, "zoneWeAttacking", {ZoneCapture:GetZoneName()}, coalition.side.BLUE, MESSAGE_CONFIG.ATTACK_MESSAGE_DURATION)
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
    
    MessageToCoalition(US_CC, "victoryBlue", {COALITION_TITLES.BLUE, COALITION_TITLES.BLUE_OPERATION}, coalition.side.BLUE, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
    MessageToCoalition(RU_CC, "defeatBlue", {COALITION_TITLES.BLUE, COALITION_TITLES.BLUE_OPERATION}, coalition.side.RED, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
    
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
      
      MessageToCoalition(US_CC, "missionComplete", {totalZones}, coalition.side.BLUE, 10)
    end, {}, 60 )
    
    return true
  end
  
  -- Check for RED victory
  if redZonesCount >= totalZones then
    log("[VICTORY] All zones captured by RED! Triggering victory sequence...")
    
    MessageToCoalition(RU_CC, "victoryRed", {COALITION_TITLES.RED_OPERATION, COALITION_TITLES.BLUE}, coalition.side.RED, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
    MessageToCoalition(US_CC, "defeatRed", {COALITION_TITLES.RED, COALITION_TITLES.BLUE_OPERATION}, coalition.side.BLUE, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
    
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
      
      MessageToCoalition(RU_CC, "missionComplete", {totalZones}, coalition.side.RED, 10)
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
    MessageToCoalition(RU_CC, "zoneCapturedByEnemy", {ZoneCapture:GetZoneName(), COALITION_TITLES.BLUE}, coalition.side.RED, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
    MessageToCoalition(US_CC, "zoneCapturedByUs", {ZoneCapture:GetZoneName()}, coalition.side.BLUE, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
  else
    -- Update zone visual markers to RED for captured
    ZoneCapture:UndrawZone()
    local color = ZONE_COLORS.RED_CAPTURED
    ZoneCapture:DrawZone(-1, {0, 0, 0}, 1, color, 0.2, 2, true)
    MessageToCoalition(US_CC, "zoneCapturedByEnemy", {ZoneCapture:GetZoneName(), COALITION_TITLES.RED}, coalition.side.BLUE, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
    MessageToCoalition(RU_CC, "zoneCapturedByUs", {ZoneCapture:GetZoneName()}, coalition.side.RED, MESSAGE_CONFIG.CAPTURE_MESSAGE_DURATION)
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
  
  -- Build report for BLUE coalition in their language
  local bluePlayerList = coalition.getPlayers(coalition.side.BLUE)
  local bluePlayerName = nil
  if bluePlayerList and #bluePlayerList > 0 then
    local unit = Unit.getByName(Unit.getName(bluePlayerList[1]))
    if unit then
      bluePlayerName = unit:getPlayerName()
    end
  end
  
  local blueReportMessage = string.format(
    GetText("zoneControlReport", bluePlayerName),
    status.blue, status.total,
    status.red, status.total,
    status.neutral, status.total
  )
  
  local blueDetailMessage = GetText("zoneDetails", bluePlayerName)
  for zoneName, owner in pairs(status.zones) do
    blueDetailMessage = blueDetailMessage .. string.format(GetText("zoneDetailLine", bluePlayerName), zoneName, owner)
  end
  
  local totalZones = math.max(status.total, 1)
  local blueProgressPercent = math.floor((status.blue / totalZones) * 100)
  local blueFullMessage = blueReportMessage .. blueDetailMessage .. string.format(GetText("yourProgress", bluePlayerName), blueProgressPercent)
  US_CC:MessageTypeToCoalition( blueFullMessage, MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION )
  
  -- Build report for RED coalition in their language
  local redPlayerList = coalition.getPlayers(coalition.side.RED)
  local redPlayerName = nil
  if redPlayerList and #redPlayerList > 0 then
    local unit = Unit.getByName(Unit.getName(redPlayerList[1]))
    if unit then
      redPlayerName = unit:getPlayerName()
    end
  end
  
  local redReportMessage = string.format(
    GetText("zoneControlReport", redPlayerName),
    status.blue, status.total,
    status.red, status.total,
    status.neutral, status.total
  )
  
  local redDetailMessage = GetText("zoneDetails", redPlayerName)
  for zoneName, owner in pairs(status.zones) do
    redDetailMessage = redDetailMessage .. string.format(GetText("zoneDetailLine", redPlayerName), zoneName, owner)
  end
  
  local redProgressPercent = math.floor((status.red / totalZones) * 100)
  local redFullMessage = redReportMessage .. redDetailMessage .. string.format(GetText("yourProgress", redPlayerName), redProgressPercent)
  RU_CC:MessageTypeToCoalition( redFullMessage, MESSAGE.Type.Information, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION )
  
  log("[ZONE STATUS] Blue:" .. status.blue .. "/" .. status.total .. " Red:" .. status.red .. "/" .. status.total)
  
  return status
end

-- Periodic zone monitoring (every 5 minutes) for BOTH coalitions
local ZoneMonitorScheduler = SCHEDULER:New( nil, function()
  local status = BroadcastZoneStatus()
  
  -- Check if BLUE is close to victory (80% or more zones captured)
  if status.blue >= math.floor(status.total * 0.8) and status.blue < status.total then
    local bluePercent = math.floor((status.blue / status.total) * 100)
    MessageToCoalition(US_CC, "blueNearVictory", {COALITION_TITLES.BLUE, bluePercent}, coalition.side.BLUE, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
    MessageToCoalition(RU_CC, "redNearVictory", {COALITION_TITLES.BLUE, bluePercent}, coalition.side.RED, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
  end
  
  -- Check if RED is close to victory (80% or more zones captured)
  if status.red >= math.floor(status.total * 0.8) and status.red < status.total then
    local redPercent = math.floor((status.red / status.total) * 100)
    MessageToCoalition(RU_CC, "blueNearVictory", {COALITION_TITLES.RED, redPercent}, coalition.side.RED, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
    MessageToCoalition(US_CC, "redNearVictory", {COALITION_TITLES.RED, redPercent}, coalition.side.BLUE, MESSAGE_CONFIG.VICTORY_MESSAGE_DURATION)
  end
  
end, {}, MESSAGE_CONFIG.STATUS_BROADCAST_START_DELAY, MESSAGE_CONFIG.STATUS_BROADCAST_FREQUENCY )

-- Periodic garbage collection to prevent Lua memory buildup
SCHEDULER:New( nil, function()
    collectgarbage("collect")
    local memKB = collectgarbage("count")
    log(string.format("[MEMORY] Lua garbage collection complete. Current usage: %.1f MB", memKB / 1024))
  end, {}, 120, MESSAGE_CONFIG.GARBAGE_COLLECTION_FREQUENCY )

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
  MessageToCoalition(US_CC, "zoneMarkersRefreshed", nil, coalition.side.BLUE, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION)
  MessageToCoalition(RU_CC, "zoneMarkersRefreshed", nil, coalition.side.RED, MESSAGE_CONFIG.STATUS_MESSAGE_DURATION)
end

-- NOTE: All menus are now created per-player in CreatePlayerLanguageMenu() function below
-- No coalition-wide menus needed

-- ==========================================
-- PER-PLAYER MENU SETUP (ALL ZONE CONTROL FUNCTIONS)
-- ==========================================
-- Track player menus to avoid duplicates per group
-- Key format: "playerName|groupName" to handle aircraft switches
local playerMenus = {}

-- Function to create complete Zone Control menu for a specific player
local function CreatePlayerMenu(playerUnit)
  env.info("[MENU DEBUG] CreatePlayerMenu called")
  if not playerUnit then 
    env.info("[MENU DEBUG] No playerUnit")
    return 
  end
  
  local playerName = playerUnit:getPlayerName()
  env.info(string.format("[MENU DEBUG] PlayerName: %s", tostring(playerName)))
  if not playerName then return end
  
  -- Get DCS group and convert to MOOSE GROUP wrapper
  local dcsGroup = playerUnit:getGroup()
  env.info(string.format("[MENU DEBUG] DCS Group: %s", tostring(dcsGroup and dcsGroup:getName() or "nil")))
  if not dcsGroup then return end
  
  local groupName = dcsGroup:getName()
  local group = GROUP:FindByName(groupName)
  env.info(string.format("[MENU DEBUG] MOOSE Group found: %s", tostring(group ~= nil)))
  if not group then return end
  
  local menuKey = playerName .. "|" .. groupName
  
  -- Don't create duplicate menus for same player in same group
  if playerMenus[menuKey] then 
    env.info(string.format("[MENU DEBUG] Menu already exists for %s", menuKey))
    return 
  end
  
  local playerCoalition = playerUnit:getCoalition()
  
  -- Get appropriate command center
  local commandCenter = playerCoalition == coalition.side.BLUE and US_CC or RU_CC
  if not commandCenter then 
    env.info("[MENU DEBUG] No command center found")
    return 
  end
  
  env.info(string.format("[MENU] Creating Zone Control menu for player %s (group: %s)", playerName, groupName))
  
  -- Create Zone Control root menu (use GROUP object, not group name string)
  -- Use MenuManager if available to nest under "Mission Options"
  local zoneControlMenu = MenuManager and MenuManager.CreateGroupMenu(group, GetText("menuZoneControl", playerName))
                          or MENU_GROUP:New(group, GetText("menuZoneControl", playerName))
  
  -- Add Zone Status Report command
  MENU_GROUP_COMMAND:New(group, GetText("menuStatusReport", playerName), zoneControlMenu, function()
    BroadcastZoneStatus()
  end)
  
  -- Add Victory Progress command
  MENU_GROUP_COMMAND:New(group, GetText("menuVictoryProgress", playerName), zoneControlMenu, function()
    local status = GetZoneOwnershipStatus()
    local totalZones = math.max(status.total, 1)
    local progressPercent = 0
    
    -- Calculate progress based on player's coalition
    if playerCoalition == coalition.side.BLUE then
      progressPercent = math.floor((status.blue / totalZones) * 100)
    else
      progressPercent = math.floor((status.red / totalZones) * 100)
    end
    
    -- Determine progress message based on percentage
    local progressMsg
    if progressPercent >= 100 then
      progressMsg = GetText("progressComplete", playerName)
    elseif progressPercent >= 80 then
      progressMsg = GetText("progressAlmostThere", playerName)
    elseif progressPercent >= 50 then
      progressMsg = GetText("progressGood", playerName)
    else
      progressMsg = GetText("progressKeepFighting", playerName)
    end
    
    local zonesCaptured = playerCoalition == coalition.side.BLUE and status.blue or status.red
    local zonesRemaining = status.total - zonesCaptured
    
    MESSAGE:New(
      string.format(
        "%s\n%s\n%s\n\n%s",
        string.format(GetText("victoryProgressTitle", playerName), progressPercent),
        string.format(GetText("zonesCaptured", playerName), zonesCaptured, status.total),
        string.format(GetText("zonesRemaining", playerName), zonesRemaining),
        progressMsg
      ),
      MESSAGE_CONFIG.STATUS_MESSAGE_DURATION
    ):ToGroup(group)
  end)
  
  -- Add Refresh Zone Colors command
  MENU_GROUP_COMMAND:New(group, GetText("menuRefreshColors", playerName), zoneControlMenu, function()
    RefreshAllZoneColors()
  end)
  
  -- Create Language submenu
  local langMenu = MENU_GROUP:New(group, GetText("menuLanguage", playerName), zoneControlMenu)
  
  -- Add language options
  MENU_GROUP_COMMAND:New(group, GetText("menuEnglish", playerName), langMenu, function()
    SetPlayerLanguage(playerName, "EN")
    MESSAGE:New(GetText("languageChanged", playerName), 5):ToGroup(group)
  end)
  
  MENU_GROUP_COMMAND:New(group, GetText("menuGerman", playerName), langMenu, function()
    SetPlayerLanguage(playerName, "DE")
    MESSAGE:New(GetText("languageChanged", playerName), 5):ToGroup(group)
  end)
  
  MENU_GROUP_COMMAND:New(group, GetText("menuFrench", playerName), langMenu, function()
    SetPlayerLanguage(playerName, "FR")
    MESSAGE:New(GetText("languageChanged", playerName), 5):ToGroup(group)
  end)
  
  MENU_GROUP_COMMAND:New(group, GetText("menuSpanish", playerName), langMenu, function()
    SetPlayerLanguage(playerName, "ES")
    MESSAGE:New(GetText("languageChanged", playerName), 5):ToGroup(group)
  end)
  
  MENU_GROUP_COMMAND:New(group, GetText("menuRussian", playerName), langMenu, function()
    SetPlayerLanguage(playerName, "RU")
    MESSAGE:New(GetText("languageChanged", playerName), 5):ToGroup(group)
  end)
  
  playerMenus[menuKey] = true
  log(string.format("[MENU] Zone Control menu created for %s in group %s", playerName, groupName))
end

-- Event handler to create player menus when players spawn
local function OnPlayerBirth(event)
  env.info(string.format("[MENU DEBUG] OnPlayerBirth called, event id: %s", tostring(event.id)))
  if event.id == world.event.S_EVENT_BIRTH and event.initiator then
    local unit = event.initiator
    local playerName = unit and unit:getPlayerName()
    env.info(string.format("[MENU DEBUG] Birth event for player: %s", tostring(playerName)))
    if unit and playerName then
      -- Small delay to ensure everything is initialized
      timer.scheduleFunction(function()
        CreatePlayerMenu(unit)
      end, nil, timer.getTime() + 2)
    end
  end
end

-- Set up event handler
world.addEventHandler({
  onEvent = OnPlayerBirth
})

-- Create menus for any players already in the mission
timer.scheduleFunction(function()
  env.info("[MENU] Checking for existing players...")
  for _, coalitionSide in pairs({coalition.side.BLUE, coalition.side.RED}) do
    local players = coalition.getPlayers(coalitionSide)
    env.info(string.format("[MENU DEBUG] Found %d players in coalition %d", players and #players or 0, coalitionSide))
    if players then
      for _, unit in ipairs(players) do
        local playerName = unit and unit:getPlayerName()
        env.info(string.format("[MENU DEBUG] Processing existing player: %s", tostring(playerName)))
        if unit and playerName then
          CreatePlayerMenu(unit)
        end
      end
    end
  end
end, nil, timer.getTime() + 5)

-- Initialize zone status monitoring
SCHEDULER:New( nil, function()
  log("[VICTORY SYSTEM] Initializing zone monitoring system...")
  
  -- Initialize performance optimization caches
  InitializeCachedUnitSet()
  
  -- Note: All menus are created per-player via event handlers
  
  -- Initial status report
  SCHEDULER:New( nil, function()
    log("[VICTORY SYSTEM] Broadcasting initial zone status...")
    BroadcastZoneStatus()
  end, {}, 30 ) -- Initial report after 30 seconds
  
end, {}, 5 ) -- Initialize after 5 seconds

log("[VICTORY SYSTEM] Zone capture victory monitoring system loaded successfully!")
log(string.format("[CONFIG] Loaded %d zones from configuration", totalZones))
