-- Toca os efeitos sonoros só para este jogador (SoundService:PlayLocalSound).
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)

local Sfx = {}

local cache: { [string]: Sound } = {}

function Sfx.play(name: string?)
	local sound = name and cache[name]
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

function Sfx.start()
	local folder = Instance.new("Folder")
	folder.Name = "Efeitos"
	folder.Parent = SoundService
	local list = {}
	for name, def in Sounds do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = def.id
		sound.Volume = def.volume
		sound.Parent = folder
		cache[name] = sound
		table.insert(list, sound)
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end

return Sfx
