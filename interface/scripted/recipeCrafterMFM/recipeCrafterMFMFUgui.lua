require "/scripts/MFM/entityQueryAPI.lua"
require "/interface/scripted/recipeCrafterMFM/recipeCrafterMFMgui.lua"

local autoCraftStateUpdated = false;
local entityId = nil;
local settings = {
  autoCraftState = false
};

TOGGLE_AUTOCRAFT_NAME = "toggleAutoCraft";

function init()
  EntityQueryAPI.init()
  entityId = pane.containerEntityId()
  autoCraftStateUpdated = false;
  RecipeCrafterMFMGui.init()
  hideCraftButtonIfAutoCraftEnabled()
end

function update(dt)
  updateAutoCraftState()
  RecipeCrafterMFMGui.update(dt)
end

---------------------------------------------------------------------

function getAutoCraftState()
  if(storage) then
    return storage.autoCraftState
  else
    return settings.autoCraftState
  end
end

function setAutoCraftState(val)
  if(storage) then
    storage.autoCraftState = toEnable
  else
    settings.autoCraftState = toEnable
  end
  hideCraftButtonIfAutoCraftEnabled()
end

function toggleAutoCraft()
  if(entityId == nil) then
    return
  end
  local toEnable = widget.getChecked(TOGGLE_AUTOCRAFT_NAME)
  setAutoCraftState(toEnable)
  hideCraftButtonIfAutoCraftEnabled()
  world.sendEntityMessage(entityId, "setAutoCraftState", toEnable)
end

function hideCraftButtonIfAutoCraftEnabled()
  if(getAutoCraftState()) then
    widget.setVisible("craft", false)
  else
    widget.setVisible("craft", true)
  end
end

function updateAutoCraftState()
  if(autoCraftStateUpdated) then
    return
  end
  local handle = function()
    local result = EntityQueryAPI.requestData(entityId, "getAutoCraftState", 0, nil)
    if(result ~= nil) then
      return true, result
    end
    return false, nil
  end
  
  local onCompleted = function(result)
    local autoCraftState = result.autoCraftState
    setAutoCraftState(autoCraftState)
    hideCraftButtonIfAutoCraftEnabled()
    widget.setChecked(TOGGLE_AUTOCRAFT_NAME, autoCraftState)
    autoCraftStateUpdated = true
  end
  
  EntityQueryAPI.addRequest("RGMFMFUGui.updateAutoCraftState", handle, onCompleted)
end