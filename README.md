# Superpowers Explain Widget

Windows에서 더블클릭으로 여는 Superpowers 흐름 안내 위젯입니다. 위젯은 로컬 JSON 파일만 읽고 쓰며, Codex나 AI 모델을 직접 호출하지 않습니다.

## 설치

Windows에서 PowerShell과 Git이 설치되어 있으면 바로 사용할 수 있습니다.

```powershell
git clone https://github.com/munkm1109-lang/superpowers-explain-widget.git
cd superpowers-explain-widget
.\start-superpowers-widget.bat
```

Git을 쓰지 않는 사용자는 GitHub에서 ZIP으로 내려받아 압축을 푼 뒤 `start-superpowers-widget.bat`을 더블클릭하면 됩니다.

## 실행

`start-superpowers-widget.bat`을 더블클릭합니다.

PowerShell에서 확인하려면:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1
```

## Codex 세션 연결

1. 위젯에서 `Codex 세션 연결 요청`을 누릅니다.
2. `.superpowers-widget/link-request.json`이 생성됩니다.
3. 현재 Codex 세션에 Superpowers 위젯 연결을 요청합니다.
4. Codex가 `.superpowers-widget/state.json`을 쓰면 위젯이 몇 초 안에 연결 상태를 표시합니다.

다른 Codex 세션에 연결을 부탁할 때는 아래처럼 말하면 됩니다.

```text
이 프로젝트 폴더에서 아래 명령을 실행해서 Superpowers 위젯에 연결해줘.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectSession -LinkId widget-여기에-위젯-ID
```

예를 들어 위젯에 `widget-20260614-224924-62a396fc`가 보이면:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectSession -LinkId widget-20260614-224924-62a396fc
```

이 명령은 `link-request.json`과 `state.json`을 같이 만들어서, 위젯이 연결 상태를 바로 인식하게 합니다.

`link-request.json`과 `state.json`은 런타임 파일이므로 커밋하지 않습니다.

`state.json`에서 `currentFlow`는 위젯이 파란색으로 강조할 전체 작업 흐름입니다. `activeSkill`은 중간에 호출한 보조 skill을 설명할 때만 사용합니다. 예를 들어 전체 위젯 개발이 실행 단계라면 `currentFlow`는 `executing-plans`로 유지하고, 부분 문제를 정리하려고 Brainstorming을 호출한 경우에만 `activeSkill`을 `brainstorming`으로 씁니다.

상세 패널의 `지금 할 일`은 활성 flow의 `recommendedAction`을 우선 표시합니다. `이유`도 활성 flow에서는 `recommendedReason`을 우선 표시하므로, Codex가 다음 행동과 그 이유를 함께 실시간으로 갱신할 수 있습니다.

현재 flow의 작업과 확인이 끝났다면, Codex는 먼저 `recommendedAction`에 다음 flow 전환 제안을 적습니다. 예를 들어 코드 리뷰 수정이 끝났으면 `Finishing a Development Branch로 넘어가서 최종 상태를 정리합니다.`처럼 보여줍니다. 사용자가 그 전환을 요청하거나 승인하면 그때 `currentFlow`를 다음 flow로 바꿉니다.

## 검증

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -SelfTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectionStatus
```

정상 상태에서는 `SelfTest passed`가 출력되고, 연결 전에는 `Mode`가 `Guide`로 표시됩니다.
