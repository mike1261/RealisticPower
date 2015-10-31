realisticPower = {}

realisticPower.constants = {}
realisticPower.constants.balerFillFactor = 0.032 --13*125/(540*math.pi*30) -- 13 km/h 125 Nm 540 U/min
realisticPower.constants.speedFactor     = 2

function realisticPower:loadMap(name)
end

function realisticPower:deleteMap()
end

function realisticPower:keyEvent(unicode, sym, modifier, isDown)
end

function realisticPower:mouseEvent(posX, posY, isDown, isUp, button)
end

function realisticPower:update(dt)
	if not ( realisticPower.powerUpdateDone ) then
		realisticPower.powerUpdateDone     = true
		PowerConsumer.getConsumedPtoTorque = Utils.overwrittenFunction( PowerConsumer.getConsumedPtoTorque, realisticPower.newGetConsumedPtoTorque )
		print("realisticPower update done")
	end
end

function realisticPower:draw()
end

function realisticPower:newGetConsumedPtoTorque(superFunc)
	local torque   = superFunc( self )
	
	if torque <= 0 then
		return torque 
	end
	
	local origTorque    = torque 
	
	if self.realisticPowerConsumer == nil then
		self.realisticPowerConsumer = {}
		self.realisticPowerConsumer.speedRatio    = 0	
		self.realisticPowerConsumer.fillRatio     = 0
		self.realisticPowerConsumer.fillFactor    = 0
		self.realisticPowerConsumer.speedFactor   = 0
	
		if SpecializationUtil.hasSpecialization(Baler, self.specializations) then
			self.realisticPowerConsumer.fillRatio     = 0.8
			self.realisticPowerConsumer.fillFactor    = realisticPower.constants.balerFillFactor
		end
		
		if self.realisticPowerConsumer.speedRatio > 0 and self.realisticPowerConsumer.speedFactor <= 0 and 1 < self.speedLimit and self.speedLimit < 100 then
			self.realisticPowerConsumer.speedFactor = realisticPower.constants.speedFactor / self.speedLimit
		end
	end
	
	torque = ( 1 - self.realisticPowerConsumer.speedRatio - self.realisticPowerConsumer.fillRatio ) * origTorque
	
	if origTorque > 0 and self.realisticPowerConsumer.speedRatio > 0.01 then 
		torque = torque + origTorque * self.realisticPowerConsumer.speedRatio * self.lastSpeedReal * 3600 * self.realisticPowerConsumer.speedFactor
	end
	
	if origTorque > 0 and math.abs( self.realisticPowerConsumer.fillRatio ) > 0.01 then
		local delta          = 0
		local deltaPerSecond = 0
		if self.realisticPowerConsumer.lastFillLevel == nil then
			self.realisticPowerConsumer.lastFillLevel = self.fillLevel
		else
			delta = self.fillLevel - self.realisticPowerConsumer.lastFillLevel
		end
		self.realisticPowerConsumer.lastFillLevel = self.fillLevel
		if self.realisticPowerConsumer.fillRatio < 0 then
			delta = -delta
		end
		if delta > 0 then
			if self.realisticPowerConsumer.lastFillDelta == nil then
				self.realisticPowerConsumer.lastFillDelta = 0
			end
			self.realisticPowerConsumer.lastFillDelta = self.realisticPowerConsumer.lastFillDelta + delta
			self.realisticPowerConsumer.lastFillTime  = g_currentMission.time + 1000
		end
		if self.realisticPowerConsumer.lastFillTime ~= nil and self.realisticPowerConsumer.lastFillTime > g_currentMission.time then
			numToDrop = math.min( self.tickDt * self.realisticPowerConsumer.lastFillDelta / ( self.realisticPowerConsumer.lastFillTime - g_currentMission.time ), self.realisticPowerConsumer.lastFillDelta )
			self.realisticPowerConsumer.lastFillDelta = self.realisticPowerConsumer.lastFillDelta - numToDrop
			deltaPerSecond = numToDrop * 1000 / self.tickDt
		end		
		if deltaPerSecond > 0 then
			torque = torque + math.abs( self.realisticPowerConsumer.fillRatio ) * deltaPerSecond * self.realisticPowerConsumer.fillFactor
		end
	end
	
	return torque
end

addModEventListener(realisticPower)
print("realisticPower loaded")

realisticPower.powerUpdateDone     = true
PowerConsumer.getConsumedPtoTorque = Utils.overwrittenFunction( PowerConsumer.getConsumedPtoTorque, realisticPower.newGetConsumedPtoTorque )
print("realisticPower update done")
