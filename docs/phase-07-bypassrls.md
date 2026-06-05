# Phase 06 - Owner vs RLS

## Objective

Understand how table ownership interacts with Row Level Security (RLS).

Many developers assume that enabling RLS automatically forces every user to respect policies. This phase demonstrates that ownership, privileges, and RLS are independent concepts.

## Experiments

### Verify table owner

```sql

rls_lab=# SELECT
    tablename,
    tableowner
FROM pg_tables
WHERE tablename = 'patients';

------------------------
 tablename | tableowner 
-----------+------------
 patients  | postgres
(1 row)

```

### check the roles attributes

```sql

rls_lab=# \du

-----------------------------------------------------------------------------
                                List of roles
   Role name    |                         Attributes                         
----------------+------------------------------------------------------------
 app_user       | 
 migration_user | 
 postgres       | Superuser, Create role, Create DB, Replication, Bypass RLS
 readonly_user  |

```

### Transfer ownership

```sql

rls_lab=# ALTER TABLE patients
OWNER TO migration_user;

```

Verify:

```sql

SELECT
tablename,
tableowner
FROM pg_tables
WHERE tablename = 'patients';

----------------------------
 tablename |   tableowner   
-----------+----------------
 patients  | migration_user
(1 row)

```

---

### Query as table owner

Assume the owner role:

```sql

SET ROLE migration_user;

```

Execute:

```sql

SELECT * FROM patients;

                  id                  |              tenant_id               | name  
--------------------------------------+--------------------------------------+-------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
 f241beeb-1f80-4059-8643-fabd1d7a4214 | f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Maria
(2 rows)

```

Although RLS was enabled and a policy existed, the owner was able to see all rows.

Execution plan:

```sql

EXPLAIN ANALYZE
SELECT * FROM patients;


                                              QUERY PLAN                                               
-------------------------------------------------------------------------------------------------------
 Seq Scan on patients  (cost=0.00..11.40 rows=140 width=548) (actual time=0.009..0.010 rows=2 loops=1)
 Planning Time: 0.039 ms
 Execution Time: 0.020 ms
(3 rows)

```

No RLS filter appeared in the execution plan.

### Observation

Table owners bypass RLS by default.

Ownership alone was sufficient to access all rows even though the role was not a superuser and did not have the BYPASSRLS attribute.

---

### Force RLS

Enable forced RLS evaluation:

```sql

ALTER TABLE patients
FORCE ROW LEVEL SECURITY;

```

Execute again as the owner:

```sql

SELECT * FROM patients;

 id | tenant_id | name 
----+-----------+------
(0 rows)


Execution plan:

```text

                                     QUERY PLAN                                     
------------------------------------------------------------------------------------
 Result  (cost=0.00..0.00 rows=0 width=0) (actual time=0.002..0.002 rows=0 loops=1)
   One-Time Filter: false
 Planning Time: 0.051 ms
 Execution Time: 0.018 ms
(4 rows)


```

### Observation

The owner was now required to respect RLS policies.

However, the existing policy only applied to:

```text

app_user

```

Therefore no policy was applicable to the current role and PostgreSQL returned zero rows.

---

### Verify policy scope

```sql

rls_lab=> SELECT
    policyname,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'patients';

```

Result:

```text

     policyname     |   roles    |  cmd   |                             qual                             
--------------------+------------+--------+--------------------------------------------------------------
 patients_by_tenant | {app_user} | SELECT | (tenant_id = (current_setting('app.tenant_id'::text))::uuid)
(1 row)

```

### Observation

RLS policies are role-specific.

A user may be subject to RLS but still receive no rows if no policy applies to that role.

---

### Recreate policy

```sql

DROP POLICY patients_by_tenant
ON patients;

CREATE POLICY patients_by_tenant
ON patients
FOR SELECT
TO app_user, migration_user
USING (
tenant_id =
current_setting('app.tenant_id')::uuid
);

```

Set tenant context:

```sql

SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Execute:

```sql

SELECT * FROM patients;

```

Result:

```text

                  id                  |              tenant_id               | name 
--------------------------------------+--------------------------------------+------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
(1 row)

```

Execution plan:

```sql

EXPLAIN ANALYZE
SELECT * FROM patients;

```

Result:

```text

                                             QUERY PLAN                                              
-----------------------------------------------------------------------------------------------------
 Seq Scan on patients  (cost=0.00..12.80 rows=1 width=548) (actual time=0.016..0.019 rows=1 loops=1)
   Filter: (tenant_id = (current_setting('app.tenant_id'::text))::uuid)
   Rows Removed by Filter: 1
 Planning Time: 0.097 ms
 Execution Time: 0.035 ms
(5 rows)

```

### Observation

After FORCE ROW LEVEL SECURITY and a valid policy for the owner role, PostgreSQL evaluated the RLS filter normally.

## Key Learnings

* Table ownership is independent from GRANT permissions.
* Table owners do not need explicit GRANT statements to access their tables.
* Table owners bypass RLS by default.
* FORCE ROW LEVEL SECURITY forces owners to respect RLS policies.
* FORCE RLS does not grant access by itself.
* A policy must explicitly apply to the current role.
* Superuser, ownership, GRANT permissions, and BYPASSRLS are separate concepts.
* Understanding ownership behavior is essential when validating multi-tenant isolation.

## Concepts Learned

```text

GRANT
controls SQL permissions

OWNERSHIP
controls object administration

RLS POLICY
controls row visibility

BYPASSRLS
bypasses policy evaluation

```

These mechanisms operate independently and should not be treated as equivalent.