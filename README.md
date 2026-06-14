# Superpowers Explain Widget

Superpowers 흐름을 옆에 띄워두고 보는 로컬 위젯입니다. Windows 전용 위젯과 크로스플랫폼 웹 위젯을 함께 제공합니다. 위젯은 로컬 JSON 파일만 읽고 쓰며, Codex나 AI 모델을 직접 호출하지 않습니다.

## 반드시 먼저 설치해야 하는 것

이 위젯은 **Codex Superpowers 플러그인이 설치되어 있고, Codex에서 Superpowers skill을 사용할 수 있는 상태**를 전제로 합니다.

Superpowers 플러그인이 없으면 위젯 창은 열릴 수 있지만, Codex가 현재 flow를 이해하거나 `Brainstorming`, `Executing Plans`, `Requesting Code Review` 같은 Superpowers 흐름에 맞춰 위젯을 제대로 업데이트할 수 없습니다.

따라서 처음 설치하는 사람은 아래 위젯 설치를 하기 전에 먼저 Codex에서 Superpowers 플러그인을 설치하고 활성화해 주세요.

## 설치

Windows 전용 위젯은 PowerShell만 있으면 실행할 수 있습니다. 웹 위젯은 Node.js 20 이상이 추가로 필요합니다.

```powershell
git clone https://github.com/munkm1109-lang/superpowers-explain-widget.git
cd superpowers-explain-widget
.\start-superpowers-widget.bat
```

Git을 쓰지 않는 사용자는 GitHub에서 ZIP으로 내려받아 압축을 푼 뒤 실행 파일을 더블클릭하면 됩니다.

## 웹 버전 다운로드

Git을 모르는 사용자는 ZIP 파일로 받으면 됩니다.

1. 먼저 [Node.js 20 이상](https://nodejs.org/)을 설치합니다.
2. 웹 위젯 브랜치 ZIP을 다운로드합니다: [codex/web-widget ZIP](https://github.com/munkm1109-lang/superpowers-explain-widget/archive/refs/heads/codex/web-widget.zip)
3. ZIP 압축을 풉니다.
4. Windows에서는 `start-superpowers-web-widget.bat`을 더블클릭합니다.
5. macOS 또는 Linux에서는 압축을 푼 폴더에서 아래 명령을 실행합니다.

```sh
./start-superpowers-web-widget.sh
```

실행 후 브라우저에서 `http://127.0.0.1:43821`을 열면 웹 위젯이 보입니다. 여기서 `127.0.0.1`은 실행한 사람 자신의 컴퓨터를 뜻합니다. 다른 사람이 자기 컴퓨터에서 실행하면 그 사람의 `127.0.0.1:43821`로 열립니다.

## 실행 방식 선택

- Windows 전용 위젯: `start-superpowers-widget.bat`
- 크로스플랫폼 웹 위젯: `start-superpowers-web-widget.bat` 또는 `./start-superpowers-web-widget.sh`

웹 위젯은 Node.js 20 이상이 필요합니다. 실행 후 브라우저에서 `http://127.0.0.1:43821`을 엽니다. 이 주소는 네트워크에 공개되는 주소가 아니라 각자 자기 컴퓨터 안에서만 열리는 로컬 주소입니다.

PowerShell에서 확인하려면:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1
```

## Codex 세션 연결

1. 위젯에서 `Codex 세션 연결 요청`을 누릅니다.
2. widget ID별 연결 요청 파일이 생성됩니다.
3. 위젯에 표시되는 `Superpowers 위젯에 연결해줘: widget-...` 문장을 통째로 복사합니다.
4. Codex가 같은 widget ID의 상태 파일을 쓰면 위젯이 몇 초 안에 연결 상태를 표시합니다.

위젯이 켜져 있고 연결 요청을 눌렀다면, 다른 Codex 세션에는 위젯에 표시된 문장을 그대로 붙여넣으면 됩니다.

```text
Superpowers 위젯에 연결해줘: widget-여기에-위젯-ID
```

실제 위젯 복사 문장에는 `%LOCALAPPDATA%\SuperpowersExplainWidget\links\widget-여기에-위젯-ID.json` 경로도 함께 들어갑니다. 다른 Codex 세션이 `.superpowers`, `%TEMP%`, Codex 캐시만 찾는 경우가 있어서, 복사 문장 안에 정답 위치를 직접 넣어둔 것입니다.

위젯은 연결 요청을 만들 때 Windows의 공통 보관함인 `%LOCALAPPDATA%\SuperpowersExplainWidget\links`에도 자기 위치를 등록합니다. 그래서 같은 Windows 사용자 계정 안의 다른 Codex 세션은 이 파일을 보고 어느 위젯의 상태 파일에 연결해야 하는지 찾을 수 있습니다.

만약 다른 세션이 코드만으로 찾지 못하면 아래처럼 말하면 됩니다.

```text
이 프로젝트 폴더에서 아래 명령을 실행해서 Superpowers 위젯에 연결해줘.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectSession -LinkId widget-여기에-위젯-ID
```

예를 들어 위젯에 `widget-20260614-224924-62a396fc`가 보이면:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectSession -LinkId widget-20260614-224924-62a396fc
```

이 명령은 widget ID별 연결 요청과 상태 파일을 같이 만들어서, 위젯이 연결 상태를 바로 인식하게 합니다.

코드만으로 자동 연결되는 범위는 같은 컴퓨터, 같은 Windows 사용자 계정 안입니다. 다른 사람의 컴퓨터에 켜진 위젯은 내 컴퓨터의 Codex가 코드만으로 연결할 수 없습니다.

새 연결 요청은 widget ID별 runtime 파일을 사용합니다.

```text
.superpowers-widget/runtime/links/<widget-id>.json
.superpowers-widget/runtime/states/<widget-id>.json
```

Windows 위젯과 웹 위젯을 동시에 켜도 각자 자기 widget ID 파일만 사용하므로 서로 덮어쓰지 않습니다.

호환을 위해 `.superpowers-widget/link-request.json`과 `.superpowers-widget/state.json`도 같이 만들어질 수 있지만, 이제 이 파일들은 예전 방식과의 호환용 거울입니다. runtime 파일과 legacy 거울 파일은 모두 실행 중 생기는 파일이므로 커밋하지 않습니다.

`state.json`에서 `currentFlow`는 위젯이 파란색으로 강조할 전체 작업 흐름입니다. `activeSkill`은 중간에 호출한 보조 skill을 설명할 때만 사용합니다. 예를 들어 전체 위젯 개발이 실행 단계라면 `currentFlow`는 `executing-plans`로 유지하고, 부분 문제를 정리하려고 Brainstorming을 호출한 경우에만 `activeSkill`을 `brainstorming`으로 씁니다.

상세 패널의 `지금 할 일`은 활성 flow의 `recommendedAction`을 우선 표시합니다. `이유`도 활성 flow에서는 `recommendedReason`을 우선 표시하므로, Codex가 다음 행동과 그 이유를 함께 실시간으로 갱신할 수 있습니다.

현재 flow의 작업과 확인이 끝났다면, Codex는 먼저 `recommendedAction`에 다음 flow 전환 제안을 적습니다. 예를 들어 코드 리뷰 수정이 끝났으면 `Finishing a Development Branch로 넘어가서 최종 상태를 정리합니다.`처럼 보여줍니다. 사용자가 그 전환을 요청하거나 승인하면 그때 `currentFlow`를 다음 flow로 바꿉니다.

## 검증

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -SelfTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectionStatus
```

정상 상태에서는 `SelfTest passed`가 출력되고, 연결 전에는 `Mode`가 `Guide`로 표시됩니다.
