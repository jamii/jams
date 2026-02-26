```test
{
  let a = 1;
  fn () {
    let a = 1
  };
  a
}

Error at 4:5
Name `a` is already defined at 2:3
```