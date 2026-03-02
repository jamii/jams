```test
{
  let i = [0];
  while get(i, 0) < 10 {
    set(i!, 0, get(i, 0) + 1);
  };
  take(i!, 0)
}

Error at 4:20
Can't borrow `i` here because it is already uniquely borrowed by `<anon>` at 4:9'
```

```test
{
  let i = [0];
  while get(i, 0) < 10 {
    let j = get(i, 0) + 1;
    set(i!, 0, copy(j));
  };
  take(i!, 0)
}

10
```

```test
{
  let i = [0];
  i
}

Error at 3:3
The value returned from this block borrows from `i`, but `i` will be destroyed at the end of this block.
```

```test
{
  let i = [0];
  i;
}

null
```

```test
{
  let i = [0];
  let j = [1];
  {
    let k = if null { i! } else { j! };
    set(k!, 0, 2);
  };
  copy([i,j])
}

[[0], [2]]
```

```test
{
  let i = [0];
  let j = [1];
  {
    let f = fn () {
      let k = if null { i! } else { j! };
      set(k!, 0, 2);
    };
    f();
  };
  copy([i,j])
}

[[0], [2]]
```

```test
{
  let i = [0];
  let j = [1];
  fn () {
    let k = if null { i! } else { j! };
    set(k!, 0, 2);
  }
}

Error at 4:3
The value returned from this block borrows from `i`, but `i` will be destroyed at the end of this block.
```

```test
{
  let i = [0];
  let j = [1];
  let f = fn () {
    let k = if null { i! } else { j! };
    let kn = get(k, 0) + 1;
    set(k!, 0, copy(kn))
  };
  let g = copy(f);
  [g(), g()]
}

[1, 2]
```

```test
{
  let i = [0];
  let j = [1];
  copy(fn () {
    let k = if null { i! } else { j! };
    let kn = get(k, 0) + 1;
    set(k!, 0, copy(kn))
  })
}

fn<.{ .id = 0 }>[[0], [1]]
```

```test
{
  let f = fn (x) {
    set(x!, 0, 1);
  };
  let x = [0];
  f(x!);
  copy(x)
}

Error at 3:9
Can't uniquely borrow `x` because it borrows non-uniquely from `<params>`
```

```test
{
  let f = fn (x!) {
    set(x!, 0, 1);
  };
  let x = [0];
  f(x!);
  copy(x)
}

[1]
```

```test
{
  let f = fn (x!) {
    set(x!, 0, 1);
  };
  let x = [0];
  f(x);
  copy(x)
}

Error at 6:5
The callee expected this argument to be uniquely shared, but it was not.
```

```test
{
  let f = fn (x) {
    get(x, 0);
  };
  let x = [0];
  f(x!); // it's ok (but misleading?) to pass a unique arg where it isn't expected
  copy(x)
}

[0]
```

```test
{
  let f = fn (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z, aa, ab, ac, ad, ae, af, ag, ah, ai, aj, ak, al, am, an, ao, ap, aq, ar, as, at, au, av, aw, ax, ay, az, aa, ab, ac, ad, ae, af, ag, ah, ai, aj, ak, al, am) {};
}

Error at 2:245
Functions may take at most 64 arguments
```

```test
{
  f(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z, aa, ab, ac, ad, ae, af, ag, ah, ai, aj, ak, al, am, an, ao, ap, aq, ar, as, at, au, av, aw, ax, ay, az, aa, ab, ac, ad, ae, af, ag, ah, ai, aj, ak, al, am);
}

Error at 2:235
Functions may take at most 64 arguments
```

```test
{
  let a = [[1]];
  set(get(a!, 0), 0, 2);
  copy(a)
}

[[2]]
```

```test
{
  let a = [0];
  let b = a!;
  let c = a;
  copy(c)
}

Error at 4:11
Can't borrow `a` here because it is already uniquely borrowed by `b` at 3:11'
```

```test
{
  let a = [[0]];
  let b = a!;
  let c = get(b, 0);
  set(b!, 0, 1);
  copy(b)
}

Error at 5:7
Can't uniquely borrow `b` here because it is already borrowed by `c` at 4:15'
```

```test
{
  let a = [[0]];
  let b = a!;
  let c = get(b, 0);
  set(a!, 0, 1);
  copy(b)
}

Error at 5:7
Can't uniquely borrow `a` here because it is already borrowed by `b` at 3:11'
```

```test
{
  let a = [[0]];
  let b = a!;
  {
    let c = get(b, 0);
  };
  set(b!, 0, 1);
  copy(b)
}

[1]
```

```test
{
  let a = [1];
  let b = [2];
  let c = [a!, a!];
}

Error at 4:12
This value can't be stored inside a tuple because it uniquely borrows from `a`.
```

```test
{
  let a = [1];
  let b = [2];
  let c = [a!];
  set(c!, 0, copy(b))
}

Error at 4:12
This value can't be stored inside a tuple because it uniquely borrows from `a`.
```

```test
{
  let a = [1];
  let b = [2];
  let c = [a!, b!];
  let d = take(c!, 1);
  set(get(c!, 0), 0, 42);
  set(d!, 0, 101);
  [copy(c), copy(d)]
}

Error at 4:12
This value can't be stored inside a tuple because it uniquely borrows from `a`.
```

```test
{
  let a = [1];
  let b = 2;
  set(a, 0, b);
  copy(a);
}

Error at 4:7
Can't set an elem on this tuple because it borrows non-uniquely from `a`.'
```

```test
set([2], 0, 1)

2
```

```test
get([2], 0)

2
```

```test
take([2], 0)

2
```

```test
{
  let a = 1;
  get([2, a], 0)
}

Error at 3:3
The value returned from this block borrows from `a`, but `a` will be destroyed at the end of this block.
```

```test
{
  let a = 1;
  copy(get([2, a], 0))
}

2
```