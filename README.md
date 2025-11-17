# MOOSE Dual Coalition Zone Capture System

A dynamic zone capture and control system for DCS World missions using the MOOSE framework. This script enables territory-based gameplay where RED and BLUE coalitions compete to capture and hold strategic zones across the battlefield.

![Version](https://img.shields.io/badge/version-2.0-blue)
![DCS](https://img.shields.io/badge/DCS-2.9%2B-green)
![MOOSE](https://img.shields.io/badge/MOOSE-Latest-orange)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## 🎯 Features

- **🎨 Visual Feedback**: Color-coded zone boundaries (Red/Blue/Green/Orange) that change dynamically
- **💨 Smoke Signals**: Automatic smoke markers indicating zone status
- **📍 Tactical Information**: Real-time force composition and MGRS coordinates for enemies
- **🏆 Victory Conditions**: Automatic win detection when one coalition captures all zones
- **📻 F10 Radio Menu**: Player-accessible status reports and progress tracking
- **⚙️ Highly Configurable**: Simple zone ownership configuration via Lua tables
- **🔄 Dual Coalition**: Full support for both RED and BLUE coalitions
- **📊 Auto-Reporting**: Periodic status updates every 5 minutes
- **🎮 Player-Friendly**: Clear messaging and intuitive state transitions

## 🚀 Quick Start

### Prerequisites

1. **DCS World** (version 2.9 or higher)
2. **MOOSE Framework** ([Download here](https://github.com/FlightControl-Master/MOOSE))
3. Basic knowledge of DCS Mission Editor

### Installation

1. **Download the files:**
   - `Moose_DualCoalitionZoneCapture.lua` - Main script
   - `Moose_DualCoalitionZoneCapture.miz` - Example mission
   - `Moose_.lua` - MOOSE framework (get latest version)

2. **In DCS Mission Editor:**
   - Create trigger zones for each capture point (e.g., "Capture Zone-1", "Capture Severomorsk")
   - Create two groups: `BLUEHQ` (any BLUE ground unit) and `REDHQ` (any RED ground unit)

3. **Configure zones** in `Moose_DualCoalitionZoneCapture.lua`:

```lua
local ZONE_CONFIG = {
  RED = {
    "Capture Zone-1",
    "Capture Zone-2"
  },
  BLUE = {
    "Capture Zone-3",
    "Capture Zone-4"
  },
  NEUTRAL = {
    -- Empty zones at mission start
  }
}
```

4. **Load scripts** via Mission Start trigger:
   - Action 1: DO SCRIPT FILE → `Moose_.lua`
   - Action 2: DO SCRIPT FILE → `Moose_DualCoalitionZoneCapture.lua`

5. **Save and test** your mission!

## 📖 How It Works

### Zone States

Zones transition between four distinct states:

| State | Color | Smoke | Description |
|-------|-------|-------|-------------|
| **RED Controlled** | 🔴 Red Border | Red | Zone secured by RED coalition |
| **BLUE Controlled** | 🔵 Blue Border | Blue | Zone secured by BLUE coalition |
| **Neutral/Empty** | 🟢 Green Border | Green | Uncontrolled, ready for capture |
| **Contested** | 🟠 Orange Border | White | Multiple coalitions present - fighting for control |

### Capture Mechanics

- **To Capture**: Move ground units into a zone
- **To Hold**: Eliminate all enemy forces in the zone
- **To Win**: Capture ALL zones on the map

The script automatically scans zones every 30 seconds (configurable) and updates ownership based on unit presence.

### Tactical Information Markers

Each zone displays real-time tactical data:

```
TACTICAL: Capture Severomorsk-1
Forces: R:5 B:12
TGTS: T-90@38U LV 12345 67890, BTR-80@38U LV 12346 67891
```

- **Force Counts**: Number of units per coalition
- **MGRS Coordinates**: Precise enemy locations (when ≤10 units)
- **Coalition-Specific**: Each side sees their enemies marked

## ⚙️ Configuration Options

### Zone Settings

```lua
local ZONE_SETTINGS = {
  guardDelay = 1,        -- Seconds before entering Guard state after capture
  scanInterval = 30,     -- How often to scan for units (seconds)
  captureScore = 200     -- Points awarded for zone capture
}
```

### Performance Tuning

For missions with many units:
```lua
scanInterval = 60  -- Scan less frequently
```

For fast-paced action:
```lua
scanInterval = 15  -- More responsive zone changes
```

### Logging Control

Disable detailed logging:
```lua
CAPTURE_ZONE_LOGGING = { enabled = false }
```

## 👥 Player Features

### F10 Radio Menu Commands

Players access zone information via **F10 → Zone Control**:

- **Get Zone Status Report**: Current ownership of all zones
- **Check Victory Progress**: Percentage toward victory
- **Refresh Zone Colors**: Manually redraw zone boundaries

### Automatic Notifications

- ✅ Zone capture/loss announcements
- ⚠️ Attack warnings when zones are contested
- 📊 Status reports every 5 minutes
- 🏆 Victory alerts at 80% and 100% completion
- 🎉 Victory countdown with celebratory effects

## 🎮 Example Mission

The included `Moose_DualCoalitionZoneCapture.miz` demonstrates:

- Proper zone configuration
- HQ group placement
- Script loading order
- AI patrol patterns for testing
- All visual and messaging features

**Use this mission as a template for your own scenarios!**

## 🔧 Troubleshooting

### Common Issues

#### ❌ Script Won't Load
**Error**: "attempt to index a nil value"
- **Cause**: MOOSE not loaded first
- **Fix**: Ensure load order is MOOSE → Capture Script

#### ❌ Zone Not Found
**Error**: "Zone 'X' not found in mission editor!"
- **Cause**: Zone name mismatch
- **Fix**: Verify zone names match EXACTLY (case-sensitive!)

#### ⚠️ Zones Not Capturing
- Only ground units, planes, and helicopters are scanned
- Wait 30 seconds for scan cycle
- Eliminate ALL enemy forces to capture
- Check DCS.log for detailed information

### Checking Logs

Open `Saved Games\DCS\Logs\DCS.log` and search for:
- `[CAPTURE Module]` - General logging
- `[INIT]` - Initialization messages
- `[TACTICAL]` - Tactical marker updates
- `[VICTORY]` - Victory condition checks

## 🏗️ Mission Design Tips

### Best Practices

- **Zone Size**: Large enough for tactical areas, avoid overlaps
- **Zone Placement**: Position over airbases, FOBs, strategic terrain
- **Starting Balance**: Consider defensive vs. offensive scenarios
- **AI Behavior**: Use "Ground Hold" or "Ground On Road" waypoints
- **Player Briefing**: Document F10 menu commands in mission brief

### Integration with Other Scripts

Access zone data from other scripts:

```lua
-- Get current ownership status
local status = GetZoneOwnershipStatus()
-- Returns: { blue = X, red = Y, neutral = Z, total = N, zones = {...} }

-- Manual status broadcast
BroadcastZoneStatus()

-- Refresh zone visuals
RefreshAllZoneColors()
```

### Victory Flags

The script sets user flags on victory:
- `BLUE_VICTORY = 1` when BLUE wins
- `RED_VICTORY = 1` when RED wins

Use these in triggers to end missions or transition to next phase.

## 📋 Requirements

### Essential Components

- ✅ DCS World 2.9 or higher
- ✅ MOOSE Framework (latest version)
- ✅ Trigger zones in mission editor
- ✅ BLUEHQ and REDHQ groups

### Mission Prerequisites

- At least one trigger zone per capture point
- Exact zone name matching between editor and Lua config
- Both HQ groups must exist (can be hidden/inactive)

## 📞 Support & Resources

### Get Help

- **Discord Community**: [https://discord.gg/7wBVWKK3](https://discord.gg/7wBVWKK3)
- **Author**: F99th-TracerFacer
- **GitHub Issues**: Report bugs or request features

### Additional Resources

- [MOOSE Documentation](https://flightcontrol-master.github.io/MOOSE_DOCS/)
- [MOOSE Discord](https://discord.gg/gj68fm969S)
- [DCS Forums](https://forum.dcs.world)

## 📄 License

This script is provided free for use in DCS World missions. Feel free to modify and distribute.

## 🙏 Credits

- **Author**: F99th-TracerFacer
- **Framework**: MOOSE by FlightControl
- **Community**: DCS World Mission Makers

## 🎯 Version History

### Version 2.0 (Current)
- ✨ Full dual coalition support (RED & BLUE)
- ✨ Tactical information markers with MGRS coordinates
- ✨ Auto-victory detection and countdown
- ✨ F10 radio menu commands
- ✨ Periodic status reports
- ✨ Enhanced visual feedback system
- ✨ Configurable zone ownership via Lua tables

### Version 1.0
- Initial release
- Basic zone capture mechanics
- Single coalition focus

---

<div align="center">

**🎮 Happy Mission Making! 🚁**

*Created with ❤️ for the DCS World Community*

[Discord](https://discord.gg/7wBVWKK3) • [Documentation](Mission_Maker_Guide.html) • [Report Issue](#)

</div>
