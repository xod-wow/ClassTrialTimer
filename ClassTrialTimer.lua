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

    -- How to detect trial account?
    if UnitLevel("player") == 100 then
        self:RegisterEvent("TIME_PLAYED_MSG")
        RequestTimePlayed()
    end
end

function ClassTrialTimer_OnEvent(self, event, ...)
    if event == "TIME_PLAYED_MSG" then
        local totalTime, levelTime = ...
        if totalTime < 8 * 60 * 60 then
            self.expireTime = time() + (8 * 60 * 60) - totalTime
            Update(self)
            self:Show()
            self:SetScript("OnUpdate", ClassTrialTimer_OnUpdate)
        else
            self:Hide()
            self:SetScript("OnUpdate", nil)
        end
    end
end
