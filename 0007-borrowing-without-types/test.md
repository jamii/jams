```test
{
  let i = [0];
  while get(i, 0) < 10 {
    set(i!, 0, get(i, 0) + 1);
  };
  take(i!, 0)
}

Error at 4:20
Can't borrow i here because it is already uniquely borrowed by <anon> at 4:9'
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
The value returned from this block borrows from i, but i will be destroyed at the end of this block.
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
The value returned from this block borrows from i, but i will be destroyed at the end of this block.
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

// TODO Don't allow this shadowing.

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
Can't uniquely borrow x because it borrows non-uniquely from <params>'
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

// TODO Should fail dynamic check.
```test
{
  let f = fn (x!) {
    set(x!, 0, 1);
  };
  let x = [0];
  f(x);
  copy(x)
}

[1]
```