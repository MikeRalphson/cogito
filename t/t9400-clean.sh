#!/usr/bin/env bash
#
# Copyright (c) 2005 Pvel Roskin
#
test_description="Tests basic cg-clean functionality

Create files and directories and check that cg-clean removes them
(and keeps files and directories it should keep)."

. ./test-lib.sh

# Use spaces in names to make sure they are handled properly.
echo "repo file 1" >"repo file 1"
mkdir "repo dir"
echo "repo file 2" >"repo dir/repo file 2"
echo "*.ign" >".gitignore"
echo "*.ign1" >"repo dir/.gitignore"

test_expect_success 'initialize repo' \
	"(cg-add -r * .gitignore && \
	  cg-commit -C -m\"Initial commit\")"

echo "extra file 1" >"extra file 1"
mkdir "extra dir 1"
echo "extra file 2" >"repo dir/extra file 2"
mkdir "repo dir/extra dir 2"
echo "extra file 3" >"extra dir 1/extra file 3"
echo "ign file 1" >"ign file 1.ign"
echo "ign file 2" >"ign file 2.ign1"
echo "ign file 3" >"repo dir/ign file 3.ign"
echo "ign file 4" >"repo dir/ign file 4.ign1"

# Create file lists under .git/temp, exclude .git/ from listings.
# Compare lists before and after cg-clean and check if only the expected
# files were removed.
topdir="`pwd`"
mkdir .git/temp
list="$topdir/.git/temp/list"

mklist()
{
	cd "$topdir"
	find . 2>/dev/null | sed -n "/^.\/.git\//d;s/^..//p" |
		sort > "$list-$1"
}

check_loss()
{
	mklist new
	echo "$loss" | cat - "$list-new" |
		grep -v ^$ | sort >"$list-combined"
	diff -u "$list-init" "$list-combined" > "$list.diff" &&
		cp -f "$list-new" "$list-init"
}

mklist init
loss=''
test_expect_success 'cg-clean -n in top-level dir' \
	"(cg-clean -n && check_loss)"

test_expect_success 'cg-clean -Ddxqn in top-level dir' \
	"(cg-clean -Ddxqn && check_loss)"

test_expect_success 'cg-clean -n in subdir' \
	"(cd 'repo dir' && cg-clean -n && check_loss)"

loss='repo dir/extra file 2'
test_expect_success 'cg-clean in subdir' \
	"(cd 'repo dir' && cg-clean && check_loss)"

loss='repo dir/extra dir 2'
test_expect_success 'cg-clean -d in subdir' \
	"(cd 'repo dir' && cg-clean -d && check_loss)"

loss='repo dir/ign file 3.ign
repo dir/ign file 4.ign1'
test_expect_success 'cg-clean -x in subdir' \
	"(cd 'repo dir' && cg-clean -x && check_loss)"

# Restore extra files in "repo dir"
echo "extra file 2" >"repo dir/extra file 2"
mkdir "repo dir/extra dir 2"
echo "ign file 3" >"repo dir/ign file 3.ign"
echo "ign file 4" >"repo dir/ign file 4.ign1"
mklist init

# FIXME: cg-clean shouldn't clean unknown directories without "-d"
loss='extra file 1
ign file 2.ign1
extra dir 1/extra file 3
repo dir/extra file 2'
test_expect_success 'cg-clean in top-level dir' \
	"(cg-clean && check_loss)"

loss='ign file 1.ign
repo dir/ign file 3.ign
repo dir/ign file 4.ign1'
test_expect_success 'cg-clean -x in top-level dir' \
	"(cg-clean -x && check_loss)"

loss='extra dir 1
repo dir/extra dir 2'
test_expect_success 'cg-clean -d in top-level dir' \
	"(cg-clean -d && check_loss)"

mkdir "extra dir 3"
chmod 000 "extra dir 3"
mklist init
loss='extra dir 3'
test_expect_success 'cg-clean -D in top-level dir' \
	"(cg-clean -D && check_loss)"

test_done
