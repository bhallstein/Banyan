
--  A tree as follows:   Seq - MockLeaf[S]
--                          └─ ~
--                          └─ ~
--                          └─ ~[F]  - if F, and Seq::ignoreFailure = false, exp. only 4
--                          └─ ~       (if Seq::ignoreFailure = true, then still 5)
--  
--  - MockLeaf should be called 5 times:
--      n_times_created: 5
--      n_times_called:  5
--      n_times_resumed: 0


nodes = {
	{
		type = "Sequence",
		ignoreFailure = false
	},
	{
		type = "MockLeaf",
		succeeds = true,
	},
	{
		type = "MockLeaf",
		succeeds = true,
	},
	{
		type = "MockLeaf",
		succeeds = true,
	},
	{
		type = "MockLeaf",
		succeeds = true,
	},
	{
		type = "MockLeaf",
		succeeds = true,
	},
}

tree = {
	tree = {
		{
			node_orig_ind = 0,
			parent_gt_ind = -1,
			child_gt_inds = { 1, 2, 3, 4, 5 }
		},
		{
			node_orig_ind = 1,
			parent_gt_ind = 0,
			child_gt_inds = { }
		},
		{
			node_orig_ind = 2,
			parent_gt_ind = 0,
			child_gt_inds = { }
		},
		{
			node_orig_ind = 3,
			parent_gt_ind = 0,
			child_gt_inds = { }
		},
		{
			node_orig_ind = 4,
			parent_gt_ind = 0,
			child_gt_inds = { }
		},
		{
			node_orig_ind = 5,
			parent_gt_ind = 0,
			child_gt_inds = { }
		},
	},
	free_list = {
	
	}
}


