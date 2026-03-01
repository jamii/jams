```test
{
  let i = [0];
  while get(i, 0) < 10 {
    set(i, 0, get(i, 0) + 1)
  };
  get(i, 0)
}

10
```