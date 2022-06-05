---
layout: post
title:  "How to sanity check post-`git rebase` conflicts"
date:   2021-05-06 00:49:23 +0200
categories: git
tags: git git-rebase git-diff
---
Have you ever been in a situation where you did a `git rebase`, was met with conflicts, resolved those and then wondered if you really did it correctly. Perhaps the conflicts were complex, or just plenty small ones that got you confused half-way through?

Most often you would rebase to either keep your branch on top of your main branch while developing, or had your PR reviewed, approved, and now you want to rebase on top of the main branch before merging to maintain a linear commit history. Also squashing of `squash` or `fixup` commits into their original commit could as well cause conflicts if you created those commits with not enough isolation to their diffs.

In those cases when you _do_ get conflicts you might've wondered if there is a way to sanity check and make sure you did things right, right?

Luckily there is!

For this scenario I'll assume you've pushed your branch to the remote, had a PR approved, successfully rebased your branch, resolved conflicts **but not yet force-pushed**:

> Below snippet, replace `your-branch-name-here` with the branch you've pushed to the remote and `main` with whatever you call your "main" branch.

```bash
git diff origin/your-branch-name-here..head -- $(git diff --name-only main...)
```

let's break it down

1. `git diff origin/your-branch-name-here..head` will diff against the origin version of your branch with any changes that exists on the tip of your current branch, `head`.
2. `--` separator to tell Git we will be providing filenames.
3. `$(...)` creates a sub-shell that'll output the result of the command within. We are using `--name-only` to retrieve a list of filenames and `main...` is just a shorthand for `main...head`.

    In other words we are getting all files that have been modified/added on the current tip of your branch against the "main" branch. This is important because we don't want to include any other files that weren't modified by us.
4. Now you'll see either 1) no diff running the above command, which is good and means whatever the state of the files on your remote branch are exactly the same on your local branch post-rebase and fixing conflicts!

    Alternatively if you 2) _do_ see diffs, check these, either other people have made changes to the same files you've been working on (and that's ok) _OR_ 3) you actually made a mistake and you would see it highlighted here for you to correct.
