require "/scripts/debugUtilsCN.lua"
require "/scripts/recipeCrafterAPI.lua"
require "/scripts/MFM/recipeLocatorAPI.lua"

local rcUtilsFU = {};
local logger = nil;

function init(virtual)
  logger = DebugUtilsCN.init("[RCFU]")
  RecipeCrafterMFMApi.init(virtual);
  RecipeLocatorAPI.init(virtual);
  
  ----- Configuration -----
  logger.setDebugState(false);
  if(storage.autoCraftState == nil) then
    storage.autoCraftState = false;
  end
  rcUtilsFU.updateCraftSettings();
  -------------------------
  message.setHandler("setAutoCraftState", rcUtilsFU.setAutoCraftState);
  message.setHandler("getAutoCraftState", rcUtilsFU.getAutoCraftState);
end

function update(dt)
  RecipeCrafterMFMApi.update(dt)
  if(not RecipeCrafterMFMApi.containerContentsChanged or not getAutoCraftState()) then
    return
  end
  if(storage.currentlySelectedRecipe ~= nil and rcUtilsFU.isOutputSlotModified()) then
    rcUtilsFU.consumeIngredients()
    storage.currentlySelectedRecipe = nil;
  elseif(storage.currentlySelectedRecipe ~= nil and rcUtilsFU.shouldRemoveOutput()) then
    rcUtilsFU.removeOutput()
    storage.currentlySelectedRecipe = nil;
  elseif(getAutoCraftState()) then
    RecipeCrafterMFMApi.craftItem()
  end
end

function die()
  if(getAutoCraftState()) then
    rcUtilsFU.removeOutput()
  end
  RecipeCrafterMFMApi.die()
end

-------------------------------Callback Hooks------------------------------------

function RecipeCrafterMFMApi.isOutputSlotAvailable()
  if(not getAutoCraftState()) then
    return RecipeCrafterMFMApi.isOutputSlotAvailableBase()
  end
  local outputSlotItem = world.containerItemAt(entity.id(), storage.outputSlot)
  -- Output slot is empty
  if(outputSlotItem == nil) then
    logger.logDebug("No output item detected in output slot, it is available")
    return true;
  end
  
  local currentlySelectedRecipe = storage.currentlySelectedRecipe;
  
  -- If there is no currentlySelectedRecipe, but there is an output item
  -- If the output slot item has been modified
  if(currentlySelectedRecipe == nil) then
    logger.logDebug("No previous recipe, but an output item exists")
    return false;
  end
  
  local currentIngredients = RecipeCrafterMFMApi.getIngredients();
  -- When the ingredients change
  
  -- Check current ingredients to verify the previous recipe still has the required ingredients
  local hasRequiredIngredients = RecipeLocatorAPI.hasIngredientsForRecipe(currentlySelectedRecipe, currentIngredients);
  if(not hasRequiredIngredients) then
    logger.logDebug("Required ingredients missing for current recipe.")
    return true;
  end
  
  return not rcUtilsFU.isOutputSlotModified();
end

function RecipeCrafterMFMApi.onNoRecipeFound()
  if(not getAutoCraftState()) then
    return RecipeCrafterMFMApi.onNoRecipeFoundBase()
  end
  rcUtilsFU.removeOutput();
  storage.currentlySelectedRecipe = nil;
end

-------------------------------------------------------------------

function rcUtilsFU.updateCraftSettings()
  if(getAutoCraftState()) then
    storage.consumeIngredientsOnCraft = false;
    storage.holdIngredientsOnCraft = false;
    storage.playSoundBeforeOutputPlaced = false;
    storage.appendNewOutputToCurrentOutput = false;
  else
    storage.consumeIngredientsOnCraft = true;
    storage.holdIngredientsOnCraft = true;
    storage.playSoundBeforeOutputPlaced = true;
    storage.appendNewOutputToCurrentOutput = true;
  end
end

function getAutoCraftState()
  return rcUtilsFU.getAutoCraftState().autoCraftState
end

function rcUtilsFU.getAutoCraftState()
  if(not storage or not storage.autoCraftState) then
    if (storage) then
      storage.autoCraftState = false;
    end
    return {
      autoCraftState = false
    }
  end
  return {
    autoCraftState = storage.autoCraftState
  }
end

function rcUtilsFU.setAutoCraftState(id, name, newValue)
  if (storage.autoCraftState ~= newValue) then
    if (newValue) then
      storage.currentlySelectedRecipe = nil;
    else
      rcUtilsFU.consumeIngredients()
      storage.currentlySelectedRecipe = nil;
    end
  end
  storage.autoCraftState = newValue or false;
  rcUtilsFU.updateCraftSettings()
end

function rcUtilsFU.isOutputSlotModified()
  local outputSlotItem = world.containerItemAt(entity.id(), storage.outputSlot)
  
  local currentlySelectedRecipe = storage.currentlySelectedRecipe;
  -- If no previous recipe exists, then we haven't crafted yet
  -- If we haven't crafted and there is an output slot item, then it is modified
  -- If we haven't crafted and there is no output slot item, then it is not modified
  if(currentlySelectedRecipe == nil or currentlySelectedRecipe.output == nil) then
    return outputSlotItem ~= nil;
  end
  
  -- Output slot is empty, so it must be modified
  if(outputSlotItem == nil) then
    logger.logDebug("Expected item in output slot, but no item was found.");
    return true;
  end
  
  local previousOutput = currentlySelectedRecipe.output;
  
  if(outputSlotItem.name ~= previousOutput.name) then
    logger.logDebug("Item name in the output slot differs; Expected name: " .. previousOutput.name .. " Actual name: " .. outputSlotItem.name);
    return true;
  end
  
  if(outputSlotItem.count ~= previousOutput.count) then
    logger.logDebug("Item count in the output slot differs; Expected count: " .. previousOutput.count .. " Actual count: " .. outputSlotItem.count);
    return true;
  end
  
  logger.logDebug("Output slot has not been modified.");
  return false;
end

function rcUtilsFU.consumeIngredients()
  if(storage.currentlySelectedRecipe == nil) then
    return;
  end
  RecipeCrafterMFMApi.playCraftSound()
  RecipeCrafterMFMApi.holdIngredients(storage.currentlySelectedRecipe)
  RecipeCrafterMFMApi.consumeIngredients()
end

function rcUtilsFU.shouldRemoveOutput()
  if(storage.currentlySelectedRecipe == nil) then
    return false;
  end
  local currentIngredients = RecipeCrafterMFMApi.getIngredients();
  return not RecipeLocatorAPI.hasIngredientsForRecipe(storage.currentlySelectedRecipe, currentIngredients);
end

function rcUtilsFU.removeOutput()
  world.containerTakeAt(entity.id(), storage.outputSlot);
  storage.currentlySelectedRecipe = nil
end

function rcUtilsFU.releaseOutput()
  if(not rcUtilsFU.isOutputSlotModified()) then
    logger.logDebug("Output slot not modified, not releasing output")
    -- If not modified, then the output slot must be something the script put in, so remove it.
    rcUtilsFU.removeOutput()
    return true;
  end
end

function die()
  RecipeCrafterMFMApi.die()
  rcUtilsFU.releaseOutput()
end