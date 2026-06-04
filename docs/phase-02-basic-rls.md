# Phase 02 - Basic Row Level Security

## Objective

Understand how PostgreSQL Row Level Security (RLS) works before introducing tenant-based filtering.

The goal of this phase is to understand:

- Permission grants
- RLS activation
- Default deny behavior
- Policies
- USING expressions
- Query filtering

---

## Setup

### Grant permissions

As `app_user` should only be able to read patients:

```sql  
GRANT USAGE ON SCHEMA public TO app_user;

GRANT SELECT  
ON patients  
TO app_user;  
```

---

## Experiment 01 - Access Without RLS

### As postgres

```sql  
rls_lab=# select * from patients;
                  id                  |              tenant_id               | name  
--------------------------------------+--------------------------------------+-------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
 f241beeb-1f80-4059-8643-fabd1d7a4214 | f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Maria
(2 rows)
```

```sql
rls_lab=# select * from tenants;
                  id                  |   name   
--------------------------------------+----------
 813d31c5-5116-4fea-b4b8-eb06ce7e773c | Tenant A
 f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Tenant B
(2 rows)
```

```sql
rls_lab=# select * from appointments;
                  id                  |              patient_id              | description  
--------------------------------------+--------------------------------------+--------------
 000ceea3-56ce-41d1-960a-15675db02e52 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Cardiologist
 0c9f8a53-0f67-449d-9717-9a49351573b5 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Follow-up
 72bd338b-49fa-4db1-bb10-8ce0cc7f3636 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Orthopedic
 fd893c13-ef8b-4ac2-a619-890340a48001 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Exam Review
(4 rows)
```

### As app_user

```sql
rls_lab=> select * from patients;
                  id                  |              tenant_id               | name  
--------------------------------------+--------------------------------------+-------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
 f241beeb-1f80-4059-8643-fabd1d7a4214 | f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Maria
(2 rows)
```

```sql
rls_lab=> select * from tenants;
ERROR:  permission denied for table tenants
```

```sql
rls_lab=> select * from appointments;
ERROR:  permission denied for table appointments
```

### Observation

At this stage no RLS policy exists.
Access is controlled only through table permissions.

---

## Experiment 02 - Enable RLS

### Enable RLS

```sql
ALTER TABLE patients  
ENABLE ROW LEVEL SECURITY;  
```

### As postgres

```sql  
rls_lab=# select * from patients;
                  id                  |              tenant_id               | name  
--------------------------------------+--------------------------------------+-------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
 f241beeb-1f80-4059-8643-fabd1d7a4214 | f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Maria
(2 rows)
```

```sql
rls_lab=# select * from tenants;
                  id                  |   name   
--------------------------------------+----------
 813d31c5-5116-4fea-b4b8-eb06ce7e773c | Tenant A
 f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Tenant B
(2 rows)
```

```sql
rls_lab=# select * from appointments;
                  id                  |              patient_id              | description  
--------------------------------------+--------------------------------------+--------------
 000ceea3-56ce-41d1-960a-15675db02e52 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Cardiologist
 0c9f8a53-0f67-449d-9717-9a49351573b5 | cfb6ceaf-6fbf-4174-ac84-a877cb19262a | Follow-up
 72bd338b-49fa-4db1-bb10-8ce0cc7f3636 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Orthopedic
 fd893c13-ef8b-4ac2-a619-890340a48001 | f241beeb-1f80-4059-8643-fabd1d7a4214 | Exam Review
(4 rows)
```

### As app_user

rls_lab=> select * from patients;
 id | tenant_id | name 
----+-----------+------
(0 rows)

```sql
rls_lab=> select * from tenants;
ERROR:  permission denied for table tenants
```

```sql
rls_lab=> select * from appointments;
ERROR:  permission denied for table appointments
```

### Observation

Enabling RLS without defining any policy causes PostgreSQL to deny access to all rows.

This is known as a default deny or fail-closed behavior.

Superusers continue to see all rows because they possess the `BYPASSRLS` attribute.

---

## Experiment 03 - Allow All Rows

### Create policy

```sql
CREATE POLICY patients_allow_all  
ON patients  
FOR SELECT  
TO app_user  
USING (true);  
```

### Query

```sql
SET ROLE app_user;
```

```sql
rls_lab=> select * from patients;
                  id                  |              tenant_id               | name  
--------------------------------------+--------------------------------------+-------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
 f241beeb-1f80-4059-8643-fabd1d7a4214 | f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Maria
(2 rows)
```

### Observation

The expression:

```sql 
USING (true)  
```

evaluates to true for every row.
As a result, all rows become visible.

---

## Experiment 04 - Filter Rows

### Replace policy

```sql 
RESET ROLE;

DROP POLICY patients_allow_all ON patients;

CREATE POLICY patients_only_joao  
ON patients  
FOR SELECT  
TO app_user  
USING (name = 'João');  
```

### Query

```sql 
SET ROLE app_user;
```

```sql 
rls_lab=> select * from patients;
                  id                  |              tenant_id               | name 
--------------------------------------+--------------------------------------+------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
(1 row)
```

### Observation

The policy condition is evaluated for every row.

Rows that do not satisfy the condition are filtered from the result set.

---

## Experiment 05 - Query Plan Analysis

### Analyze execution

```sql  
rls_lab=> explain analyze select * from patients;
                                             QUERY PLAN                                              
-----------------------------------------------------------------------------------------------------
 Seq Scan on patients  (cost=0.00..11.75 rows=1 width=548) (actual time=0.017..0.020 rows=1 loops=1)
   Filter: ((name)::text = 'João'::text)
   Rows Removed by Filter: 1
 Planning Time: 0.094 ms
 Execution Time: 0.045 ms
(5 rows) 
```

### Observation

The execution plan reveals that PostgreSQL applies the RLS policy as a row filter.

Conceptually, the query behaves as if PostgreSQL had added:

```sql  
WHERE name = 'João'  
``` 

to the statement.

---

## Key Learnings

- RLS is disabled by default.
- Enabling RLS does not automatically grant access.
- When RLS is enabled and no policy exists, PostgreSQL denies access to all rows.
- Superusers bypass RLS through the `BYPASSRLS` attribute.
- Policies determine which rows are visible.
- The `USING` clause acts as a boolean condition evaluated for each row.
- RLS policies are applied transparently to queries.
- The application query does not change; only the visible data changes.

---

## Conclusion

At this stage we learned the core mechanics of PostgreSQL Row Level Security.

The next phase introduces session variables and tenant-based filtering, allowing policies to dynamically determine which tenant data should be visible.