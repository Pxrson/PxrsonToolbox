local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "Pxrson's Toolbox",
    SubTitle = "ty 4 using my toolbox. pls enjoy, " .. game.Players.LocalPlayer.Name,
    TabWidth = 140,
    Size = UDim2.fromOffset(520, 350),
    Resize = true,
    MinSize = Vector2.new(320, 220),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
}

local Tabs = {
    Main = Window:CreateTab{ Title = "Main", Icon = "house" },
    Calculator = Window:CreateTab{ Title = "Calculator", Icon = "calculator" },
    History = Window:CreateTab{ Title = "History", Icon = "clock" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "settings" }
}

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera
local UIS = game:GetService("UserInputService")
local TouchEnabled = UIS.TouchEnabled

local selectionBox = Instance.new("SelectionBox")
selectionBox.LineThickness = 0.05
selectionBox.Color3 = Color3.fromRGB(255, 50, 50)
selectionBox.Parent = workspace

local guiStroke = Instance.new("UIStroke")
guiStroke.Thickness = 3
guiStroke.Color = Color3.fromRGB(50, 255, 255)
guiStroke.Enabled = true

local partsEspOn = false
local guisEspOn = false
local currentPart = nil
local currentGui = nil
local lastGui = nil

local calcHistory = {}
local lastCalcResult = ""
local lastCalcExpr = ""

local function copyToClipboard(text)
    if setclipboard then
        setclipboard(text)
        Library:Notify{Title = "Copied", Content = text, Duration = 3}
    else
        Library:Notify{Title = "Error", Content = "Clipboard not supported.", Duration = 3}
    end
end

local function getFullPath(inst)
    local path = inst.Name
    local parent = inst.Parent
    while parent and parent ~= game do
        path = parent.Name .. "." .. path
        parent = parent.Parent
    end
    if parent == game then
        path = "game." .. path
    end
    return path
end

local function generateCodeSnippet(obj)
    if obj:IsA("GuiObject") then
        return string.format(
            [[local %s = Instance.new("%s")
%s.Position = UDim2.new(%s, %s, %s, %s)
%s.Size = UDim2.new(%s, %s, %s, %s)
%s.BackgroundColor3 = Color3.new(%s, %s, %s)
%s.Parent = game.Players.LocalPlayer.PlayerGui.%s]],
            obj.Name, obj.ClassName,
            obj.Name, obj.Position.X.Scale, obj.Position.X.Offset, obj.Position.Y.Scale, obj.Position.Y.Offset,
            obj.Name, obj.Size.X.Scale, obj.Size.X.Offset, obj.Size.Y.Scale, obj.Size.Y.Offset,
            obj.Name, obj.BackgroundColor3.R, obj.BackgroundColor3.G, obj.BackgroundColor3.B,
            obj.Name, getFullPath(obj.Parent):gsub("Players%.%w+%.PlayerGui%.", "")
        )
    else
        return string.format(
            [[local %s = Instance.new("%s")
%s.Position = Vector3.new(%s, %s, %s)
%s.Size = Vector3.new(%s, %s, %s)
%s.Material = Enum.Material.%s
%s.Parent = game.%s]],
            obj.Name, obj.ClassName,
            obj.Name, obj.Position.X, obj.Position.Y, obj.Position.Z,
            obj.Name, obj.Size.X, obj.Size.Y, obj.Size.Z,
            obj.Name, obj.Material.Name,
            obj.Name, getFullPath(obj.Parent):gsub("game%.", "")
        )
    end
end

local function showConfirm(obj)
    local info
    if obj:IsA("GuiObject") then
        info = getFullPath(obj)
    else
        info = getFullPath(obj) .. "\nPosition: " .. tostring(obj.Position)
    end
    Window:Dialog{
        Title = "Confirm Copy",
        Content = info,
        Buttons = {
            {Title = "Copy Info", Callback = function() copyToClipboard(info) end},
            {Title = "Copy Code", Callback = function() copyToClipboard(generateCodeSnippet(obj)) end},
            {Title = "Cancel", Callback = function() end}
        }
    }
end

Tabs.Main:CreateToggle("PartsESPToggle", {
    Title = "Part ESP Finder",
    Description = "Finds the parts name, and more.",
    Default = false
}):OnChanged(function()
    partsEspOn = Library.Options.PartsESPToggle.Value
    if not partsEspOn then
        currentPart = nil
        selectionBox.Adornee = nil
    end
end)

Tabs.Main:CreateToggle("GUIsESPToggle", {
    Title = "GUI Path Finder",
    Description = "Finds the GUIs path, name, and other info.",
    Default = false
}):OnChanged(function()
    guisEspOn = Library.Options.GUIsESPToggle.Value
    if not guisEspOn then
        if guiStroke.Parent then guiStroke.Parent = nil end
        currentGui = nil
        lastGui = nil
    elseif lastGui then
        guiStroke.Parent = lastGui
    end
end)

Tabs.Main:CreateButton{
    Title = "Copy Your Position",
    Description = "Copy your character's position to clipboard.",
    Callback = function()
        local char = player.Character
        if char and char.PrimaryPart then
            copyToClipboard(tostring(char.PrimaryPart.Position))
        else
            Library:Notify{Title = "Error", Content = "Character or PrimaryPart not found.", Duration = 3}
        end
    end
}

local function isGuiVisible(gui)
    return gui:IsA("GuiObject") and gui.Visible
end

local lastGuiCheck = 0

local function getInputPosition(input)
    if TouchEnabled and input.UserInputType == Enum.UserInputType.Touch then
        return input.Position
    else
        return Vector2.new(input.Position.X, input.Position.Y)
    end
end

local function getTopGuiAtPosition(x, y)
    local topGui, topZ = nil, -math.huge
    local function scan(gui)
        if gui:IsA("GuiObject") and gui.Visible then
            local absPos, absSize = gui.AbsolutePosition, gui.AbsoluteSize
            if x >= absPos.X and x <= absPos.X + absSize.X and
               y >= absPos.Y and y <= absPos.Y + absSize.Y then
                if gui.ZIndex >= topZ then
                    topGui = gui
                    topZ = gui.ZIndex
                end
            end
        end
        for _, child in ipairs(gui:GetChildren()) do
            scan(child)
        end
    end
    for _, screenGui in ipairs(player.PlayerGui:GetChildren()) do
        if screenGui:IsA("ScreenGui") and screenGui.Enabled then
            scan(screenGui)
        end
    end
    return topGui
end

UIS.InputChanged:Connect(function(input, processed)
    if processed or not camera or not player.Character or (not partsEspOn and not guisEspOn) then
        selectionBox.Adornee = nil
        if guiStroke.Parent then guiStroke.Parent = nil end
        currentPart = nil
        currentGui = nil
        lastGui = nil
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if tick() - lastGuiCheck < 0.05 then return end
        lastGuiCheck = tick()
        local mousePos = getInputPosition(input)
        if partsEspOn then
            local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {player.Character}
            params.FilterType = Enum.RaycastFilterType.Blacklist
            local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
            if result and result.Instance and result.Instance:IsA("BasePart") then
                if currentPart ~= result.Instance then
                    currentPart = result.Instance
                    selectionBox.Adornee = currentPart
                end
            else
                currentPart = nil
                selectionBox.Adornee = nil
            end
        else
            currentPart = nil
            selectionBox.Adornee = nil
        end
        if guisEspOn then
            local guiObj, highestZ = nil, -math.huge
            for _, screenGui in pairs(player.PlayerGui:GetChildren()) do
                if screenGui:IsA("ScreenGui") and screenGui.Enabled then
                    for _, gui in pairs(screenGui:GetDescendants()) do
                        if isGuiVisible(gui) then
                            local absPos, absSize = gui.AbsolutePosition, gui.AbsoluteSize
                            if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
                               mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then
                                if gui.ZIndex > highestZ then
                                    guiObj = gui
                                    highestZ = gui.ZIndex
                                end
                            end
                        end
                    end
                end
            end
            if guiObj then
                if lastGui ~= guiObj then
                    if guiStroke.Parent then guiStroke.Parent = nil end
                    guiStroke.Parent = guiObj
                    lastGui = guiObj
                end
                currentGui = guiObj
            else
                if guiStroke.Parent then guiStroke.Parent = nil end
                currentGui = nil
                lastGui = nil
            end
        else
            if guiStroke.Parent then guiStroke.Parent = nil end
            currentGui = nil
            lastGui = nil
        end
    end
end)

UIS.InputEnded:Connect(function(input, processed)
    if processed or (not partsEspOn and not guisEspOn) then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if currentGui and guisEspOn then
            showConfirm(currentGui)
        elseif currentPart and partsEspOn then
            showConfirm(currentPart)
        else
            Library:Notify{Title = "Error", Content = "No object selected.", Duration = 3}
        end
    end
end)

local function reparentVisuals()
    selectionBox.Parent = workspace
    if guiStroke.Parent and not guiStroke.Parent:IsDescendantOf(player.PlayerGui) then
        guiStroke.Parent = nil
        lastGui = nil
        currentGui = nil
    end
end

player.CharacterAdded:Connect(function()
    currentPart = nil
    currentGui = nil
    selectionBox.Adornee = nil
    if guiStroke.Parent then guiStroke.Parent = nil end
    reparentVisuals()
    task.wait(1)
end)

local calcResultParagraph = Tabs.Calculator:CreateParagraph("CalcResult", {
    Title = "Result",
    Content = "Result: "
})

local calcInputBox = Tabs.Calculator:CreateInput("CalcInput", {
    Title = "Expression",
    Placeholder = "e.g. 2+2*5",
    Default = "",
    Numeric = false,
    Finished = false,
    Callback = function(Value)
        lastCalcExpr = Value
        if Value == "" then
            calcResultParagraph:SetValue("Result: (empty)")
            return
        end
        local allowed = "0123456789.+-*/()%%^ "
        for i = 1, #Value do
            if not allowed:find(Value:sub(i,i), 1, true) then
                calcResultParagraph:SetValue("Result: Invalid character")
                return
            end
        end
        local expr = Value:gsub("%%", "%%")
        local f, err = loadstring("return " .. expr)
        if not f then
            calcResultParagraph:SetValue("Result: Syntax error")
            return
        end
        local ok, res = pcall(f)
        if not ok then
            calcResultParagraph:SetValue("Result: Math error")
            return
        end
        lastCalcResult = tostring(res)
        calcResultParagraph:SetValue("Result: " .. lastCalcResult)
    end
})

Tabs.Calculator:CreateButton{
    Title = "Copy Result",
    Description = "Copy the last result to clipboard.",
    Callback = function()
        if lastCalcResult and lastCalcResult ~= "" then
            setclipboard(lastCalcResult)
            Library:Notify{Title = "Copied", Content = lastCalcResult, Duration = 3}
        end
    end
}

Tabs.Calculator:CreateButton{
    Title = "Add To History",
    Description = "Add this calculation to history.",
    Callback = function()
        if lastCalcExpr ~= "" and lastCalcResult ~= "" then
            table.insert(calcHistory, 1, lastCalcExpr .. " = " .. lastCalcResult)
            if #calcHistory > 50 then table.remove(calcHistory) end
            Library:Notify{Title = "Added", Content = "Added to history!", Duration = 2}
        end
    end
}

local historyParagraph = Tabs.History:CreateParagraph("CalcHistoryParagraph", {
    Title = "Calculator History",
    Content = ""
})

Tabs.Calculator:CreateButton{
    Title = "Show History",
    Description = "Show calculation history.",
    Callback = function()
        local text = ""
        for i, v in ipairs(calcHistory) do
            text = text .. v .. "\n"
        end
        historyParagraph:SetValue(text)
        Window:SelectTab(Tabs.History)
    end
}

Tabs.History:CreateButton{
    Title = "Clear History",
    Description = "Clear all calculator history.",
    Callback = function()
        calcHistory = {}
        historyParagraph:SetValue("")
    end
}

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
Window:SelectTab(1)

Library:Notify{
    Title = "Toolbox",
    Content = "The script has loaded, enjoy!",
    Duration = 8
}
