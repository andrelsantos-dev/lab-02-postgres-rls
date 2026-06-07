# Phase 13 - Role-Specific Policies (Support User Access)

## Objective

Understand how Row Level Security policies are evaluated for different roles and verify that policies are not automatically shared across users.

This phase demonstrates one of the most important authorization concepts in PostgreSQL:

```text

Policies are not attached only to tables.

Policies are attached to:

Table
+
Operation
+
Role

```

This allows different users to have completely different visibility rules over the same data.

## Background

At the end of the previous phase, the patients table contained:

| Tenant   | Name       |
| -------- | ---------- |
| Tenant A | João Silva |
| Tenant B | Maria      |

The existing SELECT policies were:

### Tenant Isolation Policy

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

### Restrictive Maria Policy

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

For app_user, the effective filter became:

```sql

(name = 'Maria')
AND
(
tenant_id =
current_setting('app.tenant_id')::uuid
)

```

Result:

```text

No rows returned

```

because no record satisfied both conditions simultaneously.

## Initial Assumption

An important question emerged:

```text

Would the restrictive policy created for app_user
also affect other roles?

```

Initially, it was easy to assume that policies were global to the table.

However, inspecting pg_policies revealed otherwise.

## Inspecting Existing Policies

Query:

```sql

SELECT
policyname,
permissive,
roles,
cmd
FROM pg_policies
WHERE tablename = 'patients'
ORDER BY policyname;

```

Result:

```text

patients_by_tenant
→ roles = {app_user,migration_user}

patients_maria_access
→ roles = {app_user}

patients_insert_by_tenant
→ roles = {app_user}

patients_update_by_tenant
→ roles = {app_user}

patients_delete_by_tenant
→ roles = {app_user}

```

### Observation

The restrictive policy was associated only with:

```text

app_user

```

and not with every database role.

This suggested that different roles could have entirely different RLS behavior.

## Creating a Support Role

Create the role:

```sql

CREATE ROLE support_user;

```

Grant table access:

```sql

GRANT SELECT
ON patients
TO support_user;

```

### Observation

As demonstrated throughout the lab:

```text

GRANT
≠
Policy

```

Both are required.

The grant allows access to the table.

The policy determines which rows are visible.

## Creating a Support Policy

Create a dedicated policy:

```sql

CREATE POLICY patients_support_access
ON patients
FOR SELECT
TO support_user
USING (
true
);

```

### Policy Meaning

The condition:

```sql

USING (true)

```

always evaluates to TRUE.

Conceptually:

```text

Every row is visible

```

for the support_user role.

## Testing the Role

Switch to the role:

```sql

SET ROLE support_user;

```

Execute:

```sql

SELECT *
FROM patients;

```

Result:

```text

Maria
João Silva

```

All rows became visible.

## Execution Plan Analysis

Query:

```sql

EXPLAIN ANALYZE
SELECT *
FROM patients;

```

Result:

```sql

Seq Scan on patients

```

No filter was generated.

### Observation

Unlike previous phases, PostgreSQL did not inject any RLS filter.

Examples from earlier phases:

```sql

Filter:
(
tenant_id =
current_setting(...)
)

```

or

```sql

Filter:
(
name = 'Maria'
)
AND
(
tenant_id =
current_setting(...)
)

```

In this case no filter appeared.

## Why No Filter Appeared

The active policy was:

```sql

USING (true)

```

The optimizer recognized:

```text

TRUE

```

for every row.

Therefore:

```text

No filtering is required

```

and PostgreSQL performed a normal sequential scan.

## Important Discovery

The restrictive policy:

```sql

patients_maria_access

```

did not affect support_user.

Why?

Because it was created for:

```sql

TO app_user

```

and not:

```sql

TO support_user

```

PostgreSQL evaluated only the policies applicable to the current role.

## Effective Policies by Role

### app_user

Relevant policies:

```text

patients_by_tenant
patients_maria_access

```

Effective behavior:

```text

Tenant restriction
AND
Maria restriction

```

### support_user

Relevant policies:

```text

patients_support_access

```

Effective behavior:

```text

TRUE

```

Result:

```text

Full visibility

```

## Real-World SaaS Interpretation

This is a common SaaS authorization pattern.

### Customer User

```text

Only sees data from their own tenant

```

### Support User

```text

Can view all tenants

```

### Auditor User

```text

Can view all tenants
but cannot modify data

```

### Administrator

```text

Can manage all records

```

All implemented through:

```text

Different roles
+
Different policies

```

without disabling RLS.

## Why This Is Better Than BYPASSRLS

Using:

```sql

ALTER ROLE support_user
BYPASSRLS;

```

would bypass every policy in the database.

Instead:

```sql

USING (true)

```

maintains:

```text

RLS enabled
Policies active
Explicit access control

```

while still providing full visibility.

This is usually a safer and more auditable design.

## Key Learnings

* Policies are associated with specific roles.
* Different roles can have completely different visibility rules.
* A policy created for one role does not automatically affect another role.
* USING (true) provides full visibility while keeping RLS enabled.
* PostgreSQL evaluates only policies relevant to the current role.
* Role-specific policies are a powerful way to model SaaS authorization.
* Full access does not require BYPASSRLS.

## Concepts Learned

```text

Table
+
Operation
+
Role
====

Policy Scope

app_user
→ Tenant isolation

support_user
→ Full visibility

Same table
Different authorization model

USING (true)
→ Full access with RLS still enabled

```

This phase demonstrates how PostgreSQL RLS can be used to implement multiple access profiles over the same dataset while maintaining centralized authorization rules inside the database.
