local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage.Events

local LocalPlayer = Players.LocalPlayer

local Obbies = Workspace.Obbies
local Obby = Obbies[LocalPlayer.Name]
local Zone = Obby.GatePos.Value
local Items = Obby.Items
local Parts = Items.Parts

local Origin = Zone * CFrame.new(0, -3, -250)

local Events = {
	Move = Events.MoveObject,
	Edit = Events.PaintObject,
	Build = Events.AddObject,
	Delete = Events.DeleteObject,
	SetEditing = Events.SetEditing,
	Selection = Events.ChangeCurrentSelection
}

local function Move(Block, CFrame, Size)
	Events.Move:InvokeServer({{Block, CFrame, Size}})
end

local function Property(Property)
	return function(Block, Data)
		Events.Edit:InvokeServer({Block}, Property, Data)
	end
end

local Edit = {
    ["Size"] = function(Block, Size)
        Move(Block, Block.CFrame, Size)
    end,
    ["Position"] = function(Block, Position)
    	Move(Block, CFrame.new(Position) * (Block.Object.CFrame - Block.Object.CFrame.p), Block.Size)
    end,
    ["Orientation"] = function(Block, Orientation)
    	Move(Block, CFrame.new(Block.Object.Position) * CFrame.Angles(math.rad(Orientation.x), math.rad(Orientation.y), math.rad(Orientation.z)), Block.Size)
    end,
    ["CFrame"] = function(Block, CFrame)
    	Move(Block, CFrame, Block.Size)
    end,
    ["Color"] = Property("Color"),
    ["Transparency"] = Property("Transparency"),
    ["CanCollide"] = Property("CanCollide"),
    ["CastShadow"] = Property("CastShadow"),
    ["Material"] = Property("Material"),
    ["Reflectance"] = Property("Reflectance"),
    ["Transparency"] = Property("Transparency"),
    ["Surface"] = Property("Surface"),
    ["Water"] = Property("Water")
}


local ObbyCreator = {}
function ObbyCreator.new(Type)
    local Block
    local Connection = Items.DescendantAdded:Connect(function(Instance)
        if Instance.Name == Type and Instance:IsDescendantOf(Items) then
            if (Instance.CFrame.p - Origin.p).Magnitude < 1 then
                Block = Instance
            end
        end
    end)

    Events.Build:InvokeServer(Type, Origin)
    
    repeat task.wait() until Block ~= nil
    
	Connection:Disconnect()

    return ObbyCreator.Object(Block)
end

local function getproperties(Instance)
    local Table = {}
    
    for _, Property in next, game:GetService("ReflectionService"):GetPropertyNames(Instance.ClassName) do
        pcall(function()
            Table[Property] = Instance[Property]
        end)
    end

    Table["Position"] = Instance["Position"]
    Table["Orientation"] = Instance["Orientation"]

    return Table
end

function ObbyCreator.Object(Object)
    local Properties = getproperties(Object)

    return setmetatable({
    	Edits = 0,
    	Queue = {},
        Object = Object,
        Destroy = function(self) Events.Delete:InvokeServer({Object}) end,
        Remove = function(self) Events.Delete:InvokeServer({Object}) end,
    }, {
        __index = Properties,
        __newindex = function(self, Key, Value)
            Properties[Key] = Value
            
           	task.spawn(function()
           		local Edit = self.Edits + 1
           		self.Edits = Edit
           		
           		table.insert(self.Queue, Edit)
           		
           		repeat task.wait() until self.Queue[1] == Edit

                task.wait(0.3)

                pcall(function()
                    ObbyCreator.Edit(Object, {[Key] = Value})
                end)

            	table.remove(self.Queue, 1)
            end)
        end
    })
end

function ObbyCreator.Edit(Block, Properties)
	for Property, Value in next, Properties do
		Events.SetEditing:FireServer({Block}, false)
		Events.Selection:FireServer("Add", {Block})
		
		task.wait()
		
		Edit[Property](Block, Value)
		
		Events.SetEditing:FireServer({}, true)
		Events.Selection:FireServer("None")
	end
end

return ObbyCreator
