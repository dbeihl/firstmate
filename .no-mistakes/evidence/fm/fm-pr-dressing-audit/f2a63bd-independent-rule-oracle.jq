# Independent re-statement of the documented rules (docs/configuration.md), written without the audit's jq.
def failing: (.__typename=="CheckRun" and .status=="COMPLETED" and ([.conclusion]|inside(["FAILURE","TIMED_OUT","CANCELLED","ACTION_REQUIRED","STARTUP_FAILURE"])))
          or (.__typename=="StatusContext" and ([.state]|inside(["FAILURE","ERROR"])));
def nm: (.name // .context);
[.[].data.repository.pullRequests.nodes[]] as $prs
| $cfg.repositories | to_entries[0].value as $r
| $prs[] as $p
| (if $p.baseRefName=="main" and $r.integration_branch!="main" and (($p.headRefName==$r.integration_branch and ($p.isCrossRepository|not))|not)
   then "\($p.url): base branch is main; expected \($r.integration_branch)" else empty end),
  (([$p.reviewRequests.nodes[].requestedReviewer|objects|select(.__typename=="Team").combinedSlug] + [$p.reviews.nodes[].onBehalfOf.nodes[].combinedSlug]) as $t
   | if ($t|any(.==$r.reviewer_team)) then empty else "\($p.url): reviewer team missing: \($r.reviewer_team)" end),
  ([$r.assignees[] as $a | select([$p.assignees.nodes[].login]|any(.==$a)|not) | $a] | select(length>0) | "\($p.url): assignees missing: \(join(", "))"),
  (if $p.mergeable=="CONFLICTING" then "\($p.url): mergeable is CONFLICTING, not MERGEABLE" else empty end),
  ($r.required_checks[] as $req
   | [($p.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // [])[] | select(nm==$req)]
   | reduce .[] as $x ({}; ($x.checkSuite.workflowRun.workflow.name|tostring) as $k | if (.[$k]==null or (.[$k].startedAt // "") <= ($x.startedAt // "")) then .[$k]=$x else . end)
   | if ([.[]|failing]|any) then "\($p.url): required check failing: \($req)" else empty end)
