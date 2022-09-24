Goal: Pass all 4259065 tests in [sqllogictest](https://www.sqlite.org/sqllogictest/doc/trunk/about.wiki). From scratch. No dependencies. No surrender.*

```
> zig build test_slt -Drelease-safe=true -- $(rg --files deps/slt)
HashMap(
    error.Unimplemented => 4259065,
)
passes => 0
```

&nbsp;

&nbsp;

&nbsp;

&nbsp;

&nbsp;

*May contain surrender.