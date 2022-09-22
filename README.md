Goal: 100% pass on [sqllogictest](https://www.sqlite.org/sqllogictest/doc/trunk/about.wiki). From scratch. No dependencies.

```
zig build test_slt -Drelease-safe=true -- $(rg --files deps/slt)
```

# Links

https://www.sqlite.org/lang.html
https://www.sqlite.org/lang_keywords.html