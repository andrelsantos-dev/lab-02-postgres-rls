# Phase 04 - Relationships

## Objective

Protect tables that do not contain a direct tenant identifier using PostgreSQL Row Level Security (RLS).

This phase demonstrates how PostgreSQL can evaluate tenant ownership through relationships between entities.

---

## Problem Statement

The `patients` table contains a direct tenant reference:

```text
Patient
└── tenant_id
```

Because of this, the RLS policy can directly evaluate:

```sql
tenant_id =
current_setting('app.tenant_id')::uuid
```

However, the `appointments` table does not contain a tenant identifier.

```text
Appointment
└── patient_id
```

To determine tenant ownership, PostgreSQL must navigate the relationship chain:

```text
Appointment
↓
Patient
↓
Tenant
```

---

## Experiment 01 - Verify Permissions

Before granting access:

```sql
rls_lab=> select * from appointments;
ERROR:  permission denied for table appointments
```

### Observation

Table permissions are evaluated before Row Level Security policies.

---

## Experiment 02 - Grant Access

```sql
GRANT SELECT
ON appointments
TO app_user;
```

Execute:

```sql
rls_lab=> select * from appointments;
                  id                  |              patient_id              | description  
--------------------------------------+--------------------------------------+--------------
 000ceea3-56ce-41d1-960a-15675db02e52 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Cardiologist
 0c9f8a53-0f67-449d-9717-9a49351573b5 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Follow-up
 72bd338b-49fa-4db1-bb10-8ce0cc7f3636 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Orthopedic
 fd893c13-ef8b-4ac2-a619-890340a48001 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Exam Review
(4 rows)
```

### Observation

Without RLS enabled, all rows are visible.

---

## Experiment 03 - Enable RLS

```sql
ALTER TABLE appointments
ENABLE ROW LEVEL SECURITY;
```

Execute:

```sql
rls_lab=> select * from appointments;
 id | patient_id | description 
----+------------+-------------
(0 rows)
```

### Observation

After enabling RLS, PostgreSQL denies access because no policy exists.

This confirms the default deny behavior observed in previous phases.

---

## Ownership Analysis

### Patient Ownership

```text
Patient
└── tenant_id
```

### Appointment Ownership

```text
Appointment
└── patient_id
↓
Patient
↓
tenant_id
```

Appointments inherit tenant ownership through the patient relationship.

---

## Experiment 04 - Validate Ownership Query

Configure the tenant:

```sql
SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';
```

Execute:

```sql
rls_lab=# select a.* from appointments a inner join patients p on (a.patient_id = p.id) where p.tenant_id = current_setting('app.tenant_id')::uuid;
                  id                  |              patient_id              | description  
--------------------------------------+--------------------------------------+--------------
 000ceea3-56ce-41d1-960a-15675db02e52 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Cardiologist
 0c9f8a53-0f67-449d-9717-9a49351573b5 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Follow-up
(2 rows)
```

### Observation

The query confirms that appointment ownership can be determined through the patient relationship.

---

## Experiment 05 - Create Relationship-Based Policy

Create the policy:

```sql
CREATE POLICY appointments_by_tenant
ON appointments
FOR SELECT
TO app_user
USING (
EXISTS (
SELECT 1
FROM patients p
WHERE p.id = appointments.patient_id
AND p.tenant_id =
current_setting('app.tenant_id')::uuid
)
);
```

### Observation

The policy validates whether the appointment belongs to a patient associated with the current tenant.

---

## Experiment 06 - Tenant A

Configure:

```sql
SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';
```

Execute:

```sql
rls_lab=> select * from appointments;
                  id                  |              patient_id              | description  
--------------------------------------+--------------------------------------+--------------
 000ceea3-56ce-41d1-960a-15675db02e52 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Cardiologist
 0c9f8a53-0f67-449d-9717-9a49351573b5 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Follow-up
(2 rows)
```

### Observation

Only appointments belonging to Tenant A are visible.

---

## Experiment 07 - Tenant B

Configure:

```sql
SET app.tenant_id =
'f46c8eb7-4b1b-4ba6-8f53-734edf04d328';
```

Execute:

```sql
rls_lab=> select * from appointments;
                  id                  |              patient_id              | description 
--------------------------------------+--------------------------------------+-------------
 72bd338b-49fa-4db1-bb10-8ce0cc7f3636 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Orthopedic
 fd893c13-ef8b-4ac2-a619-890340a48001 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Exam Review
(2 rows)
```

### Observation

Only appointments belonging to Tenant B are visible.

The query remains unchanged.

Only the session variable changes.

---

## Query Plan Analysis

Execute:

```sql
EXPLAIN ANALYZE SELECT * FROM appointments;
```
```text
                                                  QUERY PLAN                                                  
--------------------------------------------------------------------------------------------------------------
 Seq Scan on appointments  (cost=0.00..1155.55 rows=70 width=548) (actual time=0.028..0.030 rows=2 loops=1)
   Filter: (ANY (patient_id = (hashed SubPlan 2).col1))
   Rows Removed by Filter: 2
   SubPlan 2
     ->  Seq Scan on patients p  (cost=0.00..12.80 rows=1 width=16) (actual time=0.006..0.007 rows=1 loops=1)
           Filter: (tenant_id = (current_setting('app.tenant_id'::text))::uuid)
           Rows Removed by Filter: 1
 Planning Time: 0.179 ms
 Execution Time: 0.073 ms
(9 rows)
```

### Observation

Although the policy was written using `EXISTS`, PostgreSQL internally optimized the query plan.

Instead of evaluating the subquery for every appointment row, PostgreSQL generated a hashed set of valid patient identifiers and used it to filter appointments.

This demonstrates that the execution plan may differ significantly from the SQL originally written.

---

## Key Learnings

* RLS can protect tables that do not contain a direct tenant identifier.
* Tenant ownership can be inferred through relationships between entities.
* EXISTS is a common strategy for relationship-based policies.
* PostgreSQL can optimize policy execution internally.
* Query execution plans may differ from the original policy definition.
* Relationship-based policies are more complex than direct tenant filters.
* Schema normalization can increase policy complexity.
* Understanding ownership chains is essential when designing multi-tenant systems.

---

## Conclusion

Relationship-based RLS policies allow PostgreSQL to enforce tenant isolation even when tables do not contain a direct tenant identifier.

This approach preserves a normalized schema but introduces additional complexity in policy definitions and query execution.

The next phase will explore how RLS behaves when queries involve JOIN operations across multiple protected tables.
