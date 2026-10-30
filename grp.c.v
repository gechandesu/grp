@[has_globals]
module grp

import sync

$if windows {
	$compile_error('grp: MS Windows is not supported')
}

#include <errno.h>
#include <grp.h>

struct C.group {
	gr_name   &char
	gr_passwd &char
	gr_gid    i32
	gr_mem    &&char
}

fn C.getgrnam(&char) &C.group
fn C.getgrgid(i32) &C.group
fn C.getgrent() &C.group
fn C.setgrent()
fn C.endgrent()

__global grp__mutex__ &sync.Mutex

fn init() {
	grp__mutex__ = sync.new_mutex()
}

fn cleanup() {
	grp__mutex__.destroy()
	unsafe { free(grp__mutex__) }
}

pub struct Group {
pub:
	name    string
	passwd  string
	gid     int
	members []string
}

fn make_group(gr &C.group) Group {
	mut members := []string{}
	mut ptr := gr.gr_mem
	for unsafe { ptr[0] != nil } {
		str := unsafe { cstring_to_vstring(ptr[0]) }
		unsafe { ptr++ }
		members << str
	}
	return unsafe {
		Group{
			name:    cstring_to_vstring(gr.gr_name)
			passwd:  cstring_to_vstring(gr.gr_passwd)
			gid:     gr.gr_gid
			members: members
		}
	}
}

fn make_error(name string, gid int) IError {
	err := C.errno
	if err !in [4, 5, 11, 12, 23, 24, 34] {
		// Error is not EINTR, EIO, EAGAIN, ENOMEM, ENFILE, EMFILE or ERANGE
		return EntryNotFoundError{
			name: name
			gid:  gid
		}
	}
	return error_with_code(c_error_number_str(err), err)
}

// group_by_gid returns group entry by group name.
// If the entry is not found, the EntryNotFoundError error will be returned.
pub fn group_by_name(name string) !Group {
	grp__mutex__.@lock()
	defer {
		grp__mutex__.unlock()
	}
	gr := C.getgrnam(&char(name.str))
	if isnil(gr) {
		return make_error(name, -1)
	}
	return make_group(gr)
}

// group_by_gid returns group entry by GID.
// If the entry is not found, the EntryNotFoundError error will be returned.
pub fn group_by_gid(gid int) !Group {
	grp__mutex__.@lock()
	defer {
		grp__mutex__.unlock()
	}
	gr := C.getgrgid(i32(gid))
	if isnil(gr) {
		return make_error('', gid)
	}
	return make_group(gr)
}

// groups returns all groups from group database in arbitrary order.
pub fn groups() ![]Group {
	mut grps := []Group{}
	grp__mutex__.@lock()
	C.setgrent()
	defer {
		C.endgrent()
		grp__mutex__.unlock()
	}
	for {
		gr := C.getgrent()
		err := make_error('', -1)
		if err.code() != 0 {
			return err
		}
		if isnil(gr) {
			break
		}
		grps << make_group(gr)
	}
	return grps
}

// EntryNotFoundError designates that an entry with the specified GID or name was not found.
pub struct EntryNotFoundError {
	Error
	name string
	gid  int
}

// msg returns the EntryNotFoundError error message.
pub fn (e EntryNotFoundError) msg() string {
	if e.name != '' {
		return "no group entry found by name '${e.name}'"
	}
	return 'no group entry found by user ID ${e.gid}'
}
