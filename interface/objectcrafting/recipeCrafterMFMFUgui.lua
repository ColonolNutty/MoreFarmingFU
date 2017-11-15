function onOutputItemTaken(widgetName)
  world.sendEntityMessage(pane.containerEntityId(), "onOutputItemTaken", widgetName)
end

function onOutputItemPartiallyTaken(widgetName)
  world.sendEntityMessage(pane.containerEntityId(), "onOutputItemPartiallyTaken", widgetName)
end