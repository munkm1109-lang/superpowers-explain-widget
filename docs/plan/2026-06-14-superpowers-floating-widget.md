# Superpowers Floating Widget Implementation Plan

> Current status note: this is the first Windows-widget implementation plan. The current shipped runtime contract is widget ID-specific: `.superpowers-widget/runtime/links/<widget-id>.json` and `.superpowers-widget/runtime/states/<widget-id>.json`. Legacy `.superpowers-widget/link-request.json` and `.superpowers-widget/state.json` are compatibility mirrors only. Use `docs/plan/2026-06-15-web-widget-implementation.md` and `README.md` for current install and runtime behavior.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight Windows floating widget launched by `.bat` that explains Superpowers flows and shows a user-requested Codex session link state.

**Architecture:** The widget is a local PowerShell/WPF utility. Static guide content lives in `.superpowers-widget/flow-guide.json`; session status lives in `.superpowers-widget/state.json`; user-requested linking writes `.superpowers-widget/link-request.json`. The widget never calls AI or controls Codex directly.

**Tech Stack:** Windows Batch, PowerShell 5+/7 compatible script style, WPF via .NET assemblies, JSON files, Git.

---

## File Structure

- Create: `start-superpowers-widget.bat`
  - User-facing double-click launcher.
  - Starts `superpowers-widget.ps1` with `-ExecutionPolicy Bypass` for this process only.

- Create: `superpowers-widget.ps1`
  - Implements the floating WPF widget.
  - Provides helper functions for JSON loading, link request creation, active/stale link detection, and UI refresh.
  - Supports `-SelfTest` for lightweight non-UI verification.

- Create: `.superpowers-widget/flow-guide.json`
  - Static Korean guide content for Flow and Situation tabs.

- Create: `.superpowers-widget/state.example.json`
  - Example linked-state file for users and tests.

- Runtime-created: `.superpowers-widget/link-request.json`
  - Created only when the user requests session linking from the widget.

- Runtime-created: `.superpowers-widget/state.json`
  - Written by Codex after the user asks the current Codex session to connect.

---

### Task 1: Add Static Guide Data

**Files:**
- Create: `.superpowers-widget/flow-guide.json`
- Create: `.superpowers-widget/state.example.json`

- [ ] **Step 1: Verify guide data does not exist yet**

Run:

```powershell
Test-Path -LiteralPath '.superpowers-widget\flow-guide.json'
Test-Path -LiteralPath '.superpowers-widget\state.example.json'
```

Expected:

```text
False
False
```

- [ ] **Step 2: Create `.superpowers-widget/flow-guide.json`**

Create the file with this exact content:

```json
{
  "flows": [
    {
      "name": "brainstorming",
      "label": "Brainstorming",
      "when": "새 기능, UI, 동작 변경처럼 무엇을 만들지 먼저 정해야 할 때 사용합니다.",
      "does": "대략적인 아이디어를 질문, 대안 비교, 설계 승인 흐름으로 정리합니다.",
      "expect": "바로 코딩하지 않고, 설계 문서를 먼저 만듭니다.",
      "next": "writing-plans",
      "warning": "설계 승인 전에는 구현 코드를 쓰지 않습니다."
    },
    {
      "name": "using-git-worktrees",
      "label": "Using Git Worktrees",
      "when": "승인된 설계를 기존 작업과 분리해서 안전하게 구현하고 싶을 때 사용합니다.",
      "does": "새 브랜치와 격리된 작업 폴더를 준비합니다.",
      "expect": "현재 작업물을 덜 건드리면서 구현을 시작할 수 있습니다.",
      "next": "writing-plans 또는 구현 단계",
      "warning": "첫 버전 위젯 구현에서는 필요할 때만 사용합니다."
    },
    {
      "name": "writing-plans",
      "label": "Writing Plans",
      "when": "설계가 승인됐고, 실제 구현 작업을 작게 쪼개야 할 때 사용합니다.",
      "does": "만들 파일, 코드, 검증 명령, 커밋 단위를 계획합니다.",
      "expect": "작업자가 그대로 따라 할 수 있는 체크리스트가 생깁니다.",
      "next": "subagent-driven-development 또는 executing-plans",
      "warning": "계획에는 빈칸이나 막연한 지시를 남기지 않습니다."
    },
    {
      "name": "subagent-driven-development",
      "label": "Subagent-Driven Development",
      "when": "여러 작업을 빠르게 나눠 처리하고 각 작업 뒤 리뷰가 필요할 때 사용합니다.",
      "does": "작업별로 새 하위 에이전트를 보내고 결과를 검토합니다.",
      "expect": "빠른 병렬 진행과 작업 단위 리뷰를 기대할 수 있습니다.",
      "next": "requesting-code-review",
      "warning": "작업 범위가 작고 독립적일 때 가장 효과적입니다."
    },
    {
      "name": "executing-plans",
      "label": "Executing Plans",
      "when": "현재 세션에서 계획을 순서대로 직접 실행할 때 사용합니다.",
      "does": "계획의 체크박스를 따라 구현, 검증, 커밋을 진행합니다.",
      "expect": "사용자 확인 지점이 있는 안정적인 순차 실행을 기대할 수 있습니다.",
      "next": "requesting-code-review",
      "warning": "계획 밖으로 임의 확장하지 않습니다."
    },
    {
      "name": "test-driven-development",
      "label": "Test-Driven Development",
      "when": "구현할 동작을 검증 가능하게 고정해야 할 때 사용합니다.",
      "does": "실패 테스트 작성, 실패 확인, 최소 구현, 통과 확인 순서로 진행합니다.",
      "expect": "작동한다고 말하기 전에 증거를 만듭니다.",
      "next": "requesting-code-review",
      "warning": "테스트 없이 먼저 만든 코드는 되돌리고 테스트부터 다시 시작합니다."
    },
    {
      "name": "requesting-code-review",
      "label": "Requesting Code Review",
      "when": "작업 단위가 끝났고 다음 작업으로 넘어가기 전에 품질 점검이 필요할 때 사용합니다.",
      "does": "계획 준수, 결함, 누락 테스트, 유지보수 위험을 검토합니다.",
      "expect": "치명적 이슈가 있으면 다음 단계로 넘어가지 않습니다.",
      "next": "수정 또는 finishing-a-development-branch",
      "warning": "리뷰는 칭찬보다 문제 발견이 목적입니다."
    },
    {
      "name": "finishing-a-development-branch",
      "label": "Finishing a Development Branch",
      "when": "구현과 검증이 끝났고 브랜치를 마무리할 때 사용합니다.",
      "does": "최종 테스트, 상태 확인, 병합/PR/유지/폐기 선택지를 정리합니다.",
      "expect": "끝났다고 말하기 전에 마지막 증거를 확인합니다.",
      "next": "완료",
      "warning": "테스트 실패나 미검증 위험을 숨기지 않습니다."
    }
  ],
  "situations": [
    {
      "name": "새 기능 또는 UI 요청",
      "startSkill": "brainstorming",
      "why": "기능의 목적, 제약, 성공 기준을 먼저 정해야 하기 때문입니다.",
      "then": "writing-plans -> test-driven-development -> requesting-code-review",
      "plain": "바로 만들기보다 설계도를 먼저 그리고, 그다음 작은 작업으로 나눕니다."
    },
    {
      "name": "버그 조사",
      "startSkill": "systematic-debugging",
      "why": "추측으로 고치지 않고 원인을 좁혀야 하기 때문입니다.",
      "then": "test-driven-development -> verification-before-completion",
      "plain": "증상을 보고 바로 손대지 않고, 왜 생겼는지 확인한 뒤 고칩니다."
    },
    {
      "name": "리팩터링 또는 정리",
      "startSkill": "brainstorming 또는 writing-plans",
      "why": "기존 동작을 보존하면서 정리 범위를 작게 잡아야 하기 때문입니다.",
      "then": "test-driven-development -> requesting-code-review",
      "plain": "겉보기 동작은 유지하고, 내부만 더 단순하게 만듭니다."
    },
    {
      "name": "코드 리뷰",
      "startSkill": "requesting-code-review",
      "why": "동작 결함, 테스트 누락, 유지보수 위험을 먼저 찾아야 하기 때문입니다.",
      "then": "receiving-code-review 또는 수정 작업",
      "plain": "좋은 점보다 문제가 될 부분을 먼저 확인합니다."
    },
    {
      "name": "브랜치 마무리",
      "startSkill": "finishing-a-development-branch",
      "why": "완료 전 최종 검증과 정리 선택지가 필요하기 때문입니다.",
      "then": "merge, PR, keep, discard 중 선택",
      "plain": "정말 끝났는지 확인하고 작업을 어떻게 보관할지 정합니다."
    },
    {
      "name": "뭘 해야 할지 모를 때",
      "startSkill": "brainstorming",
      "why": "상황과 목표를 먼저 말로 정리해야 다음 행동을 고를 수 있기 때문입니다.",
      "then": "상황에 맞는 다음 Superpowers flow",
      "plain": "지금 어디에 있는지부터 확인하고 다음 스킬을 고릅니다."
    }
  ]
}
```

- [ ] **Step 3: Create `.superpowers-widget/state.example.json`**

Create the file with this exact content:

```json
{
  "linkId": "widget-example-link",
  "sessionId": "manual-example-session",
  "sessionLabel": "Example Codex session",
  "workspacePath": "C:\\Users\\munkm\\OneDrive\\Documents\\New project",
  "currentFlow": "brainstorming",
  "status": "설계 검토 중",
  "nextSkill": "writing-plans",
  "recommendedAction": "설계 문서를 승인하면 구현 계획을 작성합니다.",
  "blockedActions": [
    "설계 승인 전 구현 코드를 작성하지 않습니다."
  ],
  "updatedAt": "2026-06-14T00:00:00+09:00",
  "expiresAt": "2099-12-31T23:59:59+09:00"
}
```

- [ ] **Step 4: Verify JSON parses**

Run:

```powershell
Get-Content -Raw -LiteralPath '.superpowers-widget\flow-guide.json' | ConvertFrom-Json | Out-Null
Get-Content -Raw -LiteralPath '.superpowers-widget\state.example.json' | ConvertFrom-Json | Out-Null
```

Expected: no output and exit code `0`.

- [ ] **Step 5: Commit**

```bash
git add .superpowers-widget/flow-guide.json .superpowers-widget/state.example.json
git commit -m "Add Superpowers widget guide data"
```

---

### Task 2: Add Launcher

**Files:**
- Create: `start-superpowers-widget.bat`

- [ ] **Step 1: Verify launcher does not exist yet**

Run:

```powershell
Test-Path -LiteralPath '.\start-superpowers-widget.bat'
```

Expected:

```text
False
```

- [ ] **Step 2: Create `start-superpowers-widget.bat`**

Create the file with this exact content:

```bat
@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "WIDGET_SCRIPT=%SCRIPT_DIR%superpowers-widget.ps1"

if not exist "%WIDGET_SCRIPT%" (
  echo Superpowers widget script was not found.
  echo Expected: %WIDGET_SCRIPT%
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WIDGET_SCRIPT%"

if errorlevel 1 (
  echo.
  echo Superpowers widget could not start.
  echo If Windows blocked PowerShell, right-click the file and choose Run as administrator once, or ask Codex to check the PowerShell policy.
  pause
)
```

- [ ] **Step 3: Verify launcher references the widget script**

Run:

```powershell
Select-String -LiteralPath '.\start-superpowers-widget.bat' -Pattern 'superpowers-widget.ps1'
```

Expected: one or more matching lines.

- [ ] **Step 4: Commit**

```bash
git add start-superpowers-widget.bat
git commit -m "Add Superpowers widget launcher"
```

---

### Task 3: Add Widget Script with Self-Test Mode

**Files:**
- Create: `superpowers-widget.ps1`

- [ ] **Step 1: Verify script does not exist yet**

Run:

```powershell
Test-Path -LiteralPath '.\superpowers-widget.ps1'
```

Expected:

```text
False
```

- [ ] **Step 2: Create `superpowers-widget.ps1`**

Create the file with this exact content:

```powershell
param(
  [switch]$SelfTest,
  [switch]$CreateLinkRequest
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

  $raw = Get-Content -Raw -LiteralPath $Path
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
      State = $state
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
  if (-not $guide.flows -or $guide.flows.Count -lt 7) {
    throw "Guide must include the main Superpowers flows."
  }
  if (-not $guide.situations -or $guide.situations.Count -lt 5) {
    throw "Guide must include common situations."
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

function Add-GuideCard {
  param(
    [System.Windows.Controls.Panel]$Panel,
    [string]$Title,
    [string[]]$Lines
  )

  $border = New-Object System.Windows.Controls.Border
  $border.BorderBrush = "#D2D8DE"
  $border.BorderThickness = "1"
  $border.CornerRadius = "8"
  $border.Background = "#FFFFFF"
  $border.Padding = "12"
  $border.Margin = "0,0,0,10"

  $stack = New-Object System.Windows.Controls.StackPanel
  $stack.Children.Add((New-TextBlock -Text $Title -FontSize 15 -Weight "Bold" -Color "#2458D3")) | Out-Null
  foreach ($line in $Lines) {
    $stack.Children.Add((New-TextBlock -Text $line -FontSize 12 -Color "#4F5B66")) | Out-Null
  }

  $border.Child = $stack
  $Panel.Children.Add($border) | Out-Null
}

function Start-Widget {
  Add-Type -AssemblyName PresentationFramework
  Add-Type -AssemblyName PresentationCore
  Add-Type -AssemblyName WindowsBase

  $guide = Read-JsonFile -Path $Script:GuidePath -Required

  $window = New-Object System.Windows.Window
  $window.Title = "Superpowers Guide"
  $window.Width = 420
  $window.Height = 640
  $window.Topmost = $true
  $window.WindowStartupLocation = "Manual"
  $window.Left = [System.Windows.SystemParameters]::PrimaryScreenWidth - 460
  $window.Top = 80
  $window.Background = "#F7F4ED"

  $root = New-Object System.Windows.Controls.DockPanel
  $window.Content = $root

  $header = New-Object System.Windows.Controls.Border
  $header.Background = "#1E252B"
  $header.Padding = "12"
  [System.Windows.Controls.DockPanel]::SetDock($header, "Top")
  $root.Children.Add($header) | Out-Null

  $headerStack = New-Object System.Windows.Controls.StackPanel
  $header.Child = $headerStack
  $headerStack.Children.Add((New-TextBlock -Text "Superpowers Widget" -FontSize 17 -Weight "Bold" -Color "#FFFFFF")) | Out-Null
  $headerStack.Children.Add((New-TextBlock -Text "작업 흐름과 Codex 연결 상태를 가볍게 확인합니다." -FontSize 12 -Color "#DCE3EA")) | Out-Null
  $header.Add_MouseLeftButtonDown({ $window.DragMove() })

  $statusPanel = New-Object System.Windows.Controls.Border
  $statusPanel.Background = "#FFFFFF"
  $statusPanel.BorderBrush = "#D2D8DE"
  $statusPanel.BorderThickness = "0,0,0,1"
  $statusPanel.Padding = "12"
  [System.Windows.Controls.DockPanel]::SetDock($statusPanel, "Top")
  $root.Children.Add($statusPanel) | Out-Null

  $statusStack = New-Object System.Windows.Controls.StackPanel
  $statusPanel.Child = $statusStack

  $statusTitle = New-TextBlock -Text "안내 모드" -FontSize 15 -Weight "Bold" -Color "#19745D"
  $statusMessage = New-TextBlock -Text "아직 Codex 세션과 연결하지 않았습니다." -FontSize 12 -Color "#4F5B66"
  $statusDetail = New-TextBlock -Text "" -FontSize 12 -Color "#4F5B66"
  $connectButton = New-Object System.Windows.Controls.Button
  $connectButton.Content = "Codex 세션 연결 요청"
  $connectButton.Height = 32
  $connectButton.Margin = "0,4,0,0"
  $connectButton.Add_Click({
    $request = Write-LinkRequest
    $statusTitle.Text = "연결 요청 생성됨"
    $statusMessage.Text = "현재 Codex 세션에서 'Superpowers 위젯 연결해줘'라고 요청하세요."
    $statusDetail.Text = "linkId: $($request.linkId)"
  })

  $statusStack.Children.Add($statusTitle) | Out-Null
  $statusStack.Children.Add($statusMessage) | Out-Null
  $statusStack.Children.Add($statusDetail) | Out-Null
  $statusStack.Children.Add($connectButton) | Out-Null

  $tabs = New-Object System.Windows.Controls.TabControl
  $tabs.Margin = "10"
  $root.Children.Add($tabs) | Out-Null

  $flowTab = New-Object System.Windows.Controls.TabItem
  $flowTab.Header = "Flow"
  $flowScroll = New-Object System.Windows.Controls.ScrollViewer
  $flowScroll.VerticalScrollBarVisibility = "Auto"
  $flowStack = New-Object System.Windows.Controls.StackPanel
  $flowScroll.Content = $flowStack
  foreach ($flow in $guide.flows) {
    Add-GuideCard -Panel $flowStack -Title $flow.label -Lines @(
      "언제: $($flow.when)",
      "하는 일: $($flow.does)",
      "기대 효과: $($flow.expect)",
      "다음: $($flow.next)",
      "주의: $($flow.warning)"
    )
  }
  $flowTab.Content = $flowScroll
  $tabs.Items.Add($flowTab) | Out-Null

  $situationTab = New-Object System.Windows.Controls.TabItem
  $situationTab.Header = "Situation"
  $situationScroll = New-Object System.Windows.Controls.ScrollViewer
  $situationScroll.VerticalScrollBarVisibility = "Auto"
  $situationStack = New-Object System.Windows.Controls.StackPanel
  $situationScroll.Content = $situationStack
  foreach ($situation in $guide.situations) {
    Add-GuideCard -Panel $situationStack -Title $situation.name -Lines @(
      "먼저 쓸 것: $($situation.startSkill)",
      "이유: $($situation.why)",
      "다음 흐름: $($situation.then)",
      "쉬운 설명: $($situation.plain)"
    )
  }
  $situationTab.Content = $situationScroll
  $tabs.Items.Add($situationTab) | Out-Null

  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromSeconds(2)
  $timer.Add_Tick({
    try {
      $connection = Get-ConnectionStatus
      $statusTitle.Text = $connection.Title
      $statusMessage.Text = $connection.Message

      if ($connection.State) {
        $blocked = ""
        if ($connection.State.blockedActions) {
          $blocked = " / 금지: " + (($connection.State.blockedActions | ForEach-Object { [string]$_ }) -join ", ")
        }
        $statusDetail.Text = "현재: $($connection.State.currentFlow) / 상태: $($connection.State.status) / 다음: $($connection.State.nextSkill)$blocked"
      } elseif ($connection.LinkRequest) {
        $statusDetail.Text = "linkId: $($connection.LinkRequest.linkId)"
      } else {
        $statusDetail.Text = ""
      }
    } catch {
      $statusTitle.Text = "상태 읽기 오류"
      $statusMessage.Text = "상태 파일을 읽을 수 없습니다."
      $statusDetail.Text = $_.Exception.Message
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

Start-Widget
```

- [ ] **Step 3: Run self-test**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -SelfTest
```

Expected:

```text
SelfTest passed
```

- [ ] **Step 4: Commit**

```bash
git add superpowers-widget.ps1
git commit -m "Add Superpowers floating widget"
```

---

### Task 4: Verify Link Request and Active-State Matching

**Files:**
- Modify: `.superpowers-widget/link-request.json` through runtime action or PowerShell helper call
- Create: `.superpowers-widget/state.json`

- [ ] **Step 1: Create a link request without opening the UI**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -CreateLinkRequest
```

Expected: JSON output with `linkId`, `workspacePath`, `requestedAt`, and `instruction`.

- [ ] **Step 2: Create `.superpowers-widget/state.json` from the latest request**

Run:

```powershell
$request = Get-Content -Raw -LiteralPath '.superpowers-widget\link-request.json' | ConvertFrom-Json
$state = [ordered]@{
  linkId = $request.linkId
  sessionId = "manual-test-session"
  sessionLabel = "Manual test Codex session"
  workspacePath = $request.workspacePath
  currentFlow = "writing-plans"
  status = "구현 계획 검토 중"
  nextSkill = "executing-plans"
  recommendedAction = "계획이 맞으면 구현을 시작합니다."
  blockedActions = @("계획 승인 전 구현 범위를 늘리지 않습니다.")
  updatedAt = (Get-Date).ToString("o")
  expiresAt = (Get-Date).AddHours(2).ToString("o")
}
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath '.superpowers-widget\state.json' -Encoding UTF8
```

Expected: no output and `.superpowers-widget/state.json` exists.

- [ ] **Step 3: Verify state JSON parses**

Run:

```powershell
Get-Content -Raw -LiteralPath '.superpowers-widget\state.json' | ConvertFrom-Json | Select-Object linkId,workspacePath,currentFlow,nextSkill
```

Expected: output includes `currentFlow` as `writing-plans` and `nextSkill` as `executing-plans`.

- [ ] **Step 4: Commit example runtime state only if intentionally keeping it**

Do not commit `.superpowers-widget/state.json` or `.superpowers-widget/link-request.json` unless the project explicitly wants sample runtime files. For this first version, leave them untracked or delete them after manual verification:

```powershell
Remove-Item -LiteralPath '.superpowers-widget\state.json' -ErrorAction SilentlyContinue
Remove-Item -LiteralPath '.superpowers-widget\link-request.json' -ErrorAction SilentlyContinue
```

Expected: no commit for runtime state files.

---

### Task 5: Manual UI Verification

**Files:**
- Modify: none expected

- [ ] **Step 1: Start the widget**

Run by double-clicking:

```text
start-superpowers-widget.bat
```

Expected:

- A small window opens.
- It stays above normal windows.
- Header says `Superpowers Widget`.
- Status area starts in guide mode.

- [ ] **Step 2: Verify guide tabs**

In the widget:

- Open `Flow`.
- Confirm Superpowers phases are visible.
- Open `Situation`.
- Confirm common task situations are visible.

Expected: text is readable in Korean and scrolls if needed.

- [ ] **Step 3: Verify link request button**

In the widget:

- Click `Codex 세션 연결 요청`.

Expected:

- Status changes to connection-request text.
- `.superpowers-widget/link-request.json` is created.
- UI shows the generated `linkId`.

- [ ] **Step 4: Simulate Codex writing active state**

Run:

```powershell
$request = Get-Content -Raw -LiteralPath '.superpowers-widget\link-request.json' | ConvertFrom-Json
$state = [ordered]@{
  linkId = $request.linkId
  sessionId = "manual-ui-test"
  sessionLabel = "Manual UI test"
  workspacePath = $request.workspacePath
  currentFlow = "writing-plans"
  status = "UI 연결 테스트 중"
  nextSkill = "executing-plans"
  recommendedAction = "표시가 갱신되는지 확인합니다."
  blockedActions = @("잘못된 세션을 자동 연결하지 않습니다.")
  updatedAt = (Get-Date).ToString("o")
  expiresAt = (Get-Date).AddHours(2).ToString("o")
}
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath '.superpowers-widget\state.json' -Encoding UTF8
```

Expected: within a few seconds, the widget shows `연결됨`, `writing-plans`, and `executing-plans`.

- [ ] **Step 5: Verify stale state behavior**

Run:

```powershell
$state = Get-Content -Raw -LiteralPath '.superpowers-widget\state.json' | ConvertFrom-Json
$state.expiresAt = (Get-Date).AddMinutes(-1).ToString("o")
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath '.superpowers-widget\state.json' -Encoding UTF8
```

Expected: within a few seconds, the widget shows `재연결 필요`.

- [ ] **Step 6: Clean runtime files**

Run:

```powershell
Remove-Item -LiteralPath '.superpowers-widget\state.json' -ErrorAction SilentlyContinue
Remove-Item -LiteralPath '.superpowers-widget\link-request.json' -ErrorAction SilentlyContinue
git status --short
```

Expected: runtime files are not listed. Only planned source files remain tracked or staged.

---

### Task 6: Final Verification and Commit

**Files:**
- Verify: `start-superpowers-widget.bat`
- Verify: `superpowers-widget.ps1`
- Verify: `.superpowers-widget/flow-guide.json`
- Verify: `.superpowers-widget/state.example.json`

- [ ] **Step 1: Run self-test**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -SelfTest
```

Expected:

```text
SelfTest passed
```

- [ ] **Step 2: Verify JSON files parse**

Run:

```powershell
Get-Content -Raw -LiteralPath '.superpowers-widget\flow-guide.json' | ConvertFrom-Json | Out-Null
Get-Content -Raw -LiteralPath '.superpowers-widget\state.example.json' | ConvertFrom-Json | Out-Null
```

Expected: no output and exit code `0`.

- [ ] **Step 3: Verify git status excludes runtime state**

Run:

```powershell
git status --short
```

Expected: no `.superpowers-widget/state.json` or `.superpowers-widget/link-request.json` files listed.

- [ ] **Step 4: Commit any remaining source changes**

If Task 1-3 commits were already made and no source changes remain, skip this step.

If source changes remain:

```bash
git add start-superpowers-widget.bat superpowers-widget.ps1 .superpowers-widget/flow-guide.json .superpowers-widget/state.example.json
git commit -m "Build the Superpowers floating widget"
```

Expected: implementation source is committed.

---

## Self-Review

Spec coverage:

- `.bat` launcher covered by Task 2.
- PowerShell/WPF floating widget covered by Task 3 and Task 5.
- Flow and Situation tabs covered by Task 1 and Task 5.
- Static guide JSON covered by Task 1.
- User-requested linking covered by Task 3 and Task 5.
- `linkId + workspacePath + updatedAt/expiresAt` matching covered by Task 3 and Task 5.
- Stale session warning covered by Task 5.
- No direct Codex control covered by architecture and runtime file bridge.
- No background token usage covered by local-only design.

Placeholder scan:

- No placeholder markers or delayed-implementation notes are intentionally left in the tasks.
- Runtime state files are explicitly not committed.

Type consistency:

- `linkId`, `workspacePath`, `updatedAt`, and `expiresAt` names match across guide, state example, script, and manual verification commands.
- Flow names match the Superpowers workflow names used in the design spec.
