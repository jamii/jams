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

Error at 5:3
Can't share `a` because it is borrowed by TODO
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  b&
}

Error at 5:3
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

```test
{
  let a = [3,6,9];
  a[1]
}

6
```

```test
{
  let a = [3,6,9];
  a[1] = 11;
  a
}

[3, 11, 9]
```

```test
{
  let a = [3,6,9];
  let b = a[1]!;
  b = 11;
  a
}

Error at 4:3
Can't assign a value of type `number` to a ref of type `ref(number)`
```

```test
{
  let a = [3,6,9];
  let b = a[1]!;
  b* = 11;
  a
}

[3, 11, 9]
```

```test
{
  let a = [3,6,9];
  let b = [a[2]!];
  b[0]* = 11;
  a
}

[3, 6, 11]
```

```test
{
  let a = [3,6,9];
  let b = [a[2]!];
  b[0] = a[1]!;
  a
}

Error at 4:10
Can't borrow `a` because it is already borrowed by TODO
```

```test
{
  let a = [3,6,9];
  let b = [a[0]&, a[1]&, a[2]&];
  let c = b[1]^;
  c^;
  a
}

[3, 6, 9]
```

```test
{
  let a = [3,6,9];
  let b = [2,4,8];
  let c = [a[0]&, b[1]!, a[2]&];
  let d = c[1]^;
  d* = 11;
  b
}

[2, 11, 8]
```