---
title: "About"
slug: "about"
---

넥슨 코리아에서 매치메이킹 서비스를 만드는 백엔드 엔지니어입니다.
Go와 분산 시스템, 그리고 "공정하면서도 빠른 매칭"이라는 잘 풀리지 않는 문제에 관심이 있습니다.

[chaewonkong@gmail.com](mailto:chaewonkong@gmail.com) · [github](https://github.com/chaewonkong) · [linkedin](https://www.linkedin.com/in/chaewonkong)

## 경력

### 넥슨 코리아 — 백엔드 엔지니어

2022년 7월 – 현재

**Matchmaker v2 — 신규 개발** *(18개월, 진행 중)*

- 외부 게임 스튜디오가 엔지니어링 지원 없이 독립적으로 연동할 수 있는 스탠드얼론 매치메이킹 서비스를 처음부터 설계
- 여러 타이틀의 서로 다른 요구사항을 수용하기 위해 재사용 가능한 큐 설정 스키마와 매칭 알고리즘을 설계
- 사내 모놀리식 서비스를 Helm 기반의 배포 가능한 형태로 전환하고 매니지드 티어를 붙여, 외부 판매가 가능한 제품으로 만듦

**Matchmaker — 관측 플랫폼**

- PoC와 TCO 분석을 거쳐 PostgreSQL/Timescale에서 ClickHouse로 마이그레이션, 쿼리 성능 **5–17배** 개선
- 게임팀이 데이터 분석가에게 의존하지 않아도 되도록 셀프서비스 분석 API 구축
- 마이그레이션 결정 전, PostgreSQL 쿼리를 약 10배 최적화

**Backfill 시뮬레이션 — 가속 테스트 엔진**

- 백필 테스트를 위한 가속 로그 리플레이 시뮬레이션을 개발해 검증 시간을 **60분에서 100초로(36배)** 단축
- 진행 중인 매치의 빈 슬롯을 60초 안에 채우는 백필 정책을 빠르게 반복 검증할 수 있게 함
- *퍼스트 디센던트*에 적용: 대기 시간 **12.6% 감소**, 풀 매치 **50.77% 증가**

## 이전 경력

- **프론트엔드 엔지니어**, 뱅크샐러드 *(2020–2022)*
- **공동 창업자**, Oh Good Project *(2020–2022)*

## 기술

`Go` `PostgreSQL` `Redis` `ClickHouse` `Kubernetes` `Docker` `LGTM Stack`
