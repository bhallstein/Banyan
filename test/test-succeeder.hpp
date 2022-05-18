Node Tree_Succeeder = construct({
  .node = Repeater(),
  .props = {
    {"N", {.int_value = 2}},
  },
  .children = {
    {
      .node = Succeeder(),
      .children = {
        {.node = MockLeaf},
      },
    },
  },
});
