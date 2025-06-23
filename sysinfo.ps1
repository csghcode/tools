Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "System Information"
$form.Size = New-Object System.Drawing.Size(900, 750)
$form.StartPosition = "CenterScreen"

# Panel to hold buttons
$panel = New-Object System.Windows.Forms.Panel
$panel.Height = 40
$panel.Dock = "Top"

# Create the RichTextBox instead of TextBox
$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Multiline = $true
$richTextBox.ScrollBars = "Vertical"
$richTextBox.ReadOnly = $true
$richTextBox.Dock = "Fill"
$richTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$richTextBox.BackColor = [System.Drawing.Color]::FromArgb(30,30,30)  # Dark background
$richTextBox.ForeColor = [System.Drawing.Color]::White                # Default text color white

# Add controls to the form in correct order
$form.Controls.Add($richTextBox)
$form.Controls.Add($panel)

# Refresh Button
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh"
$refreshButton.Width = 100
$refreshButton.Height = 30
$refreshButton.Left = 10
$refreshButton.Top = 5
$panel.Controls.Add($refreshButton)

# Export Button
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = "Export to File"
$exportButton.Width = 120
$exportButton.Height = 30
$exportButton.Left = 120
$exportButton.Top = 5
$panel.Controls.Add($exportButton)

# Helper function to append colored text (does NOT append new line)
function Add-ColoredTextInline {
    param (
        [string]$text,
        [System.Drawing.Color]$color = [System.Drawing.Color]::White,
        [bool]$bold = $false
    )
    $richTextBox.SelectionStart = $richTextBox.TextLength
    $richTextBox.SelectionLength = 0
    $richTextBox.SelectionColor = $color
    if ($bold) {
        $richTextBox.SelectionFont = New-Object System.Drawing.Font($richTextBox.Font, [System.Drawing.FontStyle]::Bold)
    } else {
        $richTextBox.SelectionFont = $richTextBox.Font
    }
    $richTextBox.AppendText($text)
    $richTextBox.SelectionColor = $richTextBox.ForeColor
}

# Append new line explicitly
function Add-NewLine {
    $richTextBox.AppendText("`r`n")
}

# Function to append section header (bold, orange with newline)
function Add-SectionHeader {
    param ([string]$text)
    Add-ColoredTextInline $text ([System.Drawing.Color]::Orange) $true
    Add-NewLine
}

# Function to output key-value pairs on same line: key colored+b, value normal
function Add-KeyValue {
    param (
        [string]$key,
        [string]$value
    )
    $keyPadded = $key.PadRight(20)
    Add-ColoredTextInline "${keyPadded}: " ([System.Drawing.Color]::LightGreen) $true
    Add-ColoredTextInline "$value"
    Add-NewLine
}

# Function to add simple colored text line
function Add-ColoredLine {
    param (
        [string]$text,
        [System.Drawing.Color]$color = [System.Drawing.Color]::White,
        [bool]$bold = $false
    )
    Add-ColoredTextInline $text $color $bold
    Add-NewLine
}

# Gather system info
function Get-SystemInfo {
    $richTextBox.Clear()

    # === OS Info ===
    Add-SectionHeader "=== Operating System ==="
    $os = Get-CimInstance Win32_OperatingSystem
    Add-KeyValue "Name" $os.Caption
    Add-KeyValue "Version" $os.Version
    Add-KeyValue "Architecture" $os.OSArchitecture
    Add-KeyValue "Build Number" $os.BuildNumber

    # === Uptime ===
    Add-SectionHeader "`n=== System Uptime ==="
    $uptime = (Get-Date) - $os.LastBootUpTime
    Add-KeyValue "Last Boot Time" $os.LastBootUpTime
    Add-KeyValue "Uptime" ("{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds)

    # === RAM Summary ===
    Add-SectionHeader "`n=== Memory (RAM) Summary ==="
    $ram = Get-CimInstance Win32_ComputerSystem
    $memGB = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
    Add-KeyValue "Installed RAM" "$memGB GB"

    # === Memory Modules ===
    Add-SectionHeader "`n=== Memory Modules ==="
    $memModules = Get-CimInstance Win32_PhysicalMemory
    $count = 0
    foreach ($module in $memModules) {
        $count++
        $capacityGB = [math]::Round($module.Capacity / 1GB, 2)
        Add-ColoredLine "Module #$count" ([System.Drawing.Color]::LightBlue) $true
        Add-KeyValue "Capacity" "$capacityGB GB"
        Add-KeyValue "Speed" "$($module.Speed) MHz"
        Add-KeyValue "Manufacturer" $module.Manufacturer
        Add-KeyValue "Part Number" $module.PartNumber.Trim()
        Add-KeyValue "Serial Number" $module.SerialNumber.Trim()
        Add-NewLine
    }
    if ($count -eq 0) { Add-ColoredLine "No memory modules detected." ([System.Drawing.Color]::Red) $true }

    # === Battery ===
    Add-SectionHeader "`n=== Battery ==="
    $battery = Get-CimInstance Win32_Battery
    if ($battery) {
        foreach ($b in $battery) {
            Add-KeyValue "Battery Status" $b.BatteryStatus
            Add-KeyValue "Estimated Charge" "$($b.EstimatedChargeRemaining)%"
        }
    } else {
        Add-ColoredLine "Battery: Not detected" ([System.Drawing.Color]::Gray) $true
    }

    # === CPU Info ===
    Add-SectionHeader "`n=== CPU Info ==="
    $cpu = Get-CimInstance Win32_Processor
    Add-KeyValue "Model" $cpu.Name
    Add-KeyValue "Cores" $cpu.NumberOfCores
    Add-KeyValue "Logical Processors" $cpu.NumberOfLogicalProcessors
    Add-KeyValue "Clock Speed (MHz)" $cpu.CurrentClockSpeed

    # === Display Resolution and Details ===
    Add-SectionHeader "`n=== Display Details ==="
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen

    $monitors = Get-CimInstance Win32_DesktopMonitor | Where-Object { $_.Availability -ne $null }
    $primaryMonitor = $monitors | Select-Object -First 1

    $displayModel = if ($primaryMonitor -and $primaryMonitor.Name) { $primaryMonitor.Name.Trim() } else { "Unknown" }

    try {
        $refreshRate = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration\*\00" -ErrorAction Stop).RefreshRate
    } catch {
        $refreshRate = "Unknown"
    }

    $connectionType = "Unknown"
    try {
        $query = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams
        if ($query) {
            $connTypeCode = $query[0].VideoOutputTechnology
            switch ($connTypeCode) {
                3 { $connectionType = "HDMI" }
                4 { $connectionType = "DVI" }
                5 { $connectionType = "VGA" }
                6 { $connectionType = "S-Video" }
                10 { $connectionType = "DisplayPort" }
                default { $connectionType = "Other/Unknown" }
            }
        }
    } catch {
        $connectionType = "Unknown"
    }

    Add-KeyValue "Resolution" "$($screen.Bounds.Width) x $($screen.Bounds.Height)"
    Add-KeyValue "Model" $displayModel
    Add-KeyValue "Refresh Rate" "$refreshRate Hz"
    Add-KeyValue "Connection Type" $connectionType

    # === Physical Hard Drive Info ===
    Add-SectionHeader "`n=== Physical Hard Drives ==="
    $diskDrives = Get-CimInstance Win32_DiskDrive
    foreach ($disk in $diskDrives) {
        $sizeGB = if ($disk.Size) { [math]::Round($disk.Size / 1GB, 2) } else { "Unknown" }
        Add-KeyValue "Model" $disk.Model
        Add-KeyValue "Device ID" $disk.DeviceID
        Add-KeyValue "Serial Number" $disk.SerialNumber.Trim()
        Add-KeyValue "Size" "$sizeGB GB"
        Add-KeyValue "Media Type" $disk.MediaType
        Add-NewLine
    }

    # === Logical Drive Info ===
    Add-SectionHeader "=== Logical Drives ==="
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($drive in $drives) {
        $total = [math]::Round($drive.Size / 1GB, 2)
        $free = [math]::Round($drive.FreeSpace / 1GB, 2)
        Add-ColoredLine "$($drive.DeviceID)   : Total = $total GB, Free = $free GB" ([System.Drawing.Color]::LightCyan)
    }

    # === Network Adapters (Physical) ===
    Add-SectionHeader "`n=== Network Adapters (Physical) ==="
    $netAdapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true -and $_.NetEnabled -eq $true }
    if ($netAdapters.Count -eq 0) {
        Add-ColoredLine "No physical network adapters found." ([System.Drawing.Color]::Gray) $true
    } else {
        foreach ($adapter in $netAdapters) {
            $speedStr = "Unknown"
            if ($adapter.Speed -and ($adapter.Speed -is [long] -or $adapter.Speed -is [int])) {
                # Speed is in bits per second, convert to Mbps
                $speedMbps = [math]::Round($adapter.Speed / 1MB, 2)
                $speedStr = "$speedMbps Mbps"
            } elseif ($adapter.Speed -match '^\d+') {
                # Declare variable first before passing as ref
                $speedParsed = 0
                if ([int]::TryParse(($adapter.Speed -replace '[^\d]',''), [ref]$speedParsed)) {
                    $speedStr = "$speedParsed Mbps"
                } else {
                    $speedStr = $adapter.Speed
                }
            } else {
                $speedStr = $adapter.Speed
            }
            Add-KeyValue "Name" $adapter.Name
            Add-KeyValue "Speed" $speedStr
            Add-KeyValue "MAC Address" $adapter.MACAddress
            Add-NewLine
        }
    }

    # === USB Devices ===
    Add-SectionHeader "`n=== USB Devices ==="
    try {
        $usbDevices = Get-PnpDevice -Class USB -Status OK | Sort-Object FriendlyName
        if ($usbDevices.Count -eq 0) {
            Add-ColoredLine "No USB devices detected." ([System.Drawing.Color]::Gray) $true
        } else {
            foreach ($dev in $usbDevices) {
                # Get hardware IDs
                $hwIds = try {
                    (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName "DEVPKEY_Device_HardwareIds").Data -join ", "
                } catch {
                    "Unknown"
                }
                Add-ColoredLine "Device:" ([System.Drawing.Color]::LightBlue) $true
                Add-KeyValue "Name" $dev.FriendlyName
                Add-KeyValue "Device Type" $dev.Class
                Add-KeyValue "Hardware IDs" $hwIds
                Add-NewLine
            }
        }
    } catch {
        Add-ColoredLine "Unable to retrieve USB device information." ([System.Drawing.Color]::Red) $true
    }
}

# Initial population
Get-SystemInfo

# Refresh button event
$refreshButton.Add_Click({
    Get-SystemInfo
})

# Export to file event
$exportButton.Add_Click({
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $sfd.FileName = "SystemInfo.txt"
    if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            # Save plain text version only
            $richTextBox.Text | Out-File -FilePath $sfd.FileName -Encoding UTF8
            [System.Windows.Forms.MessageBox]::Show("Export successful.", "Export", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to export: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# Show the form
[void]$form.ShowDialog()
