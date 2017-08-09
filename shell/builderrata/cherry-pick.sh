#!/bin/sh
basedir=`dirname $0`

. $basedir/config.sh

cherry_pick()
{
  local rel_tgt
  local expect_commits_file=/tmp/commits_file.txt
  local summary_commits_file=/tmp/kernel_summary.txt
  if [ $# -ne 3 ]
  then
    echo "specify the release version: <10_3|11_0> <expected_commit_file> <sum_commit_file>"
    exit 1
  fi
  rel_tgt=$1
  expect_commits_file=$2
  summary_commits_file=$3
  local expected=$(is_expected_repo $g_git_repo)
  if [ $expected == 0 ]
  then
    cherry_pick_for_frbsd $rel_tgt $expect_commits_file $summary_commits_file
  else
    echo "Please run this script under local $g_git_repo"
  fi
}

cherry_pick $*
