-- the old code was like 20 times the length of this
-- granted, it had features like thrust effects and thrust damage, but i dont think those ar needed
-- people will just make their own thruster effects anyway so whats the point

-- i think ALL turbine get thrust so that might be an issue?

ACFE.SmallThrust = CreateConVar( "acfe_thrust_small", "10000", {FCVAR_ARCHIVE}, "Thrust for small engines (in pound-force)" )
ACFE.MediumThrust = CreateConVar( "acfe_thrust_medium", "20000", {FCVAR_ARCHIVE}, "Thrust for medium engines (in pound-force)" )
ACFE.LargeThrust = CreateConVar( "acfe_thrust_large", "40000", {FCVAR_ARCHIVE}, "Thrust for large engines (in pound-force)" )

cvars.AddChangeCallback( "acfe_thrust_small", function( name, old, new )
    ACFE.ReloadThrust()
end )
cvars.AddChangeCallback( "acfe_thrust_medium", function( name, old, new )
    ACFE.ReloadThrust()
end )
cvars.AddChangeCallback( "acfe_thrust_large", function( name, old, new )
    ACFE.ReloadThrust()
end )

function ACFE.ReloadThrust()

	ACFE.SmallThrust = GetConVar( "acfe_thrust_small" ):GetFloat() or 10000
	ACFE.MediumThrust = GetConVar( "acfe_thrust_medium" ):GetFloat() or 20000
	ACFE.LargeThrust = GetConVar( "acfe_thrust_large" ):GetFloat() or 40000

end
ACFE.ReloadThrust()

-- ( isoptional = false ) thrust is mandatory, for dedicated jet engines
-- ( isoptional = true ) thrust is optional, must be enabled via wire input
function ACFE.InjectThrust( ent, isoptional ) -- this should work for any engine

	local model = ent:GetModel()

	-- engine size
	local issmall = string.find( model, "s.mdl" )
	local ismedium = string.find( model, "m.mdl" )
	local islarge = string.find( model, "l.mdl" )

	-- thanks for the help wil
	local smallthrust = ACFE.SmallThrust * 0.00571
	local mediumthrust = ACFE.MediumThrust * 0.00571
	local largethrust = ACFE.LargeThrust * 0.00571

	-- set max thrust based on engine size
	local maxthrust = ( islarge and largethrust ) or ( ismedium and mediumthrust ) or smallthrust
	ent.MaxThrust = maxthrust

	if ( isoptional ) then

		-- create extra inputs
		-- TODO: make this modular somehow?
		local inputnames = {
			"Active",
			"Throttle",
			"Thrust"
		}
		local inputtypes = {
			"NORMAL",
			"NORMAL",
			"NORMAL"
		}
		local inputdescs = {
			"Turns the engine on or off",
			"How much throttle to apply to the engine (100 is max)",
			"How much thrust the engine should output (100 is max)"
		}

		WireLib.AdjustSpecialInputs( ent, inputnames, inputtypes, inputdescs )

	end


	-- add onto the engines think
	if ( ACF.Repositories ) then -- acf 3
		ent.Think = function( self )

			local physobj = self:GetPhysicsObject()
			local active = ent.Inputs[ "Active" ].Value >= 1 and ( not isoptional or ent.Inputs[ "Thrust" ].Value > 0 )

			local yeah = ( self and self:IsValid() and physobj and physobj:IsValid() and active )

			if ( yeah ) then

				local rpm = self.FlyRPM / self.LimitRPM

				local thrust = rpm * self.MaxThrust * math.Clamp( ent.Inputs[ "Thrust" ].Value, 0, 100 )
				physobj:ApplyForceCenter( self:GetForward() * thrust )

			end

			-- make sure it runs at sv tickrate
			self:NextThink( CurTime() )
			return true
		end
	else -- acf 2?
		-- think was taken so fuckin uhhhhhhhhhhhhh
		ent.PhysicsUpdate = function( self )

			local physobj = self:GetPhysicsObject()
			local active = ent.Inputs[ "Active" ].Value >= 1 and ( not isoptional or ent.Inputs[ "Thrust" ].Value > 0 )

			local yeah = ( self and self:IsValid() and physobj and physobj:IsValid() and active )

			if ( yeah ) then

				local rpm = self.FlyRPM / self.LimitRPM

				local thrust = rpm * self.MaxThrust * math.Clamp( ent.Inputs[ "Thrust" ].Value, 0, 100 )
				physobj:ApplyForceCenter( self:GetForward() * thrust )

			end

		end
	end

end

function ACFE.IsTurbine( ent )

	if ( IsValid( ent ) and ent:GetClass() == "acf_engine" ) then

		if ( string.find( ent:GetModel(), "/turbine" ) ) then

			return true

		end

	end

	return false

end

function ACFE.IsPulsejet( ent )

	if ( IsValid( ent ) and ent:GetClass() == "acf_engine" ) then

		if ( string.find( ent:GetModel(), "/pulsejet" ) ) then

			return true

		end

	end

	return false

end

-- da hookes
hook.Add( "OnEntityCreated", "ACFE_Inject", function( ent )

	 -- we need to wait till next think for the entity to be given a model
	timer.Simple( 0, function()

		if ( ACFE.IsTurbine( ent ) ) then

			ACFE.InjectThrust( ent, true )

		end

		if ( ACFE.IsPulsejet( ent ) ) then

			ACFE.InjectThrust( ent, false )

		end

	end )

end )
hook.Add( "ACF_OnUpdateEntity", "ACFE_Inject", function( type, ent )

	if ( ACFE.IsTurbine( ent ) ) then

		ACFE.InjectThrust( ent, true )

	end

	if ( ACFE.IsPulsejet( ent ) ) then

		ACFE.InjectThrust( ent, false )

	end

end )