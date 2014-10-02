--[[
	Purpose:
		Rendering VGUI in 3D-Space

	USAGE:
	
	PANEL:Set3D2D(bool)
	PANEL:Set3D2DScale(float)
	PANEL:	
	PANEL:Set3D2DAng(angle)
	PANEL:Set3D2DParent(entity)
]]--

local _R = debug.getregistry()
if not lib3d2d then
	lib3d2d = {}

	lib3d2d.detours = {--add libs which are used for detours here
		gui = {},
		vgui = {},
		_R = {
			Panel = {}
		},
	}
	lib3d2d.fadeDistance = 1000^2--maximum render distance^2
else
	if lib3d2d.proxyTextEntryWrapper then
		lib3d2d.proxyTextEntryWrapper:Remove()
	end
end

--FIXME:
--Fix Event handling

function lib3d2d.enable()
	lib3d2d.active = true
	local NULL_ANG = Angle(0, 0, 0)--default values
	local NULL_VEC = Vector(0, 0, 0)

	local activePanels =  {}
	lib3d2d.activePanels = activePanels
	local visiblePanels = {}

	local cursorPosX = 0
	local cursorPosY = 0

	local viewOrigin = NULL_VEC--The players cam pos
	local viewDirection = NULL_VEC--normal
	local viewDirectionAngles = NULL_ANG

	local currentPanel--Current Panel
	local currentPanelPosition = NULL_VEC
	local currentPanelAngles = NULL_ANG
	local currentPanelScale = 1
	
	function lib3d2d.debug()
		hook.Add("HUDPaint", "3D2DVGUI", function()
			surface.SetFont("default")
			surface.SetTextColor(255, 255, 255, 255)
			
			surface.SetTextPos(20, 20)
			surface.DrawText("viewOrigin: " .. tostring(viewOrigin))
			surface.SetTextPos(20, 40)
			surface.DrawText("viewDirection: " .. tostring(viewDirection))
			surface.SetTextPos(20, 60)
			surface.DrawText("viewDirectionAngles: " .. tostring(viewDirectionAngles))
			surface.SetTextPos(20, 80)
			surface.DrawText("currentPanel: " .. tostring(currentPanel))
			surface.SetTextPos(20, 100)
			surface.DrawText("currentPanelPosition: " .. tostring(currentPanelPosition))
			surface.SetTextPos(20, 120)
			surface.DrawText("currentPanelAngles: " .. tostring(currentPanelAngles))
			surface.SetTextPos(20, 140)
			surface.DrawText("currentPanelScale: " .. tostring(currentPanelScale))
			surface.SetTextPos(20, 160)
			surface.DrawText("cursorPosX: " .. tostring(cursorPosX))
			surface.SetTextPos(20, 180)
			surface.DrawText("cursorPosY: " .. tostring(cursorPosY))
		end)
	end
	
	
	

	--Needed to allow text input
	local currentTextEntry

	local proxyTextEntryWrapper = vgui.Create("EditablePanel")--needed for focusing the TextEntry

	local proxyTextEntry = vgui.Create("DTextEntry", proxyTextEntryWrapper)

	lib3d2d.proxyTextEntryWrapper = proxyTextEntryWrapper

	proxyTextEntry.OnChange = function(self)
		currentTextEntry:SetValue(self:GetValue())
	end

	local func = proxyTextEntry.OnLoseFocus
	proxyTextEntry.OnLoseFocus = function(self)
		proxyTextEntryWrapper:SetVisible(false)
		self:SetText("")
		func(self)
	end
	
	

	proxyTextEntryWrapper:SetSize(100, 20)
	proxyTextEntryWrapper:SetPos(-100, -100)
	proxyTextEntryWrapper:SetVisible(true)
	--end text input
	--UTILS

	--ray trace intersection
	local function rayPlaneIntersect(planeOrigin, planeNormal, rayOrigin, rayDirection)
		local denominator = rayDirection:Dot(planeNormal)
		if denominator == 0 then
			return false--parallel
		end
		local ret = Vector()
		ret:Set(rayDirection)
		ret:Mul(((planeOrigin - rayOrigin):Dot(planeNormal) / denominator))
		ret:Add(rayOrigin)
		return ret
	end

	--Called to set all the globals to the panel specific values
	local function setPanelInfo(pnl)
		currentPanel = pnl
		currentPanelPosition = pnl.__3d2dPos
		currentPanelAngles = pnl.__3d2dAng
		currentPanelScale = pnl.__3d2dScale
	end

	--Updates cursorPosX and cursorPosY for currentPanel
	local WorldToLocal = WorldToLocal
	local mfloor = math.floor
	
	--Inline ray trace intersection
	local function updateCurrent3D2DCursorPos()
		local collisionPoint = rayPlaneIntersect(
			currentPanelPosition,
			currentPanelAngles:Up(),
			viewOrigin,
			viewDirection
		)
		if not collisionPoint then
			return
		end
		
		local projectedPos = WorldToLocal(collisionPoint, NULL_ANG, currentPanelPosition, currentPanelAngles)
		projectedPos:Mul(1 / currentPanelScale)
		
		cursorPosX = mfloor(projectedPos.x)
		cursorPosY = mfloor(-projectedPos.y)
	end
	
	local function isInRelRect(x, y, minX, minY, sizeX, sizeY)
		return x >= minX and x <= minX + sizeX and y >= minY and y <= minY + sizeY
	end

	--Updates the hover status of the panel
	local function updateHoverState(panel)
		local x, y = panel:LocalToScreen()
		local w, h = panel:GetSize()
		panel.__hovered = isInRelRect(cursorPosX, cursorPosY, x, y, w, h)
		return panel.__hovered
	end

	local function handlePanelEvent(pnl, event, ...)
		local previousHoverState = pnl.__hovered
		if pnl.__3d2dPos then
			setPanelInfo(pnl)
			updateCurrent3D2DCursorPos()
		end
		local newHoverState = updateHoverState(pnl)
		if not previousHoverState and not newHoverState then
			return
		end
		
		local handled = false
		local posX, posY = pnl:LocalToScreen(0, 0)
		local x, y
		local isMove = event == "OnCursorMoved"

		if isMove then
			if previousHoverState ~= newHoverState then
				handlePanelEvent(pnl, newHoverState and "OnCursorEntered" or "OnCursorExited")
				pnl.Hovered = newHoverState
			end
		end

		for k, child in next, pnl:GetChildren() do
			local cx, cy = child:GetPos()
			
			local w, h = child:GetSize()
			
			x = posX + cx
			y = posY + cy
			
			local hVal = handlePanelEvent(child, event, ...)
			if hVal then
				handled = true
				break
			end
		end
		if not handled and pnl[event] then
			if event == "OnMousePressed" then
				if pnl:GetClassName() == "TextEntry" then--special handling of text entries to allow focus
					proxyTextEntry:SetValue(pnl:GetValue())
					proxyTextEntry:SetCaretPos(pnl:GetValue():len())
				
					currentTextEntry = pnl
					
					proxyTextEntryWrapper:SetVisible(true)--Needs to be visible
					proxyTextEntryWrapper:MakePopup()--GAIN DAT FOCUS
					proxyTextEntry:RequestFocus()
				end
			end
			if isMove then
				pnl[event](pnl, cursorPosX - x, cursorPosY - y)
			else
				pnl[event](pnl, ...)
			end
			if pnl:GetClassName() == "Label" then
				return false
			end
			return true--FIXME: SPECIAL CASE FOR DFRAMES!!
		else
			return false
		end
	end

	--DETOURS
	local shouldDetourGuiPos--set when any panel action is required

	local oldGuiMouseX = gui.MouseX
	lib3d2d.detours.gui.MouseX = oldGuiMouseX
	function gui.MouseX()
		if shouldDetourGuiPos then
			return cursorPosX
		end
		return oldGuiMouseX()
	end
	
	local oldGuiMouseY = gui.MouseY
	lib3d2d.detours.gui.MouseY = oldGuiMouseY
	function gui.MouseY()
		if shouldDetourGuiPos then
			return cursorPosY
		end
		return oldGuiMouseY()
	end
	
	local oldGuiMousePos = gui.MousePos
	lib3d2d.detours.gui.MousePos = oldGuiMousePos
	function gui.MousePos()
		if shouldDetourGuiPos then
			return cursorPosX, cursorPosY
		end
		return oldGuiMousePos()
	end

	local oldCursorPos = _R.Panel.CursorPos
	lib3d2d.detours._R.CursorPos = oldCursorPos
	function _R.Panel:CursorPos()
		if shouldDetourGuiPos then
			local x, y = self:LocalToScreen(0, 0)
			return cursorPosX - x, cursorPosY - y
		end
		return oldCursorPos(self)
	end
	
	local oldSetCursor = _R.Panel.SetCursor
	lib3d2d.detours._R.Panel.SetCursor = oldSetCursor
	function _R.Panel:SetCursor(cur)
		self.__cursor = cur
		oldSetCursor(self, cur)
	end
	--EVENT HOOKING

	--MOUSE CAPTURE
	local lastHoverState
	local panel
	local tremove = table.remove
	local maxDist
	local doBreak = false
	local x, y, w, h
	
	local cursorMats = {
		user = Material("cursor_user.png"),
		arrow = Material("cursor_arrow.png"),
		beam = Material("cursor_beam.png"),
		hourglass = Material("cursor_hourglass.png"),
		waitarrow = Material("cursor_waitarrow.png"),
		crosshair = Material("cursor_crosshair.png"),
		up = Material("cursor_up.png"),
		sizenwse = Material("cursor_sizewse.png"),
		sizenesw = Material("cursor_sizenesw.png"),
		sizewe = Material("cursor_sizewe.png"),
		sizens = Material("cursor_sizes.png"),
		sizeall = Material("cursor_sizeall.png"),
		no = Material("cursor_no.png"),
		hand = Material("cursor_hand.png")
	}
	
	hook.Add("CalcView", "3D2DVGUI", function(_, pos, ang)
		if #activePanels ~= 0 then
			if (viewOrigin ~= pos) or (viewDirectionAngles ~= ang) then--only update if the player changed their orientation
				shouldDetourGuiPos = true
				viewOrigin = pos
				viewDirectionAngles = ang
				viewDirection = ang:Forward()--EyeVector() doesn't work here
				
				for i = 1, #activePanels do
					panel = activePanels[i]
					maxDist = panel.__3d2dFadeDistance
					if ((pos.x - panel.__3d2dPos.x) ^ 2 +
						(pos.y - panel.__3d2dPos.y) ^ 2 +
						(pos.z - panel.__3d2dPos.z) ^ 2
						) > maxDist then
						visiblePanels[panel] = false
						continue
					end
					visiblePanels[panel] = true
					
					if not panel:IsValid() then
						tremove(activePanels, i)--drop invalid panel
					end
					
					handlePanelEvent(panel, "OnCursorMoved")
				end
				shouldDetourGuiPos = false
			end
		else
			currentPanel = false
		end
	end)

	--DRAWING
	local cStart3D2D = cam.Start3D2D
	local cEnd3D2D = cam.End3D2D
	local rGetToneMappingScaleLinear = render.GetToneMappingScaleLinear
	local rSetToneMappingScaleLinear = render.SetToneMappingScaleLinear
	
	local targetScale = Vector(0.66, 0 , 0)
	local oldScale
	hook.Add("PostDrawOpaqueRenderables", "3D2DVGUI", function()
		shouldDetourGuiPos = true
		for i = 1, #activePanels do
			panel = activePanels[i]
			if not visiblePanels[panel] then
				continue
			end
			if not panel:IsValid() then
				continue
			end
			oldScale = rGetToneMappingScaleLinear()
			
			rSetToneMappingScaleLinear(targetScale)
			
			cStart3D2D(panel.__3d2dPos, panel.__3d2dAng, panel.__3d2dScale)
			
				panel:SetPaintedManually(false)
				panel:PaintManual()
				panel:SetPaintedManually(true)
				
				if panel.__hovered and not(panel.__cursor ~= "none" or panel.__cursor ~= "last" or
				panel.__cursor ~= "blank") then
					surface.SetMaterial(cursorMats[panel.__cursor])
					surface.SetDrawColor(255, 255, 255, 255)
					surface.DrawTexturedRect(cursorPosX, cursorPosY, 16, 16)
				end
			cEnd3D2D()
			
			rSetToneMappingScaleLinear(oldScale)
		end
		shouldDetourGuiPos = false
	end)

	--KEY CAPTURE
	local IN_USE = IN_USE
	local IN_RELOAD = IN_RELOAD
	local MOUSE_LEFT = MOUSE_LEFT
	local MOUSE_RIGHT = MOUSE_RIGHT
	
	local hCall = hook.Call
	hook.Add("KeyPress", "3D2DVGUI", function(_, key)
		if #activePanels ~= 0 then
			if (key == IN_USE) or (key == IN_RELOAD) then
				shouldDetourGuiPos = true
				for i = 1, #activePanels do
					panel = activePanels[i]
					if not visiblePanels[panel] then
						continue
					end
					if panel.__hovered then
						if key == IN_USE then
							handlePanelEvent(panel, "OnMousePressed", MOUSE_LEFT)
							hCall("VGUIMousePressed", GM,  pnl, MOUSE_LEFT)
						else
							handlePanelEvent(panel, "OnMousePressed", MOUSE_RIGHT)
							hCall("VGUIMousePressed", GM, pnl, MOUSE_RIGHT)
						end
					end
				end
				shouldDetourGuiPos = false
			end
		end
	end)			

	hook.Add("KeyRelease", "3D2DVGUI", function(_, key)
		if #activePanels ~= 0 then
			if (key == IN_USE) or (key == IN_RELOAD) then
				shouldDetourGuiPos = true
				for i = 1, #activePanels do
					panel = activePanels[i]
					if not visiblePanels[panel] then
						continue
					end
					
					if panel.__hovered then
						if key == IN_USE then
							handlePanelEvent(panel, "OnMouseReleased", MOUSE_LEFT)
						else
							handlePanelEvent(panel, "OnMouseReleased", MOUSE_RIGHT)
						end
					end
				end
				shouldDetourGuiPos = false
			end
		end
	end)
	
	--Scroll capture
	hook.Add("PlayerBindPress", "3D2DVGUI", function(_, bind, _)
		if #activePanels ~= 0 then
			if (bind == "invprev") or (bind == "invnext") then
				shouldDetourGuiPos = true
				for i = 1, #activePanels do
					panel = activePanels[i]
					if not visiblePanels[panel] then
						continue
					end
					if panel.__hovered then
						if bind == "invprev" then
							handlePanelEvent(panel, "OnMouseWheeled", -0.5)
						else
							handlePanelEvent(panel, "OnMouseWheeled", 0.5)
						end
					end
				end
				shouldDetourGuiPos = false
			end
		end
	end)
	
	
	local keyCache = {}
	for k, v in next, _G do--CACHE DAT TABLE
		if k:sub(0, 4) == "KEY_" then
			keyCache[v] = false
		end
	end

	local iIsKeyDown = input.IsKeyDown
	local keyState
	hook.Add("Think", "3D2DVGUI", function()
		if #activePanels ~= 0 then
			for i = 1, 159 do--159 is highest key
				keyState = iIsKeyDown(i)
				if keyState ~= keyCache[i] then
					if keyState then
						for i = 1, #activePanels do
							panel = activePanels[i]
							if not visiblePanels[panel] then
								continue
							end
							if panel.__hovered then
								handlePanelEvent(panel, "OnKeyCodePressed", i)
							end
						end
					else
						for i = 1, #activePanels do
							panel = activePanels[i]
							if not visiblePanels[panel] then
								continue
							end
							if panel.__hovered then
								handlePanelEvent(panel, "OnKeyCodeReleased", i)
							end
						end
					end
					keyCache[i] = keyState
				end
			end
		end
	end)

	--Panel Think detour to maintain functionality
	local function thinkOverride(self)
		shouldDetourGuiPos = true
		if self.__oldThink then
			self:__oldThink()
		end
		shouldDetourGuiPos = false
	end

	local function tableHasValue(val)
		for i = 1, #activePanels do
			if val == activePanels[i] then
				return i
			end
		end
		return false
	end


	--methodes
	local tremove = table.remove
	local tinsert = table.insert
	function _R.Panel:Set3D2D(b)
		if b then
			self.__3d2dPos = NULL_VEC
			self.__3d2dAng = NULL_ANG
			self.__3d2dScale = 1
			self.__3d2dExitEventCalled = false
			self.__3d2dFadeDistance = lib3d2d.fadeDistance
		else
			self.__3d2dPos = nil
			self.__3d2dAng = nil
			self.__3d2dScale = nil
			self.__3d2dExitEventCalled = nil
			self.__3d2dFadeDistance = nil
		end
		
		self:SetPaintedManually(b)--prevent 2d drawing
		
		local idx = false
		for i = 1, #activePanels do
			if val == activePanels[i] then
				idx = i
			end
		end
		
		if idx and not b then
			tremove(activePanels, idx)
			if self.__oldThink then
				self.Think = self.__oldThink
				self.__oldThink = nil
			end
		elseif not idx and b then
			tinsert(activePanels, self)
			if self.Think then
				self.__oldThink = self.Think
				self.Think = thinkOverride
			else
				self.Think = thinkOverride
				self.__oldThink = false
			end
		end
	end
	
	function _R.Panel:Set3D2DFadeDistance(distance)
		self.__3d2dFadeDistance = distance
	end

	function _R.Panel:Set3D2DPos(vec)
		self.__3d2dPos = vec
	end

	function _R.Panel:Set3D2DAng(ang)
		ang:RotateAroundAxis(ang:Forward(), 90)
		ang:RotateAroundAxis(ang:Right(), 90)
		self.__3d2dAng = ang
	end

	function _R.Panel:Set3D2DScale(s)
		self.__3d2dScale = s
	end
end

--recursive function to replace functions within cascading tables
local function removeDetours(tbl, base)
	local t
	for k, v in next, tbl do
		t = type(v)
		if t == "table" then
			if k == "_R" then
				removeDetours(v, debug.getregistry())
			else
				removeDetours(v, base[k])
			end
		elseif t == "function" then
			base[k] = v
		end
	end
end

function lib3d2d.disable()
	if not lib3d2d.active then
		return
	end
	lib3d2d.active = false
	
	lib3d2d.proxyTextEntryWrapper:Remove()
	
	for k, panel in next, lib3d2d.activePanels do
		if panel.__oldThink then
			panel.Think = panel.__oldThink
			panel.__oldThink = nil
		end
		panel.__3d2dPos = nil
		panel.__3d2dAng = nil
		panel.__3d2dScale = nil
		panel.__3d2dExitEventCalled = nil
		panel.__3d2dFadeDistance = nil
	end
	
	lib3d2d.activePanels = nil
	
	
	--unsetting methodes
	_R.Panel.Set3D2D = nil
	_R.Panel.Set3D2DPos = nil
	_R.Panel.Set3D2DAng = nil
	_R.Panel.Set3D2DScale = nil
	_R.Panel.Set3D2DParent = nil
	
	--removing hooks
	hook.Remove("CalcView", "3D2DVGUI")
	hook.Remove("PostDrawOpaqueRenderables", "3D2DVGUI")
	hook.Remove("KeyPress", "3D2DVGUI")
	hook.Remove("KeyRelease", "3D2DVGUI")
	hook.Remove("PlayerBindPress", "3D2DVGUI")
	hook.Remove("Think", "3D2DVGUI")
	hook.Remove("HUDPaint", "3D2DVGUI")
	
	removeDetours(lib3d2d.detours, _G)
end