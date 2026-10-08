--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.ShelfConfig)
local Showcase = {}
export type Controller = {
	ownerId: number,
	editorToken: number?,
	lastToken: number,
	nextStep: number?,
	idleUntil: number,
	active: boolean,
}
function Showcase.new(ownerId: number): Controller
	return {
		ownerId = ownerId,
		editorToken = nil,
		lastToken = 0,
		nextStep = nil,
		idleUntil = 0,
		active = true,
	}
end
-- This signal only pauses presentation. It grants no edit authority or progression.
function Showcase.editor(c: Controller, rawOpen: unknown, rawToken: unknown, now: number): boolean
	if not c.active or typeof(rawOpen) ~= "boolean" or typeof(rawToken) ~= "number" then
		return false
	end
	local token = rawToken :: number
	if token ~= token or token < 1 or token > 1000000000 or token % 1 ~= 0 then
		return false
	end
	if rawOpen then
		if token <= c.lastToken then
			return false
		end
		c.lastToken = token
		c.editorToken = token
	elseif token == c.editorToken then
		c.editorToken = nil
		c.idleUntil = math.max(c.idleUntil, now + Config.showcaseEditorIdleSeconds)
		c.nextStep = c.idleUntil
	else
		return false
	end
	return true
end
function Showcase.browse(c: Controller, now: number)
	c.idleUntil = math.max(c.idleUntil, now + Config.showcaseBrowseIdleSeconds)
	c.nextStep = c.idleUntil
end
-- Called by the existing shared one-second scheduler; no plot-owned tasks/connections.
function Showcase.due(c: Controller, count: number, now: number): boolean
	if not c.active or count <= Config.visibleShelfUnits then
		c.nextStep = nil
		return false
	end
	if c.editorToken then
		return false
	end
	local nextStep = c.nextStep or math.max(now + Config.showcaseStepSeconds, c.idleUntil)
	c.nextStep = nextStep
	return now >= nextStep and now >= c.idleUntil
end
function Showcase.wait(c: Controller, now: number)
	c.nextStep = now + Config.showcaseStepSeconds
end
function Showcase.destroy(c: Controller)
	c.active = false
	c.editorToken = nil
	c.nextStep = nil
end
return Showcase
