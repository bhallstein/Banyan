Node Tree_Selector = construct({
  .node = Selector(),
  .props = {
    {"random_order", {.bool_value = false}},
    {"stop_after_first_success", {.bool_value = true}},
  },
  .children = {
    {
      .node = MockLeaf,
      .props = {
        {"succeeds", {.bool_value = false}},
      },
    },
    {
      .node = MockLeaf,
      .props = {
        {"succeeds", {.bool_value = false}},
      },
    },
    {
      .node = MockLeaf,
      .props = {
        {"succeeds", {.bool_value = false}},
      },
    },
    {
      .node = MockLeaf,
      .props = {
        {"succeeds", {.bool_value = true}},
      },
    },
    {
      .node = MockLeaf,
      .props = {
        {"succeeds", {.bool_value = false}},
      },
    },
  },
});
