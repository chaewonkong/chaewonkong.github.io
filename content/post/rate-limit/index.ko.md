---
title: "Rate Limiter 알고리즘 정리"
slug: "rate-limit"
date: 2026-09-29T21:32:00+09:00
lastmod: 2026-09-29T21:32:00+09:00
description: "Token Bucket, Leaky Bucket, Fixed Window, Sliding Window Log/Counter까지, 처리율 제한 알고리즘의 동작 방식과 장단점을 정리한다."
tags:
  - rate-limiter
  - system-design
  - algorithm
  - redis
categories:
  - backend
  - distributed-systems
draft: false
---

서버와 데이터베이스 등 리소스는 유한하다. 요청이 몰리거나 급증하면 부하가 리소스를 무너뜨리기 전에 유입량을 제어할 무언가가 필요하다.

그 역할을 하는 것이 Rate Limiter다. 클라이언트나 서비스가 보내는 트래픽의 처리율을 제어하는 장치다.

## 사용 사례
Rate Limiter는 여러가지 목적으로 사용할 수 있다.
- 무료 public API의 일간 요청 수를 제한해 운영 비용 절감
- 사용자의 분당 로그인 가능 횟수를 제한해 인증 대입 공격 방지
- 클라이언트 요청의 횟수를 제한해 악의적인 요청이나 DoS 공격 방어
- 티켓 예매 시스템에서 예매 오픈 당일 트래픽이 급증할 경우 예매 서비스의 실패를 방지하기 위한 처리율 제한

목적은 다양하고, 서버 측 리소스 보호는 그중 하나일 뿐이다. Rate Limiter가 결국 하는 일은 단위시간당 허용하는 요청의 양을 제어하는 것이다.

## 알고리즘
그렇다면 어떤 기준으로 요청량을 세고, 최대치를 제한할 것인가? 일반적으로 사용되는 처리율 제한 알고리즘으로는 아래와 같은 알고리즘들이 존재한다.

- Token Bucket
- Leaky Bucket
- Fixed Window Counter
- Sliding Window Log
- Sliding Window Counter

각 알고리즘 마다 장단점이 있고, 적합한 영역도 다를 수 있다.
IP 단위로 요청량 제한을 하는 시스템을 전제로 각 알고리즘을 살펴 보자.

### Token Bucket
버킷, 즉 바구니가 있고 일정 속도로 바구니에는 토큰이 채워진다. 바구니가 꽉 차면 더 이상 토큰을 채우지 않는다.
요청이 들어오면 버킷에 있는 토큰을 하나 꺼내고 요청을 통과시킨다. 버킷이 비어 있으면 요청은 버려진다.

```text
 refill: r tokens/sec
        │
        ▼
   ┌─────────┐   overflow (bucket full) → token discarded
   │ ● ● ● ● │ ◀─ capacity = b
   │ ● ● ●   │
   │ ● ●     │   tokens = currently remaining
   └────┬────┘
        │ 1 request = 1 token consumed
        ▼
  request ──▶ has token? ──yes──▶ pass
                  │
                  no ──▶ reject (429)

```

#### 특징
- 버킷에 쌓인 만큼 burst 허용 (최대 b개 순간 통과)
- 지속 처리율은 r을 넘지 않음

#### 장점
- 간단한 구현
- 효율적 메모리
- burst of traffic 처리 가능 (버킷에 토큰이 있다면 처리해준다)

#### 단점
- 버킷 크기와 토큰 공급률이라는 두 parameter의 튜닝이 까다롭다.
  - 얼마 만큼의 burst를 허용할 것인가?
  - 단위시간당 얼마만큼의 요청을 허용할 것인가?

### Leaky Bucket
요청 처리율이 고정이다. 요청은 큐에 도착하고, 큐에 빈 자리가 있으면 삽입하고, 없으면 버려진다. 요청 처리율 만큼 매 tick에 큐에서 요청을 꺼내 처리한다. 즉 서버 측에서 시간당 처리할 수 있는 건수를 정해두고 최대 그 건수까지만 처리하는 알고리즘이다.

```text
  requests (irregular, bursty)
     │ │ │  │    │
     ▼ ▼ ▼  ▼    ▼
   ┌───────────────┐
   │ ▒▒▒▒▒▒▒▒▒▒▒▒▒ │ ◀─ new requests rejected when queue is full
   │ ▒▒▒▒▒▒▒▒▒     │    (capacity = queue size)
   │ ▒▒▒▒          │
   └───────┬───────┘
           │  leaks at a constant rate (leak rate = r)
           ▼
       ─ ─ ─ ─ ─ ─   uniform output (burst smoothed out)
```

#### 특징
- 출력은 r을 넘지 않음
- burst 흡수하되 통과시키지 않고 지연시킴

#### 장점
- 메모리 사용량이 큐 크기로 제한됨
- 고정된 처리율이기 때문에 안정적 출력이 중요한 경우 적합

#### 단점
- 단시간에 트래픽 급증시 최신 요청들이 버려지고, 큐에 들어간 요청도 대기하면서 지연이 생긴다
- 버킷(큐)의 크기와 단위시간당 처리율이라는 parameter의 적절한 튜닝이 까다롭다

#### 참고: meter 방식
참고로 Leaky Bucket은 여기서 설명한 queue 방식 외에 meter 방식으로도 구현한다. meter 방식은 요청을 큐에 쌓지 않고, 버킷의 수위(카운터)만 관리한다. 요청이 오면 수위를 1 올리고, 수위는 시간에 따라 일정 속도(r)로 줄어든다. 수위가 capacity를 넘으면 요청을 거절한다. 요청을 지연시키지 않고 즉시 통과/거절을 판단하므로, 사실상 Token Bucket과 같은 동작이 된다. (NGINX의 `limit_req`가 이 방식이며, `burst`/`delay` 옵션으로 queue처럼 지연 처리도 할 수 있다.)

### Fixed Window Counter
타임라인을 고정된 간격의 window로 나누고 각 윈도우마다 counter를 센다.

```text
  limit = 5 / window (e.g. 1 min)

  window 1              window 2              window 3
  ┌─────────────────┬─────────────────┬─────────────────┐
  │ ● ● ● ● ●   ✕ ✕ │ ● ●             │ ● ● ● ●         │
  │ count=5 (full)  │ count=2         │ count=4         │
  └─────────────────┴─────────────────┴─────────────────┘
 00:00             01:00             02:00             03:00
                     ▲
                     └ counter reset to 0 at the boundary

```

윈도우 경계에서 윈도우 크기 기준으로 limit보다 큰 요청이 통과될 수 있다.
```text
Problem: bursts on both sides of a boundary let 2×limit through
  ┌────────────┬────────────┐
  │       ●●●●●│●●●●●       │  ← 10 requests pass between 00:59 and 01:01
  └────────────┴────────────┘
```

#### 특징
- 구현이 가장 단순 (window key + counter 하나, Redis INCR + EXPIRE 로 끝)
- 메모리 O(1), 연산 O(1), 분산 환경에서도 카운터 하나만 공유하면 됨

#### 장점
- 효율적 메모리
- 이해하기 쉽다
- 윈도가 닫히는 시점에 카운터 초기화가 적합한 트래픽 패턴에는 쓰기 좋다: 하루 5개까지 구매 가능한 상품의 구매 개수 초기화 등

#### 단점
- 윈도 경계에 트래픽이 몰리는 경우 시스템의 기대치보다 많은 양의 요청을 처리하게 된다.

### Sliding Window Log
요청의 타임스탬프를 추적한다. 새 요청이 오면 윈도우를 벗어난 만료된 타임스탬프를 제거하고, 새 요청의 타임스탬프를 로그에 추가한다. 로그의 크기가 허용치보다 같거나 작으면 요청을 전달하고 이외에는 거부한다. 이 방식에서는 거부된 요청의 타임스탬프도 로그에 남기는데, 계속 두드리는 클라이언트가 실제로 멈추기 전까지는 다시 통과하지 못하게 하기 위해서다.

```text
  limit = 5 / 60s,  now = 100s

  log at the previous request (t = 99)
  ◀──────────── window (39, 99] ────────────▶
  ┌──────┬──────┬──────┬──────┬──────┬──────┐
  │  40  │  42  │  58  │  71  │  90  │  99  │
  └──┬───┴──────┴──────┴──────┴──────┴──────┘
     │
     └─ ≤ now-60 = 40 → expired, removed

  remove 40, append the new request's timestamp (100)
         ┌──────┬──────┬──────┬──────┬──────┬──────┐
         │  42  │  58  │  71  │  90  │  99  │ 100  │
         └──────┴──────┴──────┴──────┴──────┴──────┘
         ◀─────────── window (40, 100] ────────────▶
                count = 6 > 5 → new request rejected
```

#### 특징
- 정확하다
- 요청마다 timestamp 저장 → 메모리가 윈도우 내 유입 요청 수(거부된 요청 포함)에 비례

#### 장점
- 모든 윈도우에서 통과된 요청 개수가 처리율 한도를 넘지 않는 정교한 제한

#### 단점
- 거부된 요청의 타임스탬프도 보관하므로 메모리를 과다하게 사용

### Sliding Window Counter
Fixed Window Counter를 개선해 카운터 2개만으로 Sliding Window Log를 근사하는 방식이다. `Window=1분`이라고 할 때, 최근 1분간의 요청 수를 다음과 같이 추정한다.

```text
estimate = 현재 window 내 요청 수 (지금 들어온 요청 제외)
         + 직전 window 내 요청 수 × 직전 window가 최근 1분과 겹치는 비율
```

`estimate < limit`이면 들어온 요청을 통과시킨다.

```text
  limit = 5 / 60s,  window size 60s,  now = 01:20 (1/3 into the current window)

   previous (00:00~01:00)    current (01:00~02:00)
  ┌────────────────────────┬────────────────────────┐
  │ prev = 6               │ curr = 2               │
  └────────────────────────┴────────────────────────┘
          ◀─ sliding window (60s) ─▶
          └──── overlap ───┘
        00:20            01:00   01:20

  overlap  = 1 - 1/3 = 2/3

  estimate = curr + prev × overlap
           = 2    + 6    × 2/3   = 6  ≥ 5 → rejected

```

#### 특징
- 카운터 2개만 저장 (메모리 O(1))
- 이전 창 분포가 균일하다고 가정한 근사치

#### 장점
- 직전 window를 가중치로 반영해 Fixed Window Counter의 경계 문제를 완화
- 효율적 메모리

#### 단점
- 정확하지 않은 근사치다: 정상 요청을 거절할 수도, limit을 초과해 요청을 허용할 수도 있다.
  - 다만 실제 오차는 작다. Cloudflare가 4억 건의 요청으로 측정한 결과, 잘못 허용되거나 잘못 제한된 요청은 0.003%였다. ([Counting things, a lot of different things…](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/))
- 경계 부근의 burst는 완화될 뿐 완전히 막히지는 않는다
- 클라이언트 입장에서 불투명하다: 남은 쿼터나 `Retry-After` 헤더에 전달할 값을 정확히 계산하기 어렵다

## 한도 초과 요청의 처리
클라이언트에게 처리율 제한에 걸렸다는 것을 통보할 때는 `429 Too Many Requests` 상태 코드와 함께, 언제 다시 요청할 수 있는지를 `Retry-After` 헤더로 알려준다([RFC 6585](https://www.rfc-editor.org/rfc/rfc6585#section-4)). `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` 같은 헤더도 널리 쓰이지만(GitHub, Twitter 등) 표준이 아닌 관례이며, IETF에서는 이를 표준화한 `RateLimit`, `RateLimit-Policy` 헤더를 [draft-ietf-httpapi-ratelimit-headers](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)로 논의 중이다.