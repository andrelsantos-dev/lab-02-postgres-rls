# Phase 09 - UPDATE Policies (USING + WITH CHECK)

## Objective

Understand how Row Level Security protects UPDATE operations.

This phase demonstrates how PostgreSQL uses both USING and WITH CHECK during updates and how they protect tenant isolation.

## Background

Previous phases introduced:

```text

SELECT  
→ USING

INSERT  
→ WITH CHECK

```

UPDATE combines both concepts.

When PostgreSQL executes an UPDATE it must answer two questions:

```text

1. Can this row be updated?
    
2. Is the resulting row valid after the update?
    

```

The first question is handled by USING.

The second question is handled by WITH CHECK.

## Existing Environment

The patients table already contains:

### SELECT Policy

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

### INSERT Policy

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

At this point no UPDATE policy exists.

## Experiment 1 - UPDATE Without Policy

Grant permission:

```sql

GRANT UPDATE  
ON patients  
TO app_user;

```

Assume Tenant A:

```sql

SET ROLE app_user;

SET app.tenant_id =  
'813d31c5-5116-4fea-b4b8-eb06ce7e773c';

```

Attempt update:

```sql

UPDATE patients  
SET name = 'João Silva'  
WHERE name = 'João';

```

Result:

```text

UPDATE 0

```

Execution plan:

```sql

EXPLAIN ANALYZE  
UPDATE patients  
SET name = 'João Silva'  
WHERE name = 'João';

```

Result:

```text

Result  
One-Time Filter: false

```

### Observation

Even though:

```text

GRANT UPDATE

```

was present, no UPDATE policy existed.

PostgreSQL therefore considered no rows eligible for update.

This demonstrates:

```text

GRANT  
does not bypass RLS

```

and

```text

UPDATE requires its own policy

```

## Create UPDATE Policy

Create a tenant-aware UPDATE policy:

```sql

CREATE POLICY patients_update_by_tenant  
ON patients  
FOR UPDATE  
TO app_user  
USING (  
tenant_id =  
current_setting('app.tenant_id')::uuid  
)  
WITH CHECK (  
tenant_id =  
current_setting('app.tenant_id')::uuid  
);

```

### Observation

This policy contains both parts of the UPDATE lifecycle.

USING determines which rows can be updated.

WITH CHECK determines whether the final row remains valid.

## Experiment 2 - Update Non-Tenant Data

Execute:

```sql

UPDATE patients  
SET name = 'João Silva'  
WHERE name = 'João';

```

Result:

```text

UPDATE 1

```

Verification:

```sql

SELECT *  
FROM patients;

```

Result:

```text

Carlos  
João Silva

```

### Why It Worked

USING evaluation:

```text

# Tenant A row

Tenant A session

TRUE

```

The row was eligible for update.

WITH CHECK evaluation:

```text

tenant_id remained Tenant A

TRUE

```

The resulting row remained valid.

PostgreSQL committed the update.

## Experiment 3 - Attempt Tenant Migration

Attempt:

```sql

UPDATE patients  
SET tenant_id =  
'f46c8eb7-4b1b-4ba6-8f53-734edf04d328'  
WHERE name = 'João Silva';

```

Result:

```text

ERROR:  
new row violates row-level security policy  
for table "patients"

```

### Why It Failed

USING evaluation:

```text

# Tenant A row

Tenant A session

TRUE

```

The row was reachable.

PostgreSQL then simulated the resulting row:

Before:

```text

tenant_id = Tenant A

```

After:

```text

tenant_id = Tenant B

```

WITH CHECK evaluation:

```text

# Tenant B

Tenant A

FALSE

```

The resulting row violated the policy and PostgreSQL blocked the operation.

## Understanding UPDATE Internally

PostgreSQL effectively performs:

### Step 1

Evaluate USING

```text

Can this row be updated?

```

### Step 2

Apply proposed changes

### Step 3

Evaluate WITH CHECK

```text

Can this row exist in its new state?

```

Only if both evaluations succeed is the update committed.

## Real-World SaaS Perspective

Without WITH CHECK, a tenant could potentially move records between tenants:

```text

Tenant A  
↓  
UPDATE tenant_id  
↓  
Tenant B

```

This would violate tenant isolation.

The UPDATE policy prevents such migrations at the database layer.

Even if:

- Application validation is missing.
    
- A bug exists in the API.
    
- A request payload is manipulated.
    

PostgreSQL still enforces tenant boundaries.

## Relationship Between Operations

### SELECT

```sql

USING (...)

```

Answers:

```text

Can I view this row?

```

### INSERT

```sql

WITH CHECK (...)

```

Answers:

```text

Can I create this row?

```

### UPDATE

```sql

USING (...)  
WITH CHECK (...)

```

Answers:

```text

Can I update this row?

Can this row exist after the update?

```

## Key Learnings

- UPDATE operations require their own RLS policy.
    
- GRANT UPDATE alone is insufficient.
    
- USING determines which rows are eligible for update.
    
- WITH CHECK validates the final state of updated rows.
    
- UPDATE combines both read and write validation concepts.
    
- PostgreSQL prevents tenant migration through WITH CHECK.
    
- Tenant isolation remains enforced even during data modifications.
    
- RLS protects against application-level mistakes.
    

## Concepts Learned

```text

SELECT  
USING

INSERT  
WITH CHECK

UPDATE  
USING + WITH CHECK

USING  
validates existing rows

WITH CHECK  
validates resulting rows

GRANT  
controls operation permissions

RLS  
controls row-level authorization

```

This phase completes the understanding of how PostgreSQL protects read operations, row creation, and row modifications in a multi-tenant environment.