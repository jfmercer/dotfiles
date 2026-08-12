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
    # -c rather than `git config`: the runner may have no committer identity.
    git init -q -b master "$REPO"
    cd "$REPO" || return 1
    git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

# branches -- every local branch, one per line, undecorated and sorted.
branches() {
    git for-each-ref --format='%(refname:short)' refs/heads/ | sort
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
    git branch -m master main
    git branch topic-a

    run "$GDLM"
    assert_success
    assert_equal "$(branches)" "main"
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
