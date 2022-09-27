Goal: Pass all 4259065 tests in [sqllogictest](https://www.sqlite.org/sqllogictest/doc/trunk/about.wiki). From scratch. No dependencies. No surrender.*

## Day 1

I wrote the test harness in advance, so my starting point on Monday morning was 4.2 million test failures.

```
> zig build test_slt -Drelease-safe=true -- $(rg --files deps/slt)
HashMap(
    error.Unimplemented => 4259065,
)
passes => 0
```

Serious databases write their own parsers, but serious databases aren't finished in a week. We're going to need a shortcut. Let's grab this [bnf](https://github.com/JakeWheat/sql-overview/blob/master/sql-2016-foundation-grammar.txt) extracted from the SQL 2016 spec.

Only 9139 lines long.

Also impossible to parse, because they don't escape tokens. Sometimes a `[` is just a `[`, but sometimes it opens an optional group.

```
<left bracket> ::=
  [

<less than operator> ::=
  <

<identifier body> ::=
  <identifier start> [ <identifier part>... ]
```

Also check this out:

```
<national character large object type> ::=
    NATIONAL CHARACTER LARGE OBJECT [ <left paren> <character large object length> <right
    paren> ]
  | NCHAR LARGE OBJECT [ <left paren> <character large object length> <right paren> ]
  | NCLOB [ <left paren> <character large object length> <right paren> ]
```

Yeah, they line-wrapped to 90 columns in the middle of `<right paren>`, so I have to strip excess whitespace from names after parsing them.

So parsing the bnf is kind of a mess, but I only have to parse this one bnf and not bnfs in general so I just [mashed in a bunch of special cases](https://github.com/jamii/hytradboi-jam-2022/blob/2ce6ca692af647d32f830be7b9939bd1057fe18a/lib/sql/BnfParser.zig#L179-L219).

I don't really have a way of looking at the result yet, but I at least [have the right number of definitions](https://github.com/jamii/hytradboi-jam-2022/blob/2ce6ca692af647d32f830be7b9939bd1057fe18a/lib/sql/BnfParser.zig#L134-L141).

So now I just have to use the bnf to parse sql. I don't really know how to do that because I always just hand-write recursive descent parsers whenever I need to parse something.

The sql grammar is [left-recursive](https://en.wikipedia.org/wiki/Left_recursion#Removing_left_recursion) so I can't just go top-down or it will potentially loop forever. But there is a neat trick that I heard when working with [xtdb](https://xtdb.com/) earlier this year. It's tricky to explain, but the intuition is similar to how [iterative depth-first search](https://en.wikipedia.org/wiki/Iterative_deepening_depth-first_search) avoids getting stuck in infinitely deep search trees.

So whenever we hit a rule that might be left-recursive, we make an entry in the cache that says "parse failed". That forces it to explore other branches. If it manages to find some base case, we put that in the cache and try again to see if we can parse a bigger chunk of the input. If we ever get a result that is not better than the result already in the cache then there isn't any point exploring deeper trees.

[Here's the core of that loop](https://github.com/jamii/hytradboi-jam-2022/blob/2ce6ca692af647d32f830be7b9939bd1057fe18a/lib/sql/Parser.zig#L156-L182). It took a while to debug the logic, but I think it makes sense now that I've worked through it.

It took a lot more debugging to start successfully parsing actual sql:

* My bnf parser had the wrong binding power for `|`. I had to turn it into a slightly [Pratt](https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html) parser to fix it.
* The bnf from the spec doesn't describe actual sql that well (eg `select 1;` is invalid in the spec despite being accepted by every database since forever). So I've had to start tweaking the bnf to get the sqlite tests to parse.

Here's where the scoreboard stands at the end of the day.

```
> time zig build test_slt -Drelease-safe=true -- $(rg --files deps/slt)
HashMap(
    error.Unimplemented => 172471,
    error.ParseError => 4086594,
)
passes => 0
________________________________________________________
Executed in   94.84 secs    fish           external
   usr time   94.33 secs    2.63 millis   94.33 secs
   sys time    0.53 secs    0.00 millis    0.53 secs
```

Tomorrow I'll start working through those parse failures. Probably I'll need to build a little gui debugger to help, because trying to read through printlns of all the productions of that massive grammar is not time efficient.

## Day 2

I realized that I unthinkingly made the parser greedy. It will backtrack within an `either`, but if the first branch succeeds it will never go back to explore the second branch. That means when it hits something like `avg(c)` it parses the `avg` as an identifier and then can't backtrack to try to parse it as a function call later.

SQL can be parsed with this minimal backtracking (that's how the materialize parser works) but the bnf grammar is not designed with this in mind and it would be way too much work to edit it by hand.

I read a bunch about table driven parsers for arbitrary context-free grammars (because who knows what class of grammar this bnf is). Eventually I decided it would be safer to just add backtracking to the parser I already have, since that's a method I already understand.

I flailed for a long while trying to figure out how to combine this with the memoized loop used for handling left-recursive definitions. Eventually I came up with what I think is a workable design, where the memoized value is stored on the parse stack and the loop works by adding backtrack points whenever the a recursive definition completes succesfully.

I started on the implementation but at this point I'm just staring at the screen and not making forward progress, so I'm going to stop early and get some rest.

My original plan looked like this:

* sql parser (3 days)
* name resolution (1 day)
* type inference and lowering (1 day)
* optimization and execution (1 day)
* grind out the long tail of bugs (1 day)

I estimated 3 days to get the sql parser working because I've been to sql-land before and I know what horrors lurk there, but I'm a little worried now that it will take even longer.

&nbsp;

&nbsp;

&nbsp;

&nbsp;

&nbsp;

*May contain surrender.