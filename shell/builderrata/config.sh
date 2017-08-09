#!/bin/sh
g_timestamp=`date +%Y%m%d%H%M%S`
g_git_repo="FreeBSD-Integration-Service"
g_date_10_3_start_4_missing_patch="2016-12-10"
g_date_11_0_start_4_missing_patch="2016-12-08"
g_date_4_10_3_release="2016-03-25"
g_date_4_11_0_release="2016-09-29"
g_frbsd_10_3_releng="upstream/releng/10.3"
g_frbsd_10_3_hyperv="origin/10.3.0_hyperv"
g_frbsd_10_3_local_prefix="azure/hyperv_10.3"
g_frbsd_10_3_local=${g_frbsd_10_3_local_prefix}"_"${g_timestamp}
g_frbsd_11_0_releng="upstream/releng/11.0"
g_frbsd_11_0_hyperv="origin/11.0.0_hyperv"
g_frbsd_11_0_local_prefix="azure/hyperv_11.0"
g_frbsd_11_0_local=${g_frbsd_11_0_local_prefix}"_"${g_timestamp}
g_author_list="sephe@FreeBSD.org|honzhan@microsoft.com|decui@microsoft.com|decui@FreeBSD.org"
###################### dst_brh(releng)     |   src_brh(hyperv)  | date_from_when_patch_was_missing | frbsd_release_date   | local branch name | local branch prefix  ####
g_frbsd_10_3_ci_array="$g_frbsd_10_3_releng|$g_frbsd_10_3_hyperv|$g_date_10_3_start_4_missing_patch|$g_date_4_10_3_release|$g_frbsd_10_3_local|$g_frbsd_10_3_local_prefix"
g_frbsd_11_0_ci_array="$g_frbsd_11_0_releng|$g_frbsd_11_0_hyperv|$g_date_11_0_start_4_missing_patch|$g_date_4_11_0_release|$g_frbsd_11_0_local|$g_frbsd_11_0_local_prefix"
g_ci_prefix="g_frbsd_"
g_ci_postfix="_ci_array"
derefer_2vars() {
   local prefix=$1
   local postfix=$2
   local v=${prefix}${postfix}
   eval echo \$${v}
}

## return the value according to index: 
## @param arr: array (using string)
## @param index: array index (start from 1)
## @param separator: string's separator which is used separate the array item
array_get() {
  local arr=$1
  local index=$2
  local separator=$3
  echo ""|awk -v sep=$separator -v str="$arr" -v idx=$index '{
   split(str, array, sep);
   print array[idx]
}'
}

is_expected_repo() {
  local expectRepo=$1
  local repo
  # https://github.com/FreeBSDonHyper-V/FreeBSD-Integration-Service.git
  # FreeBSD-Integration-Service.git
  # FreeBSD-Integration-Service
  repo=`git config --get remote.origin.url | awk -F / '{print $NF}' | awk -F . '{print $1}'`
  if [ $repo == $expectRepo ]
  then
     echo 0
  else
     echo 1
  fi
}
test_array() {
  local frbsd_rel_tgt="$1"
  local rel_tgt_arr_prefix=${g_ci_prefix}${frbsd_rel_tgt}
  local rel_arr_nm=$(derefer_2vars ${rel_tgt_arr_prefix} ${g_ci_postfix})
  echo $rel_arr_nm
  local dst_branch=$(array_get $rel_arr_nm 1 "|")
  local src_branch=$(array_get $rel_arr_nm 2 "|")
  local patch_start_date=$(array_get $rel_arr_nm 3 "|")
  local date_4_rel=$(array_get $rel_arr_nm 4 "|")
  local dst_local_branch=$(array_get $rel_arr_nm 5 "|")

  echo "dst_branch: $dst_branch"
  echo "src_branch: $src_branch"
  echo "patch_start: $patch_start_date"
  echo "date_4_release: $date_4_rel"
  echo "dst_local_br: $dst_local_branch"
}

pwd_check() {
  local curr_pwd=`pwd`
  local git_root=`git rev-parse --show-toplevel`
  if [ $? -ne 0 ]
  then
     #echo "Please run this script under FreeBSD-Integration-Service git root directory"
     echo 1
     return
  fi
  if [ `echo "$git_root"|cut -c 1-4` == "/usr" ]
  then
     git_root=`echo "$git_root"|cut -c 5-`
  fi

  if [ `echo "$curr_pwd" | cut -c 1-4` == "/usr" ]
  then
     $curr_pwd=`echo "$curr_pwd" | cut -c 5-`
  fi
  #echo "$curr_pwd"
  if [ "$git_root" != "$curr_pwd" ]
  then
    #echo "Please run this script under git root directory"
    echo 1
    return
  fi
  echo 0
}

## @frbsd_rel_tgt="10_3|11_0"
push_branch_to_remote() {
  local frbsd_rel_tgt="$1"
  local working_dir=$(pwd_check)
  if [ "$working_dir" != "0" ]
  then
    echo "Please run this script under FreeBSD-Integration-Service git root directory"
    exit 1
  fi
  local rel_tgt_arr_prefix=${g_ci_prefix}${frbsd_rel_tgt}
  local rel_arr_nm=$(derefer_2vars ${rel_tgt_arr_prefix} ${g_ci_postfix})
  local dst_local_branch_prefix=$(array_get $rel_arr_nm 6 "|")
  local local_1=`git branch | awk '/^\*/{print $2}' | awk -F _ '{print $1}'`
  local local_2=`git branch | awk '/^\*/{print $2}' | awk -F _ '{print $2}'`
  local dst_local=${local_1}"_"${local_2}
  if [ "$dst_local_branch_prefix" != "$dst_local" ]
  then
     echo "The current branch '$dst_local' does not match you want to commit '$dst_local_branch_prefix'"
     exit 1
  fi
  local dst_local_branch=`git branch | awk '/^\*/{print $2}'`
  git push origin $dst_local_branch
  if [ $? -eq 0 ]
  then
    echo "Successfully push '$dst_local_branch' to github"
    exit 0
  else
    echo "Fail to push '$dst_local' to remote"
    exit 1
  fi
}

## @frbsd_rel_tgt="10_3|11_0"
## @expect_commits_file : specify the file location of commits
## @kernel_summary_file : specify the file location of summary ci
cherry_pick_for_frbsd() {
  local frbsd_rel_tgt="$1"
  local expect_commits_file=$2
  local kernel_summary_file=$3
  local rel_tgt_arr_prefix=${g_ci_prefix}${frbsd_rel_tgt}
  local rel_arr_nm=$(derefer_2vars ${rel_tgt_arr_prefix} ${g_ci_postfix})
  
  local first_ci
  local last_ci
  local log_file="cherry_pick_for_"${frbsd_rel_tgt}".log"
  local dst_branch=$(array_get $rel_arr_nm 1 "|")
  local src_branch=$(array_get $rel_arr_nm 2 "|")
  local patch_start_date=$(array_get $rel_arr_nm 3 "|")
  local date_4_rel=$(array_get $rel_arr_nm 4 "|")
  local dst_local_branch=$(array_get $rel_arr_nm 5 "|")

  local working_dir=$(pwd_check)
  if [ "$working_dir" != "0" ]
  then
    echo "Please run this script under FreeBSD-Integration-Service git root directory"
    return
  fi
  ## checkout the hyperv branch and find all the private patches
  git fetch --all
  git checkout $src_branch
  git log -E --author="$g_author_list" --pretty=format:"%H-%an-%ad-%s" --since=$patch_start_date  > $expect_commits_file
  ## checkout a brand-new local branch for releng
  #local isBranchExisted=`git branch | grep $dst_local_branch`
  #if [ "$isBranchExisted" != "" ]
  #then
  #   local currBranch=`git branch | awk '/^\*/{print $2}'`
  #   if [ $currBranch == $dst_local_branch ]
  #   then
  #      git reset --hard HEAD
  #      git checkout master
  #   fi
  #   git branch -D $dst_local_branch
  #fi
  git clean -d -x -f ## clean the working directory
  git checkout -f -b $dst_local_branch $dst_branch
  if [ -s $expect_commits_file ]
  then
    first_ci=`tail -n 1 $expect_commits_file|awk -F - '{print $1}'`
    last_ci=`head -n 1 $expect_commits_file|awk -F - '{print $1}'`
    echo "git cherry-pick ${first_ci}^..${last_ci} | tee /tmp/$log_file"
    git cherry-pick ${first_ci}^..${last_ci} | tee /tmp/$log_file
    egrep "^error:|^Fail" /tmp/$log_file
    if [ $? -ne 0 ]
    then
      git log --pretty=format:"%h-%an-%ad-%s" --since=$date_4_rel > $kernel_summary_file
    else
      echo "Fail to cherry-pick"
    fi
  else
    git log --pretty=format:"%h-%an-%ad-%s" --since=$date_4_rel > $kernel_summary_file
  fi
}

