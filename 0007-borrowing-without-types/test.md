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

```test
{ 
  let x = 1;
  let y = x + 1;
  x^;
  y^
}

Error at 3:11
Expected a number but found a ref
```

```test
{
  let f = fn (x) { x^ };
  let y = 1;
  f(y)
}

Error at 4:3
Expected a closure but found a ref
```

```test
{
  let f = fn (x) { x };
  let y = 1;
  f(y)
}

Error at 4:3
Expected a closure but found a ref
```

```test
{
  let x = 1;
  x = 2
}

Error at 3:3
Can't assign to a borrowed ref
```

```test
{
  let x = 1;
  x^ = 2
}

Error at 3:3
Expected a ref but found a number
```

```test
{
  let x = 1;
  let y = x!;
  y^ = 2;
  x^
}

2
```

```test
{
  let x = 1;
  x! = x
}

Error at 3:8
Can't share `x` because it is borrowed by TODO
```

```test
{
  let x = 1;
  x! = x^
}

Error at 3:8
Can't move `x` because it is borrowed by TODO
```

```test
{
  let x = 1;
  x! = { x + 1 }
}

Error at 3:10
Can't share `x` because it is borrowed by TODO
```

```test
{
  let x = 1;
  {
    let y = 2;
    x! = y^;
  }
}

[]
```

```test
{
  let x = 1;
  let y = x;
  let z = 2;
  y! = z;
}

Error at 5:3
This value borrows/shares from `z`, which will be destroyed before `y` and so can't be owned by `y`
```

```test
{
  let x = 1;
  let z = 2;
  let y = x;
  y! = z;
}

[]
```

```test
{
  let x = 1;
  let y = x;
  {
    let z = 2;
    y! = z;
  }
}

Error at 6:5
This value borrows/shares from `z`, which will be destroyed before `y` and so can't be owned by `y`
```

```test
{
  let a = 1;
  let b = 2;
  let c = a;
  let d = {c! = b};
  d^
}

Error at 1:1
This value borrows from `a`, but `a` will be destroyed at the end of this block
```