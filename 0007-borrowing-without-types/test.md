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
Can't assign a value of type `number` to a path of type `ref(number)`
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
Can't assign a value of type `number` to a path of type `ref(number)`
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

```test
{ 
  let a = 1;
  let b = a&;
  let c = b*!;
}

Error at 4:11
Can't borrow through a shared reference
```

```test
{ 
  let a = 1;
  let b = a&;
  let c = b!;
  c* = a&;
}

[]
```

```test
{ 
  let a = 1;
  let b = a&;
  let c = b!;
  c** = 2;
}

Error at 5:3
Can't assign through a shared reference
```

```test
{
  let a = 1;
  let f = fn () { a };
  f()
}

Error at 3:19
Can't refer to `a` here because it is defined outside this function - try using an explicit capture instead.
```

```test
{
  let a = 1;
  let f = fn [a] () { a };
  f()
}

Error at 3:23
Can't refer to `a` here because it is defined outside this function - try using an explicit capture instead.
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a;
  [b, c, d]
}

[1, 2, 3]
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a^;
  [b, c, d]
}

[1, 2, 3]
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a&;
  [b, c, d]
}

Error at 1:1
This value shares/borrows from `a`, but `a` will be destroyed at the end of this block
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a&;
  [b*, c*, d*]
}

[1, 2, 3]
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a!;
  b* = 3;
  c* = 6;
  d* = 9;
  a
}

[3, 6, 9]
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a!;
  b* = 3;
  c* = 6;
  d* = 9;
  a = [1, 2, 3];
}

Error at 7:3
Can't assign to `a` because it is borrowed by TODO
```

```test
{
  let a = [1, 2, 3];
  {
    let [b, c, d] = a!;
    b* = 3;
    c* = 6;
    d* = 9;
  };
  a = [1, 2, 3];
  a
}

[1, 2, 3]
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a&;
  a = [1, 2, 3];
}

Error at 4:3
Can't assign to `a` because it is shared with TODO
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a;
  a = [1, 2, 3];
}

[]
```

```test
{
  let a = 1;
  let b = a!;
  b
}

Error at 4:3
Can't copy a borrowed reference
```

```test
{
  let a = [1, [2, 3]];
  let [b, c, d] = a;
}

Error at 3:7
Expected a tuple of length 3 but found [1, [2, 3]]
```

```test
{
  let a = [1, [2, 3]];
  let [b, c] = a;
  c
}

[2, 3]
```

```test
{
  let a = [1, [2, 3]];
  let [b, c] = a&;
  c*
}

[2, 3]
```

```test
{
  let a = [1, [2, 3]];
  let [b, [c, d]] = a&;
  [b*, c*, d*]
}

[1, 2, 3]
```

```test
{
  let a = [2, 3];
  let b = [1, a&];
  let [c, [d, e]] = b&;
  [c*, d*, e*]
}

Error at 4:11
Expected a tuple but found a ref
```

```test
{
  let a = [2, 3];
  let b = [1, a&];
  let [c, [d, e]] = b;
  [c, d, e]
}

Error at 4:11
Expected a tuple but found a ref
```

```test
{
  let a = [1, 2, 3];
  let b = a[0]!;
  let e = b*&;
}

[]
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a!;
  let e = b*&;
}

[]
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a!;
  let e = b*&;
  b* = 11;
  a
}

Error at 5:3
Can't assign to `b` because it is shared with TODO
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a!;
  let e = b*&;
  c* = 11;
  a
}

[1, 11, 3]
```

```test
{
  let a = 1;
  {
    let b = a&;
    let c = b!;
    c**&
  };
}

[]
```

```test
{
  let a = 1;
  {
    let b = a!;
    let c = b&;
    c**&
  };
}

Error at 3:3
This value shares/borrows from `b`, but `b` will be destroyed at the end of this block
```

```test
{
  let a = 1;
  {
    let b = a&;
    let c = b!;
    c*&
  };
}

Error at 3:3
This value shares/borrows from `c`, but `c` will be destroyed at the end of this block
```

```test
{
  let a = 1;
  {
    let b = a!;
    let c = b&;
    c*&
  };
}

Error at 3:3
This value shares/borrows from `b`, but `b` will be destroyed at the end of this block
```

```test
{
  let a = 1;
  {
    let b = a!;
    b*!
  };
}

Error at 3:3
This value shares/borrows from `b`, but `b` will be destroyed at the end of this block
```

```test
{
  let a = 1;
  {
    let b = a!;
    let c = b!;
    c**!
  };
}

Error at 3:3
This value shares/borrows from `c`, but `c` will be destroyed at the end of this block
```

```test
{
  let a = ref(42);
  a
}

Error at 3:3
Can't copy an owned reference
```

```test
{
  let a = ref(42);
  a^
}

ref(42)
```

```test
{
  let a = ref(42);
  {
    let b = a*!;
    b* = 12;
  };
  a^
}

ref(12)
```

```test
{
  let a = ref(42);
  {
    let b = a!;
    b* = ref(12);
  };
  a^
}

ref(12)
```

```test
{
  let a = ref(42);
  {
    let b = a!;
    let c = 12;
    b* = c&;
  };
  a^
}

Error at 6:5
This value shares/borrows from `c`, which will be destroyed before `a` and so can't be owned by `a`
```

```test
{
  let z = 12;
  let a = ref(42);
  {
    let b = a!;
    b* = z&;
  };
  a^
}

Error at 1:1
This value shares/borrows from `z`, but `z` will be destroyed at the end of this block
```

```test
{
  let z = 12;
  let a = ref(42);
  {
    let b = a!;
    b* = z&;
  };
  a*
}

12
```

```test
{
  let z = 12;
  let a = ref(z&);
}

Error at 3:11
Can't create an owned ref containing a borrowed/shared ref
```

```test
{
  let z = 12;
  let a = ref(ref(1));
  {
    let b = a*!;
    b* = z&;
  };
  a*
}

Error at 6:10
Can't share `z` because it is borrowed by TODO
```

```test
{
  let a = ref(ref(1));
  a*
}

Error at 3:3
Can't copy an owned reference
```

```test
{
  let a = ref(ref(1));
  a*^
}

ref(1)
```

```test
let a = 1;
let b = a;
b + 1

2
```

```test
let a = ref(1);
a* = { a = ref(2); 3 };
a^

ref(3)
```

```test
let a = 1;
a = [];

Error at 2:1
Can't assign a value of type `[]` to a path of type `number`
```

```test
let nums = [1, 5];
let inc = fn (i) {i + 1};
while {nums[0] < nums[1]} {
  nums[0] = inc(nums[0]);
};
nums

[5, 5]
```