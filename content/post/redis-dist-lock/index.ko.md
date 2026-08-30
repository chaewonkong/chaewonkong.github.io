---
title: "Redis 기반 분산 락과 Redlock 알고리즘"
slug: "redis-dist-lock"
date: 2025-03-13T23:00:25+09:00
lastmod: 2025-03-13T23:00:25+09:00
description: "SET NX 한 줄로 만든 분산 락에서 Redlock까지, 그리고 그것으로도 충분하지 않다는 반론."
tags:
  - distributed-systems
  - go
  - redis
  - redlock
categories:
  - distributed-systems
  - backend
---

분산 락(distributed lock)은 여러 프로세스나 노드가 동시에 접근할 수 있는 공유 자원을, 분산 환경에서 안전하게 다루기 위한 잠금 메커니즘이다.

이 글은 다음 질문들에 대한 답을 찾아가는 과정이다.

- 티켓 예매에서 같은 콘서트 좌석이 동시에 여러 명에게 팔리는 것을 어떻게 막을까?
- 여러 노드에서 실행되는 크론 잡을 정확히 한 번만 돌게 하려면 어떻게 해야 할까?
- 결제 DB와 상품 재고 DB가 분리되어 있을 때 트랜잭션을 어떻게 다뤄야 할까?

## 분산 시스템에서 생기는 문제들

### 경쟁 상태 (Race Condition)

- 여러 노드가 같은 자원에 동시에 접근해 연산하면서 순서가 뒤엉키는 경우
- 두 서버가 DB에서 같은 값을 동시에 읽어 수정하고, 결국 마지막 수정만 남는 경우

### 중복 작업

- 같은 작업이 여러 노드에서 중복으로 실행되는 경우
- 크론 잡이 여러 노드에서 병렬로 도는 경우

### 데이터 일관성 붕괴

- 분산 시스템의 각 노드가 서로 다른 시점의 데이터를 읽으면서 일관성이 깨지는 경우
- 서버 A와 B가 모두 결제를 처리한다고 하자.
    - 상품 재고가 1개 남아 있다
    - 서버 A가 재고 1개를 확인하는 바로 그 순간, 서버 B가 결제를 처리하며 재고를 1 차감한다. 즉 서버 A가 결제를 진행하는 시점에는 실제 재고가 이미 0이다

### 리더 선출 문제

- 여러 노드 중 정확히 1개가 리더로 선출되어야 한다. 여러 노드가 동시에 리더가 되어서는 안 된다.
- 카프카가 브로커 간 조율을 위해 리더 브로커를 선출하는 것이 그 예다

## 락의 목적

### 효율성 (Efficiency)

여러 노드가 같은 일을 반복하면서 생기는 불필요한 비용을 막기 위해 락을 쓸 수 있다.

### 정확성 (Correctness)

동시에 실행되는 프로세스들이 같은 자원에 접근해 수정하려 할 때 발생하는 데이터 손상과 일관성 위반을 막기 위해 락을 쓸 수 있다.

*Designing Data-Intensive Applications*의 저자 Martin Kleppmann에 따르면, 분산 락을 도입할 때 그것이 **효율성** 문제를 풀기 위한 것인지 **정확성** 문제를 풀기 위한 것인지를 분명히 이해하는 것이 중요하다.

예컨대 효율성을 목적으로 분산 락을 도입한다면 Redlock 알고리즘은 맞지 않을 수 있다. 중복 작업을 줄이자고 Redis 마스터 5대를 띄우고 그중 과반에서 락을 얻어내는 비용이, 중복 작업 자체의 비용보다 클 가능성이 높기 때문이다.

## Redis로 분산 락 구현하기

Redis는 싱글 스레드로 동작하는 인메모리 저장소로, 읽기와 쓰기가 빠르다. 단일 스레드에서 명령을 하나씩 순차적으로 처리하기 때문에 락 구현에 자주 쓰인다.

### 예제: 분산 환경의 크론 잡

여러 노드가 이중화되어 있는 환경에서 크론 잡이 실행 주기마다 한 번씩만 돌도록 하는 예제를 구현해 본다.

- 크론 잡은 여러 노드에서 동시에 트리거될 수 있다
- 한 노드에서 먼저 시작했다면, 나머지 노드는 그 작업을 실행하지 않아야 한다

### 크론 작업 정의

10초간 동작하는 작업을 흉내 낸다.

```go
func runCronTask() {
	// 실제로 실행할 크론 작업 (여기서는 10초 sleep으로 흉내 낸다)
	fmt.Println("Working... ⏳")
	time.Sleep(10 * time.Second)
	fmt.Println("Task complete! 🎉")
}
```

### 메인 구조

이미 락이 잡혀 있으면 작업을 실행하지 않고, 락이 없으면 실행한다.

```go
func main() {
	ctx := context.Background()

	// Redis 클라이언트 생성
	client := newRedisClient("localhost:6379", "", 0)

	// 분산 락 획득 시도
	acquired, err := client.acquireLock(ctx, lockKey, lockTTL)
	if err != nil {
		log.Fatalf("Redis connection error: %v", err)
	}

	if !acquired {
		fmt.Println("Cron job already running on another server! 🚫")
		return
	}

	fmt.Println("Starting cron job... ✅")

	// 크론 작업 실행 (예: 데이터 백업)
	runCronTask()

	// 락 해제
	client.releaseLock(ctx, lockKey)
	fmt.Println("Cron job complete, lock released 🔓")
}
```

`newRedisClient`는 `acquireLock`과 `releaseLock` 메서드를 갖는 Redis 클라이언트를 만드는 생성자다. 구현은 아래에서 설명한다.

### 락 구현

```go
import "github.com/redis/go-redis/v9"

// 락 관련 상수
const lockKey = "cron:job:my-task"
const lockTTL = 30 * time.Second // 락 유지 시간

// 분산 락에 사용할 Redis 클라이언트
type redisClient struct {
	client *redis.Client
}

func newRedisClient(addr, password string, db int) *redisClient {
	return &redisClient{
		client: redis.NewClient(&redis.Options{
			Addr:     addr,     // Redis 주소
			Password: password, // 비밀번호 (없으면 빈 문자열)
			DB:       db,       // 기본 DB
		}),
	}
}

// 락을 획득하는 acquireLock 메서드
func (r *redisClient) acquireLock(ctx context.Context, key string, ttl time.Duration) (bool, error) {
	ok, err := r.client.SetNX(ctx, key, "locked", ttl).Result()
	if err != nil {
		return false, err
	}
	return ok, nil
}

// 락을 해제하는 releaseLock 메서드
func (r *redisClient) releaseLock(ctx context.Context, key string) {
	r.client.Del(ctx, key)
}
```

락의 획득과 해제는 go-redis의 `SetNX`로 처리한다.

`SETNX` 명령은 deprecated 되었지만 go-redis는 여전히 이를 지원하며, 내부적으로는 키가 없을 때만 값을 설정하는 `SET` 명령을 사용한다.

락을 설정할 때는 데드락을 막기 위해 TTL을 함께 건다.

### 주의할 점

- **데드락 방지**: TTL(타임아웃)을 설정해 락이 무한정 잡혀 있지 않도록 한다.
- **락 재확인**: 락이 이미 만료되었을 수 있으므로, 작업 도중 락 상태를 다시 확인하는 로직을 넣는다.
- **락 이중 확인**: 분산 환경에서 락의 신뢰성을 높이려면 Redlock 같은 알고리즘을 사용한다.

여기까지는 Redis 인스턴스가 하나라고 가정하고 락을 구현했다. 그런데 이 구현에는 큰 문제가 하나 있다.

**Redis가 SPoF(Single Point of Failure)가 된다.**

그러면 단일 인스턴스 대신 마스터-슬레이브 구성을 쓰면 해결되지 않을까? 답은 그리 간단하지 않다.

## Redlock 알고리즘

### 마스터-슬레이브 구조의 허점

1. 클라이언트 A가 마스터에서 락을 획득한다
2. 마스터가 락 정보를 리플리카에 복제하기 전에 크래시가 나서 내려간다
3. 리플리카가 마스터로 승격된다
4. 클라이언트 B가 새로 승격된 마스터에서 락을 획득한다. 그런데 이 자원은 아직 A가 작업 중이다

### Redlock 알고리즘이란

Redlock 알고리즘은 **여러 Redis 노드**에 걸쳐 락을 획득함으로써, Redis 인스턴스 하나에 장애가 생겨도 전체 시스템의 **일관성**과 **신뢰성**이 유지되도록 한다.

1. **여러 Redis 인스턴스 사용**: Redlock은 여러 Redis 서버에 락을 요청해서 **단일 Redis 노드의 장애**에 영향받지 않게 한다. 최소 **5개의 Redis 노드**가 필요하다.
2. **과반수 정족수 필요**: 락을 획득하려면 **과반**의 Redis 서버에서 획득에 성공해야 한다. 예를 들어 **Redis 서버가 5대**라면 **최소 3대**에서 락을 얻어야 유효한 것으로 본다.
3. **락 유효성 검증**: Redis 서버마다 락 획득에 걸리는 시간이 다를 수 있으므로, 획득 후 **만료 시각을 검증**해서 락이 여전히 유효한지 확인한다.

### Redlock 알고리즘의 동작

클라이언트는 다음 순서로 동작한다.

1. 현재 시각을 밀리초 단위로 기록한다
2. 동일한 키와 랜덤 값으로 N개의 Redis 인스턴스 전부에 순차적으로 락 획득을 시도한다. 각 시도마다 짧은 타임아웃을 두어, 노드가 죽어 있으면 즉시 다음 인스턴스로 넘어가게 한다.
3. 락 획득에 걸린 총 시간을 계산한다. N개 중 과반이 락을 내주었고 그 경과 시간이 락의 유효 시간보다 짧다면, 락 획득에 성공한 것으로 본다.
4. 락을 획득했다면, 실효 유효 시간은 최초 유효 시간에서 경과 시간을 뺀 값이 된다.
5. 락을 획득하지 못했거나 남은 유효 시간이 음수라면(획득 과정에서 이미 만료되었다는 뜻), 모든 인스턴스에서 락을 해제한다.

### 장점

- **높은 가용성**: 여러 Redis 서버를 쓰기 때문에 한 대가 내려가도 락이 유효하다.
- **높은 신뢰성**: 여러 서버에서 락을 획득하도록 요구함으로써 분산 환경에서의 신뢰성을 보장한다.
- **정교한 분산 락**: Redlock은 **분산 시스템에서의 안전한 락**을 제공하며 **상호 배제**를 보장한다.

### 단점

- **복잡성**: 여러 Redis 서버와 통신해야 하므로 구현이 다소 복잡하다.
- **성능 저하**: 각 서버와 통신하는 데 시간이 들어 **성능이 떨어진다**. 락 획득에 실패하면 재시도 로직도 구현해야 하므로, 규모가 큰 분산 환경에서는 성능에 영향을 줄 수 있다.
- **Redis 노드 간 시간 동기화 필요**: 여러 서버에서 락을 획득하고 만료 시각을 계산하는 방식이므로 **각 서버의 시계**가 정확히 동기화되어 있어야 한다.

### 고려사항

- 각 Redis 마스터는 독립된 머신 또는 VM에서, 서로 독립적으로 동작해야 한다.
- 스플릿 브레인을 최소화하려면, 이론적으로 클라이언트는 멀티플렉싱을 사용해 N개 마스터 전부에 SET 명령을 동시에 보내서 최대한 빠르고 동시적으로 과반의 락을 획득해야 한다.
- 과반의 마스터에서 락 획득에 실패한 클라이언트는, 키가 만료되기를 기다리지 말고 이미 획득한 락을 즉시 해제해야 한다.

### 한계

> 아래는 Martin Kleppmann의 블로그에 정리된 Redlock 알고리즘의 한계를 요약한 것이다.
> [https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)

분산 락 자체가 다음과 같은 실패 시나리오를 안고 있다.

![Martin Kleppmann, *How to do distributed locking*](https://martin.kleppmann.com/2016/02/unsafe-lock.png)

Martin Kleppmann, *How to do distributed locking*

- 클라이언트 1이 락 획득에 성공하고 스토리지에 쓰기를 시도하는데, 지연이 발생한다 (GC 정지, 네트워크 지연 등)
- 그사이 락이 만료된다
- 클라이언트 2가 락을 획득하고, 클라이언트 1이 끝나기 전에 스토리지 쓰기를 완료한다
- 뒤이어 클라이언트 1이 스토리지 쓰기를 완료한다 (데이터 손상!)

이를 해결하기 위해 **펜싱 토큰(fencing token)** 을 쓸 수 있다. 펜싱 토큰은 단조 증가하는 숫자 토큰이다. 가장 최근에 성공한 쓰기의 토큰보다 낮은 번호를 들고 온 쓰기 요청은 오래된 토큰으로 간주하여 거부한다.

문제는 Redlock 알고리즘도 Redis도 이런 메커니즘을 내부적으로 제공하지 않는다는 점이다. 그리고 억지로 만든다 해도, 서로 다른 n개의 마스터가 완전히 동기화된 펜싱 토큰을 제공하도록 보장하는 문제에 부딪힌다.

**타이밍 문제**

각 노드가 인식하는 시간은 정확히 동기화되어 있지 않으며, 여러 이유로 몇 분씩 차이가 날 수 있다.

그래서 분산 환경에서 타이밍 문제는 까다로운데, Redlock 알고리즘은 타이밍에 크게 의존하기 때문에 취약할 수 있다.

> However, Redlock is not like this. Its safety depends on a lot of timing assumptions: it assumes that all Redis nodes hold keys for approximately the right length of time before expiring; that the network delay is small compared to the expiry duration; and that process pauses are much shorter than the expiry duration.

이런 이유로 Martin Kleppmann은 Redlock 알고리즘이 단순하지도 않고 정확성이 보장되지도 않으므로, 분산 시스템의 락 메커니즘으로 적합하지 않다고 주장한다.

## Go에서 Redlock 쉽게 쓰기

Redsync 라이브러리를 쓰면 Redlock 알고리즘을 쉽게 적용할 수 있다.

```go
func main() {
	// Redis 커넥션 풀 생성
	redisAddrs := []string{
		"localhost:6379",
		"localhost:16379",
		"localhost:26379",
		"localhost:36379",
		"localhost:46379",
	}
	var pools []redsyncredis.Pool
	for _, addr := range redisAddrs {
		client := redis.NewClient(&redis.Options{
			Addr: addr,
		})
		pools = append(pools, goredis.NewPool(client))
	}

	// 커넥션 풀로 redsync 인스턴스 생성
	rs := redsync.New(pools...)

	mutexname := "my-global-mutex"

	// 주어진 mutexname으로 Mutex 인스턴스 생성
	mutex := rs.NewMutex(mutexname)

	// 다른 프로세스나 스레드가 획득하지 못하도록 락을 잡는다
	if err := mutex.Lock(); err != nil {
		panic(err)
	}

	// 작업 수행
	{
		// do something
		time.Sleep(1 * time.Second)
	}

	// 다른 프로세스나 스레드가 획득할 수 있도록 락을 해제한다
	if ok, err := mutex.Unlock(); !ok || err != nil {
		panic("unlock failed")
	}
}
```

일반적인 락을 쓰듯이, `NewMutex`로 만든 `mutex` 인스턴스의 `Lock`과 `Unlock` 메서드를 호출해 락을 획득하고 해제하면 된다.

### Redsync는 Redlock 알고리즘을 어떻게 구현했을까?

먼저 `Mutex` 구조체를 보자.

```go
type Mutex struct {
	name   string
	expiry time.Duration

	tries     int
	delayFunc DelayFunc

	quorum int

	pools []redis.Pool
	
	// ...
}
```

내부적으로는 다음 시그니처의 `lockContext` 메서드가 호출된다.

```go
func (m *Mutex) lockContext(ctx context.Context, tries int) error
```

주어진 시도 횟수 안에서 락 획득을 시도하고, 실패하면 재시도한다. 재시도 지연은 Redlock 알고리즘의 원칙에 따라 무작위로 정해진다.

```go
func(tries int) time.Duration {
			return time.Duration(rand.Intn(maxRetryDelayMilliSec-minRetryDelayMilliSec)+minRetryDelayMilliSec) * time.Millisecond
		},
```

다시 `lockContext` 메서드로 돌아오면,

```go
		n, err := func() (int, error) {
			// ...
			return m.actOnPoolsAsync(func(pool redis.Pool) (bool, error) {
				return m.acquire(ctx, pool, value)
			})
		}()
```

`m.actOnPoolsAsync`라는 함수를 호출한다. 이 함수는 함수 하나를 받아 풀들을 순회하며 각각에 대해 실행하고, 락 획득에 성공한 마스터의 개수와 에러를 반환한다.

```go
func (m *Mutex) actOnPoolsAsync(actFn func(redis.Pool) (bool, error)) (int, error) {
// ...
	for node, pool := range m.pools {
		go func(node int, pool redis.Pool) {
			r := result{node: node}
			r.statusOK, r.err = actFn(pool)
			ch <- r
		}(node, pool)
	}
// ...

// 락 획득에 성공한 횟수를 세어 n에 담는다
	for range m.pools {
		r := <-ch
		if r.statusOK {
			n++
			// ...
			
		// n 반환
		return n, err
}
```

`lockContext` 함수는 이 결과를 `n, err`로 받는다.

마지막으로 `lockContext` 함수는 정족수 이상에서 락을 획득했는지, 그리고 락 유효 시간이 아직 만료되지 않았는지를 검증한다.

```go
if n >= m.quorum && now.Before(until) {
			m.value = value
			m.until = until
			return nil
		}
```

## 참고 자료

[Distributed Locks with Redis](https://redis.io/docs/latest/develop/use/patterns/distributed-locks/)

[How to do distributed locking — Martin Kleppmann's blog](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)

[Is Redlock safe? - antirez](https://antirez.com/news/101)
