# Lazy-Load Reference Documentation

## Performance Improvement #7: Lazy-load heavy reference docs

This file documents the strategy for lazy-loading reference documentation to reduce plugin payload size.

### Current Approach (High Payload)

Reference files like `api-reference.md` are bundled into each skill variant:
- `.plugins/integrate-jupiter/codex/skills/jupiter-vrfd/references/api-reference.md`
- `.plugins/integrate-jupiter/claude/skills/jupiter-vrfd/references/api-reference.md`

**Problem:** Each skill duplication increases distribution package size unnecessarily.

### New Approach (Optimized)

Store references centrally and use URL-based references in skill manifests:

1. **Single source of truth**
   - Keep API references in `references/` directory at repo root
   - Publish to documentation site (e.g., GitHub Pages, ReadTheDocs)

2. **Skill manifests reference via URL**
   ```json
   {
     "name": "jupiter-vrfd",
     "description": "Jupiter VRFD verification skill",
     "referenceUrl": "https://docs.example.com/api/jupiter-vrfd",
     "localReference": null
   }
   ```

3. **Fallback for local environments**
   ```json
   {
     "name": "jupiter-vrfd",
     "description": "Jupiter VRFD verification skill",
     "referenceUrl": "https://docs.example.com/api/jupiter-vrfd",
     "localReference": "./references/api-reference.md"
   }
   ```

### Implementation Strategy

1. **Phase 1: Add URL references to manifests**
   - Update skill `.mcp.json` files to include reference URLs
   - Keep local references as fallback

2. **Phase 2: Exclude references from distribution**
   - Add `references/` to `.plugignore`
   - Remove from plugin variant directories

3. **Phase 3: Monitor usage**
   - Track which references are accessed locally vs. via URL
   - Gradually move heavy docs to external sources

### Performance Impact

**Before:** 
- Each skill includes full reference docs
- Total plugin size: 2-5 MB

**After:**
- References hosted externally (1-2 MB saved per skill)
- Plugin size: ~500 KB
- Reduction: ~60-80%

### Compatibility Notes

- **Claude Code:** Can load resources via URLs
- **Codex:** Requires local resources or marketplace hosting
- **Fallback:** Local references remain available for offline use

### Files to Modify

- `SKILL.md` files: Document reference URL pattern
- `.mcp.json` manifests: Add `referenceUrl` and `localReference` fields
- `.plugignore`: Add `references/` to distribution exclusions
- `scripts/sync_plugin_skills.sh`: Already excludes via `.plugignore`

### Example: Jupiter VRFD Skill

**Before (bundled):**
```
.plugins/*/skills/jupiter-vrfd/
├── SKILL.md
├── README.md
├── references/
│   └── api-reference.md (heavy, 500KB)
├── examples/
└── .mcp.json
```

**After (lazy-loaded):**
```
.plugins/*/skills/jupiter-vrfd/
├── SKILL.md
├── README.md
├── .mcp.json  # Contains referenceUrl
└── examples/

# docs.example.com/api/jupiter-vrfd
# (external hosted reference)
```

### Migration Checklist

- [ ] Publish references to documentation site
- [ ] Update `.mcp.json` files with reference URLs
- [ ] Test URL fallbacks in development
- [ ] Add `references/` to `.plugignore`
- [ ] Measure payload size reduction
- [ ] Document for contributors

### Links

- GitHub issue for implementation
- Documentation site setup guide
- CI/CD integration for reference publishing
