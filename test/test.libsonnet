local joinIfStringArray(arr) =
    if std.type(arr) == "array" && std.length(arr) > 0 && std.type(arr[0]) == "string"
    then std.join("\n", arr)
    else arr;

{
  // Create an equality test case
  equal(name, got, want)::{
    name: name,
    pass: got == want,
    got: joinIfStringArray(got),
    want: joinIfStringArray(want),
  },

  // Create a predicate test case
  truthy(name, cond, got=null):: {
    name: name,
    pass: !!cond,
    got: if got == null then cond else got,
    want: true,
  },

  falsy(name, cond, got=null):: {
    name: name,
    pass: !cond,
    got: if got == null then cond else got,
    want: false,
  },

  // Group a set of cases under a suite name.
  // Preferred shape: objects with a `cases` array.
  suite(name, cases):: {
    name: name,
    cases: cases,
  },
}
