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
  x^
}

1
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
  let x = 1;
  let y = 2;
  x^
}

1
```

```test
{
  let x = 1;
  let y = 2;
  y^
}

2
```

```test
{
  let x = [1,2,3];
  let y = [4,5];
  x^
}

[1, 2, 3]
```

```test
{
  let x = [1,2,3];
  let y = [4,5];
  y^
}

[4, 5]
```

```test
{
  let x = [1,2,3];
  let y = [4,5];
  x
}

Error at 1:1
This value borrows from `x`, but `x` will be destroyed at the end of this block
```

```test
{
  let x = [1,2,3];
  let y = [4,5];
  y
}

Error at 1:1
This value borrows from `y`, but `y` will be destroyed at the end of this block
```

```test
{
  let x = [1,2,3];
  let y = { x };
  y
}

Error at 1:1
This value borrows from `y`, but `y` will be destroyed at the end of this block
```

```test
{
  let x = [1,2,3];
  let y = { x };
  y^
}

Error at 1:1
This value borrows from `x`, but `x` will be destroyed at the end of this block
```

```test
{
  let x = [1,2,3];
  let y = x!;
}

[]
```

```test
{
  let x = [1,2,3];
  let y = x!;
  let z = x!;
}

Error at 4:11
Can't borrow `x` because it is already borrowed by TODO
```


```test
{
  let x = [1,2,3];
  let y = x!;
  let z = y!;
}

[]
```

```test
{
  let x = [1,2,3];
  let y = x!;
  let z = x;
}

Error at 4:11
Can't share `x` because it is borrowed by TODO
```

```test
{
  let x = [1,2,3];
  let y = x!;
  y^;
  let z = x;
}

[]
```

```test
{
  let x = [1,2,3];
  let y = x!;
  y^;
  let z = y;
}

Error at 5:11
Can't share `y` because it has been moved into TODO
```