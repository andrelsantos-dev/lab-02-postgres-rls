# Phase 14 - RLS and JOINs: Authorization Does Not Propagate Through Relationships

## Objective

Understand how Row Level Security behaves when related tables have different protection levels.

This phase demonstrates a critical multi-tenant security concept:

```text

Foreign Key
≠
Authorization

```

and proves that protecting a parent table does not automatically protect child tables.

## Background

The current model contains:

### patients

| Tenant   | Name       |
| -------- | ---------- |
| Tenant A | João Silva |
| Tenant B | Maria      |

### appointments

| Patient    | Description  |
| ---------- | ------------ |
| João Silva | Cardiologist |
| João Silva | Follow-up    |
| Maria      | Orthopedic   |
| Maria      | Exam Review  |

The relationship is:

```sql

appointments.patient_id
REFERENCES patients(id)

```

## Existing Appointments Policy

Before the experiment, appointments contained the following policy:

```sql

SELECT
policyname,
roles,
qual
FROM pg_policies
WHERE tablename = 'appointments';

```

Result:

```sql

appointments_by_tenant

USING (
EXISTS (
SELECT 1
FROM patients p
WHERE p.id = appointments.patient_id
AND p.tenant_id =
current_setting('app.tenant_id')::uuid
)
)

```

### Observation

The appointments table does not contain a tenant_id column.

Instead, authorization is derived from patients.

This was explicitly implemented through the policy.

PostgreSQL does not infer this automatically.

## Experiment Setup

The appointments table was changed to:

```sql

ALTER TABLE appointments
DISABLE ROW LEVEL SECURITY;

```

Resulting state:

### patients

```text

RLS ENABLED

```

### appointments

```text

RLS DISABLED

```

## Hypothesis

If relationships propagated authorization automatically, appointments should still be filtered because:

```text

appointments
→ patient
→ tenant

```

However, if authorization is table-specific, disabling RLS should expose all appointments.

## Direct Query Test

Execute:

```sql

SET ROLE app_user;

SELECT *
FROM appointments;

```

Result:

```text

Cardiologist
Follow-up
Orthopedic
Exam Review

```

All four records became visible.

## Execution Plan Analysis

Query:

```sql

EXPLAIN ANALYZE
SELECT *
FROM appointments;

```

Result:

```sql

Seq Scan on appointments

```

No filter was applied.

No EXISTS clause appeared.

No tenant validation appeared.

### Observation

The policy disappeared entirely from the execution plan.

This proves that disabling RLS removes policy evaluation for that table.

## Important Discovery

Even though appointments references patients through a Foreign Key:

```sql

appointments.patient_id
→
patients.id

```

the PostgreSQL authorization engine does not automatically derive access control from the relationship.

The relationship remains valid.

Authorization does not.

## Join Experiment

Execute:

```sql

SELECT
p.name,
a.description
FROM patients p
JOIN appointments a
ON a.patient_id = p.id;

```

Initially the query failed:

```sql

ERROR:
unrecognized configuration parameter
'app.tenant_id'

```

### Observation

This immediately proved that a policy was still being executed.

The error originated from:

```sql

current_setting('app.tenant_id')

```

inside the patients policies.

## Configuring the Session

After setting the tenant:

```sql

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Execute again:

```sql

SELECT
p.name,
a.description
FROM patients p
JOIN appointments a
ON a.patient_id = p.id;

```

Result:

```text

0 rows

```

## Execution Plan Analysis

Query:

```sql

EXPLAIN ANALYZE
SELECT
p.name,
a.description
FROM patients p
JOIN appointments a
ON a.patient_id = p.id;

```

Relevant section:

```sql

Seq Scan on patients p

Filter:
(
(name = 'Maria')
AND
(
tenant_id =
current_setting('app.tenant_id')::uuid
)
)

Rows Removed by Filter: 2

```

### Observation

The patients table was filtered.

The appointments table was not.

## What Actually Happened

The join did not become secure because appointments was protected.

Instead:

```text

patients
→ returned zero rows

appointments
→ remained fully visible

JOIN
→ received no matching patients

Result
→ zero rows

```

The final result was empty because one side of the join was empty.

Not because appointments was protected.

## Critical Security Lesson

These two statements are very different:

### Incorrect Assumption

```text

Patients is protected.

Therefore appointments is protected.

```

### Reality

```text

Patients is protected.

Appointments must also be protected separately.

```

## Multi-Tenant Risk Example

Imagine:

```text

patients
appointments
prescriptions
medical_records

```

A developer enables RLS only on:

```text

patients

```

and forgets:

```text

appointments
prescriptions
medical_records

```

The system becomes vulnerable because direct access to child tables can bypass tenant isolation.

## Why the Original Appointments Policy Was Necessary

The original policy:

```sql

EXISTS (
SELECT 1
FROM patients p
WHERE p.id = appointments.patient_id
AND p.tenant_id =
current_setting('app.tenant_id')::uuid
)

```

explicitly propagated tenant authorization.

Without this policy:

```text

Appointments becomes unprotected.

```

The relationship alone is insufficient.

## Key Learnings

* RLS is evaluated independently for each table.
* Foreign Keys do not propagate authorization.
* Relationships do not imply security.
* Disabling RLS removes policy evaluation entirely.
* A parent table cannot automatically protect a child table.
* Child tables require their own authorization strategy.
* Multi-tenant isolation must be implemented table by table.

## Concepts Learned

```text

Foreign Key
≠
Authorization

Relationship
≠
Security

Parent Table Protection
≠
Child Table Protection

RLS
→ Table-specific

Authorization
→ Explicitly modeled

```

This phase demonstrates one of the most important principles of multi-tenant architecture:

```text

Every table containing sensitive tenant data
must have its own authorization strategy.

```

Failing to do so can expose data even when the main entity appears properly protected.