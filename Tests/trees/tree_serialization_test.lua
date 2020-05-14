treeDef = {
    nodes = {
        n0 = {
            succeeds = true,
            type = "MockLeaf"
        },
        n1 = {
            N = 2,
            ignoreFailure = false,
            type = "Repeater"
        },
        n2 = {
            N = 3,
            ignoreFailure = false,
            type = "Repeater"
        }
    },
    tree = {
        free_list = { },
        tree = {
            n0 = {
                child_gt_inds = {
                    n0 = 1
                },
                node_orig_ind = 0,
                parent_gt_ind = 2
            },
            n1 = {
                child_gt_inds = { },
                node_orig_ind = 1,
                parent_gt_ind = 0
            },
            n2 = {
                child_gt_inds = {
                    n0 = 0
                },
                node_orig_ind = 2,
                parent_gt_ind = -1
            }
        }
    }
}