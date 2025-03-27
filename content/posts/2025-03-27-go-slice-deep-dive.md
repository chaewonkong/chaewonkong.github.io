+++
date = '2025-03-27T23:56:15+09:00'
draft = true
title = 'Go Slice와 Concurrency'
lastmodified = "2025-03-27T23:56:15+09:00"
author = "Chaewon Kong"
summary = 'Go slice를 서로 다른 goroutine에서 접근하는 경우 어떤 위험이 있을지, 어떻게 하면 안전하게 사용 가능할지 알아본다.'
keywords = ['go', 'slice', 'concurrency']
+++

# Go slice와 concurrency

Go slice를 서로 다른 goroutine에서 접근하는 경우 어떤 위험이 있을지, 어떻게 하면 안전하게 사용 가능할지 알아본다.


| Action             | 동시성 안전 여부          | 설명                                    |
| ------------------ | ------------------ | ------------------------------------- |
| 읽기 (a[i])          | ✅ 안전 (read-only라면) | 여러 goroutine이 동시에 읽기 가능               |
| append()           | ❌ 안전하지 않음          | backing array 변경으로 충돌 가능              |
| 인덱스 쓰기 (a[i] = x)  | ❌ 안전하지 않음          | 한 goroutine의 쓰기가 다른 goroutine의 읽기에 영향 |
| 공유 slice에 대한 동시 쓰기 | ❌ 매우 위험            | race condition                        |

## Append

아래 케이스는 race condition이 발생할 수 있다.
```go
func TestSliceAppend(t *testing.T) {
	shared := []int{}

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		for i := 0; i < 1000; i++ {
			shared = append(shared, i)
		}
		wg.Done()
	}()

	go func() {
		for i := 1000; i < 2000; i++ {
			shared = append(shared, i)
		}
		wg.Done()
	}()
	wg.Wait()
}
```

확인방법:
```plaintext
$  go test -race -v -run ^TestSliceAppend$

# 결과
...
==================
    testing.go:1490: race detected during execution of test
--- FAIL: TestSliceAppend (0.00s)
FAIL
exit status 1
FAIL    pkg.na.nexon.com/open-matchmob/services/matchmaker/logger       0.008s
```

두 개의 goroutine이 동일한 backing array를 공유하며 append를 시도하는데, append는 두 가지 시나리오로 진행된다.

1. cap이 남아 있는 경우
2. cap이 부족한 경우

### cap이 남은 경우
backing array는 그대로 사용된다. 즉 동시에 두 goroutine이 동일한 배열에 값을 write한다.
따라서 race condition이 발생한다.

### cap이 부족한 경우
새 backing array를 만들어 복사하고 반환하며, shared slice 자체에 할당하는데 서로 다른 goroutine이 동시에 이를 할당하려고 할 수 있다. 따라서 race condition이 발생한다.

### 함수의 parameter로 slice를 공유
극단적인 사례를 한번 가정해보자. arr의 cap은 2000이고, 2개의 함수가 goroutine으로 실행되며 각각 1000개의 값을 함수의 인자로 받은 arr에 append한다.

```go
func TestSliceAppendWithFunc(t *testing.T) {
	arr := make([]int, 0, 2000)

	var wg sync.WaitGroup
	wg.Add(2)
	go func(a []int) {

		for i := 0; i < 1000; i++ {
			a = append(a, i)
		}

		wg.Done()

	}(arr)
	go func(a []int) {

		for i := 0; i < 1000; i++ {
			a = append(a, i)
		}

		wg.Done()

	}(arr)
	wg.Wait()
}
```

이 테스트 역시 `go test -race -v -run ^TestSliceAppendWithFunc$` 로 실행하면 race condition을 확인할 수 있다.

cap이 2000이고 각 goroutine이 1000개씩 append하기 때문에 어떠한 경우에도 cap이 부족하지 않다. 따라서 Go runtime은 backing array를 새로 만들지 않고 기존 것을 활용하게 된다.

slice는 value type이더라도 backing array는 공유한다. `go func(a []int) {}` 이 함수가 전달받는 a는 arr의 복사본이지만 `a[i].ptr == arr[i].ptr`로 서로 같다.

즉, 아래 테스트는 통과한다. (동일한 메모리 주소)
```go
func TestSlicePtr(t *testing.T) {
	shared := make([]int, 0, 10)
	shared = append(shared, 0)
	
	done := make(chan struct{})
	
	go func(copied []int) {
		copied = append(copied, 2)
		assert.Equal(t, &shared[0], &copied[0])
		done <- struct{}{}
	}(shared)

	<-done
}
```

shared의 원소와 copied의 원소가 같은 위치라면 같은 메모리 주소를 참조한다.