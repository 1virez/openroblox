--[[

	OpenCamera
	Revision 1
	© 2026 Made by Virez[@1Virez]

]]--

local CameraController = {}

-- Private Variables \\
local Connections = {} :: { RBXScriptConnection? } --> Where we store our Connections to keep track of them.

local Offsets = {} :: { CameraOffset? } --> Where we store our CameraOffsets.

-- Types \\
export type CameraOffset = typeof({
	Positional = Vector3.zero;
	PositionalIntensity = 1;
	Rotational = Vector3.zero;
	RotationalIntensity = 1;
	CompositeIntensity = 1;
	IsWorldSpace = false;

	-- Completely removes this offset.
	Clear = function(self: CameraOffset) : () --> "self: CameraOffset" to force Colon Function Call.
		local Index = table.find(Offsets, self)

		if Index then
			Offsets[Index] = nil
			table.remove(Offsets, Index)
			return nil
		end
	end
})

export type OffsetArguments = typeof({
	Pos = nil :: Vector3?;
	PosIntens = nil :: number?;
	Rot = nil :: Vector3?;
	RotIntens = nil :: number?;
	Intens = nil :: number?;
	World = nil :: boolean?
})
-- Types //

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Bindables = {
	["PreRender"] = Instance.new("BindableEvent")
}

local Events = {
	["PreRender"] = Bindables.PreRender.Event --> This hooks into the Camera's PreRender. Useful for keeping external functions in sync with the camera.
}

-- Linear Interpolation from A to B for variables.
local function Lerp(A: number, B: number, t: number): number
	return A + ( B - A ) * t or 0
end

-- Converts the passed angle in degrees into radians.
local function Radians(Angle: number) : number
	return math.rad(Angle) or 0
end

-- Main Logic to run before every frame.
local function PreRender() : ()
	local Anchor = CameraController.Camera.Anchor
	if not Anchor then CameraController:Stop(); warn(`Camera failed to compute: Anchor not set!`) return end
	
	local CameraInstance = workspace.CurrentCamera
	if not CameraInstance then CameraController:Stop(); warn(`Camera failed to compute: Camera not found in Workspace!`) return end
	
	CameraInstance.CameraType = Enum.CameraType.Scriptable --> Force the CameraType to scriptable so the default Roblox Camera won't fight us.
	
	local MouseLocked = CameraController.Config.MouseLocked
	local OrientByAnchor = CameraController.Config.OrientByAnchor
	
	if MouseLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	
	local CompositeRotationalOffset = Vector3.zero
	local CompositePositionalOffset = {
		WorldSpace = Vector3.zero,
		LocalSpace = Vector3.zero
	}
	
	for _, Offset: CameraOffset? in ipairs(Offsets) do
		if Offset then
			CompositeRotationalOffset += (Offset.Rotational * Offset.RotationalIntensity)
			
			if Offset.IsWorldSpace then
				CompositePositionalOffset.WorldSpace += (Offset.Positional * Offset.PositionalIntensity)
			else
				CompositePositionalOffset.LocalSpace += (Offset.Positional * Offset.PositionalIntensity)
			end
		end
	end
	
	local AnchorOrientationX, AnchorOrientationY, AnchorOrientationZ = Anchor.CFrame:ToOrientation()
	
	if OrientByAnchor then
		CameraInstance.CFrame = CFrame.new(Anchor.CFrame.Position + CompositePositionalOffset.WorldSpace)
			* CFrame.Angles(0, 0, (AnchorOrientationZ + Radians(CompositeRotationalOffset.Z)))
			* CFrame.Angles(0, (AnchorOrientationY + Radians(CompositeRotationalOffset.Y)), 0)
			* CFrame.Angles((AnchorOrientationX + Radians(CompositeRotationalOffset.X)), 0, 0)
			* CFrame.new(CompositePositionalOffset.LocalSpace)
	end
	
	local TargetWorldPosition = Anchor.CFrame.Position
	
	local Camera = CameraController.Camera
	local Config = CameraController.Config
	
	local TargetTurnVelocity = Camera.TurnVelocity * Config.Sensitivity
	
	Camera.TrueOrientation = Vector3.new(
		Lerp(Camera.TrueOrientation.X, Camera.TrueOrientation.X + TargetTurnVelocity.Y, Config.TurnRigidity),
		Lerp(Camera.TrueOrientation.Y, Camera.TrueOrientation.Y + TargetTurnVelocity.X, Config.TurnRigidity),
		Lerp(Camera.TrueOrientation.Z, Camera.TrueOrientation.Z + TargetTurnVelocity.Z, Config.TurnRigidity)
	)
	
	local Orientation = Camera.TrueOrientation
	Orientation = Vector3.new(
		math.clamp(Orientation.X, Config.MaxPitchAngles.Min, Config.MaxPitchAngles.Max),
		Orientation.Y,
		Orientation.Z
	)
	
	if Config.WrapYaw then
		if Orientation.Y >  360 then Orientation = Vector3.new(Orientation.X, Orientation.Y - 360, Orientation.Z) end
		if Orientation.Y < -360 then Orientation = Vector3.new(Orientation.X, Orientation.Y +  360, Orientation.Z) end
	end
	
	if Config.WrapRoll then
		if Orientation.Z >  360 then Orientation = Vector3.new(Orientation.X, Orientation.Y, Orientation.Z - 360) end
		if Orientation.Z < -360 then Orientation = Vector3.new(Orientation.X, Orientation.Y, Orientation.Z +  360) end
	end
	
	Camera.TrueOrientation = Orientation
	Camera.OrientationDeg = Orientation
	Camera.OrientationRad = Vector3.new(
		Radians(Orientation.X),
		Radians(Orientation.Y),
		Radians(Orientation.Z)
	)
	
	local FinalRotationDeg = Camera.OrientationDeg + CompositeRotationalOffset
	
	if not OrientByAnchor then
		local FinalRotationRad = Vector3.new(
			Radians(FinalRotationDeg.X),
			Radians(FinalRotationDeg.Y),
			Radians(FinalRotationDeg.Z)
		)

		CameraInstance.CFrame = CFrame.new(Anchor.CFrame.Position + CompositePositionalOffset.WorldSpace)
			* CFrame.Angles(0, 0, FinalRotationRad.Z)
			* CFrame.Angles(0, FinalRotationRad.Y, 0)
			* CFrame.Angles(FinalRotationRad.X, 0, 0)
			* CFrame.new(CompositePositionalOffset.LocalSpace)
	end
	
	CameraInstance.FieldOfView = Lerp(CameraInstance.FieldOfView, Config.FOV.Target, Config.FOV.Rigidity)
	
	if Camera.TurnVelocity.Magnitude >= 0.0001 then
		Camera.TurnVelocity = Camera.TurnVelocity:Lerp(Vector3.zero, CameraController.Config.TurnRigidity)
	else
		Camera.TurnVelocity = Vector3.new(0, 0, 0)
	end
	
	Bindables.PreRender:Fire()
end

-- Logic that runs whenever Input "changes".
local function InputChanged(Input: InputObject, Processed: boolean) : ()
	if Processed then return end
	
	local MouseLocked = CameraController.Config.MouseLocked
	
	if (Input.UserInputType == Enum.UserInputType.MouseMovement) then --> Converts mouse movement into turning velocity.
		if (MouseLocked)
			or ((not MouseLocked)
				and (UserInputService:IsKeyDown(Enum.KeyCode.MouseRightButton)))
		then
			local Delta = -Input.Delta
			local Delta3 = Vector3.new(Delta.X, Delta.Y, 0)

			CameraController.Camera.TurnVelocity += Delta3
		end
	end
end
-- Private Variables //

-- Global Variables \\
CameraController.Config = {
	["TurnRigidity"] = 0.75, --> How snappy the Camera's Turning is. Higher -> Snappier.
	["Sensitivity"] = 0.2, --> How much of the raw Mouse Movement is actually used to turn the Camera. Higher -> Faster.
	
	--[[ 
	| Whether or not to wrap the angles back around to 0 if they exceed -/+ 360°.
	| Only disable these when required, and re-enable them later on,
	↓ else they will grow to infinity. ]]
	["WrapPitch"] = true,
	["WrapYaw"] = true,
	["WrapRoll"] = true,
	
	["MaxPitchAngles"] = NumberRange.new(-89.9999, 89.9999), --> The maximum Pitch angles.
	["MaxYawAngles"] = NumberRange.new(-361, 361), --> The maximum Yaw angles. Set above - & + 360° to allow wrapping.
	["MaxRollAngles"] = NumberRange.new(-361, 361), --> The maximum Roll angles. Set above - & + 360° to allow wrapping.
	
	["MouseLocked"] = false, --> Whether or not to force the mouse to the center of the screen. When false, the camera will not turn, unless the Right Mouse Button is held.
	["OrientByAnchor"] = false, --> Whether or not the Camera's Orientation corresponds to the Anchor's Orientation.
	["AnchorOrientationInfluence"] = 0, --> How much the Anchor's Orientation influences the Camera's Orientation.
	
	["FOV"] = {
		["Target"] = 85, --> The FOV to Lerp towards.
		["Rigidity"] = 0.05 --> Controls how fast the visual FOV value Lerps towards the target FOV. Higher -> Faster.
	}
}

CameraController.Camera = {
	["TrueOrientation"] = Vector3.zero, --> What way the Camera is truly facing in degrees, without any Offsets applied.
	["TruePosition"] = Vector3.zero, --> Where the Camera is truly positioned without any Offsets applied.
	["OrientationDeg"] = Vector3.zero, --> The Camera's Orientation in degrees.
	["OrientationRad"] = Vector3.zero, --> The Camera's Orientation in radians.
	["Position"] = Vector3.zero, --> Where the Camera is Positioned.
	["TurnVelocity"] = Vector3.zero, --> The turning velocity of the Camera, influenced by mouse movement.
	["Anchor"] = nil :: BasePart | Attachment, --> Where the Camera sticks to.
	["InterpolatedFOV"] = 0 --> The visual FOV value. ReadOnly.
}

CameraController.PreRender = Events.PreRender --> Event that allows external scripts to sync to the Camera.

-- Creates a new Camera Offset and returns it.
function CameraController:CreateNewOffset(Arguments: OffsetArguments?) : CameraOffset
	Arguments = Arguments or {}
	local Fallback = Vector3.zero
	
	local self = {} :: CameraOffset
	self.Positional = Arguments.Pos or Fallback
	self.Rotational = Arguments.Rot or Fallback
	self.PositionalIntensity = Arguments.PosIntens or 1
	self.RotationalIntensity = Arguments.RotIntens or 1
	self.CompositeIntensity = Arguments.Intens or 1
	self.IsWorldSpace = (Arguments.World and Arguments.World ~= nil)
	
	function self:Clear()
		local Index = table.find(Offsets, self)
		
		if (Index) then
			Offsets[Index] = nil
		end
	end
	
	table.insert(Offsets, self)
	return self
end

-- Starts/Restarts the Controller's logic.
function CameraController:Start() : ()
	self:Stop()
	
	table.insert(Connections, RunService.PreRender:Connect(PreRender))
	table.insert(Connections, UserInputService.InputChanged:Connect(InputChanged))
end

-- Stops the Controller's logic.
function CameraController:Stop() : ()
	for _, Connection in ipairs(Connections) do
		if ((Connection) and (Connection.Connected)) then
			Connection:Disconnect()
		end
	end
	
	table.clear(Connections)
end
-- Global Variables //

return CameraController
