# Superpowers Explain Widget

Windows에서 더블클릭으로 여는 Superpowers 흐름 안내 위젯입니다. 위젯은 로컬 JSON 파일만 읽고 쓰며, Codex나 AI 모델을 직접 호출하지 않습니다.

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

`link-request.json`과 `state.json`은 런타임 파일이므로 커밋하지 않습니다.

`state.json`에서 `currentFlow`는 위젯이 파란색으로 강조할 전체 작업 흐름입니다. `activeSkill`은 중간에 호출한 보조 skill을 설명할 때만 사용합니다. 예를 들어 전체 위젯 개발이 실행 단계라면 `currentFlow`는 `executing-plans`로 유지하고, 부분 문제를 정리하려고 Brainstorming을 호출한 경우에만 `activeSkill`을 `brainstorming`으로 씁니다.

상세 패널의 `지금 할 일`은 활성 flow의 `recommendedAction`을 우선 표시합니다. `이유`도 활성 flow에서는 `recommendedReason`을 우선 표시하므로, Codex가 다음 행동과 그 이유를 함께 실시간으로 갱신할 수 있습니다.

## 검증

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -SelfTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectionStatus
```

정상 상태에서는 `SelfTest passed`가 출력되고, 연결 전에는 `Mode`가 `Guide`로 표시됩니다.
