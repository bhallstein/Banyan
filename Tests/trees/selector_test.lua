
--  A tree as follows:   Sel - MockLeaf[F]
--                          └─ ~[F]
--                          └─ ~[F]
--                          └─ ~[S]
--                          └─ ~[F]
-- 
--  (If the Selector is set to randomize its order, the no. of MockLeaf calls
--  will be variable.)
--
--  (If the Selector is set *not* to stop after the first success, the no. of
--  calls will be 5 instead of 4.)
-- 
--  - MockLeaf should be called 4 times:
--      n_times_created: 4
--      n_times_called:  4
--      n_times_resumed: 0

treeDef = {
	nodes = {
		{
			type = "Selector",
			stopAfterFirstSuccess = true,
			randomizeOrder = false
		},
		{
			type = "MockLeaf",
			succeeds = false,
		},
		{
			type = "MockLeaf",
			succeeds = false,
		},
		{
			type = "MockLeaf",
			succeeds = false,
		},
		{
			type = "MockLeaf",
			succeeds = true,
		},
		{
			type = "MockLeaf",
			succeeds = false,
		},
	},

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
}

