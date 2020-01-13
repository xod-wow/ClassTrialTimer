--[[----------------------------------------------------------------------------

  ClassTrialTimer - World of Warcraft AddOn

  Copyright 2017-2020 Mike Battersby

  ClassTrialTimer is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License, version 2, as published
  by the Free Software Foundation.

  ClassTrialTimer is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
  more details.

  The file LICENSE.txt included with LiteMount contains a copy of the
  license. If the LICENSE.txt file is missing, you can find a copy at
  http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt

----------------------------------------------------------------------------]]--

-- Your new trial character is playable for eight hours, or until you
-- receive your first artifact weapon and create your Order Hall. After the
-- trial is over, your character is locked from further play. You can purchase
-- and use a Character Boost to permanently unlock your trial character.
--
--   https://us.battle.net/support/en/article/64574

local WarnAtSeconds = {
    [600] = true,
    [300] = true,
    [240] = true,
    [180] = true,
    [120] = true,
     [60] = true,
     [30] = true,
     [15] = true,
}

local function clamp(value, minClamp, maxClamp)
    return min(max(value, minClamp), maxClamp)
end

local function ClassTrialMaxSeconds()
    local level = UnitLevel("player")
    if level < 110 then
        return 8 * 60 * 60
    else
        return 3 * 60 * 60
    end
end

local function Alert(...)
    local msg = format(...)
    local f = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    f:AddMessage(RED_FONT_COLOR_CODE .. msg .. FONT_COLOR_CODE_CLOSE)
end

-- Tooltip scanning, annoying but the only way it seems
local function SameZone(unit)

    -- "player" always visible so can skip UnitIsUnit("player", unit)

    if UnitIsVisible(unit) then
        return true
    end

    if not UnitIsConnected(unit) then
        return false
    end

    local tt = CTTScanTip
    if not tt then
        tt = CreateFrame("GameTooltip", "CTTScanTip")
        tt:SetOwner(UIParent, "ANCHOR_NONE")
    end

    local pzone, text, fs = GetSubZoneText()

    tt:ClearLines()
    tt:SetUnit(unit)

    -- This is a good-enough test, look through all the TT lines and
    -- see if any of the left texts match the player zone name
    for i = 2, tt:NumLines() do
        fs = _G["CTTScanTipLeftText"..i]
        if fs then
            text = fs:GetText()
            if text == pzone then return true end
        end
    end

    return false
end

-- God dammit Blizzard
local function UnitDisplayName(unit)
    local n, r = UnitFullName(unit)
    r = r or select(2, UnitFullName("player"))
    return format('%s-%s', n, r)
end

local function SameZoneCheckAndAlert()
    local unit, name
    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS do
            unit = "raid"..i
            if UnitExists(unit) and not SameZone(unit) then
                Alert('%s (%s) is not here', UnitDisplayName(unit), unit)
            end
        end
    elseif IsInGroup() then
        for i = 1, MAX_PARTY_MEMBERS do
            unit = "party"..i
            if UnitExists(unit) and not SameZone(unit) then
                Alert('%s (%s) is not here', UnitDisplayName(unit), unit)
            end
        end
    end
end

local function Update(self)
    if not self.expireTime then return end

    local remainingTime = self.expireTime - time()
    local h = floor((remainingTime % 86400) / 3600)
    local m = floor((remainingTime % 3600) / 60)
    local s = remainingTime % 60

    local string
    if self.db.showSeconds and
       (self.db.showSeconds == true or remainingTime < self.db.showSeconds)
    then
        string = format('%02s:%02d:%02d', h, m, s)
    else
        string = format('%02d:%02d', h, m)
    end
    self.remainingTime:SetText(string)

    if remainingTime < 15 * 60 then
        self.remainingTime:SetTextColor(1, 1, 0.5, 0.7)
    else
        self.remainingTime:SetTextColor(0.5, 1, 0.5, 0.7)
    end

    if WarnAtSeconds[remainingTime] then
        local info = ChatTypeInfo["SYSTEM"]
        local formattedTime = SecondsToTime(remainingTime, false, true, 1, true)
        local timerText = format(CLASS_TRIAL_TIMER_DIALOG_TEXT_HAS_REMAINING_TIME, formattedTime)
        DEFAULT_CHAT_FRAME:AddMessage(timerText, info.r, info.g, info.b, info.id)
        PlaySound(SOUNDKIT.READY_CHECK)
    end
end

local function SavePosition(self)
    local p, _, r, x, y = self:GetPoint(1)
    self.db.position = { p, r, x, y }
    self.db.color = { self:GetBackdropColor() }
end

local function LoadPosition(self)
    if self.db.position then
        self:ClearAllPoints()
        local p, r, x, y = unpack(self.db.position)
        self:SetPoint(p, UIParent, r, x, y)
    else
        self:ClearAllPoints()
        self:SetPoint("TOP", UIParent, "TOP", 0, -12)
    end

    if self.db.color then
        local r, g, b, a = unpack(self.db.color)
        self:SetBackdropColor(r, g, b, a)
        self:SetBackdropBorderColor(r, g, b, min(2*a, 1))
    else
        self:SetBackdropColor(1, 1, 1, 0.25)
        self:SetBackdropBorderColor(1, 1, 1, 0.5)
    end

    self:SetScale(self.db.scale or 1.0)
    self:EnableMouse(not self.db.locked)
end

local function ResetPosition(self)
    self.db.position = nil
    self.db.color = nil
    LoadPosition(self)
end

local function SlashCommand(self, argstr)
    local args = { strsplit(" ", argstr) }
    local cmd = table.remove(args, 1)

    if cmd == "hide" then
        self:Hide()
    elseif cmd == "show" then
        self:Show()
    elseif cmd == "seconds" then
        if args[1] == "off" or args[1] == "0" then
            self.db.showSeconds = nil
        elseif args[1] == "on" then
            self.db.showSeconds = true
        else
            self.db.showSeconds = tonumber(args[1])
        end
    elseif cmd == "reset" then
        wipe(self.db)
        ResetPosition(self)
        Update(self)
    elseif cmd == "alpha" then
        local a = tonumber(args[1])
        if not a then
            self.db.color = nil
        else
            self.db.color = { 1, 1, 1, clamp(a, 0.0, 1.0) }
        end
        LoadPosition(self)
    elseif cmd == "scale" then
        local a = tonumber(args[1])
        if not a then
            self.db.scale = nil
        else
            self.db.scale = clamp(a, 0.1, 3.0)
        end
        print(tostring(self.db.scale))
        LoadPosition(self)
    elseif cmd == "update" then
        RequestTimePlayed()
    elseif cmd == "lock" then
        self.db.locked = true
        LoadPosition(self)
    elseif cmd == "unlock" then
        self.db.locked = nil
        LoadPosition(self)
    elseif cmd == "zc" then
        SameZoneCheckAndAlert()
    else
        print('ClassTrialTimer:')
        print('  /ctt show')
        print('  /ctt hide')
        print('  /ctt reset')
        print('  /ctt lock')
        print('  /ctt unlock')
        print('  /ctt seconds on|off|secs')
        print('  /ctt alpha 0.0-1.0')
        print('  /ctt scale 0.1-3.0')
        print('  /ctt update')
    end
    return true
end

function ClassTrialTimer_OnUpdate(self, elapsed)
    self.totalElapsed = (self.totalElapsed or 0) + elapsed
    if self.totalElapsed >= 1 then
        self.totalElapsed = 0
        Update(self)
    end
end

function ClassTrialTimer_OnLoad(self)

    self:RegisterForDrag("LeftButton")

    SlashCmdList["ClassTrialTimer"] = function (...) SlashCommand(self, ...) end
    SLASH_ClassTrialTimer1 = "/ctt"

    -- Variables, and C_ClassTrial don't work in OnLoad
    self:RegisterEvent("PLAYER_LOGIN")
end

function ClassTrialTimer_OnShow(self)
    LoadPosition(self)
    self:SetScript("OnUpdate", ClassTrialTimer_OnUpdate)
end

function ClassTrialTimer_OnHide(self)
    self:SetScript("OnUpdate", nil)
end

function ClassTrialTimer_OnDragStart(self)
    self:StartMoving()
end

function ClassTrialTimer_OnDragStop(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    SavePosition(self)
end

function ClassTrialTimer_OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        ClassTrialTimerDB = ClassTrialTimerDB or { }
        self.db = ClassTrialTimerDB

        if C_ClassTrial.IsClassTrialCharacter() then
            self:RegisterEvent("TIME_PLAYED_MSG")
            self:RegisterEvent("GROUP_ROSTER_UPDATE")
            self:Show()
            RequestTimePlayed()
        end

        local name = format('%s-%s', UnitFullName("player"))
        local faction = UnitFactionGroup("player"):sub(1,1)
        self.characterName:SetText(format('%s [%s]', name, faction))

    elseif event == "TIME_PLAYED_MSG" then
        -- C_ClassTrial.GetClassTrialLogoutTimeSeconds is 0 until the trial
        -- is about to expire.
        local totalTime, levelTime = ...
        self.expireTime = time() + ClassTrialMaxSeconds() - totalTime
        Update(self)
    elseif event == "GROUP_ROSTER_UPDATE" then
        SameZoneCheckAndAlert()
    end
end
