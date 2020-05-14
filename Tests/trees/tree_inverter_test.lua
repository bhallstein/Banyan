
--  A tree as follows:   Rep(2) - Inv - MockLeaf(succ)
-- 
--  Rep is set *not* to ignore child failures, so MockLeaf
--  should only be called once:
--      n_times_created: 1
--      n_times_called:  1
--      n_times_resumed: 0

treeDef = {
	nodes = {
		{
			type = "Repeater",
			N = 2,
			ignoreFailure = false
		},
		{
			type = "Inverter"
		},
		{
			type = "MockLeaf",
			succeeds = true,
		},
	},

	tree = {
		tree = {
			{
				node_orig_ind = 0,
				parent_gt_ind = -1,
				child_gt_inds = { 1 }
			},
			{
				node_orig_ind = 1,
				parent_gt_ind = 0,
				child_gt_inds = { 2 }
			},
			{
				node_orig_ind = 2,
				parent_gt_ind = 1,
				child_gt_inds = { }
			}
		},
		free_list = {
	
		}
	}
}

