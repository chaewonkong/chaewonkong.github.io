# chaewonkong's blog

## Theme

[vortisil](https://github.com/khitezza/vortisil/tree/3fbfb836350c6ea00495b9089af80b721237b880)

## Clone 후 submodule 설정

```shell
git submodule update --init --recursive
```

## Blog 작성
```
$ hugo new content posts/20xx-xx-xx-Titile.md
```

### TODO
add
```text
date = '2025-02-09T00:31:28+09:00'
draft = false
title = 'Go의 Reflect 패키지는 얼마나 느릴까'
lastmodified = "2025-02-09T00:31:28+09:00"
author = "Chaewon Kong"
summary = 'Go의 reflect package는 type assertion에 비해 얼마나 느릴까?'
keywords = ['Go', 'reflect', 'type assertion', 'benchmark']
``````