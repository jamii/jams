```test
{
  let i = [0];
  while get(i, 0) < 10 {
    set(i!, 0, get(i, 0) + 1)
  };
  take(i, 0)
}

Error at 4:20
Can't borrow i here because it is already uniquely borrowed by <anon> at 4:9'
```