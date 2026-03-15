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
  let b = 2;
  let c = a&;
  let d = { c = b& };
  [c*, d*]
}

[2, 1]
```