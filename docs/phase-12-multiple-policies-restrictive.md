# Phase 12 - Restrictive Policies (AND Behavior)

## Objective

Understand how PostgreSQL combines PERMISSIVE and RESTRICTIVE Row Level Security policies.

This phase demonstrates the difference between:

```text

PERMISSIVE
→ OR behavior

RESTRICTIVE
→ AND behavior

```

and explains why PostgreSQL provides both policy types.

## Background

In the previous phase, two SELECT policies existed:

### Tenant Policy

```sql

CREATE POLICY patients_by_tenant
ON patients
FOR SELECT
TO app_user
USING (
tenant_id =
current_setting('app.tenant_id')::uuid
);

```

### Maria Policy

```sql

CREATE POLICY patients_maria_access
ON patients
FOR SELECT
TO app_user
USING (
name = 'Maria'
);

```

Both policies were PERMISSIVE.

The execution plan revealed:

```sql

tenant_policy
OR
maria_policy

```

Result:

```text

João Silva
Maria

```

Both rows became visible.

## Inspecting Existing Policies

Query:

```sql

SELECT
policyname,
permissive,
cmd
FROM pg_policies
WHERE tablename = 'patients'
ORDER BY policyname;

```

Result:

```text

        policyname         | permissive |  cmd   
---------------------------+------------+--------
 patients_by_tenant        | PERMISSIVE | SELECT
 patients_delete_by_tenant | PERMISSIVE | DELETE
 patients_insert_by_tenant | PERMISSIVE | INSERT
 patients_maria_access     | PERMISSIVE | SELECT
 patients_update_by_tenant | PERMISSIVE | UPDATE
(5 rows)

```

### Observation

Every policy created so far used PostgreSQL's default behavior:

```text

PERMISSIVE

```

## Initial Hypothesis

The expectation was:

```text

RESTRICTIVE

should behave like

AND

```

instead of:

```text

OR

```

If correct, combining:

```text

Tenant A policy

AND

name = 'Maria'

```

should return no rows.

## Replacing the Policy

Remove the PERMISSIVE version:

```sql

DROP POLICY patients_maria_access
ON patients;

```

Create a RESTRICTIVE version:

```sql

CREATE POLICY patients_maria_access
ON patients
AS RESTRICTIVE
FOR SELECT
TO app_user
USING (
name = 'Maria'
);

```

## Session Context

The session remained configured as Tenant A:

```sql

SET ROLE app_user;

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Available data:

| Tenant   | Name       |
| -------- | ---------- |
| Tenant A | João Silva |
| Tenant B | Maria      |

## Experiment

Execute:

```sql

SELECT *
FROM patients;

```

Result:

```text

0 rows

```

The query returned no visible data.

## Execution Plan Analysis

Execution plan:

```sql

EXPLAIN ANALYZE
SELECT *
FROM patients;

```

Result:

```sql

Filter:
(
(name = 'Maria')
AND
(
tenant_id =
current_setting('app.tenant_id')::uuid
)
)

```

### Observation

The execution plan explicitly shows:

```text

AND

```

instead of:

```text

OR

```

## Evaluating Each Row

### João Silva

Tenant policy:

```text

TRUE

```

Maria policy:

```text

FALSE

```

Evaluation:

```text

# TRUE AND FALSE

FALSE

```

Row hidden.

## Maria

Tenant policy:

```text

FALSE

```

Maria policy:

```text

TRUE

```

Evaluation:

```text

# FALSE AND TRUE

FALSE

```

Row hidden.

## Final Result

```text

No rows satisfy both conditions simultaneously.

```

Therefore:

```text

0 rows returned

```

## Understanding Policy Composition

This experiment reveals a fundamental PostgreSQL behavior.

Conceptually:

```text

PERMISSIVE policies
→ combined with OR

RESTRICTIVE policies
→ combined with AND

```

A useful mental model is:

```text

(All PERMISSIVE policies)
OR

(All other PERMISSIVE policies)

↓

Result

AND

(All RESTRICTIVE policies)

```

Which can be visualized as:

```text

(P1 OR P2 OR P3 ...)
AND
(R1 AND R2 AND R3 ...)

```

## Why RESTRICTIVE Exists

Without RESTRICTIVE policies, every additional policy would expand access.

Example:

```text

Tenant access

OR

Support access

OR

Special access

```

This is useful but not always sufficient.

Sometimes a system requires mandatory restrictions.

Examples:

```text

status = 'ACTIVE'

archived = false

deleted = false

```

These conditions should always be enforced.

RESTRICTIVE policies provide this capability.

## Real-World SaaS Example

Imagine:

### Tenant Access

```sql

tenant_id =
current_setting('app.tenant_id')::uuid

```

### Active Records Only

```sql

status = 'ACTIVE'

```

### Exclude Archived Data

```sql

archived = false

```

A possible design:

```text

PERMISSIVE
→ tenant policy

RESTRICTIVE
→ active status

RESTRICTIVE
→ archived = false

```

Effective behavior:

```sql

tenant_id = ...
AND status = 'ACTIVE'
AND archived = false

```

## Security Implications

This feature allows architects to separate:

### Access Paths

```text

Who can access data?

```

Handled through:

```text

PERMISSIVE policies

```

### Mandatory Constraints

```text

What data can never be accessed?

```

Handled through:

```text

RESTRICTIVE policies

```

This distinction is extremely valuable in multi-tenant SaaS platforms.

## Key Learnings

* PostgreSQL policies are PERMISSIVE by default.
* PERMISSIVE policies are combined using OR.
* RESTRICTIVE policies are combined using AND.
* Query execution plans expose policy composition behavior.
* RESTRICTIVE policies provide mandatory security constraints.
* Policy composition can dramatically alter data visibility.
* Understanding policy composition is essential for designing secure RLS architectures.

## Concepts Learned

```text

PERMISSIVE
→ OR

RESTRICTIVE
→ AND

Multiple PERMISSIVE policies
→ More access paths

Multiple RESTRICTIVE policies
→ More restrictions

Policy composition is explicit
inside PostgreSQL execution plans

```

This phase completes the understanding of policy composition and prepares the foundation for real-world authorization models involving:

```text

Tenant Users
Support Users
Administrators
Auditors

```

which are explored in the next phase.
