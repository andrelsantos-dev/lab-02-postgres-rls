# Phase 08 - INSERT Policies (WITH CHECK)

## Objective

Understand how Row Level Security protects write operations through INSERT policies.

This phase introduces the WITH CHECK clause and demonstrates how PostgreSQL validates new rows before allowing them to be inserted.

## Background

Previous phases focused on read isolation using:

```sql

USING (...)

```

The USING clause answers:

```

Can this row be viewed?

```

However, reading and writing are independent operations.

Even if a role can read rows, PostgreSQL must also decide whether it can create new rows.

For INSERT operations, PostgreSQL uses:

```sql

WITH CHECK (...)

```

The WITH CHECK clause answers:

```

Can this row be created?

```

## Existing Policy

The patients table already contained a SELECT policy:

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

This policy only protects read operations.

## Experiment 1 - Attempt INSERT without Policy

Grant INSERT permission:

```sql

GRANT INSERT
ON patients
TO app_user;

```

Assume Tenant A:

```sql

SET ROLE app_user;

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Attempt insertion:

```sql

INSERT INTO patients (
tenant_id,
name
)
VALUES (
'813d31c5-5116-4fea-b4b8-eb06ce7e773c',
'Carlos'
);

```

Result:

```

ERROR:
new row violates row-level security policy
for table "patients"

```

### Observation

Even with INSERT permission granted, PostgreSQL denied the operation.

This demonstrates:

```

GRANT
does not bypass RLS

```

and

```

RLS requires a valid INSERT policy

```

## Create INSERT Policy

Create a policy using WITH CHECK:

```sql

CREATE POLICY patients_insert_by_tenant
ON patients
FOR INSERT
TO app_user
WITH CHECK (
tenant_id =
current_setting('app.tenant_id')::uuid
);

```

### Observation

The policy validates the tenant_id being inserted against the tenant stored in the current session.

## Experiment 2 - Insert for Current Tenant

Assume Tenant A:

```sql

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Insert:

```sql

INSERT INTO patients (
tenant_id,
name
)
VALUES (
'813d31c5-5116-4fea-b4b8-eb06ce7e773c',
'Carlos'
);

```

Result:

```

INSERT 0 1

```

Verification:

```sql

SELECT * FROM patients;

```

Result:

```

João
Carlos

```

### Observation

The tenant_id in the new row matched the tenant stored in the session.

The policy evaluated to TRUE and PostgreSQL allowed the insert.

## Experiment 3 - Attempt Cross-Tenant Insert

Still connected as Tenant A:

```sql

INSERT INTO patients (
tenant_id,
name
)
VALUES (
'f46c8eb7-4b1b-4ba6-8f53-734edf04d328',
'Debora'
);

```

Result:

```

ERROR:
new row violates row-level security policy
for table "patients"

```

### Observation

The session belongs to Tenant A but the inserted row belongs to Tenant B.

The policy evaluated to FALSE and PostgreSQL blocked the operation.

This prevents accidental or malicious cross-tenant data creation.

## Inspecting Policies

Query existing policies:

```sql

SELECT
policyname,
roles,
cmd,
qual,
with_check
FROM pg_policies
WHERE tablename = 'patients';

```

Result:

```

patients_by_tenant
SELECT
qual populated

patients_insert_by_tenant
INSERT
with_check populated

```

### Observation

The catalog clearly shows that PostgreSQL stores read and write policies separately.

## USING vs WITH CHECK

### USING

```sql

USING (
tenant_id =
current_setting('app.tenant_id')::uuid
)

```

Answers:

```

Can this row be viewed?

```

### WITH CHECK

```sql

WITH CHECK (
tenant_id =
current_setting('app.tenant_id')::uuid
)

```

Answers:

```

Can this row be created?

```

## Real-World SaaS Perspective

This mechanism protects against:

```

Tenant A creating records for Tenant B

```

Even if:

* The application contains a bug.
* A request payload is manipulated.
* A developer forgets validation logic.

PostgreSQL still validates tenant ownership before persisting the row.

## Key Learnings

* INSERT operations require their own RLS policy.
* GRANT INSERT alone is not sufficient.
* WITH CHECK validates new rows before insertion.
* USING and WITH CHECK serve different purposes.
* PostgreSQL protects both read and write operations through RLS.
* Cross-tenant inserts can be prevented entirely at the database layer.
* RLS provides an additional security layer independent from application code.

## Concepts Learned

```

USING
controls visibility of existing rows

WITH CHECK
controls creation of new rows

SELECT
protected by USING

INSERT
protected by WITH CHECK

GRANT
controls table permissions

RLS
controls row-level access

```

This phase extends tenant isolation from read operations to write operations, ensuring that tenants can only create data that belongs to themselves.
