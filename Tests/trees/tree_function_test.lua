
--  A tree as follows:   Rep(2) - Rep(3) - MockLeaf
-- 
--  MockLeaf should tally up as follows:
--      n_times_created: 6
--      n_times_called:  6
--      n_times_resumed: 0

treeDef = {
	nodes = {
		{
			type = "Repeater",
			ignoreFailure = false,
			N = 4
		},
		{
			type = "FunctionTest"
		}
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
				child_gt_inds = { }
			}
		},
		free_list = {
	
		}
	}
}

