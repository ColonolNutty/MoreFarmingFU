require "/scripts/debugUtilsCN.lua"
require "/scripts/recipeCrafterAPI.lua"

local rcUtilsFU = {};

function init(virtual)
  RecipeCrafterMFMApi.init("[RCFU]")
  
  if(storage.outputPlaceSuccessfully == nil) then
    storage.outputPlacedSuccessfully = false
  end
  
  storage.consumeIngredientsOnCraft = false
  storage.noHold = true
  storage.playOnCraftBeforeOutputPlaced = false
  storage.appendToOutput = false
end

function update(dt)
  RecipeCrafterMFMApi.update(dt)
end

function die()
  rcUtilsFU.removeOutput()
  RecipeCrafterMFMApi.die()
end

-------------------------------Callback Hooks------------------------------------

function RecipeCrafterMFMApi.onIngredientsChanged()
  local outputFullyConsumed = rcUtilsFU.consumeIngredientsIfOutputTaken()
  if(not outputFullyConsumed) then
    return
  end
  storage.ingredientsConsumed = false
  local ingredients = RecipeCrafterMFMApi.getIngredients()
  if ingredients == nil then
    DebugUtilsCN.logDebug("No Ingredients")
    storage.expectOutputChange = false
    return
  end
  
  if not rcUtilsFU.currentRecipeIsValid(storage.previousRecipe, ingredients) then
    DebugUtilsCN.logDebug("Removing Output")
    storage.expectOutputChange = true
    rcUtilsFU.removeOutput()
  end
  
  RecipeCrafterMFMApi.startCrafting(ingredients)
end

function RecipeCrafterMFMApi.onNoRecipeFound()
  storage.expectOutputChange = true
  rcUtilsFU.removeOutput()
end

function RecipeCrafterMFMApi.shouldLookForRecipeCallback(previousOutput, outputSlotItem)
  return previousOutput.name ~= outputSlotItem.name or previousOutput.count ~= outputSlotItem.count
end

-------------------------------------------------------------------

function rcUtilsFU.consumeIngredientsIfOutputTaken()
  if storage.previousRecipe == nil or not storage.outputPlacedSuccessfully then
    return true
  end
  local outputSlotItem = world.containerItemAt(entity.id(), storage.outputSlot)
  local recipeOutput = storage.previousRecipe.output
  -- Output item taken
  if (outputSlotItem == nil or outputSlotItem.name ~= recipeOutput.name) then
    if(storage.ingredientsConsumed) then
      return true
    end
    DebugUtilsCN.logDebug("Output item fully taken, consuming")
    rcUtilsFU.consumeIngredients()
    storage.previousRecipe = nil
    storage.outputPlacedSuccessfully = false
    return true
  end
  
  -- Output item partially taken
  if(outputSlotItem.count < recipeOutput.count) then
    if(storage.ingredientsConsumed) then
      return false
    end
    DebugUtilsCN.logDebug("Output item partially taken, consuming")
    rcUtilsFU.consumeIngredients()
    return false
  end
  
  -- Output item hasn't been touched, so leave it alone
  if(outputSlotItem.count == recipeOutput.count) then
    if(storage.ingredientsConsumed) then
      return false
    end
    DebugUtilsCN.logDebug("Output item not taken")
    return false
  end
  return true
end

function rcUtilsFU.consumeIngredients()
  storage.expectOutputChange = true
  storage.ingredientsConsumed = true
  DebugUtilsCN.logDebug("Consuming ingredients for recipe with output: " .. storage.previousRecipe.output.name)
  RecipeCrafterMFMApi.onCraft()
  RecipeCrafterMFMApi.holdIngredients(storage.previousRecipe)
  RecipeCrafterMFMApi.consumeIngredients();
end

function rcUtilsFU.removeOutput()
  -- Find existing output
  local outputSlotItem = world.containerItemAt(entity.id(), storage.outputSlot)
  if not outputSlotItem then
    storage.previousRecipe = nil
    storage.outputPlacedSuccessfully = false
    isExpectingOutputChange = true
    return
  end
  
  if storage.previousRecipe then
    local outputItem = storage.previousRecipe.output
    -- If the item in the output is the same as the one we placed
    -- then we remove the amount we placed and spit the rest out of the machine
    if outputSlotItem.name == outputItem.name then
      isExpectingOutputChange = true
      world.containerConsumeAt(entity.id(), storage.outputSlot, outputItem.count)
    end
  end
  -- If output still exists, we ignore it and prevent adding new output
  storage.previousRecipe = nil
  storage.outputPlacedSuccessfully = false
  isExpectingOutputChange = false
end

function rcUtilsFU.currentRecipeIsValid(recipe, ingredients)
  if recipe == nil or ingredients == nil then
    return false
  end
  return RecipeCrafterMFMApi.checkIngredientsMatchRecipe(recipe, ingredients)
end