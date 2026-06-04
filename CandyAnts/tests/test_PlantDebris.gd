# TDD Guard 스텁. PlantDebris는 충돌·게임상태 0 영향의 순수 시각 디브리(잘린 덩쿨 조각이 떨어지며 부서짐)라
# 단위 단언 가치가 낮다. 동작 coverage는 cutter 통합 테스트가 담당한다:
#   - tests/CutterShatterVineTest.tscn (세로 덩쿨 flood-fill 전체 제거 + 디브리 스폰 비충돌 검증)
#   - tests/CutterCutThroughVineTest.tscn (가로 덩쿨 제거 + candy 회수)
#   - tests/CutterEdgeStopTest.tscn (연결 클러스터 경계에서 전파 정지)
extends Node
