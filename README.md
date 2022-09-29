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

## Day 3

Yesterday I was trying to be all fancy make the backtracking actually backtrack (which is much harder when you don't have generators or lazy lists built into the language). Today I decided to just get on with it and generate every subparse. I got this working really quickly.

Unfortunately, I then discovered that the bnf from the spec is wildly ambiguous. Check out the [7 different parses](https://gist.github.com/jamii/2a497a867a5612adaac5536f290ac29c) for `select 1;`.

I ran the thing against the whole test suite just to see how badly I'm doing:

```
HashMap(
    error.NoParse => 3971842,
    error.Unimplemented => 275660,
    error.AmbiguousParse => 11563,
)
passes => 0
________________________________________________________
Executed in   31.88 mins    fish           external
   usr time   31.77 mins    0.00 micros   31.77 mins
   sys time    0.10 mins  734.00 micros    0.10 mins
```

It's really slow because every complex query produces a bazillion parse trees. And it's still not parsing most of the tests correctly.

Plus, even if I get this whole thing working, I have to then turn those awful parse trees into something sane.

So... this is not going to work.

I didn't want to roll my own parser because we did that at materialize and while it worked out fine, it's more than 10kloc of rust. If I was just directly transcribing it I would have to type at 5 characters per second for 24 straight hours. I looked around at some other databases and even the ones that use parser generators are huge:

```
> scc cockroachdb-parser/pkg/sql/scanner/ cockroachdb-parser/pkg/sql/parser/
-------------------------------------------------------------------------------
Language                 Files     Lines   Blanks  Comments     Code Complexity
-------------------------------------------------------------------------------
Go                           6      2305      202       356     1747        403
AWK                          4       243       27        73      143          0
Bazel                        2       183       11         9      163          0
Shell                        2        49       13         8       28          1
Happy                        1     14658      843         0    13815          0
Markdown                     1       284       65         0      219          0
gitignore                    1         8        1         2        5          0
-------------------------------------------------------------------------------
Total                       17     17730     1162       448    16120        404
-------------------------------------------------------------------------------
Estimated Cost to Develop (organic) $500,413
Estimated Schedule Effort (organic) 10.572043 months
Estimated People Required (organic) 4.205190
-------------------------------------------------------------------------------
Processed 506614 bytes, 0.507 megabytes (SI)
-------------------------------------------------------------------------------
```

Except sqlite, which has a tiny little grammar definition.

```
> scc sqlite/src/parse.y sqlite/tool/lemon.c sqlite/tool/lempar.c
-------------------------------------------------------------------------------
Language                 Files     Lines   Blanks  Comments     Code Complexity
-------------------------------------------------------------------------------
C                            2      6961      356      1195     5410        916
Happy                        1      1928      179         0     1749          0
-------------------------------------------------------------------------------
Total                        3      8889      535      1195     7159        916
-------------------------------------------------------------------------------
Estimated Cost to Develop (organic) $213,397
Estimated Schedule Effort (organic) 7.647269 months
Estimated People Required (organic) 2.479133
-------------------------------------------------------------------------------
Processed 285597 bytes, 0.286 megabytes (SI)
-------------------------------------------------------------------------------
```

I only have to parse sqlite grammar, and even then probably only a fraction of it. So it looks like writing a parser generator might be plausible and by now it's really my only option if I want to get any tests passing at all.

So here's my [grammar](https://github.com/jamii/hytradboi-jam-2022/blob/main/lib/sql/grammar.txt) so far. It's parsed by [GrammarParser](https://github.com/jamii/hytradboi-jam-2022/blob/main/lib/sql/GrammarParser.zig). In theory I could do this at comptime, but until we get a [comptime allocator](https://github.com/ziglang/zig/issues/1291) that's going to be a yak shave and I am way too many yak shaves deep already. So I laboriously but reliably write out all the rules into [grammar.zig](https://github.com/jamii/hytradboi-jam-2022/blob/18c97acf216d88001595fddf623d32cdbfdd385c/lib/sql/grammar.zig). 

The [Tokenizer](https://github.com/jamii/hytradboi-jam-2022/blob/18c97acf216d88001595fddf623d32cdbfdd385c/lib/sql/Tokenizer.zig) is written by hand and seems to be basically done - it runs without complaint on the entire test set. I might discover bugs there later, of course.

The [Parser](https://github.com/jamii/hytradboi-jam-2022/blob/main/lib/sql/Parser.zig) is fun. There is a single parse function, but because it reads the rules from grammar.zig at compile time it gets specialized for each parse rule. Basically I got the same result as hand-generating the parser code, without having to splices a bunch of strings together. After the jam maybe I'll have some yak shave time to cut out grammar.zig entirely and do all the grammar stuff at comptime, and then it'll be a pretty sweet system.

The best part about this is that I get really nice parse trees by generating rich types from the input grammar. [Eg](https://github.com/jamii/hytradboi-jam-2022/blob/main/lib/sql/grammar.zig#L442-L460).

``` zig
pub const anon_18 = ?distinct_or_all;
pub const anon_19 = ?from;
pub const anon_20 = ?where;
pub const anon_21 = ?group_by;
pub const anon_22 = ?having;
pub const anon_23 = ?window;
pub const anon_24 = ?order_by;
pub const anon_25 = ?limit;
pub const select = struct {
    distinct_or_all: *anon_18,
    result_columns: *result_columns,
    from: *anon_19,
    where: *anon_20,
    group_by: *anon_21,
    having: *anon_22,
    window: *anon_23,
    order_by: *anon_24,
    limit: *anon_25,
};
```

I still can't parse many of the tests because I haven't implemented expressions, operator precedence etc. So I'm still stuck in parsing land. But I can see the light at the end of the tunnel now. 

And at least it's fast:

```
> time zig build test_slt -Drelease-safe=true -- $(rg --files deps/slt)
HashMap(
    error.ParseError => 4257825,
    error.Unimplemented => 1240,
)
passes => 0
________________________________________________________
Executed in   11.85 secs    fish           external
   usr time   11.49 secs    0.44 millis   11.49 secs
   sys time    0.39 secs    1.79 millis    0.39 secs
```

I'm going to spend tomorrow fleshing out as much of the parsing as possible and then switch to trying to analyze and execute some of the simpler tests.

&nbsp;

&nbsp;

&nbsp;

&nbsp;

&nbsp;

*May contain surrender.