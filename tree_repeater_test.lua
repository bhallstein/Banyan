
--  A tree as follows:   Rep(2) - Rep(3) - MockLeaf
-- 
--  MockLeaf should tally up as follows:
--      n_times_created: 6
--      n_times_called:  6
--      n_times_resumed: 0


nodes = {
	{
		type = "Repeater",
		ignoreFailure = false,
		N = 3
	},
	{
		type = "MockLeaf",
		succeeds = true
	},
	{
		type = "Repeater",
		N = 2,
		ignoreFailure = false
	},
}

tree = {
	tree = {
		{
			node_orig_ind = 0,
			parent_gt_ind = 2,
			child_gt_inds = { 1 }
		},
		{
			node_orig_ind = 1,
			parent_gt_ind = 0,
			child_gt_inds = { }
		},
		{
			node_orig_ind = 2,
			parent_gt_ind = -1,
			child_gt_inds = { 0 }
		}
	},
	free_list = {
	
	}
}


