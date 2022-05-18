Node Tree_While = construct({
  .node = While(),
  .children = {
    {.node = MockFailOnThirdCall},
    {.node = MockLeaf},
  },
});
