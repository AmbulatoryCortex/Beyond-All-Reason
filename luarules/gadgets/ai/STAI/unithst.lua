UnitHST = class(Module)

function UnitHST:Name()
	return "UnitHandler"
end

function UnitHST:internalName()
	return "unithst"
end

function UnitHST:Init()
	self.units = {}
	self.behaviourFactory = BehaviourFactory()
	self.behaviourFactory:SetAI(self.ai)
	self.behaviourFactory:Init()
end

function UnitHST:Update()--is before shardlua/unit
	for ID,unit in pairs(self.units) do
		if unit then
			if unit:HasBehaviours() then
				unit:Update()
			end
		end

	end
end

function UnitHST:GameEnd()
	for k,unit in pairs(self.units) do
		if unit:HasBehaviours() then
			unit:GameEnd()
		end
	end
end

function UnitHST:UnitCreated(unit, unitDefId, teamId, builderId)
	local u = self:AIRepresentation(unit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitCreated(u, unitDefId, teamId, builderId)
	end

end

function UnitHST:UnitBuilt(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitBuilt(u)
	end
end

function UnitHST:UnitDead(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitDead(u)
	end
 	self.units[engineUnit:ID()] = nil

end

function UnitHST:UnitDamaged(engineUnit,engineAttacker,damage)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitDamaged(u,engineAttacker,damage)
	end
end


function UnitHST:UnitIdle(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if not u then return end
	if u:HasBehaviours() then
		u:UnitIdle(u)
	end
end

function UnitHST:AIRepresentation(engineUnit)
	if not engineUnit then
		return nil
	end
	if not engineUnit then
		return nil
	end

 	local u = self.units[engineUnit:ID()]
	if u == nil then
		u = Unit()
		u:SetAI(self.ai)
 		self.units[engineUnit:ID()] = u
		u:SetEngineRepresentation(engineUnit)
		u:Init()
		if engineUnit:Team() == self.game:GetTeamID() then
			self.behaviourFactory:AddBehaviours(u)
-- 			if inactive[engineUnit:Name()] then
-- 				self.myInactiveUnits[engineUnit:ID()] = u
-- 			else
-- 				-- game:SendToConsole(self.ai.id, "giving my unit behaviours", engineUnit:ID(), engineUnit:Name())
--
-- 				self.myActiveUnits[engineUnit:ID()] = u
-- 			end
		end
	end
	return u
end

