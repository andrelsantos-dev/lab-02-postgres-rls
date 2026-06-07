# Phase 16 - Architectural Conclusions and Production Considerations

## Objective

Consolidate the knowledge acquired throughout the lab and connect PostgreSQL Row Level Security (RLS) concepts to real-world multi-tenant SaaS architectures.

This phase focuses on architectural lessons rather than new SQL experiments.

---

# Multi-Tenant Isolation Model

The lab implemented a shared database, shared schema multi-tenant model.

Conceptually:

```text

HTTP Request
↓
Authenticated User
↓
Tenant Resolution
↓
SET app.tenant_id
↓
RLS Policies
↓
Tenant Data

```

This approach allows multiple tenants to share the same database while maintaining logical isolation through PostgreSQL policies.

---

# Security Layers

During the lab, several independent security mechanisms were explored.

## Grants

```sql

GRANT SELECT
ON patients
TO app_user;

```

Grants determine whether a role can access a table.

However:

```text

Grant
≠
Authorization

```

A role may have permission to query a table and still receive no rows due to RLS.

---

## Row Level Security

```sql

ALTER TABLE patients
ENABLE ROW LEVEL SECURITY;

```

RLS introduces row-level filtering.

Conceptually:

```text

Permission to access
+
Permission to view specific rows

```

Both conditions must be satisfied.

---

## FORCE RLS

```sql

ALTER TABLE patients
FORCE ROW LEVEL SECURITY;

```

FORCE RLS prevents table owners from bypassing policies automatically.

Without FORCE RLS:

```text

Table Owner
↓
Can bypass policies

```

With FORCE RLS:

```text

Table Owner
↓
Must obey policies

```

---

# Policy Design

The lab demonstrated that policies are operation-specific.

Different operations require different policies:

```text

SELECT
INSERT
UPDATE
DELETE

```

Each operation can have independent authorization rules.

---

## USING

Controls visibility of existing rows.

Used by:

```text

SELECT
UPDATE
DELETE

```

Conceptually:

```text

Can I access this row?

```

---

## WITH CHECK

Controls validity of the resulting row state.

Used by:

```text

INSERT
UPDATE

```

Conceptually:

```text

Can this row exist after the operation?

```

---

# Policy Composition

PostgreSQL supports two policy evaluation models.

## PERMISSIVE

Default behavior.

Policies are combined using:

```text

OR

```

Example:

```text

Tenant Policy
OR
Special Access Policy

```

---

## RESTRICTIVE

Policies are combined using:

```text

AND

```

Example:

```text

Tenant Policy
AND
Additional Restriction

```

This behavior allows complex authorization strategies to be implemented directly in the database.

---

# Relationship Security

One of the most important discoveries of the lab:

```text

Foreign Key
≠
Authorization

```

and

```text

Relationship
≠
Security

```

Protecting a parent table does not automatically protect child tables.

Example:

```text

patients
↓
appointments

```

Both tables require their own security strategy.

Every table participating in tenant isolation must be evaluated independently.

---

# BYPASSRLS

The lab demonstrated the behavior of:

```text

BYPASSRLS

```

Roles with this attribute ignore all policies.

Conceptually:

```text

Grant
+
BYPASSRLS
=========

Full Access

```

The query planner no longer injects RLS filters.

This capability should be assigned only when absolutely necessary.

---

# SECURITY DEFINER

One of the most important security findings of the lab.

Default behavior:

```text

SECURITY INVOKER

```

Meaning:

```text

# Caller

Executor

```

RLS remains active.

---

With:

```text

SECURITY DEFINER

```

The execution context changes:

```text

Caller
↓
Function
↓
Owner

```

If the function owner possesses:

```text

BYPASSRLS

```

tenant isolation can be bypassed.

This represents a real security risk in multi-tenant applications.

---

# Recommended Role Design

A production environment should separate responsibilities.

Example:

```text

postgres
↓
migration_user
↓
app_user
↓
readonly_user

```

## postgres

Database administration only.

Should not be used by applications.

---

## migration_user

Responsible for:

```text

Flyway
Liquibase
Schema Changes

```

May require elevated permissions.

---

## app_user

Application runtime user.

Should be subject to RLS.

Must not possess BYPASSRLS.

---

## readonly_user

Reporting or auditing.

Should receive only the minimum required permissions.

---

# Connection Pool Considerations

Modern applications typically use connection pools.

Example:

```text

HikariCP
Tomcat Pool
Agroal

```

In these environments:

```sql

SET app.tenant_id = ...

```

must be executed whenever a connection is acquired.

Otherwise:

```text

Tenant A
↓
Connection returned to pool
↓
Tenant B reuses connection
↓
Incorrect tenant context

```

This is one of the most common implementation mistakes in RLS-based systems.

---

# Applying These Concepts To Asclepio

Potential domain model:

```text

Clinic
Patient
Appointment
Prescription
Medical Record

```

Every table participating in tenant isolation must have an explicit security strategy.

Questions that must always be answered:

```text

Who owns the data?

Who can access the data?

Which policy protects the data?

Does a child table require its own policy?

Does any function execute as SECURITY DEFINER?

```

---

# Final Learnings

The lab demonstrated several key concepts.

```text

Grant
≠
Authorization

Ownership
≠
BYPASSRLS

Foreign Key
≠
Authorization

Relationship
≠
Security

RLS protects tables individually

USING controls row visibility

WITH CHECK controls row validity

PERMISSIVE uses OR

RESTRICTIVE uses AND

FORCE RLS protects against owner bypass

SECURITY DEFINER can change the execution context

BYPASSRLS ignores all policies

```

---

# Conclusion

Row Level Security is a powerful foundation for multi-tenant architectures.

However, tenant isolation depends on more than simply enabling RLS.

A secure implementation requires:

```text

Role Design
+
Policy Design
+
Connection Management
+
Function Auditing
+
Operational Discipline

```

The primary lesson of this lab is that multi-tenant security is not achieved by a single feature.

It emerges from the correct combination of PostgreSQL roles, policies, ownership rules, and application architecture.