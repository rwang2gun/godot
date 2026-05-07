# Worklog

날짜별 작업 기록. 매 세션 종료 시 그 날 한 일/결정/다음 진입점을 1파일로 남긴다.

## 구조
```
worklog/
├── README.md             # 이 문서
└── YYYY-MM/
    └── YYYY-MM-DD.md     # 하루치 기록
```

## 1파일 템플릿
```markdown
# YYYY-MM-DD

## 한 일
- 항목 1
- 항목 2

## 결정 / 변경
- 결정한 내용 + 사유

## 산출물
- 추가/수정된 파일 (의미 있는 것만)

## 다음 진입점
- 내일 어디서부터 시작할지 (커서 위치 + 다음 명령)

## 미해결
- 남긴 의문/숙제/deferred 이슈
```

## 규칙
- **한 세션 = 한 파일**. 같은 날 여러 세션이면 `YYYY-MM-DD-2.md`처럼 suffix
- **다음 진입점은 반드시 명확하게**. 다음 세션이 zero-context로 시작 가능해야 함
- **deferred 이슈 링크**: phase별 `phases/mvp/reviews/phaseNN-deferred.md`로 연결, worklog는 요약만
- **결정 사유 필수**: 단순 사실 나열 금지, "왜 그렇게 했는지" 한 줄 추가
