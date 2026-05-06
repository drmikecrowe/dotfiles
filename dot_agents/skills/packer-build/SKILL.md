---
name: packer-build
description: Bake the app-host AMI via Packer with background execution, RTK error scanning, singleton enforcement, and early failure detection. Use when asked to "build the AMI", "bake the AMI", "run packer", "packer build", "rebuild the image", or "bake app-host".
---

<essential_principles>
## What This Skill Does

Runs `mise run packer` (which stages build context + builds AMI + validates result) in the background, monitors the output log for errors in real-time using RTK, enforces at most one concurrent build, and surfaces failures the moment they appear.

## Core Constraints

1. **Singleton**: Only one Packer build at a time. If a build is already running, report its status — never start a second.
2. **Background**: Build runs via `async_bash`. Agent stays responsive.
3. **Early failure detection**: Tail the log file with `rtk log` every 15-30s. Surface errors immediately — don't wait for the job to finish.
4. **Log discipline**: Output goes to a dated log file under `.logs/`. The same file is the monitor target.
5. **Failure = stop**: On build failure, report the error with context and stop. Do not retry without user instruction.

## Error Patterns to Watch

These Packer/provisioner errors indicate build failure:
- `Build 'amazon-ebs' errored` — Packer top-level failure
- `provisioner ... error` — provisioner script failed
- `ERROR:` — bake.sh explicit errors
- `exit status 1` — shell provisioner non-zero exit
- `timeout waiting for SSH` — instance unreachable
- `No default VPC` / `InsufficientInstanceCapacity` — AWS infrastructure errors
- `InvalidAMIID.NotFound` — source AMI issue
- `docker: ... ERROR` — Docker build failures inside bake.sh
- `Image count:` followed by count < 7 — image verification failure in bake.sh

## Lock File

Uses `.packer-build.lock` in the project root. Contains the job ID and log path. Cleaned up on build completion or explicit cancel.

## Mise Task

The underlying command is `mise run packer` which:
1. Stages build context (`packer/stage-build-context.sh`)
2. Runs `packer build packer/`
3. Validates the baked AMI (`packer/scripts/validate-ami.sh`)
</essential_principles>

<process>
## Step 1: Check for Running Build

Read `.packer-build.lock` if it exists. If a build is running:

```
job_id=$(cat .packer-build.lock | jq -r .job_id)
# Check if job is still active via await_job
```

If active: report current status (running time, last RTK scan result). Ask user whether to wait, cancel, or check again.
If stale (job no longer exists): remove lock file, proceed.

## Step 2: Prepare

```bash
# Create log directory
D=$(date -u +%Y-%m-%d)
mkdir -p ".logs/$D"

# Log file path
LOG_FILE=".logs/$D/packer-$(date -u +%Y-%m-%dT%H-%M-%SZ).log"
```

## Step 3: Launch Build

```bash
# Stage context + build in one shot via mise
async_bash(
  command="mise run packer 2>&1 | tee ${LOG_FILE}",
  label="packer-build",
  timeout=1200  # 20 minutes — Packer builds take 5-15 min
)
```

Immediately write lock file:
```bash
echo "{\"job_id\":\"${JOB_ID}\",\"log_file\":\"${LOG_FILE}\",\"started\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > .packer-build.lock
```

Report: "Packer build started. Job ${JOB_ID}. Log: ${LOG_FILE}"

## Step 4: Monitor Loop

While job is running, poll the log every 20-30 seconds:

```bash
# Scan for errors
rtk log "${LOG_FILE}" 2>/dev/null | tail -50
```

Also check for specific failure patterns:
```bash
# Direct grep for hard failures
rg -i 'errored|ERROR:|exit status [1-9]|Build.*errored|InsufficientInstanceCapacity|timeout waiting' "${LOG_FILE}" 2>/dev/null | tail -10
```

**On error detected:**
1. Read surrounding context (20 lines before/after the error)
2. Report the error with file:line reference
3. Check if the job has actually finished (it may still be running uselessly)
4. If job still running: cancel it via `cancel_job`
5. Clean up lock file
6. Present error to user with suggested fix

**On no error:** Report brief progress status ("Build running... X minutes elapsed. Last line: [truncated last line]")

## Step 5: Completion

When `await_job` returns:

**Success (exit 0):**
1. Extract AMI ID from the log: `rg 'ami-[a-z0-9]+' "${LOG_FILE}" | tail -1`
2. Report success with AMI ID and log path
3. Clean up lock file
4. Present next-step options

**Failure (non-zero exit):**
1. Run final RTK scan: `rtk log "${LOG_FILE}"`
2. Read the last 50 lines of the log for context
3. Clean up lock file
4. Present error summary with root cause if identifiable

## Step 6: Lock Cleanup

Always clean up `.packer-build.lock` when:
- Build completes (success or failure)
- Build is cancelled
- User explicitly requests cleanup
</process>

<quick_start>
1. Check `.packer-build.lock` — if build running, report status
2. Launch `mise run packer` via `async_bash`, tee output to `.logs/$D/packer-*.log`
3. Write `.packer-build.lock` with job ID + log path
4. Poll log with `rtk log $LOG_FILE` every 20-30s while job runs
5. Grep for error patterns on each poll — surface immediately if found
6. On completion: report AMI ID (success) or error summary (failure)
7. Clean up lock file
</quick_start>

<success_criteria>
- Build ran in background via async_bash
- Only one build at a time (lock enforced)
- Errors surfaced within 30 seconds of appearing in the log
- AMI ID reported on success
- Error summary with root cause on failure
- Lock file cleaned up
</success_criteria>
