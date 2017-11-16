require "/scripts/debugUtilsCN.lua"
require "/scripts/recipeCrafterAPI.lua"

local rcUtilsFU = {};

function init(virtual)
  RecipeCrafterMFMApi.init("[RCFU]")
  
  if(storage.outputSlotModified == nil) then
    storage.outputSlotModified = false;
  end
  
  storage.consumeIngredientsOnCraft = false;
  storage.noHold = true;
  storage.playSoundBeforeOutputPlaced = false;
  storage.appendNewOutputToCurrentOutput = false;
  
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

function RecipeCrafterMFMApi.beforeCraftStart()
  storage.outputSlotModified = false;
end

function RecipeCrafterMFMApi.onContainerContentsChanged()
  RecipeCrafterMFMApi.craftItem()
end

function RecipeCrafterMFMApi.onNoRecipeFound()
  rcUtilsFU.removeOutput()
end

-------------------------------------------------------------------

-- Returns true if no output slot item, if required ingredients still exist, or if the output slot has not been modified
-- Returns false if output slot is modified or if there is no previous recipe
function RecipeCrafterMFMApi.isOutputSlotAvailable()
  local outputSlotItem = world.containerItemAt(entity.id(), storage.outputSlot)
  -- Output slot is empty
  if(outputSlotItem == nil) then
    DebugUtilsCN.logDebug("No output item")
    if(storage.previousRecipe ~= nil and not storage.outputSlotModified) then
      DebugUtilsCN.logDebug("Output item taken, consuming ingredients for recipe with output: " .. storage.previousRecipe.output.name)
      rcUtilsFU.consumeIngredients()
    end
    return true;
  end
  
  local previousRecipe = storage.previousRecipe;
  
  -- If there is no previousRecipe, but there is an output item or if the output slot item has been modified
  if(previousRecipe == nil or storage.outputSlotModified) then
    return false;
  end
  
  -- When the ingredients change
  
  -- Check current ingredients to verify the previous recipe still has the required ingredients
  local hasRequiredIngredients = RecipeCrafterMFMApi.hasIngredientsForRecipe(previousRecipe, storage.currentIngredients);
  if(not hasRequiredIngredients) then
    return true;
  end

  local previousOutput = previousRecipe.output;
  
  -- When the output slot item changes
  
  -- Output item is different than the previous recipe result
  if(outputSlotItem.name ~= previousOutput.name) then
    storage.outputSlotModified = true;
    DebugUtilsCN.logDebug("Output item changed, consuming ingredients for recipe with output: " .. previousOutput.name)
    rcUtilsFU.consumeIngredients()
    return false;
  end
  
  -- Output item has the same name as the previous recipe result
  if(outputSlotItem.name == previousOutput.name) then
    -- Output item has the same count as the previous recipe result
    if(outputSlotItem.count ~= previousOutput.count) then
      storage.outputSlotModified = true;
      DebugUtilsCN.logDebug("Consuming ingredients for recipe with output: " .. previousOutput.name)
      rcUtilsFU.consumeIngredients()
      return false;
    else
      return not storage.outputSlotModified;
    end
  end
end

function rcUtilsFU.consumeIngredients()
  if(storage.previousRecipe == nil) then
    return;
  end
  RecipeCrafterMFMApi.onCraft()
  RecipeCrafterMFMApi.holdIngredients(storage.previousRecipe)
  RecipeCrafterMFMApi.consumeIngredients()
end

function rcUtilsFU.removeOutput()
  if(storage.outputSlotModified) then
    return;
  end
  
  -- The output item is one we placed, so remove it
  world.containerTakeAt(entity.id(), storage.outputSlot);
  
  -- If output still exists, we ignore it and prevent adding new output
  rcUtilsFU.resetForNewRecipe()
end

function rcUtilsFU.shouldRemoveCurrentOutput(recipe, ingredients)
  if recipe == nil or ingredients == nil then
    return true
  end
  return not RecipeCrafterMFMApi.hasIngredientsForRecipe(recipe, ingredients)
end

function rcUtilsFU.resetForNewRecipe()
  storage.previousRecipe = nil;
  storage.outputSlotModified = false;
end