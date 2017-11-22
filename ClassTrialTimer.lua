--[[----------------------------------------------------------------------------

  ClassTrialTimer - World of Warcraft AddOn

  Copyright 2017 Mike Battersby

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

local function Update(self)
    if not self.expireTime then return end

    local remainingTime = self.expireTime - time()
    local h = floor((remainingTime % 86400) / 3600)
    local m = floor((remainingTime % 3600) / 60)
    local s = remainingTime % 60
    local string = format('%02d:%02d', h, m)
    self.remainingTime:SetText(string)

    if remainingTime < 15 * 60 then
        self.remainingTime:SetTextColor(1, 1, 0.5, 0.7)
    else
        self.remainingTime:SetTextColor(0.5, 1, 0.5, 0.7)
    end
end

local function SlashCommand(argstr)
    local args = { strsplit(" ", argstr) }
    local cmd = table.remove(args, 1)

    if cmd == "hide" then
        ClassTrialTimer:Hide()
    elseif cmd == "show" then
        ClassTrialTimer:Show()
    else
        RequestTimePlayed()
    end
end

function ClassTrialTimer_OnUpdate(self, elapsed)
    self.totalElapsed = (self.totalElapsed or 0) + elapsed
    if self.totalElapsed >= 1 then
        self.totalElapsed = 0
        Update(self)
    end
end

function ClassTrialTimer_OnLoad(self)
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    self.characterName:SetText(format('%s-%s', name, realm))

    self:RegisterForDrag("LeftButton")

    SlashCmdList["ClassTrialTimer"] = SlashCommand
    SLASH_ClassTrialTimer1 = "/classtrialtimer"
    SLASH_ClassTrialTimer2 = "/ctt"

    -- How to detect trial account?
    if UnitLevel("player") == 100 then
        self:RegisterEvent("TIME_PLAYED_MSG")
        RequestTimePlayed()
    end
end

function ClassTrialTimer_OnShow(self)
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
    -- self:SetUserPlaced(false)
    -- ClassTrialTimer_SavePosition(self)
end

function ClassTrialTimer_OnEvent(self, event, ...)
    if event == "TIME_PLAYED_MSG" then
        local totalTime, levelTime = ...
        if totalTime < 8 * 60 * 60 then
            self.expireTime = time() + (8 * 60 * 60) - totalTime
            Update(self)
            self:Show()
        else
            self:Hide()
        end
    end
end
