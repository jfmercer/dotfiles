#!/usr/bin/env bats
#
# bin/git-delete-local-merged. Most `git-*` helpers here are one-line wrappers
# that a test could only restate, but this one decides which branches to
# destroy, and it got that decision wrong in two ways that a reader could not
# see:
#
# 1. It stripped the newlines out of `git branch --merged` and passed the result
#    to `git branch -d` as a single quoted argument, so two or more candidates
#    produced `error: branch '  topic-a  topic-b' not found` and deleted nothing.
# 2. It filtered with `grep -v master`, an unanchored substring match, which
#    skipped `feature/master-fix` while protecting nothing named `main`.
#
# git is not stubbed: the script *is* its git invocations, and every test runs
# against a throwaway repo under $BATS_TEST_TMPDIR.

load helpers/stub.bash

setup() {
    setup_sandbox
    GDLM="$REPO_ROOT/bin/git-delete-local-merged"
    if ! command -v git >/dev/null 2>&1; then
        skip "git not installed"
    fi
    REPO="$BATS_TEST_TMPDIR/repo"
    git init -q -b master "$REPO"
    cd "$REPO" || return 1
    # Repo-local, because the runner may have no committer identity at all.
    git config user.name t
    git config user.email t@t
    git commit -q --allow-empty -m init
}

# branches -- every local branch, one per line, undecorated and sorted.
branches() {
    git for-each-ref --format='%(refname:short)' refs/heads/ | sort
}

# commit_file <name> -- a commit with real content. The rebase-merge tests
# compare by patch id, and an empty commit has no patch to compare.
commit_file() {
    printf '%s\n' "$1" >"$1"
    git add "$1"
    git commit -q -m "add $1"
}

# add_remote -- a bare origin with master pushed and tracking.
add_remote() {
    git init -q --bare "$BATS_TEST_TMPDIR/remote.git"
    git remote add origin "$BATS_TEST_TMPDIR/remote.git"
    git push -q -u origin master
}

# rebase_merge <branch> -- what GitHub's rebase merge does to this repo: replay
# the branch's commits onto master as new commits with new SHAs, so the branch
# tip is never an ancestor of master.
rebase_merge() {
    git checkout -q master
    # Master moves on while the PR is open. Without that, replaying the commit
    # onto an unchanged master reproduces its hash exactly -- same tree, same
    # parent, same author, same committer second -- and the branch stays an
    # ancestor, which is the one thing a rebase merge never leaves behind.
    commit_file "mainline-$1"
    git cherry-pick "master..$1" >/dev/null
    git push -q origin master
}

# retire_remote_branch <branch> -- delete it on the remote and notice locally,
# which is what leaves the upstream [gone].
retire_remote_branch() {
    git push -q origin --delete "$1"
    git fetch -q --prune
}

@test "deletes every merged branch, not just a mangled first one" {
    git branch topic-a
    git branch topic-b
    git branch topic-c

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "master"
}

@test "keeps the branch you are on" {
    git branch topic-a
    git checkout -q topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "keeps master even when it is merged into the current branch" {
    git checkout -q -b topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "keeps main, not just master" {
    # Checked out elsewhere, so this pins the default-branch guard rather than
    # the current-branch one -- with `main` current, the other guard covers it
    # and removing `master | main` entirely would leave this test green.
    git branch -m master main
    git checkout -q -b topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "$(printf 'main\ntopic-a')"
}

@test "deletes a branch whose name merely contains master" {
    git branch feature/master-fix

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "master"
}

@test "keeps unmerged branches" {
    git checkout -q -b topic-a
    git -c user.name=t -c user.email=t@t commit -q --allow-empty -m work
    git checkout -q master

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "succeeds with nothing to do" {
    run "$GDLM"
    assert_success
    assert_output_contains "No merged branches to delete."
}

# --- rebase merge -------------------------------------------------------
#
# This repo is rebase-merge only, so a merged branch is replayed onto master
# under a new SHA and the ancestry test above can never fire for it. Both
# signals are required: the commits are upstream by patch id, AND the remote
# branch is gone. Either alone is ambiguous, so either alone must not delete.

@test "deletes a rebase-merged branch once its remote branch is gone" {
    add_remote
    git checkout -q -b topic-a
    commit_file work
    git push -q -u origin topic-a
    rebase_merge topic-a
    retire_remote_branch topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "master"
}

@test "keeps a rebase-merged branch whose remote branch still exists" {
    add_remote
    git checkout -q -b topic-a
    commit_file work
    git push -q -u origin topic-a
    rebase_merge topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "deletes a rebase-merged branch that was pushed without an upstream" {
    # `git push origin <branch>` -- the explicit refspec, which is what `gh pr
    # create` and every push-by-name does -- sets no branch.<name>.merge, and
    # push.autoSetupRemote does not apply to it. So git never marks this branch
    # [gone], and the earlier [gone]-only test kept it forever. Note the absent
    # `-u` below: it is the entire point of this test.
    add_remote
    git checkout -q -b topic-a
    commit_file work
    git push -q origin topic-a
    rebase_merge topic-a
    retire_remote_branch topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "master"
}

@test "keeps a branch pushed without an upstream whose remote branch still exists" {
    # The other half: dropping the [gone] check must not degrade into deleting
    # anything patch-identical. This branch has landed but its remote copy is
    # still there, so it stays.
    add_remote
    git checkout -q -b topic-a
    commit_file work
    git push -q origin topic-a
    rebase_merge topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "keeps an abandoned branch that is gone from the remote but never landed" {
    add_remote
    git checkout -q -b topic-a
    commit_file work
    git push -q -u origin topic-a
    git checkout -q master
    retire_remote_branch topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

# --- arguments ----------------------------------------------------------

@test "dry run deletes nothing and explains both decisions" {
    add_remote
    git checkout -q -b topic-a
    commit_file work
    git push -q -u origin topic-a
    rebase_merge topic-a
    retire_remote_branch topic-a
    git branch topic-b # merged by ancestry
    git checkout -q -b wip
    commit_file wip-work
    git checkout -q master

    run "$GDLM" --dry-run
    assert_success
    assert_output_contains "would delete: topic-a (merged upstream, no remote branch)"
    assert_output_contains "would delete: topic-b (already merged into HEAD)"
    assert_output_contains "would keep:   wip (not merged)"
    assert_equal "$(branches)" "$(printf 'master\ntopic-a\ntopic-b\nwip')"
}

@test "-n is accepted as well as --dry-run" {
    git branch topic-a

    run "$GDLM" -n
    assert_success
    assert_output_contains "would delete: topic-a"
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "naming a branch restricts the run to that branch" {
    git branch topic-a
    git branch topic-b

    run "$GDLM" topic-a
    assert_success
    assert_equal "$(branches)" "$(printf 'master\ntopic-b')"
}

@test "naming a branch it will not delete says why" {
    git checkout -q -b topic-a
    commit_file work
    git checkout -q master

    run "$GDLM" topic-a
    assert_success
    assert_output_contains "topic-a is not merged; leaving it."
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "naming a protected branch says why rather than silently doing nothing" {
    # From a topic branch, so this exercises the default-branch guard rather
    # than the current-branch one.
    git checkout -q -b topic-a

    run "$GDLM" master
    assert_success
    assert_output_contains "master is the default branch; leaving it."
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}

@test "naming the branch you are on says so" {
    git checkout -q -b topic-a

    run "$GDLM" topic-a
    assert_success
    assert_output_contains "topic-a is the branch you are on; leaving it."
}

@test "an unknown branch name is an error" {
    run "$GDLM" no-such-branch
    assert_failure
    assert_output_contains "no such branch"
}

@test "an unknown option is an error, not a branch name" {
    git branch topic-a

    run "$GDLM" --wat
    assert_failure
    assert_equal "$status" 2
    assert_output_contains "usage:"
    assert_equal "$(branches)" "$(printf 'master\ntopic-a')"
}
