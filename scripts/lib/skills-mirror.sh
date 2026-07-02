#!/usr/bin/env bash
#
# lib/skills-mirror.sh — single source of truth for mirroring commands as
# .claude/skills/<name>/SKILL.md, so slash commands appear in the Claude Code
# VSCode autocomplete as discoverable skills. Source-able (no execution on its own).
#
#   usage:  . scripts/lib/skills-mirror.sh
#
# WHY this file exists (closes bootstrap/sync skills-drift class):
#   sync-methodology.sh generated this mirror unconditionally on every run;
#   new-project-init.sh had no equivalent step at all — a freshly bootstrapped
#   project had zero command-skills until its first sync-methodology.sh run.
#   Copy-pasting the block into new-project-init.sh would have duplicated the
#   mechanism a second time (inject_md_banner / inject_skill_banner are already
#   duplicated between the two scripts) — this file is the structural fix so
#   both callers share one implementation instead of drifting independently.
#
# bash 3.2 compatible (Git Bash on Windows): no associative arrays, no ${var,,}.

# inject_cmd_as_skill: deliver a command as a .claude/skills/<name>/SKILL.md so it
# appears in the Claude Code VSCode autocomplete as a slash command. Strips the
# command's own frontmatter (lines 1-N up to and including closing ---) to avoid
# duplicate frontmatter, then prepends a minimal skill frontmatter. The description
# deliberately avoids trigger keywords to prevent auto-activation.
inject_cmd_as_skill() {
  local src="$1"
  local dest="$2"
  local name
  name="$(basename "$src" .md)"
  local title
  title="$(grep -m1 '^# ' "$src" | sed 's|^# /[^ ]* — ||; s|^# ||')"
  [[ -z "$title" ]] && title="$name"
  title="${title//\"/}"
  # Find the first line AFTER the closing --- of the frontmatter block
  local body_start
  body_start="$(awk 'NR==1 && /^---/{found=1; next} found && /^---/{print NR+1; exit}' "$src")"
  [[ -z "$body_start" ]] && body_start=1
  {
    cat <<EOF
---
name: $name
description: "Slash command /$name — $title. Вызывать явно. Не активировать автоматически."
---
EOF
    tail -n +"$body_start" "$src"
  } > "$dest"
}

# generate_command_skills: mirror every command in $2/commands/*.md (and, when
# $3 == true, $2/commands-local/*.md) to $1/.claude/skills/<name>/SKILL.md.
#
# Usage: generate_command_skills <target_dir> <methodology_dir> <include_local_cmds>
#
# Caller-provided hook: if the calling script defines a `_track_changed`
# function (sync-methodology.sh does, for --print-changed manifest tracking),
# it is invoked per written file. Callers without it (new-project-init.sh) are
# unaffected — the check is a plain `declare -f` guard, not a hard dependency.
generate_command_skills() {
  local target_dir="$1"
  local methodology_dir="$2"
  local include_local_cmds="${3:-false}"

  echo "→ skills/ (commands mirror)"
  local cmd name skill_dir
  for cmd in "$methodology_dir"/commands/*.md; do
    [[ -f "$cmd" ]] || continue
    name="$(basename "$cmd" .md)"
    skill_dir="$target_dir/.claude/skills/$name"
    mkdir -p "$skill_dir"
    inject_cmd_as_skill "$cmd" "$skill_dir/SKILL.md"
    if declare -f _track_changed >/dev/null 2>&1; then
      _track_changed ".claude/skills/$name/SKILL.md"
    fi
    echo "  ✓ $name/SKILL.md"
  done

  if [[ "$include_local_cmds" == "true" ]] && [[ -d "$methodology_dir/commands-local" ]]; then
    for cmd in "$methodology_dir"/commands-local/*.md; do
      [[ -f "$cmd" ]] || continue
      name="$(basename "$cmd" .md)"
      skill_dir="$target_dir/.claude/skills/$name"
      mkdir -p "$skill_dir"
      inject_cmd_as_skill "$cmd" "$skill_dir/SKILL.md"
      if declare -f _track_changed >/dev/null 2>&1; then
        _track_changed ".claude/skills/$name/SKILL.md"
      fi
      echo "  ✓ $name/SKILL.md (local)"
    done
  fi
}
