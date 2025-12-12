---@diagnostic disable: undefined-field, undefined-global
---@diagnostic disable: undefined-global, lowercase-global
-- WWII Pilot Intuition System using Moose Framework
--
-- Description:
-- This script simulates a WWII-era pilot intuition system for DCS World missions. It enhances immersion by providing realistic reconnaissance capabilities,
-- alerting pilots to nearby air and ground threats through voice-like messages and optional markers, mimicking how pilots spotted targets in WWII without modern aids.
--
-- Purpose:
-- To bridge the gap between modern DCS gameplay and historical WWII aviation, where situational awareness relied on visual scanning, formation flying, and intuition.
-- It helps players maintain awareness of their surroundings in dense or chaotic environments, promoting better tactics and immersion.
--
-- Use Case:
-- Ideal for WWII-themed missions, dogfights, or ground attack scenarios. Players can fly without relying on radar or labels, using the system to spot bandits,
-- ground units, and receive formation feedback. It's particularly useful in multiplayer servers for coordinated flights or solo play for enhanced challenge.

-- Features:
-- - **Dynamic Detection Ranges**: Detection ranges automatically adjust based on formation flying and environmental conditions. Flying in tight formations with wingmen significantly boosts spotting distances for both air and ground targets. For example, a solo pilot might detect air targets at 5km, but in a 2-ship formation, this increases to 10km, and in a 4-ship formation to 15km. Environmental factors like night reduce ranges (e.g., 50% at night), while bad weather can further decrease visibility. This simulates historical WWII reconnaissance where formation integrity was crucial for situational awareness.
-- - Line of Sight checks to ensure targets are only reported when visible.
-- - Realistic messaging simulating pilot radio calls for spotting bandits and ground threats.
-- - Formation integrity monitoring with alerts for wingmen presence.
-- - Dogfight assistance with alerts for merging bandits, tail warnings, head-on threats, and more.
-- - Optional visual markers (smoke, flares) for spotted targets, with selectable colors.
-- - Independent toggles for air target scanning, both globally (mission-wide) and per-player.
-- - On-demand ground target scanning with selective marking: scan nearby targets, review list, and choose which one to mark.
-- - Configurable settings via F10 menu for players to customize their experience.
-- - Scheduled summaries for players preferring less frequent updates.
-- - Per Player customization of dogfight assistance, marker types, and scanning preferences and message frequency.
-- - Per Player Multi Language Support: English, German, French, Spanish, Russian.

--
-- Setup Instructions:
-- 1. Ensure the Moose framework is installed and loaded in your DCS mission (download from https://flightcontrol-master.github.io/MOOSE_DOCS/).
-- 2. Add this script to your mission via the DCS Mission Editor: Go to Triggers > Mission Start > Do Script File, and select this Lua file.
-- 3. Optionally, customize the PILOT_INTUITION_CONFIG table below to adjust ranges, multipliers, and behaviors to fit your mission.
-- 4. The system initializes automatically on mission start. Players will see a welcome message and can access settings via the F10 menu.
-- 5. For best results, test in a mission with active AI units or other players to verify detection ranges and messaging.

-- Logging system (0=NONE, 1=ERROR, 2=INFO, 3=DEBUG, 4=TRACE)
PILOT_INTUITION_LOG_LEVEL = 1  -- Default to INFO level

local function PILog(level, message)
    if level <= PILOT_INTUITION_LOG_LEVEL then
        env.info(message)
    end
end

-- Log level constants
local LOG_NONE = 0
local LOG_ERROR = 1
local LOG_INFO = 2
local LOG_DEBUG = 3
local LOG_TRACE = 4

-- Global configuration table for settings
PILOT_INTUITION_CONFIG = {
    airDetectionRange = 8000,  -- Meters (base range for air targets) (can be modified by formation and environment)
    groundDetectionRange = 5000,  -- Meters (base range for ground targets) (can be modified by formation and environment)
    messageCooldown = 10,  -- Seconds between messages
    markerType = "smoke_red",  -- Options: "smoke_red", "smoke_green", "smoke_blue", "smoke_white", "flare_red", "flare_green", "flare_white", "none"
    markerDuration = 300,  -- Seconds for marker visibility (dcs default can't be changed, so this is just for reference)
    threatHotRange = 1000,  -- Meters for "hot" threat
    threatColdRange = 5000,  -- Meters for "cold" threat
    scanInterval = 5,  -- Seconds between scans
    mergeRange = 500,  -- Meters for merge detection
    highMergeAltitude = 500,  -- Meters altitude difference for "high merge"
    lowMergeAltitude = 500,  -- Meters altitude difference for "low merge"
    tailWarningRange = 1000,  -- Meters for tail warnings
    headOnRange = 1000,  -- Meters for head-on detection
    beamRange = 1500,  -- Meters for beam aspect detection
    separatingRange = 2000,  -- Meters - if opening past this after merge, call "separating"
    multipleBanditsRange = 2000,  -- Meters for multiple bandits detection
    multipleBanditsWarningCooldown = 300,  -- Seconds between "Multiple bandits in vicinity!" warnings (5 minutes)
    maxThreatDisplay = 3,  -- Maximum number of threats to display in multi-bandit tactical picture (most threatening first)
    combatIntensityThreshold = 3,  -- Number of bandits to trigger "high intensity" mode (increases cooldowns)
    combatIntensityCooldownMultiplier = 1.5,  -- Multiply dogfight assist cooldown by this during high intensity combat
    suppressFormationInCombat = true,  -- Suppress formation join/leave messages when engaged with bandits
    formationRange = 1000,  -- Meters for considering players in formation
    minFormationWingmen = 1,  -- Minimum wingmen for formation integrity warnings
    formationMessageCooldown = 60,  -- Seconds cooldown for formation join/leave messages (prevents spam)
    nightDetectionMultiplier = 0.5,  -- Detection range multiplier at night
    badWeatherMultiplier = 0.7,  -- Detection range multiplier in bad weather
    dogfightAssistEnabled = true,  -- Enable dogfight assistance by default
    dogfightMessageCooldown = 3,  -- Seconds between dogfight assist messages
    criticalSpeedThreshold = 150,  -- Knots - warn if speed drops below this in dogfight
    altitudeDeltaThreshold = 300,  -- Meters - significant altitude difference for callouts
    highClosureRate = 100,  -- M/s - warn if closure rate exceeds this
    positionChangeThreshold = 45,  -- Degrees - trigger update if bandit moves this much
    maxMultiplier = 8,  -- Max detection multiplier to prevent excessive ranges
    summaryInterval = 120,  -- Seconds between scheduled summaries (0 to disable)
    summaryCooldown = 2,  -- Minimum seconds between on-demand summaries
    activeMessaging = true,  -- Enable live alerts; false for on-demand only
    showGlobalMenu = true,  -- Enable global settings menu for players
    showWelcomeMessage = true,  -- Show welcome message to new players
    enableCloseFlyingCompliments = true,  -- Enable compliments for close flying
    complimentRange = 75,  -- Meters for close flying compliment
    headOnWarningRange = 150,  -- Meters for head-on warning
    closeFlyingMessageCooldown = 26,  -- Seconds between close flying messages
    enableAirScanning = true,  -- Enable scanning for air targets
    enableGroundScanning = false,  -- Enable scanning for ground targets
    illuminationCooldown = 30,  -- Seconds between illumination flare drops (simulates reload time)
    illuminationAltitude = 500,  -- Meters - altitude offset above target for illumination flares
    illuminationFlaresDefault = 3,  -- Number of illumination flares per sortie
    countAIWingmen = true,  -- Count AI units in same group as wingmen for formation bonus (false = players only count as wingmen)
    aiWingmenMultiplier = 1.0,  -- Multiplier for AI wingmen (0.5 = half credit, 1.0 = full credit)
    distanceUnit = "mi",  -- Default distance unit: "km" for kilometers, "mi" for miles (nautical miles)
    defaultLanguage = "EN",  -- Default language: "EN", "DE", "FR", "ES", "RU"
}

-- Multilingual message and menu tables
-- Each language contains all messages and menu text
PILOT_INTUITION_LANGUAGES = {
    EN = {
        -- Messages
        welcome = {
        "Welcome to WWII Pilot Intuition! This system simulates pilot reconnaissance for spotting air and ground targets. Use F10 menu for settings.",
        "Greetings, pilot! WWII Pilot Intuition is active. It helps you spot bandits and ground threats. Check F10 for options.",
        "Pilot Intuition engaged! Simulate WWII-era reconnaissance. F10 menu for controls.",
        },
        formationJoin = {
        "You've joined flight with %s - air detection increased to %.0f%s, ground to %.0f%s.",
        "%s is now flying off your wing - detection ranges boosted to %.0f%s air, %.0f%s ground.",
        "Welcome aboard, %s! Formation tightens detection to %.0f%s for air, %.0f%s for ground.",
        "%s joins the formation - eyes sharper now, %.0f%s air, %.0f%s ground range.",
        },
        formationLeave = {
        "%s left formation - air detection reduced to %.0f%s, ground to %.0f%s.",
        "%s is outa here - detection drops to %.0f%s air, %.0f%s ground.",
        "Formation broken by %s - ranges now %.0f%s air, %.0f%s ground.",
        "%s has peeled off - back to solo detection: %.0f%s air, %.0f%s ground.",
        },
        formationIntegrityLow = {
        "Formation integrity low! Tighten up.",
        "Form up, pilots! We're spread too thin.",
        "Close ranks! Formation integrity compromised.",
            "Get back in formation, lads! We're vulnerable.",
        },
        airTargetDetected = {
        "Bandit %s at %.0f degrees, %.1f %s, angels %.0f (%s)!",
        "Enemy aircraft %s: %.0f degrees, %.1f %s, altitude %.0f (%s).",
        "Bogey %s at %.0f o'clock, %.1f %s out, angels %.0f (%s).",
        "Hostile contact %s: %.0f degrees, %.1f %s, %.0f angels (%s).",
        "Bandit inbound %s: %.0f degrees, %.1f %s, angels %.0f (%s).",
        },
        groundTargetDetected = {
        "%s contact: %s %s at %.0f degrees, %.1f %s.",
        "Ground threat: %s %s %s spotted at %.0f degrees, %.1f %s.",
        "%s units detected: %s %s, %.0f degrees, %.1f %s.",
        "Enemy ground: %s %s %s at bearing %.0f, %.1f %s away.",
        },
        dogfightEngaged = {
        "Engaged!",
        "Tally ho! Dogfight started.",
        "Bandit engaged! Fight's on.",
        "Dogfight! Guns hot.",
        },
        dogfightConcluded = {
        "Dogfight concluded.",
        "Fight's over. Clear.",
        "Dogfight ended. Stand down.",
        "Engagement terminated.",
        },
        underFire = {
        "Under fire! Break %s!%s",
        "Taking hits! Evade %s!%s",
        "Shots fired! Turn %s now!%s",
        "Incoming! Break %s!%s",
        },
        closeFlyingCompliment = {
            "Nice flying! Tip-to-tip formation.",
            "Hey, nice! That's some close flying.",
            "Great job! That's close!",
            "Easy does it there tiger, I don't know you that well!",
            "Impressive! Wingtip to wingtip.",
            "Smooth moves! Close quarters flying.",
            "Damn, that's tight! Good flying.",
            "Holy shit, that's close! Nice one.",
            "Whew, that was close! Good stick work.",
            "You're glued to my wing! Excellent flying.",
            "Tight as a drum! Keep it up.",
            "Helluva formation! Tip to tip.",
            "Smooth as silk! Close flying there.",
            "Damn, pilot! That's some precision.",
            "Whoa, easy on the throttle! Nice and close.",
            "Impressive control! Wingtip distance.",
            "You're right on my six... wait, formation! Good job.",
            "Tight formation! That's how it's done.",
            "Holy cow, that's close! Well done.",
            "Nice touch! Close quarters.",
            "You're flying like a pro! Tight formation.",
            "Smooth operator! Tip-to-tip.",
            "Damn fine flying! Close as can be.",
            "Whoa there! That's some tight flying.",
            "Impressive! You're practically in my cockpit.",
            "Smooth sailing! Close formation.",
            "Hell yeah, that's tight! Good work.",
            "Easy tiger, but damn good flying.",
            "You're a formation expert! Tip-to-tip.",
            "Smooth moves, pilot! Close quarters.",
        },
        headOnWarning = {
            "Whew! That was close!",
            "Whoa! Nearly a head-on!",
            "Close call! Watch that pass.",
            "Damn, that was tight! Be careful.",
            "Holy crap, almost collided!",
        },
        markerSet = {
            "Marker set to %s.",
            "Markers now %s.",
            "Marker type changed to %s.",
        },
        dogfightAssistToggle = {
            "Dogfight assist %s.",
            "Dogfight assistance %s.",
        },
        activeMessagingToggle = {
            "Active messaging %s.",
            "Live alerts %s.",
        },
        airScanningToggle = {
            "Air scanning %s.",
            "Air detection %s.",
        },
        groundScanningToggle = {
            "Ground scanning %s.",
            "Ground detection %s.",
        },
        alertFrequencyToggle = {
            "Alert frequency set to %s.",
            "Alerts now %s.",
        },
        summaryCooldown = {
            "Summary on cooldown.",
            "Wait a bit for another summary.",
        },
        noThreats = {
            "No active threats.",
            "All clear.",
            "Situation normal.",
        },
        -- Additional hardcoded messages that need translation
        systemActive = "WWII Pilot Intuition active! Use F10 menu for settings.",
        logLevelSet = "Log level set to: %s",
        distanceUnitsSet = "Distance units set to %s.",
        targetNotAvailable = "Target %d not available.",
        markedTarget = "Marked Target %d.",
        noIlluminationFlares = "No illumination flares remaining. Land at a friendly airbase to rearm.",
        illuminationNotReady = "Illumination not ready. Wait %d seconds.",
        cannotDeterminePosition = "Cannot determine position for illumination drop.",
        cannotDetermineAltitude = "Cannot determine altitude for illumination drop.",
        illuminationDropped = "Illumination flare dropped at your position. (%d remaining)",
        cannotDetermineTargetPosition = "Cannot determine target position for illumination drop.",
        errorCouldNotDeterminePosition = "Error: Could not determine your position.",
        illuminationDroppedOnTarget = "Illumination flare dropped on Target %d (%.0f°, %.1f%s). (%d remaining)",
        illuminationRearmed = "Illumination flares rearmed: %d available.",
        noGroundTargets = "No enemy ground targets detected in range.",
        selectTargetFromMenu = "Select a target from the menu to mark it.",
        targetInfo = "Target %d: %s %s %s, Bearing %.0f, Range %.1f %s",
        -- State words
        enabled = "enabled",
        disabled = "disabled",
        hot = "hot",
        cold = "cold",
        closing = "closing",
        opening = "opening",
        left = "left",
        right = "right",
        above = "above",
        below = "below",
        high = "high",
        low = "low",
        normal = "normal",
        quiet = "quiet",
        verbose = "verbose",
        -- Menu text
        menu = {
            mainTitle = "WWII Pilot Intuition",
            dogfightAssist = "Dogfight Assist",
            enable = "Enable",
            disable = "Disable",
            markerType = "Marker Type",
            smoke = "Smoke",
            flare = "Flare",
            red = "Red",
            green = "Green",
            blue = "Blue",
            white = "White",
            none = "None",
            airScanning = "Air Scanning",
            groundScanning = "Ground Scanning",
            groundTargeting = "Ground Targeting",
            scanForTargets = "Scan for Targets",
            markTarget = "Mark Target",
            target = "Target %d",
            illumination = "Illumination (%d left)",
            dropAtMyPosition = "Drop at My Position",
            dropOnTarget = "Drop on Target",
            alertFrequency = "Alert Frequency",
            normalFreq = "Normal",
            quietFreq = "Quiet",
            verboseFreq = "Verbose",
            summary = "Summary",
            brief = "Brief",
            detailed = "Detailed",
            settingsAndGuides = "Settings & Player Guides",
            distanceUnits = "Distance Units",
            milesNautical = "Miles (Nautical)",
            kilometers = "Kilometers",
            playerGuide = "Player Guide",
            systemOverview = "System Overview",
            detectionRanges = "Detection Ranges",
            dogfightAssistHelp = "Dogfight Assist Help",
            groundTargetingHelp = "Ground Targeting Help",
            formationTips = "Formation Tips",
            illuminationHelp = "Illumination Help",
            logLevel = "Log Level",
            language = "Language / Sprache / Langue",
            english = "English",
            german = "Deutsch (German)",
            french = "Français (French)",
            spanish = "Español (Spanish)",
            russian = "Русский (Russian)",
        }
    },
    -- German language
    DE = {
        welcome = {
            "Willkommen bei WWII Piloten-Intuition! Dieses System simuliert Piloten-Aufklärung zum Erkennen von Luft- und Bodenzielen. Verwenden Sie das F10-Menü für Einstellungen.",
            "Grüße, Pilot! WWII Piloten-Intuition ist aktiv. Es hilft Ihnen, Banditen und Bodenbedrohungen zu erkennen. Prüfen Sie F10 für Optionen.",
            "Piloten-Intuition aktiviert! Simulieren Sie Aufklärung aus der WWII-Ära. F10-Menü für Steuerung.",
        },
        formationJoin = {
            "Sie haben sich dem Flug mit %s angeschlossen - Lufterkennung erhöht auf %.0f%s, Boden auf %.0f%s.",
            "%s fliegt jetzt an Ihrem Flügel - Erkennungsreichweiten erhöht auf %.0f%s Luft, %.0f%s Boden.",
            "Willkommen an Bord, %s! Formation verbessert Erkennung auf %.0f%s für Luft, %.0f%s für Boden.",
            "%s schließt sich der Formation an - Augen sind schärfer jetzt, %.0f%s Luft, %.0f%s Boden Reichweite.",
        },
        formationLeave = {
            "%s hat Formation verlassen - Lufterkennung reduziert auf %.0f%s, Boden auf %.0f%s.",
            "%s ist weg - Erkennung fällt auf %.0f%s Luft, %.0f%s Boden.",
            "Formation durch %s aufgelöst - Reichweiten jetzt %.0f%s Luft, %.0f%s Boden.",
            "%s hat sich abgesetzt - zurück zur Solo-Erkennung: %.0f%s Luft, %.0f%s Boden.",
        },
        formationIntegrityLow = {
            "Formationsintegrität niedrig! Zusammenrücken.",
            "Formiert euch, Piloten! Wir sind zu weit auseinander.",
            "Reihen schließen! Formationsintegrität gefährdet.",
            "Zurück in Formation, Leute! Wir sind verwundbar.",
        },
        airTargetDetected = {
            "Bandit %s bei %.0f Grad, %.1f %s, Engel %.0f (%s)!",
            "Feindflugzeug %s: %.0f Grad, %.1f %s, Höhe %.0f (%s).",
            "Bogey %s bei %.0f Uhr, %.1f %s entfernt, Engel %.0f (%s).",
            "Feindkontakt %s: %.0f Grad, %.1f %s, %.0f Engel (%s).",
            "Bandit im Anflug %s: %.0f Grad, %.1f %s, Engel %.0f (%s).",
        },
        groundTargetDetected = {
            "%s Kontakt: %s %s bei %.0f Grad, %.1f %s.",
            "Bodenbedrohung: %s %s %s gesichtet bei %.0f Grad, %.1f %s.",
            "%s Einheiten entdeckt: %s %s, %.0f Grad, %.1f %s.",
            "Feindlicher Boden: %s %s %s bei Peilung %.0f, %.1f %s entfernt.",
        },
        dogfightEngaged = {
            "Im Gefecht!",
            "Tally ho! Luftkampf begonnen.",
            "Bandit im Gefecht! Kampf läuft.",
            "Luftkampf! Waffen scharf.",
        },
        dogfightConcluded = {
            "Luftkampf beendet.",
            "Kampf vorbei. Klar.",
            "Luftkampf beendet. Entspannen.",
            "Gefecht beendet.",
        },
        underFire = {
            "Unter Beschuss! Ausweichen %s!%s",
            "Treffer einsteckend! Ausweichen %s!%s",
            "Schüsse abgefeuert! Wende %s jetzt!%s",
            "Eingehend! Ausweichen %s!%s",
        },
        closeFlyingCompliment = {
            "Schönes Fliegen! Spitze-zu-Spitze-Formation.",
            "Hey, schön! Das ist enges Fliegen.",
            "Großartige Arbeit! Das ist nah!",
            "Ruhig, Tiger, ich kenne dich nicht so gut!",
            "Beeindruckend! Flügelspitze zu Flügelspitze.",
            "Geschmeidige Bewegungen! Nahkampffliegen.",
            "Verdammt, das ist eng! Gutes Fliegen.",
            "Heilige Scheiße, das ist nah! Gut gemacht.",
            "Puh, das war knapp! Gute Steuerung.",
            "Du klebst an meinem Flügel! Exzellentes Fliegen.",
        },
        headOnWarning = {
            "Puh! Das war knapp!",
            "Whoa! Fast frontal!",
            "Knapper Anruf! Pass auf beim Überholen.",
            "Verdammt, das war eng! Sei vorsichtig.",
            "Heiliger Mist, fast kollidiert!",
        },
        markerSet = {
            "Markierung auf %s gesetzt.",
            "Markierungen jetzt %s.",
            "Markierungstyp geändert auf %s.",
        },
        dogfightAssistToggle = {
            "Luftkampf-Hilfe %s.",
            "Luftkampf-Unterstützung %s.",
        },
        activeMessagingToggle = {
            "Aktive Benachrichtigungen %s.",
            "Live-Warnungen %s.",
        },
        airScanningToggle = {
            "Luftscan %s.",
            "Lufterkennung %s.",
        },
        groundScanningToggle = {
            "Bodenscan %s.",
            "Bodenerkennung %s.",
        },
        alertFrequencyToggle = {
            "Warnfrequenz auf %s eingestellt.",
            "Warnungen jetzt %s.",
        },
        summaryCooldown = {
            "Zusammenfassung in Abklingzeit.",
            "Warten Sie etwas für eine weitere Zusammenfassung.",
        },
        noThreats = {
            "Keine aktiven Bedrohungen.",
            "Alles klar.",
            "Situation normal.",
        },
        systemActive = "WWII Piloten-Intuition aktiv! Verwenden Sie das F10-Menü für Einstellungen.",
        logLevelSet = "Log-Level auf %s gesetzt",
        distanceUnitsSet = "Entfernungseinheiten auf %s eingestellt.",
        targetNotAvailable = "Ziel %d nicht verfügbar.",
        markedTarget = "Ziel %d markiert.",
        noIlluminationFlares = "Keine Leuchtraketen mehr. Landen Sie auf einem befreundeten Flugplatz zum Auftanken.",
        illuminationNotReady = "Beleuchtung nicht bereit. Warten Sie %d Sekunden.",
        cannotDeterminePosition = "Kann Position für Leuchtraketen-Abwurf nicht bestimmen.",
        cannotDetermineAltitude = "Kann Höhe für Leuchtraketen-Abwurf nicht bestimmen.",
        illuminationDropped = "Leuchtrakete an Ihrer Position abgeworfen. (%d verbleibend)",
        cannotDetermineTargetPosition = "Kann Zielposition für Leuchtraketen-Abwurf nicht bestimmen.",
        errorCouldNotDeterminePosition = "Fehler: Konnte Ihre Position nicht bestimmen.",
        illuminationDroppedOnTarget = "Leuchtrakete auf Ziel %d abgeworfen (%.0f°, %.1f%s). (%d verbleibend)",
        illuminationRearmed = "Leuchtraketen aufgefüllt: %d verfügbar.",
        noGroundTargets = "Keine feindlichen Bodenziele in Reichweite erkannt.",
        selectTargetFromMenu = "Wählen Sie ein Ziel aus dem Menü zum Markieren.",
        targetInfo = "Ziel %d: %s %s %s, Peilung %.0f, Reichweite %.1f %s",
        enabled = "aktiviert",
        disabled = "deaktiviert",
        hot = "heiß",
        cold = "kalt",
        closing = "schließend",
        opening = "öffnend",
        left = "links",
        right = "rechts",
        above = "oben",
        below = "unten",
        high = "hoch",
        low = "niedrig",
        normal = "normal",
        quiet = "ruhig",
        verbose = "ausführlich",
        menu = {
            mainTitle = "WWII Piloten-Intuition",
            dogfightAssist = "Luftkampf-Hilfe",
            enable = "Aktivieren",
            disable = "Deaktivieren",
            markerType = "Markierungstyp",
            smoke = "Rauch",
            flare = "Leuchtrakete",
            red = "Rot",
            green = "Grün",
            blue = "Blau",
            white = "Weiß",
            none = "Keine",
            airScanning = "Luftscan",
            groundScanning = "Bodenscan",
            groundTargeting = "Bodenziel-Erfassung",
            scanForTargets = "Nach Zielen scannen",
            markTarget = "Ziel markieren",
            target = "Ziel %d",
            illumination = "Beleuchtung (%d übrig)",
            dropAtMyPosition = "An meiner Position abwerfen",
            dropOnTarget = "Auf Ziel abwerfen",
            alertFrequency = "Warnfrequenz",
            normalFreq = "Normal",
            quietFreq = "Ruhig",
            verboseFreq = "Ausführlich",
            summary = "Zusammenfassung",
            brief = "Kurz",
            detailed = "Detailliert",
            settingsAndGuides = "Einstellungen & Spielerführer",
            distanceUnits = "Entfernungseinheiten",
            milesNautical = "Meilen (Nautisch)",
            kilometers = "Kilometer",
            playerGuide = "Spielerführer",
            systemOverview = "Systemübersicht",
            detectionRanges = "Erkennungsreichweiten",
            dogfightAssistHelp = "Luftkampf-Hilfe Anleitung",
            groundTargetingHelp = "Bodenziel-Erfassung Anleitung",
            formationTips = "Formationstipps",
            illuminationHelp = "Beleuchtungs-Hilfe",
            logLevel = "Log-Level",
            language = "Language / Sprache / Langue",
            english = "English (Englisch)",
            german = "Deutsch (German)",
            french = "Français (Französisch)",
            spanish = "Español (Spanisch)",
            russian = "Русский (Russisch)",
        }
    },
    -- French language
    FR = {
        welcome = {
            "Bienvenue dans WWII Intuition du Pilote! Ce système simule la reconnaissance du pilote pour repérer les cibles aériennes et terrestres. Utilisez le menu F10 pour les paramètres.",
            "Salutations, pilote! WWII Intuition du Pilote est actif. Il vous aide à repérer les bandits et les menaces au sol. Consultez F10 pour les options.",
            "Intuition du pilote engagée! Simulez la reconnaissance de l'ère WWII. Menu F10 pour les commandes.",
        },
        formationJoin = {
            "Vous avez rejoint le vol avec %s - détection aérienne augmentée à %.0f%s, sol à %.0f%s.",
            "%s vole maintenant sur votre aile - portées de détection augmentées à %.0f%s air, %.0f%s sol.",
            "Bienvenue à bord, %s! La formation améliore la détection à %.0f%s pour l'air, %.0f%s pour le sol.",
            "%s rejoint la formation - les yeux sont plus aiguisés maintenant, %.0f%s air, %.0f%s sol portée.",
        },
        formationLeave = {
            "%s a quitté la formation - détection aérienne réduite à %.0f%s, sol à %.0f%s.",
            "%s est parti - détection chute à %.0f%s air, %.0f%s sol.",
            "Formation rompue par %s - portées maintenant %.0f%s air, %.0f%s sol.",
            "%s s'est détaché - retour à la détection solo: %.0f%s air, %.0f%s sol.",
        },
        formationIntegrityLow = {
            "Intégrité de formation faible! Resserrez-vous.",
            "Formez-vous, pilotes! Nous sommes trop dispersés.",
            "Serrez les rangs! Intégrité de formation compromise.",
            "Revenez en formation, les gars! Nous sommes vulnérables.",
        },
        airTargetDetected = {
            "Bandit %s à %.0f degrés, %.1f %s, anges %.0f (%s)!",
            "Avion ennemi %s: %.0f degrés, %.1f %s, altitude %.0f (%s).",
            "Bogey %s à %.0f heures, %.1f %s, anges %.0f (%s).",
            "Contact hostile %s: %.0f degrés, %.1f %s, %.0f anges (%s).",
            "Bandit entrant %s: %.0f degrés, %.1f %s, anges %.0f (%s).",
        },
        groundTargetDetected = {
            "%s contact: %s %s à %.0f degrés, %.1f %s.",
            "Menace au sol: %s %s %s repéré à %.0f degrés, %.1f %s.",
            "%s unités détectées: %s %s, %.0f degrés, %.1f %s.",
            "Sol ennemi: %s %s %s au relèvement %.0f, %.1f %s de distance.",
        },
        dogfightEngaged = {
            "Engagé!",
            "Tally ho! Combat aérien commencé.",
            "Bandit engagé! Le combat est lancé.",
            "Combat aérien! Armes chaudes.",
        },
        dogfightConcluded = {
            "Combat aérien terminé.",
            "Combat terminé. Dégagé.",
            "Combat aérien terminé. Repos.",
            "Engagement terminé.",
        },
        underFire = {
            "Sous le feu! Rompez %s!%s",
            "Prend des coups! Évitez %s!%s",
            "Coups tirés! Tournez %s maintenant!%s",
            "Entrant! Rompez %s!%s",
        },
        closeFlyingCompliment = {
            "Beau vol! Formation bout à bout.",
            "Hey, sympa! C'est du vol serré.",
            "Excellent travail! C'est proche!",
            "Doucement, tigre, je ne te connais pas si bien!",
            "Impressionnant! Bout d'aile à bout d'aile.",
            "Mouvements fluides! Vol en quartiers serrés.",
            "Merde, c'est serré! Bon vol.",
            "Putain, c'est proche! Bien joué.",
            "Ouf, c'était proche! Bon maniement du manche.",
            "Tu es collé à mon aile! Excellent vol.",
        },
        headOnWarning = {
            "Ouf! C'était proche!",
            "Whoa! Presque en face!",
            "Appel serré! Attention à ce passage.",
            "Merde, c'était serré! Soyez prudent.",
            "Sainte merde, presque entré en collision!",
        },
        markerSet = {
            "Marqueur défini sur %s.",
            "Marqueurs maintenant %s.",
            "Type de marqueur changé en %s.",
        },
        dogfightAssistToggle = {
            "Assistance combat aérien %s.",
            "Assistance combat aérien %s.",
        },
        activeMessagingToggle = {
            "Messagerie active %s.",
            "Alertes en direct %s.",
        },
        airScanningToggle = {
            "Scan aérien %s.",
            "Détection aérienne %s.",
        },
        groundScanningToggle = {
            "Scan au sol %s.",
            "Détection au sol %s.",
        },
        alertFrequencyToggle = {
            "Fréquence d'alerte définie sur %s.",
            "Alertes maintenant %s.",
        },
        summaryCooldown = {
            "Résumé en temps de recharge.",
            "Attendez un peu pour un autre résumé.",
        },
        noThreats = {
            "Aucune menace active.",
            "Tout est clair.",
            "Situation normale.",
        },
        systemActive = "WWII Intuition du Pilote actif! Utilisez le menu F10 pour les paramètres.",
        logLevelSet = "Niveau de log défini sur: %s",
        distanceUnitsSet = "Unités de distance définies sur %s.",
        targetNotAvailable = "Cible %d non disponible.",
        markedTarget = "Cible %d marquée.",
        noIlluminationFlares = "Plus de fusées éclairantes. Atterrissez sur une base aérienne amie pour vous réarmer.",
        illuminationNotReady = "Illumination pas prête. Attendez %d secondes.",
        cannotDeterminePosition = "Impossible de déterminer la position pour le largage de fusée éclairante.",
        cannotDetermineAltitude = "Impossible de déterminer l'altitude pour le largage de fusée éclairante.",
        illuminationDropped = "Fusée éclairante larguée à votre position. (%d restantes)",
        cannotDetermineTargetPosition = "Impossible de déterminer la position de la cible pour le largage de fusée éclairante.",
        errorCouldNotDeterminePosition = "Erreur: Impossible de déterminer votre position.",
        illuminationDroppedOnTarget = "Fusée éclairante larguée sur cible %d (%.0f°, %.1f%s). (%d restantes)",
        illuminationRearmed = "Fusées éclairantes réarmées: %d disponibles.",
        noGroundTargets = "Aucune cible terrestre ennemie détectée à portée.",
        selectTargetFromMenu = "Sélectionnez une cible dans le menu pour la marquer.",
        targetInfo = "Cible %d: %s %s %s, Relèvement %.0f, Portée %.1f %s",
        enabled = "activé",
        disabled = "désactivé",
        hot = "chaud",
        cold = "froid",
        closing = "rapprochement",
        opening = "éloignement",
        left = "gauche",
        right = "droite",
        above = "au-dessus",
        below = "en-dessous",
        high = "haut",
        low = "bas",
        normal = "normal",
        quiet = "calme",
        verbose = "verbeux",
        menu = {
            mainTitle = "Intuition du Pilote WWII",
            dogfightAssist = "Assistance Combat Aérien",
            enable = "Activer",
            disable = "Désactiver",
            markerType = "Type de Marqueur",
            smoke = "Fumée",
            flare = "Fusée",
            red = "Rouge",
            green = "Vert",
            blue = "Bleu",
            white = "Blanc",
            none = "Aucun",
            airScanning = "Scan Aérien",
            groundScanning = "Scan au Sol",
            groundTargeting = "Ciblage au Sol",
            scanForTargets = "Scanner les Cibles",
            markTarget = "Marquer Cible",
            target = "Cible %d",
            illumination = "Illumination (%d restantes)",
            dropAtMyPosition = "Larguer à ma Position",
            dropOnTarget = "Larguer sur Cible",
            alertFrequency = "Fréquence d'Alerte",
            normalFreq = "Normal",
            quietFreq = "Calme",
            verboseFreq = "Verbeux",
            summary = "Résumé",
            brief = "Bref",
            detailed = "Détaillé",
            settingsAndGuides = "Paramètres & Guides Joueurs",
            distanceUnits = "Unités de Distance",
            milesNautical = "Miles (Nautiques)",
            kilometers = "Kilomètres",
            playerGuide = "Guide du Joueur",
            systemOverview = "Aperçu du Système",
            detectionRanges = "Portées de Détection",
            dogfightAssistHelp = "Aide Combat Aérien",
            groundTargetingHelp = "Aide Ciblage au Sol",
            formationTips = "Conseils Formation",
            illuminationHelp = "Aide Illumination",
            logLevel = "Niveau de Log",
            language = "Language / Sprache / Langue",
            english = "English (Anglais)",
            german = "Deutsch (Allemand)",
            french = "Français (French)",
            spanish = "Español (Espagnol)",
            russian = "Русский (Russe)",
        }
    },
    -- Spanish language
    ES = {
        welcome = {
            "¡Bienvenido a WWII Intuición del Piloto! Este sistema simula el reconocimiento del piloto para detectar objetivos aéreos y terrestres. Use el menú F10 para configuración.",
            "¡Saludos, piloto! WWII Intuición del Piloto está activo. Te ayuda a detectar bandidos y amenazas terrestres. Revisa F10 para opciones.",
            "¡Intuición del piloto activada! Simula reconocimiento de la era WWII. Menú F10 para controles.",
        },
        formationJoin = {
            "Te has unido al vuelo con %s - detección aérea aumentada a %.0f%s, terrestre a %.0f%s.",
            "%s ahora vuela en tu ala - rangos de detección aumentados a %.0f%s aéreo, %.0f%s terrestre.",
            "¡Bienvenido a bordo, %s! La formación mejora detección a %.0f%s para aéreo, %.0f%s para terrestre.",
            "%s se une a la formación - ojos más agudos ahora, %.0f%s aéreo, %.0f%s terrestre rango.",
        },
        formationLeave = {
            "%s dejó la formación - detección aérea reducida a %.0f%s, terrestre a %.0f%s.",
            "%s se fue - detección cae a %.0f%s aéreo, %.0f%s terrestre.",
            "Formación rota por %s - rangos ahora %.0f%s aéreo, %.0f%s terrestre.",
            "%s se ha separado - vuelta a detección solitaria: %.0f%s aéreo, %.0f%s terrestre.",
        },
        formationIntegrityLow = {
            "¡Integridad de formación baja! Aprieten.",
            "¡Formen, pilotos! Estamos demasiado dispersos.",
            "¡Cierren filas! Integridad de formación comprometida.",
            "¡Vuelvan a la formación, muchachos! Somos vulnerables.",
        },
        airTargetDetected = {
            "Bandido %s a %.0f grados, %.1f %s, ángeles %.0f (%s)!",
            "Aeronave enemiga %s: %.0f grados, %.1f %s, altitud %.0f (%s).",
            "Bogey %s a las %.0f en punto, %.1f %s fuera, ángeles %.0f (%s).",
            "Contacto hostil %s: %.0f grados, %.1f %s, %.0f ángeles (%s).",
            "Bandido entrante %s: %.0f grados, %.1f %s, ángeles %.0f (%s).",
        },
        groundTargetDetected = {
            "%s contacto: %s %s a %.0f grados, %.1f %s.",
            "Amenaza terrestre: %s %s %s avistado a %.0f grados, %.1f %s.",
            "%s unidades detectadas: %s %s, %.0f grados, %.1f %s.",
            "Terreno enemigo: %s %s %s en rumbo %.0f, %.1f %s de distancia.",
        },
        dogfightEngaged = {
            "¡Enganchado!",
            "¡Tally ho! Combate aéreo iniciado.",
            "¡Bandido enganchado! La pelea está en marcha.",
            "¡Combate aéreo! Armas calientes.",
        },
        dogfightConcluded = {
            "Combate aéreo concluido.",
            "Pelea terminada. Despejado.",
            "Combate aéreo terminado. Descanso.",
            "Enganche terminado.",
        },
        underFire = {
            "¡Bajo fuego! ¡Rompe %s!%s",
            "¡Recibiendo impactos! ¡Evade %s!%s",
            "¡Disparos! ¡Gira %s ahora!%s",
            "¡Entrante! ¡Rompe %s!%s",
        },
        closeFlyingCompliment = {
            "¡Buen vuelo! Formación punta con punta.",
            "¡Hey, bien! Eso es vuelo cerrado.",
            "¡Excelente trabajo! ¡Qué cerca!",
            "¡Despacio ahí tigre, no te conozco tan bien!",
            "¡Impresionante! Punta de ala con punta de ala.",
            "¡Movimientos suaves! Vuelo en cuartos cerrados.",
            "¡Diablos, qué ajustado! Buen vuelo.",
            "¡Mierda, qué cerca! Bien hecho.",
            "¡Uf, eso estuvo cerca! Buen control del stick.",
            "¡Estás pegado a mi ala! Excelente vuelo.",
        },
        headOnWarning = {
            "¡Uf! ¡Eso estuvo cerca!",
            "¡Whoa! ¡Casi de frente!",
            "¡Llamada cerrada! Cuidado con ese pase.",
            "¡Diablos, eso estuvo ajustado! Ten cuidado.",
            "¡Santo cielo, casi colisionamos!",
        },
        markerSet = {
            "Marcador establecido en %s.",
            "Marcadores ahora %s.",
            "Tipo de marcador cambiado a %s.",
        },
        dogfightAssistToggle = {
            "Asistencia de combate aéreo %s.",
            "Asistencia de combate aéreo %s.",
        },
        activeMessagingToggle = {
            "Mensajería activa %s.",
            "Alertas en vivo %s.",
        },
        airScanningToggle = {
            "Escaneo aéreo %s.",
            "Detección aérea %s.",
        },
        groundScanningToggle = {
            "Escaneo terrestre %s.",
            "Detección terrestre %s.",
        },
        alertFrequencyToggle = {
            "Frecuencia de alerta establecida en %s.",
            "Alertas ahora %s.",
        },
        summaryCooldown = {
            "Resumen en tiempo de reutilización.",
            "Espera un poco para otro resumen.",
        },
        noThreats = {
            "Sin amenazas activas.",
            "Todo despejado.",
            "Situación normal.",
        },
        systemActive = "¡WWII Intuición del Piloto activo! Use el menú F10 para configuración.",
        logLevelSet = "Nivel de registro establecido en: %s",
        distanceUnitsSet = "Unidades de distancia establecidas en %s.",
        targetNotAvailable = "Objetivo %d no disponible.",
        markedTarget = "Objetivo %d marcado.",
        noIlluminationFlares = "No quedan bengalas de iluminación. Aterriza en una base aérea amiga para rearmarte.",
        illuminationNotReady = "Iluminación no lista. Espera %d segundos.",
        cannotDeterminePosition = "No se puede determinar la posición para lanzar bengala de iluminación.",
        cannotDetermineAltitude = "No se puede determinar la altitud para lanzar bengala de iluminación.",
        illuminationDropped = "Bengala de iluminación lanzada en tu posición. (%d restantes)",
        cannotDetermineTargetPosition = "No se puede determinar la posición del objetivo para lanzar bengala de iluminación.",
        errorCouldNotDeterminePosition = "Error: No se pudo determinar tu posición.",
        illuminationDroppedOnTarget = "Bengala de iluminación lanzada en Objetivo %d (%.0f°, %.1f%s). (%d restantes)",
        illuminationRearmed = "Bengalas de iluminación rearmadas: %d disponibles.",
        noGroundTargets = "No se detectaron objetivos terrestres enemigos en rango.",
        selectTargetFromMenu = "Selecciona un objetivo del menú para marcarlo.",
        targetInfo = "Objetivo %d: %s %s %s, Rumbo %.0f, Rango %.1f %s",
        enabled = "activado",
        disabled = "desactivado",
        hot = "caliente",
        cold = "frío",
        closing = "acercándose",
        opening = "alejándose",
        left = "izquierda",
        right = "derecha",
        above = "arriba",
        below = "abajo",
        high = "alto",
        low = "bajo",
        normal = "normal",
        quiet = "silencioso",
        verbose = "detallado",
        menu = {
            mainTitle = "Intuición del Piloto WWII",
            dogfightAssist = "Asistencia Combate Aéreo",
            enable = "Activar",
            disable = "Desactivar",
            markerType = "Tipo de Marcador",
            smoke = "Humo",
            flare = "Bengala",
            red = "Rojo",
            green = "Verde",
            blue = "Azul",
            white = "Blanco",
            none = "Ninguno",
            airScanning = "Escaneo Aéreo",
            groundScanning = "Escaneo Terrestre",
            groundTargeting = "Objetivo Terrestre",
            scanForTargets = "Escanear Objetivos",
            markTarget = "Marcar Objetivo",
            target = "Objetivo %d",
            illumination = "Iluminación (%d restantes)",
            dropAtMyPosition = "Lanzar en Mi Posición",
            dropOnTarget = "Lanzar en Objetivo",
            alertFrequency = "Frecuencia de Alerta",
            normalFreq = "Normal",
            quietFreq = "Silencioso",
            verboseFreq = "Detallado",
            summary = "Resumen",
            brief = "Breve",
            detailed = "Detallado",
            settingsAndGuides = "Configuración y Guías",
            distanceUnits = "Unidades de Distancia",
            milesNautical = "Millas (Náuticas)",
            kilometers = "Kilómetros",
            playerGuide = "Guía del Jugador",
            systemOverview = "Resumen del Sistema",
            detectionRanges = "Rangos de Detección",
            dogfightAssistHelp = "Ayuda Combate Aéreo",
            groundTargetingHelp = "Ayuda Objetivo Terrestre",
            formationTips = "Consejos de Formación",
            illuminationHelp = "Ayuda de Iluminación",
            logLevel = "Nivel de Registro",
            language = "Language / Sprache / Langue",
            english = "English (Inglés)",
            german = "Deutsch (Alemán)",
            french = "Français (Francés)",
            spanish = "Español (Spanish)",
            russian = "Русский (Ruso)",
        }
    },
    -- Russian language
    RU = {
        welcome = {
            "Добро пожаловать в WWII Интуиция Пилота! Эта система имитирует разведку пилота для обнаружения воздушных и наземных целей. Используйте меню F10 для настроек.",
            "Приветствую, пилот! WWII Интуиция Пилота активна. Она поможет вам обнаружить бандитов и наземные угрозы. Проверьте F10 для опций.",
            "Интуиция пилота активирована! Имитируйте разведку эпохи WWII. Меню F10 для управления.",
        },
        formationJoin = {
            "Вы присоединились к полету с %s - обнаружение воздушных целей увеличено до %.0f%s, наземных до %.0f%s.",
            "%s теперь летит на вашем крыле - дальности обнаружения увеличены до %.0f%s воздух, %.0f%s земля.",
            "Добро пожаловать на борт, %s! Формация улучшает обнаружение до %.0f%s для воздуха, %.0f%s для земли.",
            "%s присоединяется к формации - глаза острее теперь, %.0f%s воздух, %.0f%s земля дальность.",
        },
        formationLeave = {
            "%s покинул формацию - обнаружение воздушных целей снижено до %.0f%s, наземных до %.0f%s.",
            "%s ушел - обнаружение падает до %.0f%s воздух, %.0f%s земля.",
            "Формация разорвана %s - дальности теперь %.0f%s воздух, %.0f%s земля.",
            "%s отделился - обратно к одиночному обнаружению: %.0f%s воздух, %.0f%s земля.",
        },
        formationIntegrityLow = {
            "Целостность формации низкая! Сжаться.",
            "Стройтесь, пилоты! Мы слишком разбросаны.",
            "Сомкните ряды! Целостность формации под угрозой.",
            "Вернитесь в формацию, ребята! Мы уязвимы.",
        },
        airTargetDetected = {
            "Бандит %s на %.0f градусов, %.1f %s, ангелы %.0f (%s)!",
            "Вражеский самолет %s: %.0f градусов, %.1f %s, высота %.0f (%s).",
            "Боги %s на %.0f часов, %.1f %s, ангелы %.0f (%s).",
            "Враждебный контакт %s: %.0f градусов, %.1f %s, %.0f ангелов (%s).",
            "Бандит входящий %s: %.0f градусов, %.1f %s, ангелы %.0f (%s).",
        },
        groundTargetDetected = {
            "%s контакт: %s %s на %.0f градусов, %.1f %s.",
            "Наземная угроза: %s %s %s замечен на %.0f градусов, %.1f %s.",
            "%s единицы обнаружены: %s %s, %.0f градусов, %.1f %s.",
            "Вражеская земля: %s %s %s на пеленге %.0f, %.1f %s расстояние.",
        },
        dogfightEngaged = {
            "Вступил!",
            "Талли хо! Воздушный бой начат.",
            "Бандит вступил! Бой идет.",
            "Воздушный бой! Оружие горячо.",
        },
        dogfightConcluded = {
            "Воздушный бой завершен.",
            "Бой окончен. Чисто.",
            "Воздушный бой закончен. Отбой.",
            "Вступление завершено.",
        },
        underFire = {
            "Под огнем! Разрывай %s!%s",
            "Получаем попадания! Уклоняйся %s!%s",
            "Выстрелы! Поверни %s сейчас!%s",
            "Входящий! Разрывай %s!%s",
        },
        closeFlyingCompliment = {
            "Отличный полет! Формация концом к концу.",
            "Эй, хорошо! Это тесный полет.",
            "Отличная работа! Как близко!",
            "Полегче там, тигр, я тебя так хорошо не знаю!",
            "Впечатляюще! Законцовка к законцовке.",
            "Плавные движения! Полет в тесных четвертях.",
            "Черт, как тесно! Хороший полет.",
            "Святые небеса, как близко! Отлично.",
            "Уф, это было близко! Хорошая работа ручкой.",
            "Ты приклеен к моему крылу! Отличный полет.",
        },
        headOnWarning = {
            "Уф! Это было близко!",
            "Воу! Почти лобовое!",
            "Близкий вызов! Осторожнее с этим проходом.",
            "Черт, это было тесно! Будь осторожен.",
            "Святые небеса, почти столкнулись!",
        },
        markerSet = {
            "Маркер установлен на %s.",
            "Маркеры теперь %s.",
            "Тип маркера изменен на %s.",
        },
        dogfightAssistToggle = {
            "Помощь в воздушном бою %s.",
            "Ассистенс воздушного боя %s.",
        },
        activeMessagingToggle = {
            "Активные сообщения %s.",
            "Живые оповещения %s.",
        },
        airScanningToggle = {
            "Воздушное сканирование %s.",
            "Воздушное обнаружение %s.",
        },
        groundScanningToggle = {
            "Наземное сканирование %s.",
            "Наземное обнаружение %s.",
        },
        alertFrequencyToggle = {
            "Частота оповещений установлена на %s.",
            "Оповещения теперь %s.",
        },
        summaryCooldown = {
            "Резюме на перезарядке.",
            "Подожди немного для другого резюме.",
        },
        noThreats = {
            "Нет активных угроз.",
            "Все чисто.",
            "Ситуация нормальная.",
        },
        systemActive = "WWII Интуиция Пилота активна! Используйте меню F10 для настроек.",
        logLevelSet = "Уровень логирования установлен на: %s",
        distanceUnitsSet = "Единицы расстояния установлены на %s.",
        targetNotAvailable = "Цель %d недоступна.",
        markedTarget = "Цель %d отмечена.",
        noIlluminationFlares = "Осветительные ракеты закончились. Приземлитесь на дружественную авиабазу для перевооружения.",
        illuminationNotReady = "Освещение не готово. Подождите %d секунд.",
        cannotDeterminePosition = "Невозможно определить позицию для сброса осветительной ракеты.",
        cannotDetermineAltitude = "Невозможно определить высоту для сброса осветительной ракеты.",
        illuminationDropped = "Осветительная ракета сброшена на вашей позиции. (%d осталось)",
        cannotDetermineTargetPosition = "Невозможно определить позицию цели для сброса осветительной ракеты.",
        errorCouldNotDeterminePosition = "Ошибка: Не удалось определить вашу позицию.",
        illuminationDroppedOnTarget = "Осветительная ракета сброшена на Цель %d (%.0f°, %.1f%s). (%d осталось)",
        illuminationRearmed = "Осветительные ракеты перезаряжены: %d доступно.",
        noGroundTargets = "Вражеские наземные цели в радиусе не обнаружены.",
        selectTargetFromMenu = "Выберите цель из меню, чтобы отметить её.",
        targetInfo = "Цель %d: %s %s %s, Пеленг %.0f, Дальность %.1f %s",
        enabled = "включено",
        disabled = "отключено",
        hot = "горячий",
        cold = "холодный",
        closing = "сближение",
        opening = "расхождение",
        left = "слева",
        right = "справа",
        above = "сверху",
        below = "снизу",
        high = "высокий",
        low = "низкий",
        normal = "нормальный",
        quiet = "тихий",
        verbose = "подробный",
        menu = {
            mainTitle = "Интуиция Пилота WWII",
            dogfightAssist = "Помощь Воздушный Бой",
            enable = "Включить",
            disable = "Отключить",
            markerType = "Тип Маркера",
            smoke = "Дым",
            flare = "Ракета",
            red = "Красный",
            green = "Зеленый",
            blue = "Синий",
            white = "Белый",
            none = "Нет",
            airScanning = "Воздушное Сканирование",
            groundScanning = "Наземное Сканирование",
            groundTargeting = "Наземное Наведение",
            scanForTargets = "Сканировать Цели",
            markTarget = "Отметить Цель",
            target = "Цель %d",
            illumination = "Освещение (%d осталось)",
            dropAtMyPosition = "Сбросить на Моей Позиции",
            dropOnTarget = "Сбросить на Цель",
            alertFrequency = "Частота Оповещений",
            normalFreq = "Нормальная",
            quietFreq = "Тихая",
            verboseFreq = "Подробная",
            summary = "Резюме",
            brief = "Краткое",
            detailed = "Подробное",
            settingsAndGuides = "Настройки и Руководства",
            distanceUnits = "Единицы Расстояния",
            milesNautical = "Мили (Морские)",
            kilometers = "Километры",
            playerGuide = "Руководство Игрока",
            systemOverview = "Обзор Системы",
            detectionRanges = "Дальности Обнаружения",
            dogfightAssistHelp = "Помощь Воздушный Бой",
            groundTargetingHelp = "Помощь Наземное Наведение",
            formationTips = "Советы по Формации",
            illuminationHelp = "Помощь Освещение",
            logLevel = "Уровень Логирования",
            language = "Language / Sprache / Langue",
            english = "English (Английский)",
            german = "Deutsch (Немецкий)",
            french = "Français (Французский)",
            spanish = "Español (Испанский)",
            russian = "Русский (Russian)",
        }
    }
}

-- Backward compatibility: keep old reference for any direct usage
PILOT_INTUITION_MESSAGES = PILOT_INTUITION_LANGUAGES.EN

-- Pilot Intuition Class
PilotIntuition = {
    ClassName = "PilotIntuition",
    players = {},  -- Table to track per-player data
    trackedGroundTargets = {},  -- Global table to track ground targets
    lastMessageTime = 0,
    menu = nil,
    enabled = true,
    summaryScheduler = nil,
    lastDeepCleanup = 0,  -- For periodic deep cleanup
    playerMenus = {},  -- Track created player menus to avoid duplicates
}

-- Helper function to format distance based on player preference
function PilotIntuition:FormatDistance(distanceMeters, playerKey)
    local distanceUnit = PILOT_INTUITION_CONFIG.distanceUnit
    
    -- Check for player-specific preference
    if playerKey and self.players[playerKey] and self.players[playerKey].distanceUnit then
        distanceUnit = self.players[playerKey].distanceUnit
    end
    
    if distanceUnit == "mi" then
        -- Convert to nautical miles (1 nautical mile = 1852 meters)
        local distanceNM = distanceMeters / 1852
        return distanceNM, "mi"
    else
        -- Default to kilometers
        local distanceKM = distanceMeters / 1000
        return distanceKM, "km"
    end
end

-- Helper function to get player's language
function PilotIntuition:GetPlayerLanguage(playerKey)
    if playerKey and self.players[playerKey] and self.players[playerKey].language then
        return self.players[playerKey].language
    end
    return PILOT_INTUITION_CONFIG.defaultLanguage
end

-- Helper function to get translated text (non-array messages)
function PilotIntuition:GetText(textKey, playerKey)
    local lang = self:GetPlayerLanguage(playerKey)
    local langTable = PILOT_INTUITION_LANGUAGES[lang] or PILOT_INTUITION_LANGUAGES.EN
    
    -- Check if it's a nested key (e.g., "menu.mainTitle")
    if string.find(textKey, "%.") then
        local parts = {}
        for part in string.gmatch(textKey, "[^%.]+") do
            table.insert(parts, part)
        end
        
        local value = langTable
        for _, part in ipairs(parts) do
            if value and type(value) == "table" then
                value = value[part]
            else
                return textKey  -- Fallback to key if not found
            end
        end
        return value or textKey
    end
    
    return langTable[textKey] or textKey
end

-- Get random message with player language support
function PilotIntuition:GetRandomMessage(messageType, params, playerKey)
    local lang = self:GetPlayerLanguage(playerKey)
    local langTable = PILOT_INTUITION_LANGUAGES[lang] or PILOT_INTUITION_LANGUAGES.EN
    local messages = langTable[messageType]
    
    if not messages then
        env.info("PilotIntuition: No messages for type " .. tostring(messageType) .. " in language " .. lang)
        return "Message type not found: " .. tostring(messageType)
    end
    
    -- Handle both array messages and single string messages
    local msg
    if type(messages) == "table" and #messages > 0 then
        msg = messages[math.random(#messages)]
    elseif type(messages) == "string" then
        msg = messages
    else
        return "Invalid message format for: " .. tostring(messageType)
    end
    
    env.info("PilotIntuition: Selected message: " .. msg)
    if params then
        msg = string.format(msg, unpack(params))
        env.info("PilotIntuition: Formatted message: " .. msg)
    end
    return msg
end

function PilotIntuition:New()
    PILog(LOG_INFO, "PilotIntuition: System starting")
    local self = BASE:Inherit(self, BASE:New())
    self.players = {}
    self.trackedGroundTargets = {}
    self.lastMessageTime = timer.getTime()
    self.playerMenus = {}  -- Clear cached menus on initialization
    self:SetupMenu()
    self:WireEventHandlers()
    self:StartScheduler()
    PILog(LOG_INFO, "PilotIntuition: System initialized")
    return self
end

-- Helper function to get current unit for a clientName
function PilotIntuition:GetUnitForClient(clientName)
    if not clientName then 
        env.info("PilotIntuition: GetUnitForClient - no clientName provided")
        return nil 
    end
    
    env.info("PilotIntuition: GetUnitForClient looking for: " .. tostring(clientName))
    
    -- Try _DATABASE.CLIENTS first
    if _DATABASE and _DATABASE.CLIENTS and _DATABASE.CLIENTS[clientName] then
        local unitName = _DATABASE.CLIENTS[clientName].UnitName
        env.info("PilotIntuition: Found in _DATABASE.CLIENTS, unitName: " .. tostring(unitName))
        if unitName then
            local unit = UNIT:FindByName(unitName)
            if unit then
                env.info("PilotIntuition: UNIT:FindByName succeeded, IsAlive: " .. tostring(unit:IsAlive()))
                if unit:IsAlive() then
                    return unit
                end
            else
                env.info("PilotIntuition: UNIT:FindByName returned nil")
            end
        end
    else
        env.info("PilotIntuition: clientName not found in _DATABASE.CLIENTS")
    end
    
    return nil
end

-- Helper function to get player data key from a unit (handles aliasing)
function PilotIntuition:GetPlayerDataKey(playerUnit)
    if not playerUnit then return nil end
    
    local unitName = playerUnit:GetName()
    local playerName = playerUnit:GetPlayerName()
    
    -- Try unit name first (clientName from _DATABASE.CLIENTS)
    if self.players[unitName] then
        return unitName
    end
    
    -- Try player name second (may be aliased to unit name)
    if playerName and self.players[playerName] then
        return playerName
    end
    
    -- Try to find player data by searching _DATABASE.CLIENTS for matching unit
    if _DATABASE and _DATABASE.CLIENTS then
        for clientName, clientData in pairs(_DATABASE.CLIENTS) do
            if clientData and clientData.UnitName == unitName then
                if self.players[clientName] then
                    return clientName
                end
            end
        end
    end
    
    return nil
end

-- Helper function to get all active player units
function PilotIntuition:GetActivePlayers()
    local players = {}
    local count = 0
    
    -- Method 1: Try DCS coalition.getPlayers()
    for _, coalitionId in pairs({coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL}) do
        local success, coalPlayers = pcall(coalition.getPlayers, coalitionId)
        if success and coalPlayers then
            for _, playerId in pairs(coalPlayers) do
                if playerId and type(playerId) == "string" and playerId ~= "" then
                    local success2, unit = pcall(Unit.getByName, playerId)
                    if success2 and unit and unit:isExist() and unit:isActive() then
                        local unitWrapper = UNIT:Find(unit)
                        if unitWrapper then
                            local playerName = unitWrapper:GetPlayerName() or unitWrapper:GetName()
                            players[playerName] = unitWrapper
                            count = count + 1
                            env.info("PilotIntuition: Found player via coalition.getPlayers: " .. playerName)
                        end
                    end
                end
            end
        end
    end
    
    -- Method 2: Try _DATABASE.CLIENTS
    if _DATABASE and _DATABASE.CLIENTS then
        local clientCount = 0
        for clientName, clientData in pairs(_DATABASE.CLIENTS) do
            clientCount = clientCount + 1
            PILog(LOG_TRACE, "PilotIntuition: Checking _DATABASE.CLIENTS entry #" .. clientCount .. ": " .. tostring(clientName))
            if clientData then
                PILog(LOG_TRACE, "  - UnitName: " .. tostring(clientData.UnitName))
            end
            if not players[clientName] and clientData and clientData.UnitName then
                local unit = UNIT:FindByName(clientData.UnitName)
                PILog(LOG_TRACE, "  - UNIT:FindByName result: " .. tostring(unit))
                if unit then
                    PILog(LOG_TRACE, "  - Unit:IsAlive: " .. tostring(unit:IsAlive()))
                end
                if unit and unit:IsAlive() then
                    players[clientName] = unit
                    count = count + 1
                    PILog(LOG_DEBUG, "PilotIntuition: Found player via _DATABASE.CLIENTS: " .. clientName)
                end
            end
        end
        PILog(LOG_DEBUG, "PilotIntuition: _DATABASE.CLIENTS had " .. clientCount .. " total entries")
    else
        PILog(LOG_ERROR, "PilotIntuition: _DATABASE.CLIENTS not available!")
    end
    
    PILog(LOG_INFO, "PilotIntuition: GetActivePlayers found " .. count .. " players")
    return players
end

function PilotIntuition:ScanTargets()
    PILog(LOG_DEBUG, "PilotIntuition: ScanTargets called")
    if not self.enabled then
        return
    end
    local startTime = timer.getTime()  -- Profiling start

    local activePlayers = self:GetActivePlayers()
    local activeClients = {}
    local activePlayerNames = {}
    
    -- Build active client list from the players we found
    for clientName, unit in pairs(activePlayers) do
        if unit and unit:IsAlive() then
            local client = unit:GetClient()
            local pos = unit:GetCoordinate()
            local actualPlayerName = unit:GetPlayerName() or unit:GetName()
            activeClients[#activeClients + 1] = { client = client, unit = unit, name = clientName, pos = pos, coalition = unit:GetCoalition() }
            activePlayerNames[clientName] = true
            
            -- Create player data if it doesn't exist (using clientName as primary key)
            if not self.players[clientName] then
                self.players[clientName] = {
                    trackedAirTargets = {},
                    lastMessageTime = timer.getTime(),
                    lastFormationMessageTime = 3,  -- Separate cooldown for formation join/leave messages
                    lastDogfightTime = 0,  -- For multi-bandit tactical picture cooldown
                    wingmenList = {},
                    formationWarned = false,
                    lastFormationChangeTime = 0,
                    lastConclusionTime = 0,
                    trackedGroundTargets = {},
                    dogfightAssist = PILOT_INTUITION_CONFIG.dogfightAssistEnabled,
                    lastDogfightAssistTime = 0,
                    markerType = PILOT_INTUITION_CONFIG.markerType,
                    lastSpeed = 0,
                    primaryTarget = nil,
                    lastPrimaryTargetBearing = nil,
                    lastSummaryTime = 0,
                    hasBeenWelcomed = false,
                    lastComplimentTime = 0,
                    lastHeadOnWarningTime = 0,
                    enableAirScanning = PILOT_INTUITION_CONFIG.enableAirScanning,
                    enableGroundScanning = PILOT_INTUITION_CONFIG.enableGroundScanning,
                    scannedGroundTargets = {},  -- List of recently scanned ground targets for selection
                    cachedWingmen = 0,  -- Cached wingmen count
                    lastIlluminationTime = 0,  -- Cooldown tracking for illumination flares
                    illuminationFlares = PILOT_INTUITION_CONFIG.illuminationFlaresDefault,  -- Remaining illumination flares
                    lastWingmenUpdate = 0,
                    previousWingmen = 0,  -- For formation change detection
                    frequencyMultiplier = 1.0,  -- Per-player alert frequency: 1.0=normal, 2.0=quiet, 0.5=verbose
                    threateningBandits = {},  -- Reusable table for detected threats
                    lastMultipleBanditsWarningTime = 0,  -- Cooldown for "Multiple bandits in vicinity!" message
                    distanceUnit = PILOT_INTUITION_CONFIG.distanceUnit,  -- Player's distance unit preference
                    language = PILOT_INTUITION_CONFIG.defaultLanguage,  -- Player's language preference
                }
            end
            
            -- Menu creation now handled by Birth event only
        end
    end

    -- If no active players, skip the scan
    if #activeClients == 0 then
        env.info("PilotIntuition: No active players, skipping scan")
        return
    end

    -- Cache wingmen for each player (updated every scan for simplicity)
    for _, info in ipairs(activeClients) do
        local playerName = info.name
        local playerData = self.players[playerName]
        if playerData then
            playerData.cachedWingmen = 0
            
            -- Count other players in formation
            for _, otherInfo in ipairs(activeClients) do
                local u = otherInfo.unit
                if u and u:IsAlive() and u:GetCoalition() == info.unit:GetCoalition() and u:GetName() ~= info.unit:GetName() then
                    local dist = info.pos:Get2DDistance(otherInfo.pos)
                    if dist <= PILOT_INTUITION_CONFIG.formationRange then
                        playerData.cachedWingmen = playerData.cachedWingmen + 1
                    end
                end
            end
            
            -- Count AI wingmen if enabled (aircraft only, same coalition)
            if PILOT_INTUITION_CONFIG.countAIWingmen then
                PILog(LOG_INFO, "PilotIntuition: Checking AI wingmen for player " .. playerName)
                
                -- Get all friendly AIR units in formation range
                local playerCoalition = info.unit:GetCoalition()
                local allFriendlyUnits = coalition.getGroups(playerCoalition, Group.Category.AIRPLANE)
                local aiCount = 0
                
                for _, dcsGroup in ipairs(allFriendlyUnits) do
                    local mooseGroup = GROUP:Find(dcsGroup)
                    if mooseGroup and mooseGroup:IsAlive() then
                        local groupUnits = mooseGroup:GetUnits()
                        for _, aiUnit in pairs(groupUnits) do
                            if aiUnit and aiUnit:IsAlive() and aiUnit:GetName() ~= info.unit:GetName() then
                                -- Verify it's an aircraft (double-check since we filtered by category)
                                if aiUnit:IsAir() then
                                    -- Check distance first (cheaper than GetPlayerName)
                                    local aiCoord = aiUnit:GetCoordinate()
                                    if aiCoord then
                                        local dist = info.pos:Get2DDistance(aiCoord)
                                        if dist <= PILOT_INTUITION_CONFIG.formationRange then
                                            -- Now check if it's AI (not a player)
                                            local playerName = aiUnit:GetPlayerName()
                                            local isAI = not playerName or playerName == ""
                                            if isAI then
                                                -- Add AI with multiplier (can be fractional)
                                                playerData.cachedWingmen = playerData.cachedWingmen + PILOT_INTUITION_CONFIG.aiWingmenMultiplier
                                                aiCount = aiCount + 1
                                                PILog(LOG_INFO, "PilotIntuition: Added AI wingman " .. aiUnit:GetName() .. " at " .. math.floor(dist) .. "m, total: " .. playerData.cachedWingmen)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                PILog(LOG_INFO, "PilotIntuition: Total AI wingmen in formation: " .. aiCount)
            end
            
            PILog(LOG_INFO, "PilotIntuition: Final wingmen count for " .. playerName .. ": " .. playerData.cachedWingmen)
            playerData.lastWingmenUpdate = timer.getTime()
        end
    end

    -- Send welcome message to new players
    for _, info in ipairs(activeClients) do
        local playerName = info.name
        if self.players[playerName] and not self.players[playerName].hasBeenWelcomed and PILOT_INTUITION_CONFIG.showWelcomeMessage then
            MESSAGE:New(self:GetRandomMessage("welcome", nil, playerName), 10):ToClient(info.client)
            self.players[playerName].hasBeenWelcomed = true
        end
    end

    -- Clean up stale player data
    for playerName, _ in pairs(self.players) do
        if not activePlayerNames[playerName] then
            self.players[playerName] = nil
        end
    end

    -- Build enemy unit lists once per coalition for the scan
    local enemyAirByCoalition = {}
    enemyAirByCoalition[coalition.side.BLUE] = {}
    enemyAirByCoalition[coalition.side.RED] = {}
    PILog(LOG_INFO, "PilotIntuition: Building enemy air unit list from _DATABASE.UNITS...")
    local enemyCount = 0
    
    -- Iterate directly through Moose's already-populated database
    for unitName, unitObj in pairs(_DATABASE.UNITS) do
        if unitObj and unitObj:IsAlive() and unitObj:IsAir() then
            local c = unitObj:GetCoalition()
            if c == coalition.side.BLUE or c == coalition.side.RED then
                enemyAirByCoalition[c][#enemyAirByCoalition[c] + 1] = unitObj
                enemyCount = enemyCount + 1
                PILog(LOG_INFO, "PilotIntuition: Found enemy air unit: " .. unitName .. " (coalition " .. c .. ")")
            end
        end
    end
    PILog(LOG_INFO, "PilotIntuition: Total enemy air units found: " .. enemyCount)

    local enemyGroundByCoalition = {}
    enemyGroundByCoalition[coalition.side.BLUE] = {}
    enemyGroundByCoalition[coalition.side.RED] = {}
    
    -- Iterate directly through Moose's already-populated database for ground groups
    for groupName, groupObj in pairs(_DATABASE.GROUPS) do
        if groupObj and groupObj:IsAlive() and groupObj:IsGround() then
            local c = groupObj:GetCoalition()
            if c == coalition.side.BLUE or c == coalition.side.RED then
                enemyGroundByCoalition[c][#enemyGroundByCoalition[c] + 1] = groupObj
            end
        end
    end

    -- Now scan per active client
    for _, info in ipairs(activeClients) do
        local client = info.client
        local unit = info.unit
        local playerName = info.name
        local playerData = self.players[playerName]
        if playerData and unit and unit:IsAlive() then
            -- Determine enemy lists for this player
            local playerCoal = unit:GetCoalition()
            local enemyCoal = (playerCoal == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
            PILog(LOG_INFO, "PilotIntuition: Player " .. playerName .. " coalition: " .. playerCoal .. ", enemy coalition: " .. enemyCoal)
            PILog(LOG_INFO, "PilotIntuition: Air scanning enabled: " .. tostring(playerData.enableAirScanning))
            PILog(LOG_INFO, "PilotIntuition: Enemy air units for this player: " .. #(enemyAirByCoalition[enemyCoal] or {}))
            if playerData.enableAirScanning then
                self:ScanAirTargetsForPlayer(unit, playerData, client, activeClients, enemyAirByCoalition[enemyCoal])
            end
            if playerData.enableGroundScanning then
                self:ScanGroundTargetsForPlayer(unit, client, activeClients, enemyGroundByCoalition[enemyCoal])
            end
            self:CheckCloseFlyingForPlayer(unit, playerData, client, activeClients)
        end
    end

    -- Prune dead ground targets globally
    for id, data in pairs(self.trackedGroundTargets) do
        if not data.group:IsAlive() then
            self.trackedGroundTargets[id] = nil
        end
    end

    -- Periodic deep cleanup every 60 seconds
    local now = timer.getTime()
    if not self.lastDeepCleanup or (now - self.lastDeepCleanup) > 60 then
        self:DeepCleanup()
        self.lastDeepCleanup = now
    end

    local endTime = timer.getTime()  -- Profiling end
    PILog(LOG_DEBUG, string.format("PilotIntuition: ScanTargets completed in %.3f seconds", endTime - startTime))
end

function PilotIntuition:DeepCleanup()
    env.info("PilotIntuition: Performing deep cleanup")
    -- Force remove any stale tracked targets
    for playerName, playerData in pairs(self.players) do
        for id, data in pairs(playerData.trackedAirTargets) do
            if not data.unit or not data.unit:IsAlive() then
                playerData.trackedAirTargets[id] = nil
            end
        end
        for id, _ in pairs(playerData.trackedGroundTargets) do
            if not self.trackedGroundTargets[id] or not self.trackedGroundTargets[id].group:IsAlive() then
                playerData.trackedGroundTargets[id] = nil
            end
        end
    end
    -- Clean global ground targets
    for id, data in pairs(self.trackedGroundTargets) do
        if not data.group:IsAlive() then
            self.trackedGroundTargets[id] = nil
        end
    end
    env.info("PilotIntuition: Deep cleanup completed")
end

-- Setup the mission and per-player menus for pilot intuition toggles
function PilotIntuition:SetupMenu()
    PILog(LOG_INFO, "PilotIntuition: SetupMenu called - creating menus for existing players")
    
    -- Create menus for any players already in the mission (e.g., mission editor start)
    SCHEDULER:New(nil, function()
        local activePlayers = self:GetActivePlayers()
        for clientName, unit in pairs(activePlayers) do
            if unit and unit:IsAlive() then
                local group = unit:GetGroup()
                if group then
                    local groupName = group:GetName()
                    if not self.playerMenus[groupName] then
                        PILog(LOG_INFO, "PilotIntuition: Creating menu for existing player group: " .. groupName)
                        self.playerMenus[groupName] = self:BuildGroupMenus(group)
                        MESSAGE:New(self:GetText("systemActive", group:GetUnit(1):GetPlayerName()), 10):ToGroup(group)
                    end
                end
            end
        end
    end, {}, 2)  -- Wait 2 seconds for mission to fully load
end

-- BuildGroupMenus: Creates full menu tree for a player group (CTLD-style)
function PilotIntuition:BuildGroupMenus(group)
    PILog(LOG_INFO, "PilotIntuition: BuildGroupMenus called for group: " .. group:GetName())
    
    -- Verify group is valid and has units
    if not group or not group:IsAlive() then
        PILog(LOG_ERROR, "PilotIntuition: Cannot create menu - group is nil or not alive")
        return nil
    end
    
    -- Get first unit in group for callbacks and language
    local unit = group:GetUnit(1)
    if not unit then
        PILog(LOG_ERROR, "PilotIntuition: WARNING - No unit found in group")
        return nil
    end
    
    local playerKey = self:GetPlayerDataKey(unit)
    
    -- Create the main menu for this group with translated text
    local playerSubMenu = MENU_GROUP:New(group, self:GetText("menu.mainTitle", playerKey))
    PILog(LOG_INFO, "PilotIntuition: Main menu created for group: " .. group:GetName())
    
    -- Dogfight Assist submenu
    local dogfightMenu = MENU_GROUP:New(group, self:GetText("menu.dogfightAssist", playerKey), playerSubMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.enable", playerKey), dogfightMenu, function() self:MenuSetPlayerDogfightAssist(unit, true) end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.disable", playerKey), dogfightMenu, function() self:MenuSetPlayerDogfightAssist(unit, false) end)
    
    -- Marker Type submenu
    local markerMenu = MENU_GROUP:New(group, self:GetText("menu.markerType", playerKey), playerSubMenu)
    local smokeMenu = MENU_GROUP:New(group, self:GetText("menu.smoke", playerKey), markerMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.red", playerKey), smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_red") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.green", playerKey), smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_green") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.blue", playerKey), smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_blue") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.white", playerKey), smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_white") end)
    local flareMenu = MENU_GROUP:New(group, self:GetText("menu.flare", playerKey), markerMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.red", playerKey), flareMenu, function() self:MenuSetPlayerMarker(unit, "flare_red") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.green", playerKey), flareMenu, function() self:MenuSetPlayerMarker(unit, "flare_green") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.white", playerKey), flareMenu, function() self:MenuSetPlayerMarker(unit, "flare_white") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.none", playerKey), markerMenu, function() self:MenuSetPlayerMarker(unit, "none") end)
    
    -- Air scanning submenu
    local airScanMenu = MENU_GROUP:New(group, self:GetText("menu.airScanning", playerKey), playerSubMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.enable", playerKey), airScanMenu, function() self:MenuSetPlayerAirScanning(unit, true) end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.disable", playerKey), airScanMenu, function() self:MenuSetPlayerAirScanning(unit, false) end)
    
    -- Ground scanning submenu
    local groundScanMenu = MENU_GROUP:New(group, self:GetText("menu.groundScanning", playerKey), playerSubMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.enable", playerKey), groundScanMenu, function() self:MenuSetPlayerGroundScanning(unit, true) end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.disable", playerKey), groundScanMenu, function() self:MenuSetPlayerGroundScanning(unit, false) end)
    
    -- Ground targeting submenu
    local groundMenu = MENU_GROUP:New(group, self:GetText("menu.groundTargeting", playerKey), playerSubMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.scanForTargets", playerKey), groundMenu, function() self:MenuScanGroundTargets(unit) end)
    local markMenu = MENU_GROUP:New(group, self:GetText("menu.markTarget", playerKey), groundMenu)
    for i=1,5 do
        local captureIndex = i
        local targetLabel = string.format(self:GetText("menu.target", playerKey), i)
        MENU_GROUP_COMMAND:New(group, targetLabel, markMenu, function() self:MenuMarkGroundTarget(unit, captureIndex) end)
    end
    
    -- Illumination submenu with dynamic count display
    local playerName = unit:GetPlayerName() or unit:GetName()
    local flareCount = (self.players[playerName] and self.players[playerName].illuminationFlares) or PILOT_INTUITION_CONFIG.illuminationFlaresDefault
    local illuLabel = string.format(self:GetText("menu.illumination", playerKey), flareCount)
    local illuMenu = MENU_GROUP:New(group, illuLabel, playerSubMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.dropAtMyPosition", playerKey), illuMenu, function() self:MenuDropIlluminationAtPlayer(unit) end)
    local illuTargetMenu = MENU_GROUP:New(group, self:GetText("menu.dropOnTarget", playerKey), illuMenu)
    for i=1,5 do
        local captureIndex = i
        local targetLabel = string.format(self:GetText("menu.target", playerKey), i)
        MENU_GROUP_COMMAND:New(group, targetLabel, illuTargetMenu, function() self:MenuDropIlluminationOnTarget(unit, captureIndex) end)
    end
    
    -- Alert frequency submenu
    local freqMenu = MENU_GROUP:New(group, self:GetText("menu.alertFrequency", playerKey), playerSubMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.normalFreq", playerKey), freqMenu, function() self:MenuSetPlayerAlertFrequency(unit, "normal") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.quietFreq", playerKey), freqMenu, function() self:MenuSetPlayerAlertFrequency(unit, "quiet") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.verboseFreq", playerKey), freqMenu, function() self:MenuSetPlayerAlertFrequency(unit, "verbose") end)
    
    -- Summary submenu
    local summaryMenu = MENU_GROUP:New(group, self:GetText("menu.summary", playerKey), playerSubMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.brief", playerKey), summaryMenu, function() self:MenuSendPlayerSummary(unit, "brief") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.detailed", playerKey), summaryMenu, function() self:MenuSendPlayerSummary(unit, "detailed") end)
    
    -- Admin Settings submenu (placed last)
    local adminMenu = MENU_GROUP:New(group, self:GetText("menu.settingsAndGuides", playerKey), playerSubMenu)
    
    -- Language selection submenu (under admin) - Keep multilingual for accessibility
    local langMenu = MENU_GROUP:New(group, "Language / Sprache / Langue", adminMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.english", playerKey), langMenu, function() self:MenuSetPlayerLanguage(unit, "EN") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.german", playerKey), langMenu, function() self:MenuSetPlayerLanguage(unit, "DE") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.french", playerKey), langMenu, function() self:MenuSetPlayerLanguage(unit, "FR") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.spanish", playerKey), langMenu, function() self:MenuSetPlayerLanguage(unit, "ES") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.russian", playerKey), langMenu, function() self:MenuSetPlayerLanguage(unit, "RU") end)
    
    -- Distance units submenu (under admin)
    local distMenu = MENU_GROUP:New(group, self:GetText("menu.distanceUnits", playerKey), adminMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.milesNautical", playerKey), distMenu, function() self:MenuSetPlayerDistanceUnit(unit, "mi") end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.kilometers", playerKey), distMenu, function() self:MenuSetPlayerDistanceUnit(unit, "km") end)
    
    -- Player Guide submenu
    local guideMenu = MENU_GROUP:New(group, self:GetText("menu.playerGuide", playerKey), adminMenu)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.systemOverview", playerKey), guideMenu, function() self:ShowGuideOverview(group) end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.detectionRanges", playerKey), guideMenu, function() self:ShowGuideRanges(group) end)
    MENU_GROUP_COMMAND:New(group, self:GetText("menu.formationTips", playerKey), guideMenu, function() self:ShowGuideFormation(group) end)
    MENU_GROUP_COMMAND:New(group, "Environment Effects", guideMenu, function() self:ShowGuideEnvironment(group) end)
    
    -- Log level submenu (global setting)
    local logMenu = MENU_GROUP:New(group, self:GetText("menu.logLevel", playerKey), adminMenu)
    MENU_GROUP_COMMAND:New(group, "Error Only", logMenu, function() self:SetLogLevel(1, group) end)
    MENU_GROUP_COMMAND:New(group, "Info (Default)", logMenu, function() self:SetLogLevel(2, group) end)
    MENU_GROUP_COMMAND:New(group, "Debug", logMenu, function() self:SetLogLevel(3, group) end)
    MENU_GROUP_COMMAND:New(group, "Trace (Verbose)", logMenu, function() self:SetLogLevel(4, group) end)
    
    PILog(LOG_INFO, "PilotIntuition: Menu created successfully for group " .. group:GetName())
    return playerSubMenu
end

-- Rebuild menu for a player group (used when illumination flare count changes)
function PilotIntuition:RebuildPlayerMenu(unit)
    if not unit or not unit:IsAlive() then
        PILog(LOG_ERROR, "PilotIntuition: RebuildPlayerMenu - invalid unit")
        return
    end
    
    local group = unit:GetGroup()
    if not group then
        PILog(LOG_ERROR, "PilotIntuition: RebuildPlayerMenu - no group found")
        return
    end
    
    local groupName = group:GetName()
    PILog(LOG_DEBUG, "PilotIntuition: Rebuilding menu for group: " .. groupName)
    
    -- Remove old menu if it exists
    if self.playerMenus[groupName] then
        local oldMenu = self.playerMenus[groupName]
        if oldMenu and oldMenu.Remove then
            oldMenu:Remove()
            PILog(LOG_DEBUG, "PilotIntuition: Removed old menu for group: " .. groupName)
        end
        self.playerMenus[groupName] = nil
    end
    
    -- Build new menu
    self.playerMenus[groupName] = self:BuildGroupMenus(group)
    PILog(LOG_INFO, "PilotIntuition: Menu rebuilt successfully for group: " .. groupName)
end

function PilotIntuition:SetLogLevel(level, group)
    PILOT_INTUITION_LOG_LEVEL = level
    local labels = {"None", "Error", "Info", "Debug", "Trace"}
    MESSAGE:New("Log level set to: " .. (labels[level + 1] or "Unknown"), 5):ToGroup(group)
    PILog(LOG_INFO, "PilotIntuition: Log level changed to " .. level)
end

-- Player Guide functions
function PilotIntuition:ShowGuideOverview(group)
    local msg = "WWII PILOT INTUITION - SYSTEM OVERVIEW\n\n"
    msg = msg .. "This system simulates WWII-era pilot awareness without modern radar or labels.\n\n"
    msg = msg .. "KEY FEATURES:\n"
    msg = msg .. "• Air & Ground target detection based on visual ranges\n"
    msg = msg .. "• Formation flying SIGNIFICANTLY boosts detection ranges\n"
    msg = msg .. "• Dogfight assistance (merge warnings, tail alerts, energy state)\n"
    msg = msg .. "• Optional smoke/flare markers for spotted targets\n"
    msg = msg .. "• Environmental effects (night, weather reduce ranges)\n\n"
    msg = msg .. "Use F10 menu to customize settings per pilot.\n"
    msg = msg .. "Check other guide sections for detailed mechanics."
    MESSAGE:New(msg, 20):ToGroup(group)
end

function PilotIntuition:ShowGuideRanges(group)
    local airRange = PILOT_INTUITION_CONFIG.airDetectionRange
    local groundRange = PILOT_INTUITION_CONFIG.groundDetectionRange
    local maxMult = PILOT_INTUITION_CONFIG.maxMultiplier
    local formRange = PILOT_INTUITION_CONFIG.formationRange
    
    local msg = "DETECTION RANGES\n\n"
    msg = msg .. "BASE RANGES (Solo Flight):\n"
    msg = msg .. "• Air Targets: " .. airRange .. "m (~" .. math.floor(airRange / 1852 * 10) / 10 .. "nm)\n"
    msg = msg .. "• Ground Targets: " .. groundRange .. "m (~" .. math.floor(groundRange / 1852 * 10) / 10 .. "nm)\n\n"
    msg = msg .. "FORMATION MULTIPLIERS:\n"
    msg = msg .. "Solo: 1.0x (base range)\n"
    msg = msg .. "2-ship: 2.0x (double range)\n"
    msg = msg .. "3-ship: 3.0x (triple range)\n"
    msg = msg .. "4-ship: 4.0x (quadruple range)\n"
    if maxMult >= 5 then
        msg = msg .. "5-ship: 5.0x\n"
    end
    if maxMult >= 6 then
        msg = msg .. "6+ ship: " .. maxMult .. ".0x (maximum)\n\n"
    else
        msg = msg .. maxMult .. "+ ship: " .. maxMult .. ".0x (maximum)\n\n"
    end
    msg = msg .. "EXAMPLE (Air Detection):\n"
    local solo = math.floor(airRange / 1000)
    local twoship = math.floor(airRange * 2 / 1000)
    local fourship = math.floor(airRange * math.min(4, maxMult) / 1000)
    msg = msg .. "Solo: " .. solo .. "km | 2-ship: " .. twoship .. "km | 4-ship: " .. fourship .. "km\n\n"
    msg = msg .. "Formation = wingmen within " .. formRange .. "m (~" .. math.floor(formRange / 1852 * 10) / 10 .. "nm)"
    MESSAGE:New(msg, 25):ToGroup(group)
end

function PilotIntuition:ShowGuideFormation(group)
    local formRange = PILOT_INTUITION_CONFIG.formationRange
    local maxMult = PILOT_INTUITION_CONFIG.maxMultiplier
    local minWingmen = PILOT_INTUITION_CONFIG.minFormationWingmen
    
    local msg = "FORMATION FLYING BENEFITS\n\n"
    msg = msg .. "Formation flying is CRITICAL for situational awareness!\n\n"
    msg = msg .. "FORMATION REQUIREMENTS:\n"
    msg = msg .. "• Wingmen must be within " .. formRange .. "m (~" .. math.floor(formRange / 1852 * 10) / 10 .. "nm)\n"
    msg = msg .. "• Same coalition (friendlies only)\n"
    msg = msg .. "• Aircraft must be alive and player-controlled\n"
    msg = msg .. "• Minimum wingmen for warnings: " .. minWingmen .. "\n\n"
    msg = msg .. "DETECTION BOOST:\n"
    msg = msg .. "Each additional wingman adds 1.0x to your detection range (up to " .. maxMult .. ".0x max).\n\n"
    msg = msg .. "TACTICAL ADVANTAGE:\n"
    local fourShipMult = math.min(4, maxMult)
    msg = msg .. "• 4-ship formation sees " .. fourShipMult .. "x further than solo\n"
    msg = msg .. "• Spot bandits before they spot you\n"
    msg = msg .. "• Better ground reconnaissance coverage\n"
    MESSAGE:New(msg, 25):ToGroup(group)
end

function PilotIntuition:ShowGuideEnvironment(group)
    local nightMult = PILOT_INTUITION_CONFIG.nightDetectionMultiplier
    local weatherMult = PILOT_INTUITION_CONFIG.badWeatherMultiplier
    local mergeRange = PILOT_INTUITION_CONFIG.mergeRange
    local tailRange = PILOT_INTUITION_CONFIG.tailWarningRange
    local headOnRange = PILOT_INTUITION_CONFIG.headOnRange
    local beamRange = PILOT_INTUITION_CONFIG.beamRange
    local combinedMult = nightMult * weatherMult
    
    local msg = "ENVIRONMENT EFFECTS\n\n"
    msg = msg .. "Detection ranges are affected by conditions:\n\n"
    msg = msg .. "NIGHT TIME:\n"
    msg = msg .. "• " .. (nightMult * 100) .. "% detection range\n"
    msg = msg .. "• Harder to spot targets in darkness\n"
    msg = msg .. "• Formation flying still helps!\n\n"
    msg = msg .. "BAD WEATHER:\n"
    msg = msg .. "• " .. (weatherMult * 100) .. "% detection range\n"
    msg = msg .. "• Rain, fog, clouds reduce visibility\n"
    msg = msg .. "• Stacks with night penalty\n\n"
    msg = msg .. "COMBINED EFFECTS:\n"
    msg = msg .. "Night + Bad Weather = ~" .. math.floor(combinedMult * 100) .. "% of normal range.\n\n"
    msg = msg .. "DOGFIGHT RANGES:\n"
    msg = msg .. "• Merge: " .. mergeRange .. "m\n"
    msg = msg .. "• Tail Warning: " .. tailRange .. "m\n"
    msg = msg .. "• Head-On: " .. headOnRange .. "m\n"
    msg = msg .. "• Beam: " .. beamRange .. "m\n\n"
    msg = msg .. "These ranges are NOT affected by environment - they're visual merge distances."
    MESSAGE:New(msg, 30):ToGroup(group)
end

-- WireEventHandlers: Set up Birth event handler (CTLD-style)
function PilotIntuition:WireEventHandlers()
    PILog(LOG_INFO, "PilotIntuition: Wiring event handlers using EVENTHANDLER")
    
    local handler = EVENTHANDLER:New()
    handler:HandleEvent(EVENTS.Birth)
    handler:HandleEvent(EVENTS.PlayerEnterUnit)
    handler:HandleEvent(EVENTS.Shot)
    handler:HandleEvent(EVENTS.Land)
    
    local selfref = self
    
    function handler:OnEventBirth(EventData)
        if not EventData or not EventData.IniUnit then return end
        local unit = EventData.IniUnit
        if not unit or not unit:IsAlive() then return end
        
        -- Only create menus for player-controlled units
        local playerName = unit:GetPlayerName()
        if not playerName then
            PILog(LOG_TRACE, "PilotIntuition: Birth event for non-player unit, skipping menu creation")
            return
        end
        
        local group = unit:GetGroup()
        if not group then return end
        local groupName = group:GetName()
        
        -- Simple check: if menu exists for this group, skip
        if selfref.playerMenus[groupName] then 
            PILog(LOG_DEBUG, "PilotIntuition: Menu already exists for group: " .. groupName)
            return 
        end
        
        PILog(LOG_INFO, "PilotIntuition: Birth event - creating menu for player group: " .. groupName)
        selfref.playerMenus[groupName] = selfref:BuildGroupMenus(group)
        
        -- Send welcome message to group
        MESSAGE:New("WWII Pilot Intuition active! Use F10 menu for settings.", 10):ToGroup(group)
    end
    
    function handler:OnEventPlayerEnterUnit(EventData)
        if not EventData or not EventData.IniUnit then return end
        local unit = EventData.IniUnit
        if not unit or not unit:IsAlive() then return end
        
        local group = unit:GetGroup()
        if not group then return end
        local groupName = group:GetName()
        
        PILog(LOG_INFO, "PilotIntuition: PlayerEnterUnit event for group: " .. groupName)
        
        -- Add a small delay to ensure the unit is fully initialized in multiplayer
        SCHEDULER:New(nil, function()
            -- Check if menu already exists
            if not selfref.playerMenus[groupName] then
                PILog(LOG_INFO, "PilotIntuition: Creating menu for player group: " .. groupName)
                selfref.playerMenus[groupName] = selfref:BuildGroupMenus(group)
                MESSAGE:New("WWII Pilot Intuition active! Use F10 menu for settings.", 10):ToGroup(group)
            else
                PILog(LOG_DEBUG, "PilotIntuition: Menu already exists for group: " .. groupName)
            end
        end, {}, 1)
    end
    
    function handler:OnEventShot(EventData)
        selfref:OnPlayerShot(EventData)
        selfref:OnShotFired(EventData)
    end
    
    function handler:OnEventLand(EventData)
        if not EventData or not EventData.IniUnit then return end
        local unit = EventData.IniUnit
        if not unit or not unit:IsAlive() then return end
        
        -- Check if it's a player unit
        local playerName = unit:GetPlayerName()
        if not playerName then return end
        
        local playerData = selfref.players[playerName]
        if not playerData then return end
        
        -- Check if landed at a friendly airbase
        local place = EventData.Place
        if place and place:getCoalition() == unit:GetCoalition() then
            -- Rearm illumination flares
            local prevCount = playerData.illuminationFlares or 0
            playerData.illuminationFlares = PILOT_INTUITION_CONFIG.illuminationFlaresDefault
            
            local client = unit:GetClient()
            if client and prevCount < PILOT_INTUITION_CONFIG.illuminationFlaresDefault then
                MESSAGE:New(string.format(self:GetText("illuminationRearmed", clientName), PILOT_INTUITION_CONFIG.illuminationFlaresDefault), 10):ToClient(client)
            end
            
            PILog(LOG_INFO, "PilotIntuition: Player " .. playerName .. " rearmed illumination flares at friendly airbase")
        end
    end
    
    self.EventHandler = handler
    PILog(LOG_INFO, "PilotIntuition: Event handlers wired successfully")
end

function PilotIntuition:OnPlayerEnterUnit(EventData)
    env.info("PilotIntuition: OnPlayerEnterUnit event triggered")
    if EventData and EventData.IniUnit then
        local unit = EventData.IniUnit
        if unit and unit:IsAlive() then
            env.info("PilotIntuition: Player entered unit: " .. tostring(unit:GetName()))
            -- Small delay to ensure unit is fully initialized
            SCHEDULER:New(nil, function()
                self:SetupPlayerMenus()
            end, {}, 2)
        end
    end
end

function PilotIntuition:SetupPlayerMenus()
    env.info("PilotIntuition: SetupPlayerMenus called")
    
    local activePlayers = self:GetActivePlayers()
    local playersFound = 0
    
    for clientName, unit in pairs(activePlayers) do
        playersFound = playersFound + 1
        env.info("PilotIntuition: Processing player: " .. tostring(clientName))
        
        if unit and unit:IsAlive() then
            env.info("PilotIntuition: Unit is alive: " .. tostring(unit:GetName()))
            
            -- Get the actual player name for aliasing
            local actualPlayerName = unit:GetPlayerName() or unit:GetName()
            
            -- Ensure player data exists (may have been created by ScanTargets)
            if not self.players[clientName] then
                self.players[clientName] = {
                    trackedAirTargets = {},
                    lastMessageTime = timer.getTime(),
                    lastDogfightTime = 0,  -- For multi-bandit tactical picture cooldown
                    wingmenList = {},
                    formationWarned = false,
                    lastFormationChangeTime = 0,
                    lastConclusionTime = 0,
                    trackedGroundTargets = {},
                    dogfightAssist = PILOT_INTUITION_CONFIG.dogfightAssistEnabled,
                    lastDogfightAssistTime = 0,
                    markerType = PILOT_INTUITION_CONFIG.markerType,
                    lastSpeed = 0,
                    primaryTarget = nil,
                    lastPrimaryTargetBearing = nil,
                    lastSummaryTime = 0,
                    hasBeenWelcomed = false,
                    lastComplimentTime = 0,
                    lastHeadOnWarningTime = 0,
                    enableAirScanning = PILOT_INTUITION_CONFIG.enableAirScanning,
                    enableGroundScanning = PILOT_INTUITION_CONFIG.enableGroundScanning,
                    scannedGroundTargets = {},
                    cachedWingmen = 0,
                    lastWingmenUpdate = 0,
                    previousWingmen = 0,
                    frequencyMultiplier = 1.0,
                    threateningBandits = {},  -- Reusable table for detected threats
                    distanceUnit = PILOT_INTUITION_CONFIG.distanceUnit,
                    language = PILOT_INTUITION_CONFIG.defaultLanguage,
                }
            end
            
            -- Create alias for actual player name
            if actualPlayerName ~= clientName then
                env.info("PilotIntuition: Creating player alias in SetupPlayerMenus: '" .. actualPlayerName .. "' -> '" .. clientName .. "'")
                self.players[actualPlayerName] = self.players[clientName]
            end
            
            local playerGroup = unit:GetGroup()
            if not playerGroup then 
                env.info("PilotIntuition: No group found for unit " .. tostring(unit:GetName()))
            else
                -- Skip if menu already created for this player
                if self.playerMenus[clientName] then
                    env.info("PilotIntuition: Menu already exists for " .. clientName)
                else
                    env.info("PilotIntuition: Creating menu for player " .. clientName)
                    
                    -- Create the main menu for this player's group
                    local playerSubMenu = MENU_GROUP:New(playerGroup, "WWII Pilot Intuition")
                    local currentGroupName = playerGroup:GetName()
                    self.playerMenus[clientName] = {
                        menu = playerSubMenu,
                        groupName = currentGroupName
                    }
                    
                    -- Dogfight Assist submenu
                    local dogfightMenu = MENU_GROUP:New(playerGroup, "Dogfight Assist", playerSubMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Enable", dogfightMenu, function() self:MenuSetPlayerDogfightAssist(unit, true) end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Disable", dogfightMenu, function() self:MenuSetPlayerDogfightAssist(unit, false) end)
                    
                    -- Marker Type submenu
                    local markerMenu = MENU_GROUP:New(playerGroup, "Marker Type", playerSubMenu)
                    local smokeMenu = MENU_GROUP:New(playerGroup, "Smoke", markerMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Red", smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_red") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Green", smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_green") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Blue", smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_blue") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "White", smokeMenu, function() self:MenuSetPlayerMarker(unit, "smoke_white") end)
                    local flareMenu = MENU_GROUP:New(playerGroup, "Flare", markerMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Red", flareMenu, function() self:MenuSetPlayerMarker(unit, "flare_red") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Green", flareMenu, function() self:MenuSetPlayerMarker(unit, "flare_green") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "White", flareMenu, function() self:MenuSetPlayerMarker(unit, "flare_white") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "None", markerMenu, function() self:MenuSetPlayerMarker(unit, "none") end)
                    
                    -- Air scanning submenu
                    local airScanMenu = MENU_GROUP:New(playerGroup, "Air Scanning", playerSubMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Enable", airScanMenu, function() self:MenuSetPlayerAirScanning(unit, true) end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Disable", airScanMenu, function() self:MenuSetPlayerAirScanning(unit, false) end)
                    
                    -- Ground scanning submenu
                    local groundScanMenu = MENU_GROUP:New(playerGroup, "Ground Scanning", playerSubMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Enable", groundScanMenu, function() self:MenuSetPlayerGroundScanning(unit, true) end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Disable", groundScanMenu, function() self:MenuSetPlayerGroundScanning(unit, false) end)
                    
                    -- Ground targeting submenu
                    local groundMenu = MENU_GROUP:New(playerGroup, "Ground Targeting", playerSubMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Scan for Targets", groundMenu, function() self:MenuScanGroundTargets(unit) end)
                    local markMenu = MENU_GROUP:New(playerGroup, "Mark Target", groundMenu)
                    for i=1,5 do
                        MENU_GROUP_COMMAND:New(playerGroup, "Target " .. i, markMenu, function() self:MenuMarkGroundTarget(unit, i) end)
                    end
                    
                    -- Alert frequency submenu
                    local freqMenu = MENU_GROUP:New(playerGroup, "Alert Frequency", playerSubMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Normal", freqMenu, function() self:MenuSetPlayerAlertFrequency(unit, "normal") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Quiet", freqMenu, function() self:MenuSetPlayerAlertFrequency(unit, "quiet") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Verbose", freqMenu, function() self:MenuSetPlayerAlertFrequency(unit, "verbose") end)
                    
                    -- Summary submenu
                    local summaryMenu = MENU_GROUP:New(playerGroup, "Summary", playerSubMenu)
                    MENU_GROUP_COMMAND:New(playerGroup, "Brief", summaryMenu, function() self:MenuSendPlayerSummary(unit, "brief") end)
                    MENU_GROUP_COMMAND:New(playerGroup, "Detailed", summaryMenu, function() self:MenuSendPlayerSummary(unit, "detailed") end)
                    
                    env.info("PilotIntuition: Menu created successfully for " .. clientName)
                end
            end
        end
    end
    
    env.info("PilotIntuition: SetupPlayerMenus completed, processed " .. playersFound .. " players")
end

function PilotIntuition:MenuSetPlayerMarker(playerUnit, markerType)
    env.info("====== PilotIntuition: MenuSetPlayerMarker CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
        env.info("PilotIntuition: playerUnit:GetPlayerName() = " .. tostring(playerUnit:GetPlayerName()))
    end
    env.info("PilotIntuition: markerType = " .. tostring(markerType))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    -- store as player pref only - not global config
    if playerKey and self.players[playerKey] then
        self.players[playerKey].markerType = markerType
        local client = playerUnit:GetClient()
        if client then
            local niceType = markerType:gsub("_", " "):gsub("(%w)(%w*)", function(first, rest) return first:upper() .. rest:lower() end)
            MESSAGE:New(self:GetRandomMessage("markerSet", {niceType}, playerName), 10):ToClient(client)
        end
    end
end
function PilotIntuition:MenuSetMarkerType(type)
    env.info("PilotIntuition: MenuSetMarkerType called with " .. tostring(type))
    PILOT_INTUITION_CONFIG.markerType = type
    local niceType = type:gsub("_", " "):gsub("(%w)(%w*)", function(first, rest) return first:upper() .. rest:lower() end)
    local msg = self:GetRandomMessage("markerSet", {niceType})
    env.info("PilotIntuition: Marker message: " .. msg)
    self:BroadcastMessageToAll(msg)
end

function PilotIntuition:MenuSetPlayerDogfightAssist(playerUnit, onoff)
    env.info("====== PilotIntuition: MenuSetPlayerDogfightAssist CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    env.info("PilotIntuition: onoff = " .. tostring(onoff))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    env.info("PilotIntuition: Looking for player data with key: " .. tostring(playerKey))
    env.info("PilotIntuition: Available players: " .. table.concat(self:GetPlayerKeys(), ", "))
    
    if playerKey and self.players[playerKey] then
        env.info("PilotIntuition: Found player data, setting dogfightAssist to " .. tostring(onoff))
        self.players[playerKey].dogfightAssist = onoff
        local status = onoff and "enabled" or "disabled"
        local client = playerUnit:GetClient()
        env.info("PilotIntuition: Getting client: " .. tostring(client))
        if client then
            env.info("PilotIntuition: Sending message to client")
            MESSAGE:New(self:GetRandomMessage("dogfightAssistToggle", {status}, playerName), 10):ToClient(client)
        else
            env.info("PilotIntuition: ERROR - Could not get client")
        end
    else
        env.info("PilotIntuition: ERROR - Player data not found for: " .. tostring(playerKey))
    end
end

function PilotIntuition:MenuSetPlayerAirScanning(playerUnit, onoff)
    env.info("====== PilotIntuition: MenuSetPlayerAirScanning CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    env.info("PilotIntuition: onoff = " .. tostring(onoff))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    if playerKey and self.players[playerKey] then
        self.players[playerKey].enableAirScanning = onoff
        local status = onoff and "enabled" or "disabled"
        local client = playerUnit:GetClient()
        if client then
            MESSAGE:New(self:GetRandomMessage("airScanningToggle", {status}, playerName), 10):ToClient(client)
        end
    end
end

function PilotIntuition:MenuSetPlayerGroundScanning(playerUnit, onoff)
    env.info("====== PilotIntuition: MenuSetPlayerGroundScanning CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    env.info("PilotIntuition: onoff = " .. tostring(onoff))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    if playerKey and self.players[playerKey] then
        self.players[playerKey].enableGroundScanning = onoff
        local status = onoff and "enabled" or "disabled"
        local client = playerUnit:GetClient()
        if client then
            MESSAGE:New(self:GetRandomMessage("groundScanningToggle", {status}, playerName), 10):ToClient(client)
        end
    end
end

function PilotIntuition:MenuSetPlayerAlertFrequency(playerUnit, mode)
    env.info("====== PilotIntuition: MenuSetPlayerAlertFrequency CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    env.info("PilotIntuition: mode = " .. tostring(mode))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    if playerKey and self.players[playerKey] then
        local multiplier
        if mode == "normal" then
            multiplier = 1.0
        elseif mode == "quiet" then
            multiplier = 2.0
        elseif mode == "verbose" then
            multiplier = 0.5
        else
            multiplier = 1.0  -- Default
        end
        self.players[playerKey].frequencyMultiplier = multiplier
        local client = playerUnit:GetClient()
        if client then
            MESSAGE:New(self:GetRandomMessage("alertFrequencyToggle", {mode}, playerName), 10):ToClient(client)
        end
    end
end

function PilotIntuition:MenuSetPlayerDistanceUnit(playerUnit, unit)
    env.info("====== PilotIntuition: MenuSetPlayerDistanceUnit CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    env.info("PilotIntuition: unit = " .. tostring(unit))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    if playerKey and self.players[playerKey] then
        self.players[playerKey].distanceUnit = unit
        local client = playerUnit:GetClient()
        if client then
            local unitName = unit == "mi" and "Miles (Nautical)" or "Kilometers"
            MESSAGE:New(string.format(self:GetText("distanceUnitsSet", playerKey), unitName), 10):ToClient(client)
        end
    end
end

function PilotIntuition:MenuSetPlayerLanguage(playerUnit, language)
    env.info("====== PilotIntuition: MenuSetPlayerLanguage CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    env.info("PilotIntuition: language = " .. tostring(language))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    if playerKey and self.players[playerKey] then
        -- Validate language
        if not PILOT_INTUITION_LANGUAGES[language] then
            env.info("PilotIntuition: Invalid language: " .. tostring(language))
            return
        end
        
        self.players[playerKey].language = language
        
        -- Rebuild the menu immediately to apply language change
        self:RebuildPlayerMenu(playerUnit)
        
        local client = playerUnit:GetClient()
        if client then
            local langNames = {
                EN = "English",
                DE = "Deutsch",
                FR = "Français",
                ES = "Español",
                RU = "Русский"
            }
            local msg = string.format("Language set to %s. Menu has been updated.", langNames[language] or language)
            MESSAGE:New(msg, 10):ToClient(client)
        end
    end
end

function PilotIntuition:MenuScanGroundTargets(playerUnit)
    env.info("====== PilotIntuition: MenuScanGroundTargets CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    if not playerUnit or not playerUnit:IsAlive() then 
        env.info("PilotIntuition: ERROR - No playerUnit provided or unit not alive")
        return 
    end
    
    local playerPos = playerUnit:GetCoordinate()
    if not playerPos then
        env.info("PilotIntuition: ERROR - Cannot get player position")
        return
    end
    
    local playerKey = self:GetPlayerDataKey(playerUnit)
    local playerData = playerKey and self.players[playerKey]
    if not playerData then 
        env.info("PilotIntuition: ERROR - No player data found for " .. tostring(playerKey))
        return 
    end
    
    local client = playerUnit:GetClient()
    if not client then 
        env.info("PilotIntuition: ERROR - No client found")
        return 
    end

    -- Collect enemy ground groups within range
    local playerCoalition = playerUnit:GetCoalition()
    local enemyCoalition = (playerCoalition == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
    local allGroups = coalition.getGroups(enemyCoalition)
    local enemyGroundGroups = {}
    for _, dcsGroup in ipairs(allGroups) do
        -- Wrap DCS group object with Moose GROUP
        local group = GROUP:Find(dcsGroup)
        if group and group:IsAlive() and (dcsGroup:getCategory() == Group.Category.GROUND or dcsGroup:getCategory() == Group.Category.SHIP) then
            local groupCoord = group:GetCoordinate()
            if groupCoord then
                local distance = playerPos:Get2DDistance(groupCoord)
                if distance <= PILOT_INTUITION_CONFIG.groundDetectionRange then
                    table.insert(enemyGroundGroups, {group = group, distance = distance})
                end
            end
        end
    end

    -- Sort by distance
    table.sort(enemyGroundGroups, function(a,b) return a.distance < b.distance end)

    -- Take top 5
    local scanned = {}
    for i=1, math.min(5, #enemyGroundGroups) do
        scanned[i] = enemyGroundGroups[i].group
    end

    -- Store in playerData
    playerData.scannedGroundTargets = scanned

    -- Send messages listing targets
    for i, group in ipairs(scanned) do
        local targetPos = group:GetCoordinate()
        local bearing = playerPos:HeadingTo(targetPos)  -- Returns heading in degrees as number
        
        -- Ensure bearing is a valid number
        if not bearing or type(bearing) ~= "number" then
            bearing = 0  -- Fallback to 0 if bearing is invalid
        end
        
        local distanceMeters = playerPos:Get2DDistance(targetPos)
        local distance, unit = self:FormatDistance(distanceMeters, playerKey)
        local unitType = group:GetUnits()[1]:GetTypeName()
        local category = self:ClassifyGroundUnit(unitType)
        local groupSize = #group:GetUnits()
        local sizeDesc = groupSize == 1 and "single" or (groupSize <= 4 and "group" or "platoon")
        MESSAGE:New(string.format("Target %d: %s %s %s, Bearing %.0f, Range %.1f %s", i, category, sizeDesc, unitType, bearing, distance, unit), 30):ToClient(client)
    end

    if #scanned == 0 then
        MESSAGE:New(self:GetText("noGroundTargets", playerName), 10):ToClient(client)
    else
        MESSAGE:New(self:GetText("selectTargetFromMenu", playerName), 10):ToClient(client)
    end
end

function PilotIntuition:MenuMarkGroundTarget(playerUnit, index)
    env.info("====== PilotIntuition: MenuMarkGroundTarget CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    env.info("PilotIntuition: index = " .. tostring(index))
    if not playerUnit then 
        env.info("PilotIntuition: ERROR - No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    local playerData = playerKey and self.players[playerKey]
    if not playerData then 
        env.info("PilotIntuition: ERROR - No player data found for " .. tostring(playerKey))
        return 
    end
    local client = playerUnit:GetClient()
    if not client then 
        env.info("PilotIntuition: ERROR - No client found")
        return 
    end

    local scanned = playerData.scannedGroundTargets or {}
    local group = scanned[index]
    if not group or not group:IsAlive() then
        MESSAGE:New("Target " .. index .. " not available.", 10):ToClient(client)
        return
    end

    -- Mark this target
    self:ReportGroundTarget(group, playerUnit, client, true)  -- placeMarker = true
    MESSAGE:New("Marked Target " .. index .. ".", 10):ToClient(client)
end

function PilotIntuition:MenuDropIlluminationAtPlayer(playerUnit)
    env.info("====== PilotIntuition: MenuDropIlluminationAtPlayer CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    if not playerUnit or not playerUnit:IsAlive() then 
        env.info("PilotIntuition: ERROR - No playerUnit or unit not alive")
        return 
    end
    
    local playerKey = self:GetPlayerDataKey(playerUnit)
    env.info("PilotIntuition: playerKey = " .. tostring(playerKey))
    
    if not playerKey or not self.players[playerKey] then
        env.info("PilotIntuition: ERROR - Player data not found for: " .. tostring(playerKey))
        return
    end
    
    local playerData = self.players[playerKey]
    local client = playerUnit:GetClient()
    if not client then 
        env.info("PilotIntuition: ERROR - Could not get client")
        return 
    end
    
    -- Check if player has flares remaining
    if (playerData.illuminationFlares or 0) <= 0 then
        MESSAGE:New("No illumination flares remaining. Land at a friendly airbase to rearm.", 10):ToClient(client)
        return
    end
    
    -- Check cooldown
    local now = timer.getTime()
    local timeSinceLast = now - (playerData.lastIlluminationTime or 0)
    if timeSinceLast < PILOT_INTUITION_CONFIG.illuminationCooldown then
        local remaining = math.ceil(PILOT_INTUITION_CONFIG.illuminationCooldown - timeSinceLast)
        MESSAGE:New("Illumination not ready. Wait " .. remaining .. " seconds.", 5):ToClient(client)
        return
    end
    
    -- Drop illumination flare at player position with altitude offset
    local playerPos = playerUnit:GetCoordinate()
    if not playerPos then
        env.info("PilotIntuition: ERROR - Could not get player coordinate")
        MESSAGE:New("Cannot determine position for illumination drop.", 5):ToClient(client)
        return
    end
    PILog(LOG_INFO, "PilotIntuition: Player position: " .. playerPos:ToStringLLDMS())
    
    -- Get altitude from unit directly (more reliable than coordinate)
    local currentAlt = playerUnit:GetAltitude()
    if not currentAlt or type(currentAlt) ~= "number" then
        env.info("PilotIntuition: ERROR - Could not get valid altitude from unit")
        MESSAGE:New("Cannot determine altitude for illumination drop.", 5):ToClient(client)
        return
    end
    PILog(LOG_INFO, "PilotIntuition: Current altitude: " .. currentAlt .. "m")
    
    -- Create new coordinate at higher altitude
    local illuAlt = currentAlt + PILOT_INTUITION_CONFIG.illuminationAltitude
    local illuPos = COORDINATE:NewFromVec3(playerPos:GetVec3())
    illuPos = illuPos:SetAltitude(illuAlt)
    PILog(LOG_INFO, "PilotIntuition: Illumination altitude: " .. illuAlt .. "m")
    
    -- Try to drop illumination bomb
    PILog(LOG_INFO, "PilotIntuition: Attempting to drop illumination bomb")
    illuPos:IlluminationBomb()
    PILog(LOG_INFO, "PilotIntuition: IlluminationBomb() called successfully")
    
    -- Decrement flare count
    playerData.illuminationFlares = playerData.illuminationFlares - 1
    playerData.lastIlluminationTime = now
    
    MESSAGE:New("Illumination flare dropped at your position. (" .. playerData.illuminationFlares .. " remaining)", 10):ToClient(client)
    PILog(LOG_INFO, "PilotIntuition: Player " .. playerKey .. " dropped illumination at own position. " .. playerData.illuminationFlares .. " flares remaining")
    
    -- Rebuild menu to update flare count display
    self:RebuildPlayerMenu(playerUnit)
end

function PilotIntuition:MenuDropIlluminationOnTarget(playerUnit, index)
    env.info("====== PilotIntuition: MenuDropIlluminationOnTarget CALLED ======")
    env.info("PilotIntuition: playerUnit = " .. tostring(playerUnit))
    env.info("PilotIntuition: index = " .. tostring(index))
    if playerUnit then
        env.info("PilotIntuition: playerUnit:GetName() = " .. tostring(playerUnit:GetName()))
    end
    if not playerUnit or not playerUnit:IsAlive() then 
        env.info("PilotIntuition: ERROR - No playerUnit or unit not alive")
        return 
    end
    
    local playerKey = self:GetPlayerDataKey(playerUnit)
    env.info("PilotIntuition: playerKey = " .. tostring(playerKey))
    
    if not playerKey or not self.players[playerKey] then
        env.info("PilotIntuition: ERROR - Player data not found for: " .. tostring(playerKey))
        return
    end
    
    local playerData = self.players[playerKey]
    local client = playerUnit:GetClient()
    if not client then 
        env.info("PilotIntuition: ERROR - Could not get client")
        return 
    end
    
    -- Check if player has flares remaining
    if (playerData.illuminationFlares or 0) <= 0 then
        MESSAGE:New("No illumination flares remaining. Land at a friendly airbase to rearm.", 10):ToClient(client)
        return
    end
    
    -- Check cooldown
    local now = timer.getTime()
    local timeSinceLast = now - (playerData.lastIlluminationTime or 0)
    if timeSinceLast < PILOT_INTUITION_CONFIG.illuminationCooldown then
        local remaining = math.ceil(PILOT_INTUITION_CONFIG.illuminationCooldown - timeSinceLast)
        MESSAGE:New("Illumination not ready. Wait " .. remaining .. " seconds.", 5):ToClient(client)
        return
    end
    
    -- Get scanned target
    local scanned = playerData.scannedGroundTargets or {}
    local group = scanned[index]
    if not group or not group:IsAlive() then
        MESSAGE:New("Target " .. index .. " not available.", 10):ToClient(client)
        return
    end
    
    -- Drop illumination flare over target with altitude offset
    local targetPos = group:GetCoordinate()
    if not targetPos then
        env.info("PilotIntuition: ERROR - Could not get target coordinate")
        MESSAGE:New("Cannot determine target position for illumination drop.", 5):ToClient(client)
        return
    end
    PILog(LOG_INFO, "PilotIntuition: Target position: " .. targetPos:ToStringLLDMS())
    
    -- Get altitude from ground level (ground units are at ground level)
    -- Use a safe default altitude for ground targets
    local targetAlt = 0
    local firstUnit = group:GetUnit(1)
    if firstUnit and firstUnit:IsAlive() then
        local unitAlt = firstUnit:GetAltitude()
        if unitAlt and type(unitAlt) == "number" then
            targetAlt = unitAlt
        end
    end
    PILog(LOG_INFO, "PilotIntuition: Target altitude: " .. targetAlt .. "m")
    
    -- Create new coordinate at higher altitude
    local illuAlt = targetAlt + PILOT_INTUITION_CONFIG.illuminationAltitude
    local illuPos = COORDINATE:NewFromVec3(targetPos:GetVec3())
    illuPos = illuPos:SetAltitude(illuAlt)
    PILog(LOG_INFO, "PilotIntuition: Illumination altitude: " .. illuAlt .. "m")
    
    -- Try to drop illumination bomb
    PILog(LOG_INFO, "PilotIntuition: Attempting to drop illumination bomb on target")
    illuPos:IlluminationBomb()
    PILog(LOG_INFO, "PilotIntuition: IlluminationBomb() called successfully")
    
    -- Decrement flare count
    playerData.illuminationFlares = playerData.illuminationFlares - 1
    playerData.lastIlluminationTime = now
    
    local playerCoord = playerUnit:GetCoordinate()
    if not playerCoord then
        PILog(LOG_ERROR, "PilotIntuition: Could not get player coordinate for illumination drop")
        MESSAGE:New("Error: Could not determine your position.", 10):ToClient(client)
        return
    end
    
    local bearing = playerCoord:GetAngleDegrees(playerCoord:GetDirectionVec3(targetPos))
    local rawDistance = playerCoord:Get2DDistance(targetPos)
    local distance, unit = self:FormatDistance(rawDistance, playerKey)
    MESSAGE:New(string.format("Illumination flare dropped on Target %d (%.0f°, %.1f%s). (%d remaining)", index, bearing, distance, unit, playerData.illuminationFlares), 10):ToClient(client)
    PILog(LOG_INFO, "PilotIntuition: Player " .. playerKey .. " dropped illumination on target " .. index .. ". " .. playerData.illuminationFlares .. " flares remaining")
    
    -- Rebuild menu to update flare count display
    self:RebuildPlayerMenu(playerUnit)
end

function PilotIntuition:MenuSetActiveMessaging(onoff)
    env.info("PilotIntuition: MenuSetActiveMessaging called with " .. tostring(onoff))
    PILOT_INTUITION_CONFIG.activeMessaging = onoff
    if onoff then
        local msg = self:GetRandomMessage("activeMessagingToggle", {"enabled"})
        env.info("PilotIntuition: Active messaging message: " .. msg)
        self:BroadcastMessageToAll(msg)
        if self.summaryScheduler then
            self.summaryScheduler:Stop()
            self.summaryScheduler = nil
        end
    else
        local msg = self:GetRandomMessage("activeMessagingToggle", {"disabled. Use summaries for updates."})
        env.info("PilotIntuition: Active messaging message: " .. msg)
        self:BroadcastMessageToAll(msg)
        if PILOT_INTUITION_CONFIG.summaryInterval > 0 then
            self.summaryScheduler = SCHEDULER:New(nil, self.SendScheduledSummaries, {self}, 1, PILOT_INTUITION_CONFIG.summaryInterval)
        end
    end
end

function PilotIntuition:MenuSetAirScanning(onoff)
    env.info("PilotIntuition: MenuSetAirScanning called with " .. tostring(onoff))
    PILOT_INTUITION_CONFIG.enableAirScanning = onoff
    local status = onoff and "enabled" or "disabled"
    local msg = self:GetRandomMessage("airScanningToggle", {status})
    env.info("PilotIntuition: Air scanning message: " .. msg)
    self:BroadcastMessageToAll(msg)
end

function PilotIntuition:MenuSetGroundScanning(onoff)
    env.info("PilotIntuition: MenuSetGroundScanning called with " .. tostring(onoff))
    PILOT_INTUITION_CONFIG.enableGroundScanning = onoff
    local status = onoff and "enabled" or "disabled"
    local msg = self:GetRandomMessage("groundScanningToggle", {status})
    env.info("PilotIntuition: Ground scanning message: " .. msg)
    self:BroadcastMessageToAll(msg)
end

function PilotIntuition:MenuSendPlayerSummary(playerUnit, detailLevel)
    self:SendPlayerSummary(playerUnit, detailLevel)
end

function PilotIntuition:BroadcastMessageToAll(text)
    env.info("PilotIntuition: Broadcasting message: " .. tostring(text))
    MESSAGE:New(text, 10):ToAll()  -- Added duration 10 seconds
    env.info("PilotIntuition: Broadcasted to all with duration 10")
end

function PilotIntuition:GetPlayerSummary(playerName, detailLevel, playerUnit)
    local data = self.players[playerName]
    if not data then return nil end
    
    -- Get player position for bearing calculations
    local playerPos = nil
    local playerHeading = 0
    if playerUnit and playerUnit:IsAlive() then
        playerPos = playerUnit:GetCoordinate()
        playerHeading = math.deg(playerUnit:GetHeading())
    end
    
    -- Collect air threats with details
    local airThreats = {}
    for id, t in pairs(data.trackedAirTargets or {}) do
        if t.unit and t.unit:IsAlive() then
            local distance = t.lastRange or 0
            local bearing = 0
            local relativeBearing = 0
            local threat = "UNKNOWN"
            
            if playerPos then
                bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(t.unit:GetCoordinate()))
                relativeBearing = (bearing - playerHeading + 360) % 360
                
                -- Determine threat level
                if distance < PILOT_INTUITION_CONFIG.threatHotRange then
                    threat = "HOT"
                elseif distance < PILOT_INTUITION_CONFIG.threatColdRange then
                    threat = "COLD"
                else
                    threat = "FAR"
                end
            end
            
            table.insert(airThreats, {
                name = t.unit:GetTypeName() or "Unknown",
                bearing = bearing,
                distance = distance,
                altitude = t.unit:GetAltitude() or 0,
                threat = threat
            })
        end
    end
    
    -- Sort air threats by distance (closest first)
    table.sort(airThreats, function(a, b) return a.distance < b.distance end)
    
    -- Collect ground threats with details
    local groundThreats = {}
    for id, _ in pairs(data.trackedGroundTargets or {}) do
        -- Look up actual ground group from global table
        local groundData = self.trackedGroundTargets[id]
        if groundData and groundData.group and groundData.group:IsAlive() then
            local g = groundData.group
            local gPos = g:GetCoordinate()
            local distance = 0
            local bearing = 0
            local category = "Ground"
            
            if playerPos and gPos then
                distance = playerPos:Get2DDistance(gPos)
                bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(gPos))
            end
            
            -- Classify ground unit
            local firstUnit = g:GetUnit(1)
            if firstUnit then
                local unitType = firstUnit:GetTypeName() or ""
                category = self:ClassifyGroundUnit(unitType)
            end
            
            table.insert(groundThreats, {
                name = g:GetName() or "Unknown",
                category = category,
                bearing = bearing,
                distance = distance
            })
        end
    end
    
    -- Sort ground threats by distance
    table.sort(groundThreats, function(a, b) return a.distance < b.distance end)
    
    -- Build summary based on detail level
    if detailLevel == "brief" then
        -- Brief: Quick tactical overview
        local parts = {}
        
        if #airThreats > 0 then
            local closest = airThreats[1]
            local distance, unit = self:FormatDistance(closest.distance, playerName)
            table.insert(parts, string.format("%d bandit%s (closest: %s @ %.1f%s %s)", 
                #airThreats, 
                #airThreats > 1 and "s" or "",
                closest.name, 
                distance, 
                unit,
                closest.threat))
        end
        
        if #groundThreats > 0 then
            table.insert(parts, string.format("%d ground group%s", #groundThreats, #groundThreats > 1 and "s" or ""))
        end
        
        -- Formation status
        local wingmen = data.cachedWingmen or 0
        if wingmen > 0 then
            local mult = (wingmen > 0) and (2 * wingmen) or 1
            if mult > PILOT_INTUITION_CONFIG.maxMultiplier then mult = PILOT_INTUITION_CONFIG.maxMultiplier end
            local envMult = self:GetDetectionMultiplier()
            local airRange, airUnit = self:FormatDistance(PILOT_INTUITION_CONFIG.airDetectionRange * mult * envMult, playerName)
            local groundRange, groundUnit = self:FormatDistance(PILOT_INTUITION_CONFIG.groundDetectionRange * mult * envMult, playerName)
            table.insert(parts, string.format("Formation: %d wingmen (detect: %.0f%s air/%.0f%s gnd)", wingmen, airRange, airUnit, groundRange, groundUnit))
        else
            table.insert(parts, "Solo (reduced detection)")
        end
        
        if #parts == 0 then
            return nil
        end
        
        return table.concat(parts, " | ")
        
    else
        -- Detailed: Full tactical situation report
        local lines = {}
        table.insert(lines, "=== TACTICAL SITREP ===")
        
        -- Air threats section
        if #airThreats > 0 then
            table.insert(lines, "\nAIR THREATS:")
            for i, threat in ipairs(airThreats) do
                local angels = math.floor(threat.altitude * 3.28084 / 1000)  -- Convert to thousands of feet
                local distance, unit = self:FormatDistance(threat.distance, playerName)
                table.insert(lines, string.format("  %d. %s @ %03d°, %.1f%s, angels %d (%s)", 
                    i, threat.name, math.floor(threat.bearing), distance, unit, angels, threat.threat))
            end
        else
            table.insert(lines, "\nAIR THREATS: None")
        end
        
        -- Ground threats section
        if #groundThreats > 0 then
            table.insert(lines, "\nGROUND THREATS:")
            for i, threat in ipairs(groundThreats) do
                local distance, unit = self:FormatDistance(threat.distance, playerName)
                table.insert(lines, string.format("  %d. %s @ %03d°, %.1f%s", 
                    i, threat.category, math.floor(threat.bearing), distance, unit))
            end
        else
            table.insert(lines, "\nGROUND THREATS: None")
        end
        
        -- Formation and detection status
        local wingmen = data.cachedWingmen or 0
        local mult = (wingmen > 0) and (2 * wingmen) or 1
        if mult > PILOT_INTUITION_CONFIG.maxMultiplier then mult = PILOT_INTUITION_CONFIG.maxMultiplier end
        local envMult = self:GetDetectionMultiplier()
        local airRange, airUnit = self:FormatDistance(PILOT_INTUITION_CONFIG.airDetectionRange * mult * envMult, playerName)
        local groundRange, groundUnit = self:FormatDistance(PILOT_INTUITION_CONFIG.groundDetectionRange * mult * envMult, playerName)
        
        table.insert(lines, "\nFORMATION:")
        if wingmen > 0 then
            table.insert(lines, string.format("  Wingmen: %d (multiplier: x%d)", wingmen, mult))
        else
            table.insert(lines, "  Status: Solo flight")
        end
        table.insert(lines, string.format("  Detection: %.0f%s air, %.0f%s ground", airRange, airUnit, groundRange, groundUnit))
        
        return table.concat(lines, "\n")
    end
end

function PilotIntuition:SendPlayerSummary(playerUnit, detailLevel)
    env.info("PilotIntuition: SendPlayerSummary called with detailLevel: " .. tostring(detailLevel))
    if not playerUnit then 
        env.info("PilotIntuition: No playerUnit provided")
        return 
    end
    local playerKey = self:GetPlayerDataKey(playerUnit)
    env.info("PilotIntuition: Player key from unit: " .. tostring(playerKey))
    local client = playerUnit:GetClient()
    if not client then
        env.info("PilotIntuition: Could not get client for player")
        return
    end
    if not playerKey or not self.players[playerKey] then 
        env.info("PilotIntuition: Player data not found for: " .. tostring(playerKey))
        env.info("PilotIntuition: Available players: " .. table.concat(self:GetPlayerKeys(), ", "))
        return 
    end
    local now = timer.getTime()
    local data = self.players[playerKey]
    if data.lastSummaryTime and (now - data.lastSummaryTime) < (PILOT_INTUITION_CONFIG.summaryCooldown or 2) then
        MESSAGE:New(self:GetRandomMessage("summaryCooldown"), 5):ToClient(client)
        return
    end
    local summary = self:GetPlayerSummary(playerKey, detailLevel, playerUnit)
    env.info("PilotIntuition: Summary generated: " .. tostring(summary))
    if summary and summary ~= "" then
        -- Use longer duration for detailed reports
        local duration = (detailLevel == "detailed") and 30 or 15
        MESSAGE:New(summary, duration):ToClient(client)
        data.lastSummaryTime = now
    else
        MESSAGE:New(self:GetRandomMessage("noThreats"), 10):ToClient(client)
    end
end

function PilotIntuition:GetPlayerKeys()
    local keys = {}
    for k, _ in pairs(self.players) do
        table.insert(keys, k)
    end
    return keys
end

function PilotIntuition:SendScheduledSummaries()
    if not PILOT_INTUITION_CONFIG.activeMessaging then
        local clients = SET_CLIENT:New():FilterActive():FilterOnce()
        clients:ForEachClient(function(client)
            if client and type(client.GetUnit) == "function" then
                local unit = client:GetUnit()
                if unit and unit:IsAlive() then
                    self:SendPlayerSummary(unit, "brief")
                end
            end
        end)
    end
end

function PilotIntuition:StartScheduler()
    -- Schedule periodic scans
    SCHEDULER:New(nil, self.ScanTargets, {self}, 1, PILOT_INTUITION_CONFIG.scanInterval)
end

-- (old ScanTargets removed; using the optimized ScanTargets above)

function PilotIntuition:ScanAirTargetsForPlayer(playerUnit, playerData, client, activeClients, enemyAirUnits)
    local playerKey = self:GetPlayerDataKey(playerUnit)
    local playerPos = playerUnit:GetCoordinate()
    local playerCoalition = playerUnit:GetCoalition()
    local enemyCoalition = (playerCoalition == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE

    -- Use cached wingmen count
    local wingmen = playerData.cachedWingmen
    local multiplier = (wingmen > 0) and (2 * wingmen) or 1
    -- Clamp multiplier to configured maximum
    if multiplier > PILOT_INTUITION_CONFIG.maxMultiplier then
        multiplier = PILOT_INTUITION_CONFIG.maxMultiplier
    end
    local envMult = self:GetDetectionMultiplier()
    local detectionRange = PILOT_INTUITION_CONFIG.airDetectionRange * multiplier * envMult

    PILog(LOG_DEBUG, string.format("PilotIntuition: Scanning %d enemy air units within %.0fm for player %s", 
        #enemyAirUnits, detectionRange, playerKey))

    -- Notify formation changes (suppress during active combat if configured)
    local previousWingmen = playerData.previousWingmen or 0
    local now = timer.getTime()
    PILog(LOG_DEBUG, "PilotIntuition: Formation check - previous: " .. previousWingmen .. ", current: " .. wingmen .. ", cached: " .. playerData.cachedWingmen)
    
    -- Check if player is in active combat (has engaged bandits within hot range recently)
    local inCombat = false
    if PILOT_INTUITION_CONFIG.suppressFormationInCombat then
        for _, data in pairs(playerData.trackedAirTargets) do
            if data.engaged and (now - (data.lastEngagedTime or 0)) < 30 then
                inCombat = true
                break
            end
        end
    end
    
    if not inCombat and (now - playerData.lastFormationMessageTime) >= PILOT_INTUITION_CONFIG.formationMessageCooldown then
        local newWingmen = playerData.cachedWingmen
        local newMultiplier = (newWingmen > 0) and (2 * newWingmen) or 1
        -- Clamp multiplier to configured maximum
        if newMultiplier > PILOT_INTUITION_CONFIG.maxMultiplier then
            newMultiplier = PILOT_INTUITION_CONFIG.maxMultiplier
        end
        local newAirRangeMeters = PILOT_INTUITION_CONFIG.airDetectionRange * newMultiplier * envMult
        local newGroundRangeMeters = PILOT_INTUITION_CONFIG.groundDetectionRange * newMultiplier * envMult
        
        -- Convert to player's preferred units
        local newAirRange, airUnit = self:FormatDistance(newAirRangeMeters, playerKey)
        local newGroundRange, groundUnit = self:FormatDistance(newGroundRangeMeters, playerKey)
        
        PILog(LOG_DEBUG, "PilotIntuition: Formation change check - new: " .. newWingmen .. ", prev: " .. previousWingmen .. ", activeMessaging: " .. tostring(PILOT_INTUITION_CONFIG.activeMessaging))
        
        if newWingmen > previousWingmen then
            PILog(LOG_INFO, "PilotIntuition: Formation joined - sending message")
            if PILOT_INTUITION_CONFIG.activeMessaging then
                MESSAGE:New(self:GetRandomMessage("formationJoin", {"wingman", newAirRange, airUnit, newGroundRange, groundUnit}), 10):ToClient(client)
            end
            playerData.lastFormationMessageTime = now
        elseif newWingmen < previousWingmen then
            PILog(LOG_INFO, "PilotIntuition: Formation left - sending message")
            if PILOT_INTUITION_CONFIG.activeMessaging then
                MESSAGE:New(self:GetRandomMessage("formationLeave", {"wingman", newAirRange, airUnit, newGroundRange, groundUnit}), 10):ToClient(client)
            end
            playerData.lastFormationMessageTime = now
        end
    else
        if inCombat then
            PILog(LOG_DEBUG, "PilotIntuition: Formation change suppressed - player in combat")
        else
            PILog(LOG_DEBUG, "PilotIntuition: Formation change message on cooldown")
        end
    end
    playerData.previousWingmen = playerData.cachedWingmen

    -- Formation integrity warning (only if previously had wingmen)
    if previousWingmen >= PILOT_INTUITION_CONFIG.minFormationWingmen and wingmen < PILOT_INTUITION_CONFIG.minFormationWingmen then
        if not playerData.formationWarned and (now - playerData.lastFormationMessageTime) >= PILOT_INTUITION_CONFIG.formationMessageCooldown then
            if PILOT_INTUITION_CONFIG.activeMessaging then
                MESSAGE:New(self:GetRandomMessage("formationIntegrityLow"), 10):ToClient(client)
            end
            playerData.formationWarned = true
            playerData.lastFormationMessageTime = now
        end
    elseif wingmen >= PILOT_INTUITION_CONFIG.minFormationWingmen then
        playerData.formationWarned = false
    end

    -- Prune dead or out-of-range air targets
    for id, data in pairs(playerData.trackedAirTargets) do
        if not data.unit:IsAlive() or playerPos:Get2DDistance(data.unit:GetCoordinate()) > detectionRange then
            -- Explicitly nil out sub-fields before removing to help GC
            data.unit = nil
            data.banditName = nil
            playerData.trackedAirTargets[id] = nil
        end
    end

    local banditCount = 0
    local closestUnit = nil
    local minDistance = math.huge
    -- Reuse existing threateningBandits table to reduce GC pressure
    local threateningBandits = playerData.threateningBandits or {}
    -- Clear the table (faster than creating new one)
    for i = #threateningBandits, 1, -1 do
        threateningBandits[i] = nil
    end
    
    for _, unit in ipairs(enemyAirUnits) do
        PILog(LOG_DEBUG, string.format("PilotIntuition: Checking enemy unit: %s, IsAlive: %s", 
            unit and unit:GetName() or "nil", tostring(unit and unit:IsAlive())))
        if unit and unit:IsAlive() then
            local unitCoord = unit:GetCoordinate()
            if not unitCoord then
                PILog(LOG_DEBUG, "PilotIntuition: Could not get coordinate for " .. unit:GetName())
            else
                local distance = playerPos:Get2DDistance(unitCoord)
                PILog(LOG_DEBUG, string.format("PilotIntuition: Unit %s distance: %.0fm (range: %.0fm)", 
                    unit:GetName(), distance, detectionRange))
                
                -- Check if within detection range AND has line of sight
                if distance <= detectionRange then
                    -- Use coordinate-based LOS check from player to enemy
                    local hasLOS = playerPos:IsLOS(unitCoord)
                    PILog(LOG_DEBUG, string.format("PilotIntuition: Unit %s in range, LOS check: %s", 
                        unit:GetName(), tostring(hasLOS)))
                    
                    if hasLOS then
                        banditCount = banditCount + 1
                        PILog(LOG_DEBUG, string.format("PilotIntuition: Enemy detected with LOS: %s at %.0fm", unit:GetName(), distance))
                        if distance < minDistance then
                            minDistance = distance
                            closestUnit = unit
                        end
                        
                        local targetID = unit:GetName()
                        local now = timer.getTime()
                        
                        -- Calculate bearing from player to bandit
                        local bearing = playerPos:HeadingTo(unitCoord)
                        local playerHeading = playerUnit:GetHeading()  -- Already in degrees
                        
                        -- Calculate relative bearing (clock position)
                        local relativeBearing = (bearing - playerHeading + 360) % 360
                        
                        -- Calculate bandit's aspect angle (is he nose-on or tail-on to us?)
                        local banditHeading = unit:GetHeading()  -- Already in degrees
                        local banditToBearing = (bearing + 180) % 360  -- Reverse bearing (from bandit to player)
                        local aspectAngle = math.abs(banditToBearing - banditHeading)
                        if aspectAngle > 180 then aspectAngle = 360 - aspectAngle end  -- Normalize to 0-180
                        
                        -- Debug logging for first contact
                        if distance < 20000 and not playerData.trackedAirTargets[targetID] then
                            PILog(LOG_DEBUG, string.format("PilotIntuition: Initial contact %s - playerHdg:%.0f° bearing:%.0f° relBrg:%.0f° banditHdg:%.0f° aspect:%.0f°", 
                                targetID, playerHeading, bearing, relativeBearing, banditHeading, aspectAngle))
                        end
                        
                        if not playerData.trackedAirTargets[targetID] then
                local banditName = unit:GetPlayerName() or unit:GetName()
                playerData.trackedAirTargets[targetID] = { unit = unit, engaged = false, lastRange = distance, lastTime = now, wasHot = false, lastRelativeBearing = relativeBearing, lastEngagedTime = 0, banditName = banditName }
                
                -- Safety: Limit tracked targets to prevent memory bloat in long missions (keep 50 most recent)
                local trackedCount = 0
                for _ in pairs(playerData.trackedAirTargets) do trackedCount = trackedCount + 1 end
                if trackedCount > 50 then
                    -- Remove oldest non-engaged target
                    local oldestID, oldestTime = nil, math.huge
                    for tid, tdata in pairs(playerData.trackedAirTargets) do
                        if not tdata.engaged and tdata.lastTime < oldestTime then
                            oldestTime = tdata.lastTime
                            oldestID = tid
                        end
                    end
                    if oldestID then
                        playerData.trackedAirTargets[oldestID].unit = nil
                        playerData.trackedAirTargets[oldestID].banditName = nil
                        playerData.trackedAirTargets[oldestID] = nil
                    end
                end
            else
                playerData.trackedAirTargets[targetID].lastRange = playerData.trackedAirTargets[targetID].lastRange or distance
                playerData.trackedAirTargets[targetID].lastTime = playerData.trackedAirTargets[targetID].lastTime or now
                playerData.trackedAirTargets[targetID].lastRelativeBearing = playerData.trackedAirTargets[targetID].lastRelativeBearing or relativeBearing
            end
            local data = playerData.trackedAirTargets[targetID]
            local closing = distance < data.lastRange
            local wasHot = data.wasHot
            if distance <= PILOT_INTUITION_CONFIG.threatHotRange then
                data.wasHot = true
            end
            data.lastRange = distance
            data.lastTime = now
            local lastRelativeBearing = data.lastRelativeBearing
            data.lastRelativeBearing = relativeBearing

            -- Reset engaged status after 2 minutes of no engagement or if bandit is out of range
            if data.engaged and ((now - data.lastEngagedTime) > 120 or distance > PILOT_INTUITION_CONFIG.airDetectionRange) then
                data.engaged = false
                -- Only report "dogfight concluded" if the bandit was actually hot at some point (actual engagement)
                if data.wasHot and (now - playerData.lastConclusionTime) >= (PILOT_INTUITION_CONFIG.messageCooldown * playerData.frequencyMultiplier) then
                    if PILOT_INTUITION_CONFIG.activeMessaging then
                        local banditName = data.banditName or "bandit"
                        local msg = string.format("%s escaped!", banditName)
                        MESSAGE:New(msg, 10):ToClient(client)
                    end
                    playerData.lastConclusionTime = now
                end
            end

            if not data.engaged then
                -- Calculate altitude information
                local playerAlt = playerUnit:GetAltitude()
                local banditAlt = unit:GetAltitude()
                local altDelta = banditAlt - playerAlt
                
                -- Check for dogfight situations
                local onTail = relativeBearing > 150 and relativeBearing < 210
                local headOn = relativeBearing < 30 or relativeBearing > 330
                local beam = (relativeBearing > 60 and relativeBearing < 120) or (relativeBearing > 240 and relativeBearing < 300)
                local overshoot = distance < PILOT_INTUITION_CONFIG.mergeRange and lastRelativeBearing < 90 and relativeBearing > 270 and not closing
                
                -- High/Low merge detection
                local highMerge = distance < PILOT_INTUITION_CONFIG.mergeRange and closing and altDelta > PILOT_INTUITION_CONFIG.highMergeAltitude
                local lowMerge = distance < PILOT_INTUITION_CONFIG.mergeRange and closing and altDelta < -PILOT_INTUITION_CONFIG.lowMergeAltitude
                local coAltMerge = distance < PILOT_INTUITION_CONFIG.mergeRange and closing and math.abs(altDelta) < 200
                
                -- Separation after being hot
                local separating = wasHot and distance > PILOT_INTUITION_CONFIG.separatingRange and not closing

                -- Build threat descriptor for ALL detected bandits
                local threatType = nil
                local threatDetail = nil
                
                -- Determine threat level based on aspect angle AND distance
                -- Hot = nose-on (0-45°), Cold = tail aspect (135-180°), Flanking/Beam = side aspect
                local threatLevel = "distant"
                if distance <= PILOT_INTUITION_CONFIG.threatHotRange then
                    threatLevel = "hot"
                elseif distance <= PILOT_INTUITION_CONFIG.threatColdRange then
                    -- Use aspect angle to determine if truly hot or cold
                    if aspectAngle <= 45 then
                        threatLevel = "hot"  -- Nose-on, coming at us
                    elseif aspectAngle >= 135 then
                        threatLevel = "cold"  -- Tail aspect, running away
                    else
                        threatLevel = "flanking"  -- Side aspect
                    end
                else
                    threatLevel = "distant"
                end
                
                -- Check for specific tactical situations (high priority)
                if highMerge then
                    threatType = "high merge"
                    threatDetail = string.format("%.0fm above", altDelta)
                elseif lowMerge then
                    threatType = "low merge"
                    threatDetail = string.format("%.0fm below", math.abs(altDelta))
                elseif coAltMerge then
                    threatType = "co-alt merge"
                elseif onTail and distance < PILOT_INTUITION_CONFIG.tailWarningRange then
                    if altDelta > 200 then
                        threatType = "tail high"
                    elseif altDelta < -200 then
                        threatType = "tail low"
                    else
                        threatType = "tail"
                    end
                elseif headOn and distance < PILOT_INTUITION_CONFIG.headOnRange then
                    threatType = "head-on"
                    if math.abs(altDelta) > 200 then
                        threatDetail = string.format("alt %.0f", altDelta)
                    end
                elseif beam and distance < PILOT_INTUITION_CONFIG.beamRange then
                    threatType = "beam"
                    local side = (relativeBearing > 180) and "left" or "right"
                    threatDetail = side
                elseif separating then
                    threatType = "separating"
                elseif overshoot then
                    threatType = "overshot"
                else
                    -- Generic aspect-based description for distant contacts
                    local clockPos = math.floor((relativeBearing + 15) / 30) + 1
                    if clockPos > 12 then clockPos = clockPos - 12 end
                    threatType = threatLevel
                    local distValue, distUnit = self:FormatDistance(distance, playerKey)
                    threatDetail = string.format("%d o'clock, %.1f%s", clockPos, distValue, distUnit)
                    if closing then
                        threatDetail = threatDetail .. ", closing"
                    end
                end
                
                -- Add ALL detected bandits to the list for multi-bandit reporting
                local banditName = unit:GetPlayerName() or unit:GetName()
                table.insert(threateningBandits, {
                    unit = unit,
                    distance = distance,
                    threatType = threatType,
                    threatDetail = threatDetail,
                    relativeBearing = relativeBearing,
                    threatLevel = threatLevel,
                    banditName = banditName
                })
            end
            
            -- Dogfight assist features (if enabled)
            if playerData.dogfightAssist and data.engaged then
                -- Calculate effective cooldown based on combat intensity
                local baseCooldown = PILOT_INTUITION_CONFIG.dogfightMessageCooldown
                local effectiveCooldown = baseCooldown
                
                -- If in high-intensity combat (many bandits), increase cooldown to reduce spam
                local engagedBandits = 0
                for _, targetData in pairs(playerData.trackedAirTargets) do
                    if targetData.engaged then
                        engagedBandits = engagedBandits + 1
                    end
                end
                
                if engagedBandits >= PILOT_INTUITION_CONFIG.combatIntensityThreshold then
                    effectiveCooldown = baseCooldown * PILOT_INTUITION_CONFIG.combatIntensityCooldownMultiplier
                    PILog(LOG_DEBUG, string.format("PilotIntuition: High-intensity combat (%d bandits) - dogfight cooldown increased to %.1fs", engagedBandits, effectiveCooldown))
                end
                
                self:ProvideDogfightAssist(playerUnit, unit, distance, relativeBearing, lastRelativeBearing, playerData, client, closing, effectiveCooldown)
            end
                    end  -- End if hasLOS
                else
                    PILog(LOG_TRACE, string.format("PilotIntuition: Unit %s out of range: %.0fm > %.0fm", 
                        unit:GetName(), distance, detectionRange))
                end  -- End if distance <= detectionRange
            end  -- End if unitCoord
        end  -- End if unit and unit:IsAlive()
    end  -- End for _, unit in ipairs(enemyAirUnits)

    -- Report multiple bandits situation with tactical picture
    PILog(LOG_DEBUG, string.format("PilotIntuition: Threatening bandits count: %d", #threateningBandits))
    
    -- COMBAT FOCUS: Filter out distant threats when in close combat
    local inCloseCombat = false
    local combatFocusRange = PILOT_INTUITION_CONFIG.threatHotRange * 2  -- 2km threshold for "close combat"
    for _, threat in ipairs(threateningBandits) do
        if threat.distance <= combatFocusRange and threat.threatLevel == "hot" then
            inCloseCombat = true
            break
        end
    end
    
    -- If in close combat, filter to only show immediate threats
    local filteredThreats = threateningBandits
    if inCloseCombat then
        filteredThreats = {}
        for _, threat in ipairs(threateningBandits) do
            -- Only report threats within combat focus range OR threats that are hot/flanking
            if threat.distance <= combatFocusRange or threat.threatLevel == "hot" or threat.threatLevel == "flanking" then
                table.insert(filteredThreats, threat)
            end
        end
        PILog(LOG_DEBUG, string.format("PilotIntuition: COMBAT FOCUS - Filtered %d distant threats, showing %d immediate threats", 
            #threateningBandits - #filteredThreats, #filteredThreats))
    end
    
    if #filteredThreats > 0 then
        for i, threat in ipairs(filteredThreats) do
            PILog(LOG_DEBUG, string.format("  Threat %d: %s at %.0fm, type: %s", i, threat.unit:GetName(), threat.distance, threat.threatType))
        end
        local now = timer.getTime()
        if (now - playerData.lastDogfightTime) >= (PILOT_INTUITION_CONFIG.messageCooldown * playerData.frequencyMultiplier) then
            local message = ""
            if #filteredThreats == 1 then
                -- Single bandit - detailed callout
                local threat = filteredThreats[1]
                local banditName = threat.banditName or "bandit"
                if threat.threatDetail then
                    message = string.format("%s - %s! %s", banditName, threat.threatType:gsub("^%l", string.upper), threat.threatDetail)
                else
                    message = string.format("%s - %s!", banditName, threat.threatType:gsub("^%l", string.upper))
                end
            else
                -- Multiple bandits - build tactical picture, showing only most threatening
                -- Sort by threat priority: hot > flanking > cold > distant, then by distance
                table.sort(filteredThreats, function(a, b)
                    local priorityOrder = {hot = 1, flanking = 2, cold = 3, distant = 4}
                    local aPriority = priorityOrder[a.threatLevel] or 5
                    local bPriority = priorityOrder[b.threatLevel] or 5
                    if aPriority ~= bPriority then
                        return aPriority < bPriority
                    else
                        return a.distance < b.distance
                    end
                end)
                
                local maxDisplay = PILOT_INTUITION_CONFIG.maxThreatDisplay
                local displayCount = math.min(maxDisplay, #filteredThreats)
                local totalCount = #filteredThreats
                
                message = string.format("Multiple bandits - %d contacts", totalCount)
                if displayCount < totalCount then
                    message = message .. string.format(" (showing %d most threatening)", displayCount)
                end
                message = message .. ": "
                
                local threats = {}
                for i = 1, displayCount do
                    local threat = filteredThreats[i]
                    local banditName = threat.banditName or "unknown"
                    local desc = banditName .. " - " .. threat.threatType
                    if threat.threatDetail then
                        desc = desc .. " (" .. threat.threatDetail .. ")"
                    end
                    table.insert(threats, desc)
                end
                message = message .. table.concat(threats, ", ")
            end
            
            if PILOT_INTUITION_CONFIG.activeMessaging then
                MESSAGE:New(message, 10):ToClient(client)
            end
            playerData.lastDogfightTime = now
            
            -- Mark only HOT bandits as engaged (within hot range or actively threatening)
            for _, threat in ipairs(threateningBandits) do
                local data = playerData.trackedAirTargets[threat.unit:GetName()]
                if data and threat.threatLevel == "hot" then
                    data.engaged = true
                    data.lastEngagedTime = now
                end
            end
        end
    end

    -- Report the closest unengaged bandit (if no threats)
    if #threateningBandits == 0 and closestUnit then
        local data = playerData.trackedAirTargets[closestUnit:GetName()]
        if data and not data.engaged then
            local playerKey = self:GetPlayerDataKey(playerUnit)
            self:ReportAirTarget(closestUnit, playerPos, playerData, client, playerKey)
        end
    end

    -- Check for multiple bandits (with 5-minute cooldown to reduce spam)
    if banditCount > 1 then
        local now = timer.getTime()
        if (now - (playerData.lastMultipleBanditsWarningTime or 0)) >= PILOT_INTUITION_CONFIG.multipleBanditsWarningCooldown then
            self:ReportDogfight(nil, playerPos, playerData, client, "Multiple bandits in vicinity!")
            playerData.lastMultipleBanditsWarningTime = now
        end
    end
end

function PilotIntuition:ReportAirTarget(unit, playerPos, playerData, client, playerKey)
    local now = timer.getTime()
    if now - playerData.lastMessageTime < (PILOT_INTUITION_CONFIG.messageCooldown * playerData.frequencyMultiplier) then return end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end

    local unitCoord = unit:GetCoordinate()
    if not unitCoord then
        PILog(LOG_DEBUG, "PilotIntuition: Could not get unit coordinate for air target report")
        return
    end
    
    local bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(unitCoord))
    local rangeMeters = playerPos:Get2DDistance(unitCoord)
    local range, distUnit = self:FormatDistance(rangeMeters, playerKey)
    -- Convert altitude to angels (thousands of feet)
    local altMeters = unit:GetAltitude()
    local altFeet = altMeters * 3.28084
    local angels = math.floor(altFeet / 1000)
    local threat = "cold"
    if rangeMeters <= PILOT_INTUITION_CONFIG.threatHotRange then
        threat = "hot"
    end
    
    local group = unit:GetGroup()
    if not group then
        PILog(LOG_DEBUG, "PilotIntuition: Could not get group for air target")
        return
    end
    local groupSize = #group:GetUnits()
    local sizeDesc = groupSize == 1 and "single" or (groupSize == 2 and "pair" or "flight of " .. groupSize)

    MESSAGE:New(self:GetRandomMessage("airTargetDetected", {threat, bearing, range, distUnit, angels, sizeDesc}), 10):ToClient(client)
    playerData.lastMessageTime = now
end

function PilotIntuition:ReportDogfight(unit, playerPos, playerData, client, message)
    local now = timer.getTime()
    if now - playerData.lastMessageTime < (PILOT_INTUITION_CONFIG.messageCooldown * playerData.frequencyMultiplier) then return end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end

    MESSAGE:New(message, 10):ToClient(client)
    playerData.lastMessageTime = now
end

function PilotIntuition:ScanGroundTargetsForPlayer(playerUnit, client, activeClients, enemyGroundGroups, placeMarker)
    if placeMarker == nil then placeMarker = true end
    local playerPos = playerUnit:GetCoordinate()
    local playerCoalition = playerUnit:GetCoalition()
    local enemyCoalition = (playerCoalition == coalition.side.BLUE) and coalition.side.RED or coalition.side.BLUE
    local unitName = playerUnit:GetName()
    local playerData = self.players[unitName]
    if not playerData then return end

    -- Use cached wingmen count
    local wingmen = playerData.cachedWingmen
    local multiplier = (wingmen > 0) and (2 * wingmen) or 1
    if multiplier > PILOT_INTUITION_CONFIG.maxMultiplier then
        multiplier = PILOT_INTUITION_CONFIG.maxMultiplier
    end
    local envMult = self:GetDetectionMultiplier()
    local detectionRange = PILOT_INTUITION_CONFIG.groundDetectionRange * multiplier * envMult

    -- Prune out-of-range ground targets for this player
    for id, _ in pairs(playerData.trackedGroundTargets) do
        local group = self.trackedGroundTargets[id]
        if not group or not group.group:IsAlive() or playerPos:Get2DDistance(group.group:GetCoordinate()) > detectionRange then
            playerData.trackedGroundTargets[id] = nil
        end
    end

    -- Find the closest unmarked target for this player (no sorting needed)
    local closestGroup = nil
    local minDistance = math.huge
    for _, group in ipairs(enemyGroundGroups or {}) do
        local distance = playerPos:Get2DDistance(group:GetCoordinate())
        if distance <= detectionRange then
            local targetID = group:GetName()
            if not self.trackedGroundTargets[targetID] then
                self.trackedGroundTargets[targetID] = { group = group, marked = false }
            end
            if not playerData.trackedGroundTargets[targetID] and distance < minDistance then
                closestGroup = group
                minDistance = distance
            end
        end
    end

    -- Mark and report the closest unmarked target
    if closestGroup then
        local targetID = closestGroup:GetName()
        self:ReportGroundTarget(closestGroup, playerUnit, client, placeMarker)
        self.trackedGroundTargets[targetID].marked = true
        playerData.trackedGroundTargets[targetID] = true
    end
end

function PilotIntuition:CheckCloseFlyingForPlayer(playerUnit, playerData, client, activeClients)
    if not PILOT_INTUITION_CONFIG.enableCloseFlyingCompliments then return end
    local playerPos = playerUnit:GetCoordinate()
    local playerCoalition = playerUnit:GetCoalition()
    local now = timer.getTime()
    local playerHeading = math.deg(playerUnit:GetHeading())

    for _, info in ipairs(activeClients) do
        local otherUnit = info.unit
        if otherUnit and otherUnit:IsAlive() and otherUnit:GetCoalition() == playerCoalition and otherUnit:GetName() ~= playerUnit:GetName() then
            local otherCoord = otherUnit:GetCoordinate()
            if otherCoord then
                local distance = playerPos:Get2DDistance(otherCoord)
                if distance <= PILOT_INTUITION_CONFIG.complimentRange then
                    -- Calculate relative bearing
                    local bearing = playerPos:GetAngleDegrees(playerPos:GetDirectionVec3(otherCoord))
                    local relativeBearing = bearing - playerHeading
                    relativeBearing = (relativeBearing % 360 + 360) % 360  -- Normalize to 0-360

                    -- Check if head-on (within 30 degrees of front or back, but for pass, focus on front)
                    local isHeadOn = relativeBearing < 30 or relativeBearing > 330

                    if isHeadOn and distance <= PILOT_INTUITION_CONFIG.headOnWarningRange then
                        if now - playerData.lastHeadOnWarningTime >= (PILOT_INTUITION_CONFIG.closeFlyingMessageCooldown * playerData.frequencyMultiplier) then
                            MESSAGE:New(self:GetRandomMessage("headOnWarning"), 10):ToClient(client)
                            playerData.lastHeadOnWarningTime = now
                        end
                    elseif not isHeadOn then
                        if now - playerData.lastComplimentTime >= (PILOT_INTUITION_CONFIG.closeFlyingMessageCooldown * playerData.frequencyMultiplier) then
                            MESSAGE:New(self:GetRandomMessage("closeFlyingCompliment"), 10):ToClient(client)
                            playerData.lastComplimentTime = now
                        end
                    end
                end
            end
        end
    end
end

function PilotIntuition:ReportGroundTarget(group, playerUnit, client, placeMarker)
    if placeMarker == nil then placeMarker = true end
    local now = timer.getTime()
    if now - self.lastMessageTime < PILOT_INTUITION_CONFIG.messageCooldown then return end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end
    local playerPos = playerUnit:GetCoordinate()
    local targetPos = group:GetCoordinate()
    local bearing = playerPos:HeadingTo(targetPos)  -- Returns heading in degrees as number
    
    -- Ensure bearing is a valid number
    if not bearing or type(bearing) ~= "number" then
        bearing = 0  -- Fallback to 0 if bearing is invalid
    end
    
    local distanceMeters = playerPos:Get2DDistance(targetPos)
    local playerKey = self:GetPlayerDataKey(playerUnit)
    local distance, unit = self:FormatDistance(distanceMeters, playerKey)
    local unitType = group:GetUnits()[1]:GetTypeName()
    local category = self:ClassifyGroundUnit(unitType)
    local groupSize = #group:GetUnits()
    local sizeDesc = groupSize == 1 and "single" or (groupSize <= 4 and "group" or "platoon")

    MESSAGE:New(self:GetRandomMessage("groundTargetDetected", {category, sizeDesc, unitType, bearing, distance, unit}), 10):ToClient(client)
    self.lastMessageTime = now

    -- Place marker if requested
    if placeMarker then
        -- Determine marker type: prefer player preference if set, otherwise global config
        local markerType = PILOT_INTUITION_CONFIG.markerType
        local playerName = playerUnit:GetPlayerName() or playerUnit:GetName()
        if self.players[playerName] and self.players[playerName].markerType then
            markerType = self.players[playerName].markerType
        end
        if markerType ~= "none" then
            local coord = group:GetCoordinate()
            local markerTypePart, color = markerType:match("(%w+)_(%w+)")
            if markerTypePart == "smoke" then
                if color == "red" then coord:SmokeRed()
                elseif color == "green" then coord:SmokeGreen()
                elseif color == "blue" then coord:SmokeBlue()
                elseif color == "white" then coord:SmokeWhite()
                end
            elseif markerTypePart == "flare" then
                if color == "red" then coord:FlareRed()
                elseif color == "green" then coord:FlareGreen()
                elseif color == "white" then coord:FlareWhite()
                end
            end
            -- Note: Markers are temporary; Moose doesn't have built-in timed markers, so this is basic
        end
    end
end

function PilotIntuition:GetDetectionMultiplier()
    -- Basic night detection: reduce range at night (22:00 to 06:00)
    local time = timer.getAbsTime() % 86400
    local hour = math.floor(time / 3600)
    local isNight = hour >= 22 or hour < 6
    local mult = 1
    if isNight then
        mult = mult * PILOT_INTUITION_CONFIG.nightDetectionMultiplier
    end
    -- TODO: Add weather check if available
    return mult
end

function PilotIntuition:ClassifyGroundUnit(unitType)
    unitType = string.lower(unitType)
    if string.find(unitType, "tank") or string.find(unitType, "armor") or string.find(unitType, "panzer") then
        return "Armor"
    elseif string.find(unitType, "infantry") or string.find(unitType, "soldier") then
        return "Infantry"
    elseif string.find(unitType, "aaa") or string.find(unitType, "flak") or string.find(unitType, "aa") then
        return "Anti-Air"
    elseif string.find(unitType, "truck") or string.find(unitType, "vehicle") or string.find(unitType, "transport") then
        return "Logistics"
    else
        return "Ground"
    end
end

function PilotIntuition:ProvideDogfightAssist(playerUnit, banditUnit, distance, relativeBearing, lastRelativeBearing, playerData, client, closing, effectiveCooldown)
    local now = timer.getTime()
    -- Use provided effectiveCooldown (for combat intensity adjustment) or fall back to default
    local cooldown = effectiveCooldown or PILOT_INTUITION_CONFIG.dogfightMessageCooldown
    if (now - playerData.lastDogfightAssistTime) < (cooldown * playerData.frequencyMultiplier) then
        return
    end
    if not PILOT_INTUITION_CONFIG.activeMessaging then return end
    
    local playerPos = playerUnit:GetCoordinate()
    local banditPos = banditUnit:GetCoordinate()
    local playerAlt = playerUnit:GetAltitude()
    local banditAlt = banditUnit:GetAltitude()
    local altDelta = banditAlt - playerAlt
    
    -- Check for speed warning
    local velocity = playerUnit:GetVelocityKMH()
    local speedKnots = velocity * 0.539957
    if speedKnots < PILOT_INTUITION_CONFIG.criticalSpeedThreshold then
        MESSAGE:New("Speed critical! Extend!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Target loss detection (front to rear hemisphere)
    if lastRelativeBearing and lastRelativeBearing < 90 and relativeBearing > 270 then
        MESSAGE:New("Lost visual! Bandit reversing on you!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Check for bandit moving behind (now behind, wasn't before)
    if relativeBearing > 150 and relativeBearing < 210 and distance < PILOT_INTUITION_CONFIG.tailWarningRange then
        local direction = relativeBearing < 180 and "left" or "right"
        MESSAGE:New("Bandit at 6 o'clock! Break " .. direction .. "!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Closure rate warning (check this BEFORE altitude to prioritize immediate threats)
    if closing and distance < PILOT_INTUITION_CONFIG.threatHotRange then
        MESSAGE:New("Bandit closing fast! Prepare to engage!", 10):ToClient(client)
        playerData.lastDogfightAssistTime = now
        return
    end
    
    -- Significant position change
    if playerData.lastPrimaryTargetBearing then
        local bearingChange = math.abs(relativeBearing - playerData.lastPrimaryTargetBearing)
        if bearingChange > PILOT_INTUITION_CONFIG.positionChangeThreshold and bearingChange < (360 - PILOT_INTUITION_CONFIG.positionChangeThreshold) then
            local clockPos = math.floor(relativeBearing / 30) + 1
            if clockPos > 12 then clockPos = clockPos - 12 end
            MESSAGE:New("Bandit moving to " .. clockPos .. " o'clock!", 10):ToClient(client)
            playerData.lastDogfightAssistTime = now
            playerData.lastPrimaryTargetBearing = relativeBearing
            return
        end
    end
    
    -- Altitude advantage/disadvantage (lower priority - only if no other callouts triggered)
    if math.abs(altDelta) > PILOT_INTUITION_CONFIG.altitudeDeltaThreshold then
        local clockPos = math.floor(relativeBearing / 30) + 1
        if clockPos > 12 then clockPos = clockPos - 12 end
        local distKM = math.floor(distance / 1000 * 10) / 10
        
        if altDelta > 0 then
            -- Bandit is higher
            local altKFeet = math.floor(altDelta * 3.28084 / 1000)
            MESSAGE:New(string.format("Bandit %d o'clock, %.1fkm, %dk above!", clockPos, distKM, altKFeet), 10):ToClient(client)
        else
            -- You have altitude advantage
            local altKFeet = math.floor(math.abs(altDelta) * 3.28084 / 1000)
            MESSAGE:New(string.format("Bandit %d o'clock, %.1fkm, you're %dk high!", clockPos, distKM, altKFeet), 10):ToClient(client)
        end
        playerData.lastDogfightAssistTime = now
    end
    
    playerData.lastPrimaryTargetBearing = relativeBearing
end

-- Handle engagement (simplified: if player shoots, assume engagement for nearest target)
function PilotIntuition:OnPlayerShot(EventData)
    if not self.enabled then return end
    local playerUnit = EventData.IniUnit
    if not playerUnit then return end
    local client = playerUnit:GetClient()
    if client then
        local unitName = playerUnit:GetName()
        if self.players[unitName] then
            local playerData = self.players[unitName]
            -- Calculate wingmen for extended range
            local clients = SET_CLIENT:New():FilterActive():FilterOnce()
            local wingmen = 0
            clients:ForEachClient(function(c)
                if c and type(c.GetUnit) == "function" then
                    local u = c:GetUnit()
                    -- Validate playerUnit still exists before using it
                    if u and u:IsAlive() and playerUnit and playerUnit:IsAlive() and u:GetCoalition() == playerUnit:GetCoalition() and u:GetName() ~= playerUnit:GetName() then
                        local playerCoord = playerUnit:GetCoordinate()
                        local uCoord = u:GetCoordinate()
                        if playerCoord and uCoord then
                            local dist = playerCoord:Get2DDistance(uCoord)
                            if dist <= PILOT_INTUITION_CONFIG.formationRange then
                                wingmen = wingmen + 1
                            end
                        end
                    end
                end
            end)
            local multiplier = (wingmen > 0) and (2 * wingmen) or 1
            if multiplier > PILOT_INTUITION_CONFIG.maxMultiplier then
                multiplier = PILOT_INTUITION_CONFIG.maxMultiplier
            end
            local detectionRange = PILOT_INTUITION_CONFIG.airDetectionRange * multiplier
            -- Find nearest air target and mark as engaged
            local minDist = math.huge
            local nearestID = nil
            for id, data in pairs(playerData.trackedAirTargets) do
                if not data.engaged and data.unit and data.unit:IsAlive() and playerUnit and playerUnit:IsAlive() then
                    local playerCoord = playerUnit:GetCoordinate()
                    local targetCoord = data.unit:GetCoordinate()
                    if playerCoord and targetCoord then
                        local distance = playerCoord:Get2DDistance(targetCoord)
                        if distance < minDist then
                            minDist = distance
                            nearestID = id
                        end
                    end
                end
            end
            if nearestID and minDist <= detectionRange then
                playerData.trackedAirTargets[nearestID].engaged = true
                playerData.trackedAirTargets[nearestID].lastEngagedTime = timer.getTime()
                if PILOT_INTUITION_CONFIG.activeMessaging then
                    MESSAGE:New(self:GetRandomMessage("dogfightEngaged"), 10):ToClient(client)
                end
            end
        end
    end
end

-- Handle being shot at
function PilotIntuition:OnShotFired(EventData)
    if not self.enabled then return end
    local shooter = EventData.IniUnit
    if not shooter then return end
    
    -- Check if any player is the target
    local clients = SET_CLIENT:New():FilterActive():FilterOnce()
    clients:ForEachClient(function(client)
        if client and type(client.GetUnit) == "function" then
            local playerUnit = client:GetUnit()
            if playerUnit and playerUnit:IsAlive() and playerUnit:GetCoalition() ~= shooter:GetCoalition() then
                local playerName = playerUnit:GetPlayerName() or playerUnit:GetName()
                if self.players[playerName] and self.players[playerName].dogfightAssist then
                    local playerData = self.players[playerName]
                    local now = timer.getTime()
                    if not PILOT_INTUITION_CONFIG.activeMessaging then return end
                    
                    -- Check if shot is directed at player (within range and aspect)
                    local playerCoord = playerUnit:GetCoordinate()
                    local shooterCoord = shooter:GetCoordinate()
                    if not playerCoord or not shooterCoord then
                        return
                    end
                    local distance = playerCoord:Get2DDistance(shooterCoord)
                    if distance < 1500 and (now - playerData.lastDogfightAssistTime) >= (PILOT_INTUITION_CONFIG.dogfightMessageCooldown * playerData.frequencyMultiplier) then
                        local bearing = playerCoord:GetAngleDegrees(playerCoord:GetDirectionVec3(shooterCoord))
                        local playerHeading = math.deg(playerUnit:GetHeading())
                        local relativeBearing = (bearing - playerHeading + 360) % 360
                        
                        -- Determine evasion direction
                        local direction = "left"
                        if relativeBearing > 180 then
                            direction = "right"
                        end
                        
                        -- Check if above or below
                        local altDelta = shooter:GetAltitude() - playerUnit:GetAltitude()
                        local vertical = ""
                        if altDelta > 100 then
                            vertical = " Push!"
                        elseif altDelta < -100 then
                            vertical = " Pull!"
                        end
                        
                        MESSAGE:New(self:GetRandomMessage("underFire", {direction, vertical})):ToClient(client)
                        playerData.lastDogfightAssistTime = now
                    end
                end
            end
        end
    end)
end

-- Initialize the Pilot Intuition system
PILog(LOG_INFO, "====== PILOT INTUITION SYSTEM STARTING ======")
local pilotIntuitionSystem = PilotIntuition:New()
PILog(LOG_INFO, "====== PILOT INTUITION SYSTEM INITIALIZED ======")