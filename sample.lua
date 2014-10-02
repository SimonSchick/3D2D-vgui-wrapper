if lib3d2d then
	lib3d2d.disable()
end

include("lib3d2d.lua")

lib3d2d.enable()

local PANEL = {}

function PANEL:Init()
	self.LastWheel = 0
	self.LastExit = 0
	self.LastEnter = 0
	self.LastMove = 0
	self.LastClick = 0
	self.LastKeyPress = 0
	
	self.textField = vgui.Create("DTextEntry", self)
	self.textField:SetPos(60, 60)
end

function PANEL:Paint()
	local w, h = self:GetSize()
	surface.SetDrawColor(100,100,100,100)
	surface.DrawRect(0, 0, w, h)
	
	if self.__hovered then
		surface.SetDrawColor(255,0,0,255)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
	if (RealTime() - self.LastEnter) < 0.5 then
		surface.SetDrawColor(0, 255, 0, 255)
		surface.DrawOutlinedRect(1, 1, w-2, h-2)
	end
	if (RealTime() - self.LastExit) < 0.5 then
		surface.SetDrawColor(255, 255, 0, 255)
		surface.DrawOutlinedRect(2, 2, w-4, h-4)
	end
	if (RealTime() - self.LastWheel) < 0.5 then
		surface.SetDrawColor(255, 0, 255, 255)
		surface.DrawOutlinedRect(3, 3, w-6, h-6)
	end
	if (RealTime() - self.LastMove) < 0.5 then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(4, 4, w-8, h-8)
	end
	if (RealTime() - self.LastClick) < 0.5 then
		surface.SetDrawColor(0, 0, 255, 255)
		surface.DrawOutlinedRect(5, 5, w-10, h-10)
	end
	if (RealTime() - self.LastKeyPress) < 0.5 then
		surface.SetDrawColor(0, 255, 255, 255)
		surface.DrawOutlinedRect(6, 6, w-12, h-12)
	end
	surface.SetDrawColor(255, 0, 0, 255)
	surface.DrawRect(11, 11, (w-22)/2, (h-22)/2)
	
	surface.SetDrawColor(0, 0, 255, 255)
	surface.DrawRect(w/2, 11, (w-22)/2, (h-22)/2)
	
	surface.SetDrawColor(0, 255, 0, 255)
	surface.DrawRect(11, h/2, w-22, (h-22)/2)
	
	
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(gui.MouseX()-self.x, gui.MouseY()-self.y, 1, 1)
end

function PANEL:OnCursorEntered()
	self.LastEnter = RealTime()
end

function PANEL:OnCursorExited()
	self.LastExit = RealTime()
end

function PANEL:OnMouseWheeled()
	self.LastWheel = RealTime()
end

function PANEL:OnCursorMoved()
	self.LastMove = RealTime()
end

function PANEL:OnMousePressed()
	self.LastClick = RealTime()
end

function PANEL:OnKeyCodePressed(k)
	self.LastKeyPress = RealTime()
end

vgui.Register("3d2dTestPanel", PANEL, "EditablePanel")

if TESTFRAME then
	TESTFRAME:Remove()
end

TESTFRAME = vgui.Create("DFrame")
TESTFRAME:SetSize(200, 200)

TESTPNL = vgui.Create("3d2dTestPanel", TESTFRAME)
TESTPNL:StretchToParent(2, 20, 2, 2)

TESTBTN = vgui.Create("DButton", TESTPNL)
TESTBTN:SetPos(20, 20)
TESTBTN:SetSize(20, 20)

TESTFRAME:Set3D2D(true)
TESTFRAME:Set3D2DScale(0.2)
TESTFRAME:Set3D2DPos(LocalPlayer():GetPos())
TESTFRAME:Set3D2DAng(Angle(20,5,25))
--TESTFRAME:MakePopup()

