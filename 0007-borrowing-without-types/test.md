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
This value shares from `x`, but `x` will be destroyed at the end of this block
```

```test
{
  let x = 1;
  x!
}

Error at 1:1
This value borrows from `x`, but `x` will be destroyed at the end of this block
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
Can't assign a value of type `number` to a location of type `ref(number)`
```

```test
{
  let a = 1;
  let b = a!;
  b* = 2;
  a
}

Error at 5:3
Can't copy `a` because it is borrowed by `b`
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  c* = 2;
  a
}

Error at 6:3
Can't copy `a` because it is borrowed by `b`
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
Can't assign to `b` because it is borrowed by `c`
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

Error at 7:3
Can't copy `a` because it is borrowed by `b`
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  a&
}

Error at 5:3
Can't share `a` because it is borrowed by `b`
```

```test
{
  let a = 1;
  let b = a!;
  let c = b*!;
  b&
}

Error at 5:3
Can't share `b` because it is borrowed by `c`
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
Can't assign value to `b` because value borrows from `b`
```

```test
{
  let a = 1;
  let b = a!;
  let c = b^;
  b = c*!;
}

Error at 5:3
This value can't be owned by `b` because it borrows from `c`, which will be destroyed before `b`
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
Can't assign a value of type `number` to a location of type `ref(number)`
```

```test
{
  let a = [3,6,9];
  let b = a[1]!;
  b* = 11;
  a
}

Error at 5:3
Can't copy `a` because it is borrowed by `b`
```

```test
{
  let a = [3,6,9];
  let b = [a[2]!];
  b[0]* = 11;
  a
}

Error at 5:3
Can't copy `a` because it is borrowed by `b[0]`
```

```test
{
  let a = [3,6,9];
  let b = [a[2]!];
  b[0] = a[1]!;
  a
}

Error at 4:10
Can't borrow `a` because it is borrowed by `b[0]`
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

Error at 7:3
Can't copy `b` because it is borrowed by `d`
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
This value shares from `a`, but `a` will be destroyed at the end of this block
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

Error at 7:3
Can't copy `a` because it is borrowed by `d`
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
Can't assign to `a` because it is borrowed by `d`
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
Can't assign to `a` because it is shared by `d`
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

Error at 1:1
This value borrows from `b`, but `b` will be destroyed at the end of this block
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
Can't assign to `b` because it is shared by `e`
```

```test
{
  let a = [1, 2, 3];
  let [b, c, d] = a!;
  let e = b*&;
  c* = 11;
  a
}

Error at 6:3
Can't copy `a` because it is borrowed by `d`
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
This value shares from `b`, but `b` will be destroyed at the end of this block
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
This value shares from `c`, but `c` will be destroyed at the end of this block
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
This value shares from `b`, but `b` will be destroyed at the end of this block
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
This value borrows from `b`, but `b` will be destroyed at the end of this block
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
This value borrows from `c`, but `c` will be destroyed at the end of this block
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
This value can't be owned by `a` because it shares from `c`, which will be destroyed before `a`
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
This value shares from `z`, but `z` will be destroyed at the end of this block
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

Error at 6:5
Can't write a borrowed/shared reference to an owned ref
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
Can't assign a value of type `[]` to a location of type `number`
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

```test
let a = ref([1, 2, 3]);
a*

[1, 2, 3]
```

```test
let get = fn (tuple, index) {
  tuple[index]!
};
let a = [1, 2, 3];
{
  let b = get(a, 1);
  b* = 42;
};
a

Error at 6:11
This value borrows from `tuple`, but `tuple` will be destroyed at the end of this block
```

```test
let get = fn (tuple, index) {
  tuple*[index]!
};
let a = [1, 2, 3];
{
  let b = get(a!, 1);
  b* = 42;
};
a

Error at 6:11
This value borrows from `tuple`, but `tuple` will be destroyed at the end of this block
```

```test
let get = fn (tuple, index) {
  tuple*[index]&
};
let a = [1, 2, 3];
let b = get(a&, 1);
b*

2
```

```test
let a = ref_any(1);
a = ref_any([1, 2, 3]);
a*

[1, 2, 3]
```

```test
let f = fn (x) { x + 1 };
let g = fn (x) { x + 1 + 1 };
let a = ref_any(f);
a = ref_any(g);
a*(3)

5
```

```test
let a = ref_any(1);
a* = [1, 2, 3];
a*

Error at 2:1
Can't assign a value of type `[number, number, number]` to a location of type `number`
```

```test
{
  let a = 1;
  let f = fn [b] () { b };
  f()
}

Error at 3:15
Name `b` is not defined at this point
```

```test
{
  let a = 1;
  let f = fn [a] () { a };
  f()
}

1
```

```test
{
  let a = 1;
  let f = fn [a] () { a };
  f&()
}

Error at 4:3
This function expects to be called by move, but found a reference
```

```test
{
  let a = 1;
  let f = fn [a] () { a };
  f!()
}

Error at 4:3
This function expects to be called by move, but found a reference
```

```test
{
  let a = 1;
  let f = fn [a]! () {
    a* = {a* + 1};
    a*
  };
  f!();
  f!();
  f!()
}

4
```

```test
{
  let a = 1;
  let f = fn [a]! () {
    a* = {a* + 1};
    a*
  };
  f&();
  f&();
  f&()
}

Error at 7:3
This function expects to be called by borrow, but found a shared reference
```

```test
{
  let a = 1;
  let f = fn [a]! () {
    a* = {a* + 1};
    a*
  };
  f^();
  f^();
  f^()
}

Error at 7:3
This function expects to be called by borrow, but found an owned function
```

```test
{
  let a = 1;
  let f = fn [a]! () {
    a* = {a* + 1};
    a*
  };
  f();
  f();
  f()
}

Error at 7:3
This function expects to be called by borrow, but found an owned function
```

```test
{
  let a = 1;
  let f = fn [a]& () {
    a* + 1
  };
  f&()
}

2
```

```test
{
  let a = 1;
  let f = fn [a&] () {
    a*
  };
  f()
}

1
```

```test
{
  let a = 1;
  let f = fn [a&]& () {
    a**
  };
  f&()
}

1
```

```test
{
  let a = 1;
  let f = fn [a&]& () {
    a**
  };
  f;
}

[]
```

```test
{
  let a = 1;
  let f = fn [a!] () {
    a*
  };
  f();
}

[]
```

```test
{
  let a = 1;
  let b = 2;
  let f = fn [a&]! (x) {
    a* = x;
  };
  f!(b&);
}

[]
```

```test
{
  let a = 1;
  let f = fn [a&]! (x) {
    a* = x;
  };
  let b = 2;
  f!(b&);
}

Error at 4:5
This value can't be owned by `f` because it shares from `b`, which will be destroyed before `f`
```

```test
{
  let a = 1;
  let b = 2;
  let f = fn [a&, b&]! () {
    a* = b*;
  };
  a = 3;
}

Error at 7:3
Can't assign to `a` because it is shared by `f[0]`
```

```test
{
  let a = 1;
  let b = 2;
  let f = fn [a&, b&]! () {
    a* = b*;
  };
  f!();
  a = 3;
}

[]
```

```test
[len([]), len([0]), len([0, 0])]

[0, 1, 2]
```

```test
len(0)

Error at 1:5
Expected a tuple but found a number
```

```test
[1,2,3] == [1,2,3]

1
```

```test
[1,[2,3]] == [1,2,3]

0
```

```test
[1,2,3] == [4,5,6]

0
```

```test
[1,2,3] == [1,2,3,4]

0
```

```test
let iter_borrowed = fn (tuple_ref) {
  let index = 0;
  fn [index^, tuple_ref^]! () {
    if index* < len(tuple_ref**) {
      let elem = tuple_ref**[index*]!;
      index* = {index* + 1};
      [elem^]
    } else {
      []
    }
  }
};
let a = [1,2];
let b = [3,4];
let next = iter_borrowed(a!);
let a0 = next!();
let a1 = next!();

Error at 3:3
This value borrows from `tuple_ref`, but `tuple_ref` will be destroyed at the end of this block
```

```test
let iter_borrowed = fn (tuple_ref) {
  let index = 0;
  fn [index^, tuple_ref^]! () {
    if index* < len(tuple_ref**) {
      let elem = tuple_ref^**[index*]!;
      index* = {index* + 1};
      [elem^]
    } else {
      []
    }
  }
};
let a = [1,2];
let b = [3,4];
let next = iter_borrowed(a!);
let a0 = next!();
let a1 = next!();

Error at 17:10
Can't borrow `next` because it is borrowed by `a0[0]`
```

```test
let iter_borrowed = fn (tuple_ref) {
  let index = 0;
  fn [index^, tuple_ref^]! () {
    if index* < len(tuple_ref**) {
      let elem = tuple_ref^**[index*]!;
      index* = {index* + 1};
      [elem^]
    } else {
      []
    }
  }
};
let a = [1,2];
let b = [3,4];
let next = iter_borrowed(a!);
let a0 = next!();

[]
```

```test
let get = fn (tuple, index) {
  tuple*[index]!
};
let a = [1, 2, 3];
{
  let b = get(a!, 1);
  b* = 42;
};
a

Error at 6:11
This value borrows from `tuple`, but `tuple` will be destroyed at the end of this block
```

```test
let get = fn (tuple, index) {
  tuple^*[index]!
};
let a = [1, 2, 3];
{
  let b = get(a!, 1);
  b* = 42;
};
a

[1, 42, 3]
```

```test
let get = fn (tuple, index) {
  tuple^*[index]!
};
let a = [1, 2, 3];
get(a!, 1)* = 42;
a

[1, 42, 3]
```

```test
let a = [1,2];
let [b,c] = a!;
let d = b^*&;

Error at 3:9
Can't share `a` because it is borrowed by `c`
```

```test
let a = [1,2];
let [b,c] = a!;
c^;
let d = b^*&;

[]
```

```test
let a = 1;
let b = a!;
let c = b*!;
b

Error at 4:1
Can't copy `b` because it is borrowed by `c`
```

```test
let a = 1;
let b = a!;
let c = b*&;
b

Error at 4:1
Can't copy borrowed references from `b` because it is shared by `c`
```

```test
let a = 1;
let b = a!;
a^

Error at 3:1
Can't move out of `a` because it is borrowed by `b`
```

```test
let a = 1;
let b = a&;
a^

Error at 3:1
Can't move out of `a` because it is shared by `b`
```

```test
let a = 1;
let b = a!;
a!

Error at 3:1
Can't borrow `a` because it is borrowed by `b`
```

```test
let a = 1;
let b = a&;
a!

Error at 3:1
Can't borrow `a` because it is shared by `b`
```

```test
let a = 1;
let b = a!;
a&

Error at 3:1
Can't share `a` because it is borrowed by `b`
```

```test
let a = 1;
let b = a&;
a&

Error at 1:1
This value shares from `a`, but `a` will be destroyed at the end of this block
```

```test
let a = 1;
let b = a!;
a = 2

Error at 3:1
Can't assign to `a` because it is borrowed by `b`
```

```test
let a = 1;
let b = a&;
a = 2

Error at 3:1
Can't assign to `a` because it is shared by `b`
```

```test
let a = 1;
let b = a!;
a = b^

Error at 3:1
Can't assign value to `a` because value borrows from `a`
```

```test
let inner = [3, [1, 2]];
let x = inner[1]!;
x* = [5, 6];
[x*, inner]

Error at 4:6
Can't copy `inner` because it is borrowed by `x`
```

```test
let inner = ref([1, [2, [3]]]);
let x = inner^;
let y = x*^

[]
```

```test
let a = 1;
let b = 2;
let c = [a!, b!];
c

Error at 1:1
This value borrows from `c`, but `c` will be destroyed at the end of this block
```

```test
let f = fn (a) { a };
f(1, 2)

Error at 2:1
Expected 1 arguments but found 2 arguments
```

```test
let f = fn (a) { a };
let g = fn (a) { a };
f == g

0
```

```test
let f = fn (a) { a };
let g = fn (a) { a };
f == f

1
```

```test
let f = fn (a) { fn [a] () { a } };
f(0) == f(0)

1
```

```test
let f = fn (a) { fn [a] () { a } };
f(0) == f(1)

0
```