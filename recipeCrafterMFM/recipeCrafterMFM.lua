require "/scripts/debugUtilsCN.lua"
require "/scripts/recipeCrafterAPI.lua"

local rcUtilsFU = {};
local logger = nil;

function init(virtual)
  logger = DebugUtilsCN.init("[RCFU]")
  RecipeCrafterMFMApi.init()
  
  storage.consumeIngredientsOnCraft = false;
  storage.noHold = true;
  storage.playSoundBeforeOutputPlaced = false;
  storage.appendNewOutputToCurrentOutput = false;
  
  if(storage.outputSlotModified == nil) then
    storage.outputSlotModified = false;
  end
  
  -- This is to prevent receiving free items when loading the game with an output available but not taken
  -- The downside is, if someone is storing items in the output slot, they will lose them on loading their game. (A small sacrifice to prevent cheating)
  world.containerTakeAt(entity.id(), storage.outputSlot);
end

function update(dt)
  RecipeCrafterMFMApi.update(dt)
end

function die()
  rcUtilsFU.removeOutput()
  RecipeCrafterMFMApi.die()
end

-------------------------------Callback Hooks------------------------------------

-- Returns TRUE if
--   No output slot item
--   Required ingredients still exist
--   The output slot has not been modified
-- Returns FALSE if
--   Output slot is modified
--   There is no previous recipe
function RecipeCrafterMFMApi.isOutputSlotAvailable()
  local outputSlotItem = world.containerItemAt(entity.id(), storage.outputSlot)
  -- Output slot is empty
  if(outputSlotItem == nil) then
    if(storage.previousRecipe ~= nil and storage.previousRecipe.output ~= nil and not storage.outputSlotModified) then
      logger.logDebug("Output item taken, consuming ingredients for recipe with output: " .. storage.previousRecipe.output.name)
      rcUtilsFU.consumeIngredients()
    end
    logger.logDebug("No output item detected in output slot")
    return true;
  end
  
  local previousRecipe = storage.previousRecipe;
  
  -- If there is no previousRecipe, but there is an output item or if the output slot item has been modified
  if(previousRecipe == nil or storage.outputSlotModified) then
    logger.logDebug("No previous recipe, and output slot was modified.")
    return false;
  end
  
  -- When the ingredients change
  
  -- Check current ingredients to verify the previous recipe still has the required ingredients
  local hasRequiredIngredients = RecipeCrafterMFMApi.hasIngredientsForRecipe(previousRecipe, storage.currentIngredients);
  if(not hasRequiredIngredients) then
    logger.logDebug("Required ingredients missing for current recipe.")
    return true;
  end

  local previousOutput = previousRecipe.output;
  
  if(previousOutput == nil) then
    storage.previousRecipe = nil;
    logger.logDebug("No previous output, and output slot was modified.")
    return false;
  end
  
  -- When the output slot item changes
  
  -- Output item is different than the previous recipe result
  if(outputSlotItem.name ~= previousOutput.name) then
    storage.outputSlotModified = true;
    logger.logDebug("Output item changed, consuming ingredients for recipe with output: " .. previousOutput.name)
    rcUtilsFU.consumeIngredients()
    return false;
  end
  
  -- Output item has the same name as the previous recipe result
  if(outputSlotItem.name == previousOutput.name) then
    -- Output item has the same count as the previous recipe result
    if(outputSlotItem.count ~= previousOutput.count) then
      storage.outputSlotModified = true;
      logger.logDebug("Consuming ingredients for recipe with output: " .. previousOutput.name)
      rcUtilsFU.consumeIngredients()
      return false;
    else
      logger.logDebug("Output slot item not taken, but modified")
      return not storage.outputSlotModified;
    end
  end
end

function RecipeCrafterMFMApi.onCraftStart()
  storage.outputSlotModified = false;
end

function RecipeCrafterMFMApi.onContainerContentsChanged()
  RecipeCrafterMFMApi.craftItem()
end

function RecipeCrafterMFMApi.onRecipeFound()
end

function RecipeCrafterMFMApi.onNoIngredientsFound()
  rcUtilsFU.removeOutput();
end

function RecipeCrafterMFMApi.onNoRecipeFound()
  rcUtilsFU.removeOutput()
end

-------------------------------------------------------------------

function rcUtilsFU.consumeIngredients()
  if(storage.previousRecipe == nil) then
    return;
  end
  RecipeCrafterMFMApi.playCraftSound()
  RecipeCrafterMFMApi.holdIngredients(storage.previousRecipe)
  RecipeCrafterMFMApi.consumeIngredients()
end

function rcUtilsFU.removeOutput()
  if(storage.outputSlotModified) then
    return;
  end
  
  --logger.logDebug("Removing output item from slot: " .. storage.outputSlot)
  
  -- The output item is one we placed, so remove it
  world.containerTakeAt(entity.id(), storage.outputSlot);
  
  storage.previousRecipe = nil;
  storage.outputSlotModified = false;
end

function rcUtilsFU.releaseOutput()
  if(not storage.outputSlotModified) then
    return
  end
  
  local containerId = entity.id()
  local outputSlotItem = world.containerItemAt(containerId, storage.outputSlot)
  -- Output slot is empty
  if(outputSlotItem == nil) then
    logger.logDebug("No output item")
    return true;
  end
  
  logger.logDebug("Releasing output item with name: " .. outputSlotItem.name .. " and count: " .. outputSlotItem.count)
  local toExpel = world.containerAddItems(containerId, outputSlotItem)
  RecipeCrafterMFMApi.expelItems(toExpel)
end

function die()
  RecipeCrafterMFMApi.die()
  rcUtilsFU.releaseOutput()
end