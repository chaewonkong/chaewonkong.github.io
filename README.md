# chaewonkong.github.io

[blog.engineerd.net](https://blog.engineerd.net) — 매치메이킹과 분산 시스템에 대해 쓰는 블로그.

Hugo로 만들었고, 테마는 외부 의존성 없이 이 저장소가 직접 소유한다.

## 요구사항

Hugo **extended** 0.164.0 이상. 그 외 의존성은 없다 (Go, Node.js, Dart Sass 모두 불필요).
[just](https://github.com/casey/just)는 있으면 편하지만 없어도 된다.

```sh
brew install hugo just
```

## 명령

```sh
just              # 레시피 목록
just new <slug>   # 새 글 (ko/en 두 벌 생성)
just serve        # 개발 서버, 초안 포함 (http://localhost:1313)
just build        # 프로덕션과 동일한 빌드
just chroma       # 코드 하이라이팅 CSS 재생성
just clean        # 빌드 산출물 제거
```

## 글쓰기

```sh
just new redis-cluster-lua
```

`archetypes/post/`를 복사해 페이지 번들을 만든다. `slug`와 `date`는 채워져 나온다.

```
content/post/redis-cluster-lua/
├── index.ko.md
├── index.en.md
└── cover.png          # 언어 공용 리소스 (필요하면)
```

```yaml
---
title: "제목"                          # 직접 채운다
slug: "redis-cluster-lua"              # 자동. 두 언어가 같아야 언어 토글이 이어진다
date: 2026-08-30T18:24:33+09:00        # 자동, 명령 실행 시각
lastmod: 2026-08-30T18:24:33+09:00
description: ""                        # 홈 목록의 요약으로 쓰인다
tags: []
categories: []
draft: true                            # 발행할 때 지운다
---
```

- 본문은 `##`부터 시작한다. `title`은 레이아웃이 h1으로 그린다.
- `draft: true`인 글은 배포되지 않는다. `just serve`는 초안도 보여준다.
- 한 언어만 쓸 거면 나머지 파일은 지워도 되고, `draft`로 남겨둬도 배포되지 않는다.
- 한쪽 언어만 발행하면 반대 언어 목록에는 원문으로 노출되고, 글 상단에 안내 줄이 붙는다.

## 코드 하이라이팅

Catppuccin(Latte/Mocha). 생성물은 커밋되어 있으므로 테마를 바꿀 때만 `just chroma`를 돌린다.

## 배포

`master`에 푸시하면 GitHub Actions가 빌드해 GitHub Pages로 배포한다.
정식 주소는 `blog.engineerd.net`이며 `chaewonkong.github.io`는 그쪽으로 301된다.
커스텀 도메인은 `static/CNAME`이 유지한다.

## 문서

- [spec.md](spec.md) — 테마 스펙. 레이아웃, 타이포, 색, 다국어 구조와 그 결정 근거
- [plan.md](plan.md) — 교체 작업의 단계별 계획
- [design/mockup.html](design/mockup.html) — 확정된 수치의 근거가 된 디자인 시안
