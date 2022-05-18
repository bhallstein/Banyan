Node Tree_Repeater = construct({
  .node = Repeater(),
  .props = {
    {"N", {.int_value = 3}},
    {"break_on_failure", {.bool_value = true}},
  },
  .children = {
    {
      .node = Repeater(),
      .props = {
        {"N", {.int_value = 2}},
      },
      .children = {
        {.node = MockLeaf},
      },
    },
  },
});
