// Minimal Jsonnet test helpers
{
  // Create an equality test case
  equal(name, got, want):: {
    name: name,
    pass: got == want,
    got: got,
    want: want,
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
}

