// vtest build: !windows

module grp

fn test_group_by_gid() {
	root := group_by_gid(0)!
	assert root.gid == 0
	assert root.name == 'root'
}

fn test_group_by_name() {
	root := group_by_name('root')!
	assert root.gid == 0
	assert root.name == 'root'
}

fn test_groups() {
	grps := groups()!
	assert grps.len > 0
}
