-- ================================================
-- RAILMASTER PRO v5.1 - VOLLSTÄNDIG FUNKTIONIEREND
-- Mit allen Tabs: Einstellungen, Discord, Stats
-- Türsteuerung: X (links), C (rechts), beide
-- INDIVIDUELLE BREMSSTARTDISTANZ PRO BAHNHOF
-- ================================================

-- // SERVICES // --
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- // ERWEITERTE KONFIGURATION // --
local Config = {
    -- Webhook
    Webhook = "",
    WebhookEvents = {
        StationStop = true,
        MoneyEarned = true,
        Errors = false,
        AutoPilotToggle = true,
        SystemStart = true
    },
    
    -- Stationen MIT INDIVIDUELLER BREMSDISTANZ
    Stations = {
        Station1 = {Position = nil, Name = "Bahnhof 1", Active = true, BrakeStartDistance = nil},
        Station2 = {Position = nil, Name = "Bahnhof 2", Active = true, BrakeStartDistance = nil},
        Station3 = {Position = nil, Name = "Bahnhof 3", Active = true, BrakeStartDistance = nil},
        Station4 = {Position = nil, Name = "Nebengleis", Active = false, BrakeStartDistance = nil}
    },
    
    -- Fahrtparameter
    BrakeStartDistance = 150,
    StopDistance = 5,
    WaitTimeAtStation = 10,
    DoorSide = 2, -- 0 = links (X), 1 = rechts (C), 2 = beide
    OpenDoors = true,
    HoldGasTime = 0.3,
    HoldBrakeTime = 0.3,
    
    -- Autopilot
    StopAtEveryStation = true,
    AutoStart = false,
    LoopRoute = true,
    RandomRoute = false,
    
    -- Sonstiges
    DebugMode = true,
    SoundNotifications = true,
    
    -- Neue Einstellungen
    SlowApproachSpeed = 0.15 -- Langsame Annäherung wenn zu früh gestoppt
}

-- // VARIABLEN // --
local IsRunning = false
local TotalMoney = 0
local TripsCompleted = 0
local TotalDistance = 0
local CurrentStationIndex = 1
local AutoPilotThread = nil
local ScreenGui = nil
local CurrentTab = "Autopilot"
local IsGuiVisible = true
local EmergencyBrake = false
local LastPosition = nil
local LastDistance = nil
local IsBraking = false
local StationSkipped = false

-- Statistik Tracking
local Stats = {
    StartTime = os.time(),
    LastTripTime = 0,
    MoneyPerHour = 0,
    TripsPerHour = 0,
    StationVisits = {0, 0, 0, 0}
}

-- // NEUE FUNKTION: INDIVIDUELLE BREMSDISTANZ ABRUFEN // --
function GetBrakeDistanceForStation(stationIndex)
    local station = Config.Stations["Station" .. stationIndex]
    if station and station.BrakeStartDistance and station.BrakeStartDistance > 0 then
        return station.BrakeStartDistance
    end
    return Config.BrakeStartDistance
end

-- // GUI ERSTELLUNG // --
function CreateGUI()
    if ScreenGui then ScreenGui:Destroy() end
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RailMasterGUI"
    ScreenGui.Parent = game.CoreGui
    ScreenGui.ResetOnSpawn = false
    
    -- Hauptframe
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 450, 0, 600)
    MainFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 2
    MainFrame.BorderColor3 = Color3.fromRGB(60, 60, 80)
    MainFrame.Parent = ScreenGui
    
    -- Titel mit Drag-Funktion
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Text = "🚂 RAILMASTER PRO v5.1"
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Position = UDim2.new(0, 0, 0, 0)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 20
    Title.Parent = MainFrame
    
    -- Tab Buttons (MIT NEUEM BREMSDISTANZ TAB)
    local TabContainer = Instance.new("Frame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(1, 0, 0, 40)
    TabContainer.Position = UDim2.new(0, 0, 0, 40)
    TabContainer.BackgroundTransparency = 1
    TabContainer.Parent = MainFrame
    
    local Tabs = {
        {Name = "Autopilot", Color = Color3.fromRGB(0, 120, 215)},
        {Name = "Haltestellen", Color = Color3.fromRGB(215, 120, 0)},
        {Name = "Bremsdistanz", Color = Color3.fromRGB(170, 0, 170)},  -- NEUER TAB
        {Name = "Einstellungen", Color = Color3.fromRGB(0, 170, 0)},
        {Name = "Discord", Color = Color3.fromRGB(170, 0, 170)},
        {Name = "Stats", Color = Color3.fromRGB(170, 170, 0)}
    }
    
    for i, tab in ipairs(Tabs) do
        local TabButton = Instance.new("TextButton")
        TabButton.Name = tab.Name .. "Tab"
        TabButton.Text = tab.Name
        TabButton.Size = UDim2.new(0.166, -2, 1, 0)
        TabButton.Position = UDim2.new((i-1) * 0.166, 0, 0, 0)
        TabButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        TabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        TabButton.Font = Enum.Font.Gotham
        TabButton.TextSize = 12
        TabButton.BorderSizePixel = 0
        TabButton.Parent = TabContainer
        
        TabButton.MouseButton1Click:Connect(function()
            SwitchTab(tab.Name)
        end)
    end
    
    -- Content Area mit Scroll
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, -10, 1, -130)
    ContentFrame.Position = UDim2.new(0, 5, 0, 90)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.ScrollBarThickness = 8
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 1000)
    ContentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    ContentFrame.Parent = MainFrame
    
    -- Status Bar
    local StatusBar = Instance.new("Frame")
    StatusBar.Name = "StatusBar"
    StatusBar.Size = UDim2.new(1, 0, 0, 50)
    StatusBar.Position = UDim2.new(0, 0, 1, -50)
    StatusBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    StatusBar.Parent = MainFrame
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Text = "🟡 BEREIT"
    StatusLabel.Size = UDim2.new(0.5, 0, 0.5, 0)
    StatusLabel.Position = UDim2.new(0, 10, 0, 5)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextSize = 14
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusBar
    
    local MoneyLabel = Instance.new("TextLabel")
    MoneyLabel.Name = "MoneyLabel"
    MoneyLabel.Text = "💰 0€"
    MoneyLabel.Size = UDim2.new(0.5, -10, 0.5, 0)
    MoneyLabel.Position = UDim2.new(0.5, 0, 0, 5)
    MoneyLabel.BackgroundTransparency = 1
    MoneyLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    MoneyLabel.Font = Enum.Font.GothamBold
    MoneyLabel.TextSize = 14
    MoneyLabel.TextXAlignment = Enum.TextXAlignment.Right
    MoneyLabel.Parent = StatusBar
    
    local ActionLabel = Instance.new("TextLabel")
    ActionLabel.Name = "ActionLabel"
    ActionLabel.Text = "Aktion: Warte auf Start"
    ActionLabel.Size = UDim2.new(1, -20, 0.5, 0)
    ActionLabel.Position = UDim2.new(0, 10, 0.5, 0)
    ActionLabel.BackgroundTransparency = 1
    ActionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    ActionLabel.Font = Enum.Font.Gotham
    ActionLabel.TextSize = 12
    ActionLabel.TextXAlignment = Enum.TextXAlignment.Left
    ActionLabel.Parent = StatusBar
    
    -- Tab Inhalte erstellen
    CreateTabContents(ContentFrame)
    
    -- Initialen Tab anzeigen
    SwitchTab("Autopilot")
    
    return ScreenGui
end

function CreateTabContents(parent)
    -- AUTOPILOT TAB
    local AutoPilotFrame = Instance.new("Frame")
    AutoPilotFrame.Name = "AutopilotFrame"
    AutoPilotFrame.Size = UDim2.new(1, 0, 0, 300)
    AutoPilotFrame.Position = UDim2.new(0, 0, 0, 0)
    AutoPilotFrame.BackgroundTransparency = 1
    AutoPilotFrame.Visible = false
    AutoPilotFrame.Parent = parent
    
    -- Start/Stop Button
    local StartStopBtn = Instance.new("TextButton")
    StartStopBtn.Name = "StartStopBtn"
    StartStopBtn.Text = "🚂 AUTOPILOT STARTEN"
    StartStopBtn.Size = UDim2.new(1, -20, 0, 50)
    StartStopBtn.Position = UDim2.new(0, 10, 0, 10)
    StartStopBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    StartStopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartStopBtn.Font = Enum.Font.GothamBold
    StartStopBtn.TextSize = 16
    StartStopBtn.Parent = AutoPilotFrame
    
    -- Notstop Button
    local EmergencyBtn = Instance.new("TextButton")
    EmergencyBtn.Name = "EmergencyBtn"
    EmergencyBtn.Text = "🛑 NOTSTOPP"
    EmergencyBtn.Size = UDim2.new(1, -20, 0, 40)
    EmergencyBtn.Position = UDim2.new(0, 10, 0, 70)
    EmergencyBtn.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
    EmergencyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    EmergencyBtn.Font = Enum.Font.Gotham
    EmergencyBtn.TextSize = 14
    EmergencyBtn.Parent = AutoPilotFrame
    
    -- Info Labels
    local NextStationLabel = Instance.new("TextLabel")
    NextStationLabel.Name = "NextStationLabel"
    NextStationLabel.Text = "Nächster Halt: --"
    NextStationLabel.Size = UDim2.new(1, -20, 0, 30)
    NextStationLabel.Position = UDim2.new(0, 10, 0, 120)
    NextStationLabel.BackgroundTransparency = 1
    NextStationLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    NextStationLabel.Font = Enum.Font.Gotham
    NextStationLabel.TextSize = 14
    NextStationLabel.TextXAlignment = Enum.TextXAlignment.Left
    NextStationLabel.Parent = AutoPilotFrame
    
    local SpeedLabel = Instance.new("TextLabel")
    SpeedLabel.Name = "SpeedLabel"
    SpeedLabel.Text = "Geschwindigkeit: --"
    SpeedLabel.Size = UDim2.new(1, -20, 0, 30)
    SpeedLabel.Position = UDim2.new(0, 10, 0, 155)
    SpeedLabel.BackgroundTransparency = 1
    SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SpeedLabel.Font = Enum.Font.Gotham
    SpeedLabel.TextSize = 14
    SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    SpeedLabel.Parent = AutoPilotFrame
    
    local InfoText = Instance.new("TextLabel")
    InfoText.Name = "InfoText"
    InfoText.Text = "ℹ️  W = Gas | S = Bremsen | X/C = Türen\n🔧 Drücke F1 um GUI zu verstecken"
    InfoText.Size = UDim2.new(1, -20, 0, 60)
    InfoText.Position = UDim2.new(0, 10, 0, 200)
    InfoText.BackgroundTransparency = 1
    InfoText.TextColor3 = Color3.fromRGB(150, 150, 200)
    InfoText.Font = Enum.Font.Gotham
    InfoText.TextSize = 12
    InfoText.TextWrapped = true
    InfoText.TextXAlignment = Enum.TextXAlignment.Left
    InfoText.Parent = AutoPilotFrame
    
    -- HALTESTELLEN TAB
    local StationsFrame = Instance.new("Frame")
    StationsFrame.Name = "HaltestellenFrame"
    StationsFrame.Size = UDim2.new(1, 0, 0, 400)
    StationsFrame.Position = UDim2.new(0, 0, 0, 0)
    StationsFrame.BackgroundTransparency = 1
    StationsFrame.Visible = false
    StationsFrame.Parent = parent
    
    for i = 1, 4 do
        local yPos = 10 + (i-1) * 80
        
        -- FIX: Sicherstellen, dass die Station existiert
        local stationData = Config.Stations["Station" .. i]
        local stationName = stationData and stationData.Name or "Unbenannt"
        
        local StationBtn = Instance.new("TextButton")
        StationBtn.Name = "StationBtn" .. i
        StationBtn.Text = "📍 Haltestelle " .. i .. ": " .. stationName
        StationBtn.Size = UDim2.new(1, -20, 0, 40)
        StationBtn.Position = UDim2.new(0, 10, 0, yPos)
        StationBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 200)
        StationBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        StationBtn.Font = Enum.Font.Gotham
        StationBtn.TextSize = 14
        StationBtn.Parent = StationsFrame
        
        local StatusLabel = Instance.new("TextLabel")
        StatusLabel.Name = "StationStatus" .. i
        StatusLabel.Text = "Nicht gespeichert"
        StatusLabel.Size = UDim2.new(1, -20, 0, 30)
        StatusLabel.Position = UDim2.new(0, 10, 0, yPos + 45)
        StatusLabel.BackgroundTransparency = 1
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        StatusLabel.Font = Enum.Font.Gotham
        StatusLabel.TextSize = 12
        StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        StatusLabel.Parent = StationsFrame
    end
    
    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Name = "ClearBtn"
    ClearBtn.Text = "🗑️ Alle löschen"
    ClearBtn.Size = UDim2.new(1, -20, 0, 40)
    ClearBtn.Position = UDim2.new(0, 10, 0, 340)
    ClearBtn.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
    ClearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearBtn.Font = Enum.Font.Gotham
    ClearBtn.TextSize = 14
    ClearBtn.Parent = StationsFrame
    
    -- NEUER BREMSDISTANZ TAB
    local BrakeDistFrame = Instance.new("Frame")
    BrakeDistFrame.Name = "BremsdistanzFrame"
    BrakeDistFrame.Size = UDim2.new(1, 0, 0, 500)
    BrakeDistFrame.Position = UDim2.new(0, 0, 0, 0)
    BrakeDistFrame.BackgroundTransparency = 1
    BrakeDistFrame.Visible = false
    BrakeDistFrame.Parent = parent
    
    local BrakeDistTitle = Instance.new("TextLabel")
    BrakeDistTitle.Name = "BrakeDistTitle"
    BrakeDistTitle.Text = "⚡ INDIVIDUELLE BREMSDISTANZ PRO BAHNHOF"
    BrakeDistTitle.Size = UDim2.new(1, -20, 0, 40)
    BrakeDistTitle.Position = UDim2.new(0, 10, 0, 10)
    BrakeDistTitle.BackgroundTransparency = 1
    BrakeDistTitle.TextColor3 = Color3.fromRGB(255, 200, 0)
    BrakeDistTitle.Font = Enum.Font.GothamBold
    BrakeDistTitle.TextSize = 16
    BrakeDistTitle.TextXAlignment = Enum.TextXAlignment.Left
    BrakeDistTitle.Parent = BrakeDistFrame
    
    local GlobalInfo = Instance.new("TextLabel")
    GlobalInfo.Name = "GlobalInfo"
    GlobalInfo.Text = "Globale Distanz: " .. Config.BrakeStartDistance .. " Studs (für Bahnhöfe ohne individuelle Einstellung)"
    GlobalInfo.Size = UDim2.new(1, -20, 0, 30)
    GlobalInfo.Position = UDim2.new(0, 10, 0, 60)
    GlobalInfo.BackgroundTransparency = 1
    GlobalInfo.TextColor3 = Color3.fromRGB(150, 200, 255)
    GlobalInfo.Font = Enum.Font.Gotham
    GlobalInfo.TextSize = 12
    GlobalInfo.TextXAlignment = Enum.TextXAlignment.Left
    GlobalInfo.Parent = BrakeDistFrame
    
    -- Für jeden Bahnhof eine Einstellung
    for i = 1, 4 do
        local station = Config.Stations["Station" .. i]
        local stationName = station and station.Name or "Haltestelle " .. i
        
        local stationLabel = Instance.new("TextLabel")
        stationLabel.Name = "StationLabel" .. i
        stationLabel.Text = "🚉 " .. stationName .. ":"
        stationLabel.Size = UDim2.new(1, -20, 0, 25)
        stationLabel.Position = UDim2.new(0, 10, 0, 100 + (i-1) * 70)
        stationLabel.BackgroundTransparency = 1
        stationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        stationLabel.Font = Enum.Font.Gotham
        stationLabel.TextSize = 14
        stationLabel.TextXAlignment = Enum.TextXAlignment.Left
        stationLabel.Parent = BrakeDistFrame
        
        local brakeInput = Instance.new("TextBox")
        brakeInput.Name = "BrakeInput" .. i
        brakeInput.Text = station and station.BrakeStartDistance and tostring(station.BrakeStartDistance) or ""
        brakeInput.Size = UDim2.new(0.4, -5, 0, 30)
        brakeInput.Position = UDim2.new(0, 10, 0, 125 + (i-1) * 70)
        brakeInput.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        brakeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        brakeInput.Font = Enum.Font.Gotham
        brakeInput.TextSize = 14
        brakeInput.PlaceholderText = "Studs (50-800) - leer = global"
        brakeInput.Parent = BrakeDistFrame
        
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "ValueLabel" .. i
        valueLabel.Text = station and station.BrakeStartDistance and ("Aktiv: " .. station.BrakeStartDistance .. " Studs") or "Verwendet global: " .. Config.BrakeStartDistance .. " Studs"
        valueLabel.Size = UDim2.new(0.5, -5, 0, 30)
        valueLabel.Position = UDim2.new(0.45, 0, 0, 125 + (i-1) * 70)
        valueLabel.BackgroundTransparency = 1
        valueLabel.TextColor3 = station and station.BrakeStartDistance and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(150, 150, 150)
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 12
        valueLabel.TextXAlignment = Enum.TextXAlignment.Left
        valueLabel.Parent = BrakeDistFrame
        
        -- Reset Button
        local resetBtn = Instance.new("TextButton")
        resetBtn.Name = "ResetBtn" .. i
        resetBtn.Text = "↺"
        resetBtn.Size = UDim2.new(0, 30, 0, 30)
        resetBtn.Position = UDim2.new(0.95, -30, 0, 125 + (i-1) * 70)
        resetBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        resetBtn.Font = Enum.Font.GothamBold
        resetBtn.TextSize = 16
        resetBtn.Parent = BrakeDistFrame
    end
    
    local SaveBtn = Instance.new("TextButton")
    SaveBtn.Name = "SaveBrakeDistBtn"
    SaveBtn.Text = "💾 BREMSDISTANZEN SPEICHERN"
    SaveBtn.Size = UDim2.new(1, -20, 0, 45)
    SaveBtn.Position = UDim2.new(0, 10, 0, 380)
    SaveBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
    SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveBtn.Font = Enum.Font.GothamBold
    SaveBtn.TextSize = 16
    SaveBtn.Parent = BrakeDistFrame
    
    local ResetAllBtn = Instance.new("TextButton")
    ResetAllBtn.Name = "ResetAllBrakeBtn"
    ResetAllBtn.Text = "🗑️ ALLE INDIVIDUELLEN LÖSCHEN"
    ResetAllBtn.Size = UDim2.new(1, -20, 0, 40)
    ResetAllBtn.Position = UDim2.new(0, 10, 0, 435)
    ResetAllBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    ResetAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResetAllBtn.Font = Enum.Font.Gotham
    ResetAllBtn.TextSize = 14
    ResetAllBtn.Parent = BrakeDistFrame
    
    -- EINSTELLUNGEN TAB
    local SettingsFrame = Instance.new("Frame")
    SettingsFrame.Name = "EinstellungenFrame"
    SettingsFrame.Size = UDim2.new(1, 0, 0, 850)
    SettingsFrame.Position = UDim2.new(0, 0, 0, 0)
    SettingsFrame.BackgroundTransparency = 1
    SettingsFrame.Visible = false
    SettingsFrame.Parent = parent
    
    -- Fahrtparameter Section
    local FahrParamsLabel = Instance.new("TextLabel")
    FahrParamsLabel.Name = "FahrParamsLabel"
    FahrParamsLabel.Text = "⚙️ FAHRTPARAMETER"
    FahrParamsLabel.Size = UDim2.new(1, -20, 0, 30)
    FahrParamsLabel.Position = UDim2.new(0, 10, 0, 10)
    FahrParamsLabel.BackgroundTransparency = 1
    FahrParamsLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    FahrParamsLabel.Font = Enum.Font.GothamBold
    FahrParamsLabel.TextSize = 16
    FahrParamsLabel.TextXAlignment = Enum.TextXAlignment.Left
    FahrParamsLabel.Parent = SettingsFrame
    
    -- Brems-Startdistanz Slider (GLOBALE EINSTELLUNG)
    local BrakeDistLabel = Instance.new("TextLabel")
    BrakeDistLabel.Name = "BrakeDistLabel"
    BrakeDistLabel.Text = "Globale Brems-Startdistanz: " .. Config.BrakeStartDistance .. " Studs"
    BrakeDistLabel.Size = UDim2.new(1, -20, 0, 25)
    BrakeDistLabel.Position = UDim2.new(0, 10, 0, 50)
    BrakeDistLabel.BackgroundTransparency = 1
    BrakeDistLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    BrakeDistLabel.Font = Enum.Font.Gotham
    BrakeDistLabel.TextSize = 14
    BrakeDistLabel.TextXAlignment = Enum.TextXAlignment.Left
    BrakeDistLabel.Parent = SettingsFrame
    
    local BrakeDistSlider = Instance.new("TextBox")
    BrakeDistSlider.Name = "BrakeDistSlider"
    BrakeDistSlider.Text = tostring(Config.BrakeStartDistance)
    BrakeDistSlider.Size = UDim2.new(1, -20, 0, 30)
    BrakeDistSlider.Position = UDim2.new(0, 10, 0, 75)
    BrakeDistSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    BrakeDistSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    BrakeDistSlider.Font = Enum.Font.Gotham
    BrakeDistSlider.TextSize = 14
    BrakeDistSlider.PlaceholderText = "Studs (50-500)"
    BrakeDistSlider.Parent = SettingsFrame
    
    -- Stop-Genauigkeit
    local StopDistLabel = Instance.new("TextLabel")
    StopDistLabel.Name = "StopDistLabel"
    StopDistLabel.Text = "Stop-Genauigkeit: " .. Config.StopDistance .. " Studs"
    StopDistLabel.Size = UDim2.new(1, -20, 0, 25)
    StopDistLabel.Position = UDim2.new(0, 10, 0, 115)
    StopDistLabel.BackgroundTransparency = 1
    StopDistLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StopDistLabel.Font = Enum.Font.Gotham
    StopDistLabel.TextSize = 14
    StopDistLabel.TextXAlignment = Enum.TextXAlignment.Left
    StopDistLabel.Parent = SettingsFrame
    
    local StopDistSlider = Instance.new("TextBox")
    StopDistSlider.Name = "StopDistSlider"
    StopDistSlider.Text = tostring(Config.StopDistance)
    StopDistSlider.Size = UDim2.new(1, -20, 0, 30)
    StopDistSlider.Position = UDim2.new(0, 10, 0, 140)
    StopDistSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    StopDistSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopDistSlider.Font = Enum.Font.Gotham
    StopDistSlider.TextSize = 14
    StopDistSlider.PlaceholderText = "Studs (1-20)"
    StopDistSlider.Parent = SettingsFrame
    
    -- Wartezeit an Station
    local WaitTimeLabel = Instance.new("TextLabel")
    WaitTimeLabel.Name = "WaitTimeLabel"
    WaitTimeLabel.Text = "Wartezeit an Station: " .. Config.WaitTimeAtStation .. "s"
    WaitTimeLabel.Size = UDim2.new(1, -20, 0, 25)
    WaitTimeLabel.Position = UDim2.new(0, 10, 0, 180)
    WaitTimeLabel.BackgroundTransparency = 1
    WaitTimeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    WaitTimeLabel.Font = Enum.Font.Gotham
    WaitTimeLabel.TextSize = 14
    WaitTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
    WaitTimeLabel.Parent = SettingsFrame
    
    local WaitTimeSlider = Instance.new("TextBox")
    WaitTimeSlider.Name = "WaitTimeSlider"
    WaitTimeSlider.Text = tostring(Config.WaitTimeAtStation)
    WaitTimeSlider.Size = UDim2.new(1, -20, 0, 30)
    WaitTimeSlider.Position = UDim2.new(0, 10, 0, 205)
    WaitTimeSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    WaitTimeSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    WaitTimeSlider.Font = Enum.Font.Gotham
    WaitTimeSlider.TextSize = 14
    WaitTimeSlider.PlaceholderText = "Sekunden (0-60)"
    WaitTimeSlider.Parent = SettingsFrame
    
    -- Langsame Annäherung
    local SlowSpeedLabel = Instance.new("TextLabel")
    SlowSpeedLabel.Name = "SlowSpeedLabel"
    SlowSpeedLabel.Text = "Langsame Annäherung: " .. (Config.SlowApproachSpeed or "0.1")
    SlowSpeedLabel.Size = UDim2.new(1, -20, 0, 25)
    SlowSpeedLabel.Position = UDim2.new(0, 10, 0, 245)
    SlowSpeedLabel.BackgroundTransparency = 1
    SlowSpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SlowSpeedLabel.Font = Enum.Font.Gotham
    SlowSpeedLabel.TextSize = 14
    SlowSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    SlowSpeedLabel.Parent = SettingsFrame
    
    local SlowSpeedSlider = Instance.new("TextBox")
    SlowSpeedSlider.Name = "SlowSpeedSlider"
    SlowSpeedSlider.Text = tostring(Config.SlowApproachSpeed or 0.1)
    SlowSpeedSlider.Size = UDim2.new(1, -20, 0, 30)
    SlowSpeedSlider.Position = UDim2.new(0, 10, 0, 270)
    SlowSpeedSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    SlowSpeedSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
    SlowSpeedSlider.Font = Enum.Font.Gotham
    SlowSpeedSlider.TextSize = 14
    SlowSpeedSlider.PlaceholderText = "Geschwindigkeit (0.05-0.5)"
    SlowSpeedSlider.Parent = SettingsFrame

    -- Türsteuerung Section
    local DoorSettingsLabel = Instance.new("TextLabel")
    DoorSettingsLabel.Name = "DoorSettingsLabel"
    DoorSettingsLabel.Text = "🚪 TÜRSTEUERUNG"
    DoorSettingsLabel.Size = UDim2.new(1, -20, 0, 30)
    DoorSettingsLabel.Position = UDim2.new(0, 10, 0, 315)
    DoorSettingsLabel.BackgroundTransparency = 1
    DoorSettingsLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    DoorSettingsLabel.Font = Enum.Font.GothamBold
    DoorSettingsLabel.TextSize = 16
    DoorSettingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    DoorSettingsLabel.Parent = SettingsFrame
    
    -- Türen öffnen Toggle
    local OpenDoorsToggle = Instance.new("TextButton")
    OpenDoorsToggle.Name = "OpenDoorsToggle"
    OpenDoorsToggle.Text = "Türen öffnen: " .. (Config.OpenDoors and "✅ AN" or "❌ AUS")
    OpenDoorsToggle.Size = UDim2.new(1, -20, 0, 40)
    OpenDoorsToggle.Position = UDim2.new(0, 10, 0, 355)
    OpenDoorsToggle.BackgroundColor3 = Config.OpenDoors and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    OpenDoorsToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    OpenDoorsToggle.Font = Enum.Font.Gotham
    OpenDoorsToggle.TextSize = 14
    OpenDoorsToggle.Parent = SettingsFrame
    
    -- Türseite Auswahl
    local DoorSideLabel = Instance.new("TextLabel")
    DoorSideLabel.Name = "DoorSideLabel"
    DoorSideLabel.Text = "Türseite: " .. (Config.DoorSide == 0 and "Links (X)" or Config.DoorSide == 1 and "Rechts (C)" or "Beide")
    DoorSideLabel.Size = UDim2.new(1, -20, 0, 25)
    DoorSideLabel.Position = UDim2.new(0, 10, 0, 405)
    DoorSideLabel.BackgroundTransparency = 1
    DoorSideLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    DoorSideLabel.Font = Enum.Font.Gotham
    DoorSideLabel.TextSize = 14
    DoorSideLabel.TextXAlignment = Enum.TextXAlignment.Left
    DoorSideLabel.Parent = SettingsFrame
    
    local DoorSideLeft = Instance.new("TextButton")
    DoorSideLeft.Name = "DoorSideLeft"
    DoorSideLeft.Text = "Links (X)"
    DoorSideLeft.Size = UDim2.new(0.3, -5, 0, 30)
    DoorSideLeft.Position = UDim2.new(0, 10, 0, 435)
    DoorSideLeft.BackgroundColor3 = Config.DoorSide == 0 and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(60, 60, 80)
    DoorSideLeft.TextColor3 = Color3.fromRGB(255, 255, 255)
    DoorSideLeft.Font = Enum.Font.Gotham
    DoorSideLeft.TextSize = 12
    DoorSideLeft.Parent = SettingsFrame
    
    local DoorSideRight = Instance.new("TextButton")
    DoorSideRight.Name = "DoorSideRight"
    DoorSideRight.Text = "Rechts (C)"
    DoorSideRight.Size = UDim2.new(0.3, -5, 0, 30)
    DoorSideRight.Position = UDim2.new(0.35, 0, 0, 435)
    DoorSideRight.BackgroundColor3 = Config.DoorSide == 1 and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(60, 60, 80)
    DoorSideRight.TextColor3 = Color3.fromRGB(255, 255, 255)
    DoorSideRight.Font = Enum.Font.Gotham
    DoorSideRight.TextSize = 12
    DoorSideRight.Parent = SettingsFrame
    
    local DoorSideBoth = Instance.new("TextButton")
    DoorSideBoth.Name = "DoorSideBoth"
    DoorSideBoth.Text = "Beide"
    DoorSideBoth.Size = UDim2.new(0.3, -5, 0, 30)
    DoorSideBoth.Position = UDim2.new(0.7, 0, 0, 435)
    DoorSideBoth.BackgroundColor3 = Config.DoorSide == 2 and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(60, 60, 80)
    DoorSideBoth.TextColor3 = Color3.fromRGB(255, 255, 255)
    DoorSideBoth.Font = Enum.Font.Gotham
    DoorSideBoth.TextSize = 12
    DoorSideBoth.Parent = SettingsFrame
    
    -- Autopilot Einstellungen Section
    local AutoPilotSettingsLabel = Instance.new("TextLabel")
    AutoPilotSettingsLabel.Name = "AutoPilotSettingsLabel"
    AutoPilotSettingsLabel.Text = "🤖 AUTOPILOT EINSTELLUNGEN"
    AutoPilotSettingsLabel.Size = UDim2.new(1, -20, 0, 30)
    AutoPilotSettingsLabel.Position = UDim2.new(0, 10, 0, 485)
    AutoPilotSettingsLabel.BackgroundTransparency = 1
    AutoPilotSettingsLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    AutoPilotSettingsLabel.Font = Enum.Font.GothamBold
    AutoPilotSettingsLabel.TextSize = 16
    AutoPilotSettingsLabel.TextXAlignment = Enum.TextXAlignment.Left
    AutoPilotSettingsLabel.Parent = SettingsFrame
    
    -- An jeder Station halten
    local StopEveryStationToggle = Instance.new("TextButton")
    StopEveryStationToggle.Name = "StopEveryStationToggle"
    StopEveryStationToggle.Text = "An jeder Station halten: " .. (Config.StopAtEveryStation and "✅ AN" or "❌ AUS")
    StopEveryStationToggle.Size = UDim2.new(1, -20, 0, 40)
    StopEveryStationToggle.Position = UDim2.new(0, 10, 0, 525)
    StopEveryStationToggle.BackgroundColor3 = Config.StopAtEveryStation and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    StopEveryStationToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopEveryStationToggle.Font = Enum.Font.Gotham
    StopEveryStationToggle.TextSize = 14
    StopEveryStationToggle.Parent = SettingsFrame
    
    -- Auto-Start
    local AutoStartToggle = Instance.new("TextButton")
    AutoStartToggle.Name = "AutoStartToggle"
    AutoStartToggle.Text = "Auto-Start: " .. (Config.AutoStart and "✅ AN" or "❌ AUS")
    AutoStartToggle.Size = UDim2.new(1, -20, 0, 40)
    AutoStartToggle.Position = UDim2.new(0, 10, 0, 575)
    AutoStartToggle.BackgroundColor3 = Config.AutoStart and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    AutoStartToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoStartToggle.Font = Enum.Font.Gotham
    AutoStartToggle.TextSize = 14
    AutoStartToggle.Parent = SettingsFrame
    
    -- Debug Modus
    local DebugToggle = Instance.new("TextButton")
    DebugToggle.Name = "DebugToggle"
    DebugToggle.Text = "Debug Modus: " .. (Config.DebugMode and "✅ AN" or "❌ AUS")
    DebugToggle.Size = UDim2.new(1, -20, 0, 40)
    DebugToggle.Position = UDim2.new(0, 10, 0, 625)
    DebugToggle.BackgroundColor3 = Config.DebugMode and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    DebugToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    DebugToggle.Font = Enum.Font.Gotham
    DebugToggle.TextSize = 14
    DebugToggle.Parent = SettingsFrame
    
    -- Script Beenden Button
    local ExitScriptBtn = Instance.new("TextButton")
    ExitScriptBtn.Name = "ExitScriptBtn"
    ExitScriptBtn.Text = "⚠️ SCRIPT BEENDEN"
    ExitScriptBtn.Size = UDim2.new(1, -20, 0, 45)
    ExitScriptBtn.Position = UDim2.new(0, 10, 0, 685)
    ExitScriptBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    ExitScriptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ExitScriptBtn.Font = Enum.Font.GothamBold
    ExitScriptBtn.TextSize = 16
    ExitScriptBtn.Parent = SettingsFrame
    
    -- Save Button
    local SaveSettingsBtn = Instance.new("TextButton")
    SaveSettingsBtn.Name = "SaveSettingsBtn"
    SaveSettingsBtn.Text = "💾 EINSTELLUNGEN SPEICHERN"
    SaveSettingsBtn.Size = UDim2.new(1, -20, 0, 45)
    SaveSettingsBtn.Position = UDim2.new(0, 10, 0, 740)
    SaveSettingsBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    SaveSettingsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveSettingsBtn.Font = Enum.Font.GothamBold
    SaveSettingsBtn.TextSize = 16
    SaveSettingsBtn.Parent = SettingsFrame
    
    -- Discord TAB
    local DiscordFrame = Instance.new("Frame")
    DiscordFrame.Name = "DiscordFrame"
    DiscordFrame.Size = UDim2.new(1, 0, 0, 400)
    DiscordFrame.Position = UDim2.new(0, 0, 0, 0)
    DiscordFrame.BackgroundTransparency = 1
    DiscordFrame.Visible = false
    DiscordFrame.Parent = parent
    
    -- Webhook URL
    local WebhookLabel = Instance.new("TextLabel")
    WebhookLabel.Name = "WebhookLabel"
    WebhookLabel.Text = "🔗 DISCORD WEBHOOK URL"
    WebhookLabel.Size = UDim2.new(1, -20, 0, 30)
    WebhookLabel.Position = UDim2.new(0, 10, 0, 10)
    WebhookLabel.BackgroundTransparency = 1
    WebhookLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    WebhookLabel.Font = Enum.Font.GothamBold
    WebhookLabel.TextSize = 16
    WebhookLabel.TextXAlignment = Enum.TextXAlignment.Left
    WebhookLabel.Parent = DiscordFrame
    
    local WebhookInput = Instance.new("TextBox")
    WebhookInput.Name = "WebhookInput"
    WebhookInput.Text = Config.Webhook
    WebhookInput.Size = UDim2.new(1, -20, 0, 40)
    WebhookInput.Position = UDim2.new(0, 10, 0, 50)
    WebhookInput.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    WebhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookInput.Font = Enum.Font.Gotham
    WebhookInput.TextSize = 14
    WebhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
    WebhookInput.Parent = DiscordFrame
    
    -- Webhook Events
    local EventsLabel = Instance.new("TextLabel")
    EventsLabel.Name = "EventsLabel"
    EventsLabel.Text = "🔔 BENACHRICHTIGUNGEN"
    EventsLabel.Size = UDim2.new(1, -20, 0, 30)
    EventsLabel.Position = UDim2.new(0, 10, 0, 110)
    EventsLabel.BackgroundTransparency = 1
    EventsLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    EventsLabel.Font = Enum.Font.GothamBold
    EventsLabel.TextSize = 16
    EventsLabel.TextXAlignment = Enum.TextXAlignment.Left
    EventsLabel.Parent = DiscordFrame
    
    local EventMoneyToggle = Instance.new("TextButton")
    EventMoneyToggle.Name = "EventMoneyToggle"
    EventMoneyToggle.Text = "💰 Geld verdient (+350€): " .. (Config.WebhookEvents.MoneyEarned and "✅ AN" or "❌ AUS")
    EventMoneyToggle.Size = UDim2.new(1, -20, 0, 35)
    EventMoneyToggle.Position = UDim2.new(0, 10, 0, 150)
    EventMoneyToggle.BackgroundColor3 = Config.WebhookEvents.MoneyEarned and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    EventMoneyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    EventMoneyToggle.Font = Enum.Font.Gotham
    EventMoneyToggle.TextSize = 12
    EventMoneyToggle.Parent = DiscordFrame
    
    local EventAutoToggle = Instance.new("TextButton")
    EventAutoToggle.Name = "EventAutoToggle"
    EventAutoToggle.Text = "🚂 Autopilot Start/Stop: " .. (Config.WebhookEvents.AutoPilotToggle and "✅ AN" or "❌ AUS")
    EventAutoToggle.Size = UDim2.new(1, -20, 0, 35)
    EventAutoToggle.Position = UDim2.new(0, 10, 0, 195)
    EventAutoToggle.BackgroundColor3 = Config.WebhookEvents.AutoPilotToggle and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    EventAutoToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    EventAutoToggle.Font = Enum.Font.Gotham
    EventAutoToggle.TextSize = 12
    EventAutoToggle.Parent = DiscordFrame
    
    local EventSystemToggle = Instance.new("TextButton")
    EventSystemToggle.Name = "EventSystemToggle"
    EventSystemToggle.Text = "⚙️ System Start: " .. (Config.WebhookEvents.SystemStart and "✅ AN" or "❌ AUS")
    EventSystemToggle.Size = UDim2.new(1, -20, 0, 35)
    EventSystemToggle.Position = UDim2.new(0, 10, 0, 240)
    EventSystemToggle.BackgroundColor3 = Config.WebhookEvents.SystemStart and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    EventSystemToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    EventSystemToggle.Font = Enum.Font.Gotham
    EventSystemToggle.TextSize = 12
    EventSystemToggle.Parent = DiscordFrame
    
    -- Test Buttons
    local TestWebhookBtn = Instance.new("TextButton")
    TestWebhookBtn.Name = "TestWebhookBtn"
    TestWebhookBtn.Text = "🔔 TEST-WEBHOOK SENDEN"
    TestWebhookBtn.Size = UDim2.new(1, -20, 0, 45)
    TestWebhookBtn.Position = UDim2.new(0, 10, 0, 300)
    TestWebhookBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    TestWebhookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TestWebhookBtn.Font = Enum.Font.GothamBold
    TestWebhookBtn.TextSize = 16
    TestWebhookBtn.Parent = DiscordFrame
    
    local TestMoneyBtn = Instance.new("TextButton")
    TestMoneyBtn.Name = "TestMoneyBtn"
    TestMoneyBtn.Text = "💰 TEST-GELDBENACHRICHTIGUNG"
    TestMoneyBtn.Size = UDim2.new(1, -20, 0, 45)
    TestMoneyBtn.Position = UDim2.new(0, 10, 0, 355)
    TestMoneyBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    TestMoneyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TestMoneyBtn.Font = Enum.Font.GothamBold
    TestMoneyBtn.TextSize = 16
    TestMoneyBtn.Parent = DiscordFrame
    
    -- Stats TAB
    local StatsFrame = Instance.new("Frame")
    StatsFrame.Name = "StatsFrame"
    StatsFrame.Size = UDim2.new(1, 0, 0, 500)
    StatsFrame.Position = UDim2.new(0, 0, 0, 0)
    StatsFrame.BackgroundTransparency = 1
    StatsFrame.Visible = false
    StatsFrame.Parent = parent
    
    local StatsTitle = Instance.new("TextLabel")
    StatsTitle.Name = "StatsTitle"
    StatsTitle.Text = "📊 STATISTIKEN"
    StatsTitle.Size = UDim2.new(1, -20, 0, 40)
    StatsTitle.Position = UDim2.new(0, 10, 0, 10)
    StatsTitle.BackgroundTransparency = 1
    StatsTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
    StatsTitle.Font = Enum.Font.GothamBold
    StatsTitle.TextSize = 20
    StatsTitle.TextXAlignment = Enum.TextXAlignment.Left
    StatsTitle.Parent = StatsFrame
    
    -- Statistik Labels
    local statEntries = {
        {name = "Gesamtfahrten", value = "0", y = 60},
        {name = "Gesamtgeld", value = "0€", y = 100},
        {name = "Betriebszeit", value = "00:00:00", y = 140},
        {name = "Geld/Stunde", value = "0€/h", y = 180},
        {name = "Fahrten/Stunde", value = "0/h", y = 220},
        {name = "Aktuelle Station", value = "--", y = 260},
        {name = "Station 1 Besuche", value = "0", y = 300},
        {name = "Station 2 Besuche", value = "0", y = 340},
        {name = "Station 3 Besuche", value = "0", y = 380},
        {name = "Station 4 Besuche", value = "0", y = 420}
    }
    
    for i, entry in ipairs(statEntries) do
        local label = Instance.new("TextLabel")
        label.Name = "StatLabel" .. i
        label.Text = entry.name .. ": " .. entry.value
        label.Size = UDim2.new(1, -20, 0, 30)
        label.Position = UDim2.new(0, 10, 0, entry.y)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = StatsFrame
    end
    
    -- Reset Button
    local ResetStatsBtn = Instance.new("TextButton")
    ResetStatsBtn.Name = "ResetStatsBtn"
    ResetStatsBtn.Text = "🔄 STATISTIKEN ZURÜCKSETZEN"
    ResetStatsBtn.Size = UDim2.new(1, -20, 0, 45)
    ResetStatsBtn.Position = UDim2.new(0, 10, 0, 470)
    ResetStatsBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
    ResetStatsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResetStatsBtn.Font = Enum.Font.GothamBold
    ResetStatsBtn.TextSize = 16
    ResetStatsBtn.Parent = StatsFrame
end

function SwitchTab(tabName)
    CurrentTab = tabName
    
    -- Alle Tabs verstecken
    local ContentFrame = ScreenGui.MainFrame.ContentFrame
    for _, child in pairs(ContentFrame:GetChildren()) do
        if child:IsA("Frame") then
            child.Visible = false
        end
    end
    
    -- Tab Button Farben zurücksetzen
    local TabContainer = ScreenGui.MainFrame.TabContainer
    for _, child in pairs(TabContainer:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        end
    end
    
    -- Aktiven Tab hervorheben
    local activeTab = TabContainer:FindFirstChild(tabName .. "Tab")
    if activeTab then
        activeTab.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    end
    
    -- Tab Content anzeigen
    local tabFrame = ContentFrame:FindFirstChild(tabName .. "Frame")
    if tabFrame then
        tabFrame.Visible = true
        ContentFrame.CanvasPosition = Vector2.new(0, 0)
    end
end

-- // TÜRSTEUERUNG // --
function ControlDoors(action)
    if not Config.OpenDoors then return end
    
    local VIM = game:GetService("VirtualInputManager")
    if not VIM then return end
    
    if action == "open" then
        if Config.DoorSide == 0 then -- Links (X)
            VIM:SendKeyEvent(true, Enum.KeyCode.X, false, nil)
            task.wait(0.5)
            VIM:SendKeyEvent(false, Enum.KeyCode.X, false, nil)
        elseif Config.DoorSide == 1 then -- Rechts (C)
            VIM:SendKeyEvent(true, Enum.KeyCode.C, false, nil)
            task.wait(0.5)
            VIM:SendKeyEvent(false, Enum.KeyCode.C, false, nil)
        elseif Config.DoorSide == 2 then -- Beide
            VIM:SendKeyEvent(true, Enum.KeyCode.X, false, nil)
            VIM:SendKeyEvent(true, Enum.KeyCode.C, false, nil)
            task.wait(0.5)
            VIM:SendKeyEvent(false, Enum.KeyCode.X, false, nil)
            VIM:SendKeyEvent(false, Enum.KeyCode.C, false, nil)
        end
    elseif action == "close" then
        -- Gleiche Tasten nochmal für schließen
        if Config.DoorSide == 0 then -- Links (X)
            VIM:SendKeyEvent(true, Enum.KeyCode.X, false, nil)
            task.wait(0.5)
            VIM:SendKeyEvent(false, Enum.KeyCode.X, false, nil)
        elseif Config.DoorSide == 1 then -- Rechts (C)
            VIM:SendKeyEvent(true, Enum.KeyCode.C, false, nil)
            task.wait(0.5)
            VIM:SendKeyEvent(false, Enum.KeyCode.C, false, nil)
        elseif Config.DoorSide == 2 then -- Beide
            VIM:SendKeyEvent(true, Enum.KeyCode.X, false, nil)
            VIM:SendKeyEvent(true, Enum.KeyCode.C, false, nil)
            task.wait(0.5)
            VIM:SendKeyEvent(false, Enum.KeyCode.X, false, nil)
            VIM:SendKeyEvent(false, Enum.KeyCode.C, false, nil)
        end
    end
end

-- // FUNKTIONEN // --
function SimulateKeyPress(keyCode)
    local VIM = game:GetService("VirtualInputManager")
    if VIM then
        VIM:SendKeyEvent(true, keyCode, false, nil)
        task.wait(Config.HoldGasTime or 0.3)
        VIM:SendKeyEvent(false, keyCode, false, nil)
    end
end


function SaveStationPosition(stationIndex)
    local char = LocalPlayer.Character
    if not char then
        Log("❌ Kein Charakter!")
        return
    end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        Log("❌ HumanoidRootPart nicht gefunden!")
        return
    end
    
    local stationKey = "Station" .. stationIndex
    if not Config.Stations[stationKey] then
        Config.Stations[stationKey] = {Position = nil, Name = "Station " .. stationIndex, Active = true}
    end
    
    Config.Stations[stationKey].Position = root.Position
    
    -- GUI Update
    local statusLabel = ScreenGui.MainFrame.ContentFrame.HaltestellenFrame:FindFirstChild("StationStatus" .. stationIndex)
    if statusLabel then
        statusLabel.Text = "✓ Gespeichert"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
    
    Log("✅ Haltestelle " .. stationIndex .. " gespeichert")
    SaveConfig()
end

-- // VERBESSERTE FAHRLOGIK MIT INTELLIGENTER BREMSUNG // --
function DriveToStation(stationPosition)
    if not stationPosition then return "Keine Position" end
    
    local char = LocalPlayer.Character
    if not char then return "Kein Charakter" end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return "Kein HumanoidRootPart" end
    
    local VIM = game:GetService("VirtualInputManager")
    local distance = (root.Position - stationPosition).Magnitude
    
    -- Hole individuelle Bremsdistanz für diese Station
    local brakeDistance = GetBrakeDistanceForStation(CurrentStationIndex)
    
    -- Phase 1: Normale Fahrt
    if distance > brakeDistance then
        -- Gas geben
        VIM:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        task.wait(Config.HoldGasTime)
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        return "Beschleunigen"
    
    -- Phase 2: Bremsen starten
    elseif distance <= brakeDistance and not IsBraking then
        IsBraking = true
        LastPosition = root.Position
        LastDistance = distance
        
        -- VOLLES BREMSEN - S gedrückt halten
        VIM:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
        UpdateActionLabel("VOLLE BREMSUNG")
        Log("🚦 Bremsen gestartet bei " .. math.floor(distance) .. " Studs (Distanz: " .. brakeDistance .. ")")
        
        return "Bremsen"
    
    -- Phase 3: Bremsen überwachen
    elseif IsBraking then
        local newDistance = (root.Position - stationPosition).Magnitude
        
        -- Prüfe ob Zug sich noch bewegt
        local positionChanged = (root.Position - LastPosition).Magnitude > 0.1
        
        if not positionChanged then
            -- Zug steht still
            VIM:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
            IsBraking = false
            
            -- Zweiter Check: wirklich still?
            task.wait(0.5)
            local finalCheck = (root.Position - stationPosition).Magnitude
            
            if finalCheck <= Config.StopDistance then
                -- Erfolgreich angehalten
                Log("✅ Erfolgreich angehalten bei " .. math.floor(finalCheck) .. " Studs")
                return "Angehalten"
            else
                -- Zu früh gestoppt
                Log("⚠️ Zu früh gestoppt bei " .. math.floor(finalCheck) .. " Studs")
                return "ZuFrüh"
            end
        end
        
        -- Aktualisiere letzte Position für nächsten Check
        LastPosition = root.Position
        LastDistance = newDistance
        return "Bremsen"
    
    else
        -- Sicherheitsfall: Alle Tasten loslassen
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        VIM:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
        return "Fehler"
    end
end

-- // INTELLIGENTE LANGNAME ANNAHERUNG // --
function SlowApproach(stationPosition)
    local char = LocalPlayer.Character
    if not char then return "Übersprungen" end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return "Übersprungen" end
    
    local VIM = game:GetService("VirtualInputManager")
    local startDistance = (root.Position - stationPosition).Magnitude
    local lastGoodDistance = startDistance
    local attempts = 0
    local maxAttempts = 10
    
    Log("🚶 Langsame Annäherung gestartet bei " .. math.floor(startDistance) .. " Studs")
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Kurzer Gasstoß
        VIM:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        task.wait(Config.SlowApproachSpeed or 0.1)
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        
        -- Kurze Pause für Bewegung
        task.wait(0.3)
        
        -- Neue Distanz berechnen
        local currentDistance = (root.Position - stationPosition).Magnitude
        
        -- Erfolg: Wir sind im Stop-Bereich
        if currentDistance <= Config.StopDistance then
            Log("✅ Erfolgreich angenähert auf " .. math.floor(currentDistance) .. " Studs")
            return "Angehalten"
        end
        
        -- Prüfe ob wir uns nähern
        if currentDistance < lastGoodDistance then
            -- Wir nähern uns - gut!
            lastGoodDistance = currentDistance
            UpdateActionLabel("Annäherung: " .. math.floor(currentDistance) .. " Studs")
        else
            -- Wir entfernen uns oder bewegen uns nicht
            if currentDistance > lastGoodDistance + 5 then
                -- Wir entfernen uns deutlich - wahrscheinlich vorbeigefahren
                Log("⚠️ Entferne mich von Station (" .. math.floor(currentDistance) .. " > " .. math.floor(lastGoodDistance) .. ")")
                return "Übersprungen"
            else
                -- Kaum Bewegung - weiter versuchen
                Log("ℹ️ Kaum Bewegung bei " .. math.floor(currentDistance) .. " Studs")
            end
        end
        
        -- Kleine Pause zwischen Versuchen
        task.wait(0.5)
    end
    
    -- Max Versuche erreicht ohne Erfolg
    Log("❌ Maximale Annäherungsversuche erreicht")
    return "Übersprungen"
end

-- // FIX: VERBESSERTE WEBHOOK FUNKTION // --
function SendDiscordWebhook(data)
    if Config.Webhook == "" or string.len(Config.Webhook) < 10 then
        Log("❌ Keine gültige Webhook URL")
        return false
    end
    
    local success, result = pcall(function()
        -- Versuche verschiedene HTTP Methoden
        local httpRequest = syn and syn.request or http and http.request or fluxus and fluxus.request or request
        
        if httpRequest then
            local response = httpRequest({
                Url = Config.Webhook,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })
            
            if response.Success then
                return true
            else
                error("HTTP Fehler: " .. tostring(response.StatusCode))
            end
        else
            -- Fallback auf HttpService (funktioniert nur in manchen Executoren)
            HttpService:PostAsync(Config.Webhook, HttpService:JSONEncode(data))
            return true
        end
    end)
    
    if success then
        Log("✅ Webhook gesendet")
        return true
    else
        Log("❌ Webhook-Fehler: " .. tostring(result))
        return false
    end
end

function ProcessStationStop(stationIndex)
    local station = Config.Stations["Station" .. stationIndex]
    if not station or not station.Active or not station.Position then return end
    
    Log("🛑 Halte an " .. station.Name)
    
    -- Türen öffnen
    ControlDoors("open")
    task.wait(1)
    
    -- Wartezeit
    for i = 1, Config.WaitTimeAtStation do
        UpdateActionLabel("Warte: " .. (Config.WaitTimeAtStation - i) .. "s")
        task.wait(1)
    end
    
    -- Türen schließen
    ControlDoors("close")
    task.wait(1)
    
    -- Geld verdienen
    TotalMoney = TotalMoney + 350
    TripsCompleted = TripsCompleted + 1
    Stats.StationVisits[stationIndex] = (Stats.StationVisits[stationIndex] or 0) + 1
    Stats.LastTripTime = os.time()
    
    -- Discord Benachrichtigung
    if Config.WebhookEvents.MoneyEarned and Config.Webhook ~= "" then
        SendMoneyNotification(station.Name)
    end
    
    -- Statistik Update
    UpdateStatistics()
    
    -- GUI Update
    UpdateMoneyLabel()
    UpdateActionLabel("Weiterfahrt von " .. station.Name)
    
    Log("💰 +350€ an " .. station.Name .. " | Gesamt: " .. TotalMoney .. "€")
end

function UpdateStatistics()
    if not ScreenGui then return end
    
    local statsFrame = ScreenGui.MainFrame.ContentFrame.StatsFrame
    if not statsFrame then return end
    
    -- Betriebszeit berechnen
    local runtime = os.time() - Stats.StartTime
    local hours = math.floor(runtime / 3600)
    local minutes = math.floor((runtime % 3600) / 60)
    local seconds = runtime % 60
    local runtimeText = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    
    -- Geld/Stunde berechnen
    local moneyPerHour = 0
    if runtime > 0 then
        moneyPerHour = math.floor((TotalMoney / runtime) * 3600)
    end
    
    -- Fahrten/Stunde berechnen
    local tripsPerHour = 0
    if runtime > 0 then
        tripsPerHour = math.floor((TripsCompleted / runtime) * 3600)
    end
    
    -- Aktuelle Station
    local currentStation = Config.Stations["Station" .. CurrentStationIndex]
    local stationName = currentStation and currentStation.Name or "--"
    
    -- Labels aktualisieren
    local labels = {
        {name = "Gesamtfahrten", value = TripsCompleted},
        {name = "Gesamtgeld", value = TotalMoney .. "€"},
        {name = "Betriebszeit", value = runtimeText},
        {name = "Geld/Stunde", value = moneyPerHour .. "€/h"},
        {name = "Fahrten/Stunde", value = tripsPerHour .. "/h"},
        {name = "Aktuelle Station", value = stationName},
        {name = "Station 1 Besuche", value = Stats.StationVisits[1] or 0},
        {name = "Station 2 Besuche", value = Stats.StationVisits[2] or 0},
        {name = "Station 3 Besuche", value = Stats.StationVisits[3] or 0},
        {name = "Station 4 Besuche", value = Stats.StationVisits[4] or 0}
    }
    
    for i, labelInfo in ipairs(labels) do
        local label = statsFrame:FindFirstChild("StatLabel" .. i)
        if label then
            label.Text = labelInfo.name .. ": " .. tostring(labelInfo.value)
        end
    end
end

-- // VEREINFACHTE WEBHOOK NACHRICHTEN // --
function SendMoneyNotification(stationName)
    local currentTime = os.date("%H:%M:%S")
    
    local data = {
        embeds = {{
            description = string.format(
                "**Zeit:** %s\n" ..
                "**Station:** %s\n" ..
                "**Einnahme:** +350€\n" ..
                "**Gesamtverdienst:** %d€",
                currentTime, stationName, TotalMoney
            ),
            color = 3066993,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = {
                text = "RailMaster Pro v5.1"
            }
        }}
    }
    
    SendDiscordWebhook(data)
end

function UpdateGUI()
    if not ScreenGui then return end
    
    -- Status Label
    local statusLabel = ScreenGui.MainFrame.StatusBar.StatusLabel
    if statusLabel then
        if IsRunning then
            statusLabel.Text = "🟢 AKTIV"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            statusLabel.Text = "🟡 BEREIT"
            statusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        end
    end
    
    -- Start/Stop Button
    local startStopBtn = ScreenGui.MainFrame.ContentFrame.AutopilotFrame:FindFirstChild("StartStopBtn")
    if startStopBtn then
        if IsRunning then
            startStopBtn.Text = "⏹️ AUTOPILOT STOPPEN"
            startStopBtn.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
        else
            startStopBtn.Text = "🚂 AUTOPILOT STARTEN"
            startStopBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
        end
    end
end

function UpdateActionLabel(text)
    if not ScreenGui then return end
    
    local actionLabel = ScreenGui.MainFrame.StatusBar.ActionLabel
    if actionLabel then
        actionLabel.Text = "Aktion: " .. text
    end
end

function UpdateNextStationLabel(text)
    if not ScreenGui then return end
    
    local nextLabel = ScreenGui.MainFrame.ContentFrame.AutopilotFrame:FindFirstChild("NextStationLabel")
    if nextLabel then
        nextLabel.Text = "Nächster Halt: " .. text
    end
end

function UpdateMoneyLabel()
    if not ScreenGui then return end
    
    local moneyLabel = ScreenGui.MainFrame.StatusBar.MoneyLabel
    if moneyLabel then
        moneyLabel.Text = "💰 " .. TotalMoney .. "€"
    end
end

function StartAutopilot()
    if IsRunning then return end
    
    -- Prüfe ob Stationen gespeichert sind
    for i = 1, 3 do
        if not Config.Stations["Station" .. i] or not Config.Stations["Station" .. i].Position then
            Log("❌ Haltestelle " .. i .. " nicht gespeichert!")
            UpdateActionLabel("Speichere Haltestelle " .. i .. " zuerst!")
            SwitchTab("Haltestellen")
            return
        end
    end
    
    IsRunning = true
    UpdateGUI()
    UpdateActionLabel("Autopilot gestartet")
    
    CurrentStationIndex = 1
    
    AutoPilotThread = task.spawn(function()
        while IsRunning and task.wait(0.1) do
            -- Aktuelle Station
            local station = Config.Stations["Station" .. CurrentStationIndex]
            
            if not station or not station.Position or not station.Active then
                -- Nächste aktive Station suchen
                for i = 1, 4 do
                    local nextStation = Config.Stations["Station" .. i]
                    if nextStation and nextStation.Position and nextStation.Active then
                        CurrentStationIndex = i
                        station = nextStation
                        break
                    end
                end
            end
            
            if not station or not station.Position then
                UpdateActionLabel("Keine gültige Station")
                task.wait(2)
                continue
            end
            
            -- GUI Updates
            UpdateNextStationLabel(station.Name)
            UpdateStatistics()
            
            -- Zur Station fahren
            local action = DriveToStation(station.Position)
            UpdateActionLabel(action)
            
            -- Prüfen ob angehalten
            if action == "Angehalten" then
                ProcessStationStop(CurrentStationIndex)
                
                -- Zur nächsten Station
                CurrentStationIndex = CurrentStationIndex + 1
                if CurrentStationIndex > 4 then
                    CurrentStationIndex = 1
                end
                
                task.wait(2)
                
            elseif action == "ZuFrüh" then
                -- Langsame Annäherung versuchen
                local approachResult = SlowApproach(station.Position)
                
                if approachResult == "Angehalten" then
                    ProcessStationStop(CurrentStationIndex)
                    
                    -- Zur nächsten Station
                    CurrentStationIndex = CurrentStationIndex + 1
                    if CurrentStationIndex > 4 then
                        CurrentStationIndex = 1
                    end
                elseif approachResult == "Übersprungen" then
                    -- Haltestelle übersprungen
                    Log("⏭️ Haltestelle übersprungen: " .. station.Name)
                    UpdateActionLabel("Übersprungen: " .. station.Name)
                    
                    -- Direkt zur nächsten Station
                    CurrentStationIndex = CurrentStationIndex + 1
                    if CurrentStationIndex > 4 then
                        CurrentStationIndex = 1
                    end
                    
                    -- Kurze Pause
                    task.wait(2)
                end
                
                -- Reset für nächsten Durchlauf
                IsBraking = false
                LastPosition = nil
                LastDistance = nil
                
            elseif action == "Fehler" then
                -- Reset für nächsten Durchlauf
                IsBraking = false
                LastPosition = nil
                LastDistance = nil
                task.wait(1)
            end
        end
    end)
end

function StopAutopilot()
    IsRunning = false
    IsBraking = false
    
    if AutoPilotThread then
        task.cancel(AutoPilotThread)
    end
    
    -- Alle Tasten loslassen
    local VIM = game:GetService("VirtualInputManager")
    if VIM then
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        VIM:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
    end
    
    UpdateGUI()
    UpdateActionLabel("Autopilot gestoppt")
    UpdateNextStationLabel("--")
end

function EmergencyStop()
    IsRunning = false
    IsBraking = false
    
    -- Sofort bremsen
    local VIM = game:GetService("VirtualInputManager")
    if VIM then
        for i = 1, 10 do
            VIM:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
        end
    end
    
    UpdateActionLabel("NOTSTOPP aktiviert")
    task.wait(1)
    StopAutopilot()
end

function SaveConfig()
    local saveData = {
        Config = Config,
        TotalMoney = TotalMoney,
        TripsCompleted = TripsCompleted,
        Stats = Stats
    }
    
    local success, jsonData = pcall(function()
        return HttpService:JSONEncode(saveData)
    end)
    
    if success then
        if writefile then
            writefile("railmaster_config_v5.json", jsonData)
            Log("✅ Konfiguration gespeichert")
        else
            Log("⚠️ writefile nicht verfügbar, Config nicht gespeichert")
        end
    else
        Log("❌ Fehler beim Speichern der Konfiguration")
    end
end

function LoadConfig()
    if readfile and isfile and isfile("railmaster_config_v5.json") then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile("railmaster_config_v5.json"))
        end)
        
        if success and data then
            Config = data.Config or Config
            TotalMoney = data.TotalMoney or 0
            TripsCompleted = data.TripsCompleted or 0
            Stats = data.Stats or Stats
            Log("✅ Konfiguration geladen")
        end
    else
        Log("ℹ️ Keine gespeicherte Konfiguration gefunden")
    end
end

function ApplySettingsFromGUI()
    -- Hole Werte aus GUI
    local settingsFrame = ScreenGui.MainFrame.ContentFrame.EinstellungenFrame
    
    -- Brems-Startdistanz (global)
    local brakeDistBox = settingsFrame:FindFirstChild("BrakeDistSlider")
    if brakeDistBox and brakeDistBox.Text ~= "" then
        local value = tonumber(brakeDistBox.Text)
        if value and value >= 50 and value <= 800 then
            Config.BrakeStartDistance = value
        end
    end
    
    -- Stop-Genauigkeit
    local stopDistBox = settingsFrame:FindFirstChild("StopDistSlider")
    if stopDistBox and stopDistBox.Text ~= "" then
        local value = tonumber(stopDistBox.Text)
        if value and value >= 1 and value <= 50 then
            Config.StopDistance = value
        end
    end
    
    -- Wartezeit
    local waitTimeBox = settingsFrame:FindFirstChild("WaitTimeSlider")
    if waitTimeBox and waitTimeBox.Text ~= "" then
        local value = tonumber(waitTimeBox.Text)
        if value and value >= 0 and value <= 60 then
            Config.WaitTimeAtStation = value
        end
    end
    
    -- Langsame Annäherung
    local slowSpeedBox = settingsFrame:FindFirstChild("SlowSpeedSlider")
    if slowSpeedBox and slowSpeedBox.Text ~= "" then
        local value = tonumber(slowSpeedBox.Text)
        if value and value >= 0.05 and value <= 0.5 then
            Config.SlowApproachSpeed = value
        end
    end
    
    -- Labels aktualisieren
    local brakeDistLabel = settingsFrame:FindFirstChild("BrakeDistLabel")
    if brakeDistLabel then
        brakeDistLabel.Text = "Globale Brems-Startdistanz: " .. Config.BrakeStartDistance .. " Studs"
    end
    
    local stopDistLabel = settingsFrame:FindFirstChild("StopDistLabel")
    if stopDistLabel then
        stopDistLabel.Text = "Stop-Genauigkeit: " .. Config.StopDistance .. " Studs"
    end
    
    local waitTimeLabel = settingsFrame:FindFirstChild("WaitTimeLabel")
    if waitTimeLabel then
        waitTimeLabel.Text = "Wartezeit an Station: " .. Config.WaitTimeAtStation .. "s"
    end
    
    local slowSpeedLabel = settingsFrame:FindFirstChild("SlowSpeedLabel")
    if slowSpeedLabel then
        slowSpeedLabel.Text = "Langsame Annäherung: " .. Config.SlowApproachSpeed
    end
    
    SaveConfig()
    Log("✅ Einstellungen übernommen")
end

function Log(message)
    if Config.DebugMode then
        print("[RailMaster v5.1] " .. message)
    end
end

-- // NEUE FUNKTIONEN // --
function ToggleGUI()
    if not ScreenGui then return end
    
    IsGuiVisible = not IsGuiVisible
    ScreenGui.Enabled = IsGuiVisible
    
    if IsGuiVisible then
        Log("📺 GUI eingeblendet")
        UpdateActionLabel("GUI eingeblendet")
    else
        Log("📺 GUI ausgeblendet")
    end
end

function ExitScript()
    Log("🛑 Beende Script...")
    
    -- Stoppe Autopilot
    IsRunning = false
    EmergencyBrake = true
    IsBraking = false
    
    -- Bremsen für Notstopp
    local VIM = game:GetService("VirtualInputManager")
    if VIM then
        for i = 1, 5 do
            VIM:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
            task.wait(0.1)
            VIM:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
        end
        -- Alle Tasten loslassen
        VIM:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        VIM:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
    end
    
    -- Speichere Konfiguration
    SaveConfig()
    
    -- Beende alle Threads
    if AutoPilotThread then
        task.cancel(AutoPilotThread)
    end
    
    -- Entferne GUI
    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
    end
    
    -- Erstelle Bestätigungsmeldung
    local notification = Instance.new("ScreenGui")
    notification.Name = "ExitNotification"
    notification.Parent = game.CoreGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(0.5, -150, 0.3, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255, 50, 50)
    frame.Parent = notification
    
    local label = Instance.new("TextLabel")
    label.Text = "✅ RailMaster erfolgreich beendet!"
    label.Size = UDim2.new(1, 0, 0.6, 0)
    label.Position = UDim2.new(0, 0, 0, 10)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.Parent = frame
    
    local subLabel = Instance.new("TextLabel")
    subLabel.Text = "GUI wird in 3 Sekunden geschlossen..."
    subLabel.Size = UDim2.new(1, 0, 0.4, 0)
    subLabel.Position = UDim2.new(0, 0, 0.6, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 12
    subLabel.Parent = frame
    
    -- Warte und entferne Notification
    task.wait(3)
    notification:Destroy()
    
    Log("👋 Script erfolgreich beendet")
end

-- // INITIALISIERUNG // --
LoadConfig()
CreateGUI()
UpdateMoneyLabel()
UpdateStatistics()

-- F1 Taste für GUI Toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F1 then
        ToggleGUI()
    end
end)

-- Autopilot Button Events
local startStopBtn = ScreenGui.MainFrame.ContentFrame.AutopilotFrame.StartStopBtn
startStopBtn.MouseButton1Click:Connect(function()
    if IsRunning then
        StopAutopilot()
    else
        StartAutopilot()
    end
end)

local emergencyBtn = ScreenGui.MainFrame.ContentFrame.AutopilotFrame.EmergencyBtn
emergencyBtn.MouseButton1Click:Connect(function()
    EmergencyStop()
end)

-- Haltestellen Buttons
for i = 1, 4 do
    local stationBtn = ScreenGui.MainFrame.ContentFrame.HaltestellenFrame:FindFirstChild("StationBtn" .. i)
    if stationBtn then
        stationBtn.MouseButton1Click:Connect(function()
            SaveStationPosition(i)
        end)
    end
end

local clearBtn = ScreenGui.MainFrame.ContentFrame.HaltestellenFrame.ClearBtn
clearBtn.MouseButton1Click:Connect(function()
    for i = 1, 4 do
        if Config.Stations["Station" .. i] then
            Config.Stations["Station" .. i].Position = nil
        end
        local statusLabel = ScreenGui.MainFrame.ContentFrame.HaltestellenFrame:FindFirstChild("StationStatus" .. i)
        if statusLabel then
            statusLabel.Text = "Nicht gespeichert"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
    SaveConfig()
    Log("🗑️ Alle Haltestellen gelöscht")
end)

-- Bremsdistanz Tab Events
local brakeDistFrame = ScreenGui.MainFrame.ContentFrame.BremsdistanzFrame

-- Save Button
local saveBrakeBtn = brakeDistFrame:FindFirstChild("SaveBrakeDistBtn")
if saveBrakeBtn then
    saveBrakeBtn.MouseButton1Click:Connect(function()
        for i = 1, 4 do
            local input = brakeDistFrame:FindFirstChild("BrakeInput" .. i)
            local valueLabel = brakeDistFrame:FindFirstChild("ValueLabel" .. i)
            
            if input and input.Text ~= "" then
                local value = tonumber(input.Text)
                if value and value >= 50 and value <= 800 then
                    Config.Stations["Station" .. i].BrakeStartDistance = value
                    valueLabel.Text = "Aktiv: " .. value .. " Studs"
                    valueLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
                end
            else
                -- Leer = global verwenden
                Config.Stations["Station" .. i].BrakeStartDistance = nil
                valueLabel.Text = "Verwendet global: " .. Config.BrakeStartDistance .. " Studs"
                valueLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
        end
        
        SaveConfig()
        saveBrakeBtn.Text = "✅ GESPEICHERT!"
        task.wait(1)
        saveBrakeBtn.Text = "💾 BREMSDISTANZEN SPEICHERN"
        
        Log("💾 Individuelle Bremsdistanzen gespeichert")
    end)
end

-- Reset All Button
local resetAllBtn = brakeDistFrame:FindFirstChild("ResetAllBrakeBtn")
if resetAllBtn then
    resetAllBtn.MouseButton1Click:Connect(function()
        for i = 1, 4 do
            Config.Stations["Station" .. i].BrakeStartDistance = nil
            local input = brakeDistFrame:FindFirstChild("BrakeInput" .. i)
            local valueLabel = brakeDistFrame:FindFirstChild("ValueLabel" .. i)
            
            if input then input.Text = "" end
            if valueLabel then
                valueLabel.Text = "Verwendet global: " .. Config.BrakeStartDistance .. " Studs"
                valueLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
        end
        
        SaveConfig()
        resetAllBtn.Text = "✅ ALLE ZURÜCKGESETZT!"
        task.wait(1)
        resetAllBtn.Text = "🗑️ ALLE INDIVIDUELLEN LÖSCHEN"
    end)
end

-- Reset Buttons für einzelne Stationen
for i = 1, 4 do
    local resetBtn = brakeDistFrame:FindFirstChild("ResetBtn" .. i)
    if resetBtn then
        resetBtn.MouseButton1Click:Connect(function()
            Config.Stations["Station" .. i].BrakeStartDistance = nil
            local input = brakeDistFrame:FindFirstChild("BrakeInput" .. i)
            local valueLabel = brakeDistFrame:FindFirstChild("ValueLabel" .. i)
            
            if input then input.Text = "" end
            if valueLabel then
                valueLabel.Text = "Verwendet global: " .. Config.BrakeStartDistance .. " Studs"
                valueLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
            
            SaveConfig()
            resetBtn.Text = "✓"
            task.wait(1)
            resetBtn.Text = "↺"
        end)
    end
end

-- Einstellungen Events
local settingsFrame = ScreenGui.MainFrame.ContentFrame.EinstellungenFrame

-- TextBox Events
local brakeDistBox = settingsFrame:FindFirstChild("BrakeDistSlider")
if brakeDistBox then
    brakeDistBox.FocusLost:Connect(function()
        ApplySettingsFromGUI()
    end)
end

local stopDistBox = settingsFrame:FindFirstChild("StopDistSlider")
if stopDistBox then
    stopDistBox.FocusLost:Connect(function()
        ApplySettingsFromGUI()
    end)
end

local waitTimeBox = settingsFrame:FindFirstChild("WaitTimeSlider")
if waitTimeBox then
    waitTimeBox.FocusLost:Connect(function()
        ApplySettingsFromGUI()
    end)
end

local slowSpeedBox = settingsFrame:FindFirstChild("SlowSpeedSlider")
if slowSpeedBox then
    slowSpeedBox.FocusLost:Connect(function()
        ApplySettingsFromGUI()
    end)
end

-- Türen öffnen Toggle
local openDoorsToggle = settingsFrame:FindFirstChild("OpenDoorsToggle")
if openDoorsToggle then
    openDoorsToggle.MouseButton1Click:Connect(function()
        Config.OpenDoors = not Config.OpenDoors
        openDoorsToggle.Text = "Türen öffnen: " .. (Config.OpenDoors and "✅ AN" or "❌ AUS")
        openDoorsToggle.BackgroundColor3 = Config.OpenDoors and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        SaveConfig()
    end)
end

-- Türseite Buttons
local doorSideLeft = settingsFrame:FindFirstChild("DoorSideLeft")
local doorSideRight = settingsFrame:FindFirstChild("DoorSideRight")
local doorSideBoth = settingsFrame:FindFirstChild("DoorSideBoth")
local doorSideLabel = settingsFrame:FindFirstChild("DoorSideLabel")

if doorSideLeft then
    doorSideLeft.MouseButton1Click:Connect(function()
        Config.DoorSide = 0
        doorSideLeft.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
        doorSideRight.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        doorSideBoth.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        doorSideLabel.Text = "Türseite: Links (X)"
        SaveConfig()
    end)
end

if doorSideRight then
    doorSideRight.MouseButton1Click:Connect(function()
        Config.DoorSide = 1
        doorSideLeft.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        doorSideRight.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
        doorSideBoth.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        doorSideLabel.Text = "Türseite: Rechts (C)"
        SaveConfig()
    end)
end

if doorSideBoth then
    doorSideBoth.MouseButton1Click:Connect(function()
        Config.DoorSide = 2
        doorSideLeft.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        doorSideRight.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        doorSideBoth.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
        doorSideLabel.Text = "Türseite: Beide"
        SaveConfig()
    end)
end

-- Weitere Toggles
local stopEveryStationToggle = settingsFrame:FindFirstChild("StopEveryStationToggle")
if stopEveryStationToggle then
    stopEveryStationToggle.MouseButton1Click:Connect(function()
        Config.StopAtEveryStation = not Config.StopAtEveryStation
        stopEveryStationToggle.Text = "An jeder Station halten: " .. (Config.StopAtEveryStation and "✅ AN" or "❌ AUS")
        stopEveryStationToggle.BackgroundColor3 = Config.StopAtEveryStation and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        SaveConfig()
    end)
end

local autoStartToggle = settingsFrame:FindFirstChild("AutoStartToggle")
if autoStartToggle then
    autoStartToggle.MouseButton1Click:Connect(function()
        Config.AutoStart = not Config.AutoStart
        autoStartToggle.Text = "Auto-Start: " .. (Config.AutoStart and "✅ AN" or "❌ AUS")
        autoStartToggle.BackgroundColor3 = Config.AutoStart and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        SaveConfig()
    end)
end

local debugToggle = settingsFrame:FindFirstChild("DebugToggle")
if debugToggle then
    debugToggle.MouseButton1Click:Connect(function()
        Config.DebugMode = not Config.DebugMode
        debugToggle.Text = "Debug Modus: " .. (Config.DebugMode and "✅ AN" or "❌ AUS")
        debugToggle.BackgroundColor3 = Config.DebugMode and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        SaveConfig()
    end)
end

-- Exit Script Button
local exitScriptBtn = settingsFrame:FindFirstChild("ExitScriptBtn")
if exitScriptBtn then
    exitScriptBtn.MouseButton1Click:Connect(function()
        -- Bestätigungsdialog
        local originalText = exitScriptBtn.Text
        local originalColor = exitScriptBtn.BackgroundColor3
        
        exitScriptBtn.Text = "⚠️ WIRKLICH BEENDEN? (Klick nochmal)"
        exitScriptBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        
        -- Zweiter Klick
        local doubleClickConnection
        doubleClickConnection = exitScriptBtn.MouseButton1Click:Connect(function()
            doubleClickConnection:Disconnect()
            ExitScript()
        end)
        
        -- Nach 3 Sekunden zurücksetzen
        task.wait(3)
        if doubleClickConnection then
            doubleClickConnection:Disconnect()
        end
        exitScriptBtn.Text = originalText
        exitScriptBtn.BackgroundColor3 = originalColor
    end)
end

-- Save Settings Button
local saveSettingsBtn = settingsFrame:FindFirstChild("SaveSettingsBtn")
if saveSettingsBtn then
    saveSettingsBtn.MouseButton1Click:Connect(function()
        ApplySettingsFromGUI()
        
        -- Feedback
        saveSettingsBtn.Text = "✅ GESPEICHERT!"
        task.wait(1)
        saveSettingsBtn.Text = "💾 EINSTELLUNGEN SPEICHERN"
    end)
end

-- Discord Events
local discordFrame = ScreenGui.MainFrame.ContentFrame.DiscordFrame

-- Webhook Input
local webhookInput = discordFrame:FindFirstChild("WebhookInput")
if webhookInput then
    webhookInput.FocusLost:Connect(function()
        Config.Webhook = webhookInput.Text
        SaveConfig()
    end)
end

-- Event Toggles
local eventMoneyToggle = discordFrame:FindFirstChild("EventMoneyToggle")
if eventMoneyToggle then
    eventMoneyToggle.MouseButton1Click:Connect(function()
        Config.WebhookEvents.MoneyEarned = not Config.WebhookEvents.MoneyEarned
        eventMoneyToggle.Text = "💰 Geld verdient (+350€): " .. (Config.WebhookEvents.MoneyEarned and "✅ AN" or "❌ AUS")
        eventMoneyToggle.BackgroundColor3 = Config.WebhookEvents.MoneyEarned and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        SaveConfig()
    end)
end

local eventAutoToggle = discordFrame:FindFirstChild("EventAutoToggle")
if eventAutoToggle then
    eventAutoToggle.MouseButton1Click:Connect(function()
        Config.WebhookEvents.AutoPilotToggle = not Config.WebhookEvents.AutoPilotToggle
        eventAutoToggle.Text = "🚂 Autopilot Start/Stop: " .. (Config.WebhookEvents.AutoPilotToggle and "✅ AN" or "❌ AUS")
        eventAutoToggle.BackgroundColor3 = Config.WebhookEvents.AutoPilotToggle and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        SaveConfig()
    end)
end

local eventSystemToggle = discordFrame:FindFirstChild("EventSystemToggle")
if eventSystemToggle then
    eventSystemToggle.MouseButton1Click:Connect(function()
        Config.WebhookEvents.SystemStart = not Config.WebhookEvents.SystemStart
        eventSystemToggle.Text = "⚙️ System Start: " .. (Config.WebhookEvents.SystemStart and "✅ AN" or "❌ AUS")
        eventSystemToggle.BackgroundColor3 = Config.WebhookEvents.SystemStart and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
        SaveConfig()
    end)
end

-- Test Buttons
local testWebhookBtn = discordFrame:FindFirstChild("TestWebhookBtn")
if testWebhookBtn then
    testWebhookBtn.MouseButton1Click:Connect(function()
        if Config.Webhook ~= "" then
            local data = {
                embeds = {{
                    title = "🔔 RailMaster Test",
                    description = "Testnachricht erfolgreich!\nWebhook funktioniert korrekt.",
                    color = 7419530,
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer = {
                        text = "RailMaster Pro v5.1"
                    }
                }}
            }
            
            if SendDiscordWebhook(data) then
                testWebhookBtn.Text = "✅ ERFOLGREICH!"
                task.wait(2)
                testWebhookBtn.Text = "🔔 TEST-WEBHOOK SENDEN"
            else
                testWebhookBtn.Text = "❌ FEHLER!"
                task.wait(2)
                testWebhookBtn.Text = "🔔 TEST-WEBHOOK SENDEN"
            end
        else
            testWebhookBtn.Text = "❌ KEINE URL!"
            task.wait(2)
            testWebhookBtn.Text = "🔔 TEST-WEBHOOK SENDEN"
        end
    end)
end

local testMoneyBtn = discordFrame:FindFirstChild("TestMoneyBtn")
if testMoneyBtn then
    testMoneyBtn.MouseButton1Click:Connect(function()
        SendMoneyNotification("Test-Station")
        testMoneyBtn.Text = "✅ TEST GESENDET!"
        task.wait(2)
        testMoneyBtn.Text = "💰 TEST-GELDBENACHRICHTIGUNG"
    end)
end

-- Stats Events
local resetStatsBtn = ScreenGui.MainFrame.ContentFrame.StatsFrame:FindFirstChild("ResetStatsBtn")
if resetStatsBtn then
    resetStatsBtn.MouseButton1Click:Connect(function()
        TotalMoney = 0
        TripsCompleted = 0
        Stats = {
            StartTime = os.time(),
            LastTripTime = 0,
            MoneyPerHour = 0,
            TripsPerHour = 0,
            StationVisits = {0, 0, 0, 0}
        }
        
        UpdateMoneyLabel()
        UpdateStatistics()
        SaveConfig()
        
        resetStatsBtn.Text = "✅ ZURÜCKGESETZT!"
        task.wait(2)
        resetStatsBtn.Text = "🔄 STATISTIKEN ZURÜCKSETZEN"
        
        Log("📊 Statistiken zurückgesetzt")
    end)
end


-- Auto-Start
if Config.AutoStart then
    task.wait(3)
    StartAutopilot()
end
