---
title: "Rate Limiter Algorithms"
slug: "rate-limit"
date: 2026-09-29T21:32:00+09:00
lastmod: 2026-09-29T21:32:00+09:00
description: "From Token Bucket and Leaky Bucket to Fixed Window and Sliding Window Log/Counter: how each rate limiting algorithm works, and its trade-offs."
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

Servers and databases are finite. When requests pile up or spike, something has to control the inflow before the load takes those resources down.

That is what a rate limiter does: it is a component that controls the rate of traffic sent by a client or a service.

## Use Cases
Rate limiters serve many purposes:
- Capping daily requests on a free public API to keep operating costs down
- Limiting login attempts per user per minute to prevent brute-force attacks
- Limiting the number of client requests to defend against malicious requests or DoS attacks
- Throttling a ticketing system when traffic surges on the day sales open, so the booking service doesn't fall over

The purposes vary, and protecting server-side resources is only one of them. What a rate limiter does, in the end, is control how many requests are allowed per unit of time.

## Algorithms
So how do we count requests, and how do we cap them? The commonly used rate limiting algorithms are:

- Token Bucket
- Leaky Bucket
- Fixed Window Counter
- Sliding Window Log
- Sliding Window Counter

Each algorithm has its own pros and cons, and each fits different situations.
Let's walk through them, assuming a system that limits requests per IP.

### Token Bucket
There is a bucket, and tokens are added to it at a fixed rate. Once the bucket is full, no more tokens are added.
When a request comes in, it takes one token from the bucket and passes through. If the bucket is empty, the request is dropped.

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

#### Characteristics
- Allows bursts up to what has accumulated in the bucket (at most b requests at once)
- The sustained rate is capped at r

#### Pros
- Simple to implement
- Memory efficient
- Handles bursts of traffic (as long as there are tokens in the bucket)

#### Cons
- Tuning its two parameters, bucket size and refill rate, is tricky.
  - How much burst should we allow?
  - How many requests should we allow per unit of time?

### Leaky Bucket
The processing rate is fixed. Requests arrive at a queue; if there is room, they are enqueued, otherwise they are dropped. On every tick, requests are dequeued and processed at the fixed rate. In other words, the server decides how many requests it can handle per unit of time and processes at most that many.

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

#### Characteristics
- Output never exceeds r
- Absorbs bursts, but delays them instead of letting them through

#### Pros
- Memory is bounded by the queue size
- The fixed processing rate suits cases where a stable output rate matters

#### Cons
- When traffic spikes briefly, the most recent requests get dropped, and the ones that made it into the queue wait, adding latency
- Tuning its parameters, bucket (queue) size and processing rate, is tricky

#### Note: the meter variant
Note that besides the queue-based version described here, Leaky Bucket can also be implemented as a meter. The meter version doesn't queue requests; it only tracks the bucket's water level (a counter). Each request raises the level by 1, and the level drains at a constant rate (r) over time. If the level would exceed capacity, the request is rejected. Since requests are passed or rejected immediately instead of being delayed, it effectively behaves the same as a Token Bucket. (NGINX's `limit_req` works this way, and its `burst`/`delay` options let it delay requests like a queue.)

### Fixed Window Counter
Split the timeline into fixed-size windows and keep a counter for each window.

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

Around window boundaries, more requests than the limit can get through within a span of one window size.
```text
Problem: bursts on both sides of a boundary let 2×limit through
  ┌────────────┬────────────┐
  │       ●●●●●│●●●●●       │  ← 10 requests pass between 00:59 and 01:01
  └────────────┴────────────┘
```

#### Characteristics
- The simplest to implement (one window key + one counter; Redis INCR + EXPIRE and you're done)
- O(1) memory, O(1) operations; in a distributed setup, only a single counter needs to be shared

#### Pros
- Memory efficient
- Easy to understand
- A good fit when resetting the counter at the end of a window matches the traffic pattern, e.g. resetting the purchase count for an item limited to 5 per day

#### Cons
- When traffic concentrates around window boundaries, the system ends up handling more requests than intended.

### Sliding Window Log
Track the timestamp of each request. When a new request arrives, remove the timestamps that have expired out of the window, then append the new request's timestamp to the log. If the log size is less than or equal to the limit, the request is accepted; otherwise it is rejected. In this variant, timestamps of rejected requests stay in the log as well, so a client that keeps hammering the endpoint doesn't get back in until it actually backs off.

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

#### Characteristics
- Accurate
- Stores a timestamp per request → memory grows with the number of incoming requests in the window (including rejected ones)

#### Pros
- Precise limiting: in any window, the number of accepted requests never exceeds the limit

#### Cons
- Uses a lot of memory, since timestamps of rejected requests are kept too

### Sliding Window Counter
A refinement of Fixed Window Counter that approximates Sliding Window Log with just two counters. With `window = 1 min`, estimate the number of requests in the last minute as:

```text
estimate = requests in the current window (excluding the incoming one)
         + requests in the previous window × fraction of the previous window that overlaps the last 1 min
```

The incoming request is accepted if `estimate < limit`.

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

#### Characteristics
- Stores only two counters (O(1) memory)
- An approximation that assumes requests in the previous window were evenly distributed

#### Pros
- Smooths out the boundary problem of Fixed Window Counter by weighting in the previous window
- Memory efficient

#### Cons
- It's an approximation, not exact: it may reject legitimate requests, or allow requests beyond the limit.
  - In practice, though, the error is small. Cloudflare measured it over 400 million requests and found that only 0.003% were wrongly allowed or rate limited. ([Counting things, a lot of different things…](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/))
- Bursts around the boundary are only damped, not fully prevented
- Opaque to clients: the exact remaining quota and the value to send in the `Retry-After` header are hard to compute

## Handling Requests Over the Limit
To tell a client it has been rate limited, respond with the `429 Too Many Requests` status code, and use the `Retry-After` header to say when it can try again ([RFC 6585](https://www.rfc-editor.org/rfc/rfc6585#section-4)). Headers like `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` are also widely used (GitHub and Twitter, among others), but they are a convention rather than a standard; the IETF is standardizing `RateLimit` and `RateLimit-Policy` headers in [draft-ietf-httpapi-ratelimit-headers](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/).
