---
layout: post
title: "[TIL] DB의 트랜잭션(Transaction)과 락(Lock)"
date: "2022-04-24"
categories:
  - TIL
excerpt: |
  트랜잭션이 데이터의 정합성을 보장하기 위한 기능이라면 락은 동시성을 제어하기 위한 기능이다.
feature_text: |
  ## 트랜잭션과 락의 특징과 차이점
  트랜잭션이 데이터의 정합성을 보장하기 위한 기능이라면 락은 동시성을 제어하기 위한 기능이다.
feature_image: "https://images.unsplash.com/photo-1544383835-bda2bc66a55d?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=3472&q=80"
image: "https://images.unsplash.com/photo-1544383835-bda2bc66a55d?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=3472&q=80"
---

## Transaction과 Lock

### 트랜잭션 (Transaction)

트랜잭션(Transaction)은 작업의 완전성을 보장한다.

예를들어 쇼핑몰에서 사용자가 상품을 구매했다고 하자.
처리해야할 작업은 다음과 같다고 가정하겠다.

1. 주문 정보를 주문 테이블에 생성
2. 받는사람 정보(주소, 연락처 등)를 받는사람 테이블에 생성

만약 1번은 DB에 저장이 성공하였는데, 2번은 실패하였다면 어떻게 될까?
트랜잭션을 이용하지 않았다면, 받는사람을 알 수 없어 상품을 발송하지 못할 것이다.

트랜잭션을 이용하였다면 1, 2번이 모두 성공하면 commit되어 DB에 반영되나,
하나라도 실패하게 되면 rollback이 되어 원상태가 변화하지 않는다.

이처럼 트랜잭션은 *논리적인 작업셋을 모두 완벽하게 처리하거나, 처리하지 못한다면 원상태로 복구해 유지하는 기능*이다.
즉, partial update가 발생하지 않게 돕는다.

한편, 트랜잭션은 범위를 최소화해 적용해야 한다.
동일한 논리적 작업 단위로 묶일 필요가 없는 작업은 트랜잭션에서 분리해야 한다.

트랜잭션의 범위가 늘어나면 해당 작업이 커넥션을 소유하는 시간이 늘어나는데, 사용 가능한 여유 커넥션의 개수는 유한하기 때문에, 불필요하게 트랜잭션의 범위가 넓어져 커넥션이 차지하는 길이가 길어지면, 작업들이 커넥션을 가지기 위해 기다려야 하는 시간이 길어질 수 있다.

### 락(Lock)

락은 동시성을 제어하는 기능이다.

하나의 리뷰 레코드를 여러 커넥션에서 동시에 변경하려고 한다면, 해당 레코드의 값은 예측가능하지 않아진다.
락이 없다면 각 커넥션이 동시에 동일한 데이터를 서로 다르게 변경하게 될 수 있다.

락은 여러 커넥션이 동일한 자원을 요청할 경우, 한 시점에 하나의 커넥션만 그 자원을 변경할 수 있게 해준다.