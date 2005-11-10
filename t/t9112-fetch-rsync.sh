#!/usr/bin/env bash
#
# Copyright (c) 2005 Petr Baudis
#
test_description="Tests cg-fetch over rsync

cg-fetch over rsync - if it works at all, and if it catches missing objects."

. ./test-lib.sh

# Trick to be able to use the rsync:// URLs locally. That's not something
# we want the regular user to do, but it's handy for testing, so our tool
# will just strip 'rsync://local/' from the URL start, leaving the rest
# as-is.
export RSYNC="$(pwd)/localrsync"
cat >localrsync <<EOF
#!/usr/bin/env bash
args=()
for arg in "\$@"; do
	args[\${#args[@]}]="\$(echo "\$arg" | sed 's#rsync://local/#$(pwd | sed 's/#/\\#/g')/#')"
done
rsync "\${args[@]}"
EOF
chmod a+x localrsync

verify_repo2() {
test_expect_success 'verifying repo2' \
		"(cmp repo2/.git/refs/heads/origin repo2/.git/refs/heads/master &&
		  cd repo2 && git-fsck-objects)"
}

mkdir repo1
echo stuff >repo1/file
test_expect_success 'initialize repo1' \
		"(cd repo1 && cg-init -I && cg-add file && cg-commit -C -m\"Initial commit\")"
test_expect_success 'clone repo2' \
		"(cg-clone rsync://local/repo1/.git repo2 &&
		  cmp repo2/.git/refs/heads/origin repo1/.git/refs/heads/master)"
verify_repo2

echo more stuff >>repo1/file
test_expect_success 'local commit in repo1' \
		"(cd repo1 && cg-commit -m\"Second commit\")"
test_expect_success 'updating repo2' \
		"(cd repo2 && cg-update &&
		  cmp .git/refs/heads/origin ../repo1/.git/refs/heads/master)"
verify_repo2

echo even more stuff >>repo1/file
test_expect_success 'local commit in repo1' \
		"(cd repo1 && cg-commit -m\"Third commit\")"
obj="$(cd repo1 && cg-admin-ls file | cut -f 1 | cut -d ' ' -f 3)"
test_expect_success 'damaging repo1' \
		"(cd repo1 && rm -f .git/objects/${obj:0:2}/${obj:2})"
test_expect_failure 'updating repo2' \
		"(cd repo2 && cg-fetch)" # to prevent merge failing too late
verify_repo2

test_done
