local mousePos = Cheat.GetMousePos();
local windowSize = EngineClient.GetScreenSize();
local window = { x = 20, y = 20, w = 300, h = 125, down = false, downX = 0, downY = 0 };
local velocityTable = { savedRealTime = GlobalVars.realtime, velocityGraph = {}, highestValue = 0, newHighestValue = 0 };

--[[
    Input Library
--]]

local keySystem = {};
keySystem.__index = keySystem;

keys = {};

local function newKey(key)
    if (type(key) ~= "number") then key = 0x01; end

    return setmetatable({ key = key, down = false, pressed = { pressed = false, x = 0, y = 0 }, released = { released = false, x = 0, y = 0 } }, keySystem);
end

function keySystem.addKey(key)
    local contains = false;
    for i = 1, #keys do
        if (keys[i].key == key.key) then
            contains = true;
        end
    end

    if (not contains) then
        table.insert(keys, key);
    end
end

function keySystem.removeKey(key)
    if (#keys > 0) then
        for i = 1, #keys do
            if (keys[i].key == key) then
                table.remove(keys, i);
                return;
            end
        end
    end
end

function keySystem.getKey(key)
    if (#keys > 0) then
        for i = 1, #keys do
            if (keys[i].key == key) then
                return keys[i];
            end
        end
    end
end

function keySystem.run()
    if (#keys > 0) then
        for i = 1, #keys do
            if (Cheat.IsKeyDown(keys[i].key)) then
                if (keys[i].down == false) then
                    keys[i].down = true;
                    keys[i].pressed = { pressed = true, x = mousePos.x, y = mousePos.y };
                else
                    keys[i].pressed.pressed = false;
                end
            else
                if (keys[i].down == true) then
                    keys[i].down, keys[i].pressed.pressed, keys[i].released = false, false, { released = true, x = mousePos.x, y = mousePos.y };
                else
                    keys[i].released.released = false;
                end
            end
        end
    end
end

--[[
    GUI Items
--]]

local velocityEnable = Menu.Switch("Velocity", "Enabled", true);
local velocityColor = Menu.ColorEdit("Velocity", "Line Color", Color.new(1.0, 1.0, 1.0, 1.0));
local velocityUpdate = Menu.SliderInt("Velocity", "Update Time (ms)", 20, 0, 500);

local xSlider = Menu.SliderInt("Position", "X Axis", 50, 0, windowSize.x, "", function(value) window.x = value; end);
local ySlider = Menu.SliderInt("Position", "Y Axis", 50, 0, windowSize.y, "", function(value) window.y = value; end);

local wSlider = Menu.SliderInt("Size", "Width", 300, 0, 800, "", function(value) window.w = value; end);
local hSlider = Menu.SliderInt("Size", "Height", 125, 0, 500, "", function(value) window.h = value; end);

--[[
    Callbacks
--]]

keySystem.addKey(newKey(0x01));

cheat.RegisterCallback("draw", function()
    local localPlayer = EntityList.GetLocalPlayer();

    if (localPlayer ~= nil and EngineClient.IsInGame() and velocityEnable:Get()) then
        keySystem.run();
        
        local mouseKey = keySystem.getKey(0x01);
        mousePos = Cheat.GetMousePos();

        if (mouseKey.pressed.pressed) then
            if (mouseKey.pressed.x >= window.x and mouseKey.pressed.x <= window.x + window.w) then
                if (mouseKey.pressed.y >= window.y and mouseKey.pressed.y <= window.y + window.h) then
                    window.down, window.downX, window.downY = true, mouseKey.pressed.x - window.x, mouseKey.pressed.y - window.y;
                end
            end
        end

        if (mouseKey.down) then
            if (window.down) then
                window.x, window.y = mousePos.x - window.downX, mousePos.y - window.downY;
            end
        else
            if (window.down) then
                xSlider:Set(window.x);
                ySlider:Set(window.y);
            end

            window.down = false;
        end

        Render.Blur(Vector2.new(window.x, window.y), Vector2.new(window.x + window.w, window.y + window.h), Color.new(1.0, 1.0, 1.0, 1.0), 5.0);

        local velocity = math.floor(localPlayer:GetProp("m_vecVelocity"):Length2D());
        local velText = tostring(velocity) .. " m/s";
        local textSize = Render.CalcTextSize(velText, 12)

        if (velocity > velocityTable.highestValue) then
            velocityTable.highestValue = velocity;
        end

        -- Manual Center bc we don't fuck w/ making custom fonts
        Render.Text(velText, Vector2.new(window.x + (window.w / 2) - (textSize.x / 2), window.y + window.h - textSize.y - 4), Color.new(0.85, 0.85, 0.85, 1.0), 12);

        Render.BoxFilled(Vector2.new(window.x, window.y + 5), Vector2.new(window.x + window.w, window.y + window.h - 8 - textSize.y), Color.new(0.08, 0.08, 0.08, 0.5));
        Render.Box(Vector2.new(window.x, window.y), Vector2.new(window.x + window.w, window.y + window.h), Color.new(0.2, 0.2, 0.2, 1.0), 5);

        if (GlobalVars.realtime - velocityTable.savedRealTime >= velocityUpdate:Get() / 1000) then
            velocityTable.savedRealTime = GlobalVars.realtime;

            -- Codenz go here
            local highest = false;
            if (#velocityTable.velocityGraph >= 36) then if (velocityTable.velocityGraph[1] == velocityTable.highestValue) then highest = true; end table.remove(velocityTable.velocityGraph, 1); end
            table.insert(velocityTable.velocityGraph, velocityTable.newHighestValue);

            if (highest) then
                velocityTable.highestValue = 0;
                for i = 1, #velocityTable.velocityGraph do
                    if (velocityTable.velocityGraph[i] > velocityTable.highestValue) then
                        velocityTable.highestValue = velocityTable.velocityGraph[i];
                    end
                end
            end
            
            velocityTable.newHighestValue = 0;
        else
            if (velocity > velocityTable.newHighestValue) then
                velocityTable.newHighestValue = velocity;
            end
        end

        if (#velocityTable.velocityGraph > 0) then
            local boxHeight = (window.y + window.h - 8 - textSize.y) - (window.y + 5);
            local lineWidth = window.w / (#velocityTable.velocityGraph - 1);

            local posTable = {};
            for i = 1, #velocityTable.velocityGraph do
                local lineHeight = boxHeight * (velocityTable.velocityGraph[i] / velocityTable.highestValue);

                table.insert(posTable, Vector2.new(window.x + (lineWidth * (i - 1)), window.y + 5 + (boxHeight - lineHeight)));
            end

            if (#posTable > 1) then
                for i = 1, #posTable do
                    if (i ~= 1) then
                        Render.Line(posTable[i], posTable[i - 1], velocityColor:Get());
                    end
                end
            end
        end
    end
end);
