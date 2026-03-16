```test
42

42
```

```test
[1,2,3]

[1, 2, 3]
```

```test
{
  let x = 1;
  x
}

1
```

```test
{
  let x = 1;
  x^
}

1
```

```test
{
  let x = 1;
  x&
}

Error at 1:1
This value shares/borrows from `x`, but `x` will be destroyed at the end of this block
```

```test
{
  let x = 1;
  x!
}

Error at 1:1
This value shares/borrows from `x`, but `x` will be destroyed at the end of this block
```

```test
{
  let x = 1;
  x;
}

[]
```

```test
{
  let a = 1;
  a = 2;
  a
}

2
```

```test
{
  let a = 1;
  let b = a!;
  b = 2;
  a
}

Error at 4:3
Can't assign a value of type `number` to a ref of type `ref(number)`
```

```test
{
  let a = 1;
  let b = a!;
  b* = 2;
  a
}

2
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  c* = 2;
  a
}

2
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  b* = 2;
  a
}

Error at 5:3
Can't assign to `b` because it is borrowed by TODO
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  c^;
  b* = 2;
  a
}

2
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  a&
}

Error at 5:4
Can't share `a` because it is borrowed by TODO
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  b&
}

Error at 5:4
Can't share `b` because it is borrowed by TODO
```

```test
{
  let a = 1;
  a^;
  a
}

Error at 4:3
Can't refer to `a` because it has been moved
```

```test
{
  let a = 1;
  a = a^;
  a
}

1
```

```test
{
  let a = 1;
  a = {a^ + 1};
  a
}

2
```

```test
{
  let a = 1;
  let b = a^;
  a = 2;
  [a, b]
}

[2, 1]
```

```test
{
  let a = 1;
  let b = a!;
  b = b*!;
}

Error at 4:3
Can't assign to `b` because it is borrowed by TODO
```

```test
{
  let a = 1;
  let b = a!;
  let c = b^;
  b = c*!;
}

Error at 5:3
This value shares/borrows from `c`, which will be destroyed before `b` and so can't be owned by `b`
```