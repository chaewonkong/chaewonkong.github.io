+++
date = '2025-02-09T00:31:28+09:00'
draft = false
title = 'Go의 Reflect 패키지는 얼마나 느릴까'
lastmodified = "2025-02-09T00:31:28+09:00"
author = "Chaewon Kong"
summary = 'Go의 reflect package는 type assertion에 비해 얼마나 느릴까?'
keywords = ['Go', 'reflect', 'type assertion', 'benchmark']
+++

Go에서 런타임의 값의 타입을 모르는 경우, type을 읽어오기 위해 reflect 패키지를 사용하기도 한다.

하지만, 대부분의 Gopher들은 reflect 패키지는 느리므로 사용시 주의가 필요하다는 얘기를 신조처럼 받아들이고 있다.

그렇다면 reflect는 실제로 얼마나 느릴까?

궁금해서 간단한 벤치마크를 돌려봤다.

```go
package reflectpkg_test

import (
	"reflect"
	"testing"
)

// Type switch approach
func checkTypeSwitch(value interface{}) string {
	switch value.(type) {
	case string:
		return "string"
	case int:
		return "int"
	case bool:
		return "bool"
	default:
		return "unknown"
	}
}

// reflect approach
func checkTypeReflect(value interface{}) string {
	t := reflect.TypeOf(value)
	if t.Kind() == reflect.String {
		return "string"
	} else if t.Kind() == reflect.Int {
		return "int"
	} else if t.Kind() == reflect.Bool {
		return "bool"
	}
	return "unknown"
}

// Benchmark test
func BenchmarkTypeSwitch(b *testing.B) {
	for i := 0; i < b.N; i++ {
		checkTypeSwitch("hello")
		checkTypeSwitch(42)
		checkTypeSwitch(true)
	}
}

func BenchmarkReflect(b *testing.B) {
	for i := 0; i < b.N; i++ {
		checkTypeReflect("hello")
		checkTypeReflect(42)
		checkTypeReflect(true)
	}
}
```

string 타입의 value를 받아서 type이 무엇인지 반환하는 함수를 두개 만들었다.

`checkTypeSwitch` 는 switch문을 이용해 type assertion을 하고 맞는 type을 string으로 반환한다.

`checkTypeReflect` 는 reflect 패키지를 이용해 type을 가져오고 해당 type을 string으로 반환한다.

벤치 결과는 어떻게 될까?

## Type Assertion

```go
BenchmarkTypeSwitch
BenchmarkTypeSwitch-8           1000000000               0.2914 ns/op          0 B/op          0 allocs/op
```

## reflect

```go
BenchmarkReflect
BenchmarkReflect-8      135978163                8.586 ns/op           0 B/op          0 allocs/op
```

## 결론

Type Assertion의 경우 한 번 실행하는 데 0.3 나노초가 걸린 데 반해 reflect는 8.6 나노초가 걸렸다. reflect 패키지를 사용한 경우가 28.6배 더 시간이 걸린 걸 알 수 있다.

확실히 성능 상 차이가 크게 남을 알 수 있었다.