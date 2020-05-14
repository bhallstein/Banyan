
--  A tree as follows:   Rep(2) - Succ - MockLeaf(fail)
-- 
--  - Rep is set *not* to ignore child failures, but the Succeeder should ensure
--    the Mock-fail-inducer is overruled
--  
--  - So MockLeaf should be called twice:
--      n_times_created: 2
--      n_times_called:  2
--      n_times_resumed: 0


nodes = {
	{
		type = "Repeater",
		N = 2,
		ignoreFailure = false
	},
	{
		type = "Succeeder"
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


