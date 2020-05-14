
--  A tree as follows:   While┬─ F             - condition fn which fails 2nd time
--                            └─ MockLeaf[F]   - action which fails
--  
-- - F shoudl be called 3x, and MockLeaf 2x
-- 

nodes = {
	{
		type = "While",
		breakOnFailuresIn2ndChild = false
	},
	{
		type = "NodeThatFailsEventually"
	},
	{
		type = "MockLeaf",
		succeeds = false,
	}
}

tree = {
	tree = {
		{
			node_orig_ind = 0,
			parent_gt_ind = -1,
			child_gt_inds = { 1, 2 }
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
		}
	},
	free_list = {
	
	}
}


