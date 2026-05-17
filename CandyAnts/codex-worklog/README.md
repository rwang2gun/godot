# codex-worklog

Codex가 수행한 **아키텍처 외부 작업**(맵 에디터, 스프라이트/에셋 폴리싱 등 tooling·asset 파이프라인)의 트레일.

`worklog/`(=사용자 세션 일지) 및 `phases/mvp/`(=gameplay phase) 와 직교한다.

## 구조

```
codex-worklog/
├── README.md                # 이 문서
└── <track>/                 # long-running 트랙당 하나
    ├── STATUS.md            # 현재 상태·다음 작업·블로커 SoT
    └── YYYY-MM-DD-<topic>.md  # 세션 로그
```

현재 트랙:
- `map-editor/` — 인게임 맵 에디터 툴
- `sprite-polish/` — 스테이지/엔티티 아트 폴리싱(배경·타일·spawn 등)

새 트랙은 "여러 번 돌아올 것 같은 작업"일 때만 만든다. 일회성 작업은 `worklog/` 일자 파일에 한 줄로 기록.

## 파일명 컨벤션

- 세션 로그: `YYYY-MM-DD-<short-topic>.md` (예: `2026-05-16-stage-art-polishing.md`)
- 같은 날 여러 세션: `-2`, `-3` suffix (예: `2026-05-16-stage-art-polishing-2.md`)
- 날짜 prefix로 `ls`가 시간순 정렬되도록 함 (`worklog/` 컨벤션과 동일)

## 세션 로그 1파일 템플릿

```markdown
---
name: <track>-<topic>
date: YYYY-MM-DD
track: <track>
status: implemented | wip | reverted
---

# <제목>

## 핸드오프
- codex에게 보낸 프롬프트 요지
- 입력 컨텍스트 (관련 파일/스펙 링크)

## 산출물
- codex가 돌려준 변경 (파일/에셋/diff 요약)

## 결정
- 채택/거부/수정 + 사유

## 통합 노트
- 프로젝트에 반영된 위치, 회귀 영향
- 검증 결과 (headless 로딩, 테스트, 캡처 등)

## 남은 과제
- 다음 세션 진입점, deferred 이슈
```

## 트리거 (= 언제 로그를 남기는가)

**codex가 산출물을 돌려준 직후 + 그 산출물을 커밋·반영하기 전.**

사용자가 매번 "로그 남겨줘"라고 요청해야 하는 흐름은 빠지기 쉬우므로, 이 컨벤션을 Claude 측이 알아서 트리거한다. 사용자는 결과만 확인.

권장 루틴:
1. 작업 시작 전 해당 track의 `STATUS.md`를 읽는다.
2. 작업이 끝나면 `STATUS.md`의 현재 상태·다음 작업·블로커를 갱신한다.
3. 같은 track 아래에 `YYYY-MM-DD-<topic>.md` 세션 로그를 추가한다.
4. gameplay phase 산출물이 아닌 경우 `phases/mvp/`에 중복 기록하지 않는다.

## SoT 관계

- 1차 SoT: `codex-worklog/<track>/STATUS.md` + git history
- 산출물(코드/에셋)은 Godot 컨벤션대로 `addons/`·`assets/`·`scripts/` 등 정상 위치에 살고, **여기엔 결정·트레일만 보관**
- gameplay phase와 무관하므로 `phases/mvp/`에는 두지 않음
