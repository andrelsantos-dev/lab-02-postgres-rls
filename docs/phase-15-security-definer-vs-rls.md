# Phase 15 - SECURITY DEFINER vs Row Level Security

## Objective

Understand how PostgreSQL executes functions under different security contexts and verify the impact on Row Level Security (RLS).

This phase demonstrates one of the most important security concepts in PostgreSQL:

```text

RLS protects queries.

SECURITY DEFINER can change
who is executing the query.

```

## Background

At this point in the lab:

### patients

| Tenant   | Name       |
| -------- | ---------- |
| Tenant A | João Silva |
| Tenant B | Maria      |

### Active Policy

```sql

CREATE POLICY patients_by_tenant
ON patients
FOR SELECT
TO app_user, migration_user
USING (
tenant_id =
current_setting('app.tenant_id')::uuid
);

```

### Current Session

```sql

SET ROLE app_user;

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Direct query:

```sql

SELECT *
FROM patients;

```

Result:

```text

João Silva

```

Only Tenant A was visible.

## Part 1 - SECURITY INVOKER (Default Behavior)

Create a function:

```sql

CREATE OR REPLACE FUNCTION get_patients_invoker()
RETURNS TABLE (
id uuid,
tenant_id uuid,
name varchar
)
LANGUAGE sql
AS $$
SELECT
p.id,
p.tenant_id,
p.name
FROM patients p;
$$;

```

Grant execution:

```sql

GRANT EXECUTE
ON FUNCTION get_patients_invoker()
TO app_user;

```

### Hypothesis

Even though the function was created by postgres, the expectation was:

```text

The function executes as the caller.

```

Therefore:

```text

RLS should continue to apply.

```

## Testing

Execute:

```sql

SELECT *
FROM get_patients_invoker();

```

Result:

```text

João Silva

```

Exactly the same result obtained from a direct query.

### Execution Plan

```sql

EXPLAIN ANALYZE
SELECT *
FROM get_patients_invoker();

```

Result:

```sql

Function Scan on get_patients_invoker

```

### Observation

The execution plan does not expose the internal query plan.

However, the returned data proved that RLS remained active.

## Conclusion

The default behavior is effectively:

```text

SECURITY INVOKER

```

Meaning:

```text

# Caller

Executor

```

The function executes using the privileges and restrictions of the role that invoked it.

## Part 2 - SECURITY DEFINER

Create a second function:

```sql

CREATE OR REPLACE FUNCTION get_patients_definer()
RETURNS TABLE (
id uuid,
tenant_id uuid,
name varchar
)
LANGUAGE sql
SECURITY DEFINER
AS $$
SELECT
p.id,
p.tenant_id,
p.name
FROM patients p;
$$;

```

Grant execution:

```sql

GRANT EXECUTE
ON FUNCTION get_patients_definer()
TO app_user;

```

## Hypothesis

Because the function is marked as:

```sql

SECURITY DEFINER

```

the expectation became:

```text

The function executes using the privileges
of its owner.

```

Since the owner is:

```text

postgres

```

and postgres possesses:

```text

BYPASSRLS

```

it was expected that RLS might be ignored.

## Testing

Execute:

```sql

SELECT *
FROM get_patients_definer();

```

Result:

```text

Maria
João Silva

```

Both tenants became visible.

### Observation

The session was still:

```sql

SET ROLE app_user;

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

The policy still existed.

RLS was still enabled.

Yet both tenants were returned.

## What Happened?

Conceptually:

```text

app_user
↓
calls function
↓
SECURITY DEFINER
↓
assume identity of function owner
↓
postgres
↓
BYPASSRLS
↓
query executes without RLS filters

```

## Execution Plan

```sql

EXPLAIN ANALYZE
SELECT *
FROM get_patients_definer();

```

Result:

```sql

Function Scan on get_patients_definer

```

Again, PostgreSQL does not expose the internal query plan.

The evidence comes from the returned dataset.

## Relationship With Previous Phases

Earlier we learned:

### FORCE RLS

```sql

ALTER TABLE patients
FORCE ROW LEVEL SECURITY;

```

Forces even the table owner to obey RLS.

### BYPASSRLS

A role with:

```text

BYPASSRLS

```

ignores policies entirely.

## New Discovery

This phase revealed another path:

```text

SECURITY DEFINER
↓
execute as owner
↓
owner has BYPASSRLS
↓
RLS bypassed

```

## Why This Is Dangerous

Imagine a Spring Boot API:

```java

```GetMapping("/patients")
public List<PatientDto> listPatients() {
return repository.findPatients();
}

```

Repository:

```sql

SELECT *
FROM get_patients_definer();

```

The developer may believe:

```text

The database uses RLS.
Therefore tenant isolation is guaranteed.

```

However:

```text

Every authenticated user
executes the function
as postgres.

```

Result:

```text

Cross-tenant data exposure.

```

## Real Security Risk

This type of vulnerability is often harder to detect than:

```text

BYPASSRLS

```

because:

```sql

\du

```

might show:

```text

app_user
without BYPASSRLS

```

making the system appear secure.

The bypass is hidden inside the function definition.

## Key Learnings

* SECURITY INVOKER executes using the caller's privileges.
* SECURITY DEFINER executes using the owner's privileges.
* RLS protects queries, not function calls.
* SECURITY DEFINER can completely change the security context.
* Functions owned by superusers can bypass tenant isolation.
* SECURITY DEFINER must be used carefully in multi-tenant systems.
* Auditing functions is as important as auditing roles and policies.

## Concepts Learned

```text

# SECURITY INVOKER

Execute as caller

# SECURITY DEFINER

Execute as owner

RLS
+
SECURITY INVOKER
================

Tenant isolation preserved

RLS
+
SECURITY DEFINER
+
BYPASSRLS owner
===============

Tenant isolation bypassed

```

This phase demonstrates one of the most important security lessons in PostgreSQL:

```text

A secure RLS configuration can still be compromised
if SECURITY DEFINER functions are not carefully reviewed.

```
