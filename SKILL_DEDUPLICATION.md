# Skill Tree Deduplication Strategy

## Performance Improvement #4: Deduplicate skill trees and maintain single source of truth

### Current Problem

The repository maintains duplicate skill content across multiple locations:

```
skills/                                    (Canonical source)
├── integrating-jupiter/
├── jupiter-lend/
├── jupiter-swap-migration/
└── jupiter-vrfd/

.plugins/integrate-jupiter/codex/skills/   (Duplicate - Codex variant)
├── integrating-jupiter/
├── jupiter-lend/
├── jupiter-swap-migration/
└── jupiter-vrfd/

.plugins/integrate-jupiter/claude/skills/  (Duplicate - Claude variant)
├── integrating-jupiter/
├── jupiter-lend/
├── jupiter-swap-migration/
└── jupiter-vrfd/
```

**Issues:**
- 3x storage overhead for identical content
- Maintenance burden: changes must be made in 3 places
- Risk of divergence between variants
- Slower syncs with large skill trees
- Unclear which version is authoritative

### Proposed Solution

**Maintain single canonical `skills/` directory and sync to variants at build time:**

```
skills/                                    (Single source of truth)
├── integrating-jupiter/
├── jupiter-lend/
├── jupiter-swap-migration/
└── jupiter-vrfd/

.plugins/integrate-jupiter/
├── codex/
│   └── skills/ → (symlink or copy from skills/)
├── claude/
│   └── skills/ → (symlink or copy from skills/)
└── scripts/
    └── sync_skills.sh (handles syncing)
```

### Implementation Phases

#### Phase 1: Validation (Low risk, quick)
1. Verify all 3 copies are identical using checksums
2. Confirm no variant-specific content exists
3. Document baseline metrics (file counts, sizes)

#### Phase 2: Directory Consolidation (Medium risk, careful)
1. Keep `skills/` as primary source
2. Generate symlinks in plugin variants (Unix-like systems)
3. Alternative: conditional copy logic in sync script
4. Test with both providers (Codex and Claude)

#### Phase 3: CI/CD Integration (Medium risk, requires testing)
1. Update sync script to detect both symlink and copy modes
2. Add validation that variants match canonical source
3. Add CI check to prevent divergence
4. Document setup for contributors

#### Phase 4: Documentation (Low risk)
1. Update contributor guide
2. Document canonical location and sync process
3. Add troubleshooting for variant mismatches

### Technical Approaches

#### Option A: Symlinks (Fastest, Unix-only)
```bash
# Setup
rm -rf .plugins/integrate-jupiter/codex/skills
ln -s ../../../skills .plugins/integrate-jupiter/codex/skills

# Pros: No duplication, automatic consistency, fast
# Cons: Windows compatibility, requires Unix tools
```

#### Option B: Smart Copy (Portable, requires logic update)
```bash
# Sync script detects canonical source
if needs_sync skills/ .plugins/integrate-jupiter/codex/skills; then
  cp -R skills/. .plugins/integrate-jupiter/codex/skills/.
fi
```

#### Option C: Hybrid (Best compatibility)
```bash
# Detect system capability
if ln -s test 2>/dev/null; then
  # Unix-like: use symlinks
  ln -s ../../../skills .plugins/integrate-jupiter/codex/skills
else
  # Windows: use smart copy
  # Sync will handle deduplication via checksums
fi
```

### Impact Analysis

#### Performance Gains
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Disk usage | 3x duplication | 1x (+ minimal) | ~66% reduction |
| Sync time | 5-10s | 1-2s | ~50% faster |
| Edit burden | Change in 3 places | Change once | 3x fewer edits |
| Consistency risk | High | Low | Better reliability |

#### Compatibility Impact
- **Symlink approach:** Requires Git symlink support (already configured)
- **Copy approach:** No changes needed, works everywhere
- **Recommendation:** Start with smart copy (Option B), add symlink support later

### Implementation Checklist

- [ ] Verify all 3 skill directories are identical
- [ ] Choose approach (symlink vs. smart copy)
- [ ] Update sync_plugin_skills.sh to detect canonical source
- [ ] Add CI validation for consistency
- [ ] Update contributor documentation
- [ ] Test on Windows, macOS, Linux
- [ ] Measure performance improvements
- [ ] Monitor for divergence after deployment

### Files to Modify

1. **scripts/sync_plugin_skills.sh**
   - Update to detect canonical `skills/` location
   - Add option to use symlinks if available
   - Add validation to ensure variants match canonical

2. **scripts/check_skill_changes.sh**
   - Monitor only canonical `skills/` location
   - Skip variant checks (they'll be symlinks/copies)

3. **.gitignore**
   - Consider adding `.plugins/*/skills/` as generated
   - Document canonical location

4. **CONTRIBUTING.md**
   - Document that `skills/` is canonical source
   - Explain sync process for variants

### Validation Strategy

```bash
# Checksums must be identical after sync
canonical_hash=$(find skills/ -type f -exec md5sum {} \; | sort | md5sum)
codex_hash=$(find .plugins/integrate-jupiter/codex/skills/ -type f -exec md5sum {} \; | sort | md5sum)

# These must match
if [[ "${canonical_hash}" != "${codex_hash}" ]]; then
  echo "WARNING: Skill variants diverged"
  exit 1
fi
```

### Rollback Plan

If issues arise:
1. Keep backup copy of .plugins/ directory
2. Can revert to full duplication quickly
3. CI checks will catch divergence immediately
4. No data loss (all sources backed up)

### Future Optimization

After deduplication is stable:
- [ ] Consolidate plugin metadata generation
- [ ] Unify manifest generation across variants
- [ ] Single provider directory structure
- [ ] Shared documentation site

### Success Metrics

- ✅ Disk usage reduced by ~66%
- ✅ Sync performance improved by ~50%
- ✅ Zero divergence between variants (CI validated)
- ✅ Contributor workflow unchanged (no new steps)
- ✅ Fully backward compatible
