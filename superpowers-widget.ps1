param(
  [switch]$SelfTest,
  [switch]$CreateLinkRequest,
  [switch]$ConnectionStatus
)

$ErrorActionPreference = "Stop"

$Script:RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:WidgetDir = Join-Path $Script:RootDir ".superpowers-widget"
$Script:GuidePath = Join-Path $Script:WidgetDir "flow-guide.json"
$Script:StatePath = Join-Path $Script:WidgetDir "state.json"
$Script:LinkRequestPath = Join-Path $Script:WidgetDir "link-request.json"
$Script:WorkspacePath = $Script:RootDir
$Script:LastValidState = $null

function Read-JsonFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$Required
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    if ($Required) {
      throw "Required JSON file was not found: $Path"
    }
    return $null
  }

  $resolvedPath = Resolve-Path -LiteralPath $Path
  $raw = [System.IO.File]::ReadAllText($resolvedPath, [System.Text.UTF8Encoding]::new($false))
  if ([string]::IsNullOrWhiteSpace($raw)) {
    if ($Required) {
      throw "Required JSON file is empty: $Path"
    }
    return $null
  }

  return $raw | ConvertFrom-Json
}

function ConvertTo-WidgetJson {
  param([Parameter(Mandatory = $true)]$Value)
  return $Value | ConvertTo-Json -Depth 8
}

function New-WidgetLinkId {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $suffix = [Guid]::NewGuid().ToString("N").Substring(0, 8)
  return "widget-$stamp-$suffix"
}

function Write-LinkRequest {
  if (-not (Test-Path -LiteralPath $Script:WidgetDir)) {
    New-Item -ItemType Directory -Path $Script:WidgetDir | Out-Null
  }

  $now = Get-Date
  $request = [ordered]@{
    linkId = New-WidgetLinkId
    workspacePath = $Script:WorkspacePath
    requestedAt = $now.ToString("o")
    instruction = "현재 Codex 세션에서 'Superpowers 위젯 연결해줘'라고 요청하세요."
  }

  ConvertTo-WidgetJson $request | Set-Content -LiteralPath $Script:LinkRequestPath -Encoding UTF8
  return [pscustomobject]$request
}

function Get-LatestLinkRequest {
  return Read-JsonFile -Path $Script:LinkRequestPath
}

function Test-IsFreshState {
  param([Parameter(Mandatory = $true)]$State)

  if (-not $State.updatedAt) {
    return $false
  }

  $updatedAt = [DateTimeOffset]::Parse([string]$State.updatedAt)
  $age = [DateTimeOffset]::Now - $updatedAt
  if ($age.TotalHours -gt 6) {
    return $false
  }

  if ($State.expiresAt) {
    $expiresAt = [DateTimeOffset]::Parse([string]$State.expiresAt)
    if ([DateTimeOffset]::Now -gt $expiresAt) {
      return $false
    }
  }

  return $true
}

function Get-ConnectionStatus {
  $linkRequest = Get-LatestLinkRequest
  $state = Read-JsonFile -Path $Script:StatePath

  if ($state) {
    $Script:LastValidState = $state
  }

  if (-not $linkRequest) {
    return [pscustomobject]@{
      Mode = "Guide"
      Title = "안내 모드"
      Message = "아직 Codex 세션과 연결하지 않았습니다."
      State = $null
      LinkRequest = $null
    }
  }

  if (-not $state) {
    return [pscustomobject]@{
      Mode = "Waiting"
      Title = "연결 대기 중"
      Message = "현재 Codex 세션에서 위젯 연결을 요청하세요."
      State = $null
      LinkRequest = $linkRequest
    }
  }

  $sameLink = [string]$state.linkId -eq [string]$linkRequest.linkId
  $sameWorkspace = [string]$state.workspacePath -eq [string]$linkRequest.workspacePath
  $fresh = Test-IsFreshState -State $state

  if ($sameLink -and $sameWorkspace -and $fresh) {
    return [pscustomobject]@{
      Mode = "Linked"
      Title = "연결됨"
      Message = "Codex 세션과 연결되어 있습니다."
      State = $state
      LinkRequest = $linkRequest
    }
  }

  return [pscustomobject]@{
    Mode = "Stale"
    Title = "재연결 필요"
    Message = "마지막 연결이 오래됐거나 현재 연결 요청과 일치하지 않습니다."
    State = $state
    LinkRequest = $linkRequest
  }
}

function Assert-SelfTest {
  if (-not (Test-Path -LiteralPath $Script:GuidePath)) {
    throw "Missing flow-guide.json"
  }

  $guide = Read-JsonFile -Path $Script:GuidePath -Required
  if (-not $guide.items -or $guide.items.Count -lt 6) {
    throw "Guide must include combined flow and situation items."
  }

  foreach ($item in $guide.items) {
    foreach ($field in @("flow", "situation", "previousPlugin", "nowAction", "reason", "nextPlugin")) {
      if (-not $item.$field) {
        throw "Guide item is missing required field: $field"
      }
    }
  }

  $status = Get-ConnectionStatus
  if (-not $status.Mode) {
    throw "Connection status did not return a mode."
  }

  "SelfTest passed"
}

function New-TextBlock {
  param(
    [string]$Text,
    [double]$FontSize = 13,
    [string]$Weight = "Normal",
    [string]$Color = "#1E252B"
  )

  $block = New-Object System.Windows.Controls.TextBlock
  $block.Text = $Text
  $block.FontSize = $FontSize
  $block.FontWeight = $Weight
  $block.Foreground = $Color
  $block.TextWrapping = "Wrap"
  $block.Margin = "0,0,0,8"
  return $block
}

function New-DetailRow {
  param(
    [string]$Label,
    [string]$Value
  )

  $border = New-Object System.Windows.Controls.Border
  $border.Background = "#0F0B19"
  $border.BorderBrush = "#221936"
  $border.BorderThickness = "1"
  $border.CornerRadius = "8"
  $border.Padding = "10,8,10,8"
  $border.Margin = "0,0,0,8"

  $stack = New-Object System.Windows.Controls.StackPanel
  $labelPill = New-Object System.Windows.Controls.Border
  $labelPill.Background = "#120D1D"
  $labelPill.BorderBrush = "#3A2A56"
  $labelPill.BorderThickness = "1"
  $labelPill.CornerRadius = "6"
  $labelPill.Padding = "7,2,7,2"
  $labelPill.HorizontalAlignment = "Left"
  $labelPill.Margin = "0,0,0,6"
  $labelPill.Child = New-TextBlock -Text $Label -FontSize 11 -Weight "Bold" -Color "#B8A7DC"
  $stack.Children.Add($labelPill) | Out-Null
  $stack.Children.Add((New-TextBlock -Text $Value -FontSize 13 -Color "#EADFFF")) | Out-Null

  $border.Child = $stack
  return $border
}

function Set-FigmaButtonStyle {
  param([System.Windows.Controls.Button]$Button)

  $Button.Background = "#08060D"
  $Button.BorderBrush = "#08060D"
  $Button.BorderThickness = "1"
  $Button.Padding = "10,7,10,7"
  $Button.Margin = "0,0,0,4"
  $Button.HorizontalContentAlignment = "Stretch"
  $Button.Cursor = "Hand"
  $Button.Style = New-ButtonStyle -NormalBg "#08060D" -HoverBg "#120D1D" -PressedBg "#0F0B19" -Border "#08060D" -HoverBorder "#34254F" -Foreground "#EADFFF" -CornerRadius 5
}

function Set-SelectedGuideButtonStyle {
  param(
    [System.Windows.Controls.Button]$Button,
    [bool]$Selected,
    [bool]$Active = $false
  )

  if ($Active) {
    $Button.Background = "#123B7A"
    $Button.BorderBrush = "#60A5FA"
  } elseif ($Selected) {
    $Button.Background = "#120D1D"
    $Button.BorderBrush = "#34254F"
  } else {
    $Button.Background = "#08060D"
    $Button.BorderBrush = "#08060D"
  }
}

function Get-FlowKey {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }

  return ($Value.ToLowerInvariant() -replace "[^a-z0-9]", "")
}

function Get-DisplayFlowName {
  param(
    [string]$Value,
    [System.Collections.ArrayList]$Buttons
  )

  $targetKey = Get-FlowKey -Value $Value
  foreach ($button in $Buttons) {
    if ((Get-FlowKey -Value ([string]$button.Tag.flow)) -eq $targetKey) {
      return [string]$button.Tag.flow
    }
  }

  return $Value
}

function New-ButtonStyle {
  param(
    [string]$NormalBg = "#08060D",
    [string]$HoverBg = "#120D1D",
    [string]$PressedBg = "#0F0B19",
    [string]$Border = "#2B2140",
    [string]$HoverBorder = "#34254F",
    [string]$Foreground = "#EADFFF",
    [int]$CornerRadius = 5
  )

  $xaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="{x:Type Button}">
  <Setter Property="Background" Value="$NormalBg"/>
  <Setter Property="Foreground" Value="$Foreground"/>
  <Setter Property="BorderBrush" Value="$Border"/>
  <Setter Property="BorderThickness" Value="1"/>
  <Setter Property="HorizontalContentAlignment" Value="Center"/>
  <Setter Property="VerticalContentAlignment" Value="Center"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="{x:Type Button}">
        <Border x:Name="ButtonBorder"
                Background="{TemplateBinding Background}"
                BorderBrush="{TemplateBinding BorderBrush}"
                BorderThickness="{TemplateBinding BorderThickness}"
                CornerRadius="$CornerRadius"
                SnapsToDevicePixels="True">
          <ContentPresenter Margin="{TemplateBinding Padding}"
                            HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                            VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                            RecognizesAccessKey="True"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True">
            <Setter TargetName="ButtonBorder" Property="Background" Value="$HoverBg"/>
            <Setter TargetName="ButtonBorder" Property="BorderBrush" Value="$HoverBorder"/>
          </Trigger>
          <Trigger Property="IsPressed" Value="True">
            <Setter TargetName="ButtonBorder" Property="Background" Value="$PressedBg"/>
            <Setter TargetName="ButtonBorder" Property="BorderBrush" Value="$HoverBorder"/>
          </Trigger>
          <Trigger Property="IsEnabled" Value="False">
            <Setter Property="Opacity" Value="0.5"/>
          </Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
"@

  return [System.Windows.Markup.XamlReader]::Parse($xaml)
}

function Start-Widget {
  Add-Type -AssemblyName PresentationFramework
  Add-Type -AssemblyName PresentationCore
  Add-Type -AssemblyName WindowsBase

  $guide = Read-JsonFile -Path $Script:GuidePath -Required
  $items = @($guide.items)
  $expandedWidth = 760
  $collapsedWidth = 430

  $window = New-Object System.Windows.Window
  $window.Title = "Superpowers Guide"
  $window.Width = $expandedWidth
  $window.Height = 700
  $window.Topmost = $true
  $window.WindowStartupLocation = "Manual"
  $window.Left = [System.Windows.SystemParameters]::PrimaryScreenWidth - 800
  $window.Top = 80
  $window.Background = "#050408"

  $root = New-Object System.Windows.Controls.DockPanel
  $window.Content = $root

  $header = New-Object System.Windows.Controls.Border
  $header.Background = "#07050D"
  $header.BorderBrush = "#221936"
  $header.BorderThickness = "0,0,0,1"
  $header.Padding = "12,10,12,8"
  [System.Windows.Controls.DockPanel]::SetDock($header, "Top")
  $root.Children.Add($header) | Out-Null

  $headerGrid = New-Object System.Windows.Controls.Grid
  $headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
  $badgeCol = New-Object System.Windows.Controls.ColumnDefinition
  $badgeCol.Width = "Auto"
  $headerGrid.ColumnDefinitions.Add($badgeCol) | Out-Null
  $header.Child = $headerGrid

  $headerStack = New-Object System.Windows.Controls.StackPanel
  $headerStack.Children.Add((New-TextBlock -Text "Superpowers" -FontSize 17 -Weight "Bold" -Color "#F7F2FF")) | Out-Null
  $headerStack.Children.Add((New-TextBlock -Text "현재 흐름과 다음 플러그인을 빠르게 확인합니다." -FontSize 12 -Color "#9B8CB8")) | Out-Null
  [System.Windows.Controls.Grid]::SetColumn($headerStack, 0)
  $headerGrid.Children.Add($headerStack) | Out-Null

  $topBadge = New-Object System.Windows.Controls.Border
  $topBadge.Background = "#120D1D"
  $topBadge.BorderBrush = "#34254F"
  $topBadge.BorderThickness = "1"
  $topBadge.CornerRadius = "5"
  $topBadge.Padding = "7,3,7,3"
  $topBadge.VerticalAlignment = "Top"
  $topBadge.Margin = "8,0,0,0"
  $topBadge.Child = New-TextBlock -Text "● Always on top" -FontSize 11 -Color "#B8A7DC"
  [System.Windows.Controls.Grid]::SetColumn($topBadge, 1)
  $headerGrid.Children.Add($topBadge) | Out-Null
  $header.Add_MouseLeftButtonDown({ $window.DragMove() })

  $body = New-Object System.Windows.Controls.DockPanel
  $body.Background = "#06050A"
  $body.Margin = "0"
  $root.Children.Add($body) | Out-Null

  $statusPanel = New-Object System.Windows.Controls.Border
  $statusPanel.Background = "#08060D"
  $statusPanel.BorderBrush = "#2B2140"
  $statusPanel.BorderThickness = "1"
  $statusPanel.CornerRadius = "12"
  $statusPanel.Padding = "10"
  $statusPanel.Margin = "8,8,8,0"
  [System.Windows.Controls.DockPanel]::SetDock($statusPanel, "Top")
  $body.Children.Add($statusPanel) | Out-Null

  $statusGrid = New-Object System.Windows.Controls.Grid
  $statusGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
  $statusActionCol = New-Object System.Windows.Controls.ColumnDefinition
  $statusActionCol.Width = "Auto"
  $statusGrid.ColumnDefinitions.Add($statusActionCol) | Out-Null
  $statusPanel.Child = $statusGrid

  $statusStack = New-Object System.Windows.Controls.StackPanel
  [System.Windows.Controls.Grid]::SetColumn($statusStack, 0)
  $statusGrid.Children.Add($statusStack) | Out-Null

  $statusTitle = New-TextBlock -Text "⌁ 안내 모드" -FontSize 14 -Weight "Bold" -Color "#F7F2FF"
  $statusMessage = New-TextBlock -Text "아직 Codex 세션과 연결하지 않았습니다." -FontSize 12 -Color "#9B8CB8"
  $statusDetail = New-TextBlock -Text "" -FontSize 12 -Color "#B8A7DC"

  $flowStatusPanel = New-Object System.Windows.Controls.StackPanel
  $flowStatusPanel.Orientation = "Horizontal"
  $flowStatusPanel.Margin = "0,4,0,6"
  $flowStatusPanel.Visibility = "Collapsed"

  $currentFlowBadge = New-Object System.Windows.Controls.Border
  $currentFlowBadge.Background = "#0F1E3A"
  $currentFlowBadge.BorderBrush = "#3B82F6"
  $currentFlowBadge.BorderThickness = "1"
  $currentFlowBadge.CornerRadius = "6"
  $currentFlowBadge.Padding = "7,3,7,3"
  $currentFlowBadge.Margin = "0,0,6,0"
  $currentFlowText = New-TextBlock -Text "Flow: -" -FontSize 11 -Weight "Bold" -Color "#DBEAFE"
  $currentFlowBadge.Child = $currentFlowText

  $nextFlowBadge = New-Object System.Windows.Controls.Border
  $nextFlowBadge.Background = "#120D1D"
  $nextFlowBadge.BorderBrush = "#3A2A56"
  $nextFlowBadge.BorderThickness = "1"
  $nextFlowBadge.CornerRadius = "6"
  $nextFlowBadge.Padding = "7,3,7,3"
  $nextFlowText = New-TextBlock -Text "Next: -" -FontSize 11 -Weight "Bold" -Color "#B8A7DC"
  $nextFlowBadge.Child = $nextFlowText

  $flowStatusPanel.Children.Add($currentFlowBadge) | Out-Null
  $flowStatusPanel.Children.Add($nextFlowBadge) | Out-Null

  $linkBox = New-Object System.Windows.Controls.Border
  $linkBox.Background = "#0F0B19"
  $linkBox.BorderBrush = "#34254F"
  $linkBox.BorderThickness = "1"
  $linkBox.CornerRadius = "5"
  $linkBox.Padding = "8,6,8,6"
  $linkBox.Margin = "0,2,0,8"
  $linkBox.Visibility = "Collapsed"

  $linkGrid = New-Object System.Windows.Controls.Grid
  $linkGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
  $copyCol = New-Object System.Windows.Controls.ColumnDefinition
  $copyCol.Width = "72"
  $linkGrid.ColumnDefinitions.Add($copyCol) | Out-Null
  $linkBox.Child = $linkGrid

  $linkTextBox = New-Object System.Windows.Controls.TextBox
  $linkTextBox.IsReadOnly = $true
  $linkTextBox.BorderThickness = "0"
  $linkTextBox.Background = "#0F0B19"
  $linkTextBox.FontFamily = "Consolas"
  $linkTextBox.FontSize = 12
  $linkTextBox.Foreground = "#D9C8FF"
  $linkTextBox.Padding = "2"
  $linkTextBox.Add_GotKeyboardFocus({ $this.SelectAll() })
  [System.Windows.Controls.Grid]::SetColumn($linkTextBox, 0)
  $linkGrid.Children.Add($linkTextBox) | Out-Null

  $copyButton = New-Object System.Windows.Controls.Button
  $copyButton.Content = "복사"
  $copyButton.Height = 28
  $copyButton.Margin = "8,0,0,0"
  $copyButton.Background = "#151024"
  $copyButton.Foreground = "#EADFFF"
  $copyButton.BorderBrush = "#4C3474"
  $copyButton.BorderThickness = "1"
  $copyButton.Cursor = "Hand"
  $copyButton.Style = New-ButtonStyle -NormalBg "#151024" -HoverBg "#211533" -PressedBg "#2A1A42" -Border "#4C3474" -HoverBorder "#4C3474" -Foreground "#EADFFF" -CornerRadius 5
  [System.Windows.Controls.Grid]::SetColumn($copyButton, 1)
  $linkGrid.Children.Add($copyButton) | Out-Null

  $connectButton = New-Object System.Windows.Controls.Button
  $connectButton.Content = "Codex 세션 연결 요청"
  $connectButton.Height = 34
  $connectButton.Margin = "12,4,0,0"
  $connectButton.Background = "#151024"
  $connectButton.Foreground = "#EADFFF"
  $connectButton.BorderBrush = "#4C3474"
  $connectButton.BorderThickness = "1"
  $connectButton.Cursor = "Hand"
  $connectButton.Style = New-ButtonStyle -NormalBg "#151024" -HoverBg "#211533" -PressedBg "#2A1A42" -Border "#4C3474" -HoverBorder "#4C3474" -Foreground "#EADFFF" -CornerRadius 5
  $connectButton.Add_Click({
    $request = Write-LinkRequest
    $statusTitle.Text = "연결 요청 생성됨"
    $statusMessage.Text = "현재 Codex 세션에서 'Superpowers 위젯 연결해줘'라고 요청하세요."
    $statusDetail.Text = "아래 ID를 복사해서 현재 Codex 세션에 전달할 수 있습니다."
    $linkTextBox.Text = $request.linkId
    $copyButton.Content = "복사"
    $linkBox.Visibility = "Visible"
  })
  $copyButton.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($linkTextBox.Text)) {
      [System.Windows.Clipboard]::SetText($linkTextBox.Text)
      $copyButton.Content = "완료"
    }
  })

  $disconnectButton = New-Object System.Windows.Controls.Button
  $disconnectButton.Content = "세션 해제"
  $disconnectButton.Height = 30
  $disconnectButton.Margin = "12,6,0,0"
  $disconnectButton.Background = "#12080B"
  $disconnectButton.Foreground = "#FCA5A5"
  $disconnectButton.BorderBrush = "#7F1D1D"
  $disconnectButton.BorderThickness = "1"
  $disconnectButton.Cursor = "Hand"
  $disconnectButton.Style = New-ButtonStyle -NormalBg "#12080B" -HoverBg "#1A0C10" -PressedBg "#220F14" -Border "#7F1D1D" -HoverBorder "#991B1B" -Foreground "#FCA5A5" -CornerRadius 5
  $disconnectButton.Add_Click({
    Remove-Item -LiteralPath $Script:StatePath -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Script:LinkRequestPath -ErrorAction SilentlyContinue
    $activeFlowState.Value = ""
    Update-GuideButtonStates
    $statusTitle.Text = "⌁ 안내 모드"
    $statusMessage.Text = "아직 Codex 세션과 연결하지 않았습니다."
    $statusDetail.Text = ""
    $linkTextBox.Text = ""
    $linkBox.Visibility = "Collapsed"
    $flowStatusPanel.Visibility = "Collapsed"
  })

  $statusStack.Children.Add($statusTitle) | Out-Null
  $statusStack.Children.Add($statusMessage) | Out-Null
  $statusStack.Children.Add($flowStatusPanel) | Out-Null
  $statusStack.Children.Add($statusDetail) | Out-Null
  $statusStack.Children.Add($linkBox) | Out-Null

  $statusActionStack = New-Object System.Windows.Controls.StackPanel
  $statusActionStack.Children.Add($connectButton) | Out-Null
  $statusActionStack.Children.Add($disconnectButton) | Out-Null
  [System.Windows.Controls.Grid]::SetColumn($statusActionStack, 1)
  $statusGrid.Children.Add($statusActionStack) | Out-Null

  $contentGrid = New-Object System.Windows.Controls.Grid
  $contentGrid.Margin = "8"
  $leftCol = New-Object System.Windows.Controls.ColumnDefinition
  $leftCol.Width = "365"
  $contentGrid.ColumnDefinitions.Add($leftCol) | Out-Null
  $rightCol = New-Object System.Windows.Controls.ColumnDefinition
  $rightCol.Width = "*"
  $contentGrid.ColumnDefinitions.Add($rightCol) | Out-Null
  $body.Children.Add($contentGrid) | Out-Null

  $listPanel = New-Object System.Windows.Controls.Border
  $listPanel.Background = "#08060D"
  $listPanel.BorderBrush = "#2B2140"
  $listPanel.BorderThickness = "1"
  $listPanel.CornerRadius = "12"
  $listPanel.Margin = "0,0,8,0"
  [System.Windows.Controls.Grid]::SetColumn($listPanel, 0)
  $contentGrid.Children.Add($listPanel) | Out-Null

  $listDock = New-Object System.Windows.Controls.DockPanel
  $listPanel.Child = $listDock

  $listHeader = New-Object System.Windows.Controls.Grid
  $listHeader.Margin = "10,7,10,5"
  $listHeader.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
  $listCountCol = New-Object System.Windows.Controls.ColumnDefinition
  $listCountCol.Width = "Auto"
  $listHeader.ColumnDefinitions.Add($listCountCol) | Out-Null
  $listHeader.Children.Add((New-TextBlock -Text "Flows" -FontSize 13 -Weight "Bold" -Color "#F7F2FF")) | Out-Null
  $countText = New-TextBlock -Text "$($items.Count) items" -FontSize 11 -Color "#9B8CB8"
  [System.Windows.Controls.Grid]::SetColumn($countText, 1)
  $listHeader.Children.Add($countText) | Out-Null
  [System.Windows.Controls.DockPanel]::SetDock($listHeader, "Top")
  $listDock.Children.Add($listHeader) | Out-Null

  $listScroll = New-Object System.Windows.Controls.ScrollViewer
  $listScroll.VerticalScrollBarVisibility = "Auto"
  $listStack = New-Object System.Windows.Controls.StackPanel
  $listStack.Margin = "8,0,8,8"
  $listScroll.Content = $listStack
  $listDock.Children.Add($listScroll) | Out-Null

  $detailPanel = New-Object System.Windows.Controls.Border
  $detailPanel.Background = "#08060D"
  $detailPanel.BorderBrush = "#2B2140"
  $detailPanel.BorderThickness = "1"
  $detailPanel.CornerRadius = "12"
  $detailPanel.Padding = "8"
  [System.Windows.Controls.Grid]::SetColumn($detailPanel, 1)
  $contentGrid.Children.Add($detailPanel) | Out-Null

  $detailStack = New-Object System.Windows.Controls.StackPanel
  $detailPanel.Child = $detailStack
  $guideButtons = New-Object System.Collections.ArrayList
  $guideButtonViews = New-Object System.Collections.ArrayList
  $selectedGuideButton = [pscustomobject]@{
    Value = $null
  }
  $detailModeState = [pscustomobject]@{
    Expanded = $true
  }
  $activeFlowState = [pscustomobject]@{
    Value = ""
  }
  $lastFocusedFlowKey = [pscustomobject]@{
    Value = ""
  }
  $latestConnectionState = [pscustomobject]@{
    Value = $null
  }
  $detailState = [pscustomobject]@{
    CurrentItem = $null
  }

  function Update-GuideButtonStates {
    $activeKey = Get-FlowKey -Value $activeFlowState.Value
    foreach ($view in $guideButtonViews) {
      $guideButton = $view.Button
      $isSelected = $detailModeState.Expanded -and ($guideButton -eq $selectedGuideButton.Value)
      $isActive = -not [string]::IsNullOrWhiteSpace($activeKey) -and ((Get-FlowKey -Value ([string]$view.Item.flow)) -eq $activeKey)
      Set-SelectedGuideButtonStyle -Button $guideButton -Selected $isSelected -Active $isActive

      if ($isActive) {
        $view.Badge.Background = "#1D4ED8"
        $view.Badge.BorderBrush = "#93C5FD"
        $view.BadgeText.Foreground = "#DBEAFE"
        $view.Activity.Visibility = "Visible"
      } else {
        $view.Badge.Background = "#120D1D"
        $view.Badge.BorderBrush = "#3A2A56"
        $view.BadgeText.Foreground = "#B8A7DC"
        $view.Activity.Visibility = "Collapsed"
      }
    }
  }

  function Focus-ActiveFlow {
    param([string]$Flow)

    $flowKey = Get-FlowKey -Value $Flow
    if ([string]::IsNullOrWhiteSpace($flowKey) -or $lastFocusedFlowKey.Value -eq $flowKey) {
      return
    }

    foreach ($view in $guideButtonViews) {
      if ((Get-FlowKey -Value ([string]$view.Item.flow)) -eq $flowKey) {
        $lastFocusedFlowKey.Value = $flowKey
        $selectedGuideButton.Value = $view.Button
        Show-ItemDetail -Item $view.Item
        $view.Button.BringIntoView()
        return
      }
    }
  }

  function Get-DetailNowAction {
    param($Item)

    $state = $latestConnectionState.Value
    if ($state) {
      $sameFlow = (Get-FlowKey -Value ([string]$state.currentFlow)) -eq (Get-FlowKey -Value ([string]$Item.flow))
      if ($sameFlow -and -not [string]::IsNullOrWhiteSpace([string]$state.recommendedAction)) {
        return [string]$state.recommendedAction
      }
    }

    return [string]$Item.nowAction
  }

  function Set-WidgetDetailMode {
    param([bool]$Expanded)

    $rightEdge = $window.Left + $window.Width
    if ($Expanded) {
      $window.Width = $expandedWidth
      $window.Left = $rightEdge - $expandedWidth
      $rightCol.Width = "*"
      $detailPanel.Padding = "8"
    } else {
      $window.Width = $collapsedWidth
      $window.Left = $rightEdge - $collapsedWidth
      $rightCol.Width = "42"
      $detailPanel.Padding = "6"
    }
  }

  function Collapse-DetailPanel {
    $detailModeState.Expanded = $false
    Set-WidgetDetailMode -Expanded $false
    $detailStack.Children.Clear()
    Update-GuideButtonStates

    $expandButton = New-Object System.Windows.Controls.Button
    $expandButton.Content = "+"
    $expandButton.Width = 30
    $expandButton.Height = 30
    $expandButton.Background = "#25143D"
    $expandButton.Foreground = "#D8B4FE"
    $expandButton.BorderBrush = "#8B5CF6"
    $expandButton.BorderThickness = "1"
    $expandButton.Cursor = "Hand"
    $expandButton.ToolTip = "상세 펼치기"
    $expandButton.Style = New-ButtonStyle -NormalBg "#25143D" -HoverBg "#321A54" -PressedBg "#3D2065" -Border "#8B5CF6" -HoverBorder "#A855F7" -Foreground "#D8B4FE" -CornerRadius 6
    $expandButton.Add_Click({
      Set-WidgetDetailMode -Expanded $true
      $detailModeState.Expanded = $true
      if ($detailState.CurrentItem) {
        Show-ItemDetail -Item $detailState.CurrentItem
      }
    })

    $detailStack.Children.Add($expandButton) | Out-Null
  }

  function Show-ItemDetail {
    param($Item)

    $detailModeState.Expanded = $true
    $detailState.CurrentItem = $Item
    Set-WidgetDetailMode -Expanded $true
    $detailStack.Children.Clear()
    Update-GuideButtonStates

    $detailHeader = New-Object System.Windows.Controls.Button
    $detailHeader.Background = "#0F0B19"
    $detailHeader.BorderBrush = "#221936"
    $detailHeader.BorderThickness = "1"
    $detailHeader.Padding = "10,8,10,8"
    $detailHeader.Margin = "0,0,0,8"
    $detailHeader.Cursor = "Hand"
    $detailHeader.ToolTip = "상세 접기"
    $detailHeader.HorizontalContentAlignment = "Stretch"
    $detailHeader.Style = New-ButtonStyle -NormalBg "#0F0B19" -HoverBg "#120D1D" -PressedBg "#171024" -Border "#221936" -HoverBorder "#34254F" -Foreground "#F7F2FF" -CornerRadius 8
    $detailHeader.Add_Click({
      Collapse-DetailPanel
    })

    $detailHeaderGrid = New-Object System.Windows.Controls.Grid
    $detailHeaderGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
    $tagCol = New-Object System.Windows.Controls.ColumnDefinition
    $tagCol.Width = "Auto"
    $detailHeaderGrid.ColumnDefinitions.Add($tagCol) | Out-Null
    $detailHeaderGrid.Children.Add((New-TextBlock -Text "‹  상세" -FontSize 13 -Weight "Bold" -Color "#F7F2FF")) | Out-Null
    $flowTag = New-Object System.Windows.Controls.Border
    $flowTag.Background = "#25143D"
    $flowTag.BorderBrush = "#8B5CF6"
    $flowTag.BorderThickness = "1"
    $flowTag.CornerRadius = "5"
    $flowTag.Padding = "6,2,6,2"
    $flowTag.Child = New-TextBlock -Text $Item.flow -FontSize 11 -Weight "Bold" -Color "#D8B4FE"
    [System.Windows.Controls.Grid]::SetColumn($flowTag, 1)
    $detailHeaderGrid.Children.Add($flowTag) | Out-Null
    $detailHeader.Content = $detailHeaderGrid
    $detailStack.Children.Add($detailHeader) | Out-Null

    $detailStack.Children.Add((New-DetailRow -Label "선행 플러그인" -Value $Item.previousPlugin)) | Out-Null
    $detailStack.Children.Add((New-DetailRow -Label "지금 할 일" -Value (Get-DetailNowAction -Item $Item))) | Out-Null
    $detailStack.Children.Add((New-DetailRow -Label "다음 플러그인" -Value $Item.nextPlugin)) | Out-Null
    $detailStack.Children.Add((New-DetailRow -Label "이유" -Value $Item.reason)) | Out-Null
  }

  foreach ($item in $items) {
    $button = New-Object System.Windows.Controls.Button
    Set-FigmaButtonStyle -Button $button

    $card = New-Object System.Windows.Controls.StackPanel
    $line = New-Object System.Windows.Controls.Grid
    $badgeCol = New-Object System.Windows.Controls.ColumnDefinition
    $badgeCol.Width = "Auto"
    $line.ColumnDefinitions.Add($badgeCol) | Out-Null
    $flowCol = New-Object System.Windows.Controls.ColumnDefinition
    $flowCol.Width = "*"
    $line.ColumnDefinitions.Add($flowCol) | Out-Null
    $activityCol = New-Object System.Windows.Controls.ColumnDefinition
    $activityCol.Width = "Auto"
    $line.ColumnDefinitions.Add($activityCol) | Out-Null

    $badge = New-Object System.Windows.Controls.Border
    $badge.Background = "#120D1D"
    $badge.BorderBrush = "#3A2A56"
    $badge.BorderThickness = "1"
    $badge.CornerRadius = "6"
    $badge.Padding = "7,3,7,3"
    $badge.Margin = "0,0,8,0"
    $badgeText = New-TextBlock -Text "FLOW" -FontSize 11 -Weight "Bold" -Color "#B8A7DC"
    $badge.Child = $badgeText
    [System.Windows.Controls.Grid]::SetColumn($badge, 0)
    $line.Children.Add($badge) | Out-Null

    $flowText = New-TextBlock -Text $item.flow -FontSize 14 -Weight "Bold" -Color "#F1E9FF"
    [System.Windows.Controls.Grid]::SetColumn($flowText, 1)
    $line.Children.Add($flowText) | Out-Null

    $activity = New-Object System.Windows.Controls.Border
    $activity.Background = "#1D4ED8"
    $activity.BorderBrush = "#93C5FD"
    $activity.BorderThickness = "1"
    $activity.CornerRadius = "6"
    $activity.Padding = "7,1,7,2"
    $activity.Margin = "8,0,0,0"
    $activity.Visibility = "Collapsed"
    $activity.Child = New-TextBlock -Text "현재" -FontSize 12 -Weight "Bold" -Color "#DBEAFE"
    [System.Windows.Controls.Grid]::SetColumn($activity, 2)
    $line.Children.Add($activity) | Out-Null

    $card.Children.Add($line) | Out-Null
    $situationText = New-TextBlock -Text $item.situation -FontSize 13 -Color "#B8A7DC"
    $situationText.Margin = "54,2,0,0"
    $card.Children.Add($situationText) | Out-Null
    $button.Content = $card

    $button.Tag = $item
    $button.Add_Click({
      $selectedGuideButton.Value = $this
      Update-GuideButtonStates
      Show-ItemDetail -Item $this.Tag
    })
    $guideButtons.Add($button) | Out-Null
    $guideButtonViews.Add([pscustomobject]@{
      Button = $button
      Item = $item
      Badge = $badge
      BadgeText = $badgeText
      Activity = $activity
    }) | Out-Null
    $listStack.Children.Add($button) | Out-Null
  }

  if ($items.Count -gt 0) {
    $selectedGuideButton.Value = $guideButtons[0]
    Update-GuideButtonStates
    Show-ItemDetail -Item $items[0]
  }

  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromSeconds(2)
  $timer.Add_Tick({
    try {
      $connection = Get-ConnectionStatus
      $statusTitle.Text = $connection.Title
      $statusMessage.Text = $connection.Message

      if ($connection.State) {
        $latestConnectionState.Value = $connection.State
        $blocked = ""
        if ($connection.State.blockedActions) {
          $blocked = " / 금지: " + (($connection.State.blockedActions | ForEach-Object { [string]$_ }) -join ", ")
        }
        $displayFlow = Get-DisplayFlowName -Value ([string]$connection.State.currentFlow) -Buttons $guideButtons
        $activeSkill = [string]$connection.State.activeSkill
        $activeSkillDetail = ""
        if (-not [string]::IsNullOrWhiteSpace($activeSkill) -and ((Get-FlowKey -Value $activeSkill) -ne (Get-FlowKey -Value ([string]$connection.State.currentFlow)))) {
          $activeSkillDetail = " / 보조 활동: $activeSkill"
        }
        $currentFlowText.Text = "Flow: $displayFlow"
        $nextFlowText.Text = "Next: $($connection.State.nextSkill)"
        $activeFlowState.Value = [string]$connection.State.currentFlow
        Update-GuideButtonStates
        Focus-ActiveFlow -Flow ([string]$connection.State.currentFlow)
        if ($detailState.CurrentItem -and ((Get-FlowKey -Value ([string]$detailState.CurrentItem.flow)) -eq (Get-FlowKey -Value ([string]$connection.State.currentFlow)))) {
          Show-ItemDetail -Item $detailState.CurrentItem
        }
        $flowStatusPanel.Visibility = "Visible"
        $statusDetail.Text = "상태: $($connection.State.status)$activeSkillDetail$blocked"
      } elseif ($connection.LinkRequest) {
        $latestConnectionState.Value = $null
        $activeFlowState.Value = ""
        Update-GuideButtonStates
        $flowStatusPanel.Visibility = "Collapsed"
        $statusDetail.Text = "아래 ID를 복사해서 현재 Codex 세션에 전달할 수 있습니다."
        $linkTextBox.Text = $connection.LinkRequest.linkId
        $linkBox.Visibility = "Visible"
      } else {
        $latestConnectionState.Value = $null
        $activeFlowState.Value = ""
        Update-GuideButtonStates
        $flowStatusPanel.Visibility = "Collapsed"
        $statusDetail.Text = ""
        $linkBox.Visibility = "Collapsed"
      }
    } catch {
      $statusTitle.Text = "상태 읽기 오류"
      $statusMessage.Text = "상태 파일을 읽을 수 없습니다."
      if ($Script:LastValidState) {
        $displayFlow = Get-DisplayFlowName -Value ([string]$Script:LastValidState.currentFlow) -Buttons $guideButtons
        $currentFlowText.Text = "Flow: $displayFlow"
        $nextFlowText.Text = "Next: $($Script:LastValidState.nextSkill)"
        $activeFlowState.Value = [string]$Script:LastValidState.currentFlow
        Update-GuideButtonStates
        $flowStatusPanel.Visibility = "Visible"
        $statusDetail.Text = "마지막 정상 상태를 표시 중입니다. 오류: $($_.Exception.Message)"
      } else {
        $activeFlowState.Value = ""
        Update-GuideButtonStates
        $flowStatusPanel.Visibility = "Collapsed"
        $statusDetail.Text = $_.Exception.Message
      }
    }
  })
  $timer.Start()

  [void]$window.ShowDialog()
}

if ($SelfTest) {
  Assert-SelfTest
  exit 0
}

if ($CreateLinkRequest) {
  $request = Write-LinkRequest
  ConvertTo-WidgetJson $request
  exit 0
}

if ($ConnectionStatus) {
  $status = Get-ConnectionStatus
  ConvertTo-WidgetJson $status
  exit 0
}

Start-Widget
