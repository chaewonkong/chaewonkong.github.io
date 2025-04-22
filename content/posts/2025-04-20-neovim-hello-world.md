+++
date = '2025-04-20T10:09:44+09:00'
draft = false
title = '2025 04 20 Neovim Hello World'
lastmodified = "2025-04-20T10:09:44+09:00"
author = "Chaewon Kong"
summary = 'LunarVim으로 NeoVim 찍먹 해보기'
keywords = ['neovim', 'lunarvim']
+++

# neovim 찍먹 해보기

Vim으로 현업 개발을 하는 분들도 계시지만, 나한테는 조금 불친절하다고 느꼈다.
하나하나 커스터마이징 하는 장점이 있지만, 커스터마이징에 너무 많은 노력을 써야 한다는 것은 단점으로 여겨졌다.

neovim은 vim을 보다 쉽게 쓸 수 있게 한다.
lua로 설정하고, LSP가 built-in이고 등등 장점이 많다.

하지만 neovim조차 IDE를 대체하려고 하면 설정할게 많다.

그래서 LunarVim으로 찍먹해보려 한다.


## 설치
- neovim이 설치되어 있어야 한다.

[LunarVim 설치문서](https://www.lunarvim.org/docs/installation) 참고

참고로 제대로 사용하려면 NerdFont가 설치되어 있어야 한다. 아이콘 등을 NerdFont를 사용한다고 알고 있다.

### iterm에서 혹시 nerd font가 제대로 아이콘을 그려주지 못한다면
나는 iterm을 사용하고 있는데, iterm 설정에서 폰트를 설치한 nerd font로 바꾸니 해결되었다.

## 단축키
| key | 의미 |
| ---- | --- |
| <space> + e | nvimtree (왼쪽 사이드탭을 열어 file explorer를 생성) |
| <space> + f | 검색 (파일, 텍스트 등) |
| <ctrl> + h | 왼쪽 윈도우로 이동 |
| <ctrl> + l | 오른쪽 윈도우로 이동 |
| <ctrl> + k | 위쪽 윈도우로 이동 |
| <ctrl> + j | 아래쪽 윈도우로 이동 |

## 참고
나는 vscode를 쓰다가 NeoVim/LunarVim으로 차근히 옮기는 중인데, git 형상관리 툴을 찾다 보니 Go로 된 cli 툴을 찾았다.

### LazyGit
[lazygit](https://github.com/jesseduffield/lazygit/raw/assets/demo/amend_old_commit-compressed.gif)

아직은 command key binding이 익숙하진 않지만, 금방 익숙해질 거라 생각한다.

LunarVim과 함께 쓰면 편리할 것 같다.

### 업데이트
어쩌다 보니 LunarVim을 버리고 [LazyVim](https://www.lazyvim.org/)으로 왔다. 이유는 크게 없고, "간지"가 컸다.

쓰고 있는데 너무 멋있다(ㅋㅋ)

일단 써 보면서 더 업데이트 할 수 있을 것 같다.
