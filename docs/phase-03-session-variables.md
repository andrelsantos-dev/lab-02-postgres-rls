Segue uma base completa para a **Phase 03**, usando ````` conforme combinamos para facilitar o copy/paste.

# Phase 03 - Session Variables

## Objective

Understand how PostgreSQL session variables can be used to create dynamic Row Level Security (RLS) policies.

Instead of hardcoding values inside policies, PostgreSQL can evaluate values stored in the current database session.

This approach is commonly used in multi-tenant SaaS applications.

---

## Session Variables

PostgreSQL allows applications to store custom values inside the current database session.

Example:

```sql
SET app.tenant_id = '813d31c5-5116-4fea-b4b8-eb06ce7e773c';
```

The value can later be retrieved using:

```sql
SELECT current_setting('app.tenant_id');
```

---

## Experiments

### Accessing a Non-Existing Variable

```sql
rls_lab=# SELECT current_setting('app.tenant_id');
ERROR:  unrecognized configuration parameter "app.tenant_id"
```

### Observation

By default, `current_setting()` throws an error when the requested variable does not exist.

---

### Using missing_ok

```sql
rls_lab=# SELECT current_setting('app.tenant_id', true);
 current_setting 
-----------------
 
(1 row)
```

### Observation

The second parameter (`true`) enables the `missing_ok` behavior.

Instead of throwing an error, PostgreSQL returns `NULL` when the variable does not exist.

---

### Defining a Session Variable

```sql
SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';
```

Retrieve the value:

```sql
rls_lab=# SELECT current_setting('app.tenant_id');
           current_setting            
--------------------------------------
 813d31c5-5116-4fea-b4b8-eb06ce7e773c
(1 row)
```

### Observation

The variable is now stored inside the current database session.

---

## Dynamic RLS Policy

### Previous Policy

The previous policy used a fixed value:

```sql
CREATE POLICY patients_only_maria
ON patients
FOR SELECT
TO app_user
USING (name = 'Maria');
```

### New Policy

Replace it with a tenant-based policy:

```sql
RESET ROLE;

DROP POLICY patients_only_maria ON patients;

CREATE POLICY patients_by_tenant
ON patients
FOR SELECT
TO app_user
USING (
tenant_id =
current_setting('app.tenant_id')::uuid
);
```

### Observation

The policy no longer depends on a hardcoded patient name.
Instead, it evaluates the tenant identifier stored in the current session.

---

## Tenant A Test

Configure the session:

```sql
SET app.tenant_id =
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';
```

Execute:

```sql
rls_lab=> select * from patients;
                  id                  |              tenant_id               | name 
--------------------------------------+--------------------------------------+------
 cfb6ceaf-6fbf-4174-ac84-a877cb19262a | 813d31c5-5116-4fea-b4b8-eb06ce7e773c | João
(1 row)
```

### Observation

Only records belonging to Tenant A are visible.

---

## Tenant B Test

Configure the session:

```sql
SET app.tenant_id =
'f46c8eb7-4b1b-4ba6-8f53-734edf04d328';
```

Execute:

```sql
rls_lab=> select * from patients;
                  id                  |              tenant_id               | name  
--------------------------------------+--------------------------------------+-------
 f241beeb-1f80-4059-8643-fabd1d7a4214 | f46c8eb7-4b1b-4ba6-8f53-734edf04d328 | Maria
(1 row)
```

### Observation

The query did not change.

Only the session variable changed.

PostgreSQL automatically filtered the rows according to the active tenant.

---

## Query Plan Analysis

Execute:

```sql
rls_lab=> explain analyze select * from patients;
                                             QUERY PLAN                                              
-----------------------------------------------------------------------------------------------------
 Seq Scan on patients  (cost=0.00..12.80 rows=1 width=548) (actual time=0.041..0.043 rows=1 loops=1)
   Filter: (tenant_id = (current_setting('app.tenant_id'::text))::uuid)
   Rows Removed by Filter: 1
 Planning Time: 0.091 ms
 Execution Time: 0.058 ms
(5 rows)
```


### Observation

The execution plan reveals that PostgreSQL applies the RLS policy as a row filter.

Conceptually, the query behaves as if PostgreSQL had added:

```sql
WHERE tenant_id =
current_setting('app.tenant_id')::uuid
```

to the statement.

---

## Key Learnings

* PostgreSQL supports custom session variables.
* `current_setting()` retrieves values stored in the current session.
* `current_setting()` throws an error when the variable does not exist.
* `current_setting(..., true)` returns `NULL` instead of throwing an error.
* RLS policies can reference session variables.
* Session variables allow policies to become dynamic.
* The same query can return different results depending on the active tenant.
* Applications do not need to manually add `tenant_id` filters to every query.
* PostgreSQL applies RLS policies transparently during query execution.

---

## Conclusion

Session variables are a fundamental building block for implementing multi-tenant applications with PostgreSQL Row Level Security.

By storing the tenant identifier in the database session, a single RLS policy can dynamically filter data for different tenants without changing application queries.

The next phase will explore how to protect tables that do not contain a direct `tenant_id` column, requiring PostgreSQL to navigate relationships between entities.
