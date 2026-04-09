# API Development Conventions

> API documentation lookup, change tracking, and development standards.
> Shared across all platforms.

---

## API Documentation Locations

| Source | Path | Description |
|--------|------|-------------|
| Swagger JSON | `{api_doc_path}/*.json` | Raw API definitions (git submodule, read-only) |
| Backend tasks | `{specs}/{version}/tasks/backend.md` | Backend API status + non-Swagger endpoint details |
| Feature YAML | `{specs}/{version}/features/F{nn}-*.yaml` | Per-feature endpoint references |
| Tech docs | `{api_doc_path}/tec_docs/` | Backend design docs + analytics specifications |

`{api_doc_path}` is configured in `.claude/config.yaml` as `api_doc.path`.

---

## API Source Priority

During development, use this priority for API truth:

```
1. Swagger JSON files        <- authoritative for endpoint schema
2. backend.md                <- authoritative for non-Swagger endpoints and status
3. Feature YAML api[]        <- reference only, may contain assumptions from PRD
```

When discrepancies exist between sources:
- Swagger/backend.md wins over Feature YAML assumptions
- Record discrepancies in task tech notes
- Flag for spec update if the gap is significant

---

## API Contract Verify Flow

Run this during the Check phase of task execution:

```yaml
step_1_identify_endpoints:
  - Read task detail API table
  - For each endpoint, note the source:
    - "swagger:{file}" -> verify against Swagger JSON
    - "backend.md#B{nn}" -> verify against backend.md
    - "TBD" -> warn, do not block

step_2_swagger_verify:
  for each Swagger endpoint:
    a. Locate file: {api_doc_path}/{service}_swagger.json
    b. Find endpoint definition by path
    c. Verify request params:
       - Field names match
       - Types match
       - Required/optional alignment
    d. Verify response fields:
       - Fields the task logic depends on exist
       - Types match expectations
    e. Verify enums:
       - Referenced status values are defined

step_3_backend_md_verify:
  for each non-Swagger endpoint:
    a. Read backend.md #{B{nn}} section
    b. Verify param tables match task expectations
    c. Note any missing documentation

step_4_report:
  - All pass -> "API contract verified"
  - Discrepancies -> output table:
    | Endpoint | Field | Expected | Actual | Action |
    |----------|-------|----------|--------|--------|
  - Missing endpoints -> warn, write to task tech notes (marked missing)
  - Does NOT block execution unless critical field is missing
```

---

## Change Tracking

### Detecting API Changes

```bash
# Check for API doc updates (submodule or directory)
cd {api_doc_path} && git fetch && git status

# See what changed
git diff HEAD~1 --name-only -- "*.json"

# View specific changes
git diff HEAD~1 -- {changed_file}.json
```

### When to Check for API Changes

Trigger API change check when:
- Starting a task that involves network requests
- Debugging API integration issues
- User explicitly mentions API changes
- Before API Contract Verify step

### Change Analysis Requirements

When changes are detected, analyze thoroughly:

```yaml
for each changed Swagger file:
  1. Identify: new endpoints, modified endpoints, removed endpoints
  2. Track data structure references:
     - If a definition/model changed, find ALL endpoints referencing it
     - All referencing endpoints must be noted in the changelog
  3. Record: field names, types, value ranges, defaults
  4. Map to features: use dependency_index to identify affected Feature YAMLs
```

---

## Changelog Format

Record API changes in the project's API changelog:

```markdown
### [YYYY-MM-DD] Change Title

#### Added
- `POST /path/to/endpoint` - Feature description
  - Key params: {param_name} ({type}, {required/optional})
  - Response: {key_response_fields}

#### Changed
- `POST /path/to/endpoint` - Change description
  - Before: {old_behavior}
  - After: {new_behavior}
  - Affected fields: {field_list}

#### Deprecated
- `POST /path/to/endpoint` - Replacement: {new_endpoint}

#### Removed
- `POST /path/to/endpoint` - Removed in this version
```

### Changelog Rules

- Every changed Swagger file must be analyzed and recorded -- no omissions
- New endpoints: full path + description + key params
- Param changes: specific field name, type, value range, default
- Endpoint replacement: explicit old -> new mapping
- Data structure changes: list ALL affected endpoints
- No changes detected -> no action (do not create empty changelog entries)

---

## API Call Patterns

### Common Response Structure

Most APIs follow this pattern (verify against actual Swagger):

```json
{
  "code": 1,
  "msg": "success",
  "data": { ... }
}
```

Error handling should check `code` field and handle non-success cases.

### Platform-Specific Notes

- **iOS**: Use the project's established network layer protocol pattern
- **Android**: Use the project's established network layer pattern
- **Web**: Use the project's established HTTP client pattern

Always follow the existing codebase's API call conventions rather than inventing new patterns.

---

## Swagger File Reference

Swagger files follow OpenAPI 2.0/3.0 format. Key sections:

```
paths:       -> endpoint definitions
definitions: -> data model schemas (OpenAPI 2.0)
components:  -> data model schemas (OpenAPI 3.0)
parameters:  -> shared parameter definitions
```

### Reading a Swagger Endpoint

```yaml
locate:
  1. Open {service}_swagger.json
  2. Navigate to paths["/api/path"]
  3. Read method definition (post/get/put/delete)

extract:
  - parameters: name, type, required, description
  - responses.200.schema: response structure
  - $ref references: follow to definitions/components for full schema
```

---

## Integration Checklist

Before marking an API-dependent task as done:

```
[ ] All endpoints verified against Swagger/backend.md
[ ] Request params match API docs (field names, types)
[ ] Response handling covers all documented fields
[ ] Error cases handled (network error, API error codes)
[ ] Enum values match API definitions
[ ] Pagination handled if applicable
[ ] Auth headers included where required
[ ] Discrepancies (if any) recorded in task tech notes
```
