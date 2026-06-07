# Phase 10 - DELETE Policies (USING)

## Objective

Understand how Row Level Security protects DELETE operations.

This phase demonstrates how PostgreSQL controls row deletion and clarifies why DELETE policies use USING instead of WITH CHECK.

## Background

Previous phases introduced:

```text

SELECT
→ USING

INSERT
→ WITH CHECK

UPDATE
→ USING + WITH CHECK

```

DELETE is the final CRUD operation and follows a different pattern.

Unlike UPDATE, DELETE does not produce a new version of a row.

The row simply ceases to exist.

## Initial Hypothesis

Before executing the experiment, the expectation was:

```text

DELETE operates on an existing row.

There is no resulting row after deletion.

Therefore:

USING should be relevant.

WITH CHECK should not.

```

However, before discussing policy behavior, PostgreSQL must first determine whether a DELETE policy exists.

## Experiment 1 - DELETE Without Permission

Attempt:

```sql

DELETE FROM patients
WHERE name = 'Carlos';

```

Result:

```text

ERROR:
permission denied for table patients

```

### Observation

PostgreSQL first validates table permissions.

RLS is not evaluated until the operation itself is permitted.

This reinforces:

```text

GRANT
and
RLS

are independent mechanisms.

```

## Experiment 2 - DELETE Permission Without Policy

Grant permission:

```sql

GRANT DELETE
ON patients
TO app_user;

```

Attempt deletion again:

```sql

DELETE FROM patients
WHERE name = 'Carlos';

```

Result:

```text

DELETE 0

```

Execution plan:

```sql

EXPLAIN ANALYZE
DELETE FROM patients
WHERE name = 'Carlos';

```

Result:

```text

Result
One-Time Filter: false

```

### Observation

This behavior matches previous experiments with UPDATE.

Even though DELETE permission existed, there was no DELETE policy.

Therefore:

```text

# Eligible rows for deletion

empty set

```

The operation completed successfully but affected zero rows.

## Current Policies

At this point the patients table contained:

```text

patients_by_tenant
→ SELECT

patients_insert_by_tenant
→ INSERT

patients_update_by_tenant
→ UPDATE

```

No DELETE policy existed.

## Experiment 3 - Attempt Incorrect Policy

Attempt:

```sql

CREATE POLICY patients_delete_by_tenant
ON patients
FOR DELETE
TO app_user
WITH CHECK (
tenant_id =
current_setting('app.tenant_id')::uuid
);

```

Result:

```text

ERROR:
WITH CHECK cannot be applied
to SELECT or DELETE

```

### Observation

This confirms an important PostgreSQL rule:

```text

DELETE policies
cannot use WITH CHECK

```

Because DELETE has no resulting row to validate.

## Create DELETE Policy

Create the correct policy:

```sql

CREATE POLICY patients_delete_by_tenant
ON patients
FOR DELETE
TO app_user
USING (
tenant_id =
current_setting('app.tenant_id')::uuid
);

```

### Observation

The policy evaluates the existing row before allowing deletion.

## Experiment 4 - Missing Session Variable

Attempt deletion without defining tenant context:

```sql

DELETE FROM patients
WHERE name = 'Carlos';

```

Result:

```text

ERROR:
unrecognized configuration parameter
"app.tenant_id"

```

### Observation

The policy was actively evaluated.

PostgreSQL attempted to resolve current_setting() and failed because the session variable was not defined.

## Experiment 5 - Successful Tenant-Aware Delete

Assume Tenant A:

```sql

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Execute:

```sql

DELETE FROM patients
WHERE name = 'Carlos';

```

Result:

```text

DELETE 1

```

The row was successfully removed.

## Execution Plan Analysis

Execution plan:

```sql

EXPLAIN ANALYZE
DELETE FROM patients
WHERE name = 'Carlos';

```

Result:

```text

Filter:
(name = 'Carlos')
AND
(tenant_id = current_setting(...))

```

### Observation

PostgreSQL injected the RLS predicate directly into the execution plan.

The DELETE operation only considered rows matching:

```text

Business condition:
name = 'Carlos'

AND

RLS condition:
tenant_id = current tenant

```

## Understanding DELETE Internally

DELETE only evaluates existing rows.

PostgreSQL effectively asks:

```text

Can this row be deleted?

```

Since there is no resulting row after deletion:

```text

WITH CHECK
is not applicable

```

Only USING is required.

## CRUD Policy Matrix

After completing all CRUD experiments:

| Operation | USING | WITH CHECK |
| --------- | ----- | ---------- |
| SELECT    | Yes   | No         |
| INSERT    | No    | Yes        |
| UPDATE    | Yes   | Yes        |
| DELETE    | Yes   | No         |

## Why This Makes Sense

### SELECT

Evaluates:

```text

Current row

```

### INSERT

Evaluates:

```text

New row

```

### UPDATE

Evaluates:

```text

Current row
and
new row

```

### DELETE

Evaluates:

```text

Current row

```

No new row exists after deletion.

## Real-World SaaS Perspective

This policy prevents users from deleting data belonging to another tenant.

Example:

```text

Tenant A
cannot delete
Tenant B records

```

Even if:

* Application validation fails.
* A bug exists in the API.
* A crafted request reaches the database.

PostgreSQL still enforces tenant ownership before deletion.

## Key Learnings

* DELETE requires its own RLS policy.
* GRANT DELETE alone is insufficient.
* DELETE without a policy affects zero rows.
* DELETE policies use USING.
* DELETE policies cannot use WITH CHECK.
* PostgreSQL injects RLS predicates directly into query execution plans.
* Tenant isolation applies equally to data removal operations.
* CRUD operations use different RLS mechanisms depending on whether a current row, future row, or both exist.

## Concepts Learned

```text

SELECT
USING

INSERT
WITH CHECK

UPDATE
USING + WITH CHECK

DELETE
USING

USING
validates existing rows

WITH CHECK
validates resulting rows

DELETE
has no resulting row

```

This phase completes the CRUD lifecycle under PostgreSQL Row Level Security and establishes a complete understanding of how RLS controls reading, creation, modification, and deletion of tenant data.
